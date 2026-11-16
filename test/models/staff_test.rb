# frozen_string_literal: true

require "test_helper"

class StaffTest < ActiveSupport::TestCase
  def build_staff(**attributes)
    Staff.new({ username: "taro", name: "山田太郎", role: "staff", password: "password123" }.merge(attributes))
  end

  test "必要な項目がそろっていれば有効" do
    assert build_staff.valid?
  end

  test "ユーザー名がないと無効" do
    staff = build_staff(username: "")

    assert_not staff.valid?
    assert staff.errors.added?(:username, :blank)
  end

  test "ユーザー名が重複すると無効" do
    build_staff.save!
    staff = build_staff(name: "別の人")

    assert_not staff.valid?
    assert staff.errors.of_kind?(:username, :taken)
  end

  test "名前がないと無効" do
    staff = build_staff(name: "")

    assert_not staff.valid?
    assert staff.errors.added?(:name, :blank)
  end

  test "役割がないと無効" do
    staff = build_staff(role: "")

    assert_not staff.valid?
    assert staff.errors.added?(:role, :blank)
  end

  test "役割が admin・staff 以外だと無効" do
    staff = build_staff(role: "owner")

    assert_not staff.valid?
    assert staff.errors.of_kind?(:role, :inclusion)
  end

  test "admin? は、役割が admin のときだけ true" do
    assert build_staff(role: "admin").admin?
    assert_not build_staff(role: "staff").admin?
  end

  test "パスワードは、平文ではなくハッシュで保存される" do
    staff = build_staff
    staff.save!

    assert_not_equal "password123", staff.encrypted_password
    assert staff.valid_password?("password123")
    assert_not staff.valid_password?("wrong-password")
  end

  test "無効化されていなければ、ログインできる状態" do
    assert build_staff.active_for_authentication?
  end

  test "無効化(deleted_at)されると、ログインできない状態になる" do
    assert_not build_staff(deleted_at: Time.current).active_for_authentication?
  end
end
