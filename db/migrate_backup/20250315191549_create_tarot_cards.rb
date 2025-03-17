class CreateTarotCards < ActiveRecord::Migration[8.0]
  def change
    create_table :tarot_cards do |t|
      t.string :name
      t.string :arcana
      t.string :suit
      t.text :description
      t.string :rank
      t.text :symbols
      t.text :image_url

      t.timestamps
    end
  end
end
