class CreateAccessTokens < ActiveRecord::Migration[8.0]
  def change
    create_table :access_tokens do |t|
      t.references :authorization, null: false, foreign_key: true
      t.string :token, null: false
      t.string :refresh_token, null: false
      t.string :scope, null: false
      t.datetime :expires_at, null: false
      t.datetime :last_used_at

      t.timestamps
    end

    add_index :access_tokens, :token, unique: true
    add_index :access_tokens, :refresh_token, unique: true
    add_index :access_tokens, :expires_at
    add_index :access_tokens, :last_used_at
  end
end
