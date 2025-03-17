class InitSchema < ActiveRecord::Migration[8.0]
  def change
    # Create identity providers table
    create_table :identity_providers do |t|
      t.string :name, null: false
      t.string :description
      t.jsonb :settings, default: {}

      t.timestamps
    end
    add_index :identity_providers, :name, unique: true

    # Create users table
    create_table :users do |t|
      t.string :external_id
      t.bigint :identity_provider_id
      t.jsonb :metadata, default: {}
      t.string :email

      t.timestamps
    end
    add_index :users, [:identity_provider_id, :external_id], unique: true

    # Create tarot cards table
    create_table :tarot_cards do |t|
      t.string :name
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
    add_index :tarot_cards, [:arcana, :suit]

    # Create spreads table
    create_table :spreads do |t|
      t.text :name
      t.text :description
      t.jsonb :positions
      t.boolean :is_public
      t.boolean :is_system, default: false
      t.jsonb :astrological_context
      t.bigint :user_id, null: false

      t.timestamps
    end
    add_index :spreads, :name
    add_index :spreads, :is_public
    add_index :spreads, :is_system
    add_index :spreads, :user_id

    # Create reading sessions table
    create_table :reading_sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :spread, null: true, foreign_key: true
      t.text :question
      t.text :interpretation
      t.datetime :reading_date
      t.jsonb :astrological_context
      t.date :birth_date
      t.string :name
      t.string :status, default: 'completed'
      t.string :session_id, null: false

      t.timestamps
    end
    add_index :reading_sessions, :session_id, unique: true
    add_index :reading_sessions, :name, unique: false

    # Create card readings table
    create_table :card_readings do |t|
      t.bigint :user_id, null: false
      t.bigint :tarot_card_id, null: false
      t.integer :position
      t.boolean :is_reversed
      t.text :notes
      t.bigint :spread_id
      t.text :interpretation
      t.jsonb :spread_position
      t.datetime :reading_date
      t.bigint :reading_session_id, null: false

      t.timestamps
    end
    add_index :card_readings, :user_id
    add_index :card_readings, :tarot_card_id
    add_index :card_readings, :spread_id
    add_index :card_readings, :reading_session_id
    add_index :card_readings, [:user_id, :created_at]
    add_index :card_readings, [:tarot_card_id, :created_at]
    add_index :card_readings, [:user_id, :tarot_card_id, :created_at], name: 'idx_on_user_id_tarot_card_id_created_at_cacb7b1721'

    # Add foreign keys
    add_foreign_key :users, :identity_providers
    add_foreign_key :spreads, :users
    add_foreign_key :card_readings, :users
    add_foreign_key :card_readings, :tarot_cards
    add_foreign_key :card_readings, :spreads
    add_foreign_key :card_readings, :reading_sessions
  end
end
