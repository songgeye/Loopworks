class RemovePickedUpFromInbounds < ActiveRecord::Migration[7.2]
  def change
    remove_column :inbounds, :picked_up, :boolean, null: false
  end
end
