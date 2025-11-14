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

ActiveRecord::Schema[7.2].define(version: 2025_11_12_181027) do
  create_table "benefits", force: :cascade do |t|
    t.string "rule_version_id", null: false
    t.string "category", null: false
    t.string "province", null: false
    t.json "coverage", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category", "province"], name: "index_benefits_on_category_and_province"
    t.index ["rule_version_id"], name: "index_benefits_on_rule_version_id", unique: true
  end

  create_table "chat_messages", force: :cascade do |t|
    t.integer "profile_id", null: false
    t.text "user_message", null: false
    t.text "ai_response"
    t.json "ai_metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["profile_id"], name: "index_chat_messages_on_profile_id"
  end

  create_table "coverage_balances", force: :cascade do |t|
    t.integer "profile_id", null: false
    t.string "category", null: false
    t.decimal "remaining_amount", precision: 10, scale: 2
    t.date "reset_date"
    t.string "rule_version_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["profile_id", "category"], name: "index_coverage_balances_on_profile_id_and_category"
    t.index ["profile_id"], name: "index_coverage_balances_on_profile_id"
    t.index ["rule_version_id"], name: "index_coverage_balances_on_rule_version_id"
  end

  create_table "profiles", force: :cascade do |t|
    t.string "postal_code", null: false
    t.string "province", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["postal_code"], name: "index_profiles_on_postal_code"
  end

  create_table "support_tickets", force: :cascade do |t|
    t.integer "profile_id", null: false
    t.integer "chat_message_id"
    t.string "status", default: "pending", null: false
    t.string "priority", default: "normal", null: false
    t.text "user_question", null: false
    t.text "initial_context"
    t.datetime "resolved_at"
    t.text "resolution_notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["chat_message_id"], name: "index_support_tickets_on_chat_message_id"
    t.index ["profile_id"], name: "index_support_tickets_on_profile_id"
    t.index ["status"], name: "index_support_tickets_on_status"
  end

  add_foreign_key "chat_messages", "profiles"
  add_foreign_key "coverage_balances", "profiles"
  add_foreign_key "support_tickets", "chat_messages"
  add_foreign_key "support_tickets", "profiles"
end
