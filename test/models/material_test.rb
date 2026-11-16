# frozen_string_literal: true

require "test_helper"

class MaterialTest < ActiveSupport::TestCase
  test "名前と表示順があれば有効" do
    assert Material.new(name: "テスト鉄", display_order: 1).valid?
  end

  test "名前がないと無効" do
    material = Material.new(name: "", display_order: 1)

    assert_not material.valid?
    assert material.errors.added?(:name, :blank)
  end

  test "名前が重複すると無効" do
    create_material(name: "テスト鉄")
    material = Material.new(name: "テスト鉄", display_order: 2)

    assert_not material.valid?
    assert material.errors.of_kind?(:name, :taken)
  end

  test "表示順がないと無効" do
    material = Material.new(name: "テスト鉄", display_order: nil)

    assert_not material.valid?
    assert material.errors.added?(:display_order, :blank)
  end

  test "表示順が0以下だと無効" do
    [0, -1].each do |display_order|
      material = Material.new(name: "テスト鉄", display_order: display_order)

      assert_not material.valid?, "display_order=#{display_order} が有効になっています"
      assert material.errors.of_kind?(:display_order, :greater_than)
    end
  end

  test "表示順が整数でないと無効" do
    material = Material.new(name: "テスト鉄", display_order: 1.5)

    assert_not material.valid?
    assert material.errors.of_kind?(:display_order, :not_an_integer)
  end

  test "在庫管理の対象(stock_target)は、初期値が true" do
    assert Material.new.stock_target
  end

  test "削除しても行は残り、通常の検索からは外れる(論理削除)" do
    material = create_material

    material.destroy

    assert_not_nil material.deleted_at
    assert_nil Material.find_by(id: material.id)
    assert_equal material, Material.with_deleted.find(material.id)
  end
end
