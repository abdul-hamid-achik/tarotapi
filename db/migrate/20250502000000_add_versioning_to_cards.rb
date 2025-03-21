class AddVersioningToCards < ActiveRecord::Migration[8.0]
  def change
    add_column :cards, :version, :string, default: "v1"
    add_column :cards, :previous_version_id, :integer
    add_column :cards, :next_version_id, :integer
    add_column :cards, :is_current_version, :boolean, default: true
    add_column :cards, :published_at, :datetime
    add_column :cards, :deprecated_at, :datetime

    add_index :cards, :version
    add_index :cards, :previous_version_id
    add_index :cards, :next_version_id
    add_index :cards, :is_current_version
  end
end
