module Api
  module V1
    class UsersController < BaseController
      def show_by_discord_id
        discord_account = DiscordAccount.find_by(discord_id: params[:discord_id])

        if discord_account
          render_success({
            user: {
              id: discord_account.user.id,
              username: discord_account.user.username,
              email: discord_account.user.email,
              subscription_tier: discord_account.user.subscription_tier,
              discord_id: discord_account.discord_id,
              discord_username: discord_account.username
            }
          })
        else
          render_error('User not found', status: :not_found)
        end
      end

      def create
        # Create user and link Discord account
        user = User.create!(
          username: params[:username],
          email: params[:email],
          password: SecureRandom.hex(32), # Random password since they use Discord OAuth
          subscription_tier: 'free'
        )

        discord_account = user.create_discord_account!(
          discord_id: params[:discord_id],
          username: params[:username]
        )

        # Initialize loyalty points
        user.create_loyalty_point!

        render_success({
          user: {
            id: user.id,
            username: user.username,
            email: user.email,
            subscription_tier: user.subscription_tier,
            discord_id: discord_account.discord_id
          }
        }, status: :created)
      rescue ActiveRecord::RecordInvalid => e
        render_error(e.message)
      end
    end
  end
end
