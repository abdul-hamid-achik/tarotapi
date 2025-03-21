class AddDatabaseConstraints < ActiveRecord::Migration[8.0]
  def up
    # Add constraints to cards table
    execute <<-SQL
      ALTER TABLE cards#{' '}
      ADD CONSTRAINT check_cards_valid_version#{' '}
      CHECK (version ~ '^v\\d+(\\.\\d+)*$');
    SQL

    # Add constraint to card_interpretations
    execute <<-SQL
      ALTER TABLE card_interpretations#{' '}
      ADD CONSTRAINT check_position_type#{' '}
      CHECK (position_type IN ('upright', 'reversed'));

      ALTER TABLE card_interpretations#{' '}
      ADD CONSTRAINT check_interpretation_type#{' '}
      CHECK (interpretation_type IN ('general', 'love', 'career', 'spiritual', 'financial', 'health'));

      ALTER TABLE card_interpretations#{' '}
      ADD CONSTRAINT check_interpretations_valid_version#{' '}
      CHECK (version ~ '^v\\d+(\\.\\d+)*$');
    SQL

    # Add constraint to spreads
    execute <<-SQL
      ALTER TABLE spreads#{' '}
      ADD CONSTRAINT check_spreads_valid_version#{' '}
      CHECK (version ~ '^v\\d+(\\.\\d+)*$');

      ALTER TABLE spreads#{' '}
      ADD CONSTRAINT check_difficulty_level#{' '}
      CHECK (difficulty_level IN ('beginner', 'easy', 'medium', 'advanced', 'expert'));
    SQL

    # Add constraint to audit_logs
    execute <<-SQL
      ALTER TABLE audit_logs#{' '}
      ADD CONSTRAINT check_valid_action#{' '}
      CHECK (action IN ('create', 'update', 'delete'));
    SQL
  end

  def down
    # Remove constraints from cards table
    execute "ALTER TABLE cards DROP CONSTRAINT IF EXISTS check_cards_valid_version;"

    # Remove constraint from card_interpretations
    execute "ALTER TABLE card_interpretations DROP CONSTRAINT IF EXISTS check_position_type;"
    execute "ALTER TABLE card_interpretations DROP CONSTRAINT IF EXISTS check_interpretation_type;"
    execute "ALTER TABLE card_interpretations DROP CONSTRAINT IF EXISTS check_interpretations_valid_version;"

    # Remove constraint from spreads
    execute "ALTER TABLE spreads DROP CONSTRAINT IF EXISTS check_spreads_valid_version;"
    execute "ALTER TABLE spreads DROP CONSTRAINT IF EXISTS check_difficulty_level;"

    # Remove constraint from audit_logs
    execute "ALTER TABLE audit_logs DROP CONSTRAINT IF EXISTS check_valid_action;"
  end
end
