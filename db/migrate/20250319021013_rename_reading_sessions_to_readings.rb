class RenameReadingSessionsToReadings < ActiveRecord::Migration[7.0]
  def change
    # Rename the table
    rename_table :reading_sessions, :readings

    # Update foreign keys
    rename_column :card_readings, :reading_session_id, :reading_id
    rename_column :feedbacks, :reading_session_id, :reading_id
    rename_column :reading_notes, :reading_session_id, :reading_id
    rename_column :saved_readings, :reading_session_id, :reading_id
  end
end
