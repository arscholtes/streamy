class CreateVcQueueEntries < ActiveRecord::Migration[8.0]
  def change
    create_table :vc_queue_entries do |t|
      t.references :user, null: false, foreign_key: true
      t.string :discord_user_id, null: false
      t.integer :priority, default: 0, null: false
      t.integer :position, null: false
      t.string :status, default: 'waiting', null: false
      t.datetime :joined_at, null: false
      t.datetime :left_at

      t.timestamps
    end

    add_index :vc_queue_entries, :discord_user_id
    add_index :vc_queue_entries, :status
    add_index :vc_queue_entries, [:status, :priority, :joined_at], name: 'index_vc_queue_on_status_priority_joined'
  end
end
