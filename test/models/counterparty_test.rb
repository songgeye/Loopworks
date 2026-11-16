# frozen_string_literal: true

require "test_helper"

class CounterpartyTest < ActiveSupport::TestCase
  test "名前と区分があれば有効" do
    assert Counterparty.new(name: "テスト取引先", party_type: :corporate).valid?
  end

  test "名前がないと無効" do
    counterparty = Counterparty.new(name: "", party_type: :corporate)

    assert_not counterparty.valid?
    assert counterparty.errors.added?(:name, :blank)
  end

  test "区分がないと無効" do
    counterparty = Counterparty.new(name: "テスト取引先", party_type: nil)

    assert_not counterparty.valid?
    assert counterparty.errors.of_kind?(:party_type, :inclusion)
  end

  test "区分が定義外の値だと、例外ではなく無効になる" do
    counterparty = Counterparty.new(name: "テスト取引先", party_type: "unknown")

    assert_not counterparty.valid?
    assert counterparty.errors.of_kind?(:party_type, :inclusion)
  end

  test "区分は 法人(corporate) と 個人(individual) を扱える" do
    assert Counterparty.new(name: "法人", party_type: "corporate").corporate?
    assert Counterparty.new(name: "個人", party_type: "individual").individual?
  end

  test "身分証区分は空でもよい" do
    assert Counterparty.new(name: "個人", party_type: :individual, id_type: nil).valid?
  end

  test "身分証区分は定義済みの値をすべて扱える" do
    %w[drivers_license my_number_card health_insurance passport residence_card other].each do |id_type|
      counterparty = Counterparty.new(name: "個人", party_type: :individual, id_type: id_type)

      assert counterparty.valid?, "#{id_type} が有効になっていません"
    end
  end

  test "身分証区分が定義外の値だと無効" do
    counterparty = Counterparty.new(name: "個人", party_type: :individual, id_type: "unknown")

    assert_not counterparty.valid?
    assert counterparty.errors.of_kind?(:id_type, :inclusion)
  end
end
