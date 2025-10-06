require 'rails_helper'

RSpec.describe ChatMessagesController, type: :request do
  let(:user) { create(:user) }
  let(:stream) { create(:stream) }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    allow_any_instance_of(ApplicationController).to receive(:logged_in?).and_return(true)
  end

  describe 'POST /streams/:stream_id/chat_messages' do
    it 'creates chat message successfully' do
      expect {
        post stream_chat_messages_path(stream), params: { content: 'Hello chat!' }
      }.to change(ChatMessage, :count).by(1)

      expect(response).to have_http_status(:ok)

      message = ChatMessage.last
      expect(message.content).to eq('Hello chat!')
      expect(message.user).to eq(user)
      expect(message.stream).to eq(stream)
    end

    it 'returns errors for invalid message' do
      post stream_chat_messages_path(stream), params: { content: '' }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)).to have_key('errors')
    end

    it 'requires login' do
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(nil)
      allow_any_instance_of(ApplicationController).to receive(:logged_in?).and_return(false)

      post stream_chat_messages_path(stream), params: { content: 'Hello!' }

      expect(response).to redirect_to(login_path)
    end

    it 'handles non-existent stream' do
      expect {
        post stream_chat_messages_path(id: 99999), params: { content: 'Hello!' }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it 'associates message with current user' do
      post stream_chat_messages_path(stream), params: { content: 'Test message' }

      message = ChatMessage.last
      expect(message.user_id).to eq(user.id)
    end

    it 'associates message with stream' do
      post stream_chat_messages_path(stream), params: { content: 'Test message' }

      message = ChatMessage.last
      expect(message.stream_id).to eq(stream.id)
    end
  end
end
