# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_10_06_001433) do
  create_table "achievements", force: :cascade do |t|
    t.string "name", null: false
    t.text "description", null: false
    t.string "icon"
    t.string "category", null: false
    t.integer "points_reward", default: 0, null: false
    t.string "requirement_type", null: false
    t.integer "requirement_value", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category"], name: "index_achievements_on_category"
    t.index ["name"], name: "index_achievements_on_name", unique: true
  end

  create_table "battlenet_accounts", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "battletag"
    t.string "region"
    t.string "access_token"
    t.string "refresh_token"
    t.datetime "token_expires_at"
    t.datetime "last_synced_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["battletag"], name: "index_battlenet_accounts_on_battletag", unique: true
    t.index ["user_id"], name: "index_battlenet_accounts_on_user_id"
  end

  create_table "chat_messages", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "stream_id", null: false
    t.text "content"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["stream_id"], name: "index_chat_messages_on_stream_id"
    t.index ["user_id"], name: "index_chat_messages_on_user_id"
  end

  create_table "discord_accounts", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "discord_id"
    t.string "username"
    t.string "discriminator"
    t.string "avatar_url"
    t.string "email"
    t.boolean "verified"
    t.string "locale"
    t.string "access_token"
    t.string "refresh_token"
    t.datetime "token_expires_at"
    t.datetime "last_synced_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["discord_id"], name: "index_discord_accounts_on_discord_id", unique: true
    t.index ["user_id"], name: "index_discord_accounts_on_user_id"
  end

  create_table "epic_accounts", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "epic_id"
    t.string "display_name"
    t.string "email"
    t.string "country"
    t.string "access_token"
    t.string "refresh_token"
    t.datetime "token_expires_at"
    t.datetime "last_synced_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["epic_id"], name: "index_epic_accounts_on_epic_id", unique: true
    t.index ["user_id"], name: "index_epic_accounts_on_user_id"
  end

  create_table "google_analytics_accounts", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "property_id"
    t.string "account_id"
    t.string "property_name"
    t.string "tracking_id"
    t.string "access_token"
    t.string "refresh_token"
    t.datetime "token_expires_at"
    t.datetime "last_synced_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["property_id"], name: "index_google_analytics_accounts_on_property_id", unique: true
    t.index ["user_id"], name: "index_google_analytics_accounts_on_user_id"
  end

  create_table "instagram_accounts", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "instagram_id"
    t.string "username"
    t.string "full_name"
    t.integer "follower_count"
    t.integer "media_count"
    t.string "access_token"
    t.string "refresh_token"
    t.datetime "token_expires_at"
    t.datetime "last_synced_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["instagram_id"], name: "index_instagram_accounts_on_instagram_id", unique: true
    t.index ["user_id"], name: "index_instagram_accounts_on_user_id"
  end

  create_table "integration_privacy_settings", force: :cascade do |t|
    t.string "integration_type", null: false
    t.integer "integration_id", null: false
    t.integer "user_id", null: false
    t.json "settings", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["integration_type", "integration_id"], name: "index_privacy_on_integration"
    t.index ["integration_type", "integration_id"], name: "index_privacy_unique_integration", unique: true
    t.index ["user_id"], name: "index_integration_privacy_settings_on_user_id"
  end

  create_table "loyalty_points", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "points", default: 0, null: false
    t.integer "level", default: 1, null: false
    t.integer "total_earned", default: 0, null: false
    t.integer "total_spent", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_loyalty_points_on_user_id", unique: true
  end

  create_table "loyalty_transactions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "transaction_type", null: false
    t.integer "amount", null: false
    t.text "description"
    t.json "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_loyalty_transactions_on_created_at"
    t.index ["transaction_type"], name: "index_loyalty_transactions_on_transaction_type"
    t.index ["user_id"], name: "index_loyalty_transactions_on_user_id"
  end

  create_table "mini_game_sessions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "game_type", null: false
    t.integer "bet_amount", null: false
    t.string "result", null: false
    t.integer "winnings", default: 0, null: false
    t.json "metadata", default: {}
    t.datetime "played_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["game_type"], name: "index_mini_game_sessions_on_game_type"
    t.index ["played_at"], name: "index_mini_game_sessions_on_played_at"
    t.index ["user_id", "played_at"], name: "index_mini_game_sessions_on_user_id_and_played_at"
    t.index ["user_id"], name: "index_mini_game_sessions_on_user_id"
  end

  create_table "moderation_actions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "action_type", null: false
    t.integer "target_user_id"
    t.string "moderator_discord_id", null: false
    t.string "target_discord_id", null: false
    t.text "reason"
    t.json "metadata", default: {}
    t.string "guild_id", null: false
    t.datetime "performed_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action_type"], name: "index_moderation_actions_on_action_type"
    t.index ["guild_id"], name: "index_moderation_actions_on_guild_id"
    t.index ["performed_at"], name: "index_moderation_actions_on_performed_at"
    t.index ["target_discord_id"], name: "index_moderation_actions_on_target_discord_id"
    t.index ["user_id"], name: "index_moderation_actions_on_user_id"
  end

  create_table "obs_connections", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "obs_version"
    t.string "platform"
    t.string "ip_address"
    t.datetime "last_connected_at"
    t.string "access_token"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_obs_connections_on_user_id"
  end

  create_table "openai_integrations", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "api_key"
    t.string "organization_id"
    t.integer "usage_limit"
    t.integer "usage_count"
    t.datetime "last_used_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_openai_integrations_on_user_id"
  end

  create_table "payments", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "recipient_id"
    t.string "stripe_payment_intent_id"
    t.string "stripe_charge_id"
    t.string "stripe_transfer_id"
    t.integer "amount_cents", null: false
    t.integer "platform_fee_cents", default: 0
    t.integer "recipient_amount_cents"
    t.string "currency", default: "usd", null: false
    t.string "status", default: "pending", null: false
    t.string "payment_type", null: false
    t.text "description"
    t.json "metadata", default: {}
    t.datetime "refunded_at"
    t.integer "refund_amount_cents"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "paid_at"
    t.index ["payment_type"], name: "index_payments_on_payment_type"
    t.index ["recipient_id", "status"], name: "index_payments_on_recipient_id_and_status"
    t.index ["recipient_id"], name: "index_payments_on_recipient_id"
    t.index ["status"], name: "index_payments_on_status"
    t.index ["stripe_charge_id"], name: "index_payments_on_stripe_charge_id"
    t.index ["stripe_payment_intent_id"], name: "index_payments_on_stripe_payment_intent_id", unique: true
    t.index ["user_id", "payment_type"], name: "index_payments_on_user_id_and_payment_type"
    t.index ["user_id"], name: "index_payments_on_user_id"
  end

  create_table "paypal_accounts", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "paypal_id"
    t.string "email"
    t.boolean "verified"
    t.string "account_type"
    t.string "access_token"
    t.string "refresh_token"
    t.datetime "token_expires_at"
    t.datetime "last_synced_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["paypal_id"], name: "index_paypal_accounts_on_paypal_id", unique: true
    t.index ["user_id"], name: "index_paypal_accounts_on_user_id"
  end

  create_table "playstation_accounts", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "psn_id"
    t.string "online_id"
    t.string "account_id"
    t.string "region"
    t.string "plus_status"
    t.string "access_token"
    t.string "refresh_token"
    t.datetime "token_expires_at"
    t.datetime "last_synced_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["psn_id"], name: "index_playstation_accounts_on_psn_id", unique: true
    t.index ["user_id"], name: "index_playstation_accounts_on_user_id"
  end

  create_table "riot_accounts", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "puuid"
    t.string "game_name"
    t.string "tag_line"
    t.string "region"
    t.string "access_token"
    t.string "refresh_token"
    t.datetime "token_expires_at"
    t.datetime "last_synced_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["puuid"], name: "index_riot_accounts_on_puuid", unique: true
    t.index ["user_id"], name: "index_riot_accounts_on_user_id"
  end

  create_table "spotify_accounts", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "spotify_id"
    t.string "display_name"
    t.string "email"
    t.string "product"
    t.string "country"
    t.integer "follower_count"
    t.string "access_token"
    t.string "refresh_token"
    t.datetime "token_expires_at"
    t.datetime "last_synced_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["spotify_id"], name: "index_spotify_accounts_on_spotify_id", unique: true
    t.index ["user_id"], name: "index_spotify_accounts_on_user_id"
  end

  create_table "steam_accounts", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "steam_id"
    t.string "persona_name"
    t.string "profile_url"
    t.string "avatar_url"
    t.string "real_name"
    t.string "country_code"
    t.string "state_code"
    t.integer "visibility"
    t.integer "time_created"
    t.integer "last_logoff"
    t.integer "level"
    t.string "access_token"
    t.string "refresh_token"
    t.datetime "token_expires_at"
    t.datetime "last_synced_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["steam_id"], name: "index_steam_accounts_on_steam_id", unique: true
    t.index ["user_id"], name: "index_steam_accounts_on_user_id"
  end

  create_table "streams", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "title"
    t.string "status"
    t.string "stream_key"
    t.string "playback_path"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["stream_key"], name: "index_streams_on_stream_key"
    t.index ["user_id"], name: "index_streams_on_user_id"
  end

  create_table "stripe_accounts", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "stripe_id"
    t.string "email"
    t.string "account_type"
    t.boolean "charges_enabled"
    t.boolean "payouts_enabled"
    t.string "access_token"
    t.string "refresh_token"
    t.datetime "token_expires_at"
    t.datetime "last_synced_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["stripe_id"], name: "index_stripe_accounts_on_stripe_id", unique: true
    t.index ["user_id"], name: "index_stripe_accounts_on_user_id"
  end

  create_table "subscriptions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "stripe_subscription_id", null: false
    t.string "stripe_customer_id", null: false
    t.string "status", default: "incomplete", null: false
    t.string "plan", null: false
    t.datetime "current_period_start"
    t.datetime "current_period_end"
    t.boolean "cancel_at_period_end", default: false, null: false
    t.datetime "canceled_at"
    t.datetime "trial_start"
    t.datetime "trial_end"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["plan"], name: "index_subscriptions_on_plan"
    t.index ["status"], name: "index_subscriptions_on_status"
    t.index ["stripe_customer_id"], name: "index_subscriptions_on_stripe_customer_id"
    t.index ["stripe_subscription_id"], name: "index_subscriptions_on_stripe_subscription_id", unique: true
    t.index ["user_id"], name: "index_subscriptions_on_user_id"
  end

  create_table "tiktok_accounts", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "tiktok_id"
    t.string "username"
    t.string "display_name"
    t.integer "follower_count"
    t.integer "video_count"
    t.string "access_token"
    t.string "refresh_token"
    t.datetime "token_expires_at"
    t.datetime "last_synced_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tiktok_id"], name: "index_tiktok_accounts_on_tiktok_id", unique: true
    t.index ["user_id"], name: "index_tiktok_accounts_on_user_id"
  end

  create_table "twitch_accounts", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "twitch_id"
    t.string "login"
    t.string "display_name"
    t.string "broadcaster_type"
    t.string "description"
    t.string "profile_image_url"
    t.integer "view_count"
    t.integer "follower_count"
    t.string "access_token"
    t.string "refresh_token"
    t.datetime "token_expires_at"
    t.datetime "last_synced_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["twitch_id"], name: "index_twitch_accounts_on_twitch_id", unique: true
    t.index ["user_id"], name: "index_twitch_accounts_on_user_id"
  end

  create_table "twitter_accounts", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "twitter_id"
    t.string "username"
    t.string "name"
    t.string "profile_image_url"
    t.integer "followers_count"
    t.string "access_token"
    t.string "refresh_token"
    t.datetime "token_expires_at"
    t.datetime "last_synced_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["twitter_id"], name: "index_twitter_accounts_on_twitter_id", unique: true
    t.index ["user_id"], name: "index_twitter_accounts_on_user_id"
  end

  create_table "user_achievements", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "achievement_id", null: false
    t.datetime "earned_at"
    t.integer "progress", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["achievement_id"], name: "index_user_achievements_on_achievement_id"
    t.index ["earned_at"], name: "index_user_achievements_on_earned_at"
    t.index ["user_id", "achievement_id"], name: "index_user_achievements_on_user_id_and_achievement_id", unique: true
    t.index ["user_id"], name: "index_user_achievements_on_user_id"
  end

  create_table "user_mutes", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "discord_id", null: false
    t.string "moderator_discord_id", null: false
    t.string "guild_id", null: false
    t.text "reason"
    t.datetime "muted_at", null: false
    t.datetime "unmuted_at"
    t.integer "duration_minutes", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_user_mutes_on_active"
    t.index ["discord_id", "guild_id", "active"], name: "index_user_mutes_on_discord_id_and_guild_id_and_active"
    t.index ["discord_id"], name: "index_user_mutes_on_discord_id"
    t.index ["guild_id"], name: "index_user_mutes_on_guild_id"
    t.index ["unmuted_at"], name: "index_user_mutes_on_unmuted_at"
    t.index ["user_id"], name: "index_user_mutes_on_user_id"
  end

  create_table "user_warnings", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "discord_id", null: false
    t.string "moderator_discord_id", null: false
    t.string "guild_id", null: false
    t.text "reason"
    t.datetime "warned_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["discord_id", "guild_id"], name: "index_user_warnings_on_discord_id_and_guild_id"
    t.index ["discord_id"], name: "index_user_warnings_on_discord_id"
    t.index ["guild_id"], name: "index_user_warnings_on_guild_id"
    t.index ["user_id"], name: "index_user_warnings_on_user_id"
    t.index ["warned_at"], name: "index_user_warnings_on_warned_at"
  end

  create_table "users", force: :cascade do |t|
    t.string "username"
    t.string "email"
    t.string "password_digest"
    t.string "stream_key"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "subscription_tier", default: "free", null: false
    t.string "stripe_customer_id"
    t.string "stripe_subscription_id"
    t.string "subscription_status"
    t.datetime "current_period_end"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["stream_key"], name: "index_users_on_stream_key", unique: true
    t.index ["stripe_customer_id"], name: "index_users_on_stripe_customer_id", unique: true
    t.index ["subscription_tier"], name: "index_users_on_subscription_tier"
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  create_table "vc_queue_entries", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "discord_user_id", null: false
    t.integer "priority", default: 0, null: false
    t.integer "position", null: false
    t.string "status", default: "waiting", null: false
    t.datetime "joined_at", null: false
    t.datetime "left_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["discord_user_id"], name: "index_vc_queue_entries_on_discord_user_id"
    t.index ["status", "priority", "joined_at"], name: "index_vc_queue_on_status_priority_joined"
    t.index ["status"], name: "index_vc_queue_entries_on_status"
    t.index ["user_id"], name: "index_vc_queue_entries_on_user_id"
  end

  create_table "xbox_accounts", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "xbox_id"
    t.string "gamertag"
    t.integer "gamerscore"
    t.string "account_tier"
    t.string "access_token"
    t.string "refresh_token"
    t.datetime "token_expires_at"
    t.datetime "last_synced_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_xbox_accounts_on_user_id"
    t.index ["xbox_id"], name: "index_xbox_accounts_on_xbox_id", unique: true
  end

  create_table "youtube_accounts", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "youtube_id"
    t.string "channel_title"
    t.string "channel_url"
    t.integer "subscriber_count"
    t.integer "video_count"
    t.string "thumbnail_url"
    t.string "access_token"
    t.string "refresh_token"
    t.datetime "token_expires_at"
    t.datetime "last_synced_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_youtube_accounts_on_user_id"
    t.index ["youtube_id"], name: "index_youtube_accounts_on_youtube_id", unique: true
  end

  add_foreign_key "battlenet_accounts", "users"
  add_foreign_key "chat_messages", "streams"
  add_foreign_key "chat_messages", "users"
  add_foreign_key "discord_accounts", "users"
  add_foreign_key "epic_accounts", "users"
  add_foreign_key "google_analytics_accounts", "users"
  add_foreign_key "instagram_accounts", "users"
  add_foreign_key "integration_privacy_settings", "users"
  add_foreign_key "loyalty_points", "users"
  add_foreign_key "loyalty_transactions", "users"
  add_foreign_key "mini_game_sessions", "users"
  add_foreign_key "moderation_actions", "users"
  add_foreign_key "obs_connections", "users"
  add_foreign_key "openai_integrations", "users"
  add_foreign_key "payments", "users"
  add_foreign_key "payments", "users", column: "recipient_id"
  add_foreign_key "paypal_accounts", "users"
  add_foreign_key "playstation_accounts", "users"
  add_foreign_key "riot_accounts", "users"
  add_foreign_key "spotify_accounts", "users"
  add_foreign_key "steam_accounts", "users"
  add_foreign_key "streams", "users"
  add_foreign_key "stripe_accounts", "users"
  add_foreign_key "subscriptions", "users"
  add_foreign_key "tiktok_accounts", "users"
  add_foreign_key "twitch_accounts", "users"
  add_foreign_key "twitter_accounts", "users"
  add_foreign_key "user_achievements", "achievements"
  add_foreign_key "user_achievements", "users"
  add_foreign_key "user_mutes", "users"
  add_foreign_key "user_warnings", "users"
  add_foreign_key "vc_queue_entries", "users"
  add_foreign_key "xbox_accounts", "users"
  add_foreign_key "youtube_accounts", "users"
end
