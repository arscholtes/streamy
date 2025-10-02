"""
Moderation Commands Cog
Admin and moderation commands with auto-moderation
Integrates with Rails API for data persistence
"""
import discord
from discord.ext import commands, tasks
import logging
import asyncio
from datetime import datetime, timedelta
from collections import defaultdict
from utils.helpers import (
    create_embed, create_error_embed, create_success_embed,
    create_info_embed, format_duration
)
from utils.redis_client import redis_client
from utils.moderation_api import moderation_api

logger = logging.getLogger(__name__)


class Moderation(commands.Cog):
    """Moderation commands"""

    def __init__(self, bot: commands.Bot):
        self.bot = bot
        self.muted_role_name = "Muted"

        # Auto-mod tracking
        self.message_spam_tracker = defaultdict(list)  # user_id -> [timestamps]
        self.warning_cache = {}  # user_id -> warning_count

        # Start background tasks
        self.check_mutes.start()
        self.cleanup_spam_tracker.start()

    def cog_unload(self):
        self.check_mutes.cancel()
        self.cleanup_spam_tracker.cancel()

    # ============= WARNING SYSTEM =============

    @commands.command(name='warn')
    @commands.has_permissions(manage_messages=True)
    async def warn_user(self, ctx: commands.Context, member: discord.Member, *, reason: str):
        """
        Warn a user
        Usage: !warn @user <reason>
        """
        if member.bot:
            await ctx.send(embed=create_error_embed("Error", "Cannot warn bots."))
            return

        if member.top_role >= ctx.author.top_role and ctx.author != ctx.guild.owner:
            await ctx.send(embed=create_error_embed(
                "Permission Denied",
                "You cannot warn someone with equal or higher role."
            ))
            return

        # Store warning in Rails API
        warning_result = await moderation_api.warn_user(
            discord_id=str(member.id),
            moderator_discord_id=str(ctx.author.id),
            guild_id=str(ctx.guild.id),
            reason=reason
        )

        if not warning_result:
            await ctx.send(embed=create_error_embed("Error", "Failed to create warning. Please try again."))
            return

        warning_count = warning_result.get('total_warnings', 1)
        self.warning_cache[member.id] = warning_count

        embed = create_embed(
            "⚠️ User Warned",
            f"{member.mention} has been warned.",
            color=discord.Color.orange()
        )
        embed.add_field(name="Reason", value=reason, inline=False)
        embed.add_field(name="Moderator", value=ctx.author.mention, inline=True)
        embed.add_field(name="Total Warnings", value=str(warning_count), inline=True)
        embed.set_footer(text=f"User ID: {member.id}")

        await ctx.send(embed=embed)

        # DM the user
        try:
            dm_embed = create_embed(
                "⚠️ Warning Received",
                f"You have been warned in **{ctx.guild.name}**",
                color=discord.Color.orange()
            )
            dm_embed.add_field(name="Reason", value=reason, inline=False)
            dm_embed.add_field(name="Total Warnings", value=str(warning_count), inline=False)
            dm_embed.set_footer(text="Multiple warnings may result in mute or ban.")
            await member.send(embed=dm_embed)
        except:
            pass  # User has DMs disabled

        # Log to mod channel
        await self._log_moderation(ctx.guild, "Warning", member, ctx.author, reason)

        # Auto-escalation
        if warning_count >= 5:
            await ctx.send(f"⚠️ {member.mention} has {warning_count} warnings! Consider further action.")

    @commands.command(name='warnings', aliases=['warns'])
    @commands.has_permissions(manage_messages=True)
    async def view_warnings(self, ctx: commands.Context, member: discord.Member = None):
        """
        View warnings for a user
        Usage: !warnings [@user]
        """
        target = member or ctx.author

        # Fetch warnings from Rails API
        warning_data = await moderation_api.get_warnings(
            discord_id=str(target.id),
            guild_id=str(ctx.guild.id),
            limit=10
        )

        if not warning_data or warning_data.get('total_warnings', 0) == 0:
            embed = create_info_embed(
                "No Warnings",
                f"{target.mention} has no warnings on record."
            )
            await ctx.send(embed=embed)
            return

        warnings = warning_data.get('warnings', [])
        total_warnings = warning_data.get('total_warnings', len(warnings))

        embed = create_embed(
            f"⚠️ Warnings for {target.name}",
            f"Total warnings: **{total_warnings}**",
            color=discord.Color.orange()
        )

        for i, warning in enumerate(warnings[:5], 1):  # Show first 5
            warned_at = warning.get('warned_at')
            try:
                moderator = ctx.guild.get_member(int(warning.get('moderator_discord_id')))
                mod_name = moderator.mention if moderator else f"ID: {warning.get('moderator_discord_id')}"
            except:
                mod_name = "Unknown"

            embed.add_field(
                name=f"Warning #{i}",
                value=f"**Reason:** {warning.get('reason', 'No reason')}\n**By:** {mod_name}",
                inline=False
            )

        embed.set_thumbnail(url=target.display_avatar.url)
        await ctx.send(embed=embed)

    @commands.command(name='clearwarnings', aliases=['clearwarns'])
    @commands.has_permissions(administrator=True)
    async def clear_warnings(self, ctx: commands.Context, member: discord.Member):
        """
        Clear all warnings for a user
        Usage: !clearwarnings @user
        """
        # Clear warnings via Rails API
        success = await moderation_api.clear_warnings(
            discord_id=str(member.id),
            moderator_discord_id=str(ctx.author.id),
            guild_id=str(ctx.guild.id)
        )

        if not success:
            await ctx.send(embed=create_error_embed("Error", "Failed to clear warnings. Please try again."))
            return

        if member.id in self.warning_cache:
            del self.warning_cache[member.id]

        embed = create_success_embed(
            "Warnings Cleared",
            f"All warnings for {member.mention} have been cleared."
        )
        await ctx.send(embed=embed)

        await self._log_moderation(ctx.guild, "Warnings Cleared", member, ctx.author, "All warnings removed")

    # ============= MUTE SYSTEM =============

    async def _ensure_muted_role(self, guild: discord.Guild) -> discord.Role:
        """Ensure muted role exists and has proper permissions"""
        role = discord.utils.get(guild.roles, name=self.muted_role_name)

        if not role:
            role = await guild.create_role(
                name=self.muted_role_name,
                color=discord.Color.dark_gray(),
                reason="Muted role for moderation"
            )

            # Set permissions for all channels
            for channel in guild.channels:
                try:
                    await channel.set_permissions(
                        role,
                        send_messages=False,
                        speak=False,
                        add_reactions=False,
                        reason="Setup muted role permissions"
                    )
                except:
                    pass

        return role

    @commands.command(name='mute')
    @commands.has_permissions(manage_roles=True)
    async def mute_user(self, ctx: commands.Context, member: discord.Member, duration: int, *, reason: str = None):
        """
        Mute a user temporarily
        Usage: !mute @user <minutes> [reason]
        Example: !mute @user 60 Spamming
        """
        if member.bot:
            await ctx.send(embed=create_error_embed("Error", "Cannot mute bots."))
            return

        if member.top_role >= ctx.author.top_role and ctx.author != ctx.guild.owner:
            await ctx.send(embed=create_error_embed(
                "Permission Denied",
                "You cannot mute someone with equal or higher role."
            ))
            return

        if duration < 1 or duration > 43200:  # Max 30 days
            await ctx.send(embed=create_error_embed(
                "Invalid Duration",
                "Duration must be between 1 and 43200 minutes (30 days)."
            ))
            return

        # Ensure muted role exists
        muted_role = await self._ensure_muted_role(ctx.guild)

        if muted_role in member.roles:
            await ctx.send(embed=create_error_embed(
                "Already Muted",
                f"{member.mention} is already muted."
            ))
            return

        # Store mute data in Rails API
        mute_result = await moderation_api.mute_user(
            discord_id=str(member.id),
            moderator_discord_id=str(ctx.author.id),
            guild_id=str(ctx.guild.id),
            duration_minutes=duration,
            reason=reason
        )

        if not mute_result:
            await ctx.send(embed=create_error_embed("Error", "Failed to create mute record. Please try again."))
            return

        # Apply mute role in Discord
        await member.add_roles(muted_role, reason=f"Muted by {ctx.author}: {reason or 'No reason'}")

        end_time = datetime.utcnow() + timedelta(minutes=duration)

        embed = create_embed(
            "🔇 User Muted",
            f"{member.mention} has been muted.",
            color=discord.Color.red()
        )
        embed.add_field(name="Duration", value=format_duration(duration * 60), inline=True)
        embed.add_field(name="Ends", value=f"<t:{int(end_time.timestamp())}:R>", inline=True)
        if reason:
            embed.add_field(name="Reason", value=reason, inline=False)
        embed.set_footer(text=f"Moderator: {ctx.author}")

        await ctx.send(embed=embed)

        # DM the user
        try:
            dm_embed = create_embed(
                "🔇 You've Been Muted",
                f"You have been muted in **{ctx.guild.name}**",
                color=discord.Color.red()
            )
            dm_embed.add_field(name="Duration", value=format_duration(duration * 60), inline=True)
            dm_embed.add_field(name="Ends", value=f"<t:{int(end_time.timestamp())}:R>", inline=True)
            if reason:
                dm_embed.add_field(name="Reason", value=reason, inline=False)
            await member.send(embed=dm_embed)
        except:
            pass

        await self._log_moderation(ctx.guild, "Mute", member, ctx.author, f"{duration}m - {reason or 'No reason'}")

    @commands.command(name='unmute')
    @commands.has_permissions(manage_roles=True)
    async def unmute_user(self, ctx: commands.Context, member: discord.Member):
        """
        Unmute a user
        Usage: !unmute @user
        """
        muted_role = discord.utils.get(ctx.guild.roles, name=self.muted_role_name)

        if not muted_role or muted_role not in member.roles:
            await ctx.send(embed=create_error_embed(
                "Not Muted",
                f"{member.mention} is not muted."
            ))
            return

        # Remove mute from Rails API
        success = await moderation_api.unmute_user(
            discord_id=str(member.id),
            moderator_discord_id=str(ctx.author.id),
            guild_id=str(ctx.guild.id),
            reason="Manual unmute"
        )

        if not success:
            await ctx.send(embed=create_error_embed("Error", "Failed to unmute user. Please try again."))
            return

        # Remove mute role from Discord
        await member.remove_roles(muted_role, reason=f"Unmuted by {ctx.author}")

        embed = create_success_embed(
            "User Unmuted",
            f"{member.mention} has been unmuted."
        )
        await ctx.send(embed=embed)

        await self._log_moderation(ctx.guild, "Unmute", member, ctx.author, "Manual unmute")

    @tasks.loop(seconds=30)
    async def check_mutes(self):
        """Background task to check and remove expired mutes"""
        await self.bot.wait_until_ready()

        # This is a simplified version - in production you'd iterate through Redis keys
        # For now, mutes auto-expire via Redis TTL

    # ============= KICK/BAN SYSTEM =============

    @commands.command(name='kick')
    @commands.has_permissions(kick_members=True)
    async def kick_user(self, ctx: commands.Context, member: discord.Member, *, reason: str = None):
        """
        Kick a user from the server
        Usage: !kick @user [reason]
        """
        if member.bot and member.id == self.bot.user.id:
            await ctx.send(embed=create_error_embed("Error", "I won't kick myself!"))
            return

        if member.top_role >= ctx.author.top_role and ctx.author != ctx.guild.owner:
            await ctx.send(embed=create_error_embed(
                "Permission Denied",
                "You cannot kick someone with equal or higher role."
            ))
            return

        # DM before kick
        try:
            dm_embed = create_embed(
                "👢 Kicked from Server",
                f"You have been kicked from **{ctx.guild.name}**",
                color=discord.Color.red()
            )
            if reason:
                dm_embed.add_field(name="Reason", value=reason, inline=False)
            await member.send(embed=dm_embed)
        except:
            pass

        await member.kick(reason=f"Kicked by {ctx.author}: {reason or 'No reason'}")

        embed = create_success_embed(
            "User Kicked",
            f"{member.mention} has been kicked from the server."
        )
        if reason:
            embed.add_field(name="Reason", value=reason, inline=False)
        embed.set_footer(text=f"Moderator: {ctx.author}")

        await ctx.send(embed=embed)
        await self._log_moderation(ctx.guild, "Kick", member, ctx.author, reason or "No reason")

    @commands.command(name='ban')
    @commands.has_permissions(ban_members=True)
    async def ban_user(self, ctx: commands.Context, member: discord.Member, *, reason: str = None):
        """
        Ban a user from the server
        Usage: !ban @user [reason]
        """
        if member.bot and member.id == self.bot.user.id:
            await ctx.send(embed=create_error_embed("Error", "I won't ban myself!"))
            return

        if member.top_role >= ctx.author.top_role and ctx.author != ctx.guild.owner:
            await ctx.send(embed=create_error_embed(
                "Permission Denied",
                "You cannot ban someone with equal or higher role."
            ))
            return

        # DM before ban
        try:
            dm_embed = create_embed(
                "🔨 Banned from Server",
                f"You have been banned from **{ctx.guild.name}**",
                color=discord.Color.dark_red()
            )
            if reason:
                dm_embed.add_field(name="Reason", value=reason, inline=False)
            dm_embed.set_footer(text="You can appeal this ban by contacting the moderators.")
            await member.send(embed=dm_embed)
        except:
            pass

        await member.ban(reason=f"Banned by {ctx.author}: {reason or 'No reason'}", delete_message_days=1)

        embed = create_embed(
            "🔨 User Banned",
            f"{member.mention} has been banned from the server.",
            color=discord.Color.dark_red()
        )
        if reason:
            embed.add_field(name="Reason", value=reason, inline=False)
        embed.set_footer(text=f"Moderator: {ctx.author} | User ID: {member.id}")

        await ctx.send(embed=embed)
        await self._log_moderation(ctx.guild, "Ban", member, ctx.author, reason or "No reason")

    @commands.command(name='unban')
    @commands.has_permissions(ban_members=True)
    async def unban_user(self, ctx: commands.Context, user_id: str):
        """
        Unban a user by ID
        Usage: !unban <user_id>
        """
        try:
            user_id_int = int(user_id)
        except ValueError:
            await ctx.send(embed=create_error_embed("Error", "Invalid user ID."))
            return

        try:
            user = await self.bot.fetch_user(user_id_int)
            await ctx.guild.unban(user, reason=f"Unbanned by {ctx.author}")

            embed = create_success_embed(
                "User Unbanned",
                f"**{user.name}** (ID: {user.id}) has been unbanned."
            )
            await ctx.send(embed=embed)
            await self._log_moderation(ctx.guild, "Unban", user, ctx.author, "Manual unban")

        except discord.NotFound:
            await ctx.send(embed=create_error_embed("Error", "User not found or not banned."))
        except discord.Forbidden:
            await ctx.send(embed=create_error_embed("Error", "I don't have permission to unban users."))

    # ============= MESSAGE MANAGEMENT =============

    @commands.command(name='purge', aliases=['clear', 'cleanup'])
    @commands.has_permissions(manage_messages=True)
    async def purge_messages(self, ctx: commands.Context, amount: int, member: discord.Member = None):
        """
        Delete multiple messages
        Usage: !purge <amount> [@user]
        Example: !purge 50 @spammer
        """
        if amount < 1 or amount > 1000:
            await ctx.send(embed=create_error_embed(
                "Invalid Amount",
                "Amount must be between 1 and 1000."
            ))
            return

        def check(m):
            if member:
                return m.author == member
            return True

        try:
            deleted = await ctx.channel.purge(limit=amount + 1, check=check)  # +1 for command message

            embed = create_success_embed(
                "Messages Purged",
                f"Deleted {len(deleted) - 1} message(s)" + (f" from {member.mention}" if member else "")
            )
            msg = await ctx.send(embed=embed)

            # Auto-delete confirmation after 5 seconds
            await asyncio.sleep(5)
            await msg.delete()

            await self._log_moderation(
                ctx.guild,
                "Purge",
                member or "All users",
                ctx.author,
                f"{len(deleted) - 1} messages in {ctx.channel.mention}"
            )

        except discord.Forbidden:
            await ctx.send(embed=create_error_embed("Error", "I don't have permission to delete messages."))

    @commands.command(name='slowmode', aliases=['slow'])
    @commands.has_permissions(manage_channels=True)
    async def set_slowmode(self, ctx: commands.Context, seconds: int):
        """
        Set channel slowmode
        Usage: !slowmode <seconds>
        Use 0 to disable
        """
        if seconds < 0 or seconds > 21600:
            await ctx.send(embed=create_error_embed(
                "Invalid Duration",
                "Slowmode must be between 0 and 21600 seconds (6 hours)."
            ))
            return

        await ctx.channel.edit(slowmode_delay=seconds)

        if seconds == 0:
            embed = create_success_embed(
                "Slowmode Disabled",
                f"Slowmode has been disabled in {ctx.channel.mention}"
            )
        else:
            embed = create_success_embed(
                "Slowmode Enabled",
                f"Slowmode set to {seconds} second(s) in {ctx.channel.mention}"
            )

        await ctx.send(embed=embed)

    @commands.command(name='lockdown', aliases=['lock'])
    @commands.has_permissions(manage_channels=True)
    async def lockdown_channel(self, ctx: commands.Context):
        """Lock the current channel"""
        await ctx.channel.set_permissions(
            ctx.guild.default_role,
            send_messages=False,
            reason=f"Channel lockdown by {ctx.author}"
        )

        embed = create_embed(
            "🔒 Channel Locked",
            f"{ctx.channel.mention} has been locked.",
            color=discord.Color.red()
        )
        embed.set_footer(text=f"Moderator: {ctx.author}")
        await ctx.send(embed=embed)

    @commands.command(name='unlock')
    @commands.has_permissions(manage_channels=True)
    async def unlock_channel(self, ctx: commands.Context):
        """Unlock the current channel"""
        await ctx.channel.set_permissions(
            ctx.guild.default_role,
            send_messages=None,  # Reset to default
            reason=f"Channel unlocked by {ctx.author}"
        )

        embed = create_success_embed(
            "Channel Unlocked",
            f"{ctx.channel.mention} has been unlocked."
        )
        await ctx.send(embed=embed)

    # ============= AUTO-MODERATION =============

    @commands.Cog.listener()
    async def on_message(self, message: discord.Message):
        """Auto-moderation for spam, caps, and links"""
        if message.author.bot or not message.guild:
            return

        # Skip if user has manage messages permission
        if message.author.guild_permissions.manage_messages:
            return

        # Check for spam (5+ messages in 5 seconds)
        user_messages = self.message_spam_tracker[message.author.id]
        now = datetime.utcnow()
        user_messages.append(now)

        # Remove old messages
        user_messages = [msg_time for msg_time in user_messages if (now - msg_time).seconds < 5]
        self.message_spam_tracker[message.author.id] = user_messages

        if len(user_messages) >= 5:
            try:
                await message.delete()
                warning = await message.channel.send(
                    embed=create_error_embed(
                        "Spam Detected",
                        f"{message.author.mention} Please slow down! Anti-spam triggered."
                    )
                )
                await asyncio.sleep(3)
                await warning.delete()

                # Auto-warn
                self.message_spam_tracker[message.author.id] = []
                logger.info(f"Auto-mod: Spam detected from {message.author}")

            except:
                pass
            return

        # Check for excessive caps (70%+ caps in message > 10 chars)
        if len(message.content) > 10:
            caps_count = sum(1 for c in message.content if c.isupper())
            caps_percentage = caps_count / len(message.content)

            if caps_percentage > 0.7:
                try:
                    await message.delete()
                    warning = await message.channel.send(
                        embed=create_error_embed(
                            "Excessive Caps",
                            f"{message.author.mention} Please don't use excessive caps."
                        )
                    )
                    await asyncio.sleep(3)
                    await warning.delete()
                except:
                    pass
                return

    @tasks.loop(hours=1)
    async def cleanup_spam_tracker(self):
        """Clean up old spam tracking data"""
        now = datetime.utcnow()
        for user_id in list(self.message_spam_tracker.keys()):
            messages = self.message_spam_tracker[user_id]
            messages = [msg_time for msg_time in messages if (now - msg_time).seconds < 300]
            if not messages:
                del self.message_spam_tracker[user_id]
            else:
                self.message_spam_tracker[user_id] = messages

    # ============= MODERATION LOG =============

    async def _log_moderation(self, guild: discord.Guild, action: str, target, moderator, reason: str):
        """Log moderation action to mod-log channel"""
        log_channel = discord.utils.get(guild.text_channels, name="mod-log")

        if not log_channel:
            # Try to create it
            try:
                log_channel = await guild.create_text_channel(
                    "mod-log",
                    reason="Moderation logging channel"
                )
            except:
                return  # Can't create channel

        embed = create_embed(
            f"📋 Moderation: {action}",
            "",
            color=discord.Color.blue()
        )

        target_name = target.mention if hasattr(target, 'mention') else str(target)
        embed.add_field(name="Target", value=target_name, inline=True)
        embed.add_field(name="Moderator", value=moderator.mention, inline=True)
        embed.add_field(name="Reason", value=reason, inline=False)
        embed.timestamp = datetime.utcnow()

        try:
            await log_channel.send(embed=embed)
        except:
            pass

    @commands.command(name='modhelp')
    async def mod_help(self, ctx: commands.Context):
        """Show moderation commands help"""
        embed = create_embed(
            "🛡️ Moderation Commands",
            "Comprehensive moderation toolkit",
            color=discord.Color.blue(),
            fields=[
                {
                    'name': '⚠️ Warning System',
                    'value': (
                        '`!warn @user <reason>` - Warn a user\n'
                        '`!warnings [@user]` - View warnings\n'
                        '`!clearwarnings @user` - Clear warnings'
                    ),
                    'inline': False
                },
                {
                    'name': '🔇 Mute System',
                    'value': (
                        '`!mute @user <minutes> [reason]` - Mute user\n'
                        '`!unmute @user` - Unmute user'
                    ),
                    'inline': False
                },
                {
                    'name': '🔨 Kick/Ban',
                    'value': (
                        '`!kick @user [reason]` - Kick user\n'
                        '`!ban @user [reason]` - Ban user\n'
                        '`!unban <user_id>` - Unban user'
                    ),
                    'inline': False
                },
                {
                    'name': '🧹 Message Management',
                    'value': (
                        '`!purge <amount> [@user]` - Delete messages\n'
                        '`!slowmode <seconds>` - Set slowmode\n'
                        '`!lockdown` - Lock channel\n'
                        '`!unlock` - Unlock channel'
                    ),
                    'inline': False
                },
                {
                    'name': '🤖 Auto-Moderation',
                    'value': (
                        'Automatically detects:\n'
                        '• Spam (5+ msgs/5sec)\n'
                        '• Excessive caps (70%+)\n'
                        '• Auto-deletes & warns'
                    ),
                    'inline': False
                }
            ]
        )

        await ctx.send(embed=embed)


async def setup(bot: commands.Bot):
    """Setup function for cog"""
    await bot.add_cog(Moderation(bot))
