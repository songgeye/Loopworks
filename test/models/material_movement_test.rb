# frozen_string_literal: true

require "test_helper"

class MaterialMovementTest < ActiveSupport::TestCase
  setup do
    @staff = create_staff(role: "admin")
    @material = create_material
    @inbound = Inbound.create!(counterparty: create_counterparty, staff: @staff, recorded_at: Time.zone.now)
    @inbounds_material = InboundsMaterial.create!(inbound: @inbound, material: @material, quantity_kg: 10)
    RecordMaterialMovement.call(source: @inbounds_material, staff: @staff, recorded_at: @inbound.recorded_at)
    @movement = MaterialMovement.find_by!(source: @inbounds_material)
  end

  test "品目とスタッフがないと無効" do
    movement = MaterialMovement.new(quantity_kg: 1, recorded_at: Time.zone.now)

    assert_not movement.valid?
    assert movement.errors.of_kind?(:material, :blank)
    assert movement.errors.of_kind?(:staff, :blank)
  end

  test "元になった明細(source)をたどれる" do
    assert_equal @inbounds_material, @movement.source
    assert_equal @movement, @inbounds_material.material_movement
  end

  test "通常の行は、打ち消しの行ではない" do
    assert_not @movement.reversal?
    assert_nil @movement.original_movement
    assert_nil @movement.reversal_movement
  end

  test "打ち消しの行は、元の行と相互にたどれる" do
    ReverseMaterialMovement.call(movement: @movement, staff: @staff, recorded_at: Time.zone.now)
    reversal = MaterialMovement.find_by!(reverses_id: @movement.id)

    assert reversal.reversal?
    assert_equal @movement, reversal.original_movement
    assert_equal reversal, @movement.reload.reversal_movement
  end

  test "同じ行を打ち消す行は、2行作れない" do
    attributes = {
      material: @material, staff: @staff, source: @inbounds_material,
      quantity_kg: -10, recorded_at: Time.zone.now, original_movement: @movement
    }
    MaterialMovement.create!(attributes)

    assert_raises(ActiveRecord::RecordNotUnique) do
      MaterialMovement.create!(attributes)
    end
  end
end
