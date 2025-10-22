require 'rails_helper'

RSpec.describe Integrations::YoutubeApiClient, type: :service do
  let(:youtube_account) { create(:youtube_account) }
  let(:client) { described_class.new(youtube_account) }

  describe '#api_base_url' do
    it 'returns YouTube Data API v3 base URL' do
      expect(client.api_base_url).to eq('https://www.googleapis.com/youtube/v3')
    end
  end

  describe '#fetch_channel_info' do
    let(:channel_response) do
      {
        items: [
          {
            id: 'UCtest123',
            snippet: {
              title: 'Test Gaming Channel',
              description: 'A test channel',
              customUrl: '@testchannel',
              thumbnails: {
                high: { url: 'https://example.com/thumb.jpg' }
              }
            },
            statistics: {
              subscriberCount: '50000',
              videoCount: '250',
              viewCount: '1000000'
            },
            contentDetails: {
              relatedPlaylists: {
                uploads: 'UUtest123'
              }
            }
          }
        ]
      }.to_json
    end

    it 'fetches channel information' do
      allow(youtube_account).to receive(:ensure_valid_token!)

      stub_request(:get, %r{https://www.googleapis.com/youtube/v3/channels})
        .to_return(status: 200, body: channel_response)

      result = client.fetch_channel_info

      expect(result[:id]).to eq('UCtest123')
      expect(result[:title]).to eq('Test Gaming Channel')
      expect(result[:subscriber_count]).to eq(50000)
      expect(result[:video_count]).to eq(250)
      expect(result[:uploads_playlist_id]).to eq('UUtest123')
    end

    it 'returns nil when no channel found' do
      allow(youtube_account).to receive(:ensure_valid_token!)

      stub_request(:get, %r{https://www.googleapis.com/youtube/v3/channels})
        .to_return(status: 200, body: { items: [] }.to_json)

      result = client.fetch_channel_info
      expect(result).to be_nil
    end
  end

  describe '#fetch_recent_videos' do
    let(:playlist_response) do
      {
        items: [
          {
            contentDetails: { videoId: 'video123' },
            snippet: {
              title: 'Test Video',
              description: 'A test video',
              thumbnails: {
                high: { url: 'https://example.com/video_thumb.jpg' }
              },
              publishedAt: '2025-10-15T10:00:00Z'
            }
          }
        ]
      }.to_json
    end

    it 'fetches recent videos from uploads playlist' do
      allow(youtube_account).to receive(:ensure_valid_token!)
      allow(client).to receive(:fetch_channel_info).and_return(
        { uploads_playlist_id: 'UUtest123' }
      )

      stub_request(:get, %r{https://www.googleapis.com/youtube/v3/playlistItems})
        .to_return(status: 200, body: playlist_response)

      result = client.fetch_recent_videos(max_results: 10)

      expect(result).to be_an(Array)
      expect(result.first[:id]).to eq('video123')
      expect(result.first[:title]).to eq('Test Video')
    end
  end
end
