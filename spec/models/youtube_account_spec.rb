require 'rails_helper'

RSpec.describe YoutubeAccount, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
    it { should have_one(:integration_privacy_setting).dependent(:destroy) }
  end

  describe 'validations' do
    subject { build(:youtube_account) }

    it { should validate_presence_of(:youtube_id) }
    it { should validate_uniqueness_of(:youtube_id) }
    it { should validate_presence_of(:channel_title) }
  end

  describe '#external_id' do
    it 'is aliased to youtube_id' do
      account = build(:youtube_account, youtube_id: 'UC123456')
      expect(account.external_id).to eq('UC123456')
    end
  end

  describe '#oauth_service_class' do
    it 'returns Integrations::YoutubeOauthService' do
      account = build(:youtube_account)
      expect(account.oauth_service_class).to eq(Integrations::YoutubeOauthService)
    end
  end

  describe '#sync_service_class' do
    it 'returns Integrations::YoutubeSyncService' do
      account = build(:youtube_account)
      expect(account.sync_service_class).to eq(Integrations::YoutubeSyncService)
    end
  end

  describe '.privacy_settings_schema' do
    it 'returns privacy settings schema' do
      schema = YoutubeAccount.privacy_settings_schema
      expect(schema).to have_key(:profile)
      expect(schema).to have_key(:content)
      expect(schema[:profile]).to be_an(Array)
    end
  end
end
