# StreamHub Discord Bot

Advanced Discord bot for the StreamHub streaming platform with 100+ commands, loyalty points system, achievements, mini-games, and VC queue management.

## Features

- **Loyalty Points System** - Earn and spend points through various activities
- **Achievements** - Unlock achievements and earn bonus points
- **Mini-Games** - Coinflip, slots, roulette, trivia, and duels
- **VC Queue** - Priority-based voice chat queue system
- **Stream Integration** - Real-time stream notifications and stats
- **Moderation Tools** - Comprehensive admin commands

## Prerequisites

- Python 3.10+
- Redis server
- Rails API running (localhost:3000 by default)
- Discord bot token

## Installation

1. Install Python dependencies:
```bash
cd discord_bot
pip install -r requirements.txt
```

2. Set up Redis:
```bash
# macOS
brew install redis
brew services start redis

# Ubuntu/Debian
sudo apt-get install redis-server
sudo systemctl start redis
```

3. Configure environment variables:
```bash
cp .env.example .env
# Edit .env with your configuration
```

Required environment variables:
- `DISCORD_BOT_TOKEN` - Your Discord bot token
- `DISCORD_GUILD_ID` - Your Discord server ID
- `RAILS_API_URL` - Rails API URL (default: http://localhost:3000)
- `RAILS_API_KEY` - API key for Rails authentication
- `REDIS_HOST` - Redis host (default: localhost)
- `REDIS_PORT` - Redis port (default: 6379)

4. Set up Rails API key:
```bash
# In Rails project root
rails console
> ENV['DISCORD_BOT_API_KEY'] = SecureRandom.hex(32)
# Copy this key to discord_bot/.env as RAILS_API_KEY
```

## Running the Bot

```bash
cd discord_bot
python bot.py
```

## Project Structure

```
discord_bot/
├── bot.py                  # Main bot entry point
├── config/
│   └── settings.py        # Configuration and settings
├── cogs/                  # Command modules
│   ├── general.py         # General commands (!help, !ping, !info)
│   ├── points.py          # Points system commands
│   ├── achievements.py    # Achievement commands
│   ├── minigames.py       # Game commands
│   ├── vc_queue.py        # VC queue commands
│   ├── stream.py          # Stream integration commands
│   └── moderation.py      # Moderation commands
└── utils/
    ├── api_client.py      # Rails API client
    ├── redis_client.py    # Redis caching client
    └── helpers.py         # Helper utilities
```

## Commands

### General Commands
- `!ping` - Check bot latency
- `!info` - Show bot information
- `!help [command]` - Get help
- `!stats` - View bot statistics

### Points Commands (Phase 3)
- `!points [user]` - Check points balance
- `!level [user]` - Check level
- `!leaderboard` - View top users

### Achievement Commands (Phase 3)
- `!achievements` - List all achievements
- `!myachievements` - View your achievements

### Mini-Game Commands (Phase 5)
- `!coinflip <amount> <heads|tails>` - Flip a coin
- `!slots <amount>` - Play slots
- `!roulette <amount> <bet>` - Play roulette

### VC Queue Commands (Phase 4)
- `!join` - Join VC queue
- `!leave` - Leave VC queue
- `!queue` - View current queue

### Stream Commands (Phase 6)
- `!stream` - Get stream info
- `!notify` - Toggle notifications

### Moderation Commands (Phase 9)
- `!warn <user> <reason>` - Warn user
- `!mute <user> <duration> [reason]` - Mute user
- `!purge <amount>` - Delete messages

## API Integration

The bot communicates with the Rails API for all data persistence. API endpoints:

- `GET /api/v1/users/discord/:discord_id` - Get user by Discord ID
- `POST /api/v1/users` - Create new user
- `GET /api/v1/users/:user_id/loyalty_points` - Get loyalty points
- `POST /api/v1/users/:user_id/loyalty_points/add` - Add points
- `POST /api/v1/users/:user_id/loyalty_points/spend` - Spend points
- `GET /api/v1/achievements` - List achievements
- `POST /api/v1/vc_queue/join` - Join VC queue
- `POST /api/v1/mini_games/record` - Record game session

## Development Phases

✅ **Phase 1: Core Infrastructure** (COMPLETE)
- Bot setup with discord.py
- Cog system architecture
- Rails API integration
- Redis caching
- Database models
- Rate limiting

🔄 **Phase 2: Basic Commands** (IN PROGRESS)
- General commands
- Help system
- Error handling

⏳ **Phase 3: Loyalty Points System**
- Points earning/spending
- Level progression
- Leaderboard

⏳ **Phase 4: VC Queue System**
- Priority queue
- Auto-management

⏳ **Phase 5: Mini-Games**
- Coinflip, slots, roulette
- Statistics tracking

⏳ **Phase 6: Stream Integration**
- Live notifications
- Stream stats

⏳ **Phase 7: Content Features**
- Clips, highlights
- VOD management

⏳ **Phase 8: Community Features**
- Giveaways, polls
- Custom commands

⏳ **Phase 9: Moderation**
- Warning system
- Auto-moderation

⏳ **Phase 10: Polish & Testing**
- Bug fixes
- Performance optimization
- Full test coverage

## Logging

Logs are written to `discord_bot.log` and console. Configure log level in `.env`:
```
LOG_LEVEL=INFO  # DEBUG, INFO, WARNING, ERROR, CRITICAL
```

## Troubleshooting

**Bot not starting:**
- Check `DISCORD_BOT_TOKEN` is set correctly
- Ensure Rails API is running
- Verify Redis is running

**API errors:**
- Verify `RAILS_API_KEY` matches in both .env and Rails
- Check Rails server is accessible
- Review Rails logs for errors

**Redis connection errors:**
- Ensure Redis server is running
- Check `REDIS_HOST` and `REDIS_PORT` settings
- Test Redis connection: `redis-cli ping`

## Contributing

This bot is part of the StreamHub project. Follow the main project's contribution guidelines.

## License

© 2025 StreamHub. All rights reserved.
