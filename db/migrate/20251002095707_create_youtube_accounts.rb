class CreateYoutubeAccounts < ActiveRecord::Migration[8.0]
  def change
    create_table :youtube_accounts do |t|
      t.references :user, null: false, foreign_key: true
      t.string :youtube_id
      t.string :channel_title
      t.string :channel_url
      t.integer :subscriber_count
      t.integer :video_count
      t.string :thumbnail_url
      t.string :access_token
      t.string :refresh_token
      t.datetime :token_expires_at
      t.datetime :last_synced_at

      t.timestamps
    end
    add_index :youtube_accounts, :youtube_id, unique: true
  end
end
