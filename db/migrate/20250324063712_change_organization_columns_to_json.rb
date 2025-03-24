class ChangeOrganizationColumnsToJson < ActiveRecord::Migration[8.0]
  def up
    # First remove the default
    change_column_default :organizations, :features, nil
    change_column_default :organizations, :quotas, nil

    # Then change the column type
    change_column :organizations, :features, :jsonb, using: 'features::jsonb'
    change_column :organizations, :quotas, :jsonb, using: 'quotas::jsonb'

    # Finally add the new default
    change_column_default :organizations, :features, '{}'
    change_column_default :organizations, :quotas, '{}'
  end

  def down
    change_column_default :organizations, :features, nil
    change_column_default :organizations, :quotas, nil

    change_column :organizations, :features, :text, using: 'features::text'
    change_column :organizations, :quotas, :text, using: 'quotas::text'

    change_column_default :organizations, :features, "{}"
    change_column_default :organizations, :quotas, "{}"
  end
end
