# StreamHub - TODO & Improvement Opportunities

**Last Updated:** 2025-10-15
**Test Coverage:** 71.75% (2,059 / 2,870 lines)
**Status:** Strong foundation, RTMP streaming complete, ready for feature expansion

📖 **[See DOCUMENTATION_INDEX.md](DOCUMENTATION_INDEX.md) for complete feature status & documentation tree**

---

## 🎯 High Priority - Core Functionality

### 1. ✅ Create GameSession Model ~~⚠️ **BLOCKING BUG**~~ **COMPLETED**
**Why:** Referenced in Stream model but doesn't exist, causing test failures
**Impact:** Stream callbacks for game detection are now enabled
**Files Created:**
- ✅ `app/models/game_session.rb` - Model with validations, associations, scopes
- ✅ `db/migrate/20251007164759_create_game_sessions.rb` - Database migration
- ✅ `spec/models/game_session_spec.rb` - 25 test examples (all passing)
- ✅ `spec/factories/game_sessions.rb` - Factory with traits for testing

**Features Implemented:**
- Associations: belongs_to :user, belongs_to :stream (optional)
- Validations: platform (steam/battlenet/riot), game_name, game_id, started_at
- Scopes: active, ended, for_platform, for_game, recent
- Methods: active?, ended?, duration, duration_in_minutes, end_session!
- Stream callbacks: start_game_detection, end_game_sessions now work

**Time Spent:** 2 hours
**Status:** ✅ COMPLETED - All tests passing

---

### 2. ✅ Implement Real RTMP Streaming ~~⏳ To be implemented~~ **COMPLETED**
**Why:** Need actual live streaming instead of test video
**Status:** ✅ Fully implemented and tested
**Impact:** Full RTMP streaming infrastructure now operational

**Completed Tasks:**
- ✅ Configured MediaMTX with authentication webhooks
- ✅ Implemented RTMP authentication endpoint (validates stream key)
- ✅ Detect stream start/stop via MediaMTX webhooks (runOnPublish/runOnUnPublish)
- ✅ Update Stream model status automatically via webhooks
- ✅ Created OBS_STREAMING_GUIDE.md for testing

**Files Created/Modified:**
- ✅ `mediamtx.yml` - Added runOnPublish and runOnUnPublish webhooks
- ✅ `app/controllers/rtmp_controller.rb` - Added publish/unpublish webhook actions
- ✅ `config/routes.rb` - Routes already existed
- ✅ `OBS_STREAMING_GUIDE.md` - Complete setup and testing guide

**Features Implemented:**
- Stream key authentication via `/rtmp/auth` endpoint
- Automatic stream status updates (live → offline)
- Stream session tracking (started_at, ended_at, duration)
- Action Cable broadcasts for real-time overlay updates
- Background job triggers for stream events
- HLS playback URL generation

**How to Test:**
1. Start services: `docker-compose restart mediamtx`
2. Get stream key from Settings → Streaming
3. Configure OBS: Server `rtmp://localhost:1935`, Stream Key `[your key]`
4. Start streaming in OBS
5. Check Rails logs for `🔴 PUBLISH` message
6. Verify stream shows as LIVE in dashboard

**Time Spent:** ~3 hours
**Status:** ✅ COMPLETED - Ready for production use

---

### 3. Complete Integration OAuth Flows
**Status:** 3/8 Tier 1 integrations working (Steam ✅, Discord ✅, Battle.net ✅)
**Remaining:** Riot, Spotify, Twitter, YouTube, OBS

#### Riot Games (5-6 hours)
- [ ] Implement RSO (Riot Sign-On) OAuth flow
- [ ] API clients for League, Valorant, TFT
- [ ] Sync services for rank/stats
- [ ] Test with real account

#### Spotify (3-4 hours)
- [ ] Implement OAuth with Basic Auth
- [ ] "Now Playing" API integration
- [ ] Playlist syncing
- [ ] Display on profile

#### Twitter/X (4-5 hours)
- [ ] OAuth 2.0 implementation
- [ ] Auto-tweet on stream start
- [ ] Clip sharing functionality
- [ ] Follower count display

#### YouTube (6-8 hours)
- [ ] OAuth implementation
- [ ] VOD upload API
- [ ] Subscriber count sync
- [ ] Shorts export feature

#### OBS Studio Integration (15-20 hours)
- [ ] Custom RTMP endpoints
- [ ] WebSocket API for live data
- [ ] Browser source overlays
- [ ] Stream data endpoints (rank, game, etc.)

**Estimated Time:** 35-43 hours total
**Priority:** 🟡 MEDIUM - Expands platform features

---

## 🤖 Discord Bot Integration

### 4. Connect Discord Bot to Rails Backend
**Why:** Python Discord bot exists but doesn't communicate with Rails
**Current:** Bot and Rails are separate
**Need:** REST API bridge

**Tasks:**
- [ ] Create API controller (`Api::V1::DiscordBotController`)
- [ ] Implement endpoints:
  - `GET /api/v1/discord_bot/users/:discord_id` - User lookup
  - `POST /api/v1/discord_bot/loyalty_points/add` - Award points
  - `POST /api/v1/discord_bot/loyalty_points/spend` - Deduct points
  - `GET /api/v1/discord_bot/achievements` - List achievements
  - `POST /api/v1/discord_bot/achievements/award` - Unlock achievement
  - `POST /api/v1/discord_bot/vc_queue/join` - Join queue
  - `GET /api/v1/discord_bot/vc_queue` - View queue
  - `POST /api/v1/discord_bot/vc_queue/next` - Move to next
- [ ] API authentication (bearer token / shared secret)
- [ ] Update Discord bot to call Rails API
- [ ] Test commands (!points, !achievements, !joinqueue)

**Estimated Time:** 12-15 hours
**Priority:** 🟡 MEDIUM - Enables community features

---

## 📈 Increase Test Coverage (71.75% → 90%+)

### 5. Add Missing Tests
**Current Coverage:** 71.75% (2,059 / 2,870 lines)
**Target:** 90%+

**Low Coverage Areas:**
- View templates (0% covered)
- JavaScript Stimulus controllers (0% covered)
- Error handling edge cases
- Webhook failure scenarios
- Rate limiting behavior
- Token refresh mechanisms

**Tasks:**
- [ ] Add system tests for critical user flows
- [ ] Test view rendering with different user states
- [ ] Test error boundaries (500, 404, 422 pages)
- [ ] Test webhook retry logic
- [ ] Test rate limiter with Redis
- [ ] Test OAuth token auto-refresh

**Estimated Time:** 20-25 hours
**Priority:** 🟢 LOW - Quality improvement

---

## 🎨 UI/UX Improvements

### 6. Add Loading States & Animations
**Why:** Better user experience during async operations
**Missing:**
- Loading spinners for OAuth redirects
- Progress bars for file uploads
- Skeleton screens for data loading
- Toast notifications for success/error
- Page transition animations

**Tasks:**
- [ ] Create reusable loading component
- [ ] Add Turbo Frame loading indicators
- [ ] Implement toast notification system
- [ ] Add skeleton screens for profile pages
- [ ] Smooth page transitions

**Estimated Time:** 8-10 hours
**Priority:** 🟢 LOW - Polish

---

### 7. Responsive Design Audit
**Why:** Ensure mobile compatibility
**Current:** Desktop-first design
**Need:** Mobile-responsive layouts

**Tasks:**
- [ ] Test all pages on mobile devices
- [ ] Fix dashboard stat cards on mobile
- [ ] Improve settings page tabs for mobile
- [ ] Test stream viewer on tablets
- [ ] Responsive navigation menu

**Estimated Time:** 6-8 hours
**Priority:** 🟢 LOW - User experience

---

## 💰 Monetization Features

### 8. Stripe Price IDs Configuration
**Why:** Checkout currently uses placeholder IDs
**Current:** Hardcoded test price IDs
**Need:** Production Stripe prices

**Tasks:**
- [ ] Create Stripe products in dashboard
- [ ] Create price IDs for Pro ($19/mo) and Enterprise ($99/mo)
- [ ] Update `config/credentials.yml.enc` with production IDs
- [ ] Test checkout flow in production mode
- [ ] Add annual pricing option (20% discount)

**Estimated Time:** 2-3 hours
**Priority:** 🟡 MEDIUM - Required for monetization

---

### 9. Revenue Dashboard for Streamers
**Why:** Streamers need to see earnings
**Current:** PaymentService tracks data but no UI
**Need:** Dashboard with charts

**Tasks:**
- [ ] Create analytics page (`/dashboard/analytics`)
- [ ] Chart.js integration for revenue graphs
- [ ] Display key metrics:
  - Total earnings (all time)
  - Last 30 days revenue
  - Subscription revenue vs donations
  - Top donors
  - Revenue trend graph
- [ ] Export to CSV functionality

**Estimated Time:** 10-12 hours
**Priority:** 🟡 MEDIUM - Creator feature

---

## 🔧 Technical Debt & Refactoring

### 10. Implement Proper Caching Strategy
**Why:** Reduce database queries, improve performance
**Current:** No caching implemented
**Need:** Redis caching for expensive queries

**Tasks:**
- [ ] Cache user profile data (15 min TTL)
- [ ] Cache integration account data (5 min TTL)
- [ ] Cache stream lists (1 min TTL)
- [ ] Fragment caching for profile pages
- [ ] Russian doll caching for nested data
- [ ] Add cache invalidation on updates

**Estimated Time:** 8-10 hours
**Priority:** 🟢 LOW - Performance optimization

---

### 11. Database Query Optimization
**Why:** Eliminate N+1 queries
**Current:** Some controllers have N+1 issues
**Need:** Eager loading with `includes`

**Tasks:**
- [ ] Audit all controller actions with Bullet gem
- [ ] Add `includes` to associations
- [ ] Add database indexes for foreign keys
- [ ] Optimize slow queries (check pg_stat_statements)
- [ ] Add counter caches for counts

**Estimated Time:** 6-8 hours
**Priority:** 🟢 LOW - Performance optimization

---

### 12. Background Job Monitoring
**Why:** Track sync job success/failure rates
**Current:** Jobs run but no visibility
**Need:** Dashboard for job status

**Tasks:**
- [ ] Install Sidekiq Web UI
- [ ] Add authentication to Sidekiq Web
- [ ] Create job status dashboard
- [ ] Email notifications for failed jobs
- [ ] Retry failed jobs automatically

**Estimated Time:** 4-5 hours
**Priority:** 🟢 LOW - Operations

---

## 🚀 Feature Expansions

### 13. VOD & Clip System
**Why:** Users want to save highlights
**Current:** No VOD recording
**Need:** S3 storage + clip editor

**Tasks:**
- [ ] Configure AWS S3 bucket
- [ ] Record streams to S3 (via MediaMTX)
- [ ] Create Clip model
- [ ] Build clip editor UI (trim start/end)
- [ ] Generate thumbnails
- [ ] Share clips to social media
- [ ] Clip library page

**Estimated Time:** 25-30 hours
**Priority:** 🟡 MEDIUM - Major feature

---

### 14. User Profile Enhancements
**Why:** Showcase more data from integrations
**Current:** Basic profile display
**Need:** Rich integration data

**Tasks:**
- [ ] Steam game library showcase
- [ ] Battle.net character profiles
- [ ] Riot Games rank history
- [ ] Achievement showcase
- [ ] Custom profile themes
- [ ] Profile badges (subscriber, donor, etc.)

**Estimated Time:** 15-20 hours
**Priority:** 🟢 LOW - Enhancement

---

### 15. Chat Moderation Tools
**Why:** Streamers need to moderate their communities
**Current:** Basic chat only
**Need:** Mod actions

**Tasks:**
- [ ] Implement timeout command
- [ ] Implement ban command
- [ ] Slow mode
- [ ] Emote-only mode
- [ ] Mod action audit log
- [ ] Sync bans with Discord

**Estimated Time:** 12-15 hours
**Priority:** 🟡 MEDIUM - Moderation feature

---

## 📊 Analytics & Insights

### 16. Stream Analytics Dashboard
**Why:** Streamers need performance insights
**Current:** No analytics tracking
**Need:** Comprehensive analytics

**Tasks:**
- [ ] Track viewer count over time
- [ ] Track chat messages per minute
- [ ] Track peak concurrent viewers
- [ ] Track average watch time
- [ ] Track follower growth
- [ ] Chart.js visualizations
- [ ] Export reports to PDF

**Estimated Time:** 20-25 hours
**Priority:** 🟡 MEDIUM - Analytics feature

---

## 🔐 Security Improvements

### 17. Security Audit
**Why:** Ensure production readiness
**Current:** Basic security implemented
**Need:** Comprehensive audit

**Tasks:**
- [ ] Run Brakeman security scanner
- [ ] Fix any security warnings
- [ ] Review OAuth token storage
- [ ] Test rate limiting on all endpoints
- [ ] Add CAPTCHA to registration
- [ ] Implement 2FA for accounts
- [ ] Security headers audit (CSP, HSTS, etc.)

**Estimated Time:** 10-12 hours
**Priority:** 🔴 HIGH - Before production launch

---

## 📝 Documentation

### 18. API Documentation
**Why:** Discord bot and future integrations need docs
**Current:** No API docs
**Need:** OpenAPI/Swagger docs

**Tasks:**
- [ ] Install rswag or similar
- [ ] Document all API endpoints
- [ ] Add request/response examples
- [ ] Include authentication docs
- [ ] Generate interactive API docs

**Estimated Time:** 6-8 hours
**Priority:** 🟢 LOW - Documentation

---

## 🎯 Quick Wins (< 2 hours each)

### 19. Small Improvements
- [ ] Add favicon and app icons
- [ ] Improve error messages (user-friendly)
- [ ] Add "Copy Link" button to profiles
- [ ] Add "Last Seen" to user profiles
- [ ] Add email notifications for important events
- [ ] Add dark/light mode toggle (UI is already dark)
- [ ] Add keyboard shortcuts (ESC to close modals, etc.)
- [ ] Add breadcrumb navigation
- [ ] Improve form validation messages
- [ ] Add placeholder images for avatars

**Total Estimated Time:** 10-15 hours
**Priority:** 🟢 LOW - Polish

---

## 📦 Summary

### By Priority:

**🔴 HIGH PRIORITY (Must Do):**
1. ✅ GameSession Model (2-3 hours) - **COMPLETED**
2. ✅ Real RTMP Streaming (10-15 hours) - **COMPLETED**
3. Security Audit (10-12 hours) - **NEXT UP**

**🟡 MEDIUM PRIORITY (Should Do):**
4. Complete Integration OAuth Flows (35-43 hours)
5. Discord Bot API Integration (12-15 hours)
6. Stripe Price Configuration (2-3 hours)
7. Revenue Dashboard (10-12 hours)
8. VOD & Clip System (25-30 hours)
9. Stream Analytics (20-25 hours)
10. Chat Moderation (12-15 hours)

**🟢 LOW PRIORITY (Nice to Have):**
11. Increase Test Coverage to 90%+ (20-25 hours)
12. UI/UX Polish (8-10 hours)
13. Responsive Design (6-8 hours)
14. Caching Strategy (8-10 hours)
15. Query Optimization (6-8 hours)
16. Profile Enhancements (15-20 hours)
17. API Documentation (6-8 hours)
18. Quick Wins (10-15 hours)

### Total Estimated Time: 220-280 hours

---

## 🚀 Recommended Next Steps

### This Week (Priority Order):
1. **Fix GameSession Model** (2-3 hours) - Critical bug fix
2. **Implement Real RTMP Streaming** (10-15 hours) - Core feature
3. **Complete Riot Integration** (5-6 hours) - Quick win, validates architecture

### Next Week:
4. **Connect Discord Bot** (12-15 hours) - Unlocks community features
5. **Configure Stripe Production** (2-3 hours) - Enable monetization
6. **Security Audit** (10-12 hours) - Pre-launch requirement

### Following Weeks:
7. Complete remaining Tier 1 integrations
8. Build VOD/Clip system
9. Add analytics dashboards
10. Polish UI/UX for launch

---

**Document Version:** 1.0
**Created:** 2025-10-07
**Next Review:** After completing High Priority items
