# StreamHub - Live Streaming Platform

StreamHub is a Twitch-like live streaming platform built with Ruby on Rails 8. This project is designed as a learning exercise to understand video streaming technology while building a production-ready application.

## 🎯 Project Goals

- Learn video streaming protocols (RTMP, HLS, WebRTC)
- Build custom streaming engine from scratch
- Create production-ready platform for real users
- Follow TDD (Test-Driven Development) principles
- Prepare for future payment integration

## 🚀 Features

### ✅ Authentication System
Full-featured user authentication with security best practices:
- User registration with email validation
- Secure login/logout (bcrypt password hashing)
- Session management
- Password reset capability
- Stream key generation for each user

**Implementation:**
- **Model:** `app/models/user.rb` - User model with `has_secure_password`
- **Controllers:**
  - `app/controllers/sessions_controller.rb` - Login/logout
  - `app/controllers/registrations_controller.rb` - Signup
- **Views:**
  - `app/views/sessions/new.html.erb` - Login page
  - `app/views/registrations/new.html.erb` - Signup page
- **Concern:** `app/controllers/concerns/authentication.rb` - Helper methods
- **Tests:** `test/models/user_test.rb`, `test/controllers/sessions_controller_test.rb`, `test/controllers/registrations_controller_test.rb`

**Key Concepts:**
- **BCrypt Password Hashing:** [Rails Security Guide](https://guides.rubyonrails.org/security.html#user-management)
- **has_secure_password:** [API Documentation](https://api.rubyonrails.org/classes/ActiveModel/SecurePassword/ClassMethods.html)
- **Session Management:** [Rails Sessions Guide](https://guides.rubyonrails.org/action_controller_overview.html#session)

### ✅ User Dashboard
Comprehensive dashboard for streamers:
- Stream statistics (total streams, active streams)
- RTMP URL and stream key display
- Copy-to-clipboard functionality
- Stream status indicators (live/offline)
- OBS setup guide modal
- Quick actions panel
- Recent activity timeline

**Implementation:**
- **Controller:** `app/controllers/dashboard_controller.rb`
- **View:** `app/views/dashboard/index.html.erb`
- **Route:** `GET /dashboard`
- **Tests:** `test/controllers/dashboard_controller_test.rb`

**Key Features:**
- Protected by `require_login` before_action
- Displays user's stream key (hidden by default for security)
- Shows RTMP server URL: `rtmp://localhost:1935/live`
- Interactive elements with Bootstrap 5 components

### ✅ Settings Page
Multi-tabbed settings interface:

**Profile Tab:**
- Update username
- Update email address
- Form validation with error display
- Real-time feedback

**Account Tab:**
- Change password with current password verification
- Password strength requirements (min 6 characters)
- Password confirmation matching
- Security tips sidebar

**Billing Tab (Payment-Ready):**
- Current subscription tier display
- Three-tier pricing structure:
  - **Free:** $0/mo - 720p streaming, basic analytics
  - **Pro:** $19/mo - 1080p, custom branding, priority support
  - **Enterprise:** $99/mo - 4K, unlimited bandwidth, white-label
- Upgrade/downgrade buttons (ready for Stripe integration)
- Payment integration placeholder

**Implementation:**
- **Controller:** `app/controllers/settings_controller.rb`
- **View:** `app/views/settings/index.html.erb`
- **Routes:**
  - `GET /settings` - Main settings page
  - `PATCH /settings/profile` - Update profile
  - `PATCH /settings/password` - Update password
- **Tests:** `test/controllers/settings_controller_test.rb`

**Key Concepts:**
- **Strong Parameters:** [Rails Guide](https://guides.rubyonrails.org/action_controller_overview.html#strong-parameters)
- **Bootstrap Tabs:** [Bootstrap Documentation](https://getbootstrap.com/docs/5.3/components/navs-tabs/)

### ✅ Stripe Payment Integration
Full Stripe integration with subscriptions and billing:
- **Subscription Management** - Pro ($19/mo) and Enterprise ($99/mo) tiers
- **Stripe Checkout** - Secure payment flow with Stripe-hosted checkout
- **Webhooks** - Automatic subscription status updates
- **Billing Portal** - Stripe-hosted portal for payment methods, invoices, and cancellation
- **Database Tracking** - subscription_status, stripe_customer_id, stripe_subscription_id

**Implementation:**
- **Initializer:** `config/initializers/stripe.rb` - Stripe API configuration
- **Controller:** `app/controllers/subscriptions_controller.rb` - Checkout & portal
- **Webhooks:** `app/controllers/webhooks_controller.rb` - Event handlers
- **Service:** `app/services/subscription_service.rb` - Business logic
- **Migration:** User fields for Stripe tracking

**Features:**
- Upgrade to Pro/Enterprise from billing page
- Automatic subscription status sync via webhooks
- Cancel subscriptions through Stripe billing portal
- View invoices and update payment methods

**Resources:**
- [Stripe Rails Integration](https://stripe.com/docs/payments/checkout/rails)
- [Stripe Subscriptions](https://stripe.com/docs/billing/subscriptions/overview)

## 🏗️ Architecture

### Streaming Pipeline (Current)
```
Streamer (OBS) → RTMP (Port 1935) → MediaMTX → HLS → Viewer (Browser)
```

**Components:**
- **MediaMTX:** RTMP server for ingesting streams
- **Docker:** Containerized MediaMTX instance
- **HLS:** HTTP Live Streaming for browser playback

### Database Schema

**Users Table:**
```ruby
- id (primary key)
- username (unique, indexed)
- email (unique, indexed)
- password_digest (bcrypt hash)
- stream_key (unique, indexed) - for OBS authentication
- subscription_tier (free/pro/enterprise, indexed)
- created_at, updated_at
```

**Streams Table:**
```ruby
- id (primary key)
- user_id (foreign key to users)
- title
- status (live/offline)
- stream_key (indexed)
- playback_path
- created_at, updated_at
```

### Authentication Flow
1. User registers → password hashed with bcrypt
2. Stream key automatically generated (40-char hex)
3. User logs in → session[:user_id] set
4. Protected routes check `logged_in?` helper
5. Stream key used for RTMP authentication

## 🧪 Testing

We follow **Test-Driven Development (TDD)** principles:

### Test Coverage
- **71.75% code coverage** (2,059 / 2,870 lines)
- **400+ test examples** across Minitest and RSpec
- **All tests passing** (66 Minitest + 300+ RSpec examples)
- **SimpleCov integration** for coverage tracking

### Test Suite Overview

**Minitest Tests (66 tests, 141 assertions):**
- Model tests (22): User validations, associations, callbacks, authentication
- Controller tests (37): Sessions, registrations, dashboard, settings
- Integration tests (7): Authentication concern

**RSpec Test Suite (300+ examples):**
- **Integration Controllers (14 specs):** Steam, Discord, Battle.net, Riot, Spotify, Epic, Xbox, PlayStation, TikTok, Instagram, Twitch, PayPal, Google Analytics, OpenAI
- **Service Objects (23 specs):** OAuth services, API clients, sync services, payment services, rate limiter
- **Background Jobs (5 specs):** Base sync job, Steam/Discord/Riot/Battle.net sync jobs
- **API Controllers (8 specs):** Users, loyalty points, achievements, VC queue, mini-games, moderation, OBS connections
- **Webhooks (1 spec):** Stripe webhook handlers with signature verification
- **Additional Controllers (5 specs):** Donations, streams, subscriptions, chat messages, users
- **Models (29 specs):** All integration accounts, achievements, loyalty points, VC queue entries

### Test Features
- **WebMock integration** for stubbing external API calls
- **FactoryBot** for test data generation
- **shoulda-matchers** for Rails-specific assertions
- **OAuth flow testing** with token refresh scenarios
- **Stripe webhook testing** with signature generation
- **Error handling coverage** for API failures and rate limiting
- **Authorization testing** for admin/user permissions

### Running Tests
```bash
# Run all Minitest tests
bin/rails test

# Run all RSpec tests
bundle exec rspec

# Run specific test file
bin/rails test test/models/user_test.rb
bundle exec rspec spec/requests/integrations/steam_controller_spec.rb

# Run with coverage report
COVERAGE=true bundle exec rspec

# View coverage report
open coverage/index.html
```

**Learn More:**
- [Rails Testing Guide](https://guides.rubyonrails.org/testing.html)
- [Minitest Documentation](https://github.com/minitest/minitest)
- [RSpec Documentation](https://rspec.info/)
- [SimpleCov](https://github.com/simplecov-ruby/simplecov)

## 📦 Installation & Setup

### Prerequisites
- Ruby 3.3.0
- Rails 8.0.3
- SQLite3 (development/test)
- Docker (for MediaMTX)
- OBS Studio (for streaming)

### Setup Steps

1. **Clone the repository**
```bash
git clone <repository-url>
cd rubymine-test-project-1
```

2. **Install dependencies**
```bash
bundle install
```

3. **Setup database**
```bash
bin/rails db:create
bin/rails db:migrate
```

4. **Start MediaMTX (RTMP server)**
```bash
docker-compose up -d
```

5. **Start Rails server**
```bash
bin/rails server
```

6. **Visit the application**
```
http://localhost:3000
```

### MediaMTX Configuration
The RTMP server is configured in `mediamtx.yml`:
- **RTMP Port:** 1935
- **HLS Port:** 8889
- **Stream Path:** `/live`
- **Authentication:** Validates stream key via Rails API

**Learn More:**
- [MediaMTX Documentation](https://github.com/bluenviron/mediamtx)

## 🎥 Streaming with OBS

### OBS Setup Guide

1. **Download OBS Studio**
   - Visit: https://obsproject.com/download

2. **Configure Stream Settings**
   - Open OBS → Settings → Stream
   - Service: Custom
   - Server: `rtmp://localhost:1935/live`
   - Stream Key: Copy from dashboard (Settings → Stream Key)

3. **Start Streaming**
   - Click "Start Streaming" in OBS
   - Your stream goes live automatically!

4. **View Your Stream**
   - HLS Playback URL: `http://localhost:8889/live/index.m3u8`

**Learn More:**
- [OBS Studio Documentation](https://obsproject.com/wiki/)
- [RTMP Protocol](https://en.wikipedia.org/wiki/Real-Time_Messaging_Protocol)
- [HLS Streaming](https://developer.apple.com/streaming/)

## 🎨 Frontend Technologies

- **Bootstrap 5.3:** Responsive UI framework
- **Bootstrap Icons:** Icon library
- **Turbo/Stimulus:** Hotwire for interactivity
- **ERB Templates:** Server-rendered views

**Key UI Components:**
- Modal dialogs (stream key, OBS guide)
- Tab navigation (settings page)
- Cards and badges (dashboard stats)
- Forms with validation feedback
- Copy-to-clipboard functionality

## 🔐 Security Features

### Password Security
- **BCrypt hashing:** Passwords never stored in plain text
- **Cost factor:** 12 (default bcrypt cost)
- **Salt:** Automatically generated per password
- **Rainbow table protection:** Salted hashes

### Session Security
- **Encrypted cookies:** Session data encrypted in browser
- **CSRF protection:** All forms include CSRF tokens
- **Secure headers:** Content Security Policy configured

### Stream Key Security
- **40-character hex keys:** Generated with SecureRandom
- **Unique per user:** Indexed for fast lookup
- **Hidden by default:** Password field in UI
- **HTTPS recommended:** For production deployment

**Learn More:**
- [Rails Security Guide](https://guides.rubyonrails.org/security.html)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)

### ✅ Gaming Integrations
Deep integrations with major gaming platforms:

**Steam Integration:**
- OpenID 2.0 authentication
- Profile syncing (avatar, persona name, profile URL)
- Game library tracking
- Connected and syncing live data

**Discord Integration:**
- OAuth 2.0 authentication
- Profile syncing (username, discriminator, email, avatar)
- Token refresh for long-term access
- Connected and syncing live data

**Battle.net Integration:**
- OAuth 2.0 with multi-region support (US, EU, KR, TW, CN)
- BattleTag and profile syncing
- Access to Overwatch, WoW, Diablo, StarCraft, Hearthstone APIs
- Connected and syncing live data

**Riot Games Integration:**
- Credentials configured for League of Legends, Valorant, TFT
- Ready for OAuth implementation

**Spotify Integration:**
- Credentials configured
- Ready for "Now Playing" music integration

**Implementation:**
- **Base Services:** Shared OAuth and API client architecture
- **Models:** Steam, Discord, Battle.net, Riot, Spotify account models with encryption
- **Controllers:** Standardized connect/callback/disconnect/sync endpoints
- **Privacy System:** Granular control over what data is displayed publicly
- **Brand Logos:** Professional integration logos via Simple Icons CDN

### ✅ Live Streaming
Test stream system for development:
- Live stream playback with HTML5 video player
- Looping test video (Big Buck Bunny via Google CDN)
- Stream status indicators (LIVE badges)
- Viewer count display
- Theater mode layout with chat sidebar

**Implementation:**
- **Stream Model:** Status tracking, playback URLs
- **Stream View:** `app/views/streams/show.html.erb` - Full viewer experience
- **Chat System:** Real-time chat with ActionCable (Turbo Streams)

## 🚧 Roadmap / Future Features

### Phase 1: Core Platform ✅ COMPLETE
- ✅ User authentication
- ✅ Dashboard
- ✅ Settings page
- ✅ Subscription tiers with Stripe
- ✅ Gaming integrations (Steam, Discord, Battle.net)
- ✅ Test streaming system

### Phase 2: Complete Tier 1 Integrations (In Progress - 3/8 Done)
- ✅ Steam, Discord, Battle.net connected
- [ ] Complete Riot Games OAuth flow
- [ ] Complete Spotify OAuth flow
- [ ] Twitter/X integration (auto-post on live)
- [ ] YouTube integration (VOD uploads)
- [ ] OBS Studio integration (stream data overlays)

### Phase 3: Production Streaming
- [ ] RTMP ingest with authentication
- [ ] Live stream status detection
- [ ] VOD recording and storage (S3)
- [ ] Stream thumbnails and previews
- [ ] Multi-bitrate transcoding

### Phase 4: Social Features
- ✅ Chat system (ActionCable/Turbo Streams) - Basic implementation
- [ ] Follow/subscriber system
- [ ] Enhanced viewer count tracking
- [ ] Custom emotes and badges
- [ ] User profiles with integration showcase

### Phase 5: Analytics & Discord Bot
- [ ] Stream analytics dashboard
- [ ] Viewer graphs and peak CCU tracking
- [ ] Revenue analytics
- [ ] Discord bot integration (100+ commands)
  - Viewer interaction (VC queue, !pickviewer)
  - Loyalty points system
  - Mini-games and giveaways
  - Game integration commands
  - Moderation tools

### Phase 6: Tier 2-4 Integrations (42 remaining)
- [ ] Epic Games, Xbox, PlayStation, TikTok, Instagram, Twitch, PayPal
- [ ] Origin, Ubisoft, Rockstar, Patreon, Ko-fi, Nightbot
- [ ] Nintendo, GOG, Apple Music, Mailchimp, and 20+ more

### Phase 7: Advanced Features
- [ ] WebRTC for ultra-low latency
- [ ] CDN integration (CloudFlare/AWS)
- [ ] Clip creation and sharing
- [ ] VOD highlight reels
- [ ] Stream scheduling
- [ ] Multi-streaming (simulcast)

## 📚 Documentation

### 📖 Complete Documentation Index
**NEW:** See [DOCUMENTATION_INDEX.md](DOCUMENTATION_INDEX.md) for a complete tree of all documentation, feature status, and quick links.

**Key Documentation:**
- [DOCUMENTATION_INDEX.md](DOCUMENTATION_INDEX.md) - **START HERE** - Complete documentation hub
- [PROJECT_CONTEXT.md](PROJECT_CONTEXT.md) - Complete technical overview (2000 lines)
- [STREAMHUB_MASTER_PLAN.md](STREAMHUB_MASTER_PLAN.md) - 48 integration roadmap
- [TODO.md](TODO.md) - Current task list & priorities
- [OBS_STREAMING_GUIDE.md](OBS_STREAMING_GUIDE.md) - RTMP streaming setup
- [OBS_OVERLAYS_GUIDE.md](OBS_OVERLAYS_GUIDE.md) - Browser source overlays
- [STUDIO_SYSTEM_COMPLETE.md](STUDIO_SYSTEM_COMPLETE.md) - Complete studio architecture
- [discord_bot/README.md](discord_bot/README.md) - Discord bot documentation

### Video Streaming Concepts
- **RTMP (Real-Time Messaging Protocol):** Used for ingesting video from OBS
  - [RTMP Specification](https://rtmp.veriskope.com/docs/spec/)
  - [How RTMP Works](https://www.wowza.com/blog/rtmp-streaming-real-time-messaging-protocol)

- **HLS (HTTP Live Streaming):** Used for delivering video to browsers
  - [Apple HLS Overview](https://developer.apple.com/streaming/)
  - [HLS.js Player](https://github.com/video-dev/hls.js/)

- **WebRTC (Web Real-Time Communication):** Future low-latency option
  - [WebRTC Documentation](https://webrtc.org/)
  - [WebRTC vs RTMP](https://bloggeek.me/webrtc-vs-rtmp/)

### Rails Concepts Used
- [Active Record Associations](https://guides.rubyonrails.org/association_basics.html)
- [Active Record Callbacks](https://guides.rubyonrails.org/active_record_callbacks.html)
- [Active Record Validations](https://guides.rubyonrails.org/active_record_validations.html)
- [Action Controller Overview](https://guides.rubyonrails.org/action_controller_overview.html)
- [Layouts and Rendering](https://guides.rubyonrails.org/layouts_and_rendering.html)
- [Rails Routing](https://guides.rubyonrails.org/routing.html)
- [Testing Guide](https://guides.rubyonrails.org/testing.html)

## 🤝 Contributing

This is a learning project, but contributions are welcome!

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Write tests for your feature (TDD!)
4. Implement your feature
5. Ensure all tests pass (`bin/rails test`)
6. Commit your changes (`git commit -m 'Add amazing feature'`)
7. Push to the branch (`git push origin feature/amazing-feature`)
8. Open a Pull Request

## 📝 License

This project is open source and available for learning purposes.

## 🙏 Acknowledgments

- **MediaMTX:** Open-source RTMP/HLS server
- **Rails Community:** Excellent documentation and guides
- **Bootstrap Team:** Beautiful UI components
- **OBS Project:** Professional streaming software

---

**Built with ❤️ as a learning project to understand live streaming technology**
