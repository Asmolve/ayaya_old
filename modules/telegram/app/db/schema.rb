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

ActiveRecord::Schema[8.1].define(version: 2026_08_21_050000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "account_leases", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "holder", null: false
    t.bigint "telegram_account_id", null: false
    t.datetime "updated_at", null: false
    t.index ["telegram_account_id"], name: "index_account_leases_on_telegram_account_id"
    t.index ["telegram_account_id"], name: "index_account_leases_one_per_account", unique: true
  end

  create_table "assignments", force: :cascade do |t|
    t.decimal "confidence", precision: 5, scale: 4
    t.datetime "created_at", null: false
    t.jsonb "explanation", default: {}, null: false
    t.bigint "folder_id"
    t.boolean "locked", default: false, null: false
    t.string "peer_id", null: false
    t.string "peer_kind", null: false
    t.string "source", null: false
    t.bigint "telegram_account_id", null: false
    t.datetime "updated_at", null: false
    t.index ["folder_id"], name: "index_assignments_on_folder_id"
    t.index ["telegram_account_id", "peer_kind", "peer_id"], name: "idx_on_telegram_account_id_peer_kind_peer_id_6651115d89", unique: true
    t.index ["telegram_account_id"], name: "index_assignments_on_telegram_account_id"
  end

  create_table "dialogs", force: :cascade do |t|
    t.string "access_hash"
    t.string "avatar_url"
    t.datetime "created_at", null: false
    t.jsonb "input_peer_ref", default: {}, null: false
    t.datetime "last_seen_at"
    t.string "metadata_hash", null: false
    t.string "peer_id", null: false
    t.string "peer_kind", null: false
    t.datetime "stale_at"
    t.bigint "telegram_account_id", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.string "username"
    t.index ["telegram_account_id", "peer_kind", "peer_id"], name: "index_dialogs_on_telegram_account_id_and_peer_kind_and_peer_id", unique: true
    t.index ["telegram_account_id"], name: "index_dialogs_on_telegram_account_id"
  end

  create_table "folder_proposals", force: :cascade do |t|
    t.datetime "accepted_at"
    t.string "category", null: false
    t.datetime "created_at", null: false
    t.jsonb "explanation", default: {}, null: false
    t.string "proposal_id", null: false
    t.string "status", default: "proposed", null: false
    t.bigint "telegram_account_id", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["telegram_account_id", "category"], name: "index_folder_proposals_on_telegram_account_id_and_category", unique: true
    t.index ["telegram_account_id", "proposal_id"], name: "index_folder_proposals_on_telegram_account_id_and_proposal_id", unique: true
    t.index ["telegram_account_id"], name: "index_folder_proposals_on_telegram_account_id"
  end

  create_table "folders", force: :cascade do |t|
    t.string "app_folder_id"
    t.datetime "created_at", null: false
    t.string "emoji"
    t.integer "local_revision", default: 0, null: false
    t.boolean "managed_by_app", default: false, null: false
    t.string "mode", default: "showcase", null: false
    t.jsonb "ownership_record", default: {}, null: false
    t.string "ownership_state", default: "foreign", null: false
    t.string "remote_fingerprint"
    t.jsonb "remote_state", default: {}, null: false
    t.bigint "telegram_account_id", null: false
    t.integer "telegram_folder_id", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["id", "telegram_account_id"], name: "index_folders_on_id_and_account", unique: true
    t.index ["telegram_account_id", "ownership_state"], name: "index_folders_on_telegram_account_id_and_ownership_state"
    t.index ["telegram_account_id", "telegram_folder_id"], name: "index_folders_on_telegram_account_id_and_telegram_folder_id", unique: true
    t.index ["telegram_account_id"], name: "index_folders_on_telegram_account_id"
  end

  create_table "module_users", force: :cascade do |t|
    t.string "core_user_id", null: false
    t.datetime "created_at", null: false
    t.string "display_name"
    t.string "email"
    t.string "global_role"
    t.datetime "last_seen_at"
    t.datetime "updated_at", null: false
    t.index ["core_user_id"], name: "index_module_users_on_core_user_id", unique: true
  end

  create_table "operation_steps", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "error_json", default: {}, null: false
    t.jsonb "expected_postcondition", default: {}, null: false
    t.bigint "operation_id", null: false
    t.string "precondition_fingerprint", null: false
    t.string "request_fingerprint", null: false
    t.jsonb "request_payload", default: {}, null: false
    t.string "result_fingerprint"
    t.string "rpc", default: "update_dialog_filter", null: false
    t.integer "sequence", default: 0, null: false
    t.string "status", default: "planned", null: false
    t.string "step_id", null: false
    t.bigint "telegram_account_id", null: false
    t.datetime "updated_at", null: false
    t.index ["operation_id", "sequence"], name: "index_operation_steps_on_operation_and_sequence", unique: true
    t.index ["operation_id"], name: "index_operation_steps_on_operation_id"
    t.index ["telegram_account_id", "operation_id", "step_id"], name: "index_operation_steps_on_account_operation_step", unique: true
    t.index ["telegram_account_id"], name: "index_operation_steps_on_telegram_account_id"
  end

  create_table "operations", force: :cascade do |t|
    t.integer "attempt_count", default: 0, null: false
    t.bigint "before_snapshot_id"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "execution_requested_at"
    t.datetime "next_attempt_at"
    t.string "operation_id", null: false
    t.jsonb "plan", default: {}, null: false
    t.string "plan_fingerprint"
    t.datetime "retention_until"
    t.string "status", null: false
    t.bigint "telegram_account_id", null: false
    t.datetime "updated_at", null: false
    t.datetime "worker_locked_until"
    t.index ["before_snapshot_id"], name: "index_operations_on_before_snapshot_id"
    t.index ["id", "telegram_account_id"], name: "index_operations_on_id_and_account", unique: true
    t.index ["retention_until"], name: "index_operations_on_retention_until"
    t.index ["status", "execution_requested_at", "next_attempt_at"], name: "index_operations_for_durable_worker"
    t.index ["telegram_account_id", "operation_id"], name: "index_operations_on_telegram_account_id_and_operation_id", unique: true
    t.index ["telegram_account_id"], name: "index_operations_on_telegram_account_id"
  end

  create_table "rules", force: :cascade do |t|
    t.jsonb "condition_json", default: {}, null: false
    t.datetime "created_at", null: false
    t.boolean "enabled", default: true, null: false
    t.string "explanation"
    t.integer "priority", null: false
    t.string "rule_id", null: false
    t.bigint "target_folder_id"
    t.bigint "telegram_account_id", null: false
    t.datetime "updated_at", null: false
    t.integer "version", default: 1, null: false
    t.index ["target_folder_id"], name: "index_rules_on_target_folder_id"
    t.index ["telegram_account_id", "rule_id", "version"], name: "index_rules_on_telegram_account_id_and_rule_id_and_version", unique: true
    t.index ["telegram_account_id"], name: "index_rules_on_telegram_account_id"
  end

  create_table "snapshots", force: :cascade do |t|
    t.integer "canonical_version", null: false
    t.datetime "created_at", null: false
    t.string "kind", null: false
    t.jsonb "payload", default: {}, null: false
    t.datetime "retention_until"
    t.string "snapshot_id", null: false
    t.string "source_hash", null: false
    t.bigint "telegram_account_id", null: false
    t.datetime "updated_at", null: false
    t.index ["id", "telegram_account_id"], name: "index_snapshots_on_id_and_account", unique: true
    t.index ["telegram_account_id", "snapshot_id"], name: "index_snapshots_on_telegram_account_id_and_snapshot_id", unique: true
    t.index ["telegram_account_id"], name: "index_snapshots_on_telegram_account_id"
  end

  create_table "telegram_accounts", force: :cascade do |t|
    t.jsonb "auth_challenge", default: {}, null: false
    t.string "connection_state", default: "disconnected", null: false
    t.datetime "created_at", null: false
    t.datetime "disconnected_at"
    t.string "display_name"
    t.jsonb "encrypted_api_credentials"
    t.jsonb "encrypted_session"
    t.datetime "last_seen_at"
    t.datetime "limits_updated_at"
    t.bigint "module_user_id", null: false
    t.jsonb "persisted_limits", default: {}, null: false
    t.datetime "rate_limited_until"
    t.boolean "read_only", default: true, null: false
    t.string "telegram_account_id", null: false
    t.datetime "updated_at", null: false
    t.index ["module_user_id", "telegram_account_id"], name: "idx_on_module_user_id_telegram_account_id_df563667e8", unique: true
    t.index ["module_user_id"], name: "index_telegram_accounts_on_module_user_id"
    t.index ["module_user_id"], name: "index_telegram_accounts_one_per_module_user", unique: true
    t.index ["rate_limited_until"], name: "index_telegram_accounts_on_rate_limited_until"
  end

  add_foreign_key "account_leases", "telegram_accounts"
  add_foreign_key "assignments", "folders", column: ["folder_id", "telegram_account_id"], primary_key: ["id", "telegram_account_id"]
  add_foreign_key "assignments", "telegram_accounts"
  add_foreign_key "dialogs", "telegram_accounts"
  add_foreign_key "folder_proposals", "telegram_accounts"
  add_foreign_key "folders", "telegram_accounts"
  add_foreign_key "operation_steps", "operations", column: ["operation_id", "telegram_account_id"], primary_key: ["id", "telegram_account_id"]
  add_foreign_key "operation_steps", "telegram_accounts"
  add_foreign_key "operations", "snapshots", column: ["before_snapshot_id", "telegram_account_id"], primary_key: ["id", "telegram_account_id"]
  add_foreign_key "operations", "telegram_accounts"
  add_foreign_key "rules", "folders", column: ["target_folder_id", "telegram_account_id"], primary_key: ["id", "telegram_account_id"]
  add_foreign_key "rules", "telegram_accounts"
  add_foreign_key "snapshots", "telegram_accounts"
  add_foreign_key "telegram_accounts", "module_users"
end
