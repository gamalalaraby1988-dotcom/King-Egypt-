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
		var copied_weights: Array = machine_rules["symbol_weights_bps"]
		copied_weights[0] = 1
		var fresh_rules: Dictionary = rules_script.get_machine_rules(machine_id)
		if int(fresh_rules["symbol_weights_bps"][0]) != 4000:
			push_error("Per-machine rules must return independent configuration copies.")
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
	if rules_script.get_gross_return_chips(19, 1) != 1 or rules_script.get_gross_return_chips(29, 1) != 2:
		push_error("Fractional 0.1x chip returns must round down to whole chips.")
		quit(1)
		return
	if rules_script.get_gross_return_chips(10, 0) != 0 or rules_script.get_gross_return_chips(9, 1) != 0:
		push_error("Zero returns and below-minimum wagers must not create chip payouts.")
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
	# Collection bonuses count eligible machine-specific symbols anywhere in one 3x3 result.
	var royal_three := rules_script.get_collection_result("vip_royal_classic", [0, 1, 2, 3, 0, 1, 2, 3, 4])
	if not bool(royal_three.valid) or int(royal_three.match_count) != 3 or int(royal_three.activity_multiplier) != 10:
		push_error("Three Royal Classic scarabs in any positions must award 10x activity.")
		quit(1)
		return
	var diamond_five := rules_script.get_collection_result("vip_diamond_royale", [3, 0, 1, 2, 4, 3, 0, 3, 4])
	if int(diamond_five.match_count) != 3 or int(diamond_five.activity_multiplier) != 10:
		push_error("Diamond collection must count only its own collectible symbol identity.")
		quit(1)
		return
	var golden_nine := rules_script.get_collection_result("vip_golden_crown", [4, 4, 4, 4, 4, 4, 4, 4, 4])
	if int(golden_nine.match_count) != 9 or int(golden_nine.activity_multiplier) != 100:
		push_error("Nine matching Golden Crown collectibles must award 100x activity.")
		quit(1)
		return
	var four_matches := rules_script.get_collection_result("vip_royal_classic", [0, 0, 1, 2, 4, 3, 0, 1, 2])
	if int(four_matches.activity_multiplier) != 15:
		push_error("Four matching collection symbols must award 15x activity.")
		quit(1)
		return
	var five_matches := rules_script.get_collection_result("vip_royal_classic", [0, 0, 0, 0, 0, 1, 2, 3, 1])
	if int(five_matches.activity_multiplier) != 20:
		push_error("Five matching collection symbols must award 20x activity.")
		quit(1)
		return
	var six_matches := rules_script.get_collection_result("vip_royal_classic", [0, 0, 0, 0, 0, 0, 2, 3, 1])
	var seven_matches := rules_script.get_collection_result("vip_royal_classic", [4, 4, 4, 4, 4, 4, 4, 0, 1])
	var eight_matches := rules_script.get_collection_result("vip_royal_classic", [4, 4, 4, 4, 4, 4, 4, 4, 1])
	if int(six_matches.activity_multiplier) != 30 or int(seven_matches.activity_multiplier) != 40 or int(eight_matches.activity_multiplier) != 50:
		push_error("Six, seven, and eight matches must award 30x, 40x, and 50x activity.")
		quit(1)
		return
	var split_matches := rules_script.get_collection_result("vip_royal_classic", [0, 0, 0, 4, 4, 4, 1, 2, 3])
	if int(split_matches.activity_multiplier) != 10:
		push_error("Separate collectible groups must not stack; only the highest single group applies.")
		quit(1)
		return
	var no_collection := rules_script.get_collection_result("vip_royal_classic", [1, 1, 1, 2, 2, 2, 3, 3, 3])
	if int(no_collection.activity_multiplier) != 0:
		push_error("Non-collectible symbols must not award a collection multiplier.")
		quit(1)
		return
	var malformed_collection := rules_script.get_collection_result("vip_royal_classic", [0, 0, 0, 0, 0, 0, 0, 0, 5])
	if bool(malformed_collection.valid):
		push_error("Out-of-range collection symbols must be rejected.")
		quit(1)
		return
	var short_collection := rules_script.get_collection_result("vip_royal_classic", [0, 0, 0])
	if bool(short_collection.valid):
		push_error("Collection results must contain exactly nine cells.")
		quit(1)
		return
	var unknown_machine_collection := rules_script.get_collection_result("unknown_machine", [0, 0, 0, 0, 0, 0, 0, 0, 0])
	if bool(unknown_machine_collection.valid):
		push_error("Unknown machines must not receive collection rules.")
		quit(1)
		return
	var expected_return := rules_script.get_theoretical_return_ratio()
	if absf(expected_return - 0.9240836) > 0.000001:
		push_error("Theoretical return does not match the approved 92.40836% model.")
		quit(1)
		return
	print("Approved slot payout rules tests passed.")
	quit(0)
