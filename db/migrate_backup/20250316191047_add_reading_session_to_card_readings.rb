class AddReadingSessionToCardReadings < ActiveRecord::Migration[8.0]
  def change
    add_reference :card_readings, :reading_session, null: true, foreign_key: true
  end
end 