class CreateTarotApiSchema < ActiveRecord::Migration[7.0]
  def change
    # Create identity_providers table
    create_table :identity_providers do |t|
      t.string :name, null: false
      t.string :description
      t.jsonb :settings, default: {}

      t.timestamps
    end

    add_index :identity_providers, :name, unique: true

    # Create users table with authentication fields
    create_table :users do |t|
      t.string :external_id
      t.references :identity_provider, foreign_key: true
      t.jsonb :metadata, default: {}
      t.string :email, null: false
      t.string :name
      t.boolean :admin, default: false
      t.string :password_digest, null: false
      t.string :refresh_token      # For token refresh
      t.datetime :token_expiry     # For token expiration
      t.string :stripe_customer_id # For Stripe integration
      t.string :api_key
      t.datetime :api_key_expires_at
      t.datetime :last_login_at
      t.boolean :active, default: true

      t.timestamps
    end

    add_index :users, [ :identity_provider_id, :external_id ], unique: true
    add_index :users, :email, unique: true
    add_index :users, :api_key, unique: true

    # Create tarot_cards table
    create_table :tarot_cards do |t|
      t.string :name, null: false
      t.string :arcana
      t.string :suit
      t.text :description
      t.string :rank
      t.text :symbols
      t.text :image_url

      t.timestamps
    end

    add_index :tarot_cards, :name, unique: true
    add_index :tarot_cards, :rank
    add_index :tarot_cards, [ :arcana, :suit ]

    # Create spreads table
    create_table :spreads do |t|
      t.text :name, null: false
      t.text :description
      t.jsonb :positions
      t.integer :num_cards
      t.boolean :is_public
      t.boolean :is_system, default: false
      t.jsonb :astrological_context
      t.references :user, null: false, foreign_key: true
      t.boolean :active, default: true
      t.string :difficulty_level, default: "medium"
      t.string :purpose
      t.string :theme

      t.timestamps
    end

    add_index :spreads, :name
    add_index :spreads, :is_public
    add_index :spreads, :is_system

    # Create reading_sessions table
    create_table :reading_sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :spread, null: false, foreign_key: true
      t.text :question, null: false
      t.text :interpretation
      t.datetime :reading_date, null: false
      t.jsonb :astrological_context
      t.date :birth_date
      t.string :name
      t.string :session_id, default: -> { "gen_random_uuid()" }
      t.string :status, default: "completed"

      t.timestamps
    end

    add_index :reading_sessions, :session_id, unique: true
    add_index :reading_sessions, :name

    # Create card_readings table
    create_table :card_readings do |t|
      t.references :user, null: false, foreign_key: true
      t.references :tarot_card, null: false, foreign_key: true
      t.integer :position
      t.boolean :is_reversed, default: false
      t.text :notes
      t.references :spread, foreign_key: true
      t.text :interpretation
      t.jsonb :spread_position
      t.datetime :reading_date
      t.references :reading_session, null: false, foreign_key: true

      t.timestamps
    end

    add_index :card_readings, [ :user_id, :created_at ]
    add_index :card_readings, [ :tarot_card_id, :created_at ]
    add_index :card_readings, [ :user_id, :tarot_card_id, :created_at ], name: 'idx_card_readings_user_tarot_created'

    # Create subscriptions table
    create_table :subscriptions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :stripe_id, null: false
      t.string :stripe_customer_id
      t.string :plan_name, null: false
      t.string :status, null: false
      t.datetime :current_period_start
      t.datetime :current_period_end
      t.datetime :ends_at

      t.timestamps
    end

    add_index :subscriptions, :stripe_id, unique: true
    add_index :subscriptions, [ :user_id, :status ]

    # User Preferences
    create_table :user_preferences do |t|
      t.references :user, null: false, foreign_key: true
      t.string :theme, default: "light"
      t.json :notification_settings
      t.json :ui_settings
      t.boolean :show_reversed_cards, default: true
      t.string :language, default: "en"
      t.string :timezone
      t.boolean :show_card_images, default: true

      t.timestamps
    end
    add_index :user_preferences, :user_id, unique: true

    # Reading Notes
    create_table :reading_notes do |t|
      t.references :reading_session, null: false, foreign_key: true
      t.text :content, null: false
      t.datetime :note_date, null: false
      t.boolean :is_private, default: true
      t.string :mood
      t.string :tags, array: true

      t.timestamps
    end

    # Feedback
    create_table :feedbacks do |t|
      t.references :reading_session, null: false, foreign_key: true
      t.integer :accuracy_rating
      t.integer :helpfulness_rating
      t.text :comments
      t.boolean :would_recommend
      t.string :feelings, array: true

      t.timestamps
    end
    add_index :feedbacks, :reading_session_id, unique: true

    # Saved Readings
    create_table :saved_readings do |t|
      t.references :user, null: false, foreign_key: true
      t.references :reading_session, null: false, foreign_key: true
      t.string :folder
      t.text :notes
      t.boolean :is_favorite, default: false
      t.string :tags, array: true

      t.timestamps
    end
    add_index :saved_readings, [:user_id, :reading_session_id], unique: true
  end
end
