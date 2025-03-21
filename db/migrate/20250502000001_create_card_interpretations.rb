class CreateCardInterpretations < ActiveRecord::Migration[8.0]
  def change
    create_table :card_interpretations do |t|
      t.references :card, null: false, foreign_key: true, index: { name: "idx_card_interpretations_on_card_id" }
      t.string :position_type # 'upright' or 'reversed'
      t.text :meaning
      t.text :keywords, array: true
      t.jsonb :associations
      t.string :interpretation_type # 'general', 'love', 'career', 'spiritual', etc.
      t.string :version, default: "v1"
      t.boolean :is_current_version, default: true
      t.integer :previous_version_id
      t.integer :next_version_id
      t.datetime :published_at
      t.datetime :deprecated_at

      t.timestamps
    end

    add_index :card_interpretations, [ :card_id, :position_type, :interpretation_type ], name: "idx_card_interpretations_composite"
    add_index :card_interpretations, :version
    add_index :card_interpretations, :is_current_version
  end
end
