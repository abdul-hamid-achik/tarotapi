class AddIsSystemToSpreads < ActiveRecord::Migration[7.1]
  def change
    add_column :spreads, :is_system, :boolean, default: false
    add_index :spreads, :is_system
  end
end 