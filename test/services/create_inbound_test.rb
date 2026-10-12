# frozen_string_literal: true
require "test_helper"
class CreateInboundTest< ActiveSupport::TestCase
  setup do
    @staff = Staff.create!(username: "test_admin", name: "テスト管理者", role: "admin", password: "password123")
    @counterparty = Counterparty.create!(party_type: :corporate, name: "テスト取引先")
    @iron = Material.create!(name: "テスト鉄", display_order: 1)
    @copper = Material.create!(name: "テスト銅", display_order: 2)
  end

  test "明細の数だけ台帳が増え、品目ごとに在庫が増える" do
    assert_difference "MaterialMovement.count", 2 do
      CreateInbound.call(
        counterparty: @counterparty,
        staff: @staff,
        recorded_at: Time.zone.now,
        inbounds_materials_attributes: [
          { material_id: @iron.id, quantity_kg: 10 },
          { material_id: @copper.id, quantity_kg: 5 }
        ]
      )
    end

    assert_equal 10, CurrentMaterial.find_by(material: @iron).quantity_kg
    assert_equal 5, CurrentMaterial.find_by(material: @copper).quantity_kg
  end

  test "空の明細行は無視される" do
    inbound = CreateInbound.call(
      counterparty: @counterparty,
      staff: @staff,
      recorded_at: Time.zone.now,
      inbounds_materials_attributes: [
        { material_id: @iron.id, quantity_kg: 10 },
        { material_id: nil, quantity_kg: nil }
      ]
    )

    assert_equal 1, inbound.inbounds_materials.count
  end

  test "途中で失敗したら、入荷も台帳も残らない" do
    assert_no_difference ["Inbound.count", "MaterialMovement.count"] do
      assert_raises(ActiveRecord::RecordInvalid) do
        CreateInbound.call(
          counterparty: @counterparty,
          staff: nil,
          recorded_at: Time.zone.now,
          inbounds_materials_attributes: [{ material_id: @iron.id, quantity_kg: 10 }]
        )
      end
    end
  end
end
