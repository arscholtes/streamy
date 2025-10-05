# app/models/user.rb
# User model handles authentication and user management
# Learn more about Active Record models: https://guides.rubyonrails.org/active_record_basics.html

class User < ApplicationRecord
  # ASSOCIATIONS
  # Defines relationships between models
  # Learn more: https://guides.rubyonrails.org/association_basics.html

  # has_many :streams means one user can have multiple streams
  # dependent: :destroy means when a user is deleted, all their streams are also deleted
  # This prevents orphaned records in the database
  has_many :streams, dependent: :destroy

  # Integration associations - Tier 1
  has_one :steam_account, dependent: :destroy
  has_one :discord_account, dependent: :destroy
  has_one :battlenet_account, dependent: :destroy
  has_one :riot_account, dependent: :destroy
  has_one :twitter_account, dependent: :destroy
  has_one :youtube_account, dependent: :destroy
  has_one :stripe_account, dependent: :destroy
  has_one :obs_connection, dependent: :destroy

  # Integration associations - Tier 2
  has_one :epic_account, dependent: :destroy
  has_one :xbox_account, dependent: :destroy
  has_one :playstation_account, dependent: :destroy
  has_one :spotify_account, dependent: :destroy
  has_one :tiktok_account, dependent: :destroy
  has_one :instagram_account, dependent: :destroy
  has_one :twitch_account, dependent: :destroy
  has_one :paypal_account, dependent: :destroy
  has_one :google_analytics_account, dependent: :destroy
  has_one :openai_integration, dependent: :destroy

  # Discord bot associations
  has_one :loyalty_point, dependent: :destroy
  has_many :loyalty_transactions, dependent: :destroy
  has_many :user_achievements, dependent: :destroy
  has_many :achievements, through: :user_achievements
  has_many :vc_queue_entries, dependent: :destroy
  has_many :mini_game_sessions, dependent: :destroy

  # Moderation associations
  has_many :moderation_actions, dependent: :destroy
  has_many :user_warnings, dependent: :destroy
  has_many :user_mutes, dependent: :destroy

  # Payment associations
  has_many :subscriptions, dependent: :destroy
  has_one :active_subscription, -> { active }, class_name: 'Subscription'
  has_many :payments, dependent: :destroy
  has_many :received_payments, foreign_key: :recipient_id, class_name: 'Payment', dependent: :nullify

  # Chat associations
  has_many :chat_messages, dependent: :destroy

  # CALLBACKS
  # Methods that run automatically at specific points in an object's lifecycle
  # Learn more: https://guides.rubyonrails.org/active_record_callbacks.html

  # before_save runs before the record is saved to the database
  # We use it to normalize usernames and emails to lowercase
  # This ensures case-insensitive uniqueness (e.g., "John" and "john" are treated as the same)
  before_save :downcase_username
  before_save :downcase_email

  # after_create runs after a new record is successfully created
  # We use it to generate a unique stream key for each user
  after_create :generate_stream_key

  # SECURE PASSWORD
  # has_secure_password adds methods to set and authenticate against a BCrypt password
  # This automatically:
  # 1. Adds password and password_confirmation attributes (virtual, not stored in DB)
  # 2. Adds password= method to hash and store the password in password_digest
  # 3. Adds authenticate(password) method to check if a password is correct
  # 4. Adds validation requiring password_digest to be present
  # Learn more: https://api.rubyonrails.org/classes/ActiveModel/SecurePassword/ClassMethods.html
  has_secure_password

  # VALIDATIONS
  # Ensure data integrity before saving to the database
  # Learn more: https://guides.rubyonrails.org/active_record_validations.html

  # Username validations
  validates :username,
    presence: true,     # Username cannot be blank
    uniqueness: {       # Username must be unique
      case_sensitive: false # Treat "John" and "john" as the same username
    },
    length: {           # Enforce length constraints
      minimum: 3,       # At least 3 characters
      maximum: 50       # At most 50 characters
    },
    format: {           # Must match this pattern
      with: /\A[a-zA-Z0-9_]+\z/, # Only letters, numbers, and underscores
      message: "can only contain letters, numbers, and underscores"
    }

  # Email validations
  validates :email,
    presence: true,     # Email cannot be blank
    uniqueness: {       # Email must be unique
      case_sensitive: false # Treat "John@Example.com" and "john@example.com" as the same
    },
    format: {           # Must match valid email format
      # This regex validates basic email format: something@something.something
      # \A = start of string, \z = end of string
      # [\w+\-.] = word characters, plus, hyphen, or dot
      # @ = literal @ symbol
      # [a-z\d\-.] = letters, digits, hyphen, or dot for domain
      # \. = literal dot before extension
      # [a-z]+ = one or more letters for extension
      with: /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i,
      message: "must be a valid email address"
    }

  # Password validations
  # has_secure_password automatically validates presence of password_digest
  # We add additional validation for minimum length
  validates :password,
    length: {
      minimum: 6 # Passwords must be at least 6 characters
    },
    if: :password_digest_changed? # Only validate when password is being set/changed

  # Subscription tier validation
  # Ensures only valid subscription tiers can be set
  # This prepares for future payment integration (Stripe, PayPal, etc.)
  validates :subscription_tier,
    presence: true,
    inclusion: {
      in: %w[free pro enterprise], # Only these values are allowed
      message: "%{value} is not a valid subscription tier"
    }

  # PRIVATE METHODS
  # These methods can only be called from within this class
  private

  # Converts username to lowercase before saving
  # This ensures usernames are case-insensitive in the database
  # Example: "JohnDoe" becomes "johndoe"
  def downcase_username
    # self.username refers to the current object's username attribute
    # downcase! modifies the string in place (the ! means it modifies the original)
    self.username = username.downcase if username.present?
  end

  # Converts email to lowercase before saving
  # This ensures emails are case-insensitive in the database
  # Example: "John@Example.COM" becomes "john@example.com"
  def downcase_email
    self.email = email.downcase if email.present?
  end

  # Generates a unique stream key for the user
  # This key is used by OBS/streaming software to authenticate when pushing video
  # Example: rtmp://localhost/live?key=abc123def456...
  def generate_stream_key
    # SecureRandom.hex(20) generates a random 40-character hexadecimal string
    # 20 bytes = 40 hex characters (each byte = 2 hex chars)
    # Example output: "a3d5f8b9c2e4d1f6a8b7c9e2d4f5a6b8c9d1e3f5"
    # Learn more: https://ruby-doc.org/stdlib-3.0.0/libdoc/securerandom/rdoc/SecureRandom.html
    self.stream_key = SecureRandom.hex(20)

    # save! persists the stream_key to the database
    # The ! means it will raise an exception if save fails
    save!
  end
end
