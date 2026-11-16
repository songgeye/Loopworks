# frozen_string_literal: true

require "test_helper"

class CheckStockShortageTest < ActiveSupport::TestCase
  setup do
    @iron = create_material(name: "テスト鉄", display_order: 1)
    @copper = create_material(name: "テスト銅", display_order: 2)
  end

  test "在庫がマイナスの品目を、不足量つきで返す" do
    CurrentMaterial.create!(material: @iron, quantity_kg: -2.5)

    assert_equal [{ material_id: @iron.id, name: "テスト鉄", shortage_kg: 2.5 }],
                 CheckStockShortage.call([@iron.id])
  end

  test "在庫が0以上の品目は、返さない" do
    CurrentMaterial.create!(material: @iron, quantity_kg: 0)
    CurrentMaterial.create!(material: @copper, quantity_kg: 5)

    assert_empty CheckStockShortage.call([@iron.id, @copper.id])
  end

  test "現在庫の行がない品目は、0kgとして扱う" do
    assert_empty CheckStockShortage.call([@iron.id])
  end

  test "在庫管理の対象外(stock_target: false)の品目は、マイナスでも返さない" do
    @iron.update!(stock_target: false)
    CurrentMaterial.create!(material: @iron, quantity_kg: -2.5)

    assert_empty CheckStockShortage.call([@iron.id])
  end

  test "指定していない品目は、マイナスでも返さない" do
    CurrentMaterial.create!(material: @iron, quantity_kg: -2.5)
    CurrentMaterial.create!(material: @copper, quantity_kg: -1)

    result = CheckStockShortage.call([@copper.id])

    assert_equal [@copper.id], result.map { |row| row[:material_id] }
  end

  test "品目を指定しなければ、空で返る" do
    CurrentMaterial.create!(material: @iron, quantity_kg: -2.5)

    assert_empty CheckStockShortage.call([])
  end
end
