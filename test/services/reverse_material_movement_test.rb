# frozen_string_literal: true

require "test_helper"

class ReverseMaterialMovementTest < ActiveSupport::TestCase
  setup do
    @staff = create_staff(role: "staff")
    @admin = create_staff(role: "admin")
    @material = create_material
    @inbound = Inbound.create!(counterparty: create_counterparty, staff: @staff, recorded_at: 1.day.ago)
    @inbounds_material = InboundsMaterial.create!(inbound: @inbound, material: @material, quantity_kg: 10)
    RecordMaterialMovement.call(source: @inbounds_material, staff: @staff, recorded_at: @inbound.recorded_at)
    @movement = MaterialMovement.find_by!(source: @inbounds_material)
  end

  test "逆符号の行が台帳に増え、在庫が元に戻る" do
    recorded_at = Time.zone.local(2026, 11, 6, 10, 0)

    assert_difference "MaterialMovement.count", 1 do
      ReverseMaterialMovement.call(movement: @movement, staff: @admin, recorded_at: recorded_at)
    end

    reversal = MaterialMovement.find_by!(reverses_id: @movement.id)
    assert_equal(-10, reversal.quantity_kg)
    assert_equal @material, reversal.material
    assert_equal @inbounds_material, reversal.source
    assert_equal @admin, reversal.staff
    assert_equal recorded_at, reversal.recorded_at
    assert_equal 0, CurrentMaterial.find_by(material: @material).quantity_kg
    assert_equal 0, MaterialMovement.where(material: @material).sum(:quantity_kg)
  end

  test "元の行は書き換えない" do
    assert_no_changes -> { @movement.reload.attributes } do
      ReverseMaterialMovement.call(movement: @movement, staff: @admin, recorded_at: Time.zone.now)
    end
  end

  test "出荷の行を打ち消すと、在庫が増える" do
    outbound = Outbound.create!(counterparty: create_counterparty, staff: @admin, recorded_at: Time.zone.now)
    outbounds_material = OutboundsMaterial.create!(outbound: outbound, material: @material, quantity_kg: 3)
    RecordMaterialMovement.call(source: outbounds_material, staff: @admin, recorded_at: outbound.recorded_at)
    movement = MaterialMovement.find_by!(source: outbounds_material)

    ReverseMaterialMovement.call(movement: movement, staff: @admin, recorded_at: Time.zone.now)

    assert_equal 10, CurrentMaterial.find_by(material: @material).quantity_kg
  end

  test "すでに取り消し済みの行は、もう一度取り消せない" do
    ReverseMaterialMovement.call(movement: @movement, staff: @admin, recorded_at: Time.zone.now)

    assert_no_difference "MaterialMovement.count" do
      error = assert_raises(ArgumentError) do
        ReverseMaterialMovement.call(movement: @movement.reload, staff: @admin, recorded_at: Time.zone.now)
      end
      assert_equal "すでに取り消し済みです", error.message
    end
    assert_equal 0, CurrentMaterial.find_by(material: @material).quantity_kg
  end

  test "打ち消しの行そのものは、取り消せない" do
    ReverseMaterialMovement.call(movement: @movement, staff: @admin, recorded_at: Time.zone.now)
    reversal = MaterialMovement.find_by!(reverses_id: @movement.id)

    assert_no_difference "MaterialMovement.count" do
      error = assert_raises(ArgumentError) do
        ReverseMaterialMovement.call(movement: reversal, staff: @admin, recorded_at: Time.zone.now)
      end
      assert_equal "打ち消しの行は取り消せません", error.message
    end
  end

  test "途中で失敗したら、台帳も在庫も変わらない" do
    assert_no_difference "MaterialMovement.count" do
      assert_raises(ActiveRecord::RecordInvalid) do
        ReverseMaterialMovement.call(movement: @movement, staff: nil, recorded_at: Time.zone.now)
      end
    end
    assert_equal 10, CurrentMaterial.find_by(material: @material).quantity_kg
  end
end
