# frozen_string_literal: true
require "test_helper"
class RecordMaterialMovementTest< ActiveSupport::TestCase
  setup do
    @staff = Staff.create!(username: "test_admin", name: "テスト管理者", role: "admin", password: "password123")
    @counterparty = Counterparty.create!(party_type: :corporate, name: "テスト取引先")
    @material = Material.create!(name: "テスト鉄", display_order: 1)
    @inbound = Inbound.create!(counterparty: @counterparty, staff: @staff, recorded_at: Time.zone.now)
    @inbounds_material = InboundsMaterial.create!(inbound: @inbound, material: @material, quantity_kg: 10)
  end

  test "同じ明細に2回呼ぶと、エラーになる" do
    RecordMaterialMovement.call(source: @inbounds_material, staff: @staff, recorded_at: @inbound.recorded_at)

    assert_raises(ArgumentError) do
      RecordMaterialMovement.call(source: @inbounds_material, staff: @staff, recorded_at: @inbound.recorded_at)
    end
  end

  test "出荷すると、在庫が減る" do
    RecordMaterialMovement.call(source: @inbounds_material, staff: @staff, recorded_at: @inbound.recorded_at)

    outbound = Outbound.create!(counterparty: @counterparty, staff: @staff, recorded_at: Time.zone.now)
    outbounds_material = OutboundsMaterial.create!(outbound: outbound, material: @material, quantity_kg: 3)

    RecordMaterialMovement.call(source: outbounds_material, staff: @staff, recorded_at: outbound.recorded_at)

    assert_equal(-3, outbounds_material.quantity_kg)
    assert_equal(7, CurrentMaterial.find_by(material: @material).quantity_kg)
    assert_equal(7, MaterialMovement.where(material: @material).sum(:quantity_kg))
  end

  test "途中で失敗したら、台帳に何も残らない" do
    assert_no_difference "MaterialMovement.count" do
      assert_raises(ActiveRecord::RecordInvalid) do
        RecordMaterialMovement.call(source: @inbounds_material, staff: nil, recorded_at: @inbound.recorded_at)
      end
    end
  end
end
