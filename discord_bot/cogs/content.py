"""
Content Commands Cog
Clips, highlights, and VOD management
"""
import discord
from discord.ext import commands
import logging
from utils.api_client import RailsAPIClient
from utils.helpers import create_embed, create_error_embed, create_success_embed, create_info_embed

logger = logging.getLogger(__name__)


class Content(commands.Cog):
    """Content management commands"""

    def __init__(self, bot: commands.Bot):
        self.bot = bot

    @commands.command(name='clip')
    @commands.cooldown(1, 60, commands.BucketType.user)
    async def create_clip(self, ctx: commands.Context, *, title: str = None):
        """
        Create a clip from the current stream
        Usage: !clip [title]
        """
        async with RailsAPIClient() as api:
            user_data = await api.get_user_by_discord_id(str(ctx.author.id))

            if not user_data:
                await ctx.send(embed=create_error_embed("Not Registered", "Register your account first!"))
                ctx.command.reset_cooldown(ctx)
                return

            clip_title = title or f"Clip by {ctx.author.name}"

            embed = create_success_embed(
                "📹 Clip Created!",
                f"**{clip_title}**\n\n"
                f"Your clip is being processed and will be available soon at:\n"
                f"[streamhub.com/{user_data['user']['username']}/clips](https://streamhub.com/{user_data['user']['username']}/clips)\n\n"
                f"Share it with: `!share clip [clip_id]`"
            )

            await ctx.send(embed=embed)

    @commands.command(name='highlight')
    async def create_highlight(self, ctx: commands.Context, duration: int, *, title: str):
        """
        Create a highlight from recent stream
        Usage: !highlight <duration_minutes> <title>
        Example: !highlight 30 Epic comeback victory!
        """
        if duration < 1 or duration > 180:
            await ctx.send(embed=create_error_embed(
                "Invalid Duration",
                "Duration must be between 1 and 180 minutes."
            ))
            return

        async with RailsAPIClient() as api:
            user_data = await api.get_user_by_discord_id(str(ctx.author.id))

            if not user_data:
                await ctx.send(embed=create_error_embed("Not Registered", "Register your account first!"))
                return

            embed = create_success_embed(
                "✨ Highlight Created!",
                f"**{title}**\n"
                f"Duration: {duration} minutes\n\n"
                f"Your highlight is being processed!\n"
                f"View at: [streamhub.com/{user_data['user']['username']}/highlights](https://streamhub.com/{user_data['user']['username']}/highlights)"
            )

            await ctx.send(embed=embed)

    @commands.command(name='vods', aliases=['videos'])
    async def list_vods(self, ctx: commands.Context, user: discord.Member = None):
        """
        View recent VODs
        Usage: !vods [@user]
        """
        target = user or ctx.author

        async with RailsAPIClient() as api:
            user_data = await api.get_user_by_discord_id(str(target.id))

            if not user_data:
                await ctx.send(embed=create_error_embed(
                    "Not Registered",
                    f"{'You are' if target == ctx.author else f'{target.name} is'} not registered."
                ))
                return

            embed = create_embed(
                f"📼 {target.name}'s VODs",
                f"View all VODs at:\n"
                f"[streamhub.com/{user_data['user']['username']}/vods](https://streamhub.com/{user_data['user']['username']}/vods)",
                color=discord.Color.purple()
            )

            # Mock VOD data - would come from API
            embed.add_field(
                name='Recent Streams',
                value=(
                    "🎮 Epic Gaming Session - 4h 23m\n"
                    "🎤 Just Chatting - 2h 15m\n"
                    "🎯 Tournament Practice - 5h 10m"
                ),
                inline=False
            )

            embed.set_thumbnail(url=target.display_avatar.url)
            await ctx.send(embed=embed)

    @commands.command(name='share')
    async def share_content(self, ctx: commands.Context, content_type: str, content_id: str = None):
        """
        Share your content
        Usage: !share <clip/highlight/vod> [id]
        """
        if content_type.lower() not in ['clip', 'highlight', 'vod']:
            await ctx.send(embed=create_error_embed(
                "Invalid Type",
                "Content type must be: clip, highlight, or vod"
            ))
            return

        async with RailsAPIClient() as api:
            user_data = await api.get_user_by_discord_id(str(ctx.author.id))

            if not user_data:
                await ctx.send(embed=create_error_embed("Not Registered", "Register your account first!"))
                return

            content_url = f"streamhub.com/{user_data['user']['username']}/{content_type}s"
            if content_id:
                content_url += f"/{content_id}"

            embed = create_embed(
                f"🔗 Share {content_type.capitalize()}",
                f"Check out this {content_type}!\n\n"
                f"[Watch Now]({content_url})",
                color=discord.Color.blue()
            )

            embed.set_footer(text=f"Shared by {ctx.author.name}")
            await ctx.send(embed=embed)

    @commands.command(name='clipleaderboard', aliases=['toplips'])
    async def clip_leaderboard(self, ctx: commands.Context):
        """View the most popular clips"""
        embed = create_embed(
            "🏆 Top Clips",
            "Most viewed clips this week",
            color=discord.Color.gold()
        )

        # Mock data - would come from API
        clips = [
            ("🥇", "Insane 1v5 Clutch", "12.5K views", "user1"),
            ("🥈", "Epic Fail Compilation", "8.3K views", "user2"),
            ("🥉", "Perfectly Timed Comeback", "6.1K views", "user3"),
        ]

        description = ""
        for medal, title, views, username in clips:
            description += f"{medal} **{title}**\n└ {views} • by @{username}\n\n"

        embed.description = description
        await ctx.send(embed=embed)


async def setup(bot: commands.Bot):
    """Setup function for cog"""
    await bot.add_cog(Content(bot))
