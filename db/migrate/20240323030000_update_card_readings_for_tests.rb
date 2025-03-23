class UpdateCardReadingsForTests < ActiveRecord::Migration[7.0]
  def change
    add_reference :card_readings, :user, foreign_key: true, null: true
    
    # The column is called 'reversed' in the database, but our code expects 'is_reversed'
    # Let's create an alias and add a migration to change it when it doesn't exist
    unless column_exists?(:card_readings, :is_reversed)
      if column_exists?(:card_readings, :reversed)
        # Create a view to make both columns work
        execute <<-SQL
          ALTER TABLE card_readings ADD COLUMN is_reversed BOOLEAN 
          GENERATED ALWAYS AS (reversed) STORED;
        SQL
      else
        add_column :card_readings, :is_reversed, :boolean, default: false
      end
    end
    
    add_column :card_readings, :reading_date, :datetime unless column_exists?(:card_readings, :reading_date)
    add_reference :card_readings, :spread, foreign_key: true, null: true unless column_exists?(:card_readings, :spread_id)
    
    # Add an index for performance
    add_index :card_readings, [:user_id, :created_at], name: 'index_card_readings_on_user_id_and_created_at' unless index_exists?(:card_readings, [:user_id, :created_at], name: 'index_card_readings_on_user_id_and_created_at')
  end
end 