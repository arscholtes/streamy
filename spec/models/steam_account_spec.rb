require 'rails_helper'

RSpec.describe SteamAccount, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
    it { should have_one(:integration_privacy_setting).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:steam_id) }
    it { should validate_uniqueness_of(:steam_id) }
    it { should validate_presence_of(:persona_name) }
  end

  describe '#external_id' do
    it 'is aliased to steam_id' do
      account = build(:steam_account, steam_id: '76561198000000000')
      expect(account.external_id).to eq('76561198000000000')
    end
  end

  describe '#oauth_service_class' do
    it 'returns Integrations::SteamOauthService' do
      account = build(:steam_account)
      expect(account.oauth_service_class).to eq(Integrations::SteamOauthService)
    end
  end

  describe '#sync_service_class' do
    it 'returns Integrations::SteamSyncService' do
      account = build(:steam_account)
      expect(account.sync_service_class).to eq(Integrations::SteamSyncService)
    end
  end

  describe '.privacy_settings_schema' do
    it 'returns privacy settings schema' do
      schema = SteamAccount.privacy_settings_schema
      expect(schema).to have_key(:profile)
      expect(schema).to have_key(:games)
      expect(schema).to have_key(:activity)
      expect(schema[:profile]).to be_an(Array)
    end
  end

  describe '#default_privacy_settings' do
    it 'returns default privacy settings' do
      account = build(:steam_account)
      settings = account.default_privacy_settings
      expect(settings[:show_profile]).to be true
      expect(settings[:show_persona_name]).to be true
      expect(settings[:show_avatar]).to be true
      expect(settings[:show_real_name]).to be false
      expect(settings[:show_owned_games]).to be true
      expect(settings[:show_online_status]).to be true
    end
  end
end
