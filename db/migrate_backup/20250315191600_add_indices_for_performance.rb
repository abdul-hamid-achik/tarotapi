class AddIndicesForPerformance < ActiveRecord::Migration[8.0]
  def change
    # optimize tarot_cards queries
    add_index :tarot_cards, :name, unique: true
    add_index :tarot_cards, [:arcana, :suit]
    add_index :tarot_cards, :rank

    # optimize spreads queries
    add_index :spreads, :name
    add_index :spreads, [:user_id, :is_public]
    add_index :spreads, :is_public

    # optimize card_readings queries
    add_index :card_readings, [:user_id, :created_at]
    add_index :card_readings, [:tarot_card_id, :created_at]
    add_index :card_readings, [:user_id, :tarot_card_id, :created_at]
  end
end 