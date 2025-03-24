class AddJsonbColumnsToOrganizations < ActiveRecord::Migration[8.0]
  def up
    # Add new jsonb columns with proper defaults
    add_column :organizations, :features_json, :jsonb, default: {}
    add_column :organizations, :quotas_json, :jsonb, default: {}

    # Copy data from text columns to jsonb columns
    execute <<-SQL
      UPDATE organizations#{' '}
      SET features_json = features::jsonb,#{' '}
          quotas_json = quotas::jsonb;
    SQL

    # Remove old columns
    remove_column :organizations, :features
    remove_column :organizations, :quotas

    # Rename new columns to original names
    rename_column :organizations, :features_json, :features
    rename_column :organizations, :quotas_json, :quotas
  end

  def down
    # Add back original text columns
    add_column :organizations, :features_text, :text, default: "{}"
    add_column :organizations, :quotas_text, :text, default: "{}"

    # Copy data back
    execute <<-SQL
      UPDATE organizations#{' '}
      SET features_text = features::text,#{' '}
          quotas_text = quotas::text;
    SQL

    # Remove jsonb columns
    remove_column :organizations, :features
    remove_column :organizations, :quotas

    # Rename text columns back to original names
    rename_column :organizations, :features_text, :features
    rename_column :organizations, :quotas_text, :quotas
  end
end
