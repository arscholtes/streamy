class CreateObsConnections < ActiveRecord::Migration[8.0]
  def change
    create_table :obs_connections do |t|
      t.references :user, null: false, foreign_key: true
      t.string :obs_version
      t.string :platform
      t.string :ip_address
      t.datetime :last_connected_at
      t.string :access_token

      t.timestamps
    end
  end
end
