class AddSpreadAndInterpretationToCardReadings < ActiveRecord::Migration[8.0]
  def change
    add_reference :card_readings, :spread, foreign_key: true
    add_column :card_readings, :interpretation, :text
    add_column :card_readings, :spread_position, :jsonb
    add_column :card_readings, :reading_date, :datetime
  end
end
