class CreateOutbounds < ActiveRecord::Migration[7.2]
  def change
    create_table :outbounds do |t|
      t.references :staff, null: false, foreign_key: true
      t.references :counterparty, null: false, foreign_key: true
      t.string :counterparty_pic_name
      t.datetime :recorded_at, null: false
      t.string :slip_no
      t.string :billing_no
      t.datetime :deleted_at

      t.timestamps
    end
    add_index :outbounds, :billing_no, unique: true
    add_index :outbounds, :deleted_at
  end
end
