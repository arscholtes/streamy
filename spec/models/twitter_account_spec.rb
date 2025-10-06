require 'rails_helper'

RSpec.describe TwitterAccount, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
    it { should have_one(:integration_privacy_setting).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:twitter_id) }
    it { should validate_uniqueness_of(:twitter_id) }
    it { should validate_presence_of(:username) }
  end

  describe '#external_id' do
    it 'is aliased to twitter_id' do
      account = build(:twitter_account, twitter_id: '123456789')
      expect(account.external_id).to eq('123456789')
    end
  end

  describe '#oauth_service_class' do
    it 'returns Integrations::TwitterOauthService' do
      account = build(:twitter_account)
      expect(account.oauth_service_class).to eq(Integrations::TwitterOauthService)
    end
  end

  describe '#sync_service_class' do
    it 'returns Integrations::TwitterSyncService' do
      account = build(:twitter_account)
      expect(account.sync_service_class).to eq(Integrations::TwitterSyncService)
    end
  end

  describe '.privacy_settings_schema' do
    it 'returns privacy settings schema' do
      schema = TwitterAccount.privacy_settings_schema
      expect(schema).to have_key(:profile)
      expect(schema).to have_key(:activity)
      expect(schema[:profile]).to be_an(Array)
    end
  end
end
