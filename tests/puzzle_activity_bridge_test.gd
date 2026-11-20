extends SceneTree

func _initialize() -> void:
	var failures: Array[String] = []
	var server := FileAccess.get_file_as_string("res://scripts/authoritative_game_server.gd")
	var mission := FileAccess.get_file_as_string("res://scripts/mission_manager.gd")
	var issuer := FileAccess.get_file_as_string("res://supabase/functions/game-puzzle-piece-issuer/index.ts")
	var required_ids := [
		"parcel_shipping",
		"postal_mail",
		"pizza_delivery",
		"pharmacy_orders",
		"flowers_gifts",
		"home_orders",
		"luggage_delivery"
	]
	var retired_ids := ["courier_" + "delivery", "city_" + "guide", "city_" + "maintenance"]
	for retired_id in retired_ids:
		if server.contains(retired_id) or mission.contains(retired_id) or issuer.contains(retired_id):
			failures.append("Retired job identifier returned in puzzle bridge: " + retired_id)
	for approved_id in required_ids:
		if not server.contains(approved_id):
			failures.append("Dedicated server puzzle map is missing approved job: " + approved_id)
		if not mission.contains(approved_id):
			failures.append("Mission manager puzzle allowlist is missing approved job: " + approved_id)
		if not issuer.contains(approved_id):
			failures.append("Edge Function allowlist is missing approved job: " + approved_id)
	if not server.contains("_issue_puzzle_piece_proof"):
		failures.append("Dedicated server puzzle proof issuer hook is missing.")
	if not mission.contains("claim_verified_puzzle_piece"):
		failures.append("Mission manager verified puzzle claim hook is missing.")
	if not issuer.contains("issue_server_puzzle_piece_proof"):
		failures.append("Edge Function database proof RPC is missing.")
	if failures.is_empty():
		print("Puzzle activity bridge tests passed: approved seven-job allowlist and retired-job exclusion.")
		quit(0)
	for failure in failures:
		push_error(failure)
	quit(1)
