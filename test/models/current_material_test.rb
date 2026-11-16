# frozen_string_literal: true

require "test_helper"

class CurrentMaterialTest < ActiveSupport::TestCase
  setup do
    @material = create_material
  end

  test "数量を指定しなければ、0kgで作られる" do
    current = CurrentMaterial.create!(material: @material)

    assert_equal 0, current.quantity_kg
  end

  test "品目がないと無効" do
    current = CurrentMaterial.new(material: nil)

    assert_not current.valid?
    assert current.errors.of_kind?(:material, :blank)
  end

  test "同じ品目の現在庫は、2行作れない" do
    CurrentMaterial.create!(material: @material)

    assert_raises(ActiveRecord::RecordNotUnique) do
      CurrentMaterial.create!(material: @material)
    end
  end

  test "品目から現在庫をたどれる" do
    current = CurrentMaterial.create!(material: @material, quantity_kg: 12.5)

    assert_equal current, @material.current_material
  end
end
