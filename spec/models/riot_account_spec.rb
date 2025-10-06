require 'rails_helper'

RSpec.describe RiotAccount, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
    it { should have_one(:integration_privacy_setting).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:puuid) }
    it { should validate_uniqueness_of(:puuid) }
    it { should validate_presence_of(:game_name) }
  end

  describe '#external_id' do
    it 'is aliased to puuid' do
      account = build(:riot_account, puuid: 'abc123def456')
      expect(account.external_id).to eq('abc123def456')
    end
  end

  describe '#oauth_service_class' do
    it 'returns Integrations::RiotOauthService' do
      account = build(:riot_account)
      expect(account.oauth_service_class).to eq(Integrations::RiotOauthService)
    end
  end

  describe '#sync_service_class' do
    it 'returns Integrations::RiotSyncService' do
      account = build(:riot_account)
      expect(account.sync_service_class).to eq(Integrations::RiotSyncService)
    end
  end

  describe '.privacy_settings_schema' do
    it 'returns privacy settings schema' do
      schema = RiotAccount.privacy_settings_schema
      expect(schema).to have_key(:profile)
      expect(schema).to have_key(:lol)
      expect(schema).to have_key(:valorant)
      expect(schema[:profile]).to be_an(Array)
    end
  end

  describe '#default_privacy_settings' do
    it 'returns default privacy settings' do
      account = build(:riot_account)
      settings = account.default_privacy_settings
      expect(settings[:show_game_name]).to be true
      expect(settings[:show_tag_line]).to be true
      expect(settings[:show_lol_rank]).to be true
      expect(settings[:show_valorant_rank]).to be true
    end
  end
end
