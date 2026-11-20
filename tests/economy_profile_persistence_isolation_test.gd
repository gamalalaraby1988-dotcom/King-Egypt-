extends SceneTree

const Store = preload("res://scripts/profile_config_store.gd")

const TEST_PATH := "user://economy_profile_isolation_test.cfg"
const TEMP_PATH := "user://economy_profile_isolation_test.cfg.tmp"
const BACKUP_PATH := "user://economy_profile_isolation_test.cfg.backup"
const WALLET_PENDING_PATH := "user://economy_profile_isolation_test.cfg.wallet.pending"

func _initialize() -> void:
	call_deferred("_run")

func _remove_if_exists(path: String) -> void:
	var absolute := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(absolute)

func _cleanup() -> void:
	for path in [TEST_PATH, TEMP_PATH, BACKUP_PATH, BACKUP_PATH + ".pending", WALLET_PENDING_PATH]:
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
	if int(stale_settings_snapshot.get_value("profile", "money", -1)) != 900:
		_fail("Stale settings fixture did not retain the original snapshot.")
		return

	var wallet_writer := ConfigFile.new()
	if wallet_writer.load(TEST_PATH) != OK:
		_fail("Wallet writer could not load the latest profile.")
		return
	wallet_writer.set_value("profile", "money", 925)
	wallet_writer.set_value("profile", "chips", 42)
	wallet_writer.set_value("profile", "owned_vehicles", ["toyota_corolla", "hyundai_elantra"])
	wallet_writer.set_value("wallet", "balances", {"money": 925, "chips": 42, "gems": 12})
	wallet_writer.set_value("wallet", "receipts", {"purchase_vehicle_toyota": "receipt-1", "purchase_vehicle_elantra": "receipt-2"})
	wallet_writer.set_value("wallet", "ledger", [{"transaction_id": "receipt-1", "amount": 50}, {"transaction_id": "receipt-2", "amount": 25}])
	wallet_writer.set_value("wallet", "integrity_seal", "new-test-seal")
	if wallet_writer.save(TEMP_PATH) != OK:
		_fail("Wallet writer could not stage the new snapshot.")
		return
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(TEST_PATH), ProjectSettings.globalize_path(WALLET_PENDING_PATH)) != OK:
		_fail("Wallet writer could not rotate the previous snapshot.")
		return
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(TEMP_PATH), ProjectSettings.globalize_path(TEST_PATH)) != OK:
		DirAccess.rename_absolute(ProjectSettings.globalize_path(WALLET_PENDING_PATH), ProjectSettings.globalize_path(TEST_PATH))
		_fail("Wallet writer could not install the new snapshot.")
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(WALLET_PENDING_PATH))

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
	var backup_config := ConfigFile.new()
	if backup_config.load(BACKUP_PATH) != OK or int(backup_config.get_value("profile", "money", -1)) != 925:
		_fail("Backup does not contain the latest pre-settings wallet snapshot.")
		return

	# Reject attempts to write wallet sections through the profile/settings helper.
	if Store.save_sections(TEST_PATH, {"wallet": {"balances": {"money": 1}}}, TEMP_PATH, BACKUP_PATH):
		_fail("Profile settings helper accepted a wallet-section write.")
		return
	var after_rejected_write := ConfigFile.new()
	if after_rejected_write.load(TEST_PATH) != OK or int(after_rejected_write.get_value("profile", "money", -1)) != 925:
		_fail("Rejected section update changed the saved wallet profile.")
		return
	_cleanup()
	print("Economy profile persistence isolation tests passed.")
	quit(0)
