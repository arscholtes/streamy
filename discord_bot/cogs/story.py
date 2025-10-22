"""
Story Commands Cog
Chronicle System - Help streamers document and celebrate their journey
"""
import discord
from discord.ext import commands
import logging
from datetime import datetime
from utils.api_client import RailsAPIClient
from utils.helpers import (
    create_embed, create_error_embed, create_success_embed, create_info_embed
)
from utils.redis_client import redis_client

logger = logging.getLogger(__name__)


class Story(commands.Cog):
    """Story and Chronicle commands for streamers"""

    def __init__(self, bot: commands.Bot):
        self.bot = bot

        # Define story chapters and milestones
        self.chapters = {
            1: {
                'name': 'The Beginning',
                'description': 'Every legend starts somewhere',
                'emoji': '🌱',
                'milestones': [
                    {'name': 'First Stream', 'threshold': 1},
                    {'name': 'First Follower', 'threshold': 1},
                    {'name': 'First Hour Streamed', 'threshold': 1}
                ]
            },
            2: {
                'name': 'Finding Your Voice',
                'description': 'Discovering your unique style',
                'emoji': '🎤',
                'milestones': [
                    {'name': '10 Followers', 'threshold': 10},
                    {'name': '5 Streams Completed', 'threshold': 5},
                    {'name': 'First Regular Viewer', 'threshold': 1}
                ]
            },
            3: {
                'name': 'Building Momentum',
                'description': 'Your community is growing',
                'emoji': '📈',
                'milestones': [
                    {'name': '50 Followers', 'threshold': 50},
                    {'name': '20 Streams Completed', 'threshold': 20},
                    {'name': '100 Total Viewers', 'threshold': 100}
                ]
            },
            4: {
                'name': 'The Breakthrough',
                'description': 'Something special is happening',
                'emoji': '⚡',
                'milestones': [
                    {'name': '100 Followers', 'threshold': 100},
                    {'name': 'First Viral Moment', 'threshold': 1},
                    {'name': '50 Streams Completed', 'threshold': 50}
                ]
            },
            5: {
                'name': 'Established Creator',
                'description': 'You\'re no longer a beginner',
                'emoji': '🏆',
                'milestones': [
                    {'name': '500 Followers', 'threshold': 500},
                    {'name': '100 Streams Completed', 'threshold': 100},
                    {'name': 'First Collaboration', 'threshold': 1}
                ]
            },
            6: {
                'name': 'Rising Star',
                'description': 'People are taking notice',
                'emoji': '⭐',
                'milestones': [
                    {'name': '1,000 Followers', 'threshold': 1000},
                    {'name': '200 Streams Completed', 'threshold': 200},
                    {'name': 'First Sponsor', 'threshold': 1}
                ]
            },
            7: {
                'name': 'Content King/Queen',
                'description': 'A force in your niche',
                'emoji': '👑',
                'milestones': [
                    {'name': '5,000 Followers', 'threshold': 5000},
                    {'name': '500 Streams Completed', 'threshold': 500},
                    {'name': 'Community Leader', 'threshold': 1}
                ]
            },
            8: {
                'name': 'Streaming Legend',
                'description': 'You\'ve made it',
                'emoji': '🌟',
                'milestones': [
                    {'name': '10,000 Followers', 'threshold': 10000},
                    {'name': '1,000 Streams Completed', 'threshold': 1000},
                    {'name': 'Legacy Secured', 'threshold': 1}
                ]
            }
        }

    @commands.group(name='story', invoke_without_command=True)
    async def story_group(self, ctx: commands.Context):
        """View your streaming story and journey"""
        if ctx.invoked_subcommand is None:
            await self.show_story(ctx)

    async def show_story(self, ctx: commands.Context):
        """Show the streamer's current story progress"""
        async with RailsAPIClient() as api:
            user_data = await api.get_user_by_discord_id(str(ctx.author.id))

            if not user_data:
                embed = create_error_embed(
                    "Story Not Started",
                    "You need to register on StreamHub to begin your streaming story!\n\n"
                    "Visit streamhub.com to get started."
                )
                await ctx.send(embed=embed)
                return

            # Get story progress from Redis or API
            story_key = f"story:progress:{user_data['user']['id']}"
            story_data = redis_client.get(story_key)

            if not story_data:
                # Initialize story data
                story_data = {
                    'current_chapter': 1,
                    'milestones_completed': [],
                    'started_at': datetime.utcnow().isoformat()
                }
                redis_client.set(story_key, story_data, ttl=None)  # No expiry

            current_chapter = self.chapters.get(story_data['current_chapter'], self.chapters[1])

            embed = create_embed(
                f"{current_chapter['emoji']} Chapter {story_data['current_chapter']}: {current_chapter['name']}",
                current_chapter['description'],
                color=discord.Color.purple()
            )

            # Add journey info
            started_date = datetime.fromisoformat(story_data['started_at'])
            days_streaming = (datetime.utcnow() - started_date).days

            embed.add_field(
                name='📅 Journey Started',
                value=f"{started_date.strftime('%B %d, %Y')}\n({days_streaming} days ago)",
                inline=True
            )

            embed.add_field(
                name='📖 Current Chapter',
                value=f"Chapter {story_data['current_chapter']} of 8",
                inline=True
            )

            embed.add_field(
                name='✨ Milestones Unlocked',
                value=str(len(story_data['milestones_completed'])),
                inline=True
            )

            # Show progress in current chapter
            completed_in_chapter = [
                m for m in story_data['milestones_completed']
                if m.startswith(f"ch{story_data['current_chapter']}_")
            ]

            total_in_chapter = len(current_chapter['milestones'])
            progress_bar = self._create_progress_bar(
                len(completed_in_chapter),
                total_in_chapter
            )

            embed.add_field(
                name='📊 Chapter Progress',
                value=f"{progress_bar} {len(completed_in_chapter)}/{total_in_chapter}",
                inline=False
            )

            # List milestones
            milestone_text = ""
            for milestone in current_chapter['milestones']:
                milestone_id = f"ch{story_data['current_chapter']}_{milestone['name'].lower().replace(' ', '_')}"
                completed = milestone_id in story_data['milestones_completed']
                icon = "✅" if completed else "⬜"
                milestone_text += f"{icon} {milestone['name']}\n"

            embed.add_field(
                name='🎯 Current Milestones',
                value=milestone_text or "No milestones yet",
                inline=False
            )

            # Add helpful tip
            embed.add_field(
                name='💡 Tip',
                value=(
                    "Use `!story timeline` to see your complete journey\n"
                    "Use `!story milestone` to manually log special moments\n"
                    "Use `!memory save` to journal your thoughts"
                ),
                inline=False
            )

            embed.set_thumbnail(url=ctx.author.display_avatar.url)
            embed.set_footer(text="Your story is unique. Keep writing it. 📖")

            await ctx.send(embed=embed)

    @story_group.command(name='timeline')
    async def show_timeline(self, ctx: commands.Context):
        """View your complete streaming timeline"""
        async with RailsAPIClient() as api:
            user_data = await api.get_user_by_discord_id(str(ctx.author.id))

            if not user_data:
                await ctx.send(embed=create_error_embed("Not Registered", "Register on StreamHub first!"))
                return

            story_key = f"story:progress:{user_data['user']['id']}"
            story_data = redis_client.get(story_key)

            if not story_data:
                await ctx.send(embed=create_info_embed(
                    "Story Just Beginning",
                    "Your timeline will fill up as you hit milestones!\n\nKeep streaming to build your legend."
                ))
                return

            embed = create_embed(
                "📖 Your Streaming Timeline",
                f"The story of {ctx.author.name}'s journey",
                color=discord.Color.gold()
            )

            # Show completed chapters
            current_chapter = story_data['current_chapter']

            timeline_text = ""
            for chapter_num in range(1, 9):
                chapter = self.chapters[chapter_num]

                if chapter_num < current_chapter:
                    # Completed chapter
                    timeline_text += f"{chapter['emoji']} **{chapter['name']}** ✅\n"
                    timeline_text += f"└ _{chapter['description']}_\n\n"
                elif chapter_num == current_chapter:
                    # Current chapter
                    timeline_text += f"{chapter['emoji']} **{chapter['name']}** 🔄 (Current)\n"
                    timeline_text += f"└ _{chapter['description']}_\n\n"
                else:
                    # Future chapter
                    timeline_text += f"🔒 **{chapter['name']}** (Locked)\n"
                    timeline_text += f"└ _{chapter['description']}_\n\n"

            embed.description = timeline_text

            embed.set_footer(text=f"Currently in Chapter {current_chapter} • Keep going! 🚀")
            await ctx.send(embed=embed)

    @story_group.command(name='milestone')
    async def log_milestone(self, ctx: commands.Context, *, description: str):
        """
        Manually log a special milestone moment
        Usage: !story milestone <description>
        Example: !story milestone Hit 100 concurrent viewers for the first time!
        """
        if len(description) < 10:
            await ctx.send(embed=create_error_embed(
                "Description Too Short",
                "Please provide a more detailed description (at least 10 characters)"
            ))
            return

        async with RailsAPIClient() as api:
            user_data = await api.get_user_by_discord_id(str(ctx.author.id))

            if not user_data:
                await ctx.send(embed=create_error_embed("Not Registered", "Register on StreamHub first!"))
                return

            # Store milestone in Redis
            milestones_key = f"story:milestones:{user_data['user']['id']}"
            milestones = redis_client.get(milestones_key) or []

            milestone_entry = {
                'description': description,
                'timestamp': datetime.utcnow().isoformat(),
                'channel_id': ctx.channel.id,
                'message_id': ctx.message.id
            }

            milestones.append(milestone_entry)
            redis_client.set(milestones_key, milestones, ttl=None)

            embed = create_success_embed(
                "✨ Milestone Recorded!",
                f"**{description}**\n\n"
                f"This moment has been added to your streaming story.\n"
                f"View all milestones with `!story timeline`"
            )

            embed.set_footer(text=f"Recorded on {datetime.utcnow().strftime('%B %d, %Y at %I:%M %p')}")
            await ctx.send(embed=embed)

    @story_group.command(name='chapter')
    async def show_chapter(self, ctx: commands.Context, chapter_number: int = None):
        """
        View details about a specific chapter
        Usage: !story chapter [number]
        """
        if chapter_number and (chapter_number < 1 or chapter_number > 8):
            await ctx.send(embed=create_error_embed(
                "Invalid Chapter",
                "Chapters range from 1 to 8"
            ))
            return

        if not chapter_number:
            # Show all chapters overview
            embed = create_embed(
                "📚 The 8 Chapters of Streaming",
                "Your journey through the streaming world",
                color=discord.Color.blue()
            )

            for num, chapter in self.chapters.items():
                embed.add_field(
                    name=f"{chapter['emoji']} Chapter {num}: {chapter['name']}",
                    value=chapter['description'],
                    inline=False
                )

            embed.set_footer(text="Use !story chapter <number> to see details")
            await ctx.send(embed=embed)
            return

        # Show specific chapter
        chapter = self.chapters[chapter_number]

        embed = create_embed(
            f"{chapter['emoji']} Chapter {chapter_number}: {chapter['name']}",
            chapter['description'],
            color=discord.Color.purple()
        )

        # List milestones
        milestones_text = ""
        for i, milestone in enumerate(chapter['milestones'], 1):
            milestones_text += f"{i}. **{milestone['name']}**\n"
            milestones_text += f"   └ Requires: {milestone['threshold']} achievement\n"

        embed.add_field(
            name='🎯 Milestones to Unlock',
            value=milestones_text,
            inline=False
        )

        embed.set_footer(text="Complete all milestones to progress to the next chapter")
        await ctx.send(embed=embed)

    def _create_progress_bar(self, current: int, total: int, length: int = 10) -> str:
        """Create a visual progress bar"""
        if total == 0:
            return "░" * length

        filled = int((current / total) * length)
        return "█" * filled + "░" * (length - filled)

    @commands.Cog.listener()
    async def on_ready(self):
        """Initialize story system when bot is ready"""
        logger.info("Story system initialized")


async def setup(bot: commands.Bot):
    """Setup function for cog"""
    await bot.add_cog(Story(bot))
