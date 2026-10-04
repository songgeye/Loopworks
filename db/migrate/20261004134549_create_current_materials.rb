class CreateCurrentMaterials < ActiveRecord::Migration[7.2]
  def change
    create_table :current_materials do |t|
      t.references :material, null: false, foreign_key: true, index: { unique: true }
      t.decimal :quantity_kg, precision: 10, scale: 2, null: false, default: 0

      t.timestamps
    end
  end
end
