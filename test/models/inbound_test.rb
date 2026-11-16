# frozen_string_literal: true

require "test_helper"

class InboundTest < ActiveSupport::TestCase
  setup do
    @admin = create_staff(role: "admin")
    @worker = create_staff(role: "staff")
    @counterparty = create_counterparty
    @iron = create_material(name: "テスト鉄", display_order: 1)
    @copper = create_material(name: "テスト銅", display_order: 2)
  end

  def create_inbound(items, recorded_at: Time.zone.now)
    inbound = Inbound.create!(
      counterparty: @counterparty,
      staff: @worker,
      recorded_at: recorded_at,
      inbounds_materials_attributes: items
    )
    inbound.inbounds_materials.each do |inbounds_material|
      RecordMaterialMovement.call(source: inbounds_material, staff: @worker, recorded_at: recorded_at)
    end
    inbound
  end

  test "取引先とスタッフがないと無効" do
    inbound = Inbound.new(recorded_at: Time.zone.now)

    assert_not inbound.valid?
    assert inbound.errors.of_kind?(:counterparty, :blank)
    assert inbound.errors.of_kind?(:staff, :blank)
  end

  test "明細をまとめて登録できる" do
    inbound = create_inbound([
      { material_id: @iron.id, quantity_kg: 10 },
      { material_id: @copper.id, quantity_kg: 5 }
    ])

    assert_equal 2, inbound.inbounds_materials.count
  end

  test "すべて空の明細行は、登録されない" do
    inbound = create_inbound([
      { material_id: @iron.id, quantity_kg: 10 },
      { material_id: "", quantity_kg: "" }
    ])

    assert_equal 1, inbound.inbounds_materials.count
  end

  test "同じ請求番号(billing_no)は、2件登録できない" do
    Inbound.create!(counterparty: @counterparty, staff: @worker, recorded_at: Time.zone.now, billing_no: "B-001")

    assert_raises(ActiveRecord::RecordNotUnique) do
      Inbound.create!(counterparty: @counterparty, staff: @worker, recorded_at: Time.zone.now, billing_no: "B-001")
    end
  end

  test "申告重量の合計を返す(未入力の明細は数えない)" do
    inbound = create_inbound([
      { material_id: @iron.id, quantity_kg: 10, declared_kg: 10.5 },
      { material_id: @copper.id, quantity_kg: 5, declared_kg: 4.5 },
      { material_id: @copper.id, quantity_kg: 1 }
    ])

    assert_equal 15, inbound.declared_total_kg
  end

  test "登録しただけでは、取り消し済みにならない" do
    inbound = create_inbound([{ material_id: @iron.id, quantity_kg: 10 }])

    assert_not inbound.cancelled?
  end

  test "すべての明細が打ち消されると、取り消し済みになる" do
    inbound = create_inbound([
      { material_id: @iron.id, quantity_kg: 10 },
      { material_id: @copper.id, quantity_kg: 5 }
    ])

    CancelInbound.call(inbound: inbound, staff: @admin)

    assert inbound.cancelled?
  end

  test "一部の明細だけ打ち消されても、取り消し済みにならない" do
    inbound = create_inbound([
      { material_id: @iron.id, quantity_kg: 10 },
      { material_id: @copper.id, quantity_kg: 5 }
    ])
    movement = MaterialMovement.find_by!(source: inbound.inbounds_materials.first)

    ReverseMaterialMovement.call(movement: movement, staff: @admin, recorded_at: Time.zone.now)

    assert_not inbound.cancelled?
  end

  test "明細がない入荷は、取り消し済みにならない" do
    inbound = Inbound.create!(counterparty: @counterparty, staff: @worker, recorded_at: Time.zone.now)

    assert_not inbound.cancelled?
  end

  test "作業員は当日の営業日の入荷だけ、管理者は過去の入荷も編集できる" do
    inbound = create_inbound(
      [{ material_id: @iron.id, quantity_kg: 10 }],
      recorded_at: Time.zone.local(2026, 11, 6, 10, 0)
    )

    travel_to Time.zone.local(2026, 11, 6, 18, 0) do
      assert inbound.editable_by?(@worker)
    end

    travel_to Time.zone.local(2026, 11, 7, 9, 0) do
      assert_not inbound.editable_by?(@worker)
      assert inbound.editable_by?(@admin)
    end
  end
end
