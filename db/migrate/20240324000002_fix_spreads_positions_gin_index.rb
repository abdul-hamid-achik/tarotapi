class FixSpreadsPositionsGinIndex < ActiveRecord::Migration[7.0]
  def up
    # First remove the existing index with gin_trgm_ops which is incompatible with jsonb
    if index_exists?(:spreads, :positions)
      remove_index :spreads, :positions
    end

    # Then alter the default to NULL
    execute "ALTER TABLE spreads ALTER COLUMN positions DROP DEFAULT"

    # Then change the column type to jsonb
    execute "ALTER TABLE spreads ALTER COLUMN positions TYPE jsonb USING positions::jsonb"

    # Then set the new default
    execute "ALTER TABLE spreads ALTER COLUMN positions SET DEFAULT '{}'::jsonb"

    # Create appropriate index for jsonb (jsonb_path_ops instead of gin_trgm_ops)
    add_index :spreads, :positions, using: :gin, opclass: { positions: :jsonb_path_ops }
  end

  def down
    # First remove the jsonb_path_ops index
    if index_exists?(:spreads, :positions)
      remove_index :spreads, :positions
    end

    # First, alter the default to NULL
    execute "ALTER TABLE spreads ALTER COLUMN positions DROP DEFAULT"

    # Then change back to text
    execute "ALTER TABLE spreads ALTER COLUMN positions TYPE text USING positions::text"

    # Then set the default back
    execute "ALTER TABLE spreads ALTER COLUMN positions SET DEFAULT '{}'"

    # Add back the appropriate index for text
    add_index :spreads, :positions, using: :gin, opclass: :gin_trgm_ops
  end
end
