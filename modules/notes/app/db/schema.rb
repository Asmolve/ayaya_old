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

ActiveRecord::Schema[8.1].define(version: 2026_08_01_000001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "local_users", force: :cascade do |t|
    t.string "core_user_id", null: false
    t.datetime "created_at", null: false
    t.string "display_name"
    t.string "email"
    t.string "global_role"
    t.datetime "last_seen_at"
    t.datetime "updated_at", null: false
    t.index [ "core_user_id" ], name: "index_local_users_on_core_user_id", unique: true
  end

  create_table "notes", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.bigint "local_user_id", null: false
    t.index [ "local_user_id" ], name: "index_notes_on_local_user_id"
  end

  add_foreign_key "notes", "local_users"
end
