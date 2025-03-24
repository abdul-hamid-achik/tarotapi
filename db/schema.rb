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

ActiveRecord::Schema[8.0].define(version: 2024_03_24_001000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "btree_gist"
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"

  create_table "action_text_rich_texts", force: :cascade do |t|
    t.string "name", null: false
    t.text "body"
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
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
    t.string "arcana", null: false
    t.string "suit"
    t.string "rank"
    t.text "description"
    t.string "keywords", default: [], array: true
    t.string "symbols", default: [], array: true
    t.string "image_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "to_tsvector('english'::regconfig, description)", name: "index_cards_on_description_gist", using: :gist
    t.index ["arcana"], name: "index_cards_on_arcana"
    t.index ["keywords"], name: "index_cards_on_keywords", using: :gin
    t.index ["name"], name: "index_cards_on_name", unique: true
    t.index ["suit", "rank"], name: "index_cards_on_suit_and_rank"
    t.index ["suit"], name: "index_cards_on_suit"
    t.index ["symbols"], name: "index_cards_on_symbols", using: :gin
  end

  create_table "friendly_id_slugs", force: :cascade do |t|
    t.string "slug", null: false
    t.integer "sluggable_id", null: false
    t.string "sluggable_type", limit: 50
    t.string "scope"
    t.datetime "created_at"
    t.index ["slug", "sluggable_type", "scope"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type_and_scope", unique: true
    t.index ["slug", "sluggable_type"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type"
    t.index ["sluggable_type", "sluggable_id"], name: "index_friendly_id_slugs_on_sluggable_type_and_sluggable_id"
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
    t.index ["user_id", "spread_id", "created_at"], name: "index_readings_on_user_id_spread_id_created_at"
    t.index ["user_id", "status"], name: "index_readings_on_user_id_and_status"
    t.index ["user_id"], name: "index_readings_on_user_id"
  end

  create_table "spreads", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.integer "num_cards", null: false
    t.bigint "user_id"
    t.jsonb "positions", default: {}
    t.boolean "is_public", default: false
    t.boolean "is_system", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["is_public"], name: "index_spreads_on_is_public"
    t.index ["is_system"], name: "index_spreads_on_is_system"
    t.index ["name"], name: "index_spreads_on_name"
    t.index ["positions"], name: "index_spreads_on_positions", opclass: :jsonb_path_ops, using: :gin
    t.index ["user_id"], name: "index_spreads_on_user_id"
  end

  create_table "subscription_plans", force: :cascade do |t|
    t.string "name", null: false
    t.integer "price_cents", default: 0
    t.integer "reading_limit"
    t.string "interval", default: "month"
    t.decimal "price", precision: 10, scale: 2, default: "0.0"
    t.integer "monthly_readings", default: 0
    t.integer "duration_days", default: 30
    t.boolean "is_active", default: true
    t.string "features", default: [], array: true
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["is_active"], name: "index_subscription_plans_on_is_active"
    t.index ["name"], name: "index_subscription_plans_on_name", unique: true
  end

  create_table "subscriptions", force: :cascade do |t|
    t.bigint "user_id"
    t.bigint "subscription_plan_id"
    t.string "plan_name", null: false
    t.string "status", default: "pending"
    t.datetime "current_period_start"
    t.datetime "current_period_end"
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["current_period_start", "current_period_end"], name: "idx_on_current_period_start_current_period_end_ef96a9f506"
    t.index ["status"], name: "index_subscriptions_on_status"
    t.index ["subscription_plan_id"], name: "index_subscriptions_on_subscription_plan_id"
    t.index ["user_id", "plan_name", "status"], name: "index_subscriptions_on_user_id_and_plan_name_and_status"
    t.index ["user_id", "status"], name: "index_subscriptions_on_user_id_and_status"
    t.index ["user_id"], name: "index_subscriptions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "name"
    t.string "email"
    t.string "password_digest"
    t.string "external_id"
    t.bigint "identity_provider_id"
    t.bigint "created_by_user_id"
    t.string "refresh_token"
    t.datetime "token_expiry"
    t.integer "readings_count", default: 0
    t.boolean "admin", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_user_id"], name: "index_users_on_created_by_user_id"
    t.index ["email"], name: "index_users_on_email", unique: true, where: "(email IS NOT NULL)"
    t.index ["external_id", "identity_provider_id"], name: "index_users_on_external_id_and_identity_provider_id", unique: true
    t.index ["identity_provider_id"], name: "index_users_on_identity_provider_id"
    t.index ["name"], name: "index_users_on_name"
  end

  create_table "versions", force: :cascade do |t|
    t.string "item_type", null: false
    t.bigint "item_id", null: false
    t.string "event", null: false
    t.string "whodunnit"
    t.text "object"
    t.text "object_changes"
    t.datetime "created_at"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
  end

  add_foreign_key "card_interpretations", "cards"
  add_foreign_key "card_readings", "cards"
  add_foreign_key "card_readings", "readings"
  add_foreign_key "reading_quotas", "users"
  add_foreign_key "readings", "spreads"
  add_foreign_key "readings", "users"
  add_foreign_key "spreads", "users"
  add_foreign_key "subscriptions", "subscription_plans"
  add_foreign_key "subscriptions", "users"
  add_foreign_key "users", "identity_providers"
  add_foreign_key "users", "users", column: "created_by_user_id"
end
