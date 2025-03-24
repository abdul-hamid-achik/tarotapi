class AddPerformanceIndices < ActiveRecord::Migration[7.0]
  def change
    # Add indices for better API performance
    add_index :api_keys, [ :user_id, :active ], name: 'index_api_keys_on_user_id_and_active'
    add_index :api_keys, [ :organization_id, :active ], name: 'index_api_keys_on_organization_id_and_active'

    # Add indices for better reading performance
    add_index :readings, [ :user_id, :spread_id, :status ], name: 'index_readings_on_user_id_spread_id_status'
    add_index :readings, [ :created_at, :status ], name: 'index_readings_on_created_at_and_status'

    # Add indices for better card reading performance
    add_index :card_readings, [ :user_id, :reading_date ], name: 'index_card_readings_on_user_id_and_reading_date'
    add_index :card_readings, [ :spread_id, :position ], name: 'index_card_readings_on_spread_id_and_position'

    # Add indices for better subscription performance
    add_index :subscriptions, [ :user_id, :current_period_end ], name: 'index_subscriptions_on_user_id_and_current_period_end'
    add_index :subscription_plans, [ :is_active, :price ], name: 'index_subscription_plans_on_is_active_and_price'

    # Add indices for better organization performance
    add_index :organizations, [ :status, :plan ], name: 'index_organizations_on_status_and_plan'
    add_index :memberships, [ :user_id, :role, :status ], name: 'index_memberships_on_user_id_role_status'
  end

  def down
    remove_index :memberships, name: 'index_memberships_on_user_id_role_status'
    remove_index :organizations, name: 'index_organizations_on_status_and_plan'
    remove_index :subscription_plans, name: 'index_subscription_plans_on_is_active_and_price'
    remove_index :subscriptions, name: 'index_subscriptions_on_user_id_and_current_period_end'
    remove_index :card_readings, name: 'index_card_readings_on_spread_id_and_position'
    remove_index :card_readings, name: 'index_card_readings_on_user_id_and_reading_date'
    remove_index :readings, name: 'index_readings_on_created_at_and_status'
    remove_index :readings, name: 'index_readings_on_user_id_spread_id_status'
    remove_index :api_keys, name: 'index_api_keys_on_organization_id_and_active'
    remove_index :api_keys, name: 'index_api_keys_on_user_id_and_active'
  end
end
