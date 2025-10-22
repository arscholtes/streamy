require 'rails_helper'

RSpec.describe Integrations::YoutubeSyncService, type: :service do
  let(:youtube_account) { create(:youtube_account) }
  let(:service) { described_class.new(youtube_account) }
  let(:api_client) { instance_double(Integrations::YoutubeApiClient) }

  before do
    allow(Integrations::YoutubeApiClient).to receive(:new).with(youtube_account).and_return(api_client)
  end

  describe '#sync!' do
    let(:channel_data) do
      {
        id: 'UCnewchannel123',
        title: 'Updated Channel Name',
        subscriber_count: 75000,
        video_count: 300,
        thumbnail_url: 'https://example.com/new_thumb.jpg'
      }
    end

    it 'syncs channel information' do
      allow(api_client).to receive(:fetch_channel_info).and_return(channel_data)

      expect {
        service.sync!
      }.to change { youtube_account.reload.subscriber_count }.to(75000)
        .and change { youtube_account.channel_title }.to('Updated Channel Name')
        .and change { youtube_account.last_synced_at }
    end

    it 'updates last_synced_at timestamp' do
      allow(api_client).to receive(:fetch_channel_info).and_return(channel_data)

      expect {
        service.sync!
      }.to change { youtube_account.reload.last_synced_at }

      expect(youtube_account.last_synced_at).to be_within(1.second).of(Time.current)
    end

    it 'handles API errors gracefully' do
      allow(api_client).to receive(:fetch_channel_info).and_raise(Integrations::APIError, 'API Error')
      allow(Rails.logger).to receive(:error)

      expect {
        service.sync!
      }.to raise_error(Integrations::APIError)

      expect(Rails.logger).to have_received(:error).with(/YouTube sync failed/)
    end

    it 'does not update when channel data is nil' do
      allow(api_client).to receive(:fetch_channel_info).and_return(nil)

      original_subscriber_count = youtube_account.subscriber_count

      service.sync!

      expect(youtube_account.reload.subscriber_count).to eq(original_subscriber_count)
    end
  end
end
