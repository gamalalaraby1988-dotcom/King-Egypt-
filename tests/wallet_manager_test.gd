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
	if vehicle_store.purchase_vehicle("horus_2030"):
		push_error("Horus 2030 purchase was enabled before unified economy approval.")
		quit(1)
		return
	var vehicle_catalog: Dictionary = vehicle_store.get_catalog()
	if int(vehicle_catalog.get("horus_2030", {}).get("price", 0)) != -1:
		push_error("Horus 2030 still exposes an unapproved purchase price.")
		quit(1)
		return
	for color_id in vehicle_store.get_horus_colors():
		if int(vehicle_store.get_horus_colors()[color_id].get("price", 0)) != -1:
			push_error("An unapproved Horus color price is still exposed.")
			quit(1)
			return
	if vehicle_store.purchase_horus_color("obsidian_gold"):
		push_error("Horus color purchase was enabled before unified economy approval.")
		quit(1)
		return

	print("Wallet transaction and purchase-gating tests passed.")
	quit(0)
