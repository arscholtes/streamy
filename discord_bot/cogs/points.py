"""
Points Commands Cog
Loyalty points system commands
"""
import discord
from discord.ext import commands
import logging
from utils.api_client import RailsAPIClient
from utils.helpers import (
    create_embed, create_error_embed, create_success_embed,
    format_points, calculate_level_from_points, points_to_next_level
)
from utils.redis_client import redis_client
from config.settings import POINTS_PER_MESSAGE, MIN_MESSAGE_LENGTH, RATE_LIMIT_POINTS_EARN_COOLDOWN

logger = logging.getLogger(__name__)


class Points(commands.Cog):
    """Loyalty points commands"""

    def __init__(self, bot: commands.Bot):
        self.bot = bot

    @commands.Cog.listener()
    async def on_message(self, message: discord.Message):
        """Award points for messages"""
        # Ignore bots and DMs
        if message.author.bot or not message.guild:
            return

        # Ignore commands
        if message.content.startswith('!'):
            return

        # Check message length
        if len(message.content) < MIN_MESSAGE_LENGTH:
            return

        # Check rate limit
        rate_key = f"points:message:{message.author.id}"
        if redis_client.exists(rate_key):
            return  # User on cooldown

        # Get user from API
        async with RailsAPIClient() as api:
            user_data = await api.get_user_by_discord_id(str(message.author.id))

            if not user_data:
                return  # User not registered

            # Award points
            try:
                await api.add_loyalty_points(
                    user_data['user']['id'],
                    POINTS_PER_MESSAGE,
                    f"Message in #{message.channel.name}",
                    'earned_chatting'
                )

                # Set cooldown
                redis_client.set(rate_key, 1, ttl=RATE_LIMIT_POINTS_EARN_COOLDOWN)

            except Exception as e:
                logger.error(f"Error awarding message points: {e}")

    @commands.command(name='points', aliases=['balance', 'bal', 'pts'])
    async def check_points(self, ctx: commands.Context, member: discord.Member = None):
        """Check your or another user's points balance"""
        target = member or ctx.author

        async with RailsAPIClient() as api:
            # Get user
            user_data = await api.get_user_by_discord_id(str(target.id))

            if not user_data:
                if target == ctx.author:
                    embed = create_error_embed(
                        "Not Registered",
                        "You need to register your StreamHub account first!\nUse `!register` for more info."
                    )
                else:
                    embed = create_error_embed(
                        "Not Registered",
                        f"{target.name} hasn't registered their StreamHub account yet."
                    )
                await ctx.send(embed=embed)
                return

            # Get loyalty points
            loyalty_data = await api.get_loyalty_points(user_data['user']['id'])

            if not loyalty_data:
                embed = create_error_embed(
                    "Error",
                    "Failed to fetch loyalty points data."
                )
                await ctx.send(embed=embed)
                return

            lp = loyalty_data['loyalty_points']

            # Calculate progress to next level
            current_level_points = 100 * (1.5 ** (lp['level'] - 1))
            next_level_points = 100 * (1.5 ** lp['level'])
            progress_in_level = lp['total_earned'] - sum(100 * (1.5 ** (i - 1)) for i in range(1, lp['level']))
            progress_percent = (progress_in_level / next_level_points) * 100

            # Create progress bar
            bar_length = 10
            filled = int(bar_length * (progress_percent / 100))
            bar = '█' * filled + '░' * (bar_length - filled)

            embed = create_embed(
                f"💎 {target.name}'s Points",
                color=target.color if hasattr(target, 'color') else discord.Color.gold(),
                fields=[
                    {
                        'name': '💰 Current Balance',
                        'value': f'**{format_points(lp["points"])}** points',
                        'inline': True
                    },
                    {
                        'name': '⭐ Level',
                        'value': f'**Level {lp["level"]}**',
                        'inline': True
                    },
                    {
                        'name': '📊 Total Earned',
                        'value': format_points(lp['total_earned']),
                        'inline': True
                    },
                    {
                        'name': '💸 Total Spent',
                        'value': format_points(lp['total_spent']),
                        'inline': True
                    },
                    {
                        'name': '🎯 Next Level',
                        'value': f'{format_points(lp["points_to_next_level"])} points needed',
                        'inline': True
                    },
                    {
                        'name': '📈 Progress',
                        'value': f'{bar} {progress_percent:.1f}%',
                        'inline': False
                    }
                ]
            )

            embed.set_thumbnail(url=target.display_avatar.url)
            await ctx.send(embed=embed)

    @commands.command(name='level', aliases=['lvl', 'rank'])
    async def check_level(self, ctx: commands.Context, member: discord.Member = None):
        """Check your or another user's level and progress"""
        target = member or ctx.author

        async with RailsAPIClient() as api:
            user_data = await api.get_user_by_discord_id(str(target.id))

            if not user_data:
                embed = create_error_embed(
                    "Not Registered",
                    f"{'You need' if target == ctx.author else target.name + ' needs'} to register first!"
                )
                await ctx.send(embed=embed)
                return

            loyalty_data = await api.get_loyalty_points(user_data['user']['id'])

            if not loyalty_data:
                await ctx.send(embed=create_error_embed("Error", "Failed to fetch level data."))
                return

            lp = loyalty_data['loyalty_points']

            embed = create_embed(
                f"⭐ Level {lp['level']}",
                f"{target.mention}'s Level Progress",
                color=discord.Color.gold(),
                fields=[
                    {
                        'name': '💎 Current Points',
                        'value': format_points(lp['points']),
                        'inline': True
                    },
                    {
                        'name': '🎯 Next Level',
                        'value': f'Level {lp["level"] + 1}',
                        'inline': True
                    },
                    {
                        'name': '📊 Points Needed',
                        'value': format_points(lp['points_to_next_level']),
                        'inline': True
                    },
                    {
                        'name': '🏆 Total Earned',
                        'value': format_points(lp['total_earned']),
                        'inline': True
                    }
                ]
            )

            embed.set_thumbnail(url=target.display_avatar.url)
            await ctx.send(embed=embed)

    @commands.command(name='leaderboard', aliases=['lb', 'top'])
    async def leaderboard(self, ctx: commands.Context, limit: int = 10):
        """View the points leaderboard"""
        if limit < 1 or limit > 25:
            limit = 10

        async with RailsAPIClient() as api:
            leaderboard_data = await api.get_loyalty_points(0)  # This endpoint needs to be updated

            # For now, call the leaderboard endpoint
            try:
                response = await api._request('GET', f'/api/v1/loyalty_points/leaderboard?limit={limit}')
                leaderboard = response.get('leaderboard', [])

                if not leaderboard:
                    embed = create_error_embed(
                        "Empty Leaderboard",
                        "No users have earned points yet!"
                    )
                    await ctx.send(embed=embed)
                    return

                # Build leaderboard text
                description = ""
                medals = ['🥇', '🥈', '🥉']

                for entry in leaderboard:
                    rank = entry['rank']
                    medal = medals[rank - 1] if rank <= 3 else f"**{rank}.**"

                    description += (
                        f"{medal} **{entry['username']}**\n"
                        f"└ Level {entry['level']} • {format_points(entry['total_earned'])} points\n\n"
                    )

                embed = create_embed(
                    "🏆 Points Leaderboard",
                    description,
                    color=discord.Color.gold()
                )

                embed.set_footer(text=f"Showing top {len(leaderboard)} users")
                await ctx.send(embed=embed)

            except Exception as e:
                logger.error(f"Leaderboard error: {e}")
                embed = create_error_embed(
                    "Error",
                    "Failed to fetch leaderboard data."
                )
                await ctx.send(embed=embed)

    @commands.command(name='daily')
    @commands.cooldown(1, 86400, commands.BucketType.user)  # Once per day
    async def daily_points(self, ctx: commands.Context):
        """Claim your daily points bonus"""
        async with RailsAPIClient() as api:
            user_data = await api.get_user_by_discord_id(str(ctx.author.id))

            if not user_data:
                embed = create_error_embed(
                    "Not Registered",
                    "You need to register your StreamHub account first!"
                )
                await ctx.send(embed=embed)
                ctx.command.reset_cooldown(ctx)
                return

            # Award daily bonus (100 points base, more for subscribers)
            tier_bonuses = {
                'free': 100,
                'pro': 250,
                'enterprise': 500
            }

            bonus = tier_bonuses.get(user_data['user']['subscription_tier'], 100)

            try:
                await api.add_loyalty_points(
                    user_data['user']['id'],
                    bonus,
                    "Daily login bonus",
                    'earned_custom'
                )

                embed = create_success_embed(
                    "Daily Bonus Claimed!",
                    f"You received **{format_points(bonus)}** points!\n\n"
                    f"Come back tomorrow for another bonus!"
                )

                await ctx.send(embed=embed)

            except Exception as e:
                logger.error(f"Daily bonus error: {e}")
                embed = create_error_embed(
                    "Error",
                    "Failed to claim daily bonus. Please try again."
                )
                await ctx.send(embed=embed)
                ctx.command.reset_cooldown(ctx)


async def setup(bot: commands.Bot):
    """Setup function for cog"""
    await bot.add_cog(Points(bot))
