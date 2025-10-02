class CreateIntegrationPrivacySettings < ActiveRecord::Migration[8.0]
  def change
    create_table :integration_privacy_settings do |t|
      # Polymorphic association to any integration account
      t.references :integration, polymorphic: true, null: false, index: { name: 'index_privacy_on_integration' }
      t.references :user, null: false, foreign_key: true

      # JSON column for flexible settings storage
      # Each integration can have different privacy options
      t.json :settings, default: {}, null: false

      t.timestamps
    end

    # Ensure only one privacy setting per integration
    add_index :integration_privacy_settings,
              [:integration_type, :integration_id],
              unique: true,
              name: 'index_privacy_unique_integration'
  end
end
