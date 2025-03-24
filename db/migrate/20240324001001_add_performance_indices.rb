class AddPerformanceIndices < ActiveRecord::Migration[7.0]
  def change
    # Add indices for better API performance if api_keys table exists
    if table_exists?(:api_keys)
      unless index_exists?(:api_keys, [ :user_id, :active ], name: 'index_api_keys_on_user_id_and_active')
        add_index :api_keys, [ :user_id, :active ], name: 'index_api_keys_on_user_id_and_active'
      end

      unless index_exists?(:api_keys, [ :organization_id, :active ], name: 'index_api_keys_on_organization_id_and_active')
        add_index :api_keys, [ :organization_id, :active ], name: 'index_api_keys_on_organization_id_and_active'
      end
    end

    # Add indices for better reading performance
    if table_exists?(:readings)
      unless index_exists?(:readings, [ :user_id, :spread_id, :status ], name: 'index_readings_on_user_id_spread_id_status')
        add_index :readings, [ :user_id, :spread_id, :status ], name: 'index_readings_on_user_id_spread_id_status'
      end

      unless index_exists?(:readings, [ :created_at, :status ], name: 'index_readings_on_created_at_and_status')
        add_index :readings, [ :created_at, :status ], name: 'index_readings_on_created_at_and_status'
      end
    end

    # Add indices for better card reading performance
    if table_exists?(:card_readings)
      # Only add this if reading_date column exists
      if column_exists?(:card_readings, :reading_date)
        unless index_exists?(:card_readings, [ :user_id, :reading_date ], name: 'index_card_readings_on_user_id_and_reading_date')
          add_index :card_readings, [ :user_id, :reading_date ], name: 'index_card_readings_on_user_id_and_reading_date'
        end
      end

      # Check if index already exists before creating it
      unless index_exists?(:card_readings, [ :reading_id, :position ], name: 'index_card_readings_on_reading_id_and_position')
        add_index :card_readings, [ :reading_id, :position ], name: 'index_card_readings_on_reading_id_and_position'
      end
    end

    # Add indices for better subscription performance
    if table_exists?(:subscriptions)
      unless index_exists?(:subscriptions, [ :user_id, :current_period_end ], name: 'index_subscriptions_on_user_id_and_current_period_end')
        add_index :subscriptions, [ :user_id, :current_period_end ], name: 'index_subscriptions_on_user_id_and_current_period_end'
      end
    end

    if table_exists?(:subscription_plans)
      unless index_exists?(:subscription_plans, [ :is_active, :price ], name: 'index_subscription_plans_on_is_active_and_price')
        add_index :subscription_plans, [ :is_active, :price ], name: 'index_subscription_plans_on_is_active_and_price'
      end
    end

    # Add indices for better organization performance
    if table_exists?(:organizations)
      unless index_exists?(:organizations, [ :status, :plan ], name: 'index_organizations_on_status_and_plan')
        add_index :organizations, [ :status, :plan ], name: 'index_organizations_on_status_and_plan'
      end
    end

    if table_exists?(:memberships)
      unless index_exists?(:memberships, [ :user_id, :role, :status ], name: 'index_memberships_on_user_id_role_status')
        add_index :memberships, [ :user_id, :role, :status ], name: 'index_memberships_on_user_id_role_status'
      end
    end
  end

  def down
    if table_exists?(:memberships)
      remove_index :memberships, name: 'index_memberships_on_user_id_role_status' if index_exists?(:memberships, [ :user_id, :role, :status ], name: 'index_memberships_on_user_id_role_status')
    end

    if table_exists?(:organizations)
      remove_index :organizations, name: 'index_organizations_on_status_and_plan' if index_exists?(:organizations, [ :status, :plan ], name: 'index_organizations_on_status_and_plan')
    end

    if table_exists?(:subscription_plans)
      remove_index :subscription_plans, name: 'index_subscription_plans_on_is_active_and_price' if index_exists?(:subscription_plans, [ :is_active, :price ], name: 'index_subscription_plans_on_is_active_and_price')
    end

    if table_exists?(:subscriptions)
      remove_index :subscriptions, name: 'index_subscriptions_on_user_id_and_current_period_end' if index_exists?(:subscriptions, [ :user_id, :current_period_end ], name: 'index_subscriptions_on_user_id_and_current_period_end')
    end

    if table_exists?(:card_readings)
      remove_index :card_readings, name: 'index_card_readings_on_reading_id_and_position' if index_exists?(:card_readings, [ :reading_id, :position ], name: 'index_card_readings_on_reading_id_and_position')
      remove_index :card_readings, name: 'index_card_readings_on_user_id_and_reading_date' if index_exists?(:card_readings, [ :user_id, :reading_date ], name: 'index_card_readings_on_user_id_and_reading_date')
    end

    if table_exists?(:readings)
      remove_index :readings, name: 'index_readings_on_created_at_and_status' if index_exists?(:readings, [ :created_at, :status ], name: 'index_readings_on_created_at_and_status')
      remove_index :readings, name: 'index_readings_on_user_id_spread_id_status' if index_exists?(:readings, [ :user_id, :spread_id, :status ], name: 'index_readings_on_user_id_spread_id_status')
    end

    if table_exists?(:api_keys)
      remove_index :api_keys, name: 'index_api_keys_on_organization_id_and_active' if index_exists?(:api_keys, [ :organization_id, :active ], name: 'index_api_keys_on_organization_id_and_active')
      remove_index :api_keys, name: 'index_api_keys_on_user_id_and_active' if index_exists?(:api_keys, [ :user_id, :active ], name: 'index_api_keys_on_user_id_and_active')
    end
  end
end
