class RenameTarotCardsToCards < ActiveRecord::Migration[6.1]
  def change
    rename_table :tarot_cards, :cards
    
    # rename any foreign keys if needed
    # example: rename_column :readings, :tarot_card_id, :card_id
  end
end 