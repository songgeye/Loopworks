class CreateOutboundsMaterials < ActiveRecord::Migration[7.2]
  def change
    create_table :outbounds_materials do |t|
      t.references :material, null: false, foreign_key: true
      t.references :outbound, null: false, foreign_key: true
      t.decimal :quantity_kg, null: false, precision: 10, scale: 2
      t.decimal :declared_kg, precision: 10, scale: 2
      t.datetime :deleted_at

      t.timestamps
    end
    add_index :outbounds_materials, :deleted_at
  end
end
