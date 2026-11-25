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
	var mounted_sessions := {
		11: {"authenticated": true, "jet_ski_mounted": true},
		12: {"authenticated": true, "jet_ski_mounted": true},
		13: {"authenticated": true, "jet_ski_mounted": false}
	}
	if not server._jet_ski_race_all_participants_mounted([11, 12], mounted_sessions):
		failures.append("A fully authenticated and mounted roster was incorrectly rejected.")
	if server._jet_ski_race_all_participants_mounted([11, 13], mounted_sessions):
		failures.append("A roster containing an unmounted participant was incorrectly accepted.")
	mounted_sessions[12]["authenticated"] = false
	if server._jet_ski_race_all_participants_mounted([11, 12], mounted_sessions):
		failures.append("A roster containing an unauthenticated participant was incorrectly accepted.")
	if server._jet_ski_race_all_participants_mounted([11], mounted_sessions):
		failures.append("A single mounted participant was incorrectly accepted as a race roster.")
	if server._jet_ski_race_all_participants_mounted([11, 11], mounted_sessions):
		failures.append("A duplicate peer ID was incorrectly accepted in the race roster.")
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
	if SERVER_SCRIPT.JET_SKI_RACE_WEEKLY_DAYS != [1, 4, 6]:
		failures.append("The weekly jet ski championship days must be Monday, Thursday, and Saturday.")
	if SERVER_SCRIPT.JET_SKI_RACE_START_HOUR_EGYPT != 20 or SERVER_SCRIPT.JET_SKI_RACE_START_MINUTE_EGYPT != 0:
		failures.append("The weekly jet ski championship must start at 8:00 PM Egypt time.")
	if SERVER_SCRIPT.JET_SKI_RACE_ANNOUNCEMENT_MINUTES != 15:
		failures.append("The championship announcement must be scheduled 15 minutes before start.")
	for weekday in [1, 4, 6]:
		if not server._jet_ski_race_is_scheduled_day({"weekday": weekday}):
			failures.append("An approved championship weekday was not recognized: %d." % weekday)
	for weekday in [0, 2, 3, 5]:
		if server._jet_ski_race_is_scheduled_day({"weekday": weekday}):
			failures.append("An unapproved championship weekday was recognized: %d." % weekday)
	if not server._jet_ski_race_is_announcement_time({"weekday": 6, "hour": 19, "minute": 45}):
		failures.append("The 15-minute pre-race announcement window did not open at 7:45 PM.")
	if server._jet_ski_race_is_announcement_time({"weekday": 1, "hour": 20, "minute": 0}):
		failures.append("The announcement window must end at the 8:00 PM start time.")
	if server._jet_ski_race_is_announcement_time({"weekday": 2, "hour": 19, "minute": 50}):
		failures.append("A non-championship day incorrectly triggered an announcement.")
	if SERVER_SCRIPT.JET_SKI_RACE_DAILY_REWARD_WINNING_RANKS != 3:
		failures.append("Daily jet ski rewards must be limited to the top three ranks.")
	for rank in [1, 2, 3]:
		if not server._jet_ski_race_reward_rank_eligible(rank):
			failures.append("Podium rank %d should be reward-eligible." % rank)
	for rank in [0, 4, 5]:
		if server._jet_ski_race_reward_rank_eligible(rank):
			failures.append("Non-podium rank %d must not be reward-eligible." % rank)
	if server._jet_ski_race_daily_reward_claim_key("player-123", "2026-11-23") != "player-123:2026-11-23":
		failures.append("Daily reward claim keys must be scoped to account ID and UTC day.")
	if not server._jet_ski_race_daily_reward_claim_key("", "2026-11-23").is_empty():
		failures.append("Daily reward claim keys must reject empty account IDs.")
	var aperture_radius: float = SERVER_SCRIPT.JET_SKI_RACE_GATE_APERTURE_RADIUS
	var gate_center_height: float = SERVER_SCRIPT.JET_SKI_RACE_GATE_CENTER_HEIGHT
	if not server._jet_ski_race_crossed_gate(Vector3(0.0, 0.34, 95.0), Vector3(0.0, 0.34, 97.0), 0.0, 96.0, aperture_radius):
		failures.append("A valid forward crossing through the circular ring aperture was rejected.")
	if server._jet_ski_race_crossed_gate(Vector3(0.0, 0.34, 97.0), Vector3(0.0, 34, 99.0), 0.0, 96.0, aperture_radius):
		failures.append("A racer already beyond the ring was incorrectly credited without crossing.")
	if server._jet_ski_race_crossed_gate(Vector3(0.0, 0.34, 97.0), Vector3(0.0, 0.34, 95.0), 0.0, 96.0, aperture_radius):
		failures.append("A reverse crossing was incorrectly accepted.")
	if server._jet_ski_race_crossed_gate(Vector3(4.0, 0.34, 95.0), Vector3(4.0, 0.34, 97.0), 0.0, 96.0, aperture_radius):
		failures.append("A crossing outside the lower circular aperture was incorrectly accepted.")
	if server._jet_ski_race_crossed_gate(Vector3(0.0, gate_center_height + aperture_radius + 0.1, 95.0), Vector3(0.0, gate_center_height + aperture_radius + 0.1, 97.0), 0.0, 96.0, aperture_radius):
		failures.append("A crossing above the circular ring was incorrectly accepted.")
	if server._jet_ski_race_crossed_gate(Vector3(0.0, 0.34, 95.0), Vector3(0.0, 0.34, 97.0), -10.0, 111.0, aperture_radius):
		failures.append("A segment that did not cross the requested gate plane was incorrectly accepted.")
	if SERVER_SCRIPT.JET_SKI_RACE_GATE_POSITIONS != [Vector2(0.0, 96.0), Vector2(-10.0, 111.0), Vector2(10.0, 126.0), Vector2(-10.0, 141.0), Vector2(0.0, 156.0)]:
		failures.append("Server gate positions must match the approved staggered slalom course.")
	if server._jet_ski_race_crossed_gate(Vector3(0.0, 0.34, 110.0), Vector3(0.0, 0.34, 112.0), -10.0, 111.0, aperture_radius):
		failures.append("A straight-line crossing that misses the offset checkpoint must be rejected.")
	if not server._jet_ski_race_crossed_gate(Vector3(-10.0, 0.34, 110.0), Vector3(-10.0, 0.34, 112.0), -10.0, 111.0, aperture_radius):
		failures.append("A correctly aligned crossing through the offset checkpoint must be accepted.")
	if not is_equal_approx(aperture_radius, 8.5) or not is_equal_approx(gate_center_height, 8.25):
		failures.append("Server gate aperture dimensions must match the approved circular ring geometry.")
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
	server._jet_ski_race_locked_participants = [11, 12, 13]
	server._jet_ski_race_results = [
		{"peer_id": 12, "status": "finished", "place": 1, "finish_time_usec": 2500000},
		{"peer_id": 11, "status": "finished", "place": 2, "finish_time_usec": 3100000},
		{"peer_id": 13, "status": "dnf", "reason": "disconnect"}
	]
	var public_results := server._jet_ski_race_public_results()
	if public_results.size() != 3:
		failures.append("The public race results board did not include all finishers and DNF records.")
	elif int(public_results[0].get("slot", 0)) != 2 or int(public_results[0].get("place", 0)) != 1:
		failures.append("The public results board did not sort finishers by server place.")
	elif str(public_results[2].get("status", "")) != "dnf":
		failures.append("DNF participants must appear after finishers in the public results board.")
	server._jet_ski_race_results = [
		{"peer_id": 11, "status": "finished", "place": 1, "finish_time_usec": 2500000},
		{"peer_id": 12, "status": "finished", "place": 1, "finish_time_usec": 2500000}
	]
	if server._jet_ski_race_place_for_finish_time(2500000) != 1:
		failures.append("Racers with identical server finish times must share the same rank.")
	if server._jet_ski_race_place_for_finish_time(2600000) != 3:
		failures.append("Competition ranking must skip the next place after a tie.")
	server._sessions = {
		11: {"jet_ski_race_finished": true},
		12: {"jet_ski_race_finished": true}
	}
	server._jet_ski_race_results = [{"peer_id": 13, "status": "dnf"}]
	if not server._jet_ski_race_all_locked_participants_finished():
		failures.append("A disconnected participant with a DNF result should count as resolved.")
	# The dedicated server must durably queue finalized results before attempting network delivery.
	server._is_dedicated_server = true
	server._jet_ski_race_id = "10000000-0000-4000-8000-000000000099"
	server._jet_ski_results_server_id = "city-test-01"
	server._jet_ski_results_url = "" # Keep this contract test offline.
	server._jet_ski_results_outbox.clear()
	if not server._jet_ski_results_hmac_key.is_empty():
		server._jet_ski_results_hmac_key.clear()
	server._queue_jet_ski_race_result("00000000-0000-4000-8000-000000000099", "finished", 1, 2450000, "", 1790000000000000)
	if server._jet_ski_results_outbox.size() != 1:
		failures.append("A finalized result must remain in the durable outbox while HMAC configuration is unavailable.")
	server._jet_ski_results_outbox.clear()
	var result_secret := PackedByteArray()
	result_secret.resize(32)
	result_secret.fill(7)
	server._jet_ski_results_hmac_key = result_secret
	server._queue_jet_ski_race_result("00000000-0000-4000-8000-000000000099", "finished", 1, 2450000, "", 1790000000000000)
	if server._jet_ski_results_outbox.size() != 1:
		failures.append("A finalized result was not added to the durable outbox.")
	else:
		var queued_finish: Dictionary = server._jet_ski_results_outbox[0]
		if str(queued_finish.get("status", "")) != "finished" or int(queued_finish.get("place", 0)) != 1:
			failures.append("The durable outbox did not preserve the server-finalized finish rank.")
		if not str(queued_finish.get("race_finished_at", "")).ends_with("Z"):
			failures.append("Race finish timestamps must be explicit UTC ISO-8601 values.")
		if str(queued_finish.get("race_id", "")) != server._jet_ski_race_id:
			failures.append("Queued results must retain their unique race ID.")
	server._queue_jet_ski_race_result("00000000-0000-4000-8000-000000000098", "dnf", 0, 0, "disconnect", 1790000001000000)
	if server._jet_ski_results_outbox.size() != 2:
		failures.append("A disconnected participant's DNF result was not queued.")
	else:
		var queued_dnf: Dictionary = server._jet_ski_results_outbox[1]
		if queued_dnf.get("place") != null or queued_dnf.get("finish_time_usec") != null or str(queued_dnf.get("reason", "")) != "disconnect":
			failures.append("DNF outbox records must omit finish fields and preserve the server reason.")
	var outbox_config := ConfigFile.new()
	if outbox_config.load(SERVER_SCRIPT.JET_SKI_RESULTS_OUTBOX_PATH) != OK:
		failures.append("The race result outbox was not saved to persistent server storage.")
	else:
		var saved_results: Variant = outbox_config.get_value("results", "pending", [])
		if not (saved_results is Array) or saved_results.size() != 2:
			failures.append("The persistent outbox did not preserve both pending server results.")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SERVER_SCRIPT.JET_SKI_RESULTS_OUTBOX_PATH))
	server.free()
	if not failures.is_empty():
		for failure in failures:
			push_error(failure)
		quit(1)
		return
	print("Royal jet ski race minimum/maximum participant gate tests passed.")
	quit(0)
