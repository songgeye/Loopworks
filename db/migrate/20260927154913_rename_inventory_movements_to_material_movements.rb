class RenameInventoryMovementsToMaterialMovements < ActiveRecord::Migration[7.2]
  def change
    rename_table :inventory_movements, :material_movements
  end
end
