"""
Stream Commands Cog
Stream-related commands and notifications
"""
import discord
from discord.ext import commands, tasks
import logging
from utils.api_client import RailsAPIClient
from utils.helpers import create_embed, create_error_embed, create_success_embed, create_info_embed
from utils.redis_client import redis_client

logger = logging.getLogger(__name__)


class Stream(commands.Cog):
    """Stream commands"""

    def __init__(self, bot: commands.Bot):
        self.bot = bot
        self.notification_role_name = "Stream Notifications"
        # Stream monitoring would start here if we had webhook integration
        # self.check_streams.start()

    def cog_unload(self):
        # self.check_streams.cancel()
        pass

    @commands.command(name='stream', aliases=['streaminfo', 'live'])
    async def stream_info(self, ctx: commands.Context, user: discord.Member = None):
        """
        Get current stream information
        Usage: !stream [@user]
        """
        target = user or ctx.author

        async with RailsAPIClient() as api:
            user_data = await api.get_user_by_discord_id(str(target.id))

            if not user_data:
                await ctx.send(embed=create_error_embed(
                    "Not Registered",
                    f"{'You are' if target == ctx.author else f'{target.name} is'} not registered on StreamHub."
                ))
                return

            # Check if user is currently streaming
            is_live = redis_client.get(f"stream:live:{user_data['user']['id']}")

            if is_live:
                stream_data = is_live

                embed = create_embed(
                    "🔴 LIVE NOW",
                    f"{target.mention} is currently streaming!",
                    color=discord.Color.red()
                )

                embed.add_field(
                    name='📺 Stream Title',
                    value=stream_data.get('title', 'Untitled Stream'),
                    inline=False
                )
                embed.add_field(
                    name='🎮 Game/Category',
                    value=stream_data.get('game', 'Just Chatting'),
                    inline=True
                )
                embed.add_field(
                    name='👥 Viewers',
                    value=str(stream_data.get('viewers', 0)),
                    inline=True
                )
                embed.add_field(
                    name='⏱️ Uptime',
                    value=stream_data.get('uptime', '0m'),
                    inline=True
                )
                embed.add_field(
                    name='🔗 Watch Now',
                    value=f"[streamhub.com/{user_data['user']['username']}](https://streamhub.com/{user_data['user']['username']})",
                    inline=False
                )

                embed.set_thumbnail(url=target.display_avatar.url)
                await ctx.send(embed=embed)
            else:
                embed = create_info_embed(
                    "⚫ Offline",
                    f"{target.mention} is not currently streaming.\n\n"
                    f"Use `!notify` to get notified when they go live!"
                )
                await ctx.send(embed=embed)

    @commands.command(name='notify', aliases=['notifications', 'streamnotif'])
    async def toggle_notifications(self, ctx: commands.Context):
        """Toggle stream notifications role"""
        role = discord.utils.get(ctx.guild.roles, name=self.notification_role_name)

        if not role:
            # Create role if it doesn't exist
            try:
                role = await ctx.guild.create_role(
                    name=self.notification_role_name,
                    mentionable=True,
                    color=discord.Color.red(),
                    reason="Stream notification role"
                )
                embed = create_success_embed(
                    "Role Created",
                    f"Created {role.mention} role for stream notifications!"
                )
                await ctx.send(embed=embed)
            except discord.Forbidden:
                await ctx.send(embed=create_error_embed(
                    "Permission Error",
                    "I don't have permission to create roles."
                ))
                return

        # Toggle role
        if role in ctx.author.roles:
            await ctx.author.remove_roles(role)
            embed = create_success_embed(
                "Notifications Disabled",
                f"You will no longer receive stream notifications.\n"
                f"Use `!notify` again to re-enable."
            )
        else:
            await ctx.author.add_roles(role)
            embed = create_success_embed(
                "Notifications Enabled",
                f"You'll now be notified when streams go live! 🔔\n"
                f"Use `!notify` again to disable."
            )

        await ctx.send(embed=embed)

    @commands.command(name='setstream', aliases=['updatestream'])
    async def set_stream_info(self, ctx: commands.Context, *, title: str):
        """
        Update your stream title
        Usage: !setstream <title>
        """
        async with RailsAPIClient() as api:
            user_data = await api.get_user_by_discord_id(str(ctx.author.id))

            if not user_data:
                await ctx.send(embed=create_error_embed("Not Registered", "Register your account first!"))
                return

            # Store stream info in Redis
            stream_key = f"stream:info:{user_data['user']['id']}"
            redis_client.set(stream_key, {'title': title}, ttl=86400)  # 24 hours

            embed = create_success_embed(
                "Stream Updated",
                f"Stream title set to:\n**{title}**\n\n"
                f"This will be used when you go live!"
            )
            await ctx.send(embed=embed)

    @commands.command(name='golive', aliases=['startstream'])
    async def go_live(self, ctx: commands.Context):
        """Announce that you're going live"""
        async with RailsAPIClient() as api:
            user_data = await api.get_user_by_discord_id(str(ctx.author.id))

            if not user_data:
                await ctx.send(embed=create_error_embed("Not Registered", "Register your account first!"))
                return

            # Check if already live
            live_key = f"stream:live:{user_data['user']['id']}"
            if redis_client.exists(live_key):
                await ctx.send(embed=create_error_embed(
                    "Already Live",
                    "You're already marked as live! Use `!endstream` to go offline."
                ))
                return

            # Get stream info
            stream_key = f"stream:info:{user_data['user']['id']}"
            stream_info = redis_client.get(stream_key) or {'title': 'Live Stream'}

            # Mark as live
            redis_client.set(live_key, {
                'title': stream_info.get('title', 'Live Stream'),
                'started_at': discord.utils.utcnow().isoformat(),
                'viewers': 0,
                'game': 'Just Chatting'
            }, ttl=86400)

            # Send notification
            role = discord.utils.get(ctx.guild.roles, name=self.notification_role_name)

            embed = create_embed(
                "🔴 LIVE NOW!",
                f"{ctx.author.mention} is now streaming!",
                color=discord.Color.red()
            )
            embed.add_field(
                name='📺 Stream Title',
                value=stream_info.get('title', 'Live Stream'),
                inline=False
            )
            embed.add_field(
                name='🔗 Watch Now',
                value=f"[streamhub.com/{user_data['user']['username']}](https://streamhub.com/{user_data['user']['username']})",
                inline=False
            )
            embed.set_thumbnail(url=ctx.author.display_avatar.url)

            # Mention role if it exists
            content = role.mention if role else None
            await ctx.send(content=content, embed=embed)

    @commands.command(name='endstream', aliases=['offline'])
    async def end_stream(self, ctx: commands.Context):
        """Mark yourself as offline"""
        async with RailsAPIClient() as api:
            user_data = await api.get_user_by_discord_id(str(ctx.author.id))

            if not user_data:
                await ctx.send(embed=create_error_embed("Not Registered", "Register your account first!"))
                return

            live_key = f"stream:live:{user_data['user']['id']}"

            if not redis_client.exists(live_key):
                await ctx.send(embed=create_error_embed(
                    "Not Live",
                    "You're not currently marked as live."
                ))
                return

            redis_client.delete(live_key)

            embed = create_success_embed(
                "Stream Ended",
                "You're now marked as offline. Thanks for streaming! 👋"
            )
            await ctx.send(embed=embed)

    @commands.command(name='schedule', aliases=['streamschedule'])
    async def stream_schedule(self, ctx: commands.Context):
        """View upcoming scheduled streams"""
        embed = create_info_embed(
            "📅 Stream Schedule",
            "View the streaming schedule on StreamHub:\n"
            f"[streamhub.com/schedule](https://streamhub.com/schedule)\n\n"
            "Features:\n"
            "• See all upcoming streams\n"
            "• Set reminders\n"
            "• Filter by streamer\n"
            "• Export to calendar"
        )
        await ctx.send(embed=embed)

    @commands.command(name='raid')
    @commands.has_permissions(manage_messages=True)
    async def raid_command(self, ctx: commands.Context, target: discord.Member):
        """
        [STREAMER] Raid another streamer
        Usage: !raid @user
        """
        async with RailsAPIClient() as api:
            user_data = await api.get_user_by_discord_id(str(ctx.author.id))
            target_data = await api.get_user_by_discord_id(str(target.id))

            if not user_data or not target_data:
                await ctx.send(embed=create_error_embed(
                    "Error",
                    "Both users must be registered on StreamHub."
                ))
                return

            embed = create_embed(
                "🚀 RAID INCOMING!",
                f"{ctx.author.mention} is raiding {target.mention}!",
                color=discord.Color.purple()
            )
            embed.add_field(
                name='🎉 Thank You!',
                value=f"Thanks for watching! Go show some love to {target.mention}!",
                inline=False
            )
            embed.add_field(
                name='🔗 Watch Now',
                value=f"[streamhub.com/{target_data['user']['username']}](https://streamhub.com/{target_data['user']['username']})",
                inline=False
            )

            await ctx.send(embed=embed)


async def setup(bot: commands.Bot):
    """Setup function for cog"""
    await bot.add_cog(Stream(bot))
