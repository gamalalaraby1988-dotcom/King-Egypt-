extends SceneTree

func _initialize() -> void:
	call_deferred("_run_wallet_tests")

func _run_wallet_tests() -> void:
	await process_frame
	var wallet := root.get_node_or_null("WalletManager")
	if wallet == null or not wallet.initialized:
		push_error("WalletManager autoload did not initialize.")
		quit(1)
		return

	var initial_profile := ConfigFile.new()
	if initial_profile.load("user://kings_city_profile.cfg") != OK:
		push_error("Could not load the newly initialized wallet profile.")
		quit(1)
		return
	if not initial_profile.has_section_key("profile", "money") or not initial_profile.has_section_key("profile", "chips"):
		push_error("First-run wallet migration did not initialize legacy profile balances.")
		quit(1)
		return
	if int(initial_profile.get_value("profile", "money")) != wallet.get_balance("money") or int(initial_profile.get_value("profile", "chips")) != wallet.get_balance("chips"):
		push_error("First-run profile and wallet balances do not match.")
		quit(1)
		return

	var metadata_config := ConfigFile.new()
	if metadata_config.load("user://kings_city_profile.cfg") != OK:
		push_error("Could not load profile for metadata persistence test.")
		quit(1)
		return
	metadata_config.set_value("profile", "ci_metadata_test_marker", true)
	var metadata_money_before: int = wallet.get_balance("money")
	var metadata_chips_before: int = wallet.get_balance("chips")
	if not wallet.save_profile_metadata(metadata_config):
		push_error("Atomic profile metadata save failed.")
		quit(1)
		return
	if wallet.get_balance("money") != metadata_money_before or wallet.get_balance("chips") != metadata_chips_before:
		push_error("Metadata save unexpectedly changed wallet balances.")
		quit(1)
		return
	var tampered_metadata := ConfigFile.new()
	if tampered_metadata.load("user://kings_city_profile.cfg") != OK:
		push_error("Could not reload profile for metadata integrity test.")
		quit(1)
		return
	tampered_metadata.set_value("profile", "money", metadata_money_before + 1)
	if wallet.save_profile_metadata(tampered_metadata):
		push_error("Metadata save accepted a balance change outside a wallet transaction.")
		quit(1)
		return
	var after_rejected_metadata := ConfigFile.new()
	if after_rejected_metadata.load("user://kings_city_profile.cfg") != OK or int(after_rejected_metadata.get_value("profile", "money", -1)) != metadata_money_before:
		push_error("Rejected metadata save changed the persisted balance.")
		quit(1)
		return

	var transaction_id := "ci_wallet_test_%s" % str(Time.get_ticks_usec())
	var before: int = wallet.get_balance("gems")
	if not wallet.credit(transaction_id, "gems", 25, "CI test credit"):
		push_error("Wallet credit failed.")
		quit(1)
		return
	if wallet.get_balance("gems") != before + 25:
		push_error("Wallet credit balance mismatch.")
		quit(1)
		return
	if wallet.credit(transaction_id, "gems", 25, "duplicate test"):
		push_error("Duplicate transaction was accepted.")
		quit(1)
		return
	if not wallet.debit(transaction_id + "_debit", "gems", 10, "CI test debit"):
		push_error("Wallet debit failed.")
		quit(1)
		return
	if wallet.get_balance("gems") != before + 15:
		push_error("Wallet debit balance mismatch.")
		quit(1)
		return
	if wallet.debit(transaction_id + "_insufficient", "gems", before + 16, "insufficient test"):
		push_error("Insufficient-balance debit was accepted.")
		quit(1)
		return
	if wallet.credit(transaction_id + "_negative", "gems", -1, "invalid test"):
		push_error("Negative credit was accepted.")
		quit(1)
		return
	if wallet.credit(transaction_id + "_overflow", "gems", 2000000001, "overflow test"):
		push_error("Overflow credit was accepted.")
		quit(1)
		return

	var money_before: int = wallet.get_balance("money")
	var chips_before: int = wallet.get_balance("chips")
	var profile_config := ConfigFile.new()
	if profile_config.load("user://kings_city_profile.cfg") != OK:
		push_error("Could not load profile for atomic wallet save test.")
		quit(1)
		return
	profile_config.set_value("profile", "ci_wallet_test_marker", true)
	if not wallet.save_profile_update(profile_config, money_before + 7, chips_before + 2):
		push_error("Atomic player profile and wallet save failed.")
		quit(1)
		return
	if wallet.get_balance("money") != money_before + 7 or wallet.get_balance("chips") != chips_before + 2:
		push_error("Atomic profile and wallet balance mismatch.")
		quit(1)
		return

	var purchase_id := transaction_id + "_purchase"
	var gems_before_purchase: int = wallet.get_balance("gems")
	if not wallet.purchase_once(purchase_id, "gems", 5, "CI atomic purchase", {"ci_wallet_test_owned": ["test_vehicle"]}):
		push_error("Atomic purchase transaction failed.")
		quit(1)
		return
	if wallet.get_balance("gems") != gems_before_purchase - 5:
		push_error("Atomic purchase did not debit the exact amount.")
		quit(1)
		return
	if wallet.purchase_once(purchase_id, "gems", 5, "duplicate purchase", {"ci_wallet_test_owned": ["duplicate"]}):
		push_error("Duplicate purchase was accepted.")
		quit(1)
		return
	var verify_config := ConfigFile.new()
	if verify_config.load("user://kings_city_profile.cfg") != OK or verify_config.get_value("profile", "ci_wallet_test_owned", []) != ["test_vehicle"]:
		push_error("Purchase ownership update was not saved atomically.")
		quit(1)
		return
	if wallet.purchase_once(transaction_id + "_free_claim", "money", 0, "CI free claim", {"ci_wallet_free_claim": true}) != true:
		push_error("Receipt-backed free claim failed.")
		quit(1)
		return

	var vehicle_store := root.get_node_or_null("VehicleStoreManager")
	if vehicle_store == null or not vehicle_store.has_vehicle("toyota_corolla"):
		push_error("Default vehicle ownership was not initialized.")
		quit(1)
		return
	if vehicle_store.purchase_vehicle("rolls_royce_phantom"):
		push_error("Vehicle with unapproved price was purchasable.")
		quit(1)
		return

	print("Wallet transaction tests passed.")
	quit(0)
