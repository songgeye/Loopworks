class CreateInventoryMovements < ActiveRecord::Migration[7.2]
  def change
    create_table :inventory_movements do |t|
      t.references :material, null: false, foreign_key: true
      t.decimal :quantity_kg, precision: 10, scale: 2
      t.datetime :recorded_at, null: false
      t.references :source, polymorphic: true
      t.integer :movement_type, null: false
      t.text :note
      t.references :staff, null: false, foreign_key: true

      t.timestamps
    end
    add_index :inventory_movements, :recorded_at
  end
end
