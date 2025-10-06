require 'rails_helper'

RSpec.describe Integrations::SpotifySyncService, type: :service do
  let(:user) { double('User', id: 1, metadata: {}) }
  let(:spotify_account) do
    double('SpotifyAccount',
      id: 1,
      user: user,
      update!: true
    )
  end
  let(:api_client) { instance_double(Integrations::SpotifyApiClient) }
  let(:service) { described_class.new(spotify_account) }

  before do
    allow(Integrations::SpotifyApiClient).to receive(:new).and_return(api_client)
  end

  describe '#initialize' do
    it 'sets the spotify account' do
      expect(service.spotify_account).to eq(spotify_account)
    end
  end

  describe '#sync!' do
    let(:profile_data) do
      {
        id: 'spotify123',
        display_name: 'TestUser',
        email: 'test@example.com',
        product: 'premium',
        country: 'US',
        followers: { total: 100 }
      }
    end

    before do
      allow(api_client).to receive(:fetch_user_profile).and_return(profile_data)
      allow(api_client).to receive(:fetch_currently_playing).and_return(nil)
    end

    it 'syncs profile data' do
      expect(spotify_account).to receive(:update!).with(hash_including(
        spotify_id: 'spotify123',
        display_name: 'TestUser',
        email: 'test@example.com',
        product: 'premium',
        country: 'US',
        follower_count: 100
      ))

      service.sync!
    end

    it 'updates last_synced_at' do
      expect(spotify_account).to receive(:update!).with(hash_including(:last_synced_at))
      service.sync!
    end

    it 'wraps in transaction' do
      expect(ActiveRecord::Base).to receive(:transaction).and_yield
      service.sync!
    end

    it 'logs and raises API errors' do
      allow(api_client).to receive(:fetch_user_profile)
        .and_raise(Integrations::APIError, 'API error')

      expect(Rails.logger).to receive(:error).with(/Spotify sync failed/)

      expect {
        service.sync!
      }.to raise_error(Integrations::APIError)
    end
  end

  describe '#sync_currently_playing' do
    let(:currently_playing) do
      {
        track_name: 'Test Song',
        artist_name: 'Test Artist',
        album_name: 'Test Album',
        album_image_url: 'https://image.url',
        is_playing: true
      }
    end

    before do
      allow(api_client).to receive(:fetch_currently_playing).and_return(currently_playing)
      allow(user).to receive(:update)
    end

    it 'stores currently playing track in user metadata' do
      expect(user).to receive(:update) do |args|
        spotify_data = args[:metadata][:spotify_currently_playing]
        expect(spotify_data[:track_name]).to eq('Test Song')
        expect(spotify_data[:artist_name]).to eq('Test Artist')
        expect(spotify_data[:is_playing]).to be true
      end

      service.send(:sync_currently_playing)
    end

    it 'does not update if nothing is playing' do
      allow(api_client).to receive(:fetch_currently_playing).and_return(nil)

      expect(user).not_to receive(:update)

      service.send(:sync_currently_playing)
    end
  end
end
