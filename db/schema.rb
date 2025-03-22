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

ActiveRecord::Schema[8.0].define(version: 2025_03_22_070826) do
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

  create_table "api_keys", force: :cascade do |t|
    t.string "name"
    t.string "token", null: false
    t.datetime "expires_at"
    t.bigint "user_id", null: false
    t.integer "rate_limit", default: 100
    t.datetime "last_used_at"
    t.string "description"
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["token"], name: "index_api_keys_on_token", unique: true
    t.index ["user_id"], name: "index_api_keys_on_user_id"
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
    t.index ["arcana"], name: "index_cards_on_arcana"
    t.index ["keywords"], name: "index_cards_on_keywords", using: :gin
    t.index ["name"], name: "index_cards_on_name", unique: true
    t.index ["suit", "rank"], name: "index_cards_on_suit_and_rank"
    t.index ["suit"], name: "index_cards_on_suit"
    t.index ["symbols"], name: "index_cards_on_symbols", using: :gin
  end

  create_table "identity_providers", force: :cascade do |t|
    t.string "name", null: false
    t.string "provider_type"
    t.jsonb "settings", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_identity_providers_on_name", unique: true
  end

  create_table "pay_charges", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.bigint "subscription_id"
    t.string "processor_id", null: false
    t.integer "amount", null: false
    t.string "currency"
    t.integer "application_fee_amount"
    t.integer "amount_refunded"
    t.jsonb "metadata"
    t.jsonb "data"
    t.string "stripe_account"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "type"
    t.index ["customer_id", "processor_id"], name: "index_pay_charges_on_customer_id_and_processor_id", unique: true
    t.index ["subscription_id"], name: "index_pay_charges_on_subscription_id"
  end

  create_table "pay_customers", force: :cascade do |t|
    t.string "owner_type"
    t.bigint "owner_id"
    t.string "processor", null: false
    t.string "processor_id"
    t.boolean "default"
    t.jsonb "data"
    t.string "stripe_account"
    t.datetime "deleted_at", precision: nil
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "type"
    t.index ["owner_type", "owner_id", "deleted_at"], name: "pay_customer_owner_index", unique: true
    t.index ["processor", "processor_id"], name: "index_pay_customers_on_processor_and_processor_id", unique: true
  end

  create_table "pay_merchants", force: :cascade do |t|
    t.string "owner_type"
    t.bigint "owner_id"
    t.string "processor", null: false
    t.string "processor_id"
    t.boolean "default"
    t.jsonb "data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "type"
    t.index ["owner_type", "owner_id", "processor"], name: "index_pay_merchants_on_owner_type_and_owner_id_and_processor"
  end

  create_table "pay_payment_methods", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.string "processor_id", null: false
    t.boolean "default"
    t.string "payment_method_type"
    t.jsonb "data"
    t.string "stripe_account"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "type"
    t.index ["customer_id", "processor_id"], name: "index_pay_payment_methods_on_customer_id_and_processor_id", unique: true
  end

  create_table "pay_subscriptions", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.string "name", null: false
    t.string "processor_id", null: false
    t.string "processor_plan", null: false
    t.integer "quantity", default: 1, null: false
    t.string "status", null: false
    t.datetime "current_period_start", precision: nil
    t.datetime "current_period_end", precision: nil
    t.datetime "trial_ends_at", precision: nil
    t.datetime "ends_at", precision: nil
    t.boolean "metered"
    t.string "pause_behavior"
    t.datetime "pause_starts_at", precision: nil
    t.datetime "pause_resumes_at", precision: nil
    t.decimal "application_fee_percent", precision: 8, scale: 2
    t.jsonb "metadata"
    t.jsonb "data"
    t.string "stripe_account"
    t.string "payment_method_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "type"
    t.index ["customer_id", "processor_id"], name: "index_pay_subscriptions_on_customer_id_and_processor_id", unique: true
    t.index ["metered"], name: "index_pay_subscriptions_on_metered"
    t.index ["pause_starts_at"], name: "index_pay_subscriptions_on_pause_starts_at"
  end

  create_table "pay_webhooks", force: :cascade do |t|
    t.string "processor"
    t.string "event_type"
    t.jsonb "event"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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
    t.jsonb "positions", default: {}
    t.boolean "is_public", default: false
    t.boolean "is_system", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["is_public"], name: "index_spreads_on_is_public"
    t.index ["is_system"], name: "index_spreads_on_is_system"
    t.index ["name"], name: "index_spreads_on_name"
    t.index ["positions"], name: "index_spreads_on_positions", using: :gin
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
    t.string "encrypted_password"
    t.string "external_id"
    t.bigint "identity_provider_id"
    t.bigint "created_by_user_id"
    t.string "refresh_token"
    t.datetime "token_expiry"
    t.integer "readings_count", default: 0
    t.boolean "admin", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "provider", default: "email", null: false
    t.string "uid", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.boolean "allow_password_change", default: false
    t.datetime "remember_created_at"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.json "tokens"
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["created_by_user_id"], name: "index_users_on_created_by_user_id"
    t.index ["email"], name: "index_users_on_email", unique: true, where: "(email IS NOT NULL)"
    t.index ["external_id", "identity_provider_id"], name: "index_users_on_external_id_and_identity_provider_id", unique: true
    t.index ["identity_provider_id"], name: "index_users_on_identity_provider_id"
    t.index ["name"], name: "index_users_on_name"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["uid", "provider"], name: "index_users_on_uid_and_provider", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "api_keys", "users"
  add_foreign_key "card_interpretations", "cards"
  add_foreign_key "card_readings", "cards"
  add_foreign_key "card_readings", "readings"
  add_foreign_key "pay_charges", "pay_customers", column: "customer_id"
  add_foreign_key "pay_charges", "pay_subscriptions", column: "subscription_id"
  add_foreign_key "pay_payment_methods", "pay_customers", column: "customer_id"
  add_foreign_key "pay_subscriptions", "pay_customers", column: "customer_id"
  add_foreign_key "reading_quotas", "users"
  add_foreign_key "readings", "spreads"
  add_foreign_key "readings", "users"
  add_foreign_key "spreads", "users"
  add_foreign_key "subscriptions", "subscription_plans"
  add_foreign_key "subscriptions", "users"
  add_foreign_key "users", "identity_providers"
  add_foreign_key "users", "users", column: "created_by_user_id"
end
