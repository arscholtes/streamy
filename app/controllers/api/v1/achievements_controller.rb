module Api
  module V1
    class AchievementsController < BaseController
      def index
        achievements = Achievement.ordered

        render_success({
          achievements: achievements.map do |achievement|
            {
              id: achievement.id,
              name: achievement.name,
              description: achievement.description,
              category: achievement.category,
              points_reward: achievement.points_reward,
              icon: achievement.icon
            }
          end
        })
      end

      def user_achievements
        user = User.find_by(id: params[:user_id])

        unless user
          render_error('User not found', status: :not_found)
          return
        end

        user_achievements = user.user_achievements.includes(:achievement).earned

        render_success({
          achievements: user_achievements.map do |ua|
            {
              id: ua.achievement.id,
              name: ua.achievement.name,
              description: ua.achievement.description,
              category: ua.achievement.category,
              points_reward: ua.achievement.points_reward,
              earned_at: ua.earned_at,
              icon: ua.achievement.icon
            }
          end
        })
      end

      def award
        user = User.find_by(id: params[:user_id])
        achievement = Achievement.find_by(id: params[:achievement_id])

        unless user
          render_error('User not found', status: :not_found)
          return
        end

        unless achievement
          render_error('Achievement not found', status: :not_found)
          return
        end

        user_achievement = achievement.award_to(user)

        if user_achievement
          render_success({
            achievement: {
              id: achievement.id,
              name: achievement.name,
              points_reward: achievement.points_reward,
              earned_at: user_achievement.earned_at
            }
          }, status: :created)
        else
          render_error('Achievement already earned or error occurred')
        end
      rescue StandardError => e
        render_error(e.message)
      end
    end
  end
end
