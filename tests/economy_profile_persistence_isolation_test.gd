extends SceneTree

const Store = preload("res://scripts/profile_config_store.gd")

const TEST_PATH := "user://economy_profile_isolation_test.cfg"
const TEMP_PATH := "user://economy_profile_isolation_test.cfg.tmp"
const BACKUP_PATH := "user://economy_profile_isolation_test.cfg.backup"
const CORRUPT_PATH := "user://economy_profile_corrupt_test.cfg"
const CORRUPT_TEMP_PATH := "user://economy_profile_corrupt_test.cfg.tmp"
const CORRUPT_BACKUP_PATH := "user://economy_profile_corrupt_test.cfg.backup"

func _initialize() -> void:
	call_deferred("_run")

func _remove_if_exists(path: String) -> void:
	var absolute := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(absolute)

func _cleanup() -> void:
	for path in [TEST_PATH, TEMP_PATH, BACKUP_PATH, BACKUP_PATH + ".pending", CORRUPT_PATH, CORRUPT_TEMP_PATH, CORRUPT_BACKUP_PATH, CORRUPT_BACKUP_PATH + ".pending"]:
		_remove_if_exists(path)

func _fail(message: String) -> void:
	push_error("Economy profile persistence isolation test failed: " + message)
	_cleanup()
	quit(1)

func _run() -> void:
	_cleanup()
	var seed := ConfigFile.new()
	seed.set_value("profile", "money", 900)
	seed.set_value("profile", "chips", 40)
	seed.set_value("profile", "owned_vehicles", ["toyota_corolla"])
	seed.set_value("wallet", "schema_version", 2)
	seed.set_value("wallet", "balances", {"money": 900, "chips": 40, "gems": 12})
	seed.set_value("wallet", "receipts", {"purchase_vehicle_toyota": "receipt-1"})
	seed.set_value("wallet", "ledger", [{"transaction_id": "receipt-1", "amount": 50}])
	seed.set_value("wallet", "integrity_seal", "test-seal")
	seed.set_value("settings", "language", "auto")
	if seed.save(TEST_PATH) != OK:
		_fail("Could not create isolated test profile.")
		return

	# Capture a stale settings snapshot before a newer wallet/ownership write.
	var stale_settings_snapshot := ConfigFile.new()
	if stale_settings_snapshot.load(TEST_PATH) != OK:
		_fail("Could not load stale settings snapshot.")
		return

	if not Store.save_sections(TEST_PATH, {
		"profile": {"money": 925, "chips": 42, "owned_vehicles": ["toyota_corolla", "hyundai_elantra"]},
		"wallet": {
			"balances": {"money": 925, "chips": 42, "gems": 12},
			"receipts": {"purchase_vehicle_toyota": "receipt-1", "purchase_vehicle_elantra": "receipt-2"},
			"ledger": [{"transaction_id": "receipt-1", "amount": 50}, {"transaction_id": "receipt-2", "amount": 25}],
			"integrity_seal": "new-test-seal"
		}
	}, TEMP_PATH, BACKUP_PATH):
		_fail("Could not write the newer wallet snapshot.")
		return

	# The settings writer receives stale UI values, but may update only its own keys.
	if not Store.save_sections(TEST_PATH, {
		"profile": {"player_name": "Test Player"},
		"settings": {"volume": 65, "quality": 1, "language": "ar"}
	}, TEMP_PATH, BACKUP_PATH):
		_fail("Could not merge stale settings into the latest profile.")
		return

	var verify := ConfigFile.new()
	if verify.load(TEST_PATH) != OK:
		_fail("Could not reload merged profile.")
		return
	if int(verify.get_value("profile", "money", -1)) != 925 or int(verify.get_value("profile", "chips", -1)) != 42:
		_fail("Stale settings overwrote the latest cash/chips balances.")
		return
	if verify.get_value("profile", "owned_vehicles", []) != ["toyota_corolla", "hyundai_elantra"]:
		_fail("Stale settings overwrote vehicle ownership.")
		return
	var wallet: Dictionary = verify.get_value("wallet", "balances", {})
	if wallet != {"money": 925, "chips": 42, "gems": 12}:
		_fail("Stale settings overwrote wallet balances.")
		return
	var receipts: Dictionary = verify.get_value("wallet", "receipts", {})
	if not receipts.has("purchase_vehicle_elantra") or receipts.size() != 2:
		_fail("Stale settings overwrote transaction receipts.")
		return
	var ledger: Array = verify.get_value("wallet", "ledger", [])
	if ledger.size() != 2 or str(verify.get_value("wallet", "integrity_seal", "")) != "new-test-seal":
		_fail("Stale settings overwrote ledger/integrity metadata.")
		return
	if str(verify.get_value("profile", "player_name", "")) != "Test Player":
		_fail("Profile metadata update was not applied.")
		return
	if int(verify.get_value("settings", "volume", -1)) != 65 or str(verify.get_value("settings", "language", "")) != "ar":
		_fail("Settings update was not applied.")
		return
	if not FileAccess.file_exists(BACKUP_PATH):
		_fail("First-write backup was not created.")
		return

	# An unreadable existing profile must never be replaced by a settings write.
	var corrupt_file := FileAccess.open(CORRUPT_PATH, FileAccess.WRITE)
	if corrupt_file == null:
		_fail("Could not create corrupt-profile fixture.")
		return
	corrupt_file.store_string("[broken\nnot valid config")
	corrupt_file.close()
	if Store.save_sections(CORRUPT_PATH, {"settings": {"volume": 20}}, CORRUPT_TEMP_PATH, CORRUPT_BACKUP_PATH):
		_fail("Unreadable profile was unexpectedly overwritten.")
		return
	var preserved := FileAccess.open(CORRUPT_PATH, FileAccess.READ)
	if preserved == null or preserved.get_as_text() != "[broken\nnot valid config":
		_fail("Unreadable source profile changed after rejected write.")
		return
	_cleanup()
	print("Economy profile persistence isolation tests passed.")
	quit(0)
