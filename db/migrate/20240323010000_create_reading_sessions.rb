class CreateReadingSessions < ActiveRecord::Migration[7.0]
  def change
    create_table :reading_sessions do |t|
      t.string :session_id, null: false
      t.datetime :reading_date
      t.string :status, default: 'completed'
      t.references :user, foreign_key: true
      
      t.timestamps
    end
    
    add_index :reading_sessions, :session_id, unique: true
  end
end 