extends SceneTree

const Store = preload("res://scripts/profile_config_store.gd")
const WalletManagerScript = preload("res://scripts/wallet_manager.gd")
var _account_fixture_paths: Array[String] = []

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
	for path in _account_fixture_paths:
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

	# Language-only updates use the same section merge and cannot replace wallet data.
	if not Store.save_sections(TEST_PATH, {"settings": {"language": "en"}}, TEMP_PATH, BACKUP_PATH):
		_fail("Language preference could not be saved through the shared store.")
		return
	var after_language := ConfigFile.new()
	if after_language.load(TEST_PATH) != OK or str(after_language.get_value("settings", "language", "")) != "en":
		_fail("Language preference was not persisted.")
		return
	if int(after_language.get_value("profile", "money", -1)) != 925 or after_language.get_value("profile", "owned_vehicles", []) != ["toyota_corolla", "hyundai_elantra"]:
		_fail("Language preference update changed wallet or vehicle data.")
		return

	# WalletManager's full-snapshot path also uses the shared atomic writer.
	after_language.set_value("profile", "mission_progress_test", 3)
	if not Store.save_config_snapshot(after_language, TEST_PATH, TEMP_PATH, BACKUP_PATH):
		_fail("Shared atomic snapshot writer rejected a valid wallet/progression snapshot.")
		return
	var after_snapshot := ConfigFile.new()
	if after_snapshot.load(TEST_PATH) != OK or int(after_snapshot.get_value("profile", "mission_progress_test", -1)) != 3:
		_fail("Shared atomic snapshot writer did not persist progression data.")
		return
	if int(after_snapshot.get_value("wallet", "balances", {}).get("money", -1)) != 925 or not after_snapshot.get_value("wallet", "receipts", {}).has("purchase_vehicle_elantra"):
		_fail("Shared atomic snapshot writer lost wallet balances or receipts.")
		return

	# Vehicle selection is mutable profile state, while ownership remains protected.
	after_snapshot.set_value("profile", "selected_vehicle_id", "hyundai_elantra")
	after_snapshot.set_value("profile", "selected_horus_color", "royal_gold")
	if not Store.save_config_snapshot(after_snapshot, TEST_PATH, TEMP_PATH, BACKUP_PATH):
		_fail("Could not persist selected vehicle/color through the shared writer.")
		return
	var after_vehicle_selection := ConfigFile.new()
	if after_vehicle_selection.load(TEST_PATH) != OK:
		_fail("Could not reload selected vehicle/color state.")
		return
	if str(after_vehicle_selection.get_value("profile", "selected_vehicle_id", "")) != "hyundai_elantra" or str(after_vehicle_selection.get_value("profile", "selected_horus_color", "")) != "royal_gold":
		_fail("Selected vehicle or Horus color was not persisted.")
		return
	if after_vehicle_selection.get_value("profile", "owned_vehicles", []) != ["toyota_corolla", "hyundai_elantra"]:
		_fail("Vehicle selection update changed the owned vehicle list.")
		return
	# Authenticated player profiles must never share the guest file or one another.
	var guest_path := Store.get_active_profile_path()
	if not Store.set_active_account("synthetic-account-a"):
		_fail("Could not select synthetic account A profile.")
		return
	var account_a_path := Store.get_active_profile_path()
	_account_fixture_paths.append(account_a_path)
	_account_fixture_paths.append(account_a_path + ".wallet.tmp")
	_account_fixture_paths.append(account_a_path + ".pre_wallet_backup.cfg")
	_account_fixture_paths.append(Store.get_active_scoped_path("user://kings_city_achievements.cfg"))
	_account_fixture_paths.append(Store.get_active_scoped_path("user://kings_city_daily.cfg"))
	if Store.get_active_scoped_path("user://kings_city_achievements.cfg") == "user://kings_city_achievements.cfg" or Store.get_active_scoped_path("user://kings_city_daily.cfg") == "user://kings_city_daily.cfg":
		_fail("Authenticated account A reused guest achievement or daily-activity storage.")
		return
	if account_a_path == guest_path or account_a_path == "user://kings_city_profile.cfg":
		_fail("Authenticated account A reused the legacy guest profile.")
		return
	var account_a_config := ConfigFile.new()
	account_a_config.set_value("profile", "player_name", "Account A")
	account_a_config.set_value("profile", "money", 111)
	account_a_config.set_value("profile", "chips", 0)
	account_a_config.set_value("wallet", "schema_version", 2)
	account_a_config.set_value("wallet", "balances", {"money": 111, "chips": 0, "gems": 0})
	account_a_config.set_value("wallet", "receipts", {"account_a_receipt": "fixture"})
	account_a_config.set_value("wallet", "ledger", [{"transaction_id": "account_a_receipt"}])
	account_a_config.set_value("wallet", "integrity_seal", "")
	if account_a_config.save(account_a_path) != OK:
		_fail("Could not create synthetic account A profile.")
		return
	if not Store.set_active_account("synthetic-account-b"):
		_fail("Could not select synthetic account B profile.")
		return
	var account_b_path := Store.get_active_profile_path()
	_account_fixture_paths.append(account_b_path + ".wallet.tmp")
	_account_fixture_paths.append(account_b_path + ".pre_wallet_backup.cfg")
	var account_b_achievements := Store.get_active_scoped_path("user://kings_city_achievements.cfg")
	var account_b_daily := Store.get_active_scoped_path("user://kings_city_daily.cfg")
	if account_b_achievements == _account_fixture_paths[1] or account_b_daily == _account_fixture_paths[2]:
		_fail("Achievement or daily progress storage is shared between authenticated accounts.")
		return
	_account_fixture_paths.append(account_b_path)
	_account_fixture_paths.append(account_b_achievements)
	_account_fixture_paths.append(account_b_daily)
	if account_b_path == account_a_path:
		_fail("Two authenticated accounts resolved to the same local profile.")
		return
	var account_b_config := ConfigFile.new()
	if account_b_config.load(account_b_path) != OK and FileAccess.file_exists(account_b_path):
		_fail("Could not inspect synthetic account B profile.")
		return
	if str(account_b_config.get_value("profile", "player_name", "")) == "Account A":
		_fail("Account B loaded Account A's local profile.")
		return
	account_b_config.set_value("profile", "player_name", "Account B")
	account_b_config.set_value("profile", "money", 222)
	account_b_config.set_value("profile", "chips", 0)
	account_b_config.set_value("wallet", "schema_version", 2)
	account_b_config.set_value("wallet", "balances", {"money": 222, "chips": 0, "gems": 0})
	account_b_config.set_value("wallet", "receipts", {"account_b_receipt": "fixture"})
	account_b_config.set_value("wallet", "ledger", [{"transaction_id": "account_b_receipt"}])
	account_b_config.set_value("wallet", "integrity_seal", "")
	if account_b_config.save(account_b_path) != OK:
		_fail("Could not create synthetic account B profile.")
		return
	# Exercise the real wallet loader to prove its in-memory state is replaced on account changes.
	var wallet_manager := WalletManagerScript.new()
	root.add_child(wallet_manager)
	await process_frame
	if not wallet_manager.initialized or wallet_manager.get_balance("money") != 222 or wallet_manager.has_transaction("account_a_receipt"):
		_fail("WalletManager did not load only Account B's isolated wallet.")
		return
	if not Store.set_active_account("synthetic-account-a") or not wallet_manager.initialize_wallet():
		_fail("WalletManager could not switch back to Account A's wallet.")
		return
	if wallet_manager.get_balance("money") != 111 or not wallet_manager.has_transaction("account_a_receipt") or wallet_manager.has_transaction("account_b_receipt"):
		_fail("WalletManager retained Account B's balance or receipts after switching to Account A.")
		return
	if not Store.set_active_account("synthetic-account-b") or not wallet_manager.initialize_wallet():
		_fail("WalletManager could not switch back to Account B's wallet.")
		return
	if wallet_manager.get_balance("money") != 222 or not wallet_manager.has_transaction("account_b_receipt") or wallet_manager.has_transaction("account_a_receipt"):
		_fail("WalletManager retained Account A's balance or receipts after switching to Account B.")
		return
	wallet_manager.queue_free()
	var verify_a := ConfigFile.new()
	if verify_a.load(account_a_path) != OK or str(verify_a.get_value("profile", "player_name", "")) != "Account A" or int(verify_a.get_value("wallet", "balances", {}).get("money", -1)) != 111:
		_fail("Account B profile writes changed Account A's saved data.")
		return
	if not Store.set_active_account("synthetic-account-a") or Store.get_active_profile_path() != account_a_path:
		_fail("Account A did not resolve back to its stable isolated profile.")
		return
	if not Store.set_active_account("synthetic-account-b") or Store.get_active_profile_path() != account_b_path:
		_fail("Account B did not resolve back to its stable isolated profile.")
		return
	# Restore guest mode for the remainder of the test and clean only synthetic fixtures.
	Store.set_active_account("")
	_cleanup()
	_cleanup()
	print("Economy profile persistence isolation tests passed.")
	quit(0)
