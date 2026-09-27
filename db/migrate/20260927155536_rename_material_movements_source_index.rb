class RenameMaterialMovementsSourceIndex < ActiveRecord::Migration[7.2]
  def change
    rename_index :material_movements,
       "index_inventory_movements_on_source",
       "index_material_movements_on_source"
  end
end
