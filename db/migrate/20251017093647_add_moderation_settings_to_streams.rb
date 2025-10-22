class AddModerationSettingsToStreams < ActiveRecord::Migration[8.0]
  def change
    add_column :streams, :slow_mode, :boolean, default: false, null: false
    add_column :streams, :slow_mode_seconds, :integer, default: 5
    add_column :streams, :emote_only_mode, :boolean, default: false, null: false
    add_column :streams, :subscribers_only_mode, :boolean, default: false, null: false
    add_column :streams, :followers_only_mode, :boolean, default: false, null: false
  end
end
