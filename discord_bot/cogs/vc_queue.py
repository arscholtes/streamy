"""
VC Queue Commands Cog
Voice chat queue system with priority management
"""
import discord
from discord.ext import commands
import logging
from datetime import datetime
from utils.api_client import RailsAPIClient
from utils.helpers import (
    create_embed, create_error_embed, create_success_embed,
    create_info_embed, format_duration
)
from config.settings import VC_QUEUE_MAX_SIZE, PRIORITY_TIERS

logger = logging.getLogger(__name__)


class VcQueue(commands.Cog):
    """VC Queue commands"""

    def __init__(self, bot: commands.Bot):
        self.bot = bot

    @commands.command(name='join', aliases=['joinqueue', 'joinvc'])
    async def join_queue(self, ctx: commands.Context):
        """Join the voice chat queue"""
        async with RailsAPIClient() as api:
            # Get user data
            user_data = await api.get_user_by_discord_id(str(ctx.author.id))

            if not user_data:
                embed = create_error_embed(
                    "Not Registered",
                    "You need to register your StreamHub account first!\nUse `!register` for more info."
                )
                await ctx.send(embed=embed)
                return

            user_info = user_data['user']

            # Check if user is in voice channel
            if not ctx.author.voice:
                embed = create_error_embed(
                    "Not in Voice Channel",
                    "You must be in a voice channel to join the queue!"
                )
                await ctx.send(embed=embed)
                return

            # Get current queue
            queue = await api.get_vc_queue()

            # Check queue size
            if len(queue) >= VC_QUEUE_MAX_SIZE:
                embed = create_error_embed(
                    "Queue Full",
                    f"The queue is currently full ({VC_QUEUE_MAX_SIZE} users max).\nPlease try again later."
                )
                await ctx.send(embed=embed)
                return

            # Check if already in queue
            for entry in queue:
                if entry['discord_user_id'] == str(ctx.author.id):
                    embed = create_error_embed(
                        "Already in Queue",
                        f"You're already in the queue at position #{entry['position']}!"
                    )
                    await ctx.send(embed=embed)
                    return

            # Calculate priority
            tier = user_info['subscription_tier']
            tier_priority = PRIORITY_TIERS.get(tier, 0)

            # Get loyalty level for additional priority
            loyalty_data = await api.get_loyalty_points(user_info['id'])
            loyalty_level = loyalty_data['loyalty_points']['level'] if loyalty_data else 1

            total_priority = tier_priority + loyalty_level

            # Join queue
            try:
                result = await api.join_vc_queue(
                    user_info['id'],
                    str(ctx.author.id),
                    total_priority
                )

                # Recalculate positions after join
                queue = await api.get_vc_queue()
                user_position = None
                for entry in queue:
                    if entry['discord_user_id'] == str(ctx.author.id):
                        user_position = entry['position']
                        break

                embed = create_success_embed(
                    "Joined Queue!",
                    f"You've been added to the voice chat queue.\n\n"
                    f"**Position:** #{user_position}/{len(queue)}\n"
                    f"**Priority:** {total_priority} ({tier.upper()} tier + Level {loyalty_level})\n"
                    f"**Channel:** {ctx.author.voice.channel.mention}\n\n"
                    f"You'll be notified when it's your turn!"
                )

                await ctx.send(embed=embed)

            except Exception as e:
                logger.error(f"Error joining VC queue: {e}")
                embed = create_error_embed(
                    "Error",
                    "Failed to join the queue. Please try again."
                )
                await ctx.send(embed=embed)

    @commands.command(name='leave', aliases=['leavequeue', 'leavevc'])
    async def leave_queue(self, ctx: commands.Context):
        """Leave the voice chat queue"""
        async with RailsAPIClient() as api:
            user_data = await api.get_user_by_discord_id(str(ctx.author.id))

            if not user_data:
                embed = create_error_embed(
                    "Not Registered",
                    "You need to register first!"
                )
                await ctx.send(embed=embed)
                return

            try:
                result = await api.leave_vc_queue(user_data['user']['id'])

                embed = create_success_embed(
                    "Left Queue",
                    "You've been removed from the voice chat queue."
                )
                await ctx.send(embed=embed)

            except Exception as e:
                logger.error(f"Error leaving VC queue: {e}")
                embed = create_error_embed(
                    "Not in Queue",
                    "You're not currently in the queue."
                )
                await ctx.send(embed=embed)

    @commands.command(name='queue', aliases=['q', 'vcqueue'])
    async def view_queue(self, ctx: commands.Context):
        """View the current voice chat queue"""
        async with RailsAPIClient() as api:
            try:
                queue = await api.get_vc_queue()

                if not queue:
                    embed = create_info_embed(
                        "Queue Empty",
                        "The voice chat queue is currently empty.\nUse `!join` to join!"
                    )
                    await ctx.send(embed=embed)
                    return

                # Build queue display
                description = ""
                for i, entry in enumerate(queue[:10], 1):  # Show top 10
                    # Try to get member
                    try:
                        member = ctx.guild.get_member(int(entry['discord_user_id']))
                        name = member.mention if member else entry['username']
                    except:
                        name = entry['username']

                    # Calculate wait time
                    wait_seconds = entry.get('wait_time', 0)
                    wait_str = format_duration(int(wait_seconds)) if wait_seconds else "Just joined"

                    # Priority indicator
                    priority = entry.get('priority', 0)
                    priority_emoji = "👑" if priority >= 50 else "⭐" if priority >= 25 else "🔹"

                    description += (
                        f"**{i}.** {priority_emoji} {name}\n"
                        f"└ Priority: {priority} • Wait: {wait_str}\n\n"
                    )

                if len(queue) > 10:
                    description += f"\n*+{len(queue) - 10} more in queue*"

                embed = create_embed(
                    "🎤 Voice Chat Queue",
                    description or "Queue is empty",
                    color=discord.Color.blue()
                )

                embed.set_footer(text=f"Total in queue: {len(queue)}/{VC_QUEUE_MAX_SIZE}")
                await ctx.send(embed=embed)

            except Exception as e:
                logger.error(f"Error viewing VC queue: {e}")
                embed = create_error_embed(
                    "Error",
                    "Failed to fetch queue data."
                )
                await ctx.send(embed=embed)

    @commands.command(name='position', aliases=['pos', 'mypos'])
    async def check_position(self, ctx: commands.Context):
        """Check your position in the queue"""
        async with RailsAPIClient() as api:
            user_data = await api.get_user_by_discord_id(str(ctx.author.id))

            if not user_data:
                embed = create_error_embed(
                    "Not Registered",
                    "You need to register first!"
                )
                await ctx.send(embed=embed)
                return

            try:
                queue = await api.get_vc_queue()

                # Find user in queue
                user_entry = None
                for entry in queue:
                    if entry['discord_user_id'] == str(ctx.author.id):
                        user_entry = entry
                        break

                if not user_entry:
                    embed = create_error_embed(
                        "Not in Queue",
                        "You're not currently in the queue.\nUse `!join` to join!"
                    )
                    await ctx.send(embed=embed)
                    return

                # Calculate stats
                position = user_entry['position']
                priority = user_entry['priority']
                wait_time = format_duration(int(user_entry.get('wait_time', 0)))

                embed = create_embed(
                    "📍 Your Queue Position",
                    color=discord.Color.blue(),
                    fields=[
                        {
                            'name': '🎯 Position',
                            'value': f"**#{position}** of {len(queue)}",
                            'inline': True
                        },
                        {
                            'name': '⚡ Priority',
                            'value': str(priority),
                            'inline': True
                        },
                        {
                            'name': '⏱️ Wait Time',
                            'value': wait_time,
                            'inline': True
                        }
                    ]
                )

                # Calculate ETA (rough estimate)
                if position > 1:
                    avg_duration = 300  # 5 min average per person
                    eta_seconds = (position - 1) * avg_duration
                    eta_str = format_duration(eta_seconds)
                    embed.add_field(
                        name='🕐 Estimated Wait',
                        value=f"~{eta_str}",
                        inline=False
                    )

                await ctx.send(embed=embed)

            except Exception as e:
                logger.error(f"Error checking position: {e}")
                embed = create_error_embed(
                    "Error",
                    "Failed to check position."
                )
                await ctx.send(embed=embed)

    @commands.command(name='next', aliases=['callnext'])
    @commands.has_permissions(manage_channels=True)
    async def call_next(self, ctx: commands.Context):
        """[ADMIN] Call the next person in queue"""
        async with RailsAPIClient() as api:
            try:
                result = await api._request('POST', '/api/v1/vc_queue/next')

                if not result or not result.get('user'):
                    embed = create_info_embed(
                        "Queue Empty",
                        "There's no one in the queue."
                    )
                    await ctx.send(embed=embed)
                    return

                user_info = result['user']
                discord_id = user_info['discord_user_id']

                # Try to mention the user
                try:
                    member = ctx.guild.get_member(int(discord_id))
                    if member:
                        embed = create_success_embed(
                            "Next in Queue",
                            f"{member.mention}, you're up! Please join the voice channel."
                        )
                        await ctx.send(embed=embed)

                        # Try to DM the user
                        try:
                            dm_embed = create_info_embed(
                                "🎤 Your Turn!",
                                f"You're next in the voice chat queue for **{ctx.guild.name}**!\n"
                                f"Please join the designated voice channel now."
                            )
                            await member.send(embed=dm_embed)
                        except:
                            pass  # User has DMs disabled
                    else:
                        embed = create_info_embed(
                            "Next User",
                            f"User {user_info['username']} is next, but they're not in the server."
                        )
                        await ctx.send(embed=embed)
                except:
                    embed = create_info_embed(
                        "Next User",
                        f"User {user_info['username']} is next in queue."
                    )
                    await ctx.send(embed=embed)

            except Exception as e:
                logger.error(f"Error calling next user: {e}")
                embed = create_error_embed(
                    "Error",
                    "Failed to call next user."
                )
                await ctx.send(embed=embed)

    @commands.command(name='clearqueue', aliases=['queueclear'])
    @commands.has_permissions(administrator=True)
    async def clear_queue(self, ctx: commands.Context):
        """[ADMIN] Clear the entire queue"""
        # This would need a new API endpoint - for now just inform
        embed = create_info_embed(
            "Clear Queue",
            "Queue clearing will be implemented with proper API endpoint.\n"
            "For now, users can use `!leave` to remove themselves."
        )
        await ctx.send(embed=embed)

    @commands.command(name='queuehelp', aliases=['vchelp'])
    async def queue_help(self, ctx: commands.Context):
        """Show VC queue help and information"""
        embed = create_embed(
            "🎤 VC Queue System Help",
            "StreamHub's priority-based voice chat queue system",
            color=discord.Color.blue(),
            fields=[
                {
                    'name': '📝 How It Works',
                    'value': (
                        'Join the queue to get your turn in voice chat!\n'
                        'Higher priority = better position in queue.'
                    ),
                    'inline': False
                },
                {
                    'name': '⚡ Priority System',
                    'value': (
                        f'**FREE:** {PRIORITY_TIERS["free"]} priority\n'
                        f'**PRO:** {PRIORITY_TIERS["pro"]} priority\n'
                        f'**ENTERPRISE:** {PRIORITY_TIERS["enterprise"]} priority\n'
                        f'Plus your loyalty level!'
                    ),
                    'inline': False
                },
                {
                    'name': '💡 Commands',
                    'value': (
                        '`!join` - Join the queue\n'
                        '`!leave` - Leave the queue\n'
                        '`!queue` - View current queue\n'
                        '`!position` - Check your position'
                    ),
                    'inline': False
                },
                {
                    'name': '📊 Queue Info',
                    'value': (
                        f'**Max Size:** {VC_QUEUE_MAX_SIZE} users\n'
                        f'**Auto-timeout:** 30 minutes\n'
                        f'**Priority-based:** Yes'
                    ),
                    'inline': False
                }
            ]
        )

        await ctx.send(embed=embed)


async def setup(bot: commands.Bot):
    """Setup function for cog"""
    await bot.add_cog(VcQueue(bot))
