class CreateOrganizations < ActiveRecord::Migration[8.0]
  def change
    create_table :organizations do |t|
      t.string :name, null: false
      t.string :plan, null: false
      t.string :billing_email, null: false
      t.string :status, null: false, default: 'active'
      t.jsonb :features, null: false, default: {}
      t.jsonb :quotas, null: false, default: {}

      t.timestamps
    end

    add_index :organizations, :plan
    add_index :organizations, :status
    add_index :organizations, :billing_email
  end
end
