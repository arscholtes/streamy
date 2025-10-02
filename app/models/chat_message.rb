class ChatMessage < ApplicationRecord
  belongs_to :user
  belongs_to :stream

  validates :content, presence: true, length: { maximum: 500 }

  # Scopes
  scope :recent, -> { order(created_at: :desc).limit(100) }

  # Broadcast message to stream's chat channel after creation
  after_create_commit do
    broadcast_append_to "stream_#{stream_id}_chat",
                        target: "chat-messages",
                        partial: "chat_messages/message",
                        locals: { message: self }
  end
end
