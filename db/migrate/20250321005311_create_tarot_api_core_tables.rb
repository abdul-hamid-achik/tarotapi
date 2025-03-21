class CreateTarotApiCoreTables < ActiveRecord::Migration[7.1]
  def change
    create_table :identity_providers do |t|
      t.string :name, null: false
      t.string :provider_type
      t.jsonb :settings, default: {}
      
      t.timestamps
      t.index :name, unique: true
    end

    create_table :users do |t|
      t.string :email
      t.string :password_digest
      t.string :external_id
      t.references :identity_provider, foreign_key: true
      t.references :created_by_user, foreign_key: { to_table: :users }, null: true
      t.string :refresh_token
      t.datetime :token_expiry
      t.integer :readings_count, default: 0
      
      t.timestamps
      t.index [:external_id, :identity_provider_id], unique: true
      t.index :email, unique: true, where: "email IS NOT NULL"
    end

    create_table :cards do |t|
      t.string :name, null: false
      t.string :suit
      t.integer :number
      t.text :description
      t.string :keywords, array: true, default: []
      t.string :image_url
      
      t.timestamps
      t.index :name, unique: true
    end

    create_table :spreads do |t|
      t.string :name, null: false
      t.text :description
      t.integer :num_cards, null: false
      t.references :user, foreign_key: true
      
      t.timestamps
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
    end

    create_table :card_readings do |t|
      t.references :card, foreign_key: true
      t.references :reading, foreign_key: true
      t.integer :position
      t.boolean :reversed, default: false
      t.text :interpretation
      
      t.timestamps
      t.index [:reading_id, :position], unique: true
    end

    create_table :subscriptions do |t|
      t.references :user, foreign_key: true
      t.string :plan_name, null: false
      t.string :status, default: 'pending'
      t.datetime :current_period_start
      t.datetime :current_period_end
      t.jsonb :metadata, default: {}
      
      t.timestamps
      t.index :status
    end

    create_table :reading_quotas do |t|
      t.references :user, foreign_key: true
      t.integer :monthly_limit
      t.integer :current_count, default: 0
      t.datetime :reset_at
      
      t.timestamps
    end

    create_table :card_interpretations do |t|
      t.references :card, foreign_key: true
      t.text :upright_meaning
      t.text :reversed_meaning
      t.string :category
      t.jsonb :metadata, default: {}
      
      t.timestamps
      t.index [:card_id, :category], unique: true
    end
  end
end
