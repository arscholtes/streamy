"""
Achievements Commands Cog
Achievement system commands
"""
import discord
from discord.ext import commands
import logging

logger = logging.getLogger(__name__)


class Achievements(commands.Cog):
    """Achievement commands"""

    def __init__(self, bot: commands.Bot):
        self.bot = bot

    @commands.command(name='achievements', aliases=['ach'])
    async def list_achievements(self, ctx: commands.Context):
        """List all available achievements"""
        await ctx.send("⚠️ Achievements system coming soon in Phase 3!")

    @commands.command(name='myachievements', aliases=['myach'])
    async def my_achievements(self, ctx: commands.Context):
        """View your earned achievements"""
        await ctx.send("⚠️ Achievements system coming soon in Phase 3!")


async def setup(bot: commands.Bot):
    """Setup function for cog"""
    await bot.add_cog(Achievements(bot))
