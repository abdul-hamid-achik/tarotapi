class AddReadingSessionToCardReadings < ActiveRecord::Migration[7.0]
  def change
    add_reference :card_readings, :reading_session, foreign_key: true
    add_column :card_readings, :is_reversed, :boolean, default: false, null: false unless column_exists?(:card_readings, :is_reversed)
    add_column :card_readings, :reading_date, :datetime unless column_exists?(:card_readings, :reading_date)
  end
end 