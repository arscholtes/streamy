class LoyaltyTransaction < ApplicationRecord
  belongs_to :user

  validates :transaction_type, presence: true
  validates :amount, presence: true, numericality: { other_than: 0 }

  TRANSACTION_TYPES = %w[
    earned_watching
    earned_chatting
    earned_subscribing
    earned_donating
    earned_achievement
    earned_minigame
    spent_minigame
    spent_redemption
    spent_custom
  ].freeze

  validates :transaction_type, inclusion: { in: TRANSACTION_TYPES }

  scope :earned, -> { where('amount > 0') }
  scope :spent, -> { where('amount < 0') }
  scope :by_type, ->(type) { where(transaction_type: type) }
  scope :recent, ->(limit = 50) { order(created_at: :desc).limit(limit) }
end
