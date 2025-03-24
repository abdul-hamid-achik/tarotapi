class FixSpreadsPositionsGinIndex < ActiveRecord::Migration[7.0]
  def up
    # First, change the column type to jsonb
    change_column :spreads, :positions, :jsonb, default: '{}'

    # Then create the appropriate index
    remove_index :spreads, :positions if index_exists?(:spreads, :positions)
    add_index :spreads, :positions, using: :gin, opclass: :jsonb_path_ops
  end

  def down
    remove_index :spreads, :positions if index_exists?(:spreads, :positions)
    change_column :spreads, :positions, :text, default: '{}'
    add_index :spreads, :positions, using: :gin
  end
end
