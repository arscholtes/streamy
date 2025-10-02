module Api
  module V1
    class VcQueueController < BaseController
      def index
        queue = VcQueueEntry.waiting.by_priority

        render_success({
          queue: queue.map do |entry|
            {
              id: entry.id,
              user_id: entry.user.id,
              username: entry.user.username,
              discord_user_id: entry.discord_user_id,
              priority: entry.priority,
              position: entry.position,
              wait_time: entry.wait_time,
              joined_at: entry.joined_at
            }
          end
        })
      end

      def join
        user = User.find_by(id: params[:user_id])

        unless user
          render_error('User not found', status: :not_found)
          return
        end

        # Check if already in queue
        existing = VcQueueEntry.waiting.find_by(user: user)
        if existing
          render_error('Already in queue')
          return
        end

        # Calculate priority
        priority = VcQueueEntry.calculate_priority(user)

        # Get next position
        max_position = VcQueueEntry.waiting.maximum(:position) || 0

        entry = VcQueueEntry.create!(
          user: user,
          discord_user_id: params[:discord_user_id],
          priority: params[:priority] || priority,
          position: max_position + 1,
          status: 'waiting',
          joined_at: Time.current
        )

        render_success({
          queue_entry: {
            id: entry.id,
            position: entry.position,
            priority: entry.priority,
            joined_at: entry.joined_at
          }
        }, status: :created)
      rescue ActiveRecord::RecordInvalid => e
        render_error(e.message)
      end

      def leave
        user = User.find_by(id: params[:user_id])

        unless user
          render_error('User not found', status: :not_found)
          return
        end

        entry = VcQueueEntry.waiting.find_by(user: user)

        unless entry
          render_error('Not in queue', status: :not_found)
          return
        end

        entry.mark_cancelled!

        render_success({ message: 'Left queue successfully' })
      end

      def next_in_queue
        entry = VcQueueEntry.waiting.by_priority.first

        if entry
          entry.mark_active!

          render_success({
            user: {
              id: entry.user.id,
              username: entry.user.username,
              discord_user_id: entry.discord_user_id
            }
          })
        else
          render_error('Queue is empty', status: :not_found)
        end
      end
    end
  end
end
