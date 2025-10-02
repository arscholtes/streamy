module Api
  module V1
    class MiniGamesController < BaseController
      def record
        user = User.find_by(id: params[:user_id])

        unless user
          render_error('User not found', status: :not_found)
          return
        end

        session = user.mini_game_sessions.create!(
          game_type: params[:game_type],
          bet_amount: params[:bet_amount],
          result: params[:result],
          winnings: params[:winnings],
          metadata: params[:metadata] || {},
          played_at: Time.current
        )

        # Handle points for wins/losses
        loyalty_points = user.loyalty_point || user.create_loyalty_point!

        if session.won?
          # Add winnings
          loyalty_points.add_points(
            session.profit,
            description: "Won #{session.game_type}",
            transaction_type: 'earned_minigame',
            metadata: { game_session_id: session.id }
          )
        else
          # Deduct bet (already spent)
          loyalty_points.spend_points(
            session.bet_amount,
            description: "Lost #{session.game_type}",
            transaction_type: 'spent_minigame',
            metadata: { game_session_id: session.id }
          )
        end

        render_success({
          session: {
            id: session.id,
            game_type: session.game_type,
            result: session.result,
            profit: session.profit,
            new_balance: loyalty_points.points
          }
        }, status: :created)
      rescue ActiveRecord::RecordInvalid => e
        render_error(e.message)
      end

      def stats
        user = User.find_by(id: params[:user_id])

        unless user
          render_error('User not found', status: :not_found)
          return
        end

        sessions = user.mini_game_sessions
        sessions = sessions.by_game(params[:game_type]) if params[:game_type]

        total_games = sessions.count
        total_won = sessions.wins.count
        total_lost = sessions.losses.count
        total_wagered = sessions.sum(:bet_amount)
        total_winnings = sessions.sum(:winnings)
        net_profit = total_winnings - total_wagered

        render_success({
          stats: {
            total_games: total_games,
            total_won: total_won,
            total_lost: total_lost,
            win_rate: total_games > 0 ? (total_won.to_f / total_games * 100).round(2) : 0,
            total_wagered: total_wagered,
            total_winnings: total_winnings,
            net_profit: net_profit
          }
        })
      end
    end
  end
end
