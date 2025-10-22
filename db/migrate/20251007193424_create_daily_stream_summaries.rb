class CreateDailyStreamSummaries < ActiveRecord::Migration[8.0]
  def change
    create_table :daily_stream_summaries do |t|
      t.references :user, null: false, foreign_key: true
      t.date :summary_date, null: false

      # Streaming metrics
      t.integer :total_stream_time_seconds, null: false, default: 0
      t.integer :stream_count, null: false, default: 0
      t.integer :peak_viewers, null: false, default: 0
      t.integer :avg_viewers, null: false, default: 0
      t.integer :unique_viewers, null: false, default: 0

      # Engagement metrics
      t.integer :total_chat_messages, null: false, default: 0
      t.integer :unique_chatters, null: false, default: 0
      t.float :avg_chat_rate, null: false, default: 0.0

      # Growth metrics
      t.integer :follower_count, null: false, default: 0
      t.integer :followers_gained, null: false, default: 0
      t.integer :followers_lost, null: false, default: 0

      # Revenue metrics (for future use)
      t.integer :subscriptions_gained, null: false, default: 0
      t.decimal :revenue_earned, precision: 10, scale: 2, default: 0.0

      # Additional data
      t.json :top_games, null: false
      t.json :metadata, null: false

      t.timestamps
    end

    add_index :daily_stream_summaries, :summary_date
    add_index :daily_stream_summaries, [:user_id, :summary_date], unique: true
  end
end
