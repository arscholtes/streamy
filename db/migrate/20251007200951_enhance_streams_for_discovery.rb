class EnhanceStreamsForDiscovery < ActiveRecord::Migration[8.0]
  def change
    add_column :streams, :category, :string
    add_column :streams, :tags, :json, default: []
    add_column :streams, :thumbnail_url, :string
    add_column :streams, :language, :string, default: 'en'

    # Indexes for better query performance
    add_index :streams, :category
    add_index :streams, :viewer_count
    add_index :streams, :started_at
    # Note: SQLite doesn't support GIN indexes (PostgreSQL-specific)
  end
end
