class CreateAdjustMaterials < ActiveRecord::Migration[7.2]
  def change
    create_table :adjust_materials do |t|
      t.references :material, null: false, foreign_key: true
      t.decimal :quantity_kg, precision: 10, scale: 2, null: false
      t.datetime :recorded_at, null: false
      t.text :note, null: false
      t.references :staff, null: false, foreign_key: true
      t.datetime :deleted_at

      t.timestamps
    end
    add_index :adjust_materials, :recorded_at
    add_index :adjust_materials, :deleted_at
  end
end
