class CreateApiClients < ActiveRecord::Migration[8.0]
  def change
    create_table :api_clients do |t|
      t.string :name
      t.string :client_id
      t.string :client_secret
      t.text :redirect_uri
      t.references :organization, null: false, foreign_key: true

      t.timestamps
    end
    add_index :api_clients, :client_id
  end
end
