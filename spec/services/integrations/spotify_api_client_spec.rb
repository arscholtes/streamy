require 'rails_helper'

RSpec.describe Integrations::SpotifyApiClient, type: :service do
  let(:spotify_account) do
    double('SpotifyAccount',
      access_token: 'spotify_access_token',
      ensure_valid_token!: true
    )
  end

  let(:client) { described_class.new(spotify_account) }

  describe '#api_base_url' do
    it 'returns Spotify API v1 base URL' do
      expect(client.api_base_url).to eq('https://api.spotify.com/v1')
    end
  end

  describe '#fetch_user_profile' do
    let(:profile_response) do
      {
        id: 'spotify123',
        display_name: 'TestUser',
        email: 'test@example.com',
        product: 'premium',
        country: 'US'
      }.to_json
    end

    it 'fetches user profile' do
      stub_request(:get, 'https://api.spotify.com/v1/me')
        .to_return(status: 200, body: profile_response)

      result = client.fetch_user_profile

      expect(result[:id]).to eq('spotify123')
      expect(result[:display_name]).to eq('TestUser')
      expect(result[:product]).to eq('premium')
    end
  end

  describe '#fetch_currently_playing' do
    let(:playing_response) do
      {
        item: {
          name: 'Test Song',
          artists: [{ name: 'Test Artist' }],
          album: {
            name: 'Test Album',
            images: [{ url: 'https://image.url' }]
          },
          duration_ms: 240000
        },
        is_playing: true,
        progress_ms: 60000
      }.to_json
    end

    it 'fetches currently playing track' do
      stub_request(:get, 'https://api.spotify.com/v1/me/player/currently-playing')
        .to_return(status: 200, body: playing_response)

      result = client.fetch_currently_playing

      expect(result[:track_name]).to eq('Test Song')
      expect(result[:artist_name]).to eq('Test Artist')
      expect(result[:album_name]).to eq('Test Album')
      expect(result[:is_playing]).to be true
    end

    it 'returns nil when nothing is playing' do
      stub_request(:get, 'https://api.spotify.com/v1/me/player/currently-playing')
        .to_return(status: 404, body: '')

      result = client.fetch_currently_playing

      expect(result).to be_nil
    end

    it 'returns nil on empty response' do
      stub_request(:get, 'https://api.spotify.com/v1/me/player/currently-playing')
        .to_return(status: 200, body: '')

      result = client.fetch_currently_playing

      expect(result).to be_nil
    end
  end

  describe '#fetch_recently_played' do
    it 'fetches recently played tracks' do
      stub_request(:get, 'https://api.spotify.com/v1/me/player/recently-played')
        .with(query: { limit: 20 })
        .to_return(status: 200, body: { items: [] }.to_json)

      result = client.fetch_recently_played

      expect(result).to have_key(:items)
    end

    it 'accepts custom limit' do
      stub_request(:get, 'https://api.spotify.com/v1/me/player/recently-played')
        .with(query: { limit: 10 })
        .to_return(status: 200, body: { items: [] }.to_json)

      client.fetch_recently_played(limit: 10)
    end
  end

  describe '#fetch_top_tracks' do
    it 'fetches top tracks' do
      stub_request(:get, 'https://api.spotify.com/v1/me/top/tracks')
        .with(query: { time_range: 'medium_term', limit: 20 })
        .to_return(status: 200, body: { items: [] }.to_json)

      result = client.fetch_top_tracks

      expect(result).to have_key(:items)
    end

    it 'accepts custom time range' do
      stub_request(:get, 'https://api.spotify.com/v1/me/top/tracks')
        .with(query: hash_including(time_range: 'long_term'))
        .to_return(status: 200, body: { items: [] }.to_json)

      client.fetch_top_tracks(time_range: 'long_term')
    end
  end

  describe '#fetch_top_artists' do
    it 'fetches top artists' do
      stub_request(:get, 'https://api.spotify.com/v1/me/top/artists')
        .with(query: { time_range: 'medium_term', limit: 20 })
        .to_return(status: 200, body: { items: [] }.to_json)

      result = client.fetch_top_artists

      expect(result).to have_key(:items)
    end
  end

  describe '#fetch_playlists' do
    it 'fetches user playlists' do
      stub_request(:get, 'https://api.spotify.com/v1/me/playlists')
        .with(query: { limit: 50 })
        .to_return(status: 200, body: { items: [] }.to_json)

      result = client.fetch_playlists

      expect(result).to have_key(:items)
    end
  end

  describe '#fetch_playback_state' do
    it 'fetches playback state' do
      stub_request(:get, 'https://api.spotify.com/v1/me/player')
        .to_return(status: 200, body: { device: {} }.to_json)

      result = client.fetch_playback_state

      expect(result).to have_key(:device)
    end

    it 'returns nil when no active playback' do
      stub_request(:get, 'https://api.spotify.com/v1/me/player')
        .to_return(status: 404, body: '')

      result = client.fetch_playback_state

      expect(result).to be_nil
    end
  end
end
