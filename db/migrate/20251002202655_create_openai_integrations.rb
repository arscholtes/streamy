class CreateOpenaiIntegrations < ActiveRecord::Migration[8.0]
  def change
    create_table :openai_integrations do |t|
      t.references :user, null: false, foreign_key: true
      t.string :api_key
      t.string :organization_id
      t.integer :usage_limit
      t.integer :usage_count
      t.datetime :last_used_at

      t.timestamps
    end
  end
end
