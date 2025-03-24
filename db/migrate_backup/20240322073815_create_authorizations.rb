class CreateAuthorizations < ActiveRecord::Migration[8.0]
  def change
    create_table :authorizations do |t|
      t.references :user, null: false, foreign_key: true
      t.string :client_id, null: false
      t.string :code, null: false
      t.string :scope, null: false
      t.datetime :expires_at, null: false

      t.timestamps
    end

    add_index :authorizations, :client_id
    add_index :authorizations, :code, unique: true
    add_index :authorizations, :expires_at
  end
end
