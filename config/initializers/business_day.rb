# 環境変数で BUSINESS_DAY_CUTOFF_HOUR を指定していればその時間を、指定していなければ 0時 を、締め時刻として使う
BUSINESS_DAY_CUTOFF_HOUR = ENV.fetch("BUSINESS_DAY_CUTOFF_HOUR", "0").to_i