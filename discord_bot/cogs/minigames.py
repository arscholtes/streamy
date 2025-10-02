"""
Mini-Games Commands Cog
Gambling and game commands with full integration
"""
import discord
from discord.ext import commands
import logging
import random
from utils.api_client import RailsAPIClient
from utils.helpers import (
    create_embed, create_error_embed, create_success_embed,
    format_points
)
from config.settings import COINFLIP_HOUSE_EDGE, ROULETTE_PAYOUTS, SLOTS_PAYOUTS

logger = logging.getLogger(__name__)


class MiniGames(commands.Cog):
    """Mini-game commands"""

    def __init__(self, bot: commands.Bot):
        self.bot = bot
        self.min_bet = 10
        self.max_bet = 10000

    async def validate_bet(self, ctx, amount, user_data, loyalty_data):
        """Validate bet amount and user balance"""
        if amount < self.min_bet:
            await ctx.send(embed=create_error_embed(
                "Bet Too Low",
                f"Minimum bet is {format_points(self.min_bet)} points."
            ))
            return False

        if amount > self.max_bet:
            await ctx.send(embed=create_error_embed(
                "Bet Too High",
                f"Maximum bet is {format_points(self.max_bet)} points."
            ))
            return False

        current_balance = loyalty_data['loyalty_points']['points']
        if amount > current_balance:
            await ctx.send(embed=create_error_embed(
                "Insufficient Funds",
                f"You only have {format_points(current_balance)} points.\n"
                f"You need {format_points(amount - current_balance)} more to make this bet."
            ))
            return False

        return True

    async def record_game(self, api, user_id, game_type, bet_amount, result, winnings, metadata=None):
        """Record game session in database"""
        try:
            await api.record_game_session(
                user_id,
                game_type,
                bet_amount,
                result,
                winnings,
                metadata or {}
            )
        except Exception as e:
            logger.error(f"Failed to record game session: {e}")

    @commands.command(name='coinflip', aliases=['cf', 'flip'])
    @commands.cooldown(1, 3, commands.BucketType.user)
    async def coinflip(self, ctx: commands.Context, amount: int, choice: str):
        """
        Flip a coin - bet on heads or tails
        Usage: !coinflip <amount> <heads/tails>
        Example: !coinflip 100 heads
        """
        # Validate choice
        choice = choice.lower()
        if choice not in ['heads', 'tails', 'h', 't']:
            await ctx.send(embed=create_error_embed(
                "Invalid Choice",
                "Choose either `heads` or `tails` (or `h`/`t`)"
            ))
            return

        # Normalize choice
        choice = 'heads' if choice in ['heads', 'h'] else 'tails'

        async with RailsAPIClient() as api:
            user_data = await api.get_user_by_discord_id(str(ctx.author.id))
            if not user_data:
                await ctx.send(embed=create_error_embed("Not Registered", "Register your account first!"))
                return

            loyalty_data = await api.get_loyalty_points(user_data['user']['id'])
            if not await self.validate_bet(ctx, amount, user_data, loyalty_data):
                return

            # Flip the coin
            result = random.choice(['heads', 'tails'])
            won = result == choice

            # Calculate winnings
            if won:
                winnings = amount * 2  # 2x payout (no house edge)
                profit = amount
                result_text = 'win'
            else:
                winnings = 0
                profit = -amount
                result_text = 'loss'

            # Record game
            await self.record_game(
                api,
                user_data['user']['id'],
                'coinflip',
                amount,
                result_text,
                winnings,
                {'choice': choice, 'result': result}
            )

            # Create result embed
            coin_emoji = '🪙' if result == 'heads' else '🥈'

            embed = create_embed(
                f"{coin_emoji} Coinflip Result",
                color=discord.Color.green() if won else discord.Color.red()
            )

            embed.add_field(name='You Chose', value=choice.capitalize(), inline=True)
            embed.add_field(name='Result', value=f"{coin_emoji} **{result.capitalize()}**", inline=True)
            embed.add_field(name='Outcome', value='✅ **WIN!**' if won else '❌ **LOSS**', inline=True)
            embed.add_field(name='Bet', value=format_points(amount), inline=True)
            embed.add_field(name='Profit/Loss', value=f"{'**+' if profit > 0 else ''}{format_points(profit)}**", inline=True)

            # Get new balance
            new_loyalty = await api.get_loyalty_points(user_data['user']['id'])
            embed.add_field(name='New Balance', value=format_points(new_loyalty['loyalty_points']['points']), inline=True)

            await ctx.send(embed=embed)

    @commands.command(name='slots', aliases=['slot', 'spin'])
    @commands.cooldown(1, 5, commands.BucketType.user)
    async def slots(self, ctx: commands.Context, amount: int):
        """
        Play the slot machine
        Usage: !slots <amount>
        Example: !slots 100

        Payouts:
        🎰 777: 100x
        🍒🍒🍒: 10x
        💎💎💎: 25x
        ⭐⭐⭐: 15x
        Any 2 matching: 2x
        """
        async with RailsAPIClient() as api:
            user_data = await api.get_user_by_discord_id(str(ctx.author.id))
            if not user_data:
                await ctx.send(embed=create_error_embed("Not Registered", "Register your account first!"))
                return

            loyalty_data = await api.get_loyalty_points(user_data['user']['id'])
            if not await self.validate_bet(ctx, amount, user_data, loyalty_data):
                return

            # Slot symbols with weights
            symbols = ['🍒', '🍋', '🍊', '🔔', '💎', '⭐', '7️⃣']
            weights = [30, 25, 20, 15, 5, 3, 2]  # Cherries most common, 7 rarest

            # Spin the slots
            reel1 = random.choices(symbols, weights=weights)[0]
            reel2 = random.choices(symbols, weights=weights)[0]
            reel3 = random.choices(symbols, weights=weights)[0]

            # Calculate winnings
            winnings = 0
            result_text = 'loss'
            win_desc = None

            if reel1 == reel2 == reel3:
                # Three of a kind
                result_text = 'win'
                if reel1 == '7️⃣':
                    winnings = amount * 100  # Jackpot!
                    win_desc = '🎰 **JACKPOT!!!** 🎰'
                elif reel1 == '💎':
                    winnings = amount * 25
                    win_desc = '💎 **TRIPLE DIAMONDS!** 💎'
                elif reel1 == '⭐':
                    winnings = amount * 15
                    win_desc = '⭐ **TRIPLE STARS!** ⭐'
                elif reel1 == '🍒':
                    winnings = amount * 10
                    win_desc = '🍒 **TRIPLE CHERRIES!** 🍒'
                else:
                    winnings = amount * 5
                    win_desc = f'{reel1} **TRIPLE {reel1}!** {reel1}'
            elif reel1 == reel2 or reel2 == reel3 or reel1 == reel3:
                # Two matching
                result_text = 'win'
                winnings = amount * 2
                win_desc = '✨ **Two Match!** ✨'

            profit = winnings - amount

            # Record game
            await self.record_game(
                api,
                user_data['user']['id'],
                'slots',
                amount,
                result_text,
                winnings,
                {'reels': [reel1, reel2, reel3]}
            )

            # Create animated result
            loading_msg = await ctx.send("🎰 **Spinning...**")
            await loading_msg.edit(content=f"🎰 [{reel1}] [❓] [❓]")
            await loading_msg.edit(content=f"🎰 [{reel1}] [{reel2}] [❓]")

            # Final result
            embed = create_embed(
                "🎰 Slot Machine",
                color=discord.Color.gold() if profit > 0 else discord.Color.red()
            )

            embed.add_field(
                name='Result',
                value=f"**[ {reel1} | {reel2} | {reel3} ]**",
                inline=False
            )

            if win_desc:
                embed.add_field(name='Outcome', value=win_desc, inline=False)

            embed.add_field(name='Bet', value=format_points(amount), inline=True)
            embed.add_field(
                name='Profit/Loss',
                value=f"{'**+' if profit > 0 else ''}{format_points(profit)}**",
                inline=True
            )

            new_loyalty = await api.get_loyalty_points(user_data['user']['id'])
            embed.add_field(
                name='New Balance',
                value=format_points(new_loyalty['loyalty_points']['points']),
                inline=True
            )

            await loading_msg.edit(content=None, embed=embed)

    @commands.command(name='roulette', aliases=['roul'])
    @commands.cooldown(1, 5, commands.BucketType.user)
    async def roulette(self, ctx: commands.Context, amount: int, *, bet: str):
        """
        Play roulette with various bet types
        Usage: !roulette <amount> <bet>

        Bet types:
        - Numbers: 0-36 (35x payout)
        - Colors: red, black (2x)
        - Even/Odd: even, odd (2x)
        - Halves: low (1-18), high (19-36) (2x)
        - Dozens: 1st12, 2nd12, 3rd12 (3x)

        Examples:
        !roulette 100 red
        !roulette 50 17
        !roulette 200 odd
        """
        async with RailsAPIClient() as api:
            user_data = await api.get_user_by_discord_id(str(ctx.author.id))
            if not user_data:
                await ctx.send(embed=create_error_embed("Not Registered", "Register your account first!"))
                return

            loyalty_data = await api.get_loyalty_points(user_data['user']['id'])
            if not await self.validate_bet(ctx, amount, user_data, loyalty_data):
                return

            # Parse bet
            bet = bet.lower().strip()

            # Define roulette numbers
            red_numbers = [1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36]
            black_numbers = [2, 4, 6, 8, 10, 11, 13, 15, 17, 20, 22, 24, 26, 28, 29, 31, 33, 35]

            # Spin the wheel
            result_number = random.randint(0, 36)
            result_color = 'green' if result_number == 0 else ('red' if result_number in red_numbers else 'black')

            # Determine win
            won = False
            payout_multiplier = 0
            bet_description = bet

            try:
                # Number bet
                if bet.isdigit():
                    bet_num = int(bet)
                    if 0 <= bet_num <= 36:
                        if result_number == bet_num:
                            won = True
                            payout_multiplier = 35
                        bet_description = f"Number {bet_num}"
                    else:
                        await ctx.send(embed=create_error_embed(
                            "Invalid Bet",
                            "Number must be between 0-36"
                        ))
                        return
                # Color bets
                elif bet in ['red', 'black']:
                    if result_color == bet:
                        won = True
                        payout_multiplier = 2
                    bet_description = bet.capitalize()
                # Even/Odd
                elif bet in ['even', 'odd']:
                    if result_number != 0:
                        is_even = result_number % 2 == 0
                        if (bet == 'even' and is_even) or (bet == 'odd' and not is_even):
                            won = True
                            payout_multiplier = 2
                    bet_description = bet.capitalize()
                # Low/High
                elif bet in ['low', 'high', '1-18', '19-36']:
                    if bet in ['low', '1-18']:
                        if 1 <= result_number <= 18:
                            won = True
                            payout_multiplier = 2
                        bet_description = "Low (1-18)"
                    else:
                        if 19 <= result_number <= 36:
                            won = True
                            payout_multiplier = 2
                        bet_description = "High (19-36)"
                # Dozens
                elif bet in ['1st12', '2nd12', '3rd12', 'first', 'second', 'third']:
                    if bet in ['1st12', 'first']:
                        if 1 <= result_number <= 12:
                            won = True
                            payout_multiplier = 3
                        bet_description = "1st Dozen (1-12)"
                    elif bet in ['2nd12', 'second']:
                        if 13 <= result_number <= 24:
                            won = True
                            payout_multiplier = 3
                        bet_description = "2nd Dozen (13-24)"
                    else:
                        if 25 <= result_number <= 36:
                            won = True
                            payout_multiplier = 3
                        bet_description = "3rd Dozen (25-36)"
                else:
                    await ctx.send(embed=create_error_embed(
                        "Invalid Bet",
                        "Valid bets: number (0-36), red, black, even, odd, low, high, 1st12, 2nd12, 3rd12"
                    ))
                    return

            except ValueError:
                await ctx.send(embed=create_error_embed(
                    "Invalid Bet",
                    "Please check your bet format"
                ))
                return

            # Calculate winnings
            if won:
                winnings = amount * (payout_multiplier + 1)  # Include original bet
                profit = amount * payout_multiplier
                result_text = 'win'
            else:
                winnings = 0
                profit = -amount
                result_text = 'loss'

            # Record game
            await self.record_game(
                api,
                user_data['user']['id'],
                'roulette',
                amount,
                result_text,
                winnings,
                {'bet': bet_description, 'result_number': result_number, 'result_color': result_color}
            )

            # Roulette ball animation
            loading_msg = await ctx.send("🎡 **Spinning the roulette wheel...**")

            # Color emoji
            color_emoji = '🟢' if result_color == 'green' else ('🔴' if result_color == 'red' else '⚫')

            # Create result embed
            embed = create_embed(
                "🎡 Roulette",
                color=discord.Color.green() if won else discord.Color.red()
            )

            embed.add_field(
                name='Result',
                value=f"{color_emoji} **{result_number}** ({result_color.upper()})",
                inline=False
            )
            embed.add_field(name='Your Bet', value=bet_description, inline=True)
            embed.add_field(name='Outcome', value='✅ **WIN!**' if won else '❌ **LOSS**', inline=True)

            if won:
                embed.add_field(name='Multiplier', value=f'{payout_multiplier}x', inline=True)

            embed.add_field(name='Bet Amount', value=format_points(amount), inline=True)
            embed.add_field(
                name='Profit/Loss',
                value=f"{'**+' if profit > 0 else ''}{format_points(profit)}**",
                inline=True
            )

            new_loyalty = await api.get_loyalty_points(user_data['user']['id'])
            embed.add_field(
                name='New Balance',
                value=format_points(new_loyalty['loyalty_points']['points']),
                inline=True
            )

            await loading_msg.edit(content=None, embed=embed)

    @commands.command(name='gamestats', aliases=['gstats'])
    async def game_stats(self, ctx: commands.Context, game: str = None):
        """
        View your gambling statistics
        Usage: !gamestats [game]
        Games: coinflip, slots, roulette, all
        """
        async with RailsAPIClient() as api:
            user_data = await api.get_user_by_discord_id(str(ctx.author.id))
            if not user_data:
                await ctx.send(embed=create_error_embed("Not Registered", "Register your account first!"))
                return

            try:
                game_type = game.lower() if game else None
                if game_type and game_type not in ['coinflip', 'slots', 'roulette', 'all']:
                    game_type = None

                stats = await api.get_game_stats(user_data['user']['id'], game_type)

                game_name = game_type.capitalize() if game_type and game_type != 'all' else 'All Games'

                embed = create_embed(
                    f"🎲 {game_name} Statistics",
                    f"{ctx.author.mention}'s gambling stats",
                    color=discord.Color.gold()
                )

                stat_data = stats['stats']

                embed.add_field(
                    name='📊 Games Played',
                    value=str(stat_data['total_games']),
                    inline=True
                )
                embed.add_field(
                    name='✅ Wins',
                    value=str(stat_data['total_won']),
                    inline=True
                )
                embed.add_field(
                    name='❌ Losses',
                    value=str(stat_data['total_lost']),
                    inline=True
                )
                embed.add_field(
                    name='📈 Win Rate',
                    value=f"{stat_data['win_rate']:.1f}%",
                    inline=True
                )
                embed.add_field(
                    name='💰 Total Wagered',
                    value=format_points(stat_data['total_wagered']),
                    inline=True
                )
                embed.add_field(
                    name='💎 Net Profit',
                    value=format_points(stat_data['net_profit']),
                    inline=True
                )

                await ctx.send(embed=embed)

            except Exception as e:
                logger.error(f"Error fetching game stats: {e}")
                await ctx.send(embed=create_error_embed(
                    "Error",
                    "Failed to fetch game statistics."
                ))


async def setup(bot: commands.Bot):
    """Setup function for cog"""
    await bot.add_cog(MiniGames(bot))
