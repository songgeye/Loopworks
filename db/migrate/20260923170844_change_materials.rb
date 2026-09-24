class ChangeMaterials < ActiveRecord::Migration[7.2]
  def change
    add_column :materials, :stock_target, :boolean, null: false, default: true
  end
end
