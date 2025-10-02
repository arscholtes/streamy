class ChatMessagesController < ApplicationController
  before_action :require_login
  before_action :set_stream

  def create
    @message = @stream.chat_messages.build(message_params)
    @message.user = current_user

    if @message.save
      # Message will be broadcast via the after_create_commit callback in the model
      head :ok
    else
      render json: { errors: @message.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def set_stream
    @stream = Stream.find(params[:stream_id])
  end

  def message_params
    params.permit(:content)
  end
end
