require 'rails_helper'

RSpec.describe SpotifyAccount, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
    it { should have_one(:integration_privacy_setting).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:spotify_id) }
    it { should validate_uniqueness_of(:spotify_id) }
  end

  describe '#oauth_service_class' do
    it 'returns Integrations::SpotifyOauthService' do
      account = build(:spotify_account)
      expect(account.oauth_service_class).to eq(Integrations::SpotifyOauthService)
    end
  end

  describe '#sync_service_class' do
    it 'returns Integrations::SpotifySyncService' do
      account = build(:spotify_account)
      expect(account.sync_service_class).to eq(Integrations::SpotifySyncService)
    end
  end

  describe '#external_id_field' do
    it 'returns :spotify_id' do
      account = build(:spotify_account)
      expect(account.external_id_field).to eq(:spotify_id)
    end
  end

  describe '#default_privacy_settings' do
    it 'returns default privacy settings' do
      account = build(:spotify_account)
      settings = account.default_privacy_settings
      expect(settings[:show_display_name]).to be true
      expect(settings[:show_currently_playing]).to be true
      expect(settings[:show_top_tracks]).to be false
      expect(settings[:show_playlists]).to be false
    end
  end
end
