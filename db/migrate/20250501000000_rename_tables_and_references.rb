class RenameTablesAndReferences < ActiveRecord::Migration[8.0]
  def change
    # Step 1: Rename tarot_cards table to cards
    rename_table :tarot_cards, :cards
    
    # Step 2: Rename reading_sessions table to readings
    rename_table :reading_sessions, :readings
    
    # Step 3: Update foreign keys in card_readings
    # First, rename tarot_card_id to card_id
    rename_column :card_readings, :tarot_card_id, :card_id
    
    # Then, rename reading_session_id to reading_id
    rename_column :card_readings, :reading_session_id, :reading_id
    
    # Step 4: Update indices to match the new column names
    rename_index :card_readings, 'index_card_readings_on_tarot_card_id', 'index_card_readings_on_card_id' if index_exists?(:card_readings, :tarot_card_id)
    rename_index :card_readings, 'index_card_readings_on_reading_session_id', 'index_card_readings_on_reading_id' if index_exists?(:card_readings, :reading_session_id)
    
    # Step 5: Add usage_counted column to readings if it doesn't exist
    unless column_exists?(:readings, :usage_counted)
      add_column :readings, :usage_counted, :boolean, default: false
      add_index :readings, :usage_counted
    end
  end
end 