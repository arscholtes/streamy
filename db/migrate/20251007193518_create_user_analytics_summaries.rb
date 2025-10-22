class CreateUserAnalyticsSummaries < ActiveRecord::Migration[8.0]
  def change
    create_table :user_analytics_summaries do |t|
      t.references :user, null: false, foreign_key: true
      t.string :period_type, null: false # 'daily', 'weekly', 'monthly'
      t.date :period_start, null: false
      t.date :period_end, null: false
      t.json :metrics, null: false
      t.json :insights, null: false
      t.json :metadata, null: false

      t.timestamps
    end

    add_index :user_analytics_summaries, :period_type
    add_index :user_analytics_summaries, [:user_id, :period_type, :period_start], unique: true, name: 'index_user_analytics_on_user_period_start'
    add_index :user_analytics_summaries, [:period_start, :period_end]
  end
end
