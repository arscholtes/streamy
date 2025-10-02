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

ActiveRecord::Schema[8.0].define(version: 2025_10_02_101306) do
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

  create_table "users", force: :cascade do |t|
    t.string "username"
    t.string "email"
    t.string "password_digest"
    t.string "stream_key"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "subscription_tier", default: "free", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["stream_key"], name: "index_users_on_stream_key", unique: true
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
  add_foreign_key "discord_accounts", "users"
  add_foreign_key "integration_privacy_settings", "users"
  add_foreign_key "loyalty_points", "users"
  add_foreign_key "loyalty_transactions", "users"
  add_foreign_key "mini_game_sessions", "users"
  add_foreign_key "obs_connections", "users"
  add_foreign_key "riot_accounts", "users"
  add_foreign_key "steam_accounts", "users"
  add_foreign_key "streams", "users"
  add_foreign_key "stripe_accounts", "users"
  add_foreign_key "twitter_accounts", "users"
  add_foreign_key "user_achievements", "achievements"
  add_foreign_key "user_achievements", "users"
  add_foreign_key "vc_queue_entries", "users"
  add_foreign_key "youtube_accounts", "users"
end
