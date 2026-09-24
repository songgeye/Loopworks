class CreateCounterparties < ActiveRecord::Migration[7.2]
  def change
    create_table :counterparties do |t|
      t.integer :party_type, null: false
      t.string :name, null: false
      t.text :address
      t.date :date_of_birth
      t.integer :id_type
      t.datetime :id_confirmed_at
      t.datetime :deleted_at

      t.timestamps
    end
    add_index :counterparties, :deleted_at
  end
end
