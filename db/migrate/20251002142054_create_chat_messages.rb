class CreateChatMessages < ActiveRecord::Migration[8.0]
  def change
    create_table :chat_messages do |t|
      t.references :user, null: false, foreign_key: true
      t.references :stream, null: false, foreign_key: true
      t.text :content

      t.timestamps
    end
  end
end
