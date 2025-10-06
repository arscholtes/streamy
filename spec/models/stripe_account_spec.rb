require 'rails_helper'

RSpec.describe StripeAccount, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
    it { should have_one(:integration_privacy_setting).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:stripe_id) }
    it { should validate_uniqueness_of(:stripe_id) }
  end

  describe '#external_id' do
    it 'is aliased to stripe_id' do
      account = build(:stripe_account, stripe_id: 'acct_123456')
      expect(account.external_id).to eq('acct_123456')
    end
  end

  describe '#oauth_service_class' do
    it 'returns Integrations::StripeOauthService' do
      account = build(:stripe_account)
      expect(account.oauth_service_class).to eq(Integrations::StripeOauthService)
    end
  end

  describe '#sync_service_class' do
    it 'returns Integrations::StripeSyncService' do
      account = build(:stripe_account)
      expect(account.sync_service_class).to eq(Integrations::StripeSyncService)
    end
  end

  describe '.privacy_settings_schema' do
    it 'returns privacy settings schema' do
      schema = StripeAccount.privacy_settings_schema
      expect(schema).to have_key(:profile)
      expect(schema).to have_key(:monetization)
      expect(schema[:profile]).to be_an(Array)
    end
  end
end
