"""
StreamHub Discord Bot
Main bot entry point and setup
"""
import discord
from discord.ext import commands
import logging
import sys
from pathlib import Path

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent))

from config.settings import DISCORD_BOT_TOKEN, COMMAND_PREFIX, LOG_LEVEL, LOG_FILE

# Setup logging
logging.basicConfig(
    level=getattr(logging, LOG_LEVEL),
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(LOG_FILE),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)


class StreamHubBot(commands.Bot):
    """StreamHub Discord Bot"""

    def __init__(self):
        intents = discord.Intents.default()
        intents.message_content = True
        intents.members = True
        intents.presences = True
        intents.voice_states = True

        super().__init__(
            command_prefix=COMMAND_PREFIX,
            intents=intents,
            help_command=None  # Using custom help command in general.py
        )

    async def setup_hook(self):
        """Setup hook called when bot is starting"""
        logger.info("Setting up bot...")

        # Load cogs
        cogs_to_load = [
            'cogs.general',
            'cogs.profile',
            'cogs.points',
            'cogs.achievements',
            'cogs.minigames',
            'cogs.vc_queue',
            'cogs.stream',
            'cogs.moderation',
            'cogs.obs',  # OBS remote control
            'cogs.overlays',  # OBS overlay control - trigger alerts and events
            'cogs.story',  # Chronicle system - help streamers write their story
            'cogs.memory',  # Memory Book - personal journal for streamers
            'cogs.goals',  # Goals & Progress Tracking - define and track streaming objectives
            'cogs.insights'  # Analytics with Context - the "why" behind the numbers
        ]

        for cog in cogs_to_load:
            try:
                await self.load_extension(cog)
                logger.info(f"Loaded cog: {cog}")
            except Exception as e:
                logger.error(f"Failed to load cog {cog}: {e}")

        logger.info("Bot setup complete")

    async def on_ready(self):
        """Called when bot is ready"""
        logger.info(f"Logged in as {self.user} (ID: {self.user.id})")
        logger.info(f"Connected to {len(self.guilds)} guilds")

        # Set bot status
        await self.change_presence(
            activity=discord.Activity(
                type=discord.ActivityType.watching,
                name="StreamHub | !help"
            )
        )

    async def on_command_error(self, ctx: commands.Context, error: Exception):
        """Global error handler"""
        if isinstance(error, commands.CommandNotFound):
            return

        if isinstance(error, commands.MissingRequiredArgument):
            await ctx.send(f"❌ Missing required argument: {error.param.name}")
            return

        if isinstance(error, commands.BadArgument):
            await ctx.send(f"❌ Invalid argument: {error}")
            return

        if isinstance(error, commands.CommandOnCooldown):
            await ctx.send(
                f"⏰ This command is on cooldown. "
                f"Try again in {error.retry_after:.1f}s"
            )
            return

        if isinstance(error, commands.MissingPermissions):
            await ctx.send("❌ You don't have permission to use this command")
            return

        logger.error(f"Command error: {error}", exc_info=error)
        await ctx.send(f"❌ An error occurred: {error}")


def main():
    """Main entry point"""
    if not DISCORD_BOT_TOKEN:
        logger.error("DISCORD_BOT_TOKEN not set in environment")
        sys.exit(1)

    bot = StreamHubBot()

    try:
        bot.run(DISCORD_BOT_TOKEN)
    except KeyboardInterrupt:
        logger.info("Bot shutting down...")
    except Exception as e:
        logger.error(f"Fatal error: {e}", exc_info=e)
        sys.exit(1)


if __name__ == "__main__":
    main()
