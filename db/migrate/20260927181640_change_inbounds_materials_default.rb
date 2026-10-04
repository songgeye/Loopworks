class ChangeInboundsMaterialsDefault < ActiveRecord::Migration[7.2]
  def change
    change_column_default :inbounds_materials, :flagged_as_anomaly, false
  end
end
