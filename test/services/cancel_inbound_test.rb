# frozen_string_literal: true

require "test_helper"

class CancelInboundTest < ActiveSupport::TestCase
  setup do
    @staff = create_staff(role: "staff")
    @admin = create_staff(role: "admin")
    @iron = create_material(name: "テスト鉄", display_order: 1)
    @copper = create_material(name: "テスト銅", display_order: 2)
    @inbound = CreateInbound.call(
      counterparty: create_counterparty,
      staff: @staff,
      inbounds_materials_attributes: [
        { material_id: @iron.id, quantity_kg: 10 },
        { material_id: @copper.id, quantity_kg: 5 }
      ]
    )
  end

  test "明細の数だけ打ち消しの行が増え、在庫が元に戻る" do
    assert_difference "MaterialMovement.count", 2 do
      CancelInbound.call(inbound: @inbound, staff: @admin)
    end

    assert_equal 0, CurrentMaterial.find_by(material: @iron).quantity_kg
    assert_equal 0, CurrentMaterial.find_by(material: @copper).quantity_kg
    assert @inbound.cancelled?
  end

  test "入荷と明細は削除せず、残す" do
    assert_no_difference ["Inbound.count", "InboundsMaterial.count"] do
      CancelInbound.call(inbound: @inbound, staff: @admin)
    end
  end

  test "打ち消しの行には、取り消したスタッフと時刻が記録される" do
    travel_to Time.zone.local(2026, 11, 6, 10, 0) do
      CancelInbound.call(inbound: @inbound, staff: @admin)
    end

    reversals = MaterialMovement.where.not(reverses_id: nil)
    assert_equal [@admin.id], reversals.map(&:staff_id).uniq
    assert_equal [Time.zone.local(2026, 11, 6, 10, 0)], reversals.map(&:recorded_at).uniq
  end

  test "ほかの入荷の在庫には影響しない" do
    CreateInbound.call(
      counterparty: create_counterparty(name: "別の取引先"),
      staff: @staff,
      inbounds_materials_attributes: [{ material_id: @iron.id, quantity_kg: 7 }]
    )

    CancelInbound.call(inbound: @inbound, staff: @admin)

    assert_equal 7, CurrentMaterial.find_by(material: @iron).quantity_kg
  end

  test "2回目の取り消しはエラーになり、在庫は二重に戻らない" do
    CancelInbound.call(inbound: @inbound, staff: @admin)

    assert_no_difference "MaterialMovement.count" do
      error = assert_raises(ArgumentError) do
        CancelInbound.call(inbound: @inbound.reload, staff: @admin)
      end
      assert_equal "すでに取り消し済みです", error.message
    end
    assert_equal 0, CurrentMaterial.find_by(material: @iron).quantity_kg
  end

  test "一部の明細が取り消し済みなら、全体を取り消さず元に戻す" do
    copper_movement = MaterialMovement.find_by!(source: @inbound.inbounds_materials.find_by!(material: @copper))
    ReverseMaterialMovement.call(movement: copper_movement, staff: @admin, recorded_at: Time.zone.now)

    assert_no_difference "MaterialMovement.count" do
      assert_raises(ArgumentError) do
        CancelInbound.call(inbound: @inbound.reload, staff: @admin)
      end
    end
    assert_equal 10, CurrentMaterial.find_by(material: @iron).quantity_kg
  end
end
