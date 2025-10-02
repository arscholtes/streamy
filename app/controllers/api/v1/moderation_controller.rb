module Api
  module V1
    class ModerationController < BaseController
      # POST /api/v1/moderation/warn
      # Create a warning for a user
      def warn
        user = find_or_create_user_by_discord_id(params[:discord_id])

        warning = UserWarning.create!(
          user: user,
          discord_id: params[:discord_id],
          moderator_discord_id: params[:moderator_discord_id],
          guild_id: params[:guild_id],
          reason: params[:reason],
          warned_at: Time.current
        )

        # Log the action
        ModerationAction.log_action(
          action_type: 'warn',
          moderator_discord_id: params[:moderator_discord_id],
          target_discord_id: params[:discord_id],
          guild_id: params[:guild_id],
          user: user,
          reason: params[:reason],
          metadata: { warning_id: warning.id }
        )

        warning_count = UserWarning.count_for_user(params[:discord_id], params[:guild_id])

        render_success({
          warning: {
            id: warning.id,
            discord_id: warning.discord_id,
            reason: warning.reason,
            warned_at: warning.warned_at,
            total_warnings: warning_count
          }
        }, status: :created)
      rescue StandardError => e
        render_error(e.message)
      end

      # GET /api/v1/moderation/warnings/:discord_id
      # Get warnings for a user
      def warnings
        warnings = UserWarning.recent_for_user(
          params[:discord_id],
          params[:guild_id],
          params[:limit] || 10
        )

        warning_count = UserWarning.count_for_user(params[:discord_id], params[:guild_id])

        warnings_data = warnings.map do |w|
          {
            id: w.id,
            reason: w.reason,
            moderator_discord_id: w.moderator_discord_id,
            warned_at: w.warned_at
          }
        end

        render_success({
          discord_id: params[:discord_id],
          guild_id: params[:guild_id],
          total_warnings: warning_count,
          warnings: warnings_data
        })
      end

      # DELETE /api/v1/moderation/warnings/:discord_id
      # Clear all warnings for a user
      def clear_warnings
        user = find_user_by_discord_id(params[:discord_id])
        count = UserWarning.for_user(params[:discord_id]).for_guild(params[:guild_id]).count

        UserWarning.clear_for_user(params[:discord_id], params[:guild_id])

        # Log the action
        ModerationAction.log_action(
          action_type: 'warn', # Using 'warn' type with metadata to indicate clearing
          moderator_discord_id: params[:moderator_discord_id],
          target_discord_id: params[:discord_id],
          guild_id: params[:guild_id],
          user: user,
          reason: "Cleared #{count} warnings",
          metadata: { action: 'clear_warnings', count: count }
        )

        render_success({
          message: "Cleared #{count} warnings",
          discord_id: params[:discord_id],
          guild_id: params[:guild_id]
        })
      rescue StandardError => e
        render_error(e.message)
      end

      # POST /api/v1/moderation/mute
      # Mute a user
      def mute
        user = find_or_create_user_by_discord_id(params[:discord_id])

        # Check if already muted
        existing_mute = UserMute.active_for_user(params[:discord_id], params[:guild_id])
        if existing_mute
          render_error('User is already muted', status: :unprocessable_entity)
          return
        end

        mute = UserMute.create!(
          user: user,
          discord_id: params[:discord_id],
          moderator_discord_id: params[:moderator_discord_id],
          guild_id: params[:guild_id],
          reason: params[:reason],
          duration_minutes: params[:duration_minutes].to_i,
          muted_at: Time.current,
          active: true
        )

        # Log the action
        ModerationAction.log_action(
          action_type: 'mute',
          moderator_discord_id: params[:moderator_discord_id],
          target_discord_id: params[:discord_id],
          guild_id: params[:guild_id],
          user: user,
          reason: params[:reason],
          metadata: {
            mute_id: mute.id,
            duration_minutes: params[:duration_minutes].to_i,
            ends_at: mute.ends_at
          }
        )

        render_success({
          mute: {
            id: mute.id,
            discord_id: mute.discord_id,
            reason: mute.reason,
            duration_minutes: mute.duration_minutes,
            muted_at: mute.muted_at,
            ends_at: mute.ends_at,
            active: mute.active
          }
        }, status: :created)
      rescue StandardError => e
        render_error(e.message)
      end

      # POST /api/v1/moderation/unmute
      # Unmute a user
      def unmute
        user = find_user_by_discord_id(params[:discord_id])
        mute = UserMute.active_for_user(params[:discord_id], params[:guild_id])

        unless mute
          render_error('No active mute found for this user', status: :not_found)
          return
        end

        mute.unmute!

        # Log the action
        ModerationAction.log_action(
          action_type: 'unmute',
          moderator_discord_id: params[:moderator_discord_id],
          target_discord_id: params[:discord_id],
          guild_id: params[:guild_id],
          user: user,
          reason: params[:reason] || 'Manual unmute',
          metadata: { mute_id: mute.id }
        )

        render_success({
          message: 'User unmuted successfully',
          discord_id: params[:discord_id],
          guild_id: params[:guild_id]
        })
      rescue StandardError => e
        render_error(e.message)
      end

      # GET /api/v1/moderation/mutes/active
      # Get all active mutes for a guild
      def active_mutes
        mutes = UserMute.for_guild(params[:guild_id])
                        .active_mutes
                        .where('muted_at + (duration_minutes * interval \'1 minute\') > ?', Time.current)
                        .recent

        mutes_data = mutes.map do |m|
          {
            id: m.id,
            discord_id: m.discord_id,
            moderator_discord_id: m.moderator_discord_id,
            reason: m.reason,
            duration_minutes: m.duration_minutes,
            muted_at: m.muted_at,
            ends_at: m.ends_at,
            time_remaining_minutes: m.time_remaining
          }
        end

        render_success({
          guild_id: params[:guild_id],
          active_mutes: mutes_data,
          count: mutes_data.length
        })
      end

      # GET /api/v1/moderation/mutes/:discord_id
      # Check if user is muted
      def check_mute
        mute = UserMute.active_for_user(params[:discord_id], params[:guild_id])

        if mute
          render_success({
            is_muted: true,
            mute: {
              id: mute.id,
              reason: mute.reason,
              moderator_discord_id: mute.moderator_discord_id,
              muted_at: mute.muted_at,
              ends_at: mute.ends_at,
              time_remaining_minutes: mute.time_remaining
            }
          })
        else
          render_success({
            is_muted: false,
            mute: nil
          })
        end
      end

      # POST /api/v1/moderation/action
      # Log a moderation action (kick, ban, etc.)
      def log_action
        user = find_or_create_user_by_discord_id(params[:target_discord_id])

        action = ModerationAction.log_action(
          action_type: params[:action_type],
          moderator_discord_id: params[:moderator_discord_id],
          target_discord_id: params[:target_discord_id],
          guild_id: params[:guild_id],
          user: user,
          reason: params[:reason],
          metadata: params[:metadata] || {}
        )

        render_success({
          action: {
            id: action.id,
            action_type: action.action_type,
            target_discord_id: action.target_discord_id,
            moderator_discord_id: action.moderator_discord_id,
            reason: action.reason,
            performed_at: action.performed_at
          }
        }, status: :created)
      rescue StandardError => e
        render_error(e.message)
      end

      # GET /api/v1/moderation/actions
      # Get moderation actions log
      def actions
        actions = ModerationAction.for_guild(params[:guild_id])
                                   .recent
                                   .limit(params[:limit] || 50)

        actions = actions.for_target(params[:target_discord_id]) if params[:target_discord_id].present?
        actions = actions.by_type(params[:action_type]) if params[:action_type].present?

        actions_data = actions.map do |a|
          {
            id: a.id,
            action_type: a.action_type,
            target_discord_id: a.target_discord_id,
            moderator_discord_id: a.moderator_discord_id,
            reason: a.reason,
            metadata: a.metadata,
            performed_at: a.performed_at
          }
        end

        render_success({
          guild_id: params[:guild_id],
          actions: actions_data,
          count: actions_data.length
        })
      end

      private

      def find_user_by_discord_id(discord_id)
        User.joins(:discord_account).find_by(discord_accounts: { discord_id: discord_id })
      end

      def find_or_create_user_by_discord_id(discord_id)
        find_user_by_discord_id(discord_id)
        # If user doesn't exist, we'll allow operations without a User record
        # since Discord users might not have signed up for StreamHub yet
      end
    end
  end
end
