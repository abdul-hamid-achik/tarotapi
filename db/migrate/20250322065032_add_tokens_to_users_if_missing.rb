class AddTokensToUsersIfMissing < ActiveRecord::Migration[8.0]
  def change
    # Add tokens column if it doesn't exist
    unless column_exists?(:users, :tokens)
      add_column :users, :tokens, :json, default: {}
    end
    
    # Add provider column if it doesn't exist
    unless column_exists?(:users, :provider)
      add_column :users, :provider, :string, null: false, default: "email"
    end
    
    # Add uid column if it doesn't exist
    unless column_exists?(:users, :uid)
      add_column :users, :uid, :string, null: false, default: ""
    end
    
    # Add other devise token auth fields if they don't exist
    unless column_exists?(:users, :reset_password_token)
      add_column :users, :reset_password_token, :string
    end
    
    unless column_exists?(:users, :reset_password_sent_at)
      add_column :users, :reset_password_sent_at, :datetime
    end
    
    unless column_exists?(:users, :allow_password_change)
      add_column :users, :allow_password_change, :boolean, default: false
    end
    
    unless column_exists?(:users, :remember_created_at)
      add_column :users, :remember_created_at, :datetime
    end
    
    unless column_exists?(:users, :confirmation_token)
      add_column :users, :confirmation_token, :string
    end
    
    unless column_exists?(:users, :confirmed_at)
      add_column :users, :confirmed_at, :datetime
    end
    
    unless column_exists?(:users, :confirmation_sent_at)
      add_column :users, :confirmation_sent_at, :datetime
    end
    
    unless column_exists?(:users, :unconfirmed_email)
      add_column :users, :unconfirmed_email, :string
    end
    
    # Add indexes if they don't exist
    unless index_exists?(:users, [:uid, :provider])
      add_index :users, [:uid, :provider], unique: true
    end
    
    unless index_exists?(:users, :reset_password_token)
      add_index :users, :reset_password_token, unique: true
    end
    
    unless index_exists?(:users, :confirmation_token)
      add_index :users, :confirmation_token, unique: true
    end
  end
end
