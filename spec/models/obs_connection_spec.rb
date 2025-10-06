require 'rails_helper'

RSpec.describe ObsConnection, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
  end

  describe 'validations' do
    subject { build(:obs_connection) }

    it { should validate_uniqueness_of(:user_id) }
    it { should validate_presence_of(:host) }
    it { should validate_presence_of(:port) }
    it { should validate_numericality_of(:port).only_integer.is_greater_than(0) }
  end

  describe 'scopes' do
    let!(:connected_obs) { create(:obs_connection, connected: true) }
    let!(:disconnected_obs) { create(:obs_connection, connected: false) }

    describe '.connected' do
      it 'returns only connected OBS connections' do
        expect(ObsConnection.connected).to include(connected_obs)
        expect(ObsConnection.connected).not_to include(disconnected_obs)
      end
    end

    describe '.disconnected' do
      it 'returns only disconnected OBS connections' do
        expect(ObsConnection.disconnected).to include(disconnected_obs)
        expect(ObsConnection.disconnected).not_to include(connected_obs)
      end
    end

    describe '.recent' do
      it 'orders by last_connected_at descending' do
        older_obs = create(:obs_connection, last_connected_at: 2.hours.ago)
        newer_obs = create(:obs_connection, last_connected_at: 1.hour.ago)

        expect(ObsConnection.recent.first).to eq(newer_obs)
      end
    end
  end

  describe 'callbacks' do
    describe 'before_create :generate_access_token' do
      it 'generates an access_token on creation' do
        obs_connection = create(:obs_connection, access_token: nil)
        expect(obs_connection.access_token).to be_present
        expect(obs_connection.access_token.length).to eq(64)
      end

      it 'does not overwrite existing access_token' do
        token = 'existing_token_123'
        obs_connection = create(:obs_connection, access_token: token)
        expect(obs_connection.access_token).to eq(token)
      end
    end
  end

  describe '#calculate_uptime' do
    let(:obs_connection) { create(:obs_connection) }

    it 'calculates total uptime from connection history' do
      obs_connection.update(connection_history: [
        { 'connected_at' => 2.hours.ago.iso8601, 'disconnected_at' => 1.hour.ago.iso8601 },
        { 'connected_at' => 30.minutes.ago.iso8601, 'disconnected_at' => Time.current.iso8601 }
      ])

      uptime = obs_connection.calculate_uptime
      expect(uptime).to be > 0
    end

    it 'returns 0 when connection_history is empty' do
      obs_connection.update(connection_history: [])
      expect(obs_connection.calculate_uptime).to eq(0)
    end

    it 'returns 0 when connection_history is nil' do
      obs_connection.update(connection_history: nil)
      expect(obs_connection.calculate_uptime).to eq(0)
    end

    it 'skips invalid sessions' do
      obs_connection.update(connection_history: [
        { 'connected_at' => 'invalid_date', 'disconnected_at' => Time.current.iso8601 },
        { 'connected_at' => 1.hour.ago.iso8601, 'disconnected_at' => Time.current.iso8601 }
      ])

      expect(obs_connection.calculate_uptime).to be > 0
    end
  end

  describe '#stale?' do
    it 'returns true when last_connected_at is nil' do
      obs_connection = build(:obs_connection, last_connected_at: nil)
      expect(obs_connection.stale?).to be true
    end

    it 'returns true when last connected more than 10 minutes ago' do
      obs_connection = build(:obs_connection, last_connected_at: 11.minutes.ago)
      expect(obs_connection.stale?).to be true
    end

    it 'returns false when last connected within 10 minutes' do
      obs_connection = build(:obs_connection, last_connected_at: 5.minutes.ago)
      expect(obs_connection.stale?).to be false
    end
  end

  describe '#mark_connected!' do
    let(:obs_connection) { create(:obs_connection, connected: false) }

    it 'sets connected to true' do
      obs_connection.mark_connected!
      expect(obs_connection.reload.connected).to be true
    end

    it 'updates last_connected_at' do
      obs_connection.mark_connected!
      expect(obs_connection.reload.last_connected_at).to be_within(1.second).of(Time.current)
    end
  end

  describe '#mark_disconnected!' do
    let(:obs_connection) { create(:obs_connection, connected: true) }

    it 'sets connected to false' do
      obs_connection.mark_disconnected!
      expect(obs_connection.reload.connected).to be false
    end

    it 'updates disconnected_at' do
      obs_connection.mark_disconnected!
      expect(obs_connection.reload.disconnected_at).to be_within(1.second).of(Time.current)
    end
  end

  describe '#status' do
    it 'returns "connected" when connected and not stale' do
      obs_connection = build(:obs_connection, connected: true, last_connected_at: 1.minute.ago)
      expect(obs_connection.status).to eq('connected')
    end

    it 'returns "stale" when connected but stale' do
      obs_connection = build(:obs_connection, connected: true, last_connected_at: 11.minutes.ago)
      expect(obs_connection.status).to eq('stale')
    end

    it 'returns "disconnected" when not connected' do
      obs_connection = build(:obs_connection, connected: false)
      expect(obs_connection.status).to eq('disconnected')
    end
  end

  describe '#display_info' do
    let(:obs_connection) do
      create(:obs_connection,
        host: 'localhost',
        port: 4455,
        connected: true,
        version: '5.0.0',
        last_connected_at: Time.current
      )
    end

    it 'returns a hash with connection details' do
      info = obs_connection.display_info
      expect(info[:host]).to eq('localhost')
      expect(info[:port]).to eq(4455)
      expect(info[:status]).to eq('connected')
      expect(info[:version]).to eq('5.0.0')
      expect(info[:uptime_seconds]).to be >= 0
    end

    it 'handles nil version' do
      obs_connection.update(version: nil)
      info = obs_connection.display_info
      expect(info[:version]).to eq('Unknown')
    end

    it 'returns 0 uptime when disconnected' do
      obs_connection.update(connected: false, last_connected_at: nil)
      info = obs_connection.display_info
      expect(info[:uptime_seconds]).to eq(0)
    end
  end

  describe '.privacy_settings_schema' do
    it 'returns the privacy settings schema' do
      schema = ObsConnection.privacy_settings_schema
      expect(schema).to have_key(:obs)
      expect(schema[:obs]).to be_an(Array)
      expect(schema[:obs].first).to have_key(:key)
      expect(schema[:obs].first).to have_key(:label)
      expect(schema[:obs].first).to have_key(:default)
    end
  end
end
