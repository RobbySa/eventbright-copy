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

ActiveRecord::Schema[7.1].define(version: 2026_04_07_113032) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "events", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "starts_at", null: false
    t.datetime "ends_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["starts_at"], name: "index_events_on_starts_at"
    t.check_constraint "ends_at > starts_at", name: "events_ends_after_starts"
  end

  create_table "order_items", force: :cascade do |t|
    t.bigint "order_id", null: false
    t.bigint "ticket_type_id", null: false
    t.integer "quantity", null: false
    t.integer "unit_price_cents_snapshot", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id", "ticket_type_id"], name: "index_order_items_on_order_id_and_ticket_type_id", unique: true
    t.index ["order_id"], name: "index_order_items_on_order_id"
    t.index ["ticket_type_id"], name: "index_order_items_on_ticket_type_id"
    t.check_constraint "quantity > 0", name: "order_items_quantity_positive"
    t.check_constraint "unit_price_cents_snapshot >= 0", name: "order_items_unit_price_non_negative"
  end

  create_table "orders", force: :cascade do |t|
    t.string "status", default: "pending", null: false
    t.integer "total_cents", default: 0, null: false
    t.string "currency", default: "USD", null: false
    t.datetime "placed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "email", null: false
    t.index ["status"], name: "index_orders_on_status"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying, 'confirmed'::character varying, 'cancelled'::character varying]::text[])", name: "orders_valid_status"
    t.check_constraint "total_cents >= 0", name: "orders_total_non_negative"
  end

  create_table "ticket_types", force: :cascade do |t|
    t.bigint "event_id", null: false
    t.string "name", null: false
    t.integer "price_cents", null: false
    t.string "currency", default: "USD", null: false
    t.integer "total_quantity", null: false
    t.integer "sold_quantity", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id", "name"], name: "index_ticket_types_on_event_id_and_name", unique: true
    t.index ["event_id"], name: "index_ticket_types_on_event_id"
    t.check_constraint "price_cents >= 0", name: "ticket_types_price_non_negative"
    t.check_constraint "sold_quantity <= total_quantity", name: "ticket_types_sold_lte_total"
    t.check_constraint "sold_quantity >= 0", name: "ticket_types_sold_qty_non_negative"
    t.check_constraint "total_quantity >= 0", name: "ticket_types_total_qty_non_negative"
  end

  add_foreign_key "order_items", "orders"
  add_foreign_key "order_items", "ticket_types"
  add_foreign_key "ticket_types", "events"
end
