require 'rails_helper'

RSpec.describe GameSession, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
    it { should belong_to(:stream).optional }
  end

  describe 'validations' do
    it { should validate_presence_of(:platform) }
    it { should validate_presence_of(:game_name) }
    it { should validate_presence_of(:game_id) }
    it { should validate_presence_of(:started_at) }
    it { should validate_inclusion_of(:platform).in_array(%w[steam battlenet riot]) }

    context 'ended_at validation' do
      let(:user) { create(:user) }

      it 'allows ended_at to be nil' do
        session = build(:game_session, user: user, ended_at: nil)
        expect(session).to be_valid
      end

      it 'allows ended_at to be after started_at' do
        session = build(:game_session, user: user, started_at: 1.hour.ago, ended_at: Time.current)
        expect(session).to be_valid
      end

      it 'does not allow ended_at to be before started_at' do
        session = build(:game_session, user: user, started_at: Time.current, ended_at: 1.hour.ago)
        expect(session).not_to be_valid
        expect(session.errors[:ended_at]).to include('must be after started_at')
      end
    end
  end

  describe 'scopes' do
    let(:user) { create(:user) }
    let!(:active_session) { create(:game_session, user: user, ended_at: nil) }
    let!(:ended_session) { create(:game_session, user: user, ended_at: 1.hour.ago) }
    let!(:steam_session) { create(:game_session, user: user, platform: 'steam') }
    let!(:riot_session) { create(:game_session, user: user, platform: 'riot') }

    describe '.active' do
      it 'returns only active sessions' do
        expect(GameSession.active).to include(active_session)
        expect(GameSession.active).not_to include(ended_session)
      end
    end

    describe '.ended' do
      it 'returns only ended sessions' do
        expect(GameSession.ended).to include(ended_session)
        expect(GameSession.ended).not_to include(active_session)
      end
    end

    describe '.for_platform' do
      it 'returns sessions for specified platform' do
        expect(GameSession.for_platform('steam')).to include(steam_session)
        expect(GameSession.for_platform('steam')).not_to include(riot_session)
      end
    end

    describe '.for_game' do
      it 'returns sessions for specified game' do
        game_id = steam_session.game_id
        expect(GameSession.for_game(game_id)).to include(steam_session)
      end
    end

    describe '.recent' do
      it 'orders sessions by started_at descending' do
        older_session = create(:game_session, user: user, started_at: 2.hours.ago)
        newer_session = create(:game_session, user: user, started_at: 1.hour.ago)
        expect(GameSession.recent.first).to eq(newer_session)
      end
    end
  end

  describe 'instance methods' do
    let(:user) { create(:user) }

    describe '#active?' do
      it 'returns true when ended_at is nil' do
        session = create(:game_session, user: user, ended_at: nil)
        expect(session.active?).to be true
      end

      it 'returns false when ended_at is present' do
        session = create(:game_session, user: user, ended_at: 1.hour.ago)
        expect(session.active?).to be false
      end
    end

    describe '#ended?' do
      it 'returns false when ended_at is nil' do
        session = create(:game_session, user: user, ended_at: nil)
        expect(session.ended?).to be false
      end

      it 'returns true when ended_at is present' do
        session = create(:game_session, user: user, ended_at: 1.hour.ago)
        expect(session.ended?).to be true
      end
    end

    describe '#duration' do
      it 'returns nil for active sessions' do
        session = create(:game_session, user: user, ended_at: nil)
        expect(session.duration).to be_nil
      end

      it 'returns duration in seconds for ended sessions' do
        started = 2.hours.ago
        ended = 1.hour.ago
        session = create(:game_session, user: user, started_at: started, ended_at: ended)
        expect(session.duration).to be_within(1).of(3600)
      end
    end

    describe '#duration_in_minutes' do
      it 'returns nil for active sessions' do
        session = create(:game_session, user: user, ended_at: nil)
        expect(session.duration_in_minutes).to be_nil
      end

      it 'returns duration in minutes for ended sessions' do
        started = 2.hours.ago
        ended = 1.hour.ago
        session = create(:game_session, user: user, started_at: started, ended_at: ended)
        expect(session.duration_in_minutes).to eq(60)
      end
    end

    describe '#end_session!' do
      it 'sets ended_at to current time' do
        session = create(:game_session, user: user, ended_at: nil)
        expect(session.ended_at).to be_nil

        session.end_session!
        expect(session.ended_at).to be_within(1.second).of(Time.current)
      end

      it 'changes active? to false' do
        session = create(:game_session, user: user, ended_at: nil)
        expect { session.end_session! }.to change { session.active? }.from(true).to(false)
      end
    end
  end
end
