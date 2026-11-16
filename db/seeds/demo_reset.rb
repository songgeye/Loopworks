# frozen_string_literal: true

abort "本番環境では実行できません" if Rails.env.production?
abort "CONFIRM_RESET=yes を付けて実行してください" unless ENV["CONFIRM_RESET"] == "yes"

ActiveRecord::Base.transaction do
  ActiveRecord::Base.connection.execute(<<~SQL)
    TRUNCATE TABLE material_movements, adjustment_materials, inbounds_materials, inbounds,
      outbounds_materials, outbounds, current_materials, materials, counterparties
    RESTART IDENTITY
  SQL

  removed = Staff.where.not(username: "admin").delete_all
  puts "リセット完了(スタッフ #{removed} 人を削除。admin は残しています)"
end