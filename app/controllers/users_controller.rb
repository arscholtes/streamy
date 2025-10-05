class UsersController < ApplicationController
  def show
    @user = User.find(params[:id])

    # Load user's streams
    @streams = @user.streams.recent.limit(6)
    @live_streams = @user.streams.live
    @total_streams = @user.streams.count

    # Load integrations
    @steam_connected = @user.steam_account.present?
    @discord_connected = @user.discord_account.present?
    @battlenet_connected = @user.battlenet_account.present?
    @riot_connected = @user.riot_account.present?
    @twitter_connected = @user.twitter_account.present?
    @youtube_connected = @user.youtube_account.present?

    # Count connected integrations
    @connected_integrations = [
      @steam_connected,
      @discord_connected,
      @battlenet_connected,
      @riot_connected,
      @twitter_connected,
      @youtube_connected
    ].count(true)

    # Discord bot stats (if available)
    @loyalty_points = @user.loyalty_point&.points || 0
    @achievements_count = @user.user_achievements.count
    @total_achievements = Achievement.count

    # Steam data (if connected and privacy allows)
    if @steam_connected && @user.steam_account
      @steam_account = @user.steam_account
      privacy = @steam_account.integration_privacy_setting

      # Load top games if privacy allows
      if privacy&.show?(:show_game_library)
        @steam_top_games = @steam_account.steam_games
                                         .where('playtime_forever > 0')
                                         .order(playtime_forever: :desc)
                                         .limit(6)
      end

      # Game count
      @steam_game_count = @steam_account.steam_games.count
    end

  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: 'User not found'
  end
end
