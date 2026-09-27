class RenameAdjustMaterialsToAdjustmentMaterials < ActiveRecord::Migration[7.2]
  def change
    rename_table :adjust_materials, :adjustment_materials
  end
end
