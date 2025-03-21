class CreateAuditLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :audit_logs do |t|
      t.string :table_name, null: false
      t.bigint :record_id, null: false
      t.string :action, null: false # 'create', 'update', 'delete'
      t.jsonb :changed_attributes
      t.jsonb :before_state
      t.jsonb :after_state
      t.references :user, foreign_key: true, index: { name: "idx_audit_logs_on_user_id" }
      t.string :ip_address
      t.string :user_agent

      t.timestamps
    end

    add_index :audit_logs, [ :table_name, :record_id ]
    add_index :audit_logs, :action
    add_index :audit_logs, :created_at
  end
end
