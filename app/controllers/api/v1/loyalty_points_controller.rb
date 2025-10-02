module Api
  module V1
    class LoyaltyPointsController < BaseController
      before_action :set_user

      def show
        loyalty_points = @user.loyalty_point || @user.create_loyalty_point!

        render_success({
          loyalty_points: {
            points: loyalty_points.points,
            level: loyalty_points.level,
            total_earned: loyalty_points.total_earned,
            total_spent: loyalty_points.total_spent,
            points_to_next_level: loyalty_points.points_to_next_level
          }
        })
      end

      def add
        loyalty_points = @user.loyalty_point || @user.create_loyalty_point!

        success = loyalty_points.add_points(
          params[:amount].to_i,
          description: params[:description],
          transaction_type: params[:transaction_type] || 'earned_custom',
          metadata: params[:metadata] || {}
        )

        if success
          render_success({
            loyalty_points: {
              points: loyalty_points.points,
              level: loyalty_points.level,
              total_earned: loyalty_points.total_earned
            }
          })
        else
          render_error('Failed to add points')
        end
      rescue StandardError => e
        render_error(e.message)
      end

      def spend
        loyalty_points = @user.loyalty_point

        unless loyalty_points
          render_error('User has no loyalty points', status: :not_found)
          return
        end

        success = loyalty_points.spend_points(
          params[:amount].to_i,
          description: params[:description],
          transaction_type: params[:transaction_type] || 'spent_custom',
          metadata: params[:metadata] || {}
        )

        if success
          render_success({
            loyalty_points: {
              points: loyalty_points.points,
              level: loyalty_points.level,
              total_spent: loyalty_points.total_spent
            }
          })
        else
          render_error('Insufficient points or invalid amount')
        end
      rescue StandardError => e
        render_error(e.message)
      end

      def leaderboard
        top_users = LoyaltyPoint.includes(:user)
                                .order(total_earned: :desc)
                                .limit(params[:limit] || 10)

        leaderboard_data = top_users.map.with_index(1) do |lp, rank|
          {
            rank: rank,
            user_id: lp.user.id,
            username: lp.user.username,
            points: lp.points,
            level: lp.level,
            total_earned: lp.total_earned
          }
        end

        render_success({ leaderboard: leaderboard_data })
      end

      private

      def set_user
        @user = User.find_by(id: params[:user_id])

        unless @user
          render_error('User not found', status: :not_found)
        end
      end
    end
  end
end
