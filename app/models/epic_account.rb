class EpicAccount < ApplicationRecord
  belongs_to :user
  has_one :integration_privacy_setting, as: :integration, dependent: :destroy

  validates :epic_id, presence: true, uniqueness: true
  validates :access_token, presence: true

  after_create :create_default_privacy_settings

  private

  def create_default_privacy_settings
    create_integration_privacy_setting!(
      user: user,
      settings: {
        show_display_name: true,
        show_email: false,
        show_country: true
      }
    )
  end
end
