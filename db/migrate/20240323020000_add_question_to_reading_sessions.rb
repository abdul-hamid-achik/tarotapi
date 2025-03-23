class AddQuestionToReadingSessions < ActiveRecord::Migration[7.0]
  def change
    add_column :reading_sessions, :question, :string
    add_reference :reading_sessions, :spread, foreign_key: true
  end
end 