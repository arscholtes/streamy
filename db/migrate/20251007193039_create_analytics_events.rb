class CreateAnalyticsEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :analytics_events do |t|
      t.references :user, null: false, foreign_key: true
      t.references :stream, null: true, foreign_key: true
      t.string :event_type, null: false
      t.json :event_data, null: false
      t.datetime :occurred_at, null: false

      t.timestamps
    end

    add_index :analytics_events, :event_type
    add_index :analytics_events, :occurred_at
    add_index :analytics_events, [:user_id, :occurred_at]
  end
end
