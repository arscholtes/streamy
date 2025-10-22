"""
Insights Commands Cog
Analytics with Context - The "why" behind the numbers
"""
import discord
from discord.ext import commands
import logging
from datetime import datetime, timedelta
from utils.api_client import RailsAPIClient
from utils.helpers import (
    create_embed, create_error_embed, create_success_embed, create_info_embed
)

logger = logging.getLogger(__name__)


class Insights(commands.Cog):
    """Analytics insights commands for streamers"""

    def __init__(self, bot: commands.Bot):
        self.bot = bot

    @commands.group(name='insights', invoke_without_command=True)
    async def insights_group(self, ctx: commands.Context):
        """Get your latest insights and recommendations"""
        if ctx.invoked_subcommand is None:
            await self.show_insights(ctx)

    async def show_insights(self, ctx: commands.Context):
        """Show the latest insights for the streamer"""
        async with RailsAPIClient() as api:
            user_data = await api.get_user_by_discord_id(str(ctx.author.id))

            if not user_data:
                embed = create_error_embed(
                    "Not Registered",
                    "You need to register on StreamHub to view insights!\n\n"
                    "Visit streamhub.com to get started."
                )
                await ctx.send(embed=embed)
                return

            user_id = user_data['user']['id']

            # Fetch insights data
            try:
                insights_data = await api.get_analytics_insights(user_id)
            except Exception as e:
                logger.error(f"Failed to fetch insights: {e}")
                await ctx.send(embed=create_error_embed(
                    "Error Fetching Insights",
                    "Unable to retrieve your analytics data. Try again later."
                ))
                return

            # Build the insights embed
            insights = insights_data.get('insights', [])
            journey = insights_data.get('journey', {})
            chapter = insights_data.get('current_chapter', {})

            # Main embed
            embed = create_embed(
                f"📊 {ctx.author.name}'s Insights",
                journey.get('narrative', 'Your streaming journey is just beginning!'),
                color=discord.Color.purple()
            )

            # Add current chapter info
            if chapter:
                embed.add_field(
                    name=f"{chapter.get('emoji', '📖')} Current Chapter",
                    value=f"**{chapter.get('name', 'Unknown')}** (Chapter {chapter.get('number', 1)})\n"
                          f"_{chapter.get('description', '')}_",
                    inline=False
                )

            # Add journey stats
            stats = journey.get('stats', {})
            if stats:
                stats_text = (
                    f"🎮 **{stats.get('days_streamed', 0)}** days streamed\n"
                    f"⏱️ **{stats.get('total_hours', 0)}** hours\n"
                    f"👥 **{stats.get('followers_gained', 0)}** followers gained\n"
                    f"💬 **{stats.get('total_messages', 0)}** chat messages\n"
                    f"⭐ **{stats.get('engagement_score', 0)}**/100 engagement"
                )
                embed.add_field(
                    name="📈 Your Journey So Far",
                    value=stats_text,
                    inline=False
                )

            # Show top 3 insights
            if insights:
                top_insights = sorted(insights, key=lambda i: self._priority_score(i.get('priority', 'low')), reverse=True)[:3]

                for i, insight in enumerate(top_insights, 1):
                    priority_emoji = self._priority_emoji(insight.get('priority', 'low'))
                    title = f"{priority_emoji} {insight.get('title', 'Insight')}"
                    description = insight.get('description', '')
                    recommendation = insight.get('recommendation', '')

                    value = f"{description}\n\n💡 **Tip:** {recommendation}"

                    embed.add_field(
                        name=title,
                        value=value[:1024],  # Discord field limit
                        inline=False
                    )
            else:
                embed.add_field(
                    name="No Insights Yet",
                    value="Stream more to unlock personalized insights!",
                    inline=False
                )

            # Add command hints
            embed.add_field(
                name="🔍 Dive Deeper",
                value=(
                    "• `!insights growth` - Growth trends\n"
                    "• `!insights content` - Content performance\n"
                    "• `!insights audience` - Audience behavior\n"
                    "• `!insights compare` - Compare periods"
                ),
                inline=False
            )

            embed.set_thumbnail(url=ctx.author.display_avatar.url)
            embed.set_footer(text="Analytics with Context • Last 30 days")

            await ctx.send(embed=embed)

    @insights_group.command(name='growth')
    async def show_growth(self, ctx: commands.Context):
        """View growth trends and projections"""
        async with RailsAPIClient() as api:
            user_data = await api.get_user_by_discord_id(str(ctx.author.id))

            if not user_data:
                await ctx.send(embed=create_error_embed("Not Registered", "Register on StreamHub first!"))
                return

            user_id = user_data['user']['id']

            try:
                growth_data = await api.get_analytics_growth(user_id)
            except Exception as e:
                logger.error(f"Failed to fetch growth data: {e}")
                await ctx.send(embed=create_error_embed("Error", "Unable to fetch growth data"))
                return

            growth = growth_data.get('growth', {})
            trends = growth_data.get('trends', {})

            embed = create_embed(
                "📈 Your Growth This Month",
                "Here's how your channel is growing",
                color=discord.Color.green()
            )

            # Follower growth
            follower_rate = growth.get('follower_growth_rate', 0)
            follower_emoji = "📈" if follower_rate > 0 else ("📉" if follower_rate < 0 else "➡️")
            embed.add_field(
                name=f"{follower_emoji} Follower Growth",
                value=f"**{abs(follower_rate):.1f}%** {'growth' if follower_rate > 0 else 'decline'}\n"
                      f"Total gained: **{growth.get('total_followers_gained', 0)}** followers",
                inline=True
            )

            # Viewer growth
            viewer_rate = growth.get('viewer_growth_rate', 0)
            viewer_emoji = "📈" if viewer_rate > 0 else ("📉" if viewer_rate < 0 else "➡️")
            embed.add_field(
                name=f"{viewer_emoji} Viewer Growth",
                value=f"**{abs(viewer_rate):.1f}%** {'growth' if viewer_rate > 0 else 'decline'}\n"
                      f"Trend: **{trends.get('viewer_trend', 'stable')}**",
                inline=True
            )

            # Predictions from insights
            insights_data = await api.get_analytics_insights(user_id)
            predictions = insights_data.get('predictions', [])

            if predictions:
                predictions_text = ""
                for pred in predictions[:2]:  # Show top 2 predictions
                    predictions_text += f"• {pred.get('description', 'N/A')}\n"

                embed.add_field(
                    name="🔮 Predictions",
                    value=predictions_text or "No predictions yet",
                    inline=False
                )

            embed.set_footer(text="Based on last 30 days of data")
            await ctx.send(embed=embed)

    @insights_group.command(name='content')
    async def show_content(self, ctx: commands.Context):
        """Analyze your content performance"""
        async with RailsAPIClient() as api:
            user_data = await api.get_user_by_discord_id(str(ctx.author.id))

            if not user_data:
                await ctx.send(embed=create_error_embed("Not Registered", "Register on StreamHub first!"))
                return

            user_id = user_data['user']['id']

            try:
                content_data = await api.get_analytics_content(user_id)
            except Exception as e:
                logger.error(f"Failed to fetch content data: {e}")
                await ctx.send(embed=create_error_embed("Error", "Unable to fetch content data"))
                return

            content = content_data.get('content', {})
            games = content_data.get('games', [])
            recommendations = content_data.get('recommendations', [])

            embed = create_embed(
                "🎮 Content Performance",
                f"You played **{content.get('total_games_played', 0)}** different games",
                color=discord.Color.blue()
            )

            # Show top 3 games
            if games:
                top_games = games[:3]
                for i, game in enumerate(top_games, 1):
                    embed.add_field(
                        name=f"#{i} {game.get('name', 'Unknown')}",
                        value=(
                            f"**{game.get('total_hours', 0):.1f}** hours\n"
                            f"**{game.get('sessions_count', 0)}** sessions\n"
                            f"Platform: {game.get('platform', 'Unknown')}"
                        ),
                        inline=True
                    )

            # Recommendations
            if recommendations:
                recommendations_text = "\n".join([f"• {rec}" for rec in recommendations[:3]])
                embed.add_field(
                    name="💡 Recommendations",
                    value=recommendations_text,
                    inline=False
                )

            embed.set_footer(text="Last 30 days")
            await ctx.send(embed=embed)

    @insights_group.command(name='audience')
    async def show_audience(self, ctx: commands.Context):
        """Understand your audience behavior"""
        async with RailsAPIClient() as api:
            user_data = await api.get_user_by_discord_id(str(ctx.author.id))

            if not user_data:
                await ctx.send(embed=create_error_embed("Not Registered", "Register on StreamHub first!"))
                return

            user_id = user_data['user']['id']

            try:
                audience_data = await api.get_analytics_audience(user_id)
            except Exception as e:
                logger.error(f"Failed to fetch audience data: {e}")
                await ctx.send(embed=create_error_embed("Error", "Unable to fetch audience data"))
                return

            engagement = audience_data.get('engagement', {})
            retention = audience_data.get('retention', {})
            best_times = audience_data.get('best_times', {})

            embed = create_embed(
                "👥 Your Audience",
                "Understanding who watches and when",
                color=discord.Color.orange()
            )

            # Engagement score
            score = engagement.get('engagement_score', 0)
            score_emoji = "🔥" if score > 70 else ("⭐" if score > 40 else "📊")
            embed.add_field(
                name=f"{score_emoji} Engagement Score",
                value=f"**{score:.0f}**/100\n"
                      f"Chat rate: **{engagement.get('avg_chat_rate', 0):.1f}** msgs/min\n"
                      f"Participation: **{engagement.get('chat_participation_rate', 0):.1f}%**",
                inline=True
            )

            # Retention
            retention_score = retention.get('score', 0)
            retention_desc = retention.get('description', 'N/A')
            embed.add_field(
                name="🎯 Viewer Retention",
                value=f"**{retention_score:.0f}%**\n{retention_desc}",
                inline=True
            )

            # Best times
            if best_times:
                embed.add_field(
                    name="⏰ Best Times to Stream",
                    value=(
                        f"Day: **{best_times.get('day', 'N/A')}**\n"
                        f"Time: **{best_times.get('time', 'N/A')}**"
                    ),
                    inline=False
                )

            embed.set_footer(text="Last 30 days of audience data")
            await ctx.send(embed=embed)

    @insights_group.command(name='compare')
    async def show_comparison(self, ctx: commands.Context):
        """Compare current period with previous"""
        async with RailsAPIClient() as api:
            user_data = await api.get_user_by_discord_id(str(ctx.author.id))

            if not user_data:
                await ctx.send(embed=create_error_embed("Not Registered", "Register on StreamHub first!"))
                return

            user_id = user_data['user']['id']

            try:
                comparison_data = await api.get_analytics_compare(user_id)
            except Exception as e:
                logger.error(f"Failed to fetch comparison data: {e}")
                await ctx.send(embed=create_error_embed("Error", "Unable to fetch comparison data"))
                return

            comparison = comparison_data.get('comparison', {})

            embed = create_embed(
                "⚖️ Period Comparison",
                "This month vs last month",
                color=discord.Color.teal()
            )

            # Compare key metrics
            growth_comp = comparison.get('growth', {})
            if growth_comp.get('follower_growth_rate'):
                fg = growth_comp['follower_growth_rate']
                change_emoji = "📈" if fg.get('trend') == 'up' else ("📉" if fg.get('trend') == 'down' else "➡️")
                embed.add_field(
                    name=f"{change_emoji} Follower Growth",
                    value=f"Now: **{fg.get('current', 0):.1f}%**\n"
                          f"Was: **{fg.get('previous', 0):.1f}%**\n"
                          f"Change: **{fg.get('change_percentage', 0):.1f}%**",
                    inline=True
                )

            engagement_comp = comparison.get('engagement', {})
            if engagement_comp.get('engagement_score'):
                es = engagement_comp['engagement_score']
                change_emoji = "📈" if es.get('trend') == 'up' else ("📉" if es.get('trend') == 'down' else "➡️")
                embed.add_field(
                    name=f"{change_emoji} Engagement",
                    value=f"Now: **{es.get('current', 0):.0f}**/100\n"
                          f"Was: **{es.get('previous', 0):.0f}**/100\n"
                          f"Change: **{es.get('change_percentage', 0):.1f}%**",
                    inline=True
                )

            embed.set_footer(text="Comparing last 30 days to previous 30 days")
            await ctx.send(embed=embed)

    def _priority_emoji(self, priority: str) -> str:
        """Get emoji for priority level"""
        return {
            'high': '🔥',
            'medium': '⭐',
            'low': '💡'
        }.get(priority, '📊')

    def _priority_score(self, priority: str) -> int:
        """Get numeric score for priority"""
        return {
            'high': 3,
            'medium': 2,
            'low': 1
        }.get(priority, 0)

    @commands.Cog.listener()
    async def on_ready(self):
        """Initialize insights system when bot is ready"""
        logger.info("Insights system initialized")


async def setup(bot: commands.Bot):
    """Setup function for cog"""
    await bot.add_cog(Insights(bot))
