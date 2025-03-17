class AddUserIdToSpreads < ActiveRecord::Migration[8.0]
  def up
    add_reference :spreads, :user, null: true, foreign_key: true
    
    # create a default user for existing spreads
    default_user = User.create!(email: 'system@example.com')
    
    # update existing spreads
    Spread.where(user_id: nil).update_all(user_id: default_user.id)
    
    # make user_id not nullable
    change_column_null :spreads, :user_id, false
  end

  def down
    remove_reference :spreads, :user
  end
end
