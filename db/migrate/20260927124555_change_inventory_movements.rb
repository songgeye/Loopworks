class ChangeInventoryMovements < ActiveRecord::Migration[7.2]
  def change
    remove_column :inventory_movements, :movement_type
    change_column_null :inventory_movements, :source_type, false
    change_column_null :inventory_movements, :source_id, false
    change_column_null :inventory_movements, :quantity_kg, false
  end
end
