class AddIdentityProviders < ActiveRecord::Migration[8.0]
  def change
    create_table :identity_providers do |t|
      t.string :name, null: false
      t.string :description
      t.jsonb :settings, default: {}
      t.timestamps
    end

    add_index :identity_providers, :name, unique: true

    add_column :users, :external_id, :string
    add_column :users, :identity_provider_id, :bigint
    add_column :users, :metadata, :jsonb, default: {}
    add_column :users, :email, :string
    
    add_index :users, [:identity_provider_id, :external_id], unique: true
    add_foreign_key :users, :identity_providers
  end
end 