class MiniGameSession < ApplicationRecord
  belongs_to :user

  validates :game_type, presence: true
  validates :bet_amount, presence: true, numericality: { greater_than: 0 }
  validates :result, presence: true
  validates :played_at, presence: true

  GAME_TYPES = %w[coinflip roulette slots trivia duel].freeze
  RESULTS = %w[win loss draw].freeze

  validates :game_type, inclusion: { in: GAME_TYPES }
  validates :result, inclusion: { in: RESULTS }

  scope :wins, -> { where(result: 'win') }
  scope :losses, -> { where(result: 'loss') }
  scope :by_game, ->(game) { where(game_type: game) }
  scope :recent, ->(limit = 50) { order(played_at: :desc).limit(limit) }

  def profit
    winnings - bet_amount
  end

  def won?
    result == 'win'
  end

  def lost?
    result == 'loss'
  end
end
