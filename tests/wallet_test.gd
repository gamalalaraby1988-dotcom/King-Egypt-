extends SceneTree

const MissionManagerScript = preload("res://scripts/mission_manager.gd")
const PROFILE_PATH := "user://kings_city_profile.cfg"
const PROFILE_BACKUP_PATH := "user://wallet_test_original_profile.cfg"
const WALLET_BACKUP_PATH := "user://kings_city_profile.pre_wallet_v1.cfg"
const WALLET_BACKUP_COPY_PATH := "user://wallet_test_original_backup.cfg"

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("WALLET TEST FAILED: " + message)


func _copy_if_exists(source: String, destination: String) -> bool:
	if not FileAccess.file_exists(source):
		return false
	return DirAccess.copy_absolute(ProjectSettings.globalize_path(source), ProjectSettings.globalize_path(destination)) == OK


func _remove_if_exists(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _restore_file(source: String, destination: String, existed: bool) -> void:
	_remove_if_exists(destination)
	if existed:
		DirAccess.copy_absolute(ProjectSettings.globalize_path(source), ProjectSettings.globalize_path(destination))
		_remove_if_exists(source)


func _run() -> void:
	print("WALLET TEST: begin and preserve existing files")
	var had_profile := _copy_if_exists(PROFILE_PATH, PROFILE_BACKUP_PATH)
	var had_wallet_backup := _copy_if_exists(WALLET_BACKUP_PATH, WALLET_BACKUP_COPY_PATH)
	_remove_if_exists(PROFILE_PATH)
	_remove_if_exists(WALLET_BACKUP_PATH)

	print("WALLET TEST: legacy migration")
	# Legacy profile: migration must preserve existing Cash and Chips and initialize Gems to zero.
	var legacy := ConfigFile.new()
	legacy.set_value("profile", "player_level", 4)
	legacy.set_value("profile", "xp", 25)
	legacy.set_value("profile", "money", 1234)
	legacy.set_value("profile", "chips", 57)
	legacy.set_value("profile", "completed_missions", {"legacy_mission": true})
	_check(legacy.save(PROFILE_PATH) == OK, "create legacy profile")
	var manager = MissionManagerScript.new()
	manager.call("_load_profile")
	_check(manager.money == 1234, "legacy Cash preserved")
	_check(manager.chips == 57, "legacy Chips preserved")
	_check(manager.gems == 0, "legacy Gems initialized to zero")
	_check(FileAccess.file_exists(WALLET_BACKUP_PATH), "pre-migration backup created")
	var migrated := ConfigFile.new()
	_check(migrated.load(PROFILE_PATH) == OK, "migrated profile readable")
	_check(int(migrated.get_value("profile", "money", -1)) == 1234, "saved Cash preserved")
	_check(int(migrated.get_value("profile", "chips", -1)) == 57, "saved Chips preserved")
	_check(int(migrated.get_value("profile", "gems", -1)) == 0, "saved Gems initialized")
	_check(int(migrated.get_value("profile", "wallet_schema_version", 0)) == 1, "wallet schema version written")

	print("WALLET TEST: reward and spending transactions")
	# Reward idempotency and all-currency persistence.
	_check(manager.grant_reward_once("wallet_test_reward", 10, 5, 3, 2), "first three-currency reward accepted")
	_check(not manager.grant_reward_once("wallet_test_reward", 10, 5, 3, 2), "duplicate reward rejected")
	_check(manager.money == 1244 and manager.chips == 60 and manager.gems == 2, "reward balances updated once")
	_check(manager.spend_currency_once("chips", "wallet_test_spend_chips", 5), "Chips spend accepted")
	_check(not manager.spend_currency_once("chips", "wallet_test_spend_chips", 5), "duplicate Chips spend rejected")
	_check(manager.spend_currency_once("gems", "wallet_test_spend_gems", 1), "Gems spend accepted")
	_check(not manager.spend_currency_once("cash", "wallet_test_insufficient", 999999), "insufficient Cash spend rejected")
	_check(not manager.spend_currency_once("unknown", "wallet_test_unknown", 1), "unknown currency rejected")
	_check(not manager.grant_reward_once("wallet_test_negative", 0, 0, 0, -1), "negative Gems reward rejected")
	_check(manager.complete_activity_once("wallet_test_mission", "mission", 1, 1, 1, 1), "activity with all currencies accepted")
	_check(not manager.complete_activity_once("wallet_test_mission", "mission", 1, 1, 1, 1), "duplicate activity rejected")

	print("WALLET TEST: reload persistence")
	var reloaded = MissionManagerScript.new()
	reloaded.call("_load_profile")
	_check(reloaded.money == 1245 and reloaded.chips == 56 and reloaded.gems == 2, "balances persist after reload")
	_check(reloaded.reward_receipts.has("wallet_test_reward"), "reward receipt persists")
	_check(reloaded.reward_receipts.has("spend_currency_chips_wallet_test_spend_chips"), "spend receipt persists")
	_check(reloaded.completed_missions.has("wallet_test_mission"), "activity completion persists")

	print("WALLET TEST: corrupt profile protection")
	# Corrupt files must not be overwritten by wallet operations.
	var corrupt := FileAccess.open(PROFILE_PATH, FileAccess.WRITE)
	_check(corrupt != null, "open profile for corruption guard test")
	if corrupt != null:
		corrupt.store_string("[broken\nnot a config")
		corrupt.close()
	var before := FileAccess.get_file_as_string(PROFILE_PATH)
	var blocked = MissionManagerScript.new()
	blocked.money = 99
	_check(not blocked.grant_reward_once("wallet_test_corrupt", 1), "reward rejected for corrupt profile")
	_check(FileAccess.get_file_as_string(PROFILE_PATH) == before, "corrupt profile left untouched")

	print("WALLET TEST: restore files and finish")
	manager.free()
	reloaded.free()
	blocked.free()
	_restore_file(PROFILE_BACKUP_PATH, PROFILE_PATH, had_profile)
	_restore_file(WALLET_BACKUP_COPY_PATH, WALLET_BACKUP_PATH, had_wallet_backup)

	if failures.is_empty():
		print("WALLET TESTS PASSED")
		quit(0)
	else:
		push_error("WALLET TESTS FAILED: %d" % failures.size())
		quit(1)
