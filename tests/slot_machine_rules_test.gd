extends SceneTree

func _initialize() -> void:
	_run_slot_rules_tests()

func _run_slot_rules_tests() -> void:
	var rules_script := load("res://scripts/slot_machine_rules.gd")
	if rules_script == null:
		push_error("Approved slot rules script could not be loaded.")
		quit(1)
		return
	if not rules_script.is_configuration_valid():
		push_error("Approved slot rules configuration is invalid.")
		quit(1)
		return
	for machine_id in ["vip_royal_classic", "vip_diamond_royale", "vip_golden_crown"]:
		var machine_rules: Dictionary = rules_script.get_machine_rules(machine_id)
		if machine_rules.is_empty() or int(machine_rules.get("minimum_bet_chips", 0)) != 10:
			push_error("Missing approved rules for machine: " + machine_id)
			quit(1)
			return
		if machine_rules["symbol_weights_bps"] != [4000, 3000, 1800, 900, 300]:
			push_error("Symbol weights do not match the approved distribution.")
			quit(1)
			return
		if machine_rules["triple_payout_tenths"] != [50, 100, 300, 1200, 5000]:
			push_error("Triple-symbol payouts do not match the approved table.")
			quit(1)
			return
		if machine_rules["symbol_weights_bps"] == rules_script.SYMBOL_WEIGHTS_BPS and not machine_rules["symbol_weights_bps"] is Array:
			push_error("Machine rules must expose a copied configuration array.")
			quit(1)
			return
	if rules_script.get_payout_multiplier_tenths([0, 0, 0]) != 50:
		push_error("Three first symbols must pay 5.0x.")
		quit(1)
		return
	if rules_script.get_payout_multiplier_tenths([1, 1, 1]) != 100:
		push_error("Three second symbols must pay 10.0x.")
		quit(1)
		return
	if rules_script.get_payout_multiplier_tenths([2, 2, 2]) != 300:
		push_error("Three third symbols must pay 30.0x.")
		quit(1)
		return
	if rules_script.get_payout_multiplier_tenths([3, 3, 3]) != 1200:
		push_error("Three fourth symbols must pay 120.0x.")
		quit(1)
		return
	if rules_script.get_payout_multiplier_tenths([4, 4, 4]) != 5000:
		push_error("Three fifth symbols must pay 500.0x.")
		quit(1)
		return
	if rules_script.get_payout_multiplier_tenths([0, 0, 1]) != 1:
		push_error("Exactly two matching symbols must pay 0.1x.")
		quit(1)
		return
	if rules_script.get_payout_multiplier_tenths([0, 1, 2]) != 0:
		push_error("No matching symbols must pay zero.")
		quit(1)
		return
	if rules_script.get_payout_multiplier_tenths([0, 0]) != 0 or rules_script.get_payout_multiplier_tenths([0, 0, 5]) != 0:
		push_error("Malformed symbol results must be rejected.")
		quit(1)
		return
	var expected_return := rules_script.get_theoretical_return_ratio()
	if absf(expected_return - 0.9240836) > 0.000001:
		push_error("Theoretical return does not match the approved 92.40836% model.")
		quit(1)
		return
	print("Approved slot payout rules tests passed.")
	quit(0)
