module Api
  module V1
    class GoalsController < BaseController
      before_action :set_user, only: [:index, :create, :stats]
      before_action :set_goal, only: [:show, :update, :destroy, :update_progress, :complete, :pause, :resume, :abandon]

      # GET /api/v1/users/:user_id/goals
      def index
        goals = @user.goals.includes(:goal_steps, :goal_updates)

        # Filter by status if provided
        goals = goals.where(status: params[:status]) if params[:status].present?

        # Filter by goal_type if provided
        goals = goals.where(goal_type: params[:goal_type]) if params[:goal_type].present?

        # Default to recent order
        goals = goals.recent

        render_success({
          goals: goals.map { |goal| goal_json(goal) }
        })
      end

      # GET /api/v1/goals/:id
      def show
        render_success({ goal: goal_json(@goal, detailed: true) })
      end

      # POST /api/v1/users/:user_id/goals
      def create
        goal = @user.goals.build(goal_params)

        if goal.save
          render_success({ goal: goal_json(goal) }, status: :created)
        else
          render_error(goal.errors.full_messages.join(', '))
        end
      end

      # PATCH /api/v1/goals/:id
      def update
        if @goal.update(goal_params)
          render_success({ goal: goal_json(@goal) })
        else
          render_error(@goal.errors.full_messages.join(', '))
        end
      end

      # DELETE /api/v1/goals/:id
      def destroy
        @goal.destroy
        render_success({ message: 'Goal deleted successfully' })
      end

      # POST /api/v1/goals/:id/progress
      def update_progress
        new_value = params[:value].to_f
        note = params[:note]

        @goal.update_progress!(new_value, note: note)
        render_success({ goal: goal_json(@goal, detailed: true) })
      rescue StandardError => e
        render_error(e.message)
      end

      # POST /api/v1/goals/:id/complete
      def complete
        @goal.mark_completed!
        render_success({ goal: goal_json(@goal), message: 'Goal completed!' })
      rescue StandardError => e
        render_error(e.message)
      end

      # POST /api/v1/goals/:id/pause
      def pause
        @goal.pause!
        render_success({ goal: goal_json(@goal), message: 'Goal paused' })
      rescue StandardError => e
        render_error(e.message)
      end

      # POST /api/v1/goals/:id/resume
      def resume
        @goal.resume!
        render_success({ goal: goal_json(@goal), message: 'Goal resumed' })
      rescue StandardError => e
        render_error(e.message)
      end

      # POST /api/v1/goals/:id/abandon
      def abandon
        @goal.abandon!
        render_success({ goal: goal_json(@goal), message: 'Goal abandoned' })
      rescue StandardError => e
        render_error(e.message)
      end

      # GET /api/v1/users/:user_id/goals/stats
      def stats
        goals = @user.goals
        active_goals = goals.active
        completed_goals = goals.completed

        render_success({
          total_goals: goals.count,
          active_goals: active_goals.count,
          completed_goals: completed_goals.count,
          draft_goals: goals.draft.count,
          paused_goals: goals.paused.count,
          completion_rate: goals.count.zero? ? 0 : (completed_goals.count.to_f / goals.count * 100).round(2),
          goals_by_type: {
            growth: goals.growth.count,
            content: goals.content.count,
            skill: goals.skill.count,
            business: goals.business.count,
            community: goals.community.count,
            personal: goals.personal.count
          },
          recent_completions: completed_goals.limit(5).map { |goal| goal_json(goal) }
        })
      end

      private

      def set_user
        @user = User.find_by(id: params[:user_id])
        render_error('User not found', status: :not_found) unless @user
      end

      def set_goal
        @goal = Goal.includes(:goal_steps, :goal_updates).find_by(id: params[:id])

        unless @goal
          render_error('Goal not found', status: :not_found)
          return
        end
      end

      def goal_params
        params.require(:goal).permit(
          :title,
          :description,
          :goal_type,
          :status,
          :progress_type,
          :current_value,
          :target_value,
          :deadline,
          :visibility,
          metadata: {}
        )
      end

      def goal_json(goal, detailed: false)
        json = {
          id: goal.id,
          title: goal.title,
          description: goal.description,
          goal_type: goal.goal_type,
          status: goal.status,
          progress_type: goal.progress_type,
          current_value: goal.current_value,
          target_value: goal.target_value,
          progress_percentage: goal.progress_percentage,
          deadline: goal.deadline,
          days_until_deadline: goal.days_until_deadline,
          days_active: goal.days_active,
          overdue: goal.overdue?,
          on_track: goal.on_track?,
          visibility: goal.visibility,
          emoji_type: goal.emoji_for_type,
          emoji_status: goal.emoji_for_status,
          started_at: goal.started_at,
          completed_at: goal.completed_at,
          created_at: goal.created_at,
          updated_at: goal.updated_at
        }

        if detailed
          json.merge!({
            steps: goal.goal_steps.ordered.map { |step| step_json(step) },
            steps_progress: goal.steps_progress,
            recent_updates: goal.goal_updates.recent.limit(10).map { |update| update_json(update) }
          })
        end

        json
      end

      def step_json(step)
        {
          id: step.id,
          title: step.title,
          position: step.position,
          completed: step.completed,
          created_at: step.created_at
        }
      end

      def update_json(update)
        {
          id: update.id,
          update_type: update.update_type,
          value_before: update.value_before,
          value_after: update.value_after,
          progress_delta: update.progress_delta,
          note: update.note,
          created_at: update.created_at
        }
      end
    end
  end
end