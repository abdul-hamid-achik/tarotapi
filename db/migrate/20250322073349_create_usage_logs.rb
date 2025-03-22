class CreateUsageLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :usage_logs do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :user, foreign_key: true
      t.string :metric_type, null: false
      t.jsonb :metadata, null: false, default: {}
      t.datetime :recorded_at, null: false

      t.timestamps
    end

    add_index :usage_logs, [ :organization_id, :metric_type ]
    add_index :usage_logs, [ :organization_id, :recorded_at ]
    add_index :usage_logs, [ :user_id, :metric_type ]
    add_index :usage_logs, :recorded_at
  end
end
