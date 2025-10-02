class ChatChannel < ApplicationCable::Channel
  def subscribed
    # Subscribe to the stream's chat channel
    stream = Stream.find(params[:stream_id])
    stream_from "stream_#{stream.id}_chat"
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
    stop_all_streams
  end

  def send_message(data)
    # Create a new chat message
    stream = Stream.find(params[:stream_id])
    message = stream.chat_messages.create!(
      user: current_user,
      content: data['content']
    )
  end

  private

  def current_user
    # Get the current user from the connection
    # This will be set in ApplicationCable::Connection
    connection.current_user
  end
end
