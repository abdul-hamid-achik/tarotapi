class CreateCardReadings < ActiveRecord::Migration[8.0]
  def change
    create_table :card_readings do |t|
      t.references :user, null: false, foreign_key: true
      t.references :tarot_card, null: false, foreign_key: true
      t.integer :position
      t.boolean :is_reversed
      t.text :notes

      t.timestamps
    end
  end
end
