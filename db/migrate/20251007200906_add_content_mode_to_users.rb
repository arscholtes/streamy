class AddContentModeToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :content_mode, :string, default: 'streamer', null: false
    add_index :users, :content_mode
  end
end
