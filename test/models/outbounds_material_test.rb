# frozen_string_literal: true

require "test_helper"

class OutboundsMaterialTest < ActiveSupport::TestCase
  setup do
    @admin = create_staff(role: "admin")
    @worker = create_staff(role: "staff")
    @material = create_material
    @outbound = Outbound.create!(
      counterparty: create_counterparty,
      staff: @admin,
      recorded_at: Time.zone.local(2026, 11, 6, 10, 0)
    )
  end

  test "出荷と品目がないと無効" do
    outbounds_material = OutboundsMaterial.new(quantity_kg: 3)

    assert_not outbounds_material.valid?
    assert outbounds_material.errors.of_kind?(:outbound, :blank)
    assert outbounds_material.errors.of_kind?(:material, :blank)
  end

  test "数量をプラスで渡しても、マイナスで保存される" do
    outbounds_material = OutboundsMaterial.create!(outbound: @outbound, material: @material, quantity_kg: 3)

    assert_equal(-3, outbounds_material.reload.quantity_kg)
  end

  test "数量をマイナスで渡しても、マイナスのまま保存される" do
    outbounds_material = OutboundsMaterial.create!(outbound: @outbound, material: @material, quantity_kg: -3)

    assert_equal(-3, outbounds_material.reload.quantity_kg)
  end

  test "営業日は、出荷の記録日時から決まる" do
    outbounds_material = OutboundsMaterial.create!(outbound: @outbound, material: @material, quantity_kg: 3)

    assert_equal Date.new(2026, 11, 6), outbounds_material.business_date
  end

  test "作業員は当日の営業日だけ、管理者は過去の営業日も編集できる" do
    outbounds_material = OutboundsMaterial.create!(outbound: @outbound, material: @material, quantity_kg: 3)

    travel_to Time.zone.local(2026, 11, 6, 18, 0) do
      assert outbounds_material.editable_by?(@worker)
    end

    travel_to Time.zone.local(2026, 11, 7, 9, 0) do
      assert_not outbounds_material.editable_by?(@worker)
      assert outbounds_material.editable_by?(@admin)
    end
  end
end
