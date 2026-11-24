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
