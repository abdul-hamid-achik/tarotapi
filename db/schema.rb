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

ActiveRecord::Schema[8.0].define(version: 2025_03_21_011021) do
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

  create_table "card_interpretations", force: :cascade do |t|
    t.bigint "card_id"
    t.text "upright_meaning"
    t.text "reversed_meaning"
    t.string "category"
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["card_id", "category"], name: "index_card_interpretations_on_card_id_and_category", unique: true
    t.index ["card_id", "created_at"], name: "index_card_interpretations_on_card_id_and_created_at"
    t.index ["card_id"], name: "index_card_interpretations_on_card_id"
    t.index ["category"], name: "index_card_interpretations_on_category"
  end

  create_table "card_readings", force: :cascade do |t|
    t.bigint "card_id"
    t.bigint "reading_id"
    t.integer "position"
    t.boolean "reversed", default: false
    t.text "interpretation"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["card_id", "created_at"], name: "index_card_readings_on_card_id_and_created_at"
    t.index ["card_id", "reading_id"], name: "index_card_readings_on_card_id_and_reading_id"
    t.index ["card_id"], name: "index_card_readings_on_card_id"
    t.index ["reading_id", "card_id"], name: "index_card_readings_on_reading_id_and_card_id"
    t.index ["reading_id", "position"], name: "index_card_readings_on_reading_id_and_position", unique: true
    t.index ["reading_id"], name: "index_card_readings_on_reading_id"
  end

  create_table "cards", force: :cascade do |t|
    t.string "name", null: false
    t.string "suit"
    t.integer "number"
    t.text "description"
    t.string "keywords", default: [], array: true
    t.string "image_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["keywords"], name: "index_cards_on_keywords", using: :gin
    t.index ["name"], name: "index_cards_on_name", unique: true
    t.index ["suit", "number"], name: "index_cards_on_suit_and_number"
    t.index ["suit"], name: "index_cards_on_suit"
  end

  create_table "identity_providers", force: :cascade do |t|
    t.string "name", null: false
    t.string "provider_type"
    t.jsonb "settings", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_identity_providers_on_name", unique: true
  end

  create_table "reading_quotas", force: :cascade do |t|
    t.bigint "user_id"
    t.integer "monthly_limit"
    t.integer "current_count", default: 0
    t.datetime "reset_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["reset_at", "current_count"], name: "index_reading_quotas_on_reset_at_and_current_count"
    t.index ["user_id", "reset_at"], name: "index_reading_quotas_on_user_id_and_reset_at"
    t.index ["user_id"], name: "index_reading_quotas_on_user_id"
  end

  create_table "readings", force: :cascade do |t|
    t.bigint "user_id"
    t.bigint "spread_id"
    t.text "question"
    t.text "interpretation"
    t.datetime "completed_at"
    t.string "status", default: "pending"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["completed_at", "status"], name: "index_readings_on_completed_at_and_status"
    t.index ["created_at"], name: "index_readings_on_created_at"
    t.index ["spread_id"], name: "index_readings_on_spread_id"
    t.index ["status"], name: "index_readings_on_status"
    t.index ["user_id", "created_at"], name: "index_readings_on_user_id_and_created_at"
    t.index ["user_id", "status"], name: "index_readings_on_user_id_and_status"
    t.index ["user_id"], name: "index_readings_on_user_id"
  end

  create_table "spreads", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.integer "num_cards", null: false
    t.bigint "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["num_cards"], name: "index_spreads_on_num_cards"
    t.index ["user_id", "name"], name: "index_spreads_on_user_id_and_name"
    t.index ["user_id"], name: "index_spreads_on_user_id"
  end

  create_table "subscriptions", force: :cascade do |t|
    t.bigint "user_id"
    t.string "plan_name", null: false
    t.string "status", default: "pending"
    t.datetime "current_period_start"
    t.datetime "current_period_end"
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["current_period_start", "current_period_end"], name: "idx_on_current_period_start_current_period_end_ef96a9f506"
    t.index ["status"], name: "index_subscriptions_on_status"
    t.index ["user_id", "plan_name", "status"], name: "index_subscriptions_on_user_id_and_plan_name_and_status"
    t.index ["user_id", "status"], name: "index_subscriptions_on_user_id_and_status"
    t.index ["user_id"], name: "index_subscriptions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email"
    t.string "password_digest"
    t.string "external_id"
    t.bigint "identity_provider_id"
    t.bigint "created_by_user_id"
    t.string "refresh_token"
    t.datetime "token_expiry"
    t.integer "readings_count", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_user_id"], name: "index_users_on_created_by_user_id"
    t.index ["email", "identity_provider_id"], name: "index_users_on_email_and_identity_provider_id", where: "(email IS NOT NULL)"
    t.index ["email"], name: "index_users_on_email", unique: true, where: "(email IS NOT NULL)"
    t.index ["external_id", "identity_provider_id"], name: "index_users_on_external_id_and_identity_provider_id", unique: true
    t.index ["identity_provider_id"], name: "index_users_on_identity_provider_id"
    t.index ["refresh_token"], name: "index_users_on_refresh_token", where: "(refresh_token IS NOT NULL)"
    t.index ["token_expiry"], name: "index_users_on_token_expiry"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "card_interpretations", "cards"
  add_foreign_key "card_readings", "cards"
  add_foreign_key "card_readings", "readings"
  add_foreign_key "reading_quotas", "users"
  add_foreign_key "readings", "spreads"
  add_foreign_key "readings", "users"
  add_foreign_key "spreads", "users"
  add_foreign_key "subscriptions", "users"
  add_foreign_key "users", "identity_providers"
  add_foreign_key "users", "users", column: "created_by_user_id"
end
