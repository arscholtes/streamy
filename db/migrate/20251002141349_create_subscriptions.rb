class CreateSubscriptions < ActiveRecord::Migration[8.0]
  def change
    create_table :subscriptions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :stripe_subscription_id, null: false
      t.string :stripe_customer_id, null: false
      t.string :status, null: false, default: 'incomplete'
      t.string :plan, null: false
      t.datetime :current_period_start
      t.datetime :current_period_end
      t.boolean :cancel_at_period_end, default: false, null: false
      t.datetime :canceled_at
      t.datetime :trial_start
      t.datetime :trial_end

      t.timestamps
    end

    add_index :subscriptions, :stripe_subscription_id, unique: true
    add_index :subscriptions, :stripe_customer_id
    add_index :subscriptions, :status
    add_index :subscriptions, :plan
  end
end
