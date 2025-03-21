class AddVersioningToSpreads < ActiveRecord::Migration[8.0]
  def change
    add_column :spreads, :version, :string, default: "v1"
    add_column :spreads, :previous_version_id, :integer
    add_column :spreads, :next_version_id, :integer
    add_column :spreads, :is_current_version, :boolean, default: true
    add_column :spreads, :published_at, :datetime
    add_column :spreads, :deprecated_at, :datetime

    add_index :spreads, :version
    add_index :spreads, :previous_version_id
    add_index :spreads, :next_version_id
    add_index :spreads, :is_current_version
  end
end
