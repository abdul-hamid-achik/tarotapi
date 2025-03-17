class AddSessionIdToReadingSessions < ActiveRecord::Migration[8.0]
  def up
    add_column :reading_sessions, :session_id, :string
    add_index :reading_sessions, :session_id, unique: true

    ReadingSession.find_each do |session|
      session.update_column(:session_id, SecureRandom.uuid)
    end

    change_column_null :reading_sessions, :session_id, false
  end

  def down
    remove_column :reading_sessions, :session_id
  end
end
