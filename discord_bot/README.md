# StreamHub Discord Bot

**"Help streamers write their legendary story"**

A story-first Discord bot companion for the StreamHub streaming platform. Unlike traditional bots that focus on transactions, StreamHub's bot helps streamers document their journey, build their brand, manage their business, and create meaningful connections with their community.

## 🎯 Mission

StreamHub Discord Bot is designed to help streamers **write their streaming story** by providing:
- 📖 **Chronicle tools** to document their journey
- 💼 **Business management** tools to run their stream professionally
- 🌟 **Community building** features to create loyal audiences
- 📊 **Contextual analytics** to understand what's working (and why)
- 🎨 **Brand development** tools to stand out

**The goal:** Make streamers want to stay on StreamHub because we help them succeed.

---

## 🌟 Core Philosophy

Every interaction should:
1. **Tell their story** - Frame progress as narrative chapters
2. **Provide business value** - Professional tools, not just entertainment
3. **Build emotional attachment** - Create meaning, not just metrics
4. **Empower growth** - Actionable insights, not vanity numbers
5. **Celebrate the journey** - Recognize milestones and progress

---

## 📚 Feature Overview

### ✅ Phase 1: Story Foundation (IMPLEMENTED)

#### 1. Chronicle System (`!story`)
**The 8 Chapters of Streaming**
- Tracks streaming journey through narrative chapters (The Beginning → Streaming Legend)
- Auto-documents milestones and achievements
- Visual timeline of progress
- Story-based framing makes numbers meaningful

**Commands:**
- `!story` - View current chapter and progress
- `!story timeline` - See complete journey through all chapters
- `!story milestone <description>` - Log special moments
- `!story chapter [number]` - View chapter details

**Chapters:**
1. 🌱 The Beginning
2. 🎤 Finding Your Voice
3. 📈 Building Momentum
4. ⚡ The Breakthrough
5. 🏆 Established Creator
6. ⭐ Rising Star
7. 👑 Content King/Queen
8. 🌟 Streaming Legend

#### 2. Memory Book (`!memory`)
**Personal journal for streamers**
- Private journaling system to document thoughts and feelings
- Mood detection and tracking
- Searchable memory archive
- Statistics and insights

**Commands:**
- `!memory` or `!journal` - View recent entries
- `!memory save <content>` - Save a journal entry
- `!memory list [page]` - Browse all memories
- `!memory search <keyword>` - Find specific memories
- `!memory stats` - View journaling statistics
- `!memory delete <entry>` - Delete an entry

**Features:**
- Auto-detects mood (😊 😔 🤔 📝)
- Word count tracking
- Milestone celebrations (1st, 10th, 50th entry)
- Private and secure

---

### 🔄 Phase 2: Business Tools (IN PROGRESS)

#### 3. Goals & Progress Tracking (`!goals`)
**Define and track streaming objectives**
- Set SMART goals with deadlines
- Track progress with actionable steps
- Celebrate when goals are achieved
- Get unstuck with AI suggestions

**Planned Commands:**
- `!goals set <description>` - Set a new goal
- `!goals list` - View all goals
- `!goals progress <goal>` - Update goal progress
- `!goals complete <goal>` - Mark goal as complete
- `!goals suggest` - Get goal ideas based on your journey

#### 4. Business Dashboard (`!business`)
**Professional stream management**
- Revenue tracking across all sources
- Expense management for taxes
- Sponsor contract reminders
- ROI analytics per content type
- Financial reporting

**Planned Commands:**
- `!business dashboard` - View business overview
- `!business revenue add` - Log income
- `!business expense add` - Log expense
- `!business sponsors` - Manage sponsor contracts
- `!business report <period>` - Generate financial report

#### 5. Analytics with Context (`!insights`)
**The "why" behind the numbers**
- Explains trends in plain language
- Compares to your own past performance
- Provides actionable recommendations
- Tracks growth velocity

**Planned Commands:**
- `!insights` - Get latest insights
- `!insights growth` - Growth trends
- `!insights content` - Content performance
- `!insights audience` - Audience behavior
- `!insights compare` - Compare periods

---

### ⏳ Phase 3: Community Features (PLANNED)

#### 6. Community Stories (`!community stories`)
**Viewer testimonials and impact**
- Viewers share how streamer impacted them
- "How I found your channel" collection
- Anniversary celebrations
- Member spotlights

#### 7. Inner Circle System (`!circle`)
**Tiered community structure**
- Public → Community → VIP → Inner Circle
- Each tier with unique perks
- Progression system for viewers
- Recognition and rewards

#### 8. Collaborative Milestones
**Shared achievements**
- Track community-wide accomplishments
- "Together we've..." statistics
- Legacy preservation

---

### ⏳ Phase 4: Advanced Features (PLANNED)

#### 9. Content Strategy Tools
- Idea generator based on performance
- Stream planner with storytelling structure
- Series management
- Collaboration matcher

#### 10. Burnout Prevention
- Energy level monitoring
- Rest recommendations
- Stress signal detection
- Self-care reminders

#### 11. The Retrospective (`!yearreview`)
**THE KILLER FEATURE**
- Annual (or on-demand) journey recap
- Auto-generates cinematic montage
- Growth narrative with emotion
- Community testimonials
- Shareable social content
- Video + written formats

**Why it matters:** Creates emotional attachment and platform loyalty.

---

## 🏗️ Project Structure

```
discord_bot/
├── bot.py                      # Main bot entry point
├── config/
│   └── settings.py            # Configuration and settings
├── cogs/                      # Command modules (organized by feature)
│   ├── story.py              # ✅ Chronicle System
│   ├── memory.py             # ✅ Memory Book
│   ├── goals.py              # 🔄 Goals & Progress (coming soon)
│   ├── business.py           # ⏳ Business Dashboard (planned)
│   ├── insights.py           # ⏳ Analytics with Context (planned)
│   ├── community_stories.py  # ⏳ Community Stories (planned)
│   ├── inner_circle.py       # ⏳ Inner Circle System (planned)
│   ├── retrospective.py      # ⏳ Year in Review (planned)
│   │
│   ├── general.py            # General commands
│   ├── profile.py            # User profiles
│   ├── points.py             # Loyalty points
│   ├── achievements.py       # Achievement system
│   ├── minigames.py          # Mini-games (coinflip, slots, roulette)
│   ├── vc_queue.py           # VC queue management
│   ├── stream.py             # Stream integration
│   ├── content.py            # Clips, VODs, highlights
│   ├── community.py          # Giveaways, polls
│   ├── moderation.py         # Moderation tools
│   └── obs.py                # OBS remote control
└── utils/
    ├── api_client.py         # Rails API client
    ├── redis_client.py       # Redis caching
    └── helpers.py            # Helper utilities
```

---

## 📋 Installation

### Prerequisites
- Python 3.10+ (tested on 3.13)
- Redis server
- Rails API running (localhost:3000 by default)
- Discord bot token from [Discord Developer Portal](https://discord.com/developers/applications)

### Step 1: Install Dependencies

```bash
cd discord_bot

# Recommended: Use virtual environment
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install packages
pip install -r requirements.txt
```

### Step 2: Set Up Redis

```bash
# macOS
brew install redis
brew services start redis

# Ubuntu/Debian
sudo apt-get install redis-server
sudo systemctl start redis

# Verify Redis is running
redis-cli ping  # Should return "PONG"
```

### Step 3: Configure Environment

```bash
cp .env.example .env
# Edit .env with your configuration
```

**Required environment variables:**

```env
# Discord Configuration
DISCORD_BOT_TOKEN=your_bot_token_here
DISCORD_GUILD_ID=your_server_id

# Bot Settings
COMMAND_PREFIX=!

# Rails API Settings
RAILS_API_URL=http://localhost:3000
RAILS_API_KEY=your_api_key_here

# Redis Settings
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_DB=0

# Logging
LOG_LEVEL=INFO
LOG_FILE=discord_bot.log
```

### Step 4: Get Discord Bot Token

1. Go to [Discord Developer Portal](https://discord.com/developers/applications)
2. Create a new application (or select existing)
3. Go to **Bot** section
4. Click **Reset Token** and copy the token
5. Paste into `.env` as `DISCORD_BOT_TOKEN`

**Important:** The token looks like: `MTIzNDU2Nzg5.Abcdef.XyZ123-aBcDeF_gHiJkL` (with two dots)

### Step 5: Generate Rails API Key

```bash
# In Rails project root
rails console
> SecureRandom.hex(32)
# Copy output to discord_bot/.env as RAILS_API_KEY
```

### Step 6: Run the Bot

```bash
cd discord_bot
source venv/bin/activate
python bot.py
```

You should see:
```
INFO - Loaded cog: cogs.story
INFO - Loaded cog: cogs.memory
INFO - Bot setup complete
INFO - Logged in as StreamHub Bot
```

---

## 🎮 Command Reference

### Story & Chronicle Commands

```bash
# View your streaming story
!story

# See complete timeline
!story timeline

# Log a special moment
!story milestone Hit 100 viewers for the first time!

# View chapter details
!story chapter 3
```

### Memory Book Commands

```bash
# View recent memories
!memory

# Save a journal entry
!memory save Today was incredible! Finally hit my follower goal

# Search memories
!memory search "first stream"

# View statistics
!memory stats

# List all entries
!memory list
!memory list 2  # Page 2
```

### Loyalty Points (Existing)

```bash
!points [user]       # Check points
!level [user]        # Check level
!leaderboard         # Top users
!daily               # Daily bonus
```

### Mini-Games (Existing)

```bash
!coinflip 100 heads        # Flip a coin
!slots 50                  # Play slots
!roulette 200 red          # Play roulette
!gamestats                 # View stats
```

### VC Queue (Existing)

```bash
!join         # Join queue
!leave        # Leave queue
!queue        # View queue
!position     # Your position
```

### Stream Integration (Existing)

```bash
!stream [user]       # Stream info
!notify              # Toggle notifications
!golive              # Announce going live
!endstream           # Mark offline
```

### OBS Control (Existing)

```bash
!obs connect [host] [port] [password]
!obs status
!obs scene <name>
!obs sources
# See OBS_REMOTE_CONTROL.md for full documentation
```

---

## 🔌 API Integration

The bot communicates with Rails API for all persistence:

### User Endpoints
- `GET /api/v1/users/discord/:discord_id` - Get user
- `POST /api/v1/users` - Create user
- `GET /api/v1/users/:user_id/loyalty_points` - Get points
- `POST /api/v1/users/:user_id/loyalty_points/add` - Add points

### Story Endpoints (To be implemented in Rails)
- `GET /api/v1/users/:user_id/story` - Get story progress
- `POST /api/v1/users/:user_id/story/milestone` - Log milestone
- `GET /api/v1/users/:user_id/memories` - Get memories (with pagination)
- `POST /api/v1/users/:user_id/memories` - Save memory

### Goals Endpoints (Planned)
- `GET /api/v1/users/:user_id/goals` - List goals
- `POST /api/v1/users/:user_id/goals` - Create goal
- `PATCH /api/v1/users/:user_id/goals/:goal_id` - Update goal

### Analytics Endpoints (Planned)
- `GET /api/v1/users/:user_id/insights` - Get insights
- `GET /api/v1/users/:user_id/analytics` - Growth analytics

---

## 🛠️ Development

### Adding New Features

1. **Create a new cog** in `cogs/` directory
2. **Follow the pattern:**

```python
"""
Feature Name Commands Cog
Description of what this cog does
"""
import discord
from discord.ext import commands
import logging
from utils.api_client import RailsAPIClient
from utils.helpers import create_embed, create_error_embed

logger = logging.getLogger(__name__)

class FeatureName(commands.Cog):
    """Feature description"""

    def __init__(self, bot: commands.Bot):
        self.bot = bot

    @commands.command(name='yourcommand')
    async def your_command(self, ctx: commands.Context):
        """Command description"""
        # Implementation here
        pass

async def setup(bot: commands.Bot):
    """Setup function for cog"""
    await bot.add_cog(FeatureName(bot))
```

3. **Register the cog** in `bot.py`:

```python
cogs_to_load = [
    # ... existing cogs
    'cogs.your_feature'
]
```

4. **Test the cog:**

```bash
# Import test
python -c "from cogs import your_feature; print('✅ Import successful')"

# Run bot
python bot.py
```

### Code Style

- Use **async/await** for all I/O operations
- **Type hints** for function parameters
- **Docstrings** for all commands
- **Logging** for important events
- **Error handling** with user-friendly messages

### Testing

```bash
# Check bot can start
python bot.py

# Test specific command
# Use Discord client to run: !yourcommand
```

---

## 📊 Success Metrics

### For Streamers (Platform Retention)
- Days active on platform (30/90 day retention)
- Goal completion rate
- Business dashboard usage
- Journal entry frequency

### For Community (Network Effects)
- Viewer progression through tiers
- Story submission rates
- Cross-channel interactions
- Community engagement scores

### For Platform (Lock-in)
- Emotional attachment (sentiment analysis)
- Feature stickiness (DAU per feature)
- Retrospective generation rate
- NPS / advocacy

---

## 🐛 Troubleshooting

### Bot Won't Start

**Error: "LoginFailure: Improper token has been passed"**
- Token is wrong format or invalid
- Get token from Discord Developer Portal → Bot → Reset Token
- Token should have two dots (`.`) separating three parts

**Error: "Connection refused (Redis)"**
- Redis not running: `brew services start redis` (macOS)
- Check Redis: `redis-cli ping` should return `PONG`

**Error: "Cannot connect to Rails API"**
- Rails server not running: `rails s` in Rails project
- Check `RAILS_API_URL` in `.env`
- Verify API key matches Rails config

### Commands Not Working

**"Not Registered" error**
- User needs to register on StreamHub website first
- Bot requires Rails API integration

**Commands not responding**
- Check bot has proper permissions in Discord
- Verify command prefix (`!` by default)
- Check bot logs in `discord_bot.log`

### Python Version Issues

**"audioop module not found" (Python 3.13)**
- Already fixed with discord.py 2.6.3+
- If you see this: `pip install --upgrade discord.py`

---

## 📖 Additional Documentation

- [OBS Remote Control Guide](./OBS_REMOTE_CONTROL.md) - Full OBS integration docs
- [API Documentation](../docs/API.md) - Rails API reference (TODO)
- [Contributing Guide](../CONTRIBUTING.md) - How to contribute (TODO)

---

## 🗺️ Roadmap

### Q1 2025 (Current)
- ✅ Chronicle System
- ✅ Memory Book
- 🔄 Goals & Progress Tracking
- ⏳ Business Dashboard

### Q2 2025
- Analytics with Context
- Community Stories
- Inner Circle System
- Content Strategy Tools

### Q3 2025
- Burnout Prevention
- Advanced Collaboration Tools
- Enhanced Profile System
- Mobile App Integration

### Q4 2025
- The Retrospective (Year in Review)
- Legacy Builder
- Multi-platform Integration
- Enterprise Features

---

## 💡 Design Principles

1. **Story-First**: Every feature tells part of their journey
2. **Business Value**: Professional tools, not just games
3. **Emotional Resonance**: Build attachment through meaning
4. **Actionable Insights**: Data that leads to decisions
5. **Privacy & Security**: Sensitive data stays private
6. **Community Co-creation**: Viewers are part of the story
7. **Long-term Vision**: Legacy building, not daily metrics

---

## 🤝 Contributing

We welcome contributions! Areas we need help with:

- **Backend**: Rails API endpoints for new features
- **Frontend**: Discord UI/UX improvements
- **Data Science**: Analytics and insights algorithms
- **Design**: Visual assets, profile cards, timelines
- **Documentation**: Tutorials, guides, examples
- **Testing**: Test coverage and quality assurance

---

## 📝 License

© 2025 StreamHub. All rights reserved.

---

## 🙏 Acknowledgments

Built with:
- [discord.py](https://github.com/Rapptz/discord.py) - Discord API wrapper
- [aiohttp](https://github.com/aio-libs/aiohttp) - Async HTTP client
- [Redis](https://redis.io/) - Caching and state management
- [Rails](https://rubyonrails.org/) - Backend API

---

## 📞 Support

- GitHub Issues: [Report bugs or request features](https://github.com/your-org/streamhub/issues)
- Discord: Join our community server (TODO: add link)
- Email: support@streamhub.com

---

**Remember: You're not just building a channel. You're writing a legend.** 📖✨
