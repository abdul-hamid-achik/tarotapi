class AddNumerologyFieldsToReadingSessions < ActiveRecord::Migration[8.0]
  def change
    add_column :reading_sessions, :birth_date, :date
    add_column :reading_sessions, :name, :string
  end
end
