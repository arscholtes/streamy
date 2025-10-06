require 'rails_helper'

RSpec.describe DiscordAccount, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
    it { should have_one(:integration_privacy_setting).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:discord_id) }
    it { should validate_uniqueness_of(:discord_id) }
    it { should validate_presence_of(:username) }
  end

  describe '#external_id' do
    it 'is aliased to discord_id' do
      account = build(:discord_account, discord_id: '123456789')
      expect(account.external_id).to eq('123456789')
    end
  end

  describe '#oauth_service_class' do
    it 'returns Integrations::DiscordOauthService' do
      account = build(:discord_account)
      expect(account.oauth_service_class).to eq(Integrations::DiscordOauthService)
    end
  end

  describe '#sync_service_class' do
    it 'returns Integrations::DiscordSyncService' do
      account = build(:discord_account)
      expect(account.sync_service_class).to eq(Integrations::DiscordSyncService)
    end
  end

  describe '.privacy_settings_schema' do
    it 'returns privacy settings schema' do
      schema = DiscordAccount.privacy_settings_schema
      expect(schema).to have_key(:profile)
      expect(schema).to have_key(:servers)
      expect(schema).to have_key(:activity)
      expect(schema[:profile]).to be_an(Array)
    end
  end

  describe '#default_privacy_settings' do
    it 'returns default privacy settings' do
      account = build(:discord_account)
      settings = account.default_privacy_settings
      expect(settings[:show_username]).to be true
      expect(settings[:show_avatar]).to be true
      expect(settings[:show_discriminator]).to be false
      expect(settings[:show_servers]).to be true
      expect(settings[:show_online_status]).to be true
    end
  end
end
