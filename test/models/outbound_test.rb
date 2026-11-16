# frozen_string_literal: true

require "test_helper"

class OutboundTest < ActiveSupport::TestCase
  setup do
    @admin = create_staff(role: "admin")
    @counterparty = create_counterparty
    @iron = create_material(name: "テスト鉄", display_order: 1)
    @copper = create_material(name: "テスト銅", display_order: 2)
  end

  def create_outbound(items)
    outbound = Outbound.create!(
      counterparty: @counterparty,
      staff: @admin,
      recorded_at: Time.zone.now,
      outbounds_materials_attributes: items
    )
    outbound.outbounds_materials.each do |outbounds_material|
      RecordMaterialMovement.call(source: outbounds_material, staff: @admin, recorded_at: outbound.recorded_at)
    end
    outbound
  end

  test "取引先とスタッフがないと無効" do
    outbound = Outbound.new(recorded_at: Time.zone.now)

    assert_not outbound.valid?
    assert outbound.errors.of_kind?(:counterparty, :blank)
    assert outbound.errors.of_kind?(:staff, :blank)
  end

  test "すべて空の明細行は、登録されない" do
    outbound = create_outbound([
      { material_id: @iron.id, quantity_kg: 3 },
      { material_id: "", quantity_kg: "" }
    ])

    assert_equal 1, outbound.outbounds_materials.count
  end

  test "同じ請求番号(billing_no)は、2件登録できない" do
    Outbound.create!(counterparty: @counterparty, staff: @admin, recorded_at: Time.zone.now, billing_no: "B-001")

    assert_raises(ActiveRecord::RecordNotUnique) do
      Outbound.create!(counterparty: @counterparty, staff: @admin, recorded_at: Time.zone.now, billing_no: "B-001")
    end
  end

  test "申告重量の合計を返す" do
    outbound = create_outbound([
      { material_id: @iron.id, quantity_kg: 3, declared_kg: 3.5 },
      { material_id: @copper.id, quantity_kg: 2, declared_kg: 1.5 }
    ])

    assert_equal 5, outbound.declared_total_kg
  end

  test "登録しただけでは、取り消し済みにならない" do
    outbound = create_outbound([{ material_id: @iron.id, quantity_kg: 3 }])

    assert_not outbound.cancelled?
  end

  test "すべての明細が打ち消されると、取り消し済みになる" do
    outbound = create_outbound([
      { material_id: @iron.id, quantity_kg: 3 },
      { material_id: @copper.id, quantity_kg: 2 }
    ])

    CancelOutbound.call(outbound: outbound, staff: @admin)

    assert outbound.cancelled?
  end

  test "一部の明細だけ打ち消されても、取り消し済みにならない" do
    outbound = create_outbound([
      { material_id: @iron.id, quantity_kg: 3 },
      { material_id: @copper.id, quantity_kg: 2 }
    ])
    movement = MaterialMovement.find_by!(source: outbound.outbounds_materials.first)

    ReverseMaterialMovement.call(movement: movement, staff: @admin, recorded_at: Time.zone.now)

    assert_not outbound.cancelled?
  end

  test "明細がない出荷は、取り消し済みにならない" do
    outbound = Outbound.create!(counterparty: @counterparty, staff: @admin, recorded_at: Time.zone.now)

    assert_not outbound.cancelled?
  end
end
