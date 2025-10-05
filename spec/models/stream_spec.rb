require 'rails_helper'

RSpec.describe Stream, type: :model do
  let(:user) { create(:user) }
  let(:stream) { create(:stream, user: user) }

  describe 'associations' do
    it { should belong_to(:user) }
    it { should have_many(:chat_messages).dependent(:destroy) }
    it { should have_many(:game_sessions).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:title) }
    it { should validate_length_of(:title).is_at_least(3).is_at_most(100) }
    it { should validate_presence_of(:status) }
    it { should validate_inclusion_of(:status).in_array(%w[live offline]) }
  end

  describe 'scopes' do
    let!(:live_stream) { create(:stream, status: 'live') }
    let!(:offline_stream) { create(:stream, status: 'offline') }

    describe '.live' do
      it 'returns only live streams' do
        expect(Stream.live).to include(live_stream)
        expect(Stream.live).not_to include(offline_stream)
      end
    end

    describe '.offline' do
      it 'returns only offline streams' do
        expect(Stream.offline).to include(offline_stream)
        expect(Stream.offline).not_to include(live_stream)
      end
    end

    describe '.recent' do
      it 'orders streams by updated_at descending' do
        older_stream = create(:stream, updated_at: 1.day.ago)
        newer_stream = create(:stream, updated_at: 1.hour.ago)

        expect(Stream.recent.first).to eq(newer_stream)
      end
    end

    describe '.search' do
      let(:user1) { create(:user, username: 'gamer123') }
      let(:user2) { create(:user, username: 'streamer456') }
      let!(:stream1) { create(:stream, user: user1, title: 'Playing Dota 2') }
      let!(:stream2) { create(:stream, user: user2, title: 'Counter-Strike Tournament') }

      it 'searches by title' do
        results = Stream.search('Dota')
        expect(results).to include(stream1)
        expect(results).not_to include(stream2)
      end

      it 'searches by username' do
        results = Stream.search('gamer')
        expect(results).to include(stream1)
        expect(results).not_to include(stream2)
      end

      it 'is case insensitive' do
        results = Stream.search('DOTA')
        expect(results).to include(stream1)
      end

      it 'returns all streams when query is blank' do
        results = Stream.search('')
        expect(results.count).to eq(Stream.count)
      end
    end
  end

  describe '#live?' do
    it 'returns true when status is live' do
      stream.status = 'live'
      expect(stream.live?).to be true
    end

    it 'returns false when status is offline' do
      stream.status = 'offline'
      expect(stream.live?).to be false
    end
  end

  describe '#offline?' do
    it 'returns true when status is offline' do
      stream.status = 'offline'
      expect(stream.offline?).to be true
    end

    it 'returns false when status is live' do
      stream.status = 'live'
      expect(stream.live?).to be true
    end
  end

  describe '#viewer_count' do
    it 'returns 0 when stream is offline' do
      stream.status = 'offline'
      expect(stream.viewer_count).to eq(0)
    end

    it 'returns a number when stream is live' do
      stream.status = 'live'
      expect(stream.viewer_count).to be_a(Integer)
      expect(stream.viewer_count).to be > 0
    end
  end

  describe '#playback_url' do
    it 'returns nil when stream is offline' do
      stream.status = 'offline'
      expect(stream.playback_url).to be_nil
    end

    it 'returns URL when stream is live' do
      stream.status = 'live'
      expect(stream.playback_url).to be_present
      expect(stream.playback_url).to include('.m3u8')
    end
  end

  describe 'callbacks' do
    let(:steam_account) { create(:steam_account, user: user) }

    describe 'going live' do
      before do
        stream.update(status: 'offline')
      end

      it 'starts game detection when stream goes live' do
        expect(Integrations::DetectCurrentGameJob).to receive(:perform_later).with(stream.id)

        stream.update(status: 'live')
      end

      it 'does not start game detection if user has no Steam account' do
        steam_account.destroy

        expect(Integrations::DetectCurrentGameJob).not_to receive(:perform_later)

        stream.update(status: 'live')
      end

      it 'does not trigger when already live' do
        stream.update(status: 'live')

        expect(Integrations::DetectCurrentGameJob).not_to receive(:perform_later)

        stream.update(title: 'New Title')
      end
    end

    describe 'going offline' do
      let!(:active_session) { create(:game_session, stream: stream, user: user, ended_at: nil) }

      before do
        stream.update(status: 'live')
      end

      it 'ends all active game sessions when stream goes offline' do
        expect {
          stream.update(status: 'offline')
        }.to change { active_session.reload.ended_at }.from(nil)
      end

      it 'does not affect already ended sessions' do
        ended_session = create(:game_session, stream: stream, user: user, ended_at: 1.hour.ago)

        stream.update(status: 'offline')

        expect(ended_session.reload.ended_at).to be_within(1.second).of(1.hour.ago)
      end

      it 'does not trigger when already offline' do
        stream.update(status: 'offline')

        expect {
          stream.update(title: 'New Title')
        }.not_to change(GameSession.where(ended_at: nil), :count)
      end
    end
  end
end
