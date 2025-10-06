require 'rails_helper'

RSpec.describe EpicAccount, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
    it { should have_one(:integration_privacy_setting).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:epic_id) }
    it { should validate_uniqueness_of(:epic_id) }
    it { should validate_presence_of(:access_token) }
  end

  describe 'callbacks' do
    describe 'after_create :create_default_privacy_settings' do
      let(:user) { create(:user) }
      let(:epic_account) { create(:epic_account, user: user) }

      it 'creates integration_privacy_setting after creation' do
        expect(epic_account.integration_privacy_setting).to be_present
      end

      it 'sets default privacy settings' do
        settings = epic_account.integration_privacy_setting.settings
        expect(settings['show_display_name']).to be true
        expect(settings['show_email']).to be false
        expect(settings['show_country']).to be true
      end
    end
  end
end
