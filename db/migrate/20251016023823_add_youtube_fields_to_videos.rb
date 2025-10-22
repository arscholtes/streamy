class AddYoutubeFieldsToVideos < ActiveRecord::Migration[8.0]
  def change
    add_column :videos, :youtube_video_id, :string
    add_reference :videos, :youtube_account, null: true, foreign_key: true
    add_column :videos, :error_message, :text
    add_column :videos, :privacy_status, :string, default: 'unlisted'
    add_column :videos, :category_id, :string, default: '20' # Gaming category
    add_column :videos, :tags, :json, default: []

    add_index :videos, :youtube_video_id, unique: true
  end
end
