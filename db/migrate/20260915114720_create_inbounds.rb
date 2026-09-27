class CreateInbounds < ActiveRecord::Migration[7.2]
  def change
    create_table :inbounds do |t|
      t.references :staff, null: false, foreign_key: true
      t.references :counterparty, null: false, foreign_key: true
      t.string :counterparty_pic_name
      t.datetime :recorded_at, null: false
      t.string :slip_no
      t.string :billing_no
      t.boolean :picked_up, null: false
      t.datetime :deleted_at

      t.timestamps
    end
    add_index :inbounds, :billing_no, unique: true
    add_index :inbounds, :deleted_at
  end
end
