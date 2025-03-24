class AddMissingIndicesAndTables < ActiveRecord::Migration[7.0]
  def change
    # Add versions table for PaperTrail
    create_table :versions do |t|
      t.string   :item_type, null: false
      t.bigint   :item_id,   null: false
      t.string   :event,     null: false
      t.string   :whodunnit
      t.text     :object
      t.text     :object_changes
      t.datetime :created_at
      t.index [ :item_type, :item_id ], name: 'index_versions_on_item_type_and_item_id'
    end

    # Add Action Text rich texts table
    create_table :action_text_rich_texts do |t|
      t.string     :name, null: false
      t.text       :body
      t.references :record, null: false, polymorphic: true, index: false
      t.timestamps
      t.index [ :record_type, :record_id, :name ], name: "index_action_text_rich_texts_uniqueness", unique: true
    end

    # Add friendly_id slugs table
    create_table :friendly_id_slugs do |t|
      t.string   :slug,           null: false
      t.integer  :sluggable_id,   null: false
      t.string   :sluggable_type, limit: 50
      t.string   :scope
      t.datetime :created_at
      t.index [ :sluggable_type, :sluggable_id ], name: 'index_friendly_id_slugs_on_sluggable_type_and_sluggable_id'
      t.index [ :slug, :sluggable_type ], name: 'index_friendly_id_slugs_on_slug_and_sluggable_type', length: { slug: 140, sluggable_type: 50 }
      t.index [ :slug, :sluggable_type, :scope ], name: 'index_friendly_id_slugs_on_slug_and_sluggable_type_and_scope', length: { slug: 70, sluggable_type: 50, scope: 70 }, unique: true
    end

    # Add missing indices for better query performance
    add_index :readings, [ :user_id, :spread_id, :created_at ], name: 'index_readings_on_user_id_spread_id_created_at'
    add_index :card_readings, :reading_date, name: 'index_card_readings_on_reading_date'

    # Add GiST index for full text search on cards description
    enable_extension 'btree_gist'
    execute <<-SQL
      CREATE INDEX index_cards_on_description_gist ON cards USING gist(to_tsvector('english', description));
    SQL
  end

  def down
    remove_index :card_readings, name: 'index_card_readings_on_reading_date'
    remove_index :readings, name: 'index_readings_on_user_id_spread_id_created_at'

    execute 'DROP INDEX IF EXISTS index_cards_on_description_gist;'
    disable_extension 'btree_gist'

    drop_table :friendly_id_slugs
    drop_table :action_text_rich_texts
    drop_table :versions
  end
end
