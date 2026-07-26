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

ActiveRecord::Schema[8.1].define(version: 2026_07_26_232452) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_admin_comments", force: :cascade do |t|
    t.bigint "author_id"
    t.string "author_type"
    t.text "body"
    t.datetime "created_at", null: false
    t.string "namespace"
    t.bigint "resource_id"
    t.string "resource_type"
    t.datetime "updated_at", null: false
    t.index ["author_type", "author_id"], name: "index_active_admin_comments_on_author"
    t.index ["namespace"], name: "index_active_admin_comments_on_namespace"
    t.index ["resource_type", "resource_id"], name: "index_active_admin_comments_on_resource"
  end

  create_table "module_user_accesses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "registered_module_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["registered_module_id", "user_id"], name: "index_module_access_on_module_and_user", unique: true
    t.index ["registered_module_id"], name: "index_module_user_accesses_on_registered_module_id"
    t.index ["user_id"], name: "index_module_user_accesses_on_user_id"
  end

  create_table "registered_modules", force: :cascade do |t|
    t.string "access_policy_mode", default: "manual", null: false
    t.string "adapter_protocol_version", null: false
    t.string "adapter_secret_digest", null: false
    t.string "adapter_url", null: false
    t.string "admin_state", default: "registered", null: false
    t.datetime "created_at", null: false
    t.datetime "last_manifest_refreshed_at"
    t.datetime "last_status_refreshed_at"
    t.text "maintenance_reason"
    t.jsonb "manifest_snapshot", default: {}, null: false
    t.string "module_key", null: false
    t.string "name", null: false
    t.string "runtime_status", default: "unknown", null: false
    t.jsonb "status_snapshot", default: {}, null: false
    t.datetime "updated_at", null: false
    t.string "version", null: false
    t.index ["access_policy_mode"], name: "index_registered_modules_on_access_policy_mode"
    t.index ["admin_state"], name: "index_registered_modules_on_admin_state"
    t.index ["module_key"], name: "index_registered_modules_on_module_key", unique: true
    t.index ["runtime_status"], name: "index_registered_modules_on_runtime_status"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "display_name", default: "", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.string "role", default: "user", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_users_on_active"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["role"], name: "index_users_on_role"
  end

  add_foreign_key "module_user_accesses", "registered_modules"
  add_foreign_key "module_user_accesses", "users"
end
