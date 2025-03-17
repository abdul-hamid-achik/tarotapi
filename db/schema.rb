# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_03_16_220659) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "card_readings", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "tarot_card_id", null: false
    t.integer "position"
    t.boolean "is_reversed"
    t.text "notes"
    t.bigint "spread_id"
    t.text "interpretation"
    t.jsonb "spread_position"
    t.datetime "reading_date"
    t.bigint "reading_session_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["reading_session_id"], name: "index_card_readings_on_reading_session_id"
    t.index ["spread_id"], name: "index_card_readings_on_spread_id"
    t.index ["tarot_card_id", "created_at"], name: "index_card_readings_on_tarot_card_id_and_created_at"
    t.index ["tarot_card_id"], name: "index_card_readings_on_tarot_card_id"
    t.index ["user_id", "created_at"], name: "index_card_readings_on_user_id_and_created_at"
    t.index ["user_id", "tarot_card_id", "created_at"], name: "idx_on_user_id_tarot_card_id_created_at_cacb7b1721"
    t.index ["user_id"], name: "index_card_readings_on_user_id"
  end

  create_table "identity_providers", force: :cascade do |t|
    t.string "name", null: false
    t.string "description"
    t.jsonb "settings", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_identity_providers_on_name", unique: true
  end

  create_table "reading_sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "spread_id"
    t.text "question"
    t.text "interpretation"
    t.datetime "reading_date"
    t.jsonb "astrological_context"
    t.date "birth_date"
    t.string "name"
    t.string "status", default: "completed"
    t.string "session_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_reading_sessions_on_name"
    t.index ["session_id"], name: "index_reading_sessions_on_session_id", unique: true
    t.index ["spread_id"], name: "index_reading_sessions_on_spread_id"
    t.index ["user_id"], name: "index_reading_sessions_on_user_id"
  end

  create_table "spreads", force: :cascade do |t|
    t.text "name"
    t.text "description"
    t.jsonb "positions"
    t.boolean "is_public"
    t.boolean "is_system", default: false
    t.jsonb "astrological_context"
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["is_public"], name: "index_spreads_on_is_public"
    t.index ["is_system"], name: "index_spreads_on_is_system"
    t.index ["name"], name: "index_spreads_on_name"
    t.index ["user_id"], name: "index_spreads_on_user_id"
  end

  create_table "tarot_cards", force: :cascade do |t|
    t.string "name"
    t.string "arcana"
    t.string "suit"
    t.text "description"
    t.string "rank"
    t.text "symbols"
    t.text "image_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["arcana", "suit"], name: "index_tarot_cards_on_arcana_and_suit"
    t.index ["name"], name: "index_tarot_cards_on_name", unique: true
    t.index ["rank"], name: "index_tarot_cards_on_rank"
  end

  create_table "users", force: :cascade do |t|
    t.string "external_id"
    t.bigint "identity_provider_id"
    t.jsonb "metadata", default: {}
    t.string "email"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["identity_provider_id", "external_id"], name: "index_users_on_identity_provider_id_and_external_id", unique: true
  end

  add_foreign_key "card_readings", "reading_sessions"
  add_foreign_key "card_readings", "spreads"
  add_foreign_key "card_readings", "tarot_cards"
  add_foreign_key "card_readings", "users"
  add_foreign_key "reading_sessions", "spreads"
  add_foreign_key "reading_sessions", "users"
  add_foreign_key "spreads", "users"
  add_foreign_key "users", "identity_providers"
end
