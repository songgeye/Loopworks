class AddReversesIdToMaterialMovements < ActiveRecord::Migration[7.2]
  def change
    add_reference :material_movements, :reverses,
                  null: true,
                  foreign_key: { to_table: :material_movements },
                  index: {unique: true}
  end
end
