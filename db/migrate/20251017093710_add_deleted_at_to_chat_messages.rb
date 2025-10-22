class AddDeletedAtToChatMessages < ActiveRecord::Migration[8.0]
  def change
    add_column :chat_messages, :deleted_at, :datetime
    add_column :chat_messages, :deleted_by_id, :integer
    add_column :chat_messages, :deletion_reason, :text

    add_index :chat_messages, :deleted_at
    add_index :chat_messages, :deleted_by_id
    add_foreign_key :chat_messages, :users, column: :deleted_by_id
  end
end
