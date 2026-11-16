# frozen_string_literal: true

require "test_helper"

class InboundsMaterialTest < ActiveSupport::TestCase
  setup do
    @admin = create_staff(role: "admin")
    @worker = create_staff(role: "staff")
    @material = create_material
    @inbound = Inbound.create!(
      counterparty: create_counterparty,
      staff: @worker,
      recorded_at: Time.zone.local(2026, 11, 6, 10, 0)
    )
    @inbounds_material = InboundsMaterial.create!(inbound: @inbound, material: @material, quantity_kg: 10)
  end

  test "入荷と品目がないと無効" do
    inbounds_material = InboundsMaterial.new(quantity_kg: 10)

    assert_not inbounds_material.valid?
    assert inbounds_material.errors.of_kind?(:inbound, :blank)
    assert inbounds_material.errors.of_kind?(:material, :blank)
  end

  test "異常フラグは、初期値が false" do
    assert_not @inbounds_material.flagged_as_anomaly
  end

  test "営業日は、入荷の記録日時から決まる" do
    assert_equal Date.new(2026, 11, 6), @inbounds_material.business_date
  end

  test "締め時刻より前の入荷は、前日の営業日になる" do
    @inbound.update!(recorded_at: Time.zone.local(2026, 11, 6, 3, 0))

    with_cutoff_hour(5) do
      assert_equal Date.new(2026, 11, 5), @inbounds_material.business_date
    end
  end

  test "作業員は、当日の営業日の入荷だけ編集できる" do
    travel_to Time.zone.local(2026, 11, 6, 18, 0) do
      assert @inbounds_material.editable_by?(@worker)
    end

    travel_to Time.zone.local(2026, 11, 7, 9, 0) do
      assert_not @inbounds_material.editable_by?(@worker)
    end
  end

  test "管理者は、過去の営業日の入荷も編集できる" do
    travel_to Time.zone.local(2026, 11, 30, 9, 0) do
      assert @inbounds_material.editable_by?(@admin)
    end
  end

  test "ログインしていない場合は、過去の営業日の入荷を編集できない" do
    travel_to Time.zone.local(2026, 11, 7, 9, 0) do
      assert_not @inbounds_material.editable_by?(nil)
    end
  end
end
