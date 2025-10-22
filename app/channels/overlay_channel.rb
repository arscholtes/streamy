# app/channels/overlay_channel.rb
# ActionCable channel for real-time overlay data updates
class OverlayChannel < ApplicationCable::Channel
  def subscribed
    # Verify token and get user
    token = params[:token]
    @user = User.find_by(stream_key: token)

    if @user
      # Subscribe to user-specific overlay stream
      stream_for @user

      # Log subscription
      logger.info "OverlayChannel: User #{@user.username} subscribed"

      # Send initial data
      send_overlay_data
    else
      reject
      logger.warn "OverlayChannel: Invalid token attempted"
    end
  end

  def unsubscribed
    # Cleanup when channel is unsubscribed
    logger.info "OverlayChannel: User #{@user&.username} unsubscribed"
  end

  def request_update(data)
    # Client can request a data update
    overlay_type = data['overlay_type']
    send_overlay_data(overlay_type)
  end

  private

  def send_overlay_data(overlay_type = nil)
    # Build overlay data based on type
    data = if overlay_type
      build_specific_overlay_data(overlay_type)
    else
      build_all_overlay_data
    end

    # Broadcast to this user's overlay stream
    OverlayChannel.broadcast_to(@user, {
      type: 'data_update',
      overlay_type: overlay_type,
      data: data,
      timestamp: Time.current.to_i
    })
  end

  def build_all_overlay_data
    {
      gaming_stats: build_gaming_stats_data,
      stream_info: build_stream_info_data,
      social_stats: build_social_stats_data,
      now_playing: build_now_playing_data,
      recent_events: build_recent_events_data,
      custom_alert: build_custom_alert_data
    }
  end

  def build_specific_overlay_data(overlay_type)
    case overlay_type
    when 'gaming_stats'
      build_gaming_stats_data
    when 'stream_info'
      build_stream_info_data
    when 'social_stats'
      build_social_stats_data
    when 'now_playing'
      build_now_playing_data
    when 'recent_events'
      build_recent_events_data
    when 'custom_alert'
      build_custom_alert_data
    else
      {}
    end
  end

  def build_gaming_stats_data
    data = {
      user: {
        username: @user.username,
        display_name: @user.username
      },
      steam: {},
      discord: {},
      battlenet: {},
      riot: {}
    }

    # Steam data
    if @user.steam_account.present?
      steam = @user.steam_account
      data[:steam] = {
        connected: true,
        persona_name: steam.persona_name,
        avatar_url: steam.avatar_url,
        profile_url: steam.profile_url,
        current_game: steam.current_game_name,
        game_count: steam.owned_games_count
      }
    end

    # Discord data
    if @user.discord_account.present?
      discord = @user.discord_account
      data[:discord] = {
        connected: true,
        username: discord.username,
        discriminator: discord.discriminator,
        avatar_url: discord.avatar_url
      }
    end

    # Battle.net data
    if @user.battlenet_account.present?
      battlenet = @user.battlenet_account
      data[:battlenet] = {
        connected: true,
        battletag: battlenet.battletag
      }
    end

    # Riot Games data
    if @user.riot_account.present?
      riot = @user.riot_account
      data[:riot] = {
        connected: true,
        puuid: riot.puuid,
        game_name: riot.game_name,
        tag_line: riot.tag_line
      }
    end

    data
  end

  def build_stream_info_data
    stream = @user.streams.order(created_at: :desc).first

    {
      stream: stream ? {
        title: stream.title,
        status: stream.status,
        created_at: stream.created_at,
        live_duration: stream.status == 'live' ? (Time.current - stream.created_at).to_i : 0
      } : nil,
      user: {
        username: @user.username,
        subscription_tier: @user.subscription_tier
      }
    }
  end

  def build_social_stats_data
    {
      user: {
        username: @user.username,
        total_streams: @user.streams.count,
        account_age_days: (Date.today - @user.created_at.to_date).to_i
      },
      integrations: {
        steam: @user.steam_account.present?,
        discord: @user.discord_account.present?,
        battlenet: @user.battlenet_account.present?,
        riot: @user.riot_account.present?,
        spotify: @user.spotify_account.present?
      }
    }
  end

  def build_now_playing_data
    data = {
      playing: false,
      service: nil,
      track: nil
    }

    # Spotify integration
    if @user.spotify_account.present?
      spotify = @user.spotify_account
      data[:service] = 'spotify'
    end

    # Steam integration - current game
    if @user.steam_account.present? && @user.steam_account.current_game_name.present?
      data[:playing] = true
      data[:service] = 'steam'
      data[:game] = {
        name: @user.steam_account.current_game_name
      }
    end

    data
  end

  def build_recent_events_data
    # Get recent events from cache/database
    events = Rails.cache.fetch("overlay_events:#{@user.id}", expires_in: 5.minutes) do
      []
    end

    {
      events: events
    }
  end

  def build_custom_alert_data
    # Get custom alerts from cache/database
    alerts = Rails.cache.fetch("overlay_alerts:#{@user.id}", expires_in: 5.minutes) do
      []
    end

    {
      alerts: alerts
    }
  end
end
