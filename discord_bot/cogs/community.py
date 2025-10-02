"""
Community Commands Cog
Giveaways, polls, and community engagement
"""
import discord
from discord.ext import commands
import logging
import random
from datetime import datetime, timedelta
from utils.helpers import create_embed, create_error_embed, create_success_embed, format_duration
from utils.redis_client import redis_client

logger = logging.getLogger(__name__)


class Community(commands.Cog):
    """Community engagement commands"""

    def __init__(self, bot: commands.Bot):
        self.bot = bot
        self.active_giveaways = {}
        self.active_polls = {}

    @commands.command(name='giveaway', aliases=['gstart'])
    @commands.has_permissions(manage_messages=True)
    async def start_giveaway(self, ctx: commands.Context, duration: int, winners: int, *, prize: str):
        """
        Start a giveaway
        Usage: !giveaway <duration_minutes> <winners> <prize>
        Example: !giveaway 60 1 Discord Nitro
        """
        if duration < 1 or duration > 1440:  # Max 24 hours
            await ctx.send(embed=create_error_embed(
                "Invalid Duration",
                "Duration must be between 1 and 1440 minutes (24 hours)."
            ))
            return

        if winners < 1 or winners > 20:
            await ctx.send(embed=create_error_embed(
                "Invalid Winners",
                "Winners must be between 1 and 20."
            ))
            return

        end_time = datetime.utcnow() + timedelta(minutes=duration)

        embed = create_embed(
            "🎉 GIVEAWAY! 🎉",
            f"**Prize:** {prize}\n"
            f"**Winners:** {winners}\n"
            f"**Ends:** <t:{int(end_time.timestamp())}:R>\n\n"
            f"React with 🎉 to enter!",
            color=discord.Color.gold()
        )
        embed.set_footer(text=f"Hosted by {ctx.author.name}")

        giveaway_msg = await ctx.send(embed=embed)
        await giveaway_msg.add_reaction("🎉")

        # Store giveaway data
        self.active_giveaways[giveaway_msg.id] = {
            'prize': prize,
            'winners': winners,
            'end_time': end_time,
            'host': ctx.author.id
        }

        # Store in Redis for persistence
        redis_client.set(
            f"giveaway:{giveaway_msg.id}",
            self.active_giveaways[giveaway_msg.id],
            ttl=duration * 60
        )

    @commands.command(name='gend', aliases=['endgiveaway'])
    @commands.has_permissions(manage_messages=True)
    async def end_giveaway(self, ctx: commands.Context, message_id: int):
        """
        End a giveaway early
        Usage: !gend <message_id>
        """
        try:
            message = await ctx.channel.fetch_message(message_id)
        except:
            await ctx.send(embed=create_error_embed("Error", "Message not found."))
            return

        giveaway_data = self.active_giveaways.get(message_id) or redis_client.get(f"giveaway:{message_id}")

        if not giveaway_data:
            await ctx.send(embed=create_error_embed("Error", "No active giveaway found."))
            return

        # Get reaction users
        reaction = discord.utils.get(message.reactions, emoji="🎉")
        if not reaction or reaction.count < 2:  # Subtract bot reaction
            await ctx.send(embed=create_error_embed(
                "No Entries",
                "Not enough participants for the giveaway."
            ))
            return

        users = [user async for user in reaction.users() if not user.bot]

        if len(users) < giveaway_data['winners']:
            winners = users
        else:
            winners = random.sample(users, giveaway_data['winners'])

        # Announce winners
        winner_mentions = [user.mention for user in winners]

        embed = create_embed(
            "🎉 Giveaway Ended! 🎉",
            f"**Prize:** {giveaway_data['prize']}\n\n"
            f"**{'Winner' if len(winners) == 1 else 'Winners'}:**\n" + '\n'.join(winner_mentions),
            color=discord.Color.gold()
        )

        await ctx.send(embed=embed)

        # Clean up
        if message_id in self.active_giveaways:
            del self.active_giveaways[message_id]
        redis_client.delete(f"giveaway:{message_id}")

    @commands.command(name='poll')
    async def create_poll(self, ctx: commands.Context, duration: int, question: str, *options):
        """
        Create a poll
        Usage: !poll <duration_minutes> "<question>" <option1> <option2> [option3...]
        Example: !poll 30 "Best game?" Valorant "League of Legends" "CS:GO"
        """
        if duration < 1 or duration > 1440:
            await ctx.send(embed=create_error_embed(
                "Invalid Duration",
                "Duration must be between 1 and 1440 minutes."
            ))
            return

        if len(options) < 2:
            await ctx.send(embed=create_error_embed(
                "Not Enough Options",
                "Polls need at least 2 options."
            ))
            return

        if len(options) > 10:
            await ctx.send(embed=create_error_embed(
                "Too Many Options",
                "Maximum 10 options allowed."
            ))
            return

        # Number emojis for reactions
        number_emojis = ["1️⃣", "2️⃣", "3️⃣", "4️⃣", "5️⃣", "6️⃣", "7️⃣", "8️⃣", "9️⃣", "🔟"]

        end_time = datetime.utcnow() + timedelta(minutes=duration)

        # Build poll embed
        description = f"**{question}**\n\n"
        for i, option in enumerate(options[:10]):
            description += f"{number_emojis[i]} {option}\n"

        description += f"\nEnds <t:{int(end_time.timestamp())}:R>"

        embed = create_embed(
            "📊 Poll",
            description,
            color=discord.Color.blue()
        )
        embed.set_footer(text=f"Created by {ctx.author.name}")

        poll_msg = await ctx.send(embed=embed)

        # Add reactions
        for i in range(len(options)):
            await poll_msg.add_reaction(number_emojis[i])

        # Store poll data
        self.active_polls[poll_msg.id] = {
            'question': question,
            'options': list(options),
            'end_time': end_time,
            'creator': ctx.author.id
        }

        redis_client.set(
            f"poll:{poll_msg.id}",
            self.active_polls[poll_msg.id],
            ttl=duration * 60
        )

    @commands.command(name='pollresults', aliases=['presults'])
    async def poll_results(self, ctx: commands.Context, message_id: int):
        """
        View poll results
        Usage: !pollresults <message_id>
        """
        try:
            message = await ctx.channel.fetch_message(message_id)
        except:
            await ctx.send(embed=create_error_embed("Error", "Message not found."))
            return

        poll_data = self.active_polls.get(message_id) or redis_client.get(f"poll:{message_id}")

        if not poll_data:
            await ctx.send(embed=create_error_embed("Error", "No poll data found."))
            return

        # Count votes
        number_emojis = ["1️⃣", "2️⃣", "3️⃣", "4️⃣", "5️⃣", "6️⃣", "7️⃣", "8️⃣", "9️⃣", "🔟"]
        results = []

        total_votes = 0
        for i, option in enumerate(poll_data['options']):
            reaction = discord.utils.get(message.reactions, emoji=number_emojis[i])
            votes = (reaction.count - 1) if reaction else 0  # Subtract bot
            results.append((option, votes))
            total_votes += votes

        # Build results embed
        description = f"**{poll_data['question']}**\n\n"

        if total_votes == 0:
            description += "No votes yet!"
        else:
            for i, (option, votes) in enumerate(results):
                percentage = (votes / total_votes * 100) if total_votes > 0 else 0
                bar_length = int(percentage / 10)
                bar = "█" * bar_length + "░" * (10 - bar_length)

                description += f"{number_emojis[i]} **{option}**\n"
                description += f"{bar} {percentage:.1f}% ({votes} votes)\n\n"

        embed = create_embed(
            "📊 Poll Results",
            description,
            color=discord.Color.blue()
        )
        embed.set_footer(text=f"Total votes: {total_votes}")

        await ctx.send(embed=embed)

    @commands.command(name='trivia')
    @commands.cooldown(1, 300, commands.BucketType.guild)
    async def trivia_game(self, ctx: commands.Context):
        """Start a trivia game"""
        # Sample trivia questions - would come from API/database
        questions = [
            {
                'question': 'What is the capital of France?',
                'options': ['London', 'Paris', 'Berlin', 'Madrid'],
                'answer': 1
            },
            {
                'question': 'Which planet is known as the Red Planet?',
                'options': ['Venus', 'Jupiter', 'Mars', 'Saturn'],
                'answer': 2
            },
            {
                'question': 'Who painted the Mona Lisa?',
                'options': ['Van Gogh', 'Picasso', 'Da Vinci', 'Monet'],
                'answer': 2
            }
        ]

        question_data = random.choice(questions)
        number_emojis = ["1️⃣", "2️⃣", "3️⃣", "4️⃣"]

        description = f"**{question_data['question']}**\n\n"
        for i, option in enumerate(question_data['options']):
            description += f"{number_emojis[i]} {option}\n"

        description += "\nYou have 30 seconds to answer!"

        embed = create_embed(
            "🧠 Trivia Time!",
            description,
            color=discord.Color.purple()
        )

        trivia_msg = await ctx.send(embed=embed)

        # Add reactions
        for i in range(len(question_data['options'])):
            await trivia_msg.add_reaction(number_emojis[i])

        # Wait for answers (simplified - production would use wait_for)
        await ctx.send(f"The correct answer was: **{question_data['options'][question_data['answer']]}**!")


async def setup(bot: commands.Bot):
    """Setup function for cog"""
    await bot.add_cog(Community(bot))
