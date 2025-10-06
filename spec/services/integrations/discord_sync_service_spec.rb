require 'rails_helper'

RSpec.describe Integrations::DiscordSyncService, type: :service do
  let(:discord_account) do
    double('DiscordAccount',
      id: 1,
      update!: true
    )
  end
  let(:api_client) { instance_double(Integrations::DiscordApiClient) }
  let(:service) { described_class.new(discord_account) }

  before do
    allow(Integrations::DiscordApiClient).to receive(:new).and_return(api_client)
  end

  describe '#initialize' do
    it 'sets the discord account' do
      expect(service.discord_account).to eq(discord_account)
    end
  end

  describe '#sync!' do
    let(:user_data) do
      {
        id: '123456789',
        username: 'TestUser',
        discriminator: '1234',
        avatar: 'avatar_hash',
        email: 'test@example.com',
        verified: true,
        locale: 'en-US'
      }
    end

    before do
      allow(api_client).to receive(:fetch_user_profile).and_return(user_data)
    end

    it 'syncs user profile' do
      expect(discord_account).to receive(:update!).with(hash_including(
        username: 'TestUser',
        discriminator: '1234',
        email: 'test@example.com',
        verified: true,
        locale: 'en-US'
      ))

      service.sync!
    end

    it 'builds avatar URL when avatar is present' do
      expect(discord_account).to receive(:update!) do |args|
        expect(args[:avatar_url]).to include('cdn.discordapp.com')
        expect(args[:avatar_url]).to include('123456789')
        expect(args[:avatar_url]).to include('avatar_hash')
      end

      service.sync!
    end

    it 'sets avatar_url to nil when no avatar' do
      user_data[:avatar] = nil

      expect(discord_account).to receive(:update!) do |args|
        expect(args[:avatar_url]).to be_nil
      end

      service.sync!
    end

    it 'updates last_synced_at' do
      expect(discord_account).to receive(:update!).with(hash_including(:last_synced_at))
      service.sync!
    end

    it 'wraps in transaction' do
      expect(ActiveRecord::Base).to receive(:transaction).and_yield
      service.sync!
    end

    it 'logs and raises API errors' do
      allow(api_client).to receive(:fetch_user_profile)
        .and_raise(Integrations::APIError, 'API error')

      expect(Rails.logger).to receive(:error).with(/Discord sync failed/)

      expect {
        service.sync!
      }.to raise_error(Integrations::APIError)
    end
  end
end
