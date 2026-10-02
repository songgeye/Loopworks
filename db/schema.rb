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

ActiveRecord::Schema[7.2].define(version: 2026_09_28_155402) do
  create_table "adjustment_materials", force: :cascade do |t|
    t.integer "material_id", null: false
    t.decimal "quantity_kg", precision: 10, scale: 2, null: false
    t.datetime "recorded_at", null: false
    t.text "note", null: false
    t.integer "staff_id", null: false
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_adjustment_materials_on_deleted_at"
    t.index ["material_id"], name: "index_adjustment_materials_on_material_id"
    t.index ["recorded_at"], name: "index_adjustment_materials_on_recorded_at"
    t.index ["staff_id"], name: "index_adjustment_materials_on_staff_id"
  end

  create_table "counterparties", force: :cascade do |t|
    t.integer "party_type", null: false
    t.string "name", null: false
    t.text "address"
    t.date "date_of_birth"
    t.integer "id_type"
    t.datetime "id_confirmed_at"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_counterparties_on_deleted_at"
  end

  create_table "inbounds", force: :cascade do |t|
    t.integer "staff_id", null: false
    t.integer "counterparty_id", null: false
    t.string "counterparty_pic_name"
    t.datetime "recorded_at", null: false
    t.string "slip_no"
    t.string "billing_no"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["billing_no"], name: "index_inbounds_on_billing_no", unique: true
    t.index ["counterparty_id"], name: "index_inbounds_on_counterparty_id"
    t.index ["deleted_at"], name: "index_inbounds_on_deleted_at"
    t.index ["staff_id"], name: "index_inbounds_on_staff_id"
  end

  create_table "inbounds_materials", force: :cascade do |t|
    t.integer "material_id", null: false
    t.integer "inbound_id", null: false
    t.decimal "quantity_kg", precision: 10, scale: 2, null: false
    t.decimal "declared_kg", precision: 10, scale: 2
    t.boolean "flagged_as_anomaly", default: false, null: false
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_inbounds_materials_on_deleted_at"
    t.index ["inbound_id"], name: "index_inbounds_materials_on_inbound_id"
    t.index ["material_id"], name: "index_inbounds_materials_on_material_id"
  end

  create_table "material_movements", force: :cascade do |t|
    t.integer "material_id", null: false
    t.decimal "quantity_kg", precision: 10, scale: 2, null: false
    t.datetime "recorded_at", null: false
    t.string "source_type", null: false
    t.integer "source_id", null: false
    t.text "note"
    t.integer "staff_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["material_id"], name: "index_material_movements_on_material_id"
    t.index ["recorded_at"], name: "index_material_movements_on_recorded_at"
    t.index ["source_type", "source_id"], name: "index_material_movements_on_source"
    t.index ["staff_id"], name: "index_material_movements_on_staff_id"
  end

  create_table "materials", force: :cascade do |t|
    t.string "name", null: false
    t.integer "display_order", null: false
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "stock_target", default: true, null: false
    t.index ["deleted_at"], name: "index_materials_on_deleted_at"
  end

  create_table "outbounds", force: :cascade do |t|
    t.integer "staff_id", null: false
    t.integer "counterparty_id", null: false
    t.string "counterparty_pic_name"
    t.datetime "recorded_at", null: false
    t.string "slip_no"
    t.string "billing_no"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["billing_no"], name: "index_outbounds_on_billing_no", unique: true
    t.index ["counterparty_id"], name: "index_outbounds_on_counterparty_id"
    t.index ["deleted_at"], name: "index_outbounds_on_deleted_at"
    t.index ["staff_id"], name: "index_outbounds_on_staff_id"
  end

  create_table "outbounds_materials", force: :cascade do |t|
    t.integer "material_id", null: false
    t.integer "outbound_id", null: false
    t.decimal "quantity_kg", precision: 10, scale: 2, null: false
    t.decimal "declared_kg", precision: 10, scale: 2
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_outbounds_materials_on_deleted_at"
    t.index ["material_id"], name: "index_outbounds_materials_on_material_id"
    t.index ["outbound_id"], name: "index_outbounds_materials_on_outbound_id"
  end

  create_table "staffs", force: :cascade do |t|
    t.string "username", null: false
    t.string "name", null: false
    t.string "role", null: false
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "remember_created_at"
    t.index ["deleted_at"], name: "index_staffs_on_deleted_at"
    t.index ["username"], name: "index_staffs_on_username", unique: true
  end

  add_foreign_key "adjustment_materials", "materials"
  add_foreign_key "adjustment_materials", "staffs"
  add_foreign_key "inbounds", "counterparties"
  add_foreign_key "inbounds", "staffs"
  add_foreign_key "inbounds_materials", "inbounds"
  add_foreign_key "inbounds_materials", "materials"
  add_foreign_key "material_movements", "materials"
  add_foreign_key "material_movements", "staffs"
  add_foreign_key "outbounds", "counterparties"
  add_foreign_key "outbounds", "staffs"
  add_foreign_key "outbounds_materials", "materials"
  add_foreign_key "outbounds_materials", "outbounds"
end
