# db/migrate/[timestamp]_create_users.rb
# This migration creates the users table in the database
# Learn more about migrations: https://guides.rubyonrails.org/active_record_migrations.html

class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    # create_table generates a new table with an auto-incrementing primary key (id)
    create_table :users do |t|
      # t.string creates a VARCHAR column in the database
      # username: unique identifier for the user (e.g., "johndoe")
      t.string :username

      # email: user's email address for authentication and communication
      t.string :email

      # password_digest: stores the hashed password (NOT the plain text password)
      # This is used by has_secure_password in the User model
      # Learn more: https://api.rubyonrails.org/classes/ActiveModel/SecurePassword/ClassMethods.html
      t.string :password_digest

      # stream_key: unique key that streamers use to authenticate when pushing video
      # This is used by OBS/streaming software in the RTMP URL
      # Example: rtmp://localhost/live?key=abc123...
      t.string :stream_key

      # t.timestamps creates two columns: created_at and updated_at
      # Rails automatically manages these timestamps
      t.timestamps
    end

    # Indexes improve database query performance and enforce uniqueness
    # Learn more: https://guides.rubyonrails.org/active_record_migrations.html#creating-standalone-indexes

    # unique: true ensures no two users can have the same username
    # This also creates a database-level constraint for data integrity
    add_index :users, :username, unique: true

    # Ensures each email address can only be used once
    add_index :users, :email, unique: true

    # Ensures each stream key is unique across all users
    # This prevents stream key conflicts when users go live
    add_index :users, :stream_key, unique: true
  end
end
