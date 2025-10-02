"""
Discord Bot Configuration Settings
Loads environment variables and provides configuration constants
"""
import os
from dotenv import load_dotenv

load_dotenv()

# Discord Settings
DISCORD_BOT_TOKEN = os.getenv('DISCORD_BOT_TOKEN')
DISCORD_GUILD_ID = int(os.getenv('DISCORD_GUILD_ID', 0))
COMMAND_PREFIX = os.getenv('COMMAND_PREFIX', '!')

# Rails API Settings
RAILS_API_URL = os.getenv('RAILS_API_URL', 'http://localhost:3000')
RAILS_API_KEY = os.getenv('RAILS_API_KEY', '')

# Redis Settings
REDIS_HOST = os.getenv('REDIS_HOST', 'localhost')
REDIS_PORT = int(os.getenv('REDIS_PORT', 6379))
REDIS_DB = int(os.getenv('REDIS_DB', 0))

# Loyalty Points Settings
POINTS_PER_MINUTE_WATCHING = int(os.getenv('POINTS_PER_MINUTE_WATCHING', 5))
POINTS_PER_MESSAGE = int(os.getenv('POINTS_PER_MESSAGE', 2))
MIN_MESSAGE_LENGTH = int(os.getenv('MIN_MESSAGE_LENGTH', 10))

# Mini-Game Settings
COINFLIP_HOUSE_EDGE = 0.0  # 0% house edge
ROULETTE_PAYOUTS = {
    'number': 35,      # Single number
    'color': 2,        # Red/Black
    'even_odd': 2,     # Even/Odd
    'dozen': 3,        # First/Second/Third dozen
    'column': 3,       # Column bet
    'half': 2          # 1-18 or 19-36
}
SLOTS_PAYOUTS = {
    '777': 100,        # Jackpot
    'cherries': 10,    # Three cherries
    'bars': 5,         # Three bars
    'any_two': 2       # Any two matching
}

# VC Queue Settings
VC_QUEUE_MAX_SIZE = 100
VC_QUEUE_TIMEOUT_MINUTES = 30
PRIORITY_TIERS = {
    'free': 0,
    'pro': 25,
    'enterprise': 50
}

# Rate Limiting
RATE_LIMIT_COMMANDS_PER_MINUTE = 10
RATE_LIMIT_POINTS_EARN_COOLDOWN = 60  # seconds

# Logging
LOG_LEVEL = os.getenv('LOG_LEVEL', 'INFO')
LOG_FILE = os.getenv('LOG_FILE', 'discord_bot.log')
