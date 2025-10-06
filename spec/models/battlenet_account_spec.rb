require 'rails_helper'

RSpec.describe BattlenetAccount, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
    it { should have_one(:integration_privacy_setting).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:battletag) }
    it { should validate_uniqueness_of(:battletag) }
    it { should validate_presence_of(:region) }
  end

  describe '#external_id' do
    it 'is aliased to battletag' do
      account = build(:battlenet_account, battletag: 'Player#1234')
      expect(account.external_id).to eq('Player#1234')
    end
  end

  describe '#oauth_service_class' do
    it 'returns Integrations::BattlenetOauthService' do
      account = build(:battlenet_account)
      expect(account.oauth_service_class).to eq(Integrations::BattlenetOauthService)
    end
  end

  describe '#sync_service_class' do
    it 'returns Integrations::BattlenetSyncService' do
      account = build(:battlenet_account)
      expect(account.sync_service_class).to eq(Integrations::BattlenetSyncService)
    end
  end

  describe '.privacy_settings_schema' do
    it 'returns privacy settings schema' do
      schema = BattlenetAccount.privacy_settings_schema
      expect(schema).to have_key(:profile)
      expect(schema).to have_key(:games)
      expect(schema[:profile]).to be_an(Array)
      expect(schema[:games]).to be_an(Array)
    end
  end

  describe '#default_privacy_settings' do
    it 'returns default privacy settings' do
      account = build(:battlenet_account)
      settings = account.default_privacy_settings
      expect(settings[:show_battletag]).to be true
      expect(settings[:show_region]).to be true
      expect(settings[:show_wow_characters]).to be true
      expect(settings[:show_overwatch_stats]).to be true
      expect(settings[:show_diablo_characters]).to be true
    end
  end
end
