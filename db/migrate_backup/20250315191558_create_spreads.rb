class CreateSpreads < ActiveRecord::Migration[8.0]
  def change
    create_table :spreads do |t|
      t.text :name
      t.text :description
      t.jsonb :positions
      t.references :user, null: false, foreign_key: true
      t.boolean :is_public

      t.timestamps
    end
  end
end
