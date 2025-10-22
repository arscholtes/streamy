class CreateStreamModerators < ActiveRecord::Migration[8.0]
  def change
    create_table :stream_moderators do |t|
      t.references :user, null: false, foreign_key: true
      t.references :stream, null: false, foreign_key: true
      t.references :moderator_role, null: false, foreign_key: true
      t.datetime :appointed_at, null: false
      t.integer :appointed_by_id
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :stream_moderators, [:user_id, :stream_id], unique: true
    add_index :stream_moderators, :appointed_by_id
    add_foreign_key :stream_moderators, :users, column: :appointed_by_id
  end
end
