class CreateInboundsMaterials < ActiveRecord::Migration[7.2]
  def change
    create_table :inbounds_materials do |t|
      t.references :material, null: false, foreign_key: true
      t.references :inbound, null: false, foreign_key: true
      t.decimal :quantity_kg, null: false, precision: 10, scale: 2
      t.decimal :declared_kg, precision: 10, scale: 2
      t.boolean :flagged_as_anomaly, null: false
      t.datetime :deleted_at

      t.timestamps
    end
    add_index :inbounds_materials, :deleted_at
  end
end
