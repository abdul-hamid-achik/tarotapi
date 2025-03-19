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

ActiveRecord::Schema[8.0].define(version: 2025_03_19_065533) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "card_readings", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "tarot_card_id", null: false
    t.integer "position"
    t.boolean "is_reversed", default: false
    t.text "notes"
    t.bigint "spread_id"
    t.text "interpretation"
    t.jsonb "spread_position"
    t.datetime "reading_date"
    t.bigint "reading_session_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["reading_session_id"], name: "idx_card_readings_on_reading_session_id"
    t.index ["spread_id"], name: "idx_card_readings_on_spread_id"
    t.index ["tarot_card_id", "created_at"], name: "idx_card_readings_on_tarot_card_id_created_at"
    t.index ["tarot_card_id"], name: "idx_card_readings_on_tarot_card_id"
    t.index ["user_id", "created_at"], name: "idx_card_readings_on_user_id_and_created_at"
    t.index ["user_id", "tarot_card_id", "created_at"], name: "idx_card_readings_user_tarot_created"
    t.index ["user_id"], name: "idx_card_readings_on_user_id"
  end

  create_table "feedbacks", force: :cascade do |t|
    t.bigint "reading_session_id", null: false
    t.integer "accuracy_rating"
    t.integer "helpfulness_rating"
    t.text "comments"
    t.boolean "would_recommend"
    t.string "feelings", array: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["reading_session_id"], name: "idx_feedbacks_on_reading_session_id", unique: true
  end

  create_table "identity_providers", force: :cascade do |t|
    t.string "name", null: false
    t.string "description"
    t.jsonb "settings", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "idx_identity_providers_name_unique", unique: true
  end

  create_table "reading_notes", force: :cascade do |t|
    t.bigint "reading_session_id", null: false
    t.text "content", null: false
    t.datetime "note_date", null: false
    t.boolean "is_private", default: true
    t.string "mood"
    t.string "tags", array: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["reading_session_id"], name: "idx_reading_notes_on_reading_session_id"
  end

  create_table "reading_sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "spread_id", null: false
    t.text "question", null: false
    t.text "interpretation"
    t.datetime "reading_date", null: false
    t.jsonb "astrological_context"
    t.date "birth_date"
    t.string "name"
    t.string "session_id", default: -> { "gen_random_uuid()" }
    t.string "status", default: "completed"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "idx_reading_sessions_on_name"
    t.index ["session_id"], name: "idx_reading_sessions_on_session_id_unique", unique: true
    t.index ["spread_id"], name: "idx_reading_sessions_on_spread_id"
    t.index ["user_id"], name: "idx_reading_sessions_on_user_id"
  end

  create_table "saved_readings", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "reading_session_id", null: false
    t.string "folder"
    t.text "notes"
    t.boolean "is_favorite", default: false
    t.string "tags", array: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["reading_session_id"], name: "idx_saved_readings_on_reading_session_id"
    t.index ["user_id", "reading_session_id"], name: "idx_saved_readings_on_user_id_reading_session_id", unique: true
    t.index ["user_id"], name: "idx_saved_readings_on_user_id"
  end

  create_table "spreads", force: :cascade do |t|
    t.text "name", null: false
    t.text "description"
    t.jsonb "positions"
    t.integer "num_cards"
    t.boolean "is_public"
    t.boolean "is_system", default: false
    t.jsonb "astrological_context"
    t.bigint "user_id", null: false
    t.boolean "active", default: true
    t.string "difficulty_level", default: "medium"
    t.string "purpose"
    t.string "theme"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["is_public"], name: "idx_spreads_on_is_public"
    t.index ["is_system"], name: "idx_spreads_on_is_system"
    t.index ["name"], name: "idx_spreads_on_name"
    t.index ["user_id"], name: "idx_spreads_on_user_id"
  end

  create_table "subscriptions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "stripe_id", null: false
    t.string "stripe_customer_id"
    t.string "plan_name", null: false
    t.string "status", null: false
    t.datetime "current_period_start"
    t.datetime "current_period_end"
    t.datetime "ends_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["stripe_id"], name: "idx_subscriptions_on_stripe_id_unique", unique: true
    t.index ["user_id", "status"], name: "idx_subscriptions_on_user_id_and_status"
    t.index ["user_id"], name: "idx_subscriptions_on_user_id"
  end

  create_table "tarot_cards", force: :cascade do |t|
    t.string "name", null: false
    t.string "arcana"
    t.string "suit"
    t.text "description"
    t.string "rank"
    t.text "symbols"
    t.text "image_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["arcana", "suit"], name: "idx_tarot_cards_on_arcana_and_suit"
    t.index ["name"], name: "idx_tarot_cards_on_name_unique", unique: true
    t.index ["rank"], name: "idx_tarot_cards_on_rank"
  end

  create_table "user_preferences", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "theme", default: "light"
    t.json "notification_settings"
    t.json "ui_settings"
    t.boolean "show_reversed_cards", default: true
    t.string "language", default: "en"
    t.string "timezone"
    t.boolean "show_card_images", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "idx_user_preferences_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "external_id"
    t.bigint "identity_provider_id"
    t.jsonb "metadata", default: {}
    t.string "email", null: false
    t.string "name"
    t.boolean "admin", default: false
    t.string "password_digest", null: false
    t.string "refresh_token"
    t.datetime "token_expiry"
    t.string "stripe_customer_id"
    t.string "api_key"
    t.datetime "api_key_expires_at"
    t.datetime "last_login_at"
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["api_key"], name: "idx_users_on_api_key_unique", unique: true
    t.index ["email"], name: "idx_users_on_email_unique", unique: true
    t.index ["identity_provider_id", "external_id"], name: "idx_users_on_identity_provider_external_id", unique: true
    t.index ["identity_provider_id"], name: "idx_users_on_identity_provider_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "card_readings", "reading_sessions"
  add_foreign_key "card_readings", "spreads"
  add_foreign_key "card_readings", "tarot_cards"
  add_foreign_key "card_readings", "users"
  add_foreign_key "feedbacks", "reading_sessions"
  add_foreign_key "reading_notes", "reading_sessions"
  add_foreign_key "reading_sessions", "spreads"
  add_foreign_key "reading_sessions", "users"
  add_foreign_key "saved_readings", "reading_sessions"
  add_foreign_key "saved_readings", "users"
  add_foreign_key "spreads", "users"
  add_foreign_key "subscriptions", "users"
  add_foreign_key "user_preferences", "users"
  add_foreign_key "users", "identity_providers"
end
