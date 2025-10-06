require 'rails_helper'

RSpec.describe Integrations::DiscordApiClient, type: :service do
  let(:discord_account) do
    double('DiscordAccount',
      access_token: 'discord_access_token',
      ensure_valid_token!: true
    )
  end

  let(:client) { described_class.new(discord_account) }

  describe '#api_base_url' do
    it 'returns Discord API v10 base URL' do
      expect(client.api_base_url).to eq('https://discord.com/api/v10')
    end
  end

  describe '#fetch_user_profile' do
    let(:user_response) do
      {
        id: '123456789',
        username: 'TestUser',
        discriminator: '1234',
        avatar: 'avatar_hash',
        email: 'test@example.com',
        verified: true
      }.to_json
    end

    it 'fetches current user profile' do
      stub_request(:get, 'https://discord.com/api/v10/users/@me')
        .to_return(status: 200, body: user_response)

      result = client.fetch_user_profile

      expect(result[:username]).to eq('TestUser')
      expect(result[:discriminator]).to eq('1234')
      expect(result[:email]).to eq('test@example.com')
    end
  end

  describe '#fetch_user_guilds' do
    let(:guilds_response) do
      [
        { id: 'guild1', name: 'Test Server 1', icon: 'icon1' },
        { id: 'guild2', name: 'Test Server 2', icon: 'icon2' }
      ].to_json
    end

    it 'fetches user guilds (servers)' do
      stub_request(:get, 'https://discord.com/api/v10/users/@me/guilds')
        .to_return(status: 200, body: guilds_response)

      result = client.fetch_user_guilds

      expect(result).to be_an(Array)
      expect(result.count).to eq(2)
      expect(result.first[:name]).to eq('Test Server 1')
    end
  end

  describe '#fetch_user_connections' do
    let(:connections_response) do
      [
        { type: 'steam', name: 'Steam Account', verified: true }
      ].to_json
    end

    it 'fetches user connections' do
      stub_request(:get, 'https://discord.com/api/v10/users/@me/connections')
        .to_return(status: 200, body: connections_response)

      result = client.fetch_user_connections

      expect(result).to be_an(Array)
      expect(result.first[:type]).to eq('steam')
    end
  end

  describe '#fetch_guild_member' do
    let(:member_response) do
      {
        user: { id: '123', username: 'TestUser' },
        nick: 'Nickname',
        roles: ['role1', 'role2']
      }.to_json
    end

    it 'fetches guild member info' do
      stub_request(:get, 'https://discord.com/api/v10/users/@me/guilds/guild123/member')
        .to_return(status: 200, body: member_response)

      result = client.fetch_guild_member('guild123')

      expect(result[:nick]).to eq('Nickname')
      expect(result[:roles]).to be_an(Array)
    end
  end
end
