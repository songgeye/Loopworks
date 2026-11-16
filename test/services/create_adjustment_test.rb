# frozen_string_literal: true

require "test_helper"

class CreateAdjustmentTest < ActiveSupport::TestCase
  setup do
    @staff = create_staff(role: "admin")
    @material = create_material
    CurrentMaterial.create!(material: @material, quantity_kg: 10)
  end

  def attributes(**overrides)
    { material_id: @material.id, staff_id: @staff.id, direction: "increase", quantity_kg: 5, note: "棚卸差異" }
      .merge(overrides)
  end

  test "増やす調整をすると、台帳が1行増え、在庫が増える" do
    adjustment = nil
    assert_difference ["AdjustmentMaterial.count", "MaterialMovement.count"], 1 do
      adjustment = CreateAdjustment.call(attributes(direction: "increase", quantity_kg: 5))
    end

    assert_equal 5, adjustment.quantity_kg
    assert_equal 15, CurrentMaterial.find_by(material: @material).quantity_kg
    assert_equal 5, MaterialMovement.find_by!(source: adjustment).quantity_kg
  end

  test "減らす調整をすると、在庫が減る" do
    adjustment = CreateAdjustment.call(attributes(direction: "decrease", quantity_kg: 4))

    assert_equal(-4, adjustment.quantity_kg)
    assert_equal 6, CurrentMaterial.find_by(material: @material).quantity_kg
    assert_equal(-4, MaterialMovement.find_by!(source: adjustment).quantity_kg)
  end

  test "記録日時は、実行した時刻になる" do
    travel_to Time.zone.local(2026, 11, 6, 10, 0) do
      adjustment = CreateAdjustment.call(attributes)

      assert_equal Time.zone.local(2026, 11, 6, 10, 0), adjustment.recorded_at
      assert_equal adjustment.recorded_at, MaterialMovement.find_by!(source: adjustment).recorded_at
    end
  end

  test "現在庫の行がない品目でも、調整できる" do
    copper = create_material(name: "テスト銅", display_order: 2)

    CreateAdjustment.call(attributes(material_id: copper.id, quantity_kg: 3))

    assert_equal 3, CurrentMaterial.find_by(material: copper).quantity_kg
  end

  test "区分が increase・decrease 以外だと、エラーになり何も残らない" do
    assert_no_difference ["AdjustmentMaterial.count", "MaterialMovement.count"] do
      [nil, "", "unknown"].each do |direction|
        error = assert_raises(ArgumentError) do
          CreateAdjustment.call(attributes(direction: direction))
        end
        assert_equal "区分が正しくありません", error.message
      end
    end
  end

  test "理由がないと、エラーになり何も残らない" do
    assert_no_difference ["AdjustmentMaterial.count", "MaterialMovement.count"] do
      assert_raises(ActiveRecord::RecordInvalid) do
        CreateAdjustment.call(attributes(note: ""))
      end
    end
    assert_equal 10, CurrentMaterial.find_by(material: @material).quantity_kg
  end

  test "数量が0だと、エラーになり何も残らない" do
    assert_no_difference ["AdjustmentMaterial.count", "MaterialMovement.count"] do
      assert_raises(ActiveRecord::RecordInvalid) do
        CreateAdjustment.call(attributes(quantity_kg: 0))
      end
    end
  end
end
