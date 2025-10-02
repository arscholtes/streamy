# db/migrate/[timestamp]_add_subscription_tier_to_users.rb
# This migration adds subscription_tier column to users table
# This prepares the system for future payment/subscription functionality
# Learn more: https://guides.rubyonrails.org/active_record_migrations.html

class AddSubscriptionTierToUsers < ActiveRecord::Migration[8.0]
  def change
    # Add subscription_tier column to users table
    # This will store the user's subscription level: 'free', 'pro', 'enterprise'
    # default: 'free' - new users start on free tier
    add_column :users, :subscription_tier, :string, default: "free", null: false

    # Add index for faster queries when filtering by tier
    # This is useful for analytics and admin dashboards
    add_index :users, :subscription_tier
  end
end
