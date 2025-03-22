class CreateMemberships < ActiveRecord::Migration[8.0]
  def change
    create_table :memberships do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :role, null: false
      t.string :status, null: false, default: 'invited'
      t.datetime :last_active_at

      t.timestamps
    end

    add_index :memberships, [ :organization_id, :user_id ], unique: true
    add_index :memberships, [ :organization_id, :role ]
    add_index :memberships, :status
  end
end
