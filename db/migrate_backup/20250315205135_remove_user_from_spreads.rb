class RemoveUserFromSpreads < ActiveRecord::Migration[8.0]
  def change
    remove_reference :spreads, :user, foreign_key: true
  end
end 