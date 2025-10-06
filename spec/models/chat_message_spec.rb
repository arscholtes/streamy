require 'rails_helper'

RSpec.describe ChatMessage, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
    it { should belong_to(:stream) }
  end

  describe 'validations' do
    it { should validate_presence_of(:content) }
    it { should validate_length_of(:content).is_at_most(500) }
  end

  describe 'scopes' do
    let(:stream) { create(:stream) }
    let!(:old_message) { create(:chat_message, stream: stream, created_at: 1.hour.ago) }
    let!(:recent_message) { create(:chat_message, stream: stream, created_at: 1.minute.ago) }

    describe '.recent' do
      it 'returns most recent messages first' do
        expect(ChatMessage.recent.first).to eq(recent_message)
      end

      it 'limits to 100 messages' do
        create_list(:chat_message, 105, stream: stream)
        expect(ChatMessage.recent.count).to eq(100)
      end
    end
  end

  describe 'callbacks' do
    it 'broadcasts after creation' do
      stream = create(:stream)
      message = build(:chat_message, stream: stream)

      expect(message).to receive(:broadcast_append_to)
      message.save
    end
  end
end
