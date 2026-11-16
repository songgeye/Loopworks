# frozen_string_literal: true

require "test_helper"

class BusinessDayTest < ActiveSupport::TestCase
  test "締め時刻が0時なら、暦の日付がそのまま営業日になる" do
    with_cutoff_hour(0) do
      assert_equal Date.new(2026, 11, 6), BusinessDay.from(Time.zone.local(2026, 11, 6, 0, 0))
      assert_equal Date.new(2026, 11, 6), BusinessDay.from(Time.zone.local(2026, 11, 6, 23, 59))
    end
  end

  test "締め時刻より前は、前日の営業日になる" do
    with_cutoff_hour(5) do
      assert_equal Date.new(2026, 11, 5), BusinessDay.from(Time.zone.local(2026, 11, 6, 4, 59))
      assert_equal Date.new(2026, 11, 6), BusinessDay.from(Time.zone.local(2026, 11, 6, 5, 0))
    end
  end

  test "UTCの時刻は、アプリのタイムゾーン(東京)に直して判定する" do
    with_cutoff_hour(0) do
      # UTC 11/5 15:00 = 東京 11/6 0:00
      assert_equal Date.new(2026, 11, 6), BusinessDay.from(Time.utc(2026, 11, 5, 15, 0))
      assert_equal Date.new(2026, 11, 5), BusinessDay.from(Time.utc(2026, 11, 5, 14, 59))
    end
  end

  test "current は、今の時刻の営業日を返す" do
    with_cutoff_hour(0) do
      travel_to Time.zone.local(2026, 11, 6, 12, 0) do
        assert_equal Date.new(2026, 11, 6), BusinessDay.current
      end
    end
  end
end
