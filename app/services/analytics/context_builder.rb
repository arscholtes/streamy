# frozen_string_literal: true

module Analytics
  class ContextBuilder
    attr_reader :user, :metrics, :insights

    def initialize(user, metrics, insights)
      @user = user
      @metrics = metrics
      @insights = insights
    end

    # Build full context with storytelling
    def build_context
      {
        user_info: build_user_context,
        journey_summary: build_journey_summary,
        current_chapter: determine_current_chapter,
        insights_with_context: contextualize_insights,
        milestones: recent_milestones,
        predictions: build_predictions
      }
    end

    private

    def build_user_context
      {
        username: user.username,
        account_created: user.created_at.to_date,
        days_on_platform: (Date.today - user.created_at.to_date).to_i,
        total_streams: user.streams.count,
        total_hours_streamed: metrics[:consistency][:total_hours_streamed]
      }
    end

    def build_journey_summary
      consistency = metrics[:consistency]
      growth = metrics[:growth]
      engagement = metrics[:engagement]

      {
        narrative: generate_journey_narrative,
        stats: {
          days_streamed: consistency[:days_streamed],
          total_hours: consistency[:total_hours_streamed].round(1),
          followers_gained: growth[:total_followers_gained],
          total_messages: engagement[:total_chat_messages],
          engagement_score: engagement[:engagement_score].round
        }
      }
    end

    def generate_journey_narrative
      consistency = metrics[:consistency]
      growth = metrics[:growth]

      hours = consistency[:total_hours_streamed].round(1)
      days = consistency[:days_streamed]
      followers = growth[:total_followers_gained]

      # Generate narrative based on actual data
      if days == 0
        "You haven't started streaming yet. Your journey begins now!"
      elsif days < 7
        "You're just getting started! #{days} #{days == 1 ? 'stream' : 'streams'} and #{hours} hours logged. Keep building momentum!"
      elsif days < 30
        "You're finding your rhythm. #{days} streams, #{hours} hours, and #{followers} new followers. The foundation is being built."
      elsif days < 90
        "You're becoming consistent! #{days} streams across #{hours} hours. Your community of #{followers} followers is growing."
      else
        "You're an established creator! #{days} streams, #{hours} hours, and #{followers} loyal followers. This is your legacy."
      end
    end

    def determine_current_chapter
      hours = metrics[:consistency][:total_hours_streamed]
      followers = metrics[:growth][:total_followers_gained]
      consistency = metrics[:consistency][:consistency_score]

      # Determine chapter based on multiple factors
      chapter = case
                when hours < 10 then 1 # The Beginning
                when hours < 50 && followers < 50 then 2 # Finding Your Voice
                when hours < 100 && followers < 100 then 3 # Building Momentum
                when hours < 200 && followers < 500 then 4 # The Breakthrough
                when hours < 500 && followers < 1000 then 5 # Established Creator
                when hours < 1000 && followers < 5000 then 6 # Rising Star
                when hours < 2000 && followers < 10000 then 7 # Content King/Queen
                else 8 # Streaming Legend
                end

      chapter_info(chapter)
    end

    def chapter_info(number)
      chapters = {
        1 => { name: 'The Beginning', emoji: '🌱', description: 'Every legend starts somewhere' },
        2 => { name: 'Finding Your Voice', emoji: '🎤', description: 'Discovering your unique style' },
        3 => { name: 'Building Momentum', emoji: '📈', description: 'Your community is growing' },
        4 => { name: 'The Breakthrough', emoji: '⚡', description: 'Something special is happening' },
        5 => { name: 'Established Creator', emoji: '🏆', description: "You're no longer a beginner" },
        6 => { name: 'Rising Star', emoji: '⭐', description: 'People are taking notice' },
        7 => { name: 'Content King/Queen', emoji: '👑', description: 'A force in your niche' },
        8 => { name: 'Streaming Legend', emoji: '🌟', description: "You've made it" }
      }

      chapters[number].merge(number: number)
    end

    def contextualize_insights
      insights.map do |insight|
        insight.merge(
          story_context: add_story_context(insight),
          next_steps: suggest_next_steps(insight)
        )
      end
    end

    def add_story_context(insight)
      # Add narrative framing based on insight type
      case insight[:type]
      when 'growth'
        "Your streaming journey is about growth, and this #{insight[:priority] == 'high' ? 'is a huge win' : 'is worth noting'}."
      when 'engagement'
        "Great streams are built on community connection. #{insight[:priority] == 'high' ? 'Your community loves interacting with you' : 'There\'s room to deepen connections'}."
      when 'consistency'
        "Consistency is how legends are built. #{insight[:priority] == 'high' ? 'You\'re showing up for your community' : 'Every stream gets you closer to your goals'}."
      when 'performance'
        "Understanding what works helps you level up. #{insight[:priority] == 'high' ? 'You\'re learning what resonates' : 'Experiment and find your edge'}."
      when 'content'
        "Your content defines your brand. #{insight[:priority] == 'high' ? 'You\'ve found something that works' : 'Keep exploring what fits you best'}."
      else
        "Every data point tells part of your story."
      end
    end

    def suggest_next_steps(insight)
      # Suggest actionable next steps beyond the recommendation
      case insight[:type]
      when 'growth'
        if insight[:priority] == 'high'
          ['Share your stream schedule on social media', 'Thank your new followers', 'Consider a follower celebration stream']
        else
          ['Review what worked in your best streams', 'Try a different game or content type', 'Engage more on social media']
        end
      when 'engagement'
        if insight[:priority] == 'high'
          ['Create VIP roles for active chatters', 'Run a community event or tournament', 'Feature chat messages on screen']
        else
          ['Ask questions throughout your stream', 'React to every chat message', 'Run polls or chat games']
        end
      when 'consistency'
        ['Set a fixed streaming schedule', 'Create a schedule graphic for social media', 'Use Discord/Twitter to announce streams']
      when 'performance'
        ['Analyze VODs from your best streams', 'Test different stream times', 'Track which games perform best']
      when 'content'
        ['Poll your community on what they want to see', 'Try a new format (speedruns, challenges)', 'Research trending games in your niche']
      else
        ['Keep experimenting', 'Stay consistent', 'Engage with your community']
      end
    end

    def recent_milestones
      # Get recent achievement events
      milestone_events = user.analytics_events
                             .where(event_type: ['achievement_unlocked', 'milestone_reached'])
                             .order(occurred_at: :desc)
                             .limit(5)

      milestone_events.map do |event|
        {
          type: event.event_type,
          title: event.event_data['achievement_name'] || event.event_data['milestone_type'],
          occurred_at: event.occurred_at,
          description: format_milestone_description(event)
        }
      end
    end

    def format_milestone_description(event)
      case event.event_type
      when 'achievement_unlocked'
        "Unlocked: #{event.event_data['achievement_name']}"
      when 'milestone_reached'
        "Reached: #{event.event_data['milestone_type']} - #{event.event_data['milestone_value']}"
      else
        'Special milestone'
      end
    end

    def build_predictions
      consistency = metrics[:consistency]
      growth = metrics[:growth]

      predictions = []

      # Predict follower milestone
      if growth[:follower_growth_rate] > 0
        current_followers = growth[:total_followers_gained]
        weekly_gain = current_followers / [consistency[:days_streamed] / 7.0, 1].max

        next_milestone = next_follower_milestone(current_followers)
        weeks_to_milestone = ((next_milestone - current_followers) / weekly_gain).ceil

        if weeks_to_milestone > 0 && weeks_to_milestone < 52
          predictions << {
            type: 'follower_milestone',
            milestone: next_milestone,
            estimated_weeks: weeks_to_milestone,
            description: "At your current pace, you'll hit #{next_milestone} followers in ~#{weeks_to_milestone} weeks"
          }
        end
      end

      # Predict streaming hours milestone
      if consistency[:days_streamed] > 0
        hours = consistency[:total_hours_streamed]
        hours_per_week = hours / [consistency[:days_streamed] / 7.0, 1].max

        next_hour_milestone = next_hours_milestone(hours)
        weeks_to_milestone = ((next_hour_milestone - hours) / hours_per_week).ceil

        if weeks_to_milestone > 0 && weeks_to_milestone < 52
          predictions << {
            type: 'hours_milestone',
            milestone: next_hour_milestone,
            estimated_weeks: weeks_to_milestone,
            description: "You'll reach #{next_hour_milestone} hours streamed in ~#{weeks_to_milestone} weeks"
          }
        end
      end

      predictions
    end

    def next_follower_milestone(current)
      milestones = [10, 25, 50, 100, 250, 500, 1000, 2500, 5000, 10000]
      milestones.find { |m| m > current } || (current + 10000)
    end

    def next_hours_milestone(current)
      milestones = [10, 25, 50, 100, 250, 500, 1000, 2000, 5000]
      milestones.find { |m| m > current } || (current + 1000)
    end
  end
end
