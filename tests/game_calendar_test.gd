extends SceneTree

const GameCalendarScript = preload("res://scripts/game_calendar.gd")

func _initialize() -> void:
	_run_calendar_tests()

func _run_calendar_tests() -> void:
	# 21:59 UTC is 23:59 in the project's configured Egypt UTC+2 clock.
	var before_midnight := 1795211940 # 2026-11-20 21:59:00 UTC
	# 22:00 UTC is 00:00 on the next Egypt game day.
	var after_midnight := 1795212000 # 2026-11-20 22:00:00 UTC
	var before_key := GameCalendarScript.egypt_day_key_for_unix_time(before_midnight)
	var after_key := GameCalendarScript.egypt_day_key_for_unix_time(after_midnight)
	if before_key != "2026-11-20":
		push_error("Egypt game day before midnight boundary was incorrect: %s" % before_key)
		quit(1)
		return
	if after_key != "2026-11-21":
		push_error("Egypt game day after midnight boundary was incorrect: %s" % after_key)
		quit(1)
		return
	# A season is exactly 30 * 24 hours, independent of month length or device timezone.
	var season_start := 1795212000
	var season_end := GameCalendarScript.monthly_season_end_unix(season_start)
	if season_end != season_start + 2592000:
		push_error("Monthly season duration was not exactly 30 days.")
		quit(1)
		return
	if GameCalendarScript.monthly_season_day_index(season_start, season_start) != 0:
		push_error("Monthly season did not begin at day index zero.")
		quit(1)
		return
	if GameCalendarScript.monthly_season_day_index(season_start, season_start + 29 * 86400) != 29:
		push_error("Monthly season final day index was incorrect.")
		quit(1)
		return
	if GameCalendarScript.monthly_season_day_index(season_start, season_end - 1) != 29:
		push_error("Monthly season expired before its final second.")
		quit(1)
		return
	if GameCalendarScript.monthly_season_day_index(season_start, season_end) != -1:
		push_error("Monthly season remained active at its exact end boundary.")
		quit(1)
		return
	if GameCalendarScript.monthly_season_day_index(season_start, season_start - 1) != -1:
		push_error("Monthly season accepted a timestamp before its start.")
		quit(1)
		return
	if GameCalendarScript.monthly_season_end_unix(0) != 0:
		push_error("Invalid monthly season start timestamp was accepted.")
		quit(1)
		return
	print("Egypt game calendar and 30-day season tests passed.")
	quit(0)
