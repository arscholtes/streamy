# app/controllers/overlays_controller.rb
# Browser source overlays for OBS Studio
# Serves HTML pages that can be added to OBS as browser sources
class OverlaysController < ApplicationController
  skip_before_action :require_login, only: [:show, :data]
  before_action :verify_overlay_token, only: [:show, :data]
  before_action :find_user

  # GET /overlays/:username/:overlay_type?token=xxx
  # Renders the overlay HTML page for OBS browser source
  def show
    @overlay_type = params[:overlay_type]

    # Validate overlay type
    unless valid_overlay_type?(@overlay_type)
      render plain: "Invalid overlay type", status: :not_found
      return
    end

    # Render without layout (clean HTML for OBS)
    render "overlays/#{@overlay_type}", layout: 'overlay'
  end

  # GET /overlays/:username/:overlay_type/data?token=xxx
  # Returns JSON data for the overlay (polled by JavaScript)
  def data
    @overlay_type = params[:overlay_type]

    unless valid_overlay_type?(@overlay_type)
      render json: { error: "Invalid overlay type" }, status: :not_found
      return
    end

    # Build data based on overlay type
    data = case @overlay_type
    when 'gaming_stats'
      gaming_stats_data
    when 'stream_info'
      stream_info_data
    when 'social_stats'
      social_stats_data
    when 'recent_events'
      recent_events_data
    when 'now_playing'
      now_playing_data
    when 'custom_alert'
      custom_alert_data
    else
      {}
    end

    render json: data
  end

  private

  def find_user
    @user = User.find_by!(username: params[:username])
  rescue ActiveRecord::RecordNotFound
    render plain: "User not found", status: :not_found
  end

  def verify_overlay_token
    # Verify the overlay token matches the user's stream key
    # This prevents unauthorized access to overlay data
    token = params[:token]

    unless token && @user&.stream_key == token
      render plain: "Unauthorized", status: :unauthorized
    end
  end

  def valid_overlay_type?(type)
    %w[gaming_stats stream_info social_stats recent_events now_playing custom_alert].include?(type)
  end

  # Data builders for different overlay types

  def gaming_stats_data
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

  def stream_info_data
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

  def social_stats_data
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

  def recent_events_data
    # Get recent donations, followers, etc.
    # This will be expanded when we add those features
    {
      events: [
        # Placeholder for future events
      ]
    }
  end

  def now_playing_data
    data = {
      playing: false,
      service: nil,
      track: nil
    }

    # Spotify integration
    if @user.spotify_account.present?
      spotify = @user.spotify_account
      # This would fetch current playing track from Spotify API
      # For now, return placeholder
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

  def custom_alert_data
    # Custom alerts for donations, follows, etc.
    # Will be expanded with real-time events
    {
      alerts: []
    }
  end
end
