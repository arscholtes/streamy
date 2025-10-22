class AddStreamTrackingFieldsToStreams < ActiveRecord::Migration[8.0]
  def change
    add_column :streams, :started_at, :datetime
    add_column :streams, :ended_at, :datetime
    add_column :streams, :duration_seconds, :integer, default: 0
    add_column :streams, :viewer_count, :integer, default: 0
  end
end
