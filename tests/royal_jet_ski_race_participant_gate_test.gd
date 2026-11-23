extends SceneTree

const SERVER_SCRIPT = preload("res://scripts/authoritative_game_server.gd")

func _initialize() -> void:
	var server := SERVER_SCRIPT.new()
	var failures: Array[String] = []
	for count in [0, 1]:
		if server._jet_ski_race_can_start(count):
			failures.append("Race start incorrectly allowed with %d participant(s)." % count)
	for count in [2, 3, 4]:
		if not server._jet_ski_race_can_start(count):
			failures.append("Race start incorrectly rejected with %d participant(s)." % count)
	if server._jet_ski_race_can_start(5):
		failures.append("Race start incorrectly allowed with five participants.")
	if server._jet_ski_race_should_reopen_after_disconnect(false, "ready"):
		failures.append("A non-participant disconnect incorrectly reopened a ready race.")
	if server._jet_ski_race_should_reopen_after_disconnect(false, "countdown"):
		failures.append("A non-participant disconnect incorrectly cancelled the countdown.")
	if not server._jet_ski_race_should_reopen_after_disconnect(true, "ready"):
		failures.append("A participant disconnect did not reopen a ready race.")
	if not server._jet_ski_race_should_reopen_after_disconnect(true, "countdown"):
		failures.append("A participant disconnect did not cancel the active countdown.")
	if SERVER_SCRIPT.JET_SKI_RACE_COUNTDOWN_SECONDS != 5:
		failures.append("The synchronized server countdown must be five seconds.")
	if SERVER_SCRIPT.JET_SKI_RACE_DURATION_SECONDS != 300:
		failures.append("The server race duration must be exactly five minutes.")
	if SERVER_SCRIPT.JET_SKI_RACE_OFF_COURSE_LIMIT_SECONDS != 300:
		failures.append("The off-course return allowance must be exactly five minutes.")
	if server._jet_ski_race_duration_expired(999999, 1000000):
		failures.append("The race duration expired before its deadline.")
	if not server._jet_ski_race_duration_expired(1000000, 1000000):
		failures.append("The race duration did not expire at its deadline.")
	if server._jet_ski_race_duration_expired(1000000, 0):
		failures.append("A cleared race deadline was incorrectly treated as expired.")
	if server._jet_ski_race_should_reopen_after_disconnect(true, "waiting"):
		failures.append("A participant disconnect changed a lobby that was already waiting.")
	var participant_ids: Array[int] = [11, 12]
	if server._jet_ski_race_can_watch(11, participant_ids):
		failures.append("A registered racer was incorrectly allowed into spectator mode.")
	if not server._jet_ski_race_can_watch(13, participant_ids):
		failures.append("A non-participant was incorrectly blocked from spectator mode.")
	if server._jet_ski_race_can_watch(0, participant_ids):
		failures.append("An invalid peer ID was incorrectly allowed into spectator mode.")
	server.free()
	if not failures.is_empty():
		for failure in failures:
			push_error(failure)
		quit(1)
		return
	print("Royal jet ski race minimum/maximum participant gate tests passed.")
	quit(0)
