# frozen_string_literal: true

module Analytics
  class InsightsGenerator
    attr_reader :user, :metrics

    def initialize(user, metrics)
      @user = user
      @metrics = metrics
    end

    # Generate all insights
    def generate_all
      insights = []

      insights << generate_growth_insights
      insights << generate_engagement_insights
      insights << generate_consistency_insights
      insights << generate_performance_insights
      insights << generate_content_insights

      insights.flatten.compact.sort_by { |i| -priority_score(i[:priority]) }
    end

    private

    # Growth insights
    def generate_growth_insights
      growth = metrics[:growth]
      insights = []

      # Follower growth insight
      if growth[:follower_growth_rate] > 20
        insights << {
          type: 'growth',
          priority: 'high',
          title: 'Strong Follower Growth! 🚀',
          description: "Your follower count is up #{growth[:follower_growth_rate].round}% this week",
          context: "You gained #{growth[:total_followers_gained]} followers - that's #{compare_to_average(growth[:follower_growth_rate], 10)} average growth",
          recommendation: "Keep doing what you're doing! Your content is resonating with viewers.",
          data: { growth_rate: growth[:follower_growth_rate], total_gained: growth[:total_followers_gained] }
        }
      elsif growth[:follower_growth_rate] < -10
        insights << {
          type: 'growth',
          priority: 'medium',
          title: 'Follower Growth Slowing',
          description: "Follower growth is down #{growth[:follower_growth_rate].abs.round}% this week",
          context: "This might be a temporary dip - let's focus on engagement",
          recommendation: "Try interacting more with chat and running a giveaway to boost interest.",
          data: { growth_rate: growth[:follower_growth_rate] }
        }
      end

      # Viewer growth insight
      if growth[:viewer_growth_rate] > 15
        insights << {
          type: 'growth',
          priority: 'high',
          title: 'Viewer Count Growing! 📈',
          description: "Average viewers up #{growth[:viewer_growth_rate].round}% from last week",
          context: "Your streams are attracting more people",
          recommendation: "This is momentum - stream more consistently to capitalize on it.",
          data: { growth_rate: growth[:viewer_growth_rate] }
        }
      end

      insights
    end

    # Engagement insights
    def generate_engagement_insights
      engagement = metrics[:engagement]
      insights = []

      # Engagement score insight
      if engagement[:engagement_score] > 70
        insights << {
          type: 'engagement',
          priority: 'high',
          title: 'Excellent Chat Engagement! 💬',
          description: "Your engagement score is #{engagement[:engagement_score].round} (out of 100)",
          context: "Your chat is very active - viewers are invested in your content",
          recommendation: "Keep encouraging chat interaction. Consider chat-driven content ideas.",
          data: { score: engagement[:engagement_score] }
        }
      elsif engagement[:engagement_score] < 30
        insights << {
          type: 'engagement',
          priority: 'medium',
          title: 'Chat Could Be More Active',
          description: "Your engagement score is #{engagement[:engagement_score].round} - there's room to improve",
          context: "#{engagement[:chat_participation_rate].round}% of viewers are chatting",
          recommendation: "Ask more questions, run polls, or react to chat messages more actively.",
          data: { score: engagement[:engagement_score], participation_rate: engagement[:chat_participation_rate] }
        }
      end

      # Chat participation insight
      if engagement[:chat_participation_rate] > 50
        insights << {
          type: 'engagement',
          priority: 'medium',
          title: 'Great Chat Participation',
          description: "#{engagement[:chat_participation_rate].round}% of viewers are chatting",
          context: "Most platforms see 20-30% participation - you're doing great",
          recommendation: "Your community is engaged. Consider creating VIP roles for active chatters.",
          data: { participation_rate: engagement[:chat_participation_rate] }
        }
      end

      insights
    end

    # Consistency insights
    def generate_consistency_insights
      consistency = metrics[:consistency]
      insights = []

      # Consistency score insight
      if consistency[:consistency_score] > 70
        insights << {
          type: 'consistency',
          priority: 'high',
          title: 'Excellent Streaming Consistency! ⭐',
          description: "You streamed #{consistency[:days_streamed]} of the last #{consistency[:total_days]} days (#{consistency[:consistency_score].round}%)",
          context: "Consistency builds audience loyalty and helps with discovery",
          recommendation: "Your schedule is solid. Consider letting viewers know your next stream time.",
          data: { consistency_score: consistency[:consistency_score], days_streamed: consistency[:days_streamed] }
        }
      elsif consistency[:consistency_score] < 40
        insights << {
          type: 'consistency',
          priority: 'high',
          title: 'Stream More Consistently',
          description: "You streamed only #{consistency[:days_streamed]} of the last #{consistency[:total_days]} days (#{consistency[:consistency_score].round}%)",
          context: "Viewers need predictability to know when to tune in",
          recommendation: "Try to set a regular schedule (e.g., Mon/Wed/Fri at 8 PM). Even 3 days/week helps.",
          data: { consistency_score: consistency[:consistency_score], days_streamed: consistency[:days_streamed] }
        }
      end

      # Stream duration insight
      if consistency[:avg_stream_duration_hours] > 0
        if consistency[:avg_stream_duration_hours] < 2
          insights << {
            type: 'consistency',
            priority: 'medium',
            title: 'Consider Streaming Longer',
            description: "Your average stream is #{consistency[:avg_stream_duration_hours].round(1)} hours",
            context: "Viewers often arrive late or need time to discover your stream",
            recommendation: "Try extending to 2-3 hours to give viewers more time to find you.",
            data: { avg_duration: consistency[:avg_stream_duration_hours] }
          }
        elsif consistency[:avg_stream_duration_hours] > 6
          insights << {
            type: 'consistency',
            priority: 'low',
            title: 'Watch Out for Burnout',
            description: "Your average stream is #{consistency[:avg_stream_duration_hours].round(1)} hours",
            context: "Long streams are great, but sustainability matters",
            recommendation: "Make sure you're taking breaks and not burning out. Quality > quantity.",
            data: { avg_duration: consistency[:avg_stream_duration_hours] }
          }
        end
      end

      insights
    end

    # Performance insights
    def generate_performance_insights
      performance = metrics[:performance]
      insights = []

      # Viewer count comparison
      current = performance[:avg_viewers_current]
      previous = performance[:avg_viewers_previous]

      if current > previous && previous > 0
        change_pct = ((current - previous).to_f / previous * 100).round
        insights << {
          type: 'performance',
          priority: 'high',
          title: 'Viewership Trending Up! 🎉',
          description: "Averaging #{current} viewers (up #{change_pct}% from #{previous} last week)",
          context: "Your recent streams are performing better",
          recommendation: "Analyze what changed - game choice, stream time, or content style?",
          data: { current: current, previous: previous, change_pct: change_pct }
        }
      elsif current < previous && previous > 0
        change_pct = ((previous - current).to_f / previous * 100).round
        insights << {
          type: 'performance',
          priority: 'medium',
          title: 'Viewership Dipped This Week',
          description: "Averaging #{current} viewers (down #{change_pct}% from #{previous})",
          context: "This could be timing, game choice, or just variance",
          recommendation: "Try switching games or adjusting your stream time to see if that helps.",
          data: { current: current, previous: previous, change_pct: change_pct }
        }
      end

      # Best stream time insight
      if performance[:best_stream_time] != 'N/A'
        insights << {
          type: 'performance',
          priority: 'medium',
          title: 'Peak Performance Time Identified',
          description: "Your best streams are around #{performance[:best_stream_time]}",
          context: "This is when you get the most viewers on average",
          recommendation: "Try to stream during or near this time window more often.",
          data: { best_time: performance[:best_stream_time] }
        }
      end

      # Viewer retention
      if performance[:viewer_retention_score] > 70
        insights << {
          type: 'performance',
          priority: 'high',
          title: 'Great Viewer Retention! 🎯',
          description: "#{performance[:viewer_retention_score].round}% of viewers stick around throughout your streams",
          context: "High retention means people enjoy your content and stay engaged",
          recommendation: "Your content is working - keep it up!",
          data: { retention_score: performance[:viewer_retention_score] }
        }
      elsif performance[:viewer_retention_score] < 40 && performance[:viewer_retention_score] > 0
        insights << {
          type: 'performance',
          priority: 'medium',
          title: 'Work on Viewer Retention',
          description: "Only #{performance[:viewer_retention_score].round}% of viewers stay for your full stream",
          context: "People are clicking in but leaving early",
          recommendation: "Keep energy up throughout, tease upcoming segments, and avoid long quiet periods.",
          data: { retention_score: performance[:viewer_retention_score] }
        }
      end

      insights
    end

    # Content insights
    def generate_content_insights
      content = metrics[:content]
      insights = []

      # Game variety
      games_count = content[:total_games_played]

      if games_count == 1
        insights << {
          type: 'content',
          priority: 'low',
          title: 'Single Game Focus',
          description: "You're playing only one game",
          context: "Specializing can build a dedicated audience, but variety can attract new viewers",
          recommendation: "Consider trying 1-2 other games occasionally to test engagement.",
          data: { games_played: games_count }
        }
      elsif games_count > 5
        insights << {
          type: 'content',
          priority: 'medium',
          title: 'High Game Variety',
          description: "You played #{games_count} different games",
          context: "Variety attracts different audiences but can make it harder to build consistency",
          recommendation: "Consider focusing on your top 2-3 performing games.",
          data: { games_played: games_count }
        }
      end

      # Best performing game
      if content[:most_played_game]
        game = content[:most_played_game]
        insights << {
          type: 'content',
          priority: 'medium',
          title: "#{game[:name]} Is Your Go-To Game",
          description: "You've streamed #{game[:name]} for #{game[:total_hours].round(1)} hours (#{game[:sessions_count]} sessions)",
          context: "This is your most-played game",
          recommendation: "If this game performs well viewer-wise, lean into it. If not, consider shifting focus.",
          data: game
        }
      end

      insights
    end

    # Helper methods
    def compare_to_average(value, average)
      if value > average * 1.5
        "well above"
      elsif value > average
        "above"
      elsif value < average * 0.5
        "well below"
      else
        "below"
      end
    end

    def priority_score(priority)
      case priority
      when 'high' then 3
      when 'medium' then 2
      when 'low' then 1
      else 0
      end
    end
  end
end
