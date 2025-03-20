class RenameCardReadingsToReadings < ActiveRecord::Migration[6.1]
  def change
    rename_table :card_readings, :readings
    
    # rename any foreign keys if needed
    # example: rename_column :other_tables, :card_reading_id, :reading_id
  end
end 