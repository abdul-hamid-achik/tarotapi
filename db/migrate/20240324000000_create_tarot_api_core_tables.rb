class CreateTarotApiCoreTables < ActiveRecord::Migration[7.0]
  def change
    # Only enable pg_trgm if using PostgreSQL
    if connection.adapter_name.downcase.include?('postgresql')
      unless connection.select_value("SELECT 1 FROM pg_extension WHERE extname = 'pg_trgm'")
        enable_extension 'pg_trgm'
      end
    end

    create_table :identity_providers do |t|
      t.string :name, null: false
      t.string :provider_type
      # Use text for SQLite, jsonb for PostgreSQL
      if connection.adapter_name.downcase.include?('postgresql')
        t.jsonb :settings, default: {}
      else
        t.text :settings, default: '{}'
      end

      t.timestamps
      t.index :name, unique: true
    end

    create_table :subscription_plans do |t|
      t.string :name, null: false
      t.integer :price_cents, default: 0
      t.integer :reading_limit
      t.string :interval, default: 'month'
      t.decimal :price, precision: 10, scale: 2, default: 0.0
      t.integer :monthly_readings, default: 0
      t.integer :duration_days, default: 30
      t.boolean :is_active, default: true
      # Handle array type for SQLite
      if connection.adapter_name.downcase.include?('postgresql')
        t.string :features, array: true, default: []
        t.jsonb :metadata, default: {}
      else
        t.text :features, default: '[]' # store as JSON string
        t.text :metadata, default: '{}'
      end

      t.timestamps
      t.index :name, unique: true
      t.index :is_active
    end

    create_table :users do |t|
      t.string :name
      t.string :email
      t.string :password_digest
      t.string :external_id
      t.references :identity_provider, foreign_key: true
      t.references :created_by_user, foreign_key: { to_table: :users }, null: true
      t.string :refresh_token
      t.datetime :token_expiry
      t.integer :readings_count, default: 0
      t.boolean :admin, default: false

      t.timestamps
      t.index [ :external_id, :identity_provider_id ], unique: true
      t.index :email, unique: true, where: "email IS NOT NULL"
      t.index :name
    end

    create_table :cards do |t|
      t.string :name, null: false
      t.string :arcana, null: false
      t.string :suit
      t.string :rank
      t.text :description
      # Handle array type for SQLite
      if connection.adapter_name.downcase.include?('postgresql')
        t.string :keywords, array: true, default: []
        t.string :symbols, array: true, default: []
      else
        t.text :keywords, default: '[]' # store as JSON string
        t.text :symbols, default: '[]'
      end
      t.string :image_url

      t.timestamps
      t.index :name, unique: true
      t.index :arcana
      t.index :suit
      t.index [ :suit, :rank ]
      # Add GIN indexes only for PostgreSQL
      if connection.adapter_name.downcase.include?('postgresql')
        t.index :keywords, using: :gin
        t.index :symbols, using: :gin
      end
    end

    create_table :spreads do |t|
      t.string :name, null: false
      t.text :description
      t.integer :num_cards, null: false
      t.references :user, foreign_key: true
      t.text :positions, default: "{}"
      t.boolean :is_public, default: false
      t.boolean :is_system, default: false

      t.timestamps
      t.index :name
      t.index :is_public
      t.index :is_system
      # Add GIN indexes only for PostgreSQL
      if connection.adapter_name.downcase.include?('postgresql')
        t.index :positions, using: :gin, opclass: :gin_trgm_ops
      end
    end

    create_table :readings do |t|
      t.references :user, foreign_key: true
      t.references :spread, foreign_key: true
      t.text :question
      t.text :interpretation
      t.datetime :completed_at
      t.string :status, default: 'pending'

      t.timestamps
      t.index :status
      t.index :created_at
      t.index [ :completed_at, :status ]
      t.index [ :user_id, :created_at ]
      t.index [ :user_id, :status ]
    end

    create_table :card_readings do |t|
      t.references :card, foreign_key: true
      t.references :reading, foreign_key: true
      t.integer :position
      t.boolean :reversed, default: false
      t.text :interpretation

      t.timestamps
      t.index [ :reading_id, :position ], unique: true
      t.index [ :reading_id, :card_id ]
      t.index [ :card_id, :reading_id ]
      t.index [ :card_id, :created_at ]
    end

    create_table :subscriptions do |t|
      t.references :user, foreign_key: true
      t.references :subscription_plan, foreign_key: true
      t.string :plan_name, null: false
      t.string :status, default: 'pending'
      t.datetime :current_period_start
      t.datetime :current_period_end
      # Handle jsonb for SQLite
      if connection.adapter_name.downcase.include?('postgresql')
        t.jsonb :metadata, default: {}
      else
        t.text :metadata, default: '{}'
      end

      t.timestamps
      t.index :status
      t.index [ :user_id, :status ]
      t.index [ :user_id, :plan_name, :status ]
      t.index [ :current_period_start, :current_period_end ], name: 'idx_on_current_period_start_current_period_end_ef96a9f506'
    end

    create_table :reading_quotas do |t|
      t.references :user, foreign_key: true
      t.integer :monthly_limit
      t.integer :current_count, default: 0
      t.datetime :reset_at

      t.timestamps
      t.index [ :user_id, :reset_at ]
      t.index [ :reset_at, :current_count ]
    end

    create_table :card_interpretations do |t|
      t.references :card, foreign_key: true
      t.text :upright_meaning
      t.text :reversed_meaning
      t.string :category
      # Handle jsonb for SQLite
      if connection.adapter_name.downcase.include?('postgresql')
        t.jsonb :metadata, default: {}
      else
        t.text :metadata, default: '{}'
      end

      t.timestamps
      t.index [ :card_id, :category ], unique: true
      t.index [ :card_id, :created_at ]
      t.index :category
    end
  end
end
