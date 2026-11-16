# frozen_string_literal: true

require "test_helper"

class AdjustmentMaterialTest < ActiveSupport::TestCase
  setup do
    @staff = create_staff(role: "admin")
    @material = create_material
  end

  def build_adjustment(**attributes)
    AdjustmentMaterial.new({
      material: @material,
      staff: @staff,
      quantity_kg: 5,
      note: "棚卸差異",
      recorded_at: Time.zone.now
    }.merge(attributes))
  end

  test "必要な項目がそろっていれば有効" do
    assert build_adjustment.valid?
  end

  test "理由(note)がないと無効" do
    adjustment = build_adjustment(note: "")

    assert_not adjustment.valid?
    assert adjustment.errors.added?(:note, :blank)
  end

  test "数量が0だと無効" do
    adjustment = build_adjustment(quantity_kg: 0)

    assert_not adjustment.valid?
    assert adjustment.errors.of_kind?(:quantity_kg, :other_than)
  end

  test "数量が数値でないと無効" do
    adjustment = build_adjustment(quantity_kg: nil)

    assert_not adjustment.valid?
    assert adjustment.errors.of_kind?(:quantity_kg, :not_a_number)
  end

  test "品目とスタッフがないと無効" do
    adjustment = build_adjustment(material: nil, staff: nil)

    assert_not adjustment.valid?
    assert adjustment.errors.of_kind?(:material, :blank)
    assert adjustment.errors.of_kind?(:staff, :blank)
  end

  test "区分が decrease なら、数量はマイナスになる" do
    adjustment = build_adjustment(direction: "decrease", quantity_kg: 5)
    adjustment.valid?

    assert_equal(-5, adjustment.quantity_kg)
  end

  test "区分が decrease なら、マイナスで渡してもマイナスのまま" do
    adjustment = build_adjustment(direction: "decrease", quantity_kg: -5)
    adjustment.valid?

    assert_equal(-5, adjustment.quantity_kg)
  end

  test "区分が increase なら、マイナスで渡してもプラスになる" do
    adjustment = build_adjustment(direction: "increase", quantity_kg: -5)
    adjustment.valid?

    assert_equal 5, adjustment.quantity_kg
  end

  test "区分がなければ、数量の符号はそのまま" do
    adjustment = build_adjustment(direction: nil, quantity_kg: -5)
    adjustment.valid?

    assert_equal(-5, adjustment.quantity_kg)
  end

  test "保存後は変更できない" do
    adjustment = build_adjustment
    adjustment.save!

    assert_raises(ActiveRecord::ReadOnlyRecord) do
      adjustment.update!(note: "書き換え")
    end
    assert_equal "棚卸差異", adjustment.reload.note
  end
end
