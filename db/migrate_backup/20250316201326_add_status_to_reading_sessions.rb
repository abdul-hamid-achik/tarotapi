class AddStatusToReadingSessions < ActiveRecord::Migration[8.0]
  def up
    add_column :reading_sessions, :status, :string, default: 'completed'
    ReadingSession.update_all(status: 'completed')
  end

  def down
    remove_column :reading_sessions, :status
  end
end
