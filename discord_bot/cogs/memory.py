"""
Memory Book Commands Cog
Personal journal for streamers to document their thoughts, feelings, and lessons
"""
import discord
from discord.ext import commands
import logging
from datetime import datetime, timedelta
from utils.api_client import RailsAPIClient
from utils.helpers import (
    create_embed, create_error_embed, create_success_embed, create_info_embed,
    format_duration
)
from utils.redis_client import redis_client

logger = logging.getLogger(__name__)


class Memory(commands.Cog):
    """Memory Book - Journal for streamers"""

    def __init__(self, bot: commands.Bot):
        self.bot = bot

    @commands.group(name='memory', aliases=['journal'], invoke_without_command=True)
    async def memory_group(self, ctx: commands.Context):
        """Access your personal streaming journal"""
        if ctx.invoked_subcommand is None:
            await self.show_recent_memories(ctx)

    async def show_recent_memories(self, ctx: commands.Context):
        """Show recent journal entries"""
        async with RailsAPIClient() as api:
            user_data = await api.get_user_by_discord_id(str(ctx.author.id))

            if not user_data:
                await ctx.send(embed=create_error_embed("Not Registered", "Register on StreamHub first!"))
                return

            memories_key = f"memories:{user_data['user']['id']}"
            memories = redis_client.get(memories_key) or []

            if not memories:
                embed = create_info_embed(
                    "📖 Your Memory Book",
                    "No memories yet! Start journaling your streaming journey.\n\n"
                    "**How to use:**\n"
                    "`!memory save <your thoughts>` - Save a memory\n"
                    "`!memory list` - View all memories\n"
                    "`!memory search <keyword>` - Find specific memories\n"
                    "`!memory stats` - See your journaling stats\n\n"
                    "💡 **Pro tip:** Journal after each stream to track your growth!"
                )
                embed.set_footer(text="Your thoughts are private and only visible to you")
                await ctx.send(embed=embed)
                return

            # Show last 5 memories
            recent_memories = sorted(
                memories,
                key=lambda x: x['timestamp'],
                reverse=True
            )[:5]

            embed = create_embed(
                "📖 Recent Memories",
                f"Your last {len(recent_memories)} journal entries",
                color=discord.Color.purple()
            )

            for i, memory in enumerate(recent_memories, 1):
                timestamp = datetime.fromisoformat(memory['timestamp'])
                time_ago = self._time_ago(timestamp)

                # Truncate long entries
                content = memory['content']
                if len(content) > 100:
                    content = content[:100] + "..."

                embed.add_field(
                    name=f"#{memory.get('entry_number', i)} - {time_ago}",
                    value=f"```{content}```",
                    inline=False
                )

            embed.set_footer(text=f"Total entries: {len(memories)} • Use !memory list to see all")
            await ctx.send(embed=embed)

    @memory_group.command(name='save', aliases=['write', 'add'])
    async def save_memory(self, ctx: commands.Context, *, content: str):
        """
        Save a memory or journal entry
        Usage: !memory save <your thoughts>

        Examples:
        !memory save Today was amazing! Hit 50 viewers for the first time
        !memory save Feeling burnt out. Need to remember why I started
        !memory save Just had the best chat interaction with a viewer
        """
        if len(content) < 10:
            await ctx.send(embed=create_error_embed(
                "Entry Too Short",
                "Please write at least 10 characters. Give your future self more context!"
            ))
            return

        if len(content) > 2000:
            await ctx.send(embed=create_error_embed(
                "Entry Too Long",
                f"Maximum 2000 characters. Your entry is {len(content)} characters."
            ))
            return

        async with RailsAPIClient() as api:
            user_data = await api.get_user_by_discord_id(str(ctx.author.id))

            if not user_data:
                await ctx.send(embed=create_error_embed("Not Registered", "Register on StreamHub first!"))
                return

            memories_key = f"memories:{user_data['user']['id']}"
            memories = redis_client.get(memories_key) or []

            # Create memory entry
            memory_entry = {
                'entry_number': len(memories) + 1,
                'content': content,
                'timestamp': datetime.utcnow().isoformat(),
                'channel_id': ctx.channel.id,
                'mood': self._detect_mood(content),  # Auto-detect mood from content
                'word_count': len(content.split())
            }

            memories.append(memory_entry)
            redis_client.set(memories_key, memories, ttl=None)  # No expiry

            embed = create_success_embed(
                "✅ Memory Saved",
                f"**Entry #{memory_entry['entry_number']}** has been saved to your journal.\n\n"
                f"📝 {memory_entry['word_count']} words • {memory_entry['mood']} mood\n\n"
                f"Your thoughts are private and only visible to you."
            )

            # Add milestone if this is a special number
            if memory_entry['entry_number'] in [1, 10, 50, 100, 250, 500]:
                embed.add_field(
                    name='🎉 Milestone!',
                    value=f"This is your {self._ordinal(memory_entry['entry_number'])} journal entry!",
                    inline=False
                )

            embed.set_footer(text=f"Saved on {datetime.utcnow().strftime('%B %d, %Y at %I:%M %p')}")
            await ctx.send(embed=embed)

    @memory_group.command(name='list', aliases=['all'])
    async def list_memories(self, ctx: commands.Context, page: int = 1):
        """
        List all your memories (paginated)
        Usage: !memory list [page]
        """
        async with RailsAPIClient() as api:
            user_data = await api.get_user_by_discord_id(str(ctx.author.id))

            if not user_data:
                await ctx.send(embed=create_error_embed("Not Registered", "Register on StreamHub first!"))
                return

            memories_key = f"memories:{user_data['user']['id']}"
            memories = redis_client.get(memories_key) or []

            if not memories:
                await ctx.send(embed=create_info_embed(
                    "No Memories Yet",
                    "Start journaling with `!memory save <your thoughts>`"
                ))
                return

            # Pagination
            per_page = 5
            total_pages = (len(memories) + per_page - 1) // per_page
            page = max(1, min(page, total_pages))

            start_idx = (page - 1) * per_page
            end_idx = start_idx + per_page

            # Sort by most recent
            sorted_memories = sorted(
                memories,
                key=lambda x: x['timestamp'],
                reverse=True
            )
            page_memories = sorted_memories[start_idx:end_idx]

            embed = create_embed(
                f"📖 Your Memory Book - Page {page}/{total_pages}",
                f"Showing entries {start_idx + 1}-{min(end_idx, len(memories))} of {len(memories)}",
                color=discord.Color.purple()
            )

            for memory in page_memories:
                timestamp = datetime.fromisoformat(memory['timestamp'])
                content = memory['content']
                if len(content) > 150:
                    content = content[:150] + "..."

                embed.add_field(
                    name=f"Entry #{memory['entry_number']} - {timestamp.strftime('%b %d, %Y')}",
                    value=f"{memory['mood']} ```{content}```",
                    inline=False
                )

            if total_pages > 1:
                embed.set_footer(text=f"Page {page} of {total_pages} • Use !memory list {page + 1} for next page")
            else:
                embed.set_footer(text=f"Total entries: {len(memories)}")

            await ctx.send(embed=embed)

    @memory_group.command(name='search', aliases=['find'])
    async def search_memories(self, ctx: commands.Context, *, keyword: str):
        """
        Search your memories for a keyword
        Usage: !memory search <keyword>
        """
        async with RailsAPIClient() as api:
            user_data = await api.get_user_by_discord_id(str(ctx.author.id))

            if not user_data:
                await ctx.send(embed=create_error_embed("Not Registered", "Register on StreamHub first!"))
                return

            memories_key = f"memories:{user_data['user']['id']}"
            memories = redis_client.get(memories_key) or []

            if not memories:
                await ctx.send(embed=create_info_embed(
                    "No Memories Yet",
                    "Start journaling with `!memory save <your thoughts>`"
                ))
                return

            # Search memories
            keyword_lower = keyword.lower()
            matching_memories = [
                m for m in memories
                if keyword_lower in m['content'].lower()
            ]

            if not matching_memories:
                embed = create_info_embed(
                    "No Matches Found",
                    f"No memories found containing \"{keyword}\"\n\n"
                    f"Try a different keyword or use `!memory list` to browse all entries"
                )
                await ctx.send(embed=embed)
                return

            embed = create_embed(
                f"🔍 Search Results: \"{keyword}\"",
                f"Found {len(matching_memories)} matching {'entry' if len(matching_memories) == 1 else 'entries'}",
                color=discord.Color.blue()
            )

            # Show up to 5 results
            for memory in matching_memories[:5]:
                timestamp = datetime.fromisoformat(memory['timestamp'])
                content = memory['content']
                if len(content) > 150:
                    content = content[:150] + "..."

                embed.add_field(
                    name=f"Entry #{memory['entry_number']} - {timestamp.strftime('%b %d, %Y')}",
                    value=f"```{content}```",
                    inline=False
                )

            if len(matching_memories) > 5:
                embed.set_footer(text=f"Showing 5 of {len(matching_memories)} results")

            await ctx.send(embed=embed)

    @memory_group.command(name='stats')
    async def memory_stats(self, ctx: commands.Context):
        """View your journaling statistics"""
        async with RailsAPIClient() as api:
            user_data = await api.get_user_by_discord_id(str(ctx.author.id))

            if not user_data:
                await ctx.send(embed=create_error_embed("Not Registered", "Register on StreamHub first!"))
                return

            memories_key = f"memories:{user_data['user']['id']}"
            memories = redis_client.get(memories_key) or []

            if not memories:
                await ctx.send(embed=create_info_embed(
                    "No Memories Yet",
                    "Start journaling with `!memory save <your thoughts>`"
                ))
                return

            # Calculate stats
            total_entries = len(memories)
            total_words = sum(m['word_count'] for m in memories)
            avg_words = total_words // total_entries if total_entries > 0 else 0

            # First and last entry dates
            sorted_memories = sorted(memories, key=lambda x: x['timestamp'])
            first_entry = datetime.fromisoformat(sorted_memories[0]['timestamp'])
            last_entry = datetime.fromisoformat(sorted_memories[-1]['timestamp'])
            days_journaling = (last_entry - first_entry).days + 1

            # Mood distribution
            moods = {}
            for memory in memories:
                mood = memory['mood']
                moods[mood] = moods.get(mood, 0) + 1

            # Most common mood
            most_common_mood = max(moods.items(), key=lambda x: x[1]) if moods else (None, 0)

            embed = create_embed(
                "📊 Your Journaling Stats",
                "How you've been documenting your journey",
                color=discord.Color.gold()
            )

            embed.add_field(
                name='📝 Total Entries',
                value=str(total_entries),
                inline=True
            )

            embed.add_field(
                name='📖 Total Words',
                value=f"{total_words:,}",
                inline=True
            )

            embed.add_field(
                name='📏 Avg Words/Entry',
                value=str(avg_words),
                inline=True
            )

            embed.add_field(
                name='📅 First Entry',
                value=first_entry.strftime('%b %d, %Y'),
                inline=True
            )

            embed.add_field(
                name='🗓️ Last Entry',
                value=last_entry.strftime('%b %d, %Y'),
                inline=True
            )

            embed.add_field(
                name='⏱️ Days Journaling',
                value=str(days_journaling),
                inline=True
            )

            # Mood breakdown
            mood_text = ""
            for mood, count in sorted(moods.items(), key=lambda x: x[1], reverse=True):
                percentage = (count / total_entries) * 100
                mood_text += f"{mood} {count} ({percentage:.1f}%)\n"

            embed.add_field(
                name='😊 Mood Breakdown',
                value=mood_text or "No mood data",
                inline=False
            )

            embed.set_footer(text=f"Keep journaling to track your growth! 🌱")
            await ctx.send(embed=embed)

    @memory_group.command(name='delete')
    async def delete_memory(self, ctx: commands.Context, entry_number: int):
        """
        Delete a specific memory entry
        Usage: !memory delete <entry_number>
        """
        async with RailsAPIClient() as api:
            user_data = await api.get_user_by_discord_id(str(ctx.author.id))

            if not user_data:
                await ctx.send(embed=create_error_embed("Not Registered", "Register on StreamHub first!"))
                return

            memories_key = f"memories:{user_data['user']['id']}"
            memories = redis_client.get(memories_key) or []

            # Find and remove the memory
            memory_to_delete = None
            for memory in memories:
                if memory['entry_number'] == entry_number:
                    memory_to_delete = memory
                    break

            if not memory_to_delete:
                await ctx.send(embed=create_error_embed(
                    "Entry Not Found",
                    f"No memory entry #{entry_number} found."
                ))
                return

            memories.remove(memory_to_delete)
            redis_client.set(memories_key, memories, ttl=None)

            embed = create_success_embed(
                "🗑️ Memory Deleted",
                f"Entry #{entry_number} has been removed from your journal.\n\n"
                f"This action cannot be undone."
            )
            await ctx.send(embed=embed)

    def _detect_mood(self, content: str) -> str:
        """Simple mood detection based on keywords"""
        content_lower = content.lower()

        # Positive keywords
        positive_keywords = ['amazing', 'great', 'awesome', 'happy', 'excited', 'love', 'best', 'incredible', 'fantastic']
        # Negative keywords
        negative_keywords = ['sad', 'tired', 'burnt', 'burnout', 'frustrated', 'angry', 'difficult', 'hard', 'struggling']
        # Neutral/reflective
        reflective_keywords = ['thinking', 'wondering', 'considering', 'learning', 'growing']

        positive_score = sum(1 for word in positive_keywords if word in content_lower)
        negative_score = sum(1 for word in negative_keywords if word in content_lower)
        reflective_score = sum(1 for word in reflective_keywords if word in content_lower)

        if positive_score > negative_score and positive_score > reflective_score:
            return '😊'
        elif negative_score > positive_score:
            return '😔'
        elif reflective_score > 0:
            return '🤔'
        else:
            return '📝'

    def _time_ago(self, timestamp: datetime) -> str:
        """Convert timestamp to human-readable 'time ago' format"""
        now = datetime.utcnow()
        diff = now - timestamp

        if diff.days > 365:
            years = diff.days // 365
            return f"{years} {'year' if years == 1 else 'years'} ago"
        elif diff.days > 30:
            months = diff.days // 30
            return f"{months} {'month' if months == 1 else 'months'} ago"
        elif diff.days > 0:
            return f"{diff.days} {'day' if diff.days == 1 else 'days'} ago"
        elif diff.seconds > 3600:
            hours = diff.seconds // 3600
            return f"{hours} {'hour' if hours == 1 else 'hours'} ago"
        elif diff.seconds > 60:
            minutes = diff.seconds // 60
            return f"{minutes} {'minute' if minutes == 1 else 'minutes'} ago"
        else:
            return "Just now"

    def _ordinal(self, n: int) -> str:
        """Convert number to ordinal (1st, 2nd, 3rd, etc.)"""
        if 10 <= n % 100 <= 20:
            suffix = 'th'
        else:
            suffix = {1: 'st', 2: 'nd', 3: 'rd'}.get(n % 10, 'th')
        return f"{n}{suffix}"


async def setup(bot: commands.Bot):
    """Setup function for cog"""
    await bot.add_cog(Memory(bot))
