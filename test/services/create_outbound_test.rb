# frozen_string_literal: true
require "test_helper"
class CreateOutboundTest < ActiveSupport::TestCase
  setup do
    @staff = Staff.create!(username: "test_admin", name: "テスト管理者", role: "admin", password: "password123")
    @counterparty = Counterparty.create!(party_type: :corporate, name: "テスト取引先")
    @iron = Material.create!(name: "テスト鉄", display_order: 1)
    @copper = Material.create!(name: "テスト銅", display_order: 2)
    CurrentMaterial.create!(material: @iron, quantity_kg: 10)
    CurrentMaterial.create!(material: @copper, quantity_kg: 10)
  end

  test "明細の数だけ台帳が増え、品目ごとに在庫が減る" do
    assert_difference "MaterialMovement.count", 2 do
      CreateOutbound.call(
        counterparty: @counterparty,
        staff: @staff,
        outbounds_materials_attributes: [
          { material_id: @iron.id, quantity_kg: 3 },
          { material_id: @copper.id, quantity_kg: 2 }
        ]
      )
    end

    assert_equal 7, CurrentMaterial.find_by(material: @iron).quantity_kg
    assert_equal 8, CurrentMaterial.find_by(material: @copper).quantity_kg
  end

  test "空の明細行は無視される" do
    outbound = CreateOutbound.call(
      counterparty: @counterparty,
      staff: @staff,
      outbounds_materials_attributes: [
        { material_id: @iron.id, quantity_kg: 3 },
        { material_id: nil, quantity_kg: nil }
      ]
    )

    assert_equal 1, outbound.outbounds_materials.count
  end

  test "途中で失敗したら、出荷も台帳も残らず、在庫も変わらない" do
    assert_no_difference ["Outbound.count", "MaterialMovement.count"] do
      assert_raises(ActiveRecord::RecordInvalid) do
        CreateOutbound.call(
          counterparty: @counterparty,
          staff: nil,
          outbounds_materials_attributes: [{ material_id: @iron.id, quantity_kg: 3 }]
        )
      end
    end

    assert_equal 10, CurrentMaterial.find_by(material: @iron).quantity_kg
  end
end
