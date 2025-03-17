class RemoveUniqueConstraintFromReadingSessionName < ActiveRecord::Migration[8.0]
  def up
    # Remove any unique index on the name column if it exists
    if index_exists?(:reading_sessions, :name, unique: true)
      remove_index :reading_sessions, :name
    end
    
    # Add a non-unique index if needed for performance
    unless index_exists?(:reading_sessions, :name)
      add_index :reading_sessions, :name, unique: false
    end
  end
  
  def down
    # This migration is not reversible as we don't know if there was a unique index before
    raise ActiveRecord::IrreversibleMigration
  end
end
