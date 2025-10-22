class CreateStreamMetricSnapshots < ActiveRecord::Migration[8.0]
  def change
    create_table :stream_metric_snapshots do |t|
      t.references :stream, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.datetime :snapshot_at, null: false
      t.integer :viewer_count, null: false, default: 0
      t.integer :chat_messages_count, null: false, default: 0
      t.float :chat_rate, null: false, default: 0.0 # messages per minute
      t.integer :peak_viewers, null: false, default: 0
      t.integer :unique_chatters, null: false, default: 0
      t.json :metadata, null: false

      t.timestamps
    end

    add_index :stream_metric_snapshots, :snapshot_at
    add_index :stream_metric_snapshots, [:stream_id, :snapshot_at]
    add_index :stream_metric_snapshots, [:user_id, :snapshot_at]
  end
end
