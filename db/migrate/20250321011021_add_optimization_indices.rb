class AddOptimizationIndices < ActiveRecord::Migration[7.1]
  def change
    # Users - Index for auth-related queries and user lookup patterns
    add_index :users, :refresh_token, where: "refresh_token IS NOT NULL"
    add_index :users, [ :email, :identity_provider_id ], where: "email IS NOT NULL"
    add_index :users, :token_expiry

    # Readings - Common query patterns for user readings and status filtering
    add_index :readings, [ :user_id, :created_at ]
    add_index :readings, [ :user_id, :status ]
    add_index :readings, [ :completed_at, :status ]
    add_index :readings, :created_at

    # Card Readings - Optimize card position queries and reading relationships
    add_index :card_readings, [ :card_id, :reading_id ]
    add_index :card_readings, [ :reading_id, :card_id ]
    add_index :card_readings, [ :card_id, :created_at ]

    # Cards - Optimize card lookups by various attributes
    add_index :cards, :suit
    add_index :cards, [ :suit, :number ]
    add_index :cards, :keywords, using: :gin

    # Card Interpretations - Optimize meaning lookups
    add_index :card_interpretations, [ :card_id, :created_at ]
    add_index :card_interpretations, :category

    # Subscriptions - Track active subscriptions and periods
    add_index :subscriptions, [ :user_id, :status ]
    add_index :subscriptions, [ :current_period_start, :current_period_end ]
    add_index :subscriptions, [ :user_id, :plan_name, :status ]

    # Reading Quotas - Optimize quota checks
    add_index :reading_quotas, [ :user_id, :reset_at ]
    add_index :reading_quotas, [ :reset_at, :current_count ]

    # Spreads - Common access patterns
    add_index :spreads, [ :user_id, :name ]
    add_index :spreads, :num_cards
  end
end
