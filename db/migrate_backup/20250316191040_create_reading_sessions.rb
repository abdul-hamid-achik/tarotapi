class CreateReadingSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :reading_sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :spread, null: true, foreign_key: true
      t.text :question
      t.text :interpretation
      t.datetime :reading_date

      t.timestamps
    end
  end
end 