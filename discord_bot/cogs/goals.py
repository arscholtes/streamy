"""
Goals & Progress Tracking Commands Cog
Help streamers define and track their streaming objectives
"""
import discord
from discord.ext import commands
import logging
from datetime import datetime, timedelta
from utils.api_client import RailsAPIClient
from utils.helpers import (
    create_embed, create_error_embed, create_success_embed, create_info_embed
)
from utils.redis_client import redis_client

logger = logging.getLogger(__name__)


class Goals(commands.Cog):
    """Goals and progress tracking for streamers"""

    def __init__(self, bot: commands.Bot):
        self.bot = bot

        # Goal type information
        self.goal_types = {
            'growth': {'emoji': '📈', 'name': 'Growth', 'description': 'Audience & reach goals'},
            'content': {'emoji': '🎬', 'name': 'Content', 'description': 'Creative output goals'},
            'skill': {'emoji': '🎮', 'name': 'Skill', 'description': 'Performance goals'},
            'business': {'emoji': '💼', 'name': 'Business', 'description': 'Revenue & partnership goals'},
            'community': {'emoji': '🌟', 'name': 'Community', 'description': 'Building loyal fans'},
            'personal': {'emoji': '💚', 'name': 'Personal', 'description': 'Well-being goals'}
        }

    @commands.group(name='goals', invoke_without_command=True)
    async def goals_group(self, ctx: commands.Context):
        """Manage your streaming goals"""
        if ctx.invoked_subcommand is None:
            await self.list_goals(ctx)

    async def list_goals(self, ctx: commands.Context, status: str = 'active'):
        """Show user's active goals"""
        async with RailsAPIClient() as api:
            user_data = await api.get_user_by_discord_id(str(ctx.author.id))

            if not user_data:
                await ctx.send(embed=create_error_embed("Not Registered", "Register on StreamHub first!"))
                return

            try:
                response = await api.get_goals(user_data['user']['id'], status=status)
                goals = response.get('goals', [])

                if not goals:
                    embed = create_info_embed(
                        "🎯 Your Goals",
                        "No active goals yet! Start setting goals to track your streaming journey.\n\n"
                        "**How to use:**\n"
                        "`!goals set <title>` - Create a new goal\n"
                        "`!goals list` - View all active goals\n"
                        "`!goals stats` - See your goal statistics\n\n"
                        "💡 **Pro tip:** Goals help you stay focused and motivated!"
                    )
                    await ctx.send(embed=embed)
                    return

                embed = create_embed(
                    f"🎯 Your {status.title()} Goals",
                    f"You have {len(goals)} {status} {'goal' if len(goals) == 1 else 'goals'}",
                    color=discord.Color.blue()
                )

                for i, goal in enumerate(goals[:5], 1):  # Show max 5 goals
                    emoji_type = goal.get('emoji_type', '📝')
                    emoji_status = goal.get('emoji_status', '🔄')
                    title = goal.get('title', 'Untitled Goal')
                    progress = goal.get('progress_percentage', 0)
                    progress_bar = self._create_progress_bar(progress)

                    # Build field value
                    field_value = f"{progress_bar} {progress:.0f}%\n"

                    if goal.get('deadline'):
                        days_left = goal.get('days_until_deadline')
                        if days_left is not None:
                            if days_left < 0:
                                field_value += f"⚠️ Overdue by {abs(days_left)} days\n"
                            else:
                                field_value += f"📅 {days_left} days remaining\n"

                    if goal.get('on_track') is not None:
                        track_emoji = "✅" if goal['on_track'] else "⚠️"
                        track_text = "On track" if goal['on_track'] else "Behind schedule"
                        field_value += f"{track_emoji} {track_text}\n"

                    field_value += f"Use `!goals show {goal['id']}` for details"

                    embed.add_field(
                        name=f"{emoji_type} {emoji_status} {title}",
                        value=field_value,
                        inline=False
                    )

                if len(goals) > 5:
                    embed.set_footer(text=f"Showing 5 of {len(goals)} goals • Use !goals stats for overview")
                else:
                    embed.set_footer(text="Use !goals set <title> to create a new goal")

                await ctx.send(embed=embed)

            except Exception as e:
                logger.error(f"Error listing goals: {e}")
                await ctx.send(embed=create_error_embed("Error", "Failed to retrieve goals"))

    @goals_group.command(name='set')
    async def set_goal(self, ctx: commands.Context, *, title: str):
        """
        Create a new goal
        Usage: !goals set <title>
        Example: !goals set Reach 500 followers
        """
        if len(title) < 3:
            await ctx.send(embed=create_error_embed(
                "Title Too Short",
                "Goal title must be at least 3 characters"
            ))
            return

        if len(title) > 200:
            await ctx.send(embed=create_error_embed(
                "Title Too Long",
                f"Goal title must be under 200 characters (current: {len(title)})"
            ))
            return

        async with RailsAPIClient() as api:
            user_data = await api.get_user_by_discord_id(str(ctx.author.id))

            if not user_data:
                await ctx.send(embed=create_error_embed("Not Registered", "Register on StreamHub first!"))
                return

            try:
                # Create the goal
                response = await api.create_goal(
                    user_id=user_data['user']['id'],
                    title=title,
                    goal_type='growth',  # Default type
                    status='active',
                    progress_type='percentage',
                    target_value=100.0
                )

                goal = response.get('goal', {})

                embed = create_success_embed(
                    "✨ Goal Created!",
                    f"**{title}**\n\n"
                    f"Your goal has been added to your streaming journey!\n\n"
                    f"**Next steps:**\n"
                    f"• `!goals progress {goal['id']} <value>` - Update progress\n"
                    f"• `!goals show {goal['id']}` - View details\n"
                    f"• `!goals complete {goal['id']}` - Mark as completed"
                )

                embed.set_footer(text=f"Goal ID: {goal['id']} • Created {datetime.now().strftime('%b %d, %Y')}")
                await ctx.send(embed=embed)

            except Exception as e:
                logger.error(f"Error creating goal: {e}")
                await ctx.send(embed=create_error_embed("Error", "Failed to create goal"))

    @goals_group.command(name='show')
    async def show_goal(self, ctx: commands.Context, goal_id: int):
        """
        View detailed information about a specific goal
        Usage: !goals show <goal_id>
        """
        async with RailsAPIClient() as api:
            user_data = await api.get_user_by_discord_id(str(ctx.author.id))

            if not user_data:
                await ctx.send(embed=create_error_embed("Not Registered", "Register on StreamHub first!"))
                return

            try:
                response = await api.get_goal(goal_id)
                goal = response.get('goal', {})

                if not goal:
                    await ctx.send(embed=create_error_embed("Not Found", f"Goal #{goal_id} not found"))
                    return

                emoji_type = goal.get('emoji_type', '📝')
                emoji_status = goal.get('emoji_status', '🔄')
                progress = goal.get('progress_percentage', 0)

                embed = create_embed(
                    f"{emoji_type} {emoji_status} {goal['title']}",
                    goal.get('description', 'No description provided'),
                    color=discord.Color.gold()
                )

                # Progress section
                progress_bar = self._create_progress_bar(progress)
                current_val = goal.get('current_value', 0)
                target_val = goal.get('target_value', 100)

                embed.add_field(
                    name='📊 Progress',
                    value=f"{progress_bar} {progress:.1f}%\n{current_val}/{target_val}",
                    inline=True
                )

                # Type and Status
                goal_type_info = self.goal_types.get(goal.get('goal_type', 'growth'), self.goal_types['growth'])
                embed.add_field(
                    name='📁 Type',
                    value=f"{goal_type_info['emoji']} {goal_type_info['name']}",
                    inline=True
                )

                embed.add_field(
                    name='⚡ Status',
                    value=goal.get('status', 'active').title(),
                    inline=True
                )

                # Timeline info
                if goal.get('deadline'):
                    days_left = goal.get('days_until_deadline')
                    deadline_date = datetime.fromisoformat(goal['deadline'].replace('Z', '+00:00'))
                    deadline_str = deadline_date.strftime('%b %d, %Y')

                    if days_left is not None:
                        if days_left < 0:
                            deadline_info = f"⚠️ Overdue by {abs(days_left)} days\n{deadline_str}"
                        else:
                            deadline_info = f"📅 {days_left} days remaining\n{deadline_str}"
                    else:
                        deadline_info = deadline_str

                    embed.add_field(
                        name='🎯 Deadline',
                        value=deadline_info,
                        inline=True
                    )

                # Days active
                days_active = goal.get('days_active', 0)
                embed.add_field(
                    name='⏱️ Days Active',
                    value=f"{days_active} days",
                    inline=True
                )

                # On track status
                if goal.get('on_track') is not None:
                    track_emoji = "✅" if goal['on_track'] else "⚠️"
                    track_text = "On track!" if goal['on_track'] else "Behind schedule"
                    embed.add_field(
                        name='🎯 Progress Tracking',
                        value=f"{track_emoji} {track_text}",
                        inline=True
                    )

                # Steps if available
                steps_progress = goal.get('steps_progress', {})
                if steps_progress.get('total', 0) > 0:
                    completed_steps = steps_progress.get('completed', 0)
                    total_steps = steps_progress.get('total', 0)
                    steps_bar = self._create_progress_bar(steps_progress.get('percentage', 0))

                    embed.add_field(
                        name='✅ Steps Completed',
                        value=f"{steps_bar}\n{completed_steps}/{total_steps} steps",
                        inline=False
                    )

                # Recent updates
                recent_updates = goal.get('recent_updates', [])
                if recent_updates:
                    last_update = recent_updates[0]
                    update_date = datetime.fromisoformat(last_update['created_at'].replace('Z', '+00:00'))
                    update_text = f"Last updated {self._time_ago(update_date)}"
                    if last_update.get('note'):
                        update_text += f"\n\"{last_update['note']}\""

                    embed.add_field(
                        name='💬 Last Update',
                        value=update_text,
                        inline=False
                    )

                embed.set_footer(text=f"Goal ID: {goal['id']} • Use !goals progress {goal['id']} <value> to update")
                await ctx.send(embed=embed)

            except Exception as e:
                logger.error(f"Error showing goal: {e}")
                await ctx.send(embed=create_error_embed("Error", "Failed to retrieve goal details"))

    @goals_group.command(name='progress')
    async def update_progress(self, ctx: commands.Context, goal_id: int, value: float, *, note: str = None):
        """
        Update progress on a goal
        Usage: !goals progress <goal_id> <value> [note]
        Example: !goals progress 5 75 Hit 375 followers today!
        """
        if value < 0 or value > 100:
            await ctx.send(embed=create_error_embed(
                "Invalid Value",
                "Progress value must be between 0 and 100"
            ))
            return

        async with RailsAPIClient() as api:
            user_data = await api.get_user_by_discord_id(str(ctx.author.id))

            if not user_data:
                await ctx.send(embed=create_error_embed("Not Registered", "Register on StreamHub first!"))
                return

            try:
                response = await api.update_goal_progress(goal_id, value, note)
                goal = response.get('goal', {})

                progress = goal.get('progress_percentage', value)
                progress_bar = self._create_progress_bar(progress)

                # Check for milestones
                milestone_message = self._check_milestone(progress)

                embed = create_success_embed(
                    "📊 Progress Updated!",
                    f"**{goal['title']}**\n\n"
                    f"{progress_bar} {progress:.1f}%\n\n"
                )

                if note:
                    embed.add_field(
                        name='💬 Note',
                        value=f"\"{note}\"",
                        inline=False
                    )

                if milestone_message:
                    embed.add_field(
                        name='🎉 Milestone Reached!',
                        value=milestone_message,
                        inline=False
                    )

                # Check if completed
                if goal.get('status') == 'completed':
                    embed.add_field(
                        name='🏆 GOAL COMPLETED!',
                        value="Congratulations! You've achieved your goal!",
                        inline=False
                    )

                    # Award loyalty points
                    try:
                        await api.add_loyalty_points(
                            user_id=user_data['user']['id'],
                            amount=500,
                            description=f"Completed goal: {goal['title']}",
                            transaction_type='earned_goal_completion'
                        )
                        embed.add_field(
                            name='💎 Bonus',
                            value='+500 loyalty points for completing your goal!',
                            inline=False
                        )
                    except:
                        pass

                embed.set_footer(text=f"Goal ID: {goal['id']}")
                await ctx.send(embed=embed)

            except Exception as e:
                logger.error(f"Error updating progress: {e}")
                await ctx.send(embed=create_error_embed("Error", "Failed to update progress"))

    @goals_group.command(name='complete')
    async def complete_goal(self, ctx: commands.Context, goal_id: int):
        """
        Mark a goal as completed
        Usage: !goals complete <goal_id>
        """
        async with RailsAPIClient() as api:
            user_data = await api.get_user_by_discord_id(str(ctx.author.id))

            if not user_data:
                await ctx.send(embed=create_error_embed("Not Registered", "Register on StreamHub first!"))
                return

            try:
                response = await api.complete_goal(goal_id)
                goal = response.get('goal', {})

                embed = create_embed(
                    "🏆 GOAL COMPLETED! 🏆",
                    f"**{goal['title']}**\n\n"
                    f"Congratulations on achieving your goal!\n"
                    f"This accomplishment has been added to your streaming story.",
                    color=discord.Color.gold()
                )

                # Calculate time taken
                if goal.get('started_at'):
                    started = datetime.fromisoformat(goal['started_at'].replace('Z', '+00:00'))
                    completed = datetime.now()
                    days_taken = (completed - started).days

                    embed.add_field(
                        name='⏱️ Time Taken',
                        value=f"{days_taken} days",
                        inline=True
                    )

                # Award loyalty points
                try:
                    await api.add_loyalty_points(
                        user_id=user_data['user']['id'],
                        amount=500,
                        description=f"Completed goal: {goal['title']}",
                        transaction_type='earned_goal_completion'
                    )
                    embed.add_field(
                        name='💎 Reward',
                        value='+500 loyalty points!',
                        inline=True
                    )
                except:
                    pass

                embed.add_field(
                    name='🎯 Ready for More?',
                    value='Use `!goals set` to create your next goal!',
                    inline=False
                )

                embed.set_footer(text="Keep crushing your goals! 🚀")
                await ctx.send(embed=embed)

            except Exception as e:
                logger.error(f"Error completing goal: {e}")
                await ctx.send(embed=create_error_embed("Error", "Failed to complete goal"))

    @goals_group.command(name='pause')
    async def pause_goal(self, ctx: commands.Context, goal_id: int):
        """
        Pause a goal temporarily
        Usage: !goals pause <goal_id>
        """
        async with RailsAPIClient() as api:
            user_data = await api.get_user_by_discord_id(str(ctx.author.id))

            if not user_data:
                await ctx.send(embed=create_error_embed("Not Registered", "Register on StreamHub first!"))
                return

            try:
                response = await api.pause_goal(goal_id)
                goal = response.get('goal', {})

                embed = create_success_embed(
                    "⏸️ Goal Paused",
                    f"**{goal['title']}** has been paused.\n\n"
                    f"You can resume it anytime with `!goals resume {goal_id}`"
                )
                await ctx.send(embed=embed)

            except Exception as e:
                logger.error(f"Error pausing goal: {e}")
                await ctx.send(embed=create_error_embed("Error", "Failed to pause goal"))

    @goals_group.command(name='resume')
    async def resume_goal(self, ctx: commands.Context, goal_id: int):
        """
        Resume a paused goal
        Usage: !goals resume <goal_id>
        """
        async with RailsAPIClient() as api:
            user_data = await api.get_user_by_discord_id(str(ctx.author.id))

            if not user_data:
                await ctx.send(embed=create_error_embed("Not Registered", "Register on StreamHub first!"))
                return

            try:
                response = await api.resume_goal(goal_id)
                goal = response.get('goal', {})

                embed = create_success_embed(
                    "▶️ Goal Resumed",
                    f"**{goal['title']}** is now active again.\n\n"
                    f"Keep pushing towards your goal!"
                )
                await ctx.send(embed=embed)

            except Exception as e:
                logger.error(f"Error resuming goal: {e}")
                await ctx.send(embed=create_error_embed("Error", "Failed to resume goal"))

    @goals_group.command(name='abandon')
    async def abandon_goal(self, ctx: commands.Context, goal_id: int):
        """
        Abandon a goal (no judgment!)
        Usage: !goals abandon <goal_id>
        """
        async with RailsAPIClient() as api:
            user_data = await api.get_user_by_discord_id(str(ctx.author.id))

            if not user_data:
                await ctx.send(embed=create_error_embed("Not Registered", "Register on StreamHub first!"))
                return

            try:
                response = await api.abandon_goal(goal_id)
                goal = response.get('goal', {})

                embed = create_info_embed(
                    "📝 Goal Abandoned",
                    f"**{goal['title']}** has been marked as abandoned.\n\n"
                    f"Sometimes priorities change, and that's okay!\n"
                    f"Ready to set a new goal? Use `!goals set`"
                )
                await ctx.send(embed=embed)

            except Exception as e:
                logger.error(f"Error abandoning goal: {e}")
                await ctx.send(embed=create_error_embed("Error", "Failed to abandon goal"))

    @goals_group.command(name='stats')
    async def goal_stats(self, ctx: commands.Context):
        """View your goal statistics"""
        async with RailsAPIClient() as api:
            user_data = await api.get_user_by_discord_id(str(ctx.author.id))

            if not user_data:
                await ctx.send(embed=create_error_embed("Not Registered", "Register on StreamHub first!"))
                return

            try:
                response = await api.get_goal_stats(user_data['user']['id'])

                embed = create_embed(
                    "📊 Your Goal Statistics",
                    "Track your progress and achievements",
                    color=discord.Color.purple()
                )

                embed.add_field(
                    name='📝 Total Goals',
                    value=str(response.get('total_goals', 0)),
                    inline=True
                )

                embed.add_field(
                    name='🔄 Active Goals',
                    value=str(response.get('active_goals', 0)),
                    inline=True
                )

                embed.add_field(
                    name='✅ Completed Goals',
                    value=str(response.get('completed_goals', 0)),
                    inline=True
                )

                embed.add_field(
                    name='⏸️ Paused Goals',
                    value=str(response.get('paused_goals', 0)),
                    inline=True
                )

                embed.add_field(
                    name='📝 Draft Goals',
                    value=str(response.get('draft_goals', 0)),
                    inline=True
                )

                embed.add_field(
                    name='📈 Completion Rate',
                    value=f"{response.get('completion_rate', 0):.1f}%",
                    inline=True
                )

                # Goals by type
                goals_by_type = response.get('goals_by_type', {})
                if any(goals_by_type.values()):
                    type_text = ""
                    for goal_type, count in goals_by_type.items():
                        if count > 0:
                            type_info = self.goal_types.get(goal_type, {})
                            emoji = type_info.get('emoji', '📝')
                            name = type_info.get('name', goal_type.title())
                            type_text += f"{emoji} {name}: {count}\n"

                    if type_text:
                        embed.add_field(
                            name='📁 Goals by Type',
                            value=type_text,
                            inline=False
                        )

                # Recent completions
                recent_completions = response.get('recent_completions', [])
                if recent_completions:
                    completion_text = ""
                    for goal in recent_completions[:3]:
                        title = goal.get('title', 'Untitled')[:40]
                        completion_text += f"✅ {title}\n"

                    embed.add_field(
                        name='🏆 Recent Completions',
                        value=completion_text,
                        inline=False
                    )

                embed.set_footer(text="Use !goals list to see your active goals")
                await ctx.send(embed=embed)

            except Exception as e:
                logger.error(f"Error getting goal stats: {e}")
                await ctx.send(embed=create_error_embed("Error", "Failed to retrieve statistics"))

    def _create_progress_bar(self, percentage: float, length: int = 10) -> str:
        """Create a visual progress bar"""
        percentage = max(0, min(100, percentage))
        filled = int((percentage / 100) * length)
        return "█" * filled + "░" * (length - filled)

    def _check_milestone(self, progress: float) -> str:
        """Check if a milestone was hit"""
        milestones = [25, 50, 75, 100]
        for milestone in milestones:
            if progress >= milestone and progress < milestone + 5:  # Within 5% of milestone
                if milestone == 25:
                    return "You're 25% of the way there! Keep going! 💪"
                elif milestone == 50:
                    return "Halfway there! You're doing great! 🎉"
                elif milestone == 75:
                    return "75% complete! Almost there! 🚀"
                elif milestone == 100:
                    return "Goal completed! Amazing work! 🏆"
        return None

    def _time_ago(self, timestamp: datetime) -> str:
        """Convert timestamp to human-readable 'time ago' format"""
        now = datetime.now(timestamp.tzinfo)
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

    @commands.Cog.listener()
    async def on_ready(self):
        """Initialize goals system when bot is ready"""
        logger.info("Goals system initialized")


async def setup(bot: commands.Bot):
    """Setup function for cog"""
    await bot.add_cog(Goals(bot))
