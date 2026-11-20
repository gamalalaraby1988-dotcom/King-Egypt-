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
	print("Egypt game calendar tests passed.")
	quit(0)
