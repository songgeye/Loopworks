class DropProductionRecords < ActiveRecord::Migration[7.2]
  def change
    drop_table :production_records
  end
end
