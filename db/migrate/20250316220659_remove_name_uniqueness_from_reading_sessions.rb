class RemoveNameUniquenessFromReadingSessions < ActiveRecord::Migration[8.0]
  def up
    # Remove any unique index on name if it exists
    if index_exists?(:reading_sessions, :name, unique: true)
      remove_index :reading_sessions, :name
      add_index :reading_sessions, :name, unique: false
    end
    
    # Also check for any other index on name that might be unique
    execute <<-SQL
      DO $$
      BEGIN
        IF EXISTS (
          SELECT 1 FROM pg_indexes 
          WHERE tablename = 'reading_sessions' 
          AND indexdef LIKE '%name%' 
          AND indexdef LIKE '%UNIQUE%'
        ) THEN
          DROP INDEX IF EXISTS index_reading_sessions_on_name;
          CREATE INDEX index_reading_sessions_on_name ON reading_sessions(name);
        END IF;
      END
      $$;
    SQL
  end

  def down
    # No need to add back a unique constraint
  end
end
