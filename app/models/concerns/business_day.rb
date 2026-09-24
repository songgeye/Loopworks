module BusinessDay
  module_function

  def current
    from(Time.zone.now)
  end

  def from(time)
    (time.in_time_zone - BUSINESS_DAY_CUTOFF_HOUR.hours).to_date
  end
end