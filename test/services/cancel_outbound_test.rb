# frozen_string_literal: true

require "test_helper"

class CancelOutboundTest < ActiveSupport::TestCase
  setup do
    @admin = create_staff(role: "admin")
    @iron = create_material(name: "テスト鉄", display_order: 1)
    @copper = create_material(name: "テスト銅", display_order: 2)
    CurrentMaterial.create!(material: @iron, quantity_kg: 10)
    CurrentMaterial.create!(material: @copper, quantity_kg: 10)
    @outbound = CreateOutbound.call(
      counterparty: create_counterparty,
      staff: @admin,
      outbounds_materials_attributes: [
        { material_id: @iron.id, quantity_kg: 3 },
        { material_id: @copper.id, quantity_kg: 2 }
      ]
    )
  end

  test "明細の数だけ打ち消しの行が増え、在庫が元に戻る" do
    assert_difference "MaterialMovement.count", 2 do
      CancelOutbound.call(outbound: @outbound, staff: @admin)
    end

    assert_equal 10, CurrentMaterial.find_by(material: @iron).quantity_kg
    assert_equal 10, CurrentMaterial.find_by(material: @copper).quantity_kg
    assert @outbound.cancelled?
  end

  test "打ち消しの行は、プラスの数量になる" do
    CancelOutbound.call(outbound: @outbound, staff: @admin)

    assert_equal [2, 3], MaterialMovement.where.not(reverses_id: nil).map(&:quantity_kg).sort
  end

  test "出荷と明細は削除せず、残す" do
    assert_no_difference ["Outbound.count", "OutboundsMaterial.count"] do
      CancelOutbound.call(outbound: @outbound, staff: @admin)
    end
  end

  test "2回目の取り消しはエラーになり、在庫は二重に戻らない" do
    CancelOutbound.call(outbound: @outbound, staff: @admin)

    assert_no_difference "MaterialMovement.count" do
      error = assert_raises(ArgumentError) do
        CancelOutbound.call(outbound: @outbound.reload, staff: @admin)
      end
      assert_equal "すでに取り消し済みです", error.message
    end
    assert_equal 10, CurrentMaterial.find_by(material: @iron).quantity_kg
  end
end
