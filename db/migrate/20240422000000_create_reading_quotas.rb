class CreateReadingQuotas < ActiveRecord::Migration[7.1]
  def change
    create_table :reading_quotas do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :monthly_limit, default: 100, null: false
      t.integer :readings_this_month, default: 0, null: false
      t.datetime :reset_date, null: false
      t.timestamps
    end

    add_index :reading_quotas, :reset_date
  end
end
