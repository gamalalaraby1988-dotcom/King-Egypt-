extends RefCounted
## Deterministic placement policy for the smart city session allocator.
## This policy does not open connections or move players between servers by itself.
## A trusted matchmaking directory must supply the candidate session records.

const STATUS_ASSIGNED := "assigned"
const STATUS_PARTY_SESSION_UNAVAILABLE := "party_session_unavailable"
const STATUS_NO_CAPACITY := "no_capacity"


static func select_instance(
	candidates: Array,
	preferred_region: String,
	party_instance_id: String = "",
	party_size: int = 1
) -> Dictionary:
	if party_size < 1 or party_size > 64:
		return {"status": STATUS_NO_CAPACITY, "instance_id": ""}

	var eligible: Array[Dictionary] = []
	for candidate_variant in candidates:
		if not (candidate_variant is Dictionary):
			continue
		var candidate: Dictionary = candidate_variant
		var instance_id := str(candidate.get("instance_id", "")).strip_edges()
		var region := str(candidate.get("region", "")).strip_edges()
		var player_count_variant: Variant = candidate.get("player_count", -1)
		var capacity_variant: Variant = candidate.get("capacity", -1)
		if instance_id.is_empty() or region.is_empty():
			continue
		if not (player_count_variant is int) or not (capacity_variant is int):
			continue
		var player_count := int(player_count_variant)
		var capacity := int(capacity_variant)
		if player_count < 0 or capacity < 1 or capacity > 64 or player_count > capacity:
			continue
		if region != preferred_region or player_count + party_size > capacity:
			continue
		eligible.append({
			"instance_id": instance_id,
			"player_count": player_count,
			"capacity": capacity
		})

	if not party_instance_id.is_empty():
		for candidate in eligible:
			if str(candidate["instance_id"]) == party_instance_id:
				return {"status": STATUS_ASSIGNED, "instance_id": party_instance_id}
		return {"status": STATUS_PARTY_SESSION_UNAVAILABLE, "instance_id": ""}

	if eligible.is_empty():
		return {"status": STATUS_NO_CAPACITY, "instance_id": ""}

	# Compare occupancy ratios without floating-point rounding. Break ties by ID
	# so the same directory snapshot always produces the same assignment.
	eligible.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var left := int(a["player_count"]) * int(b["capacity"])
		var right := int(b["player_count"]) * int(a["capacity"])
		if left == right:
			return str(a["instance_id"]) < str(b["instance_id"])
		return left < right
	)
	return {"status": STATUS_ASSIGNED, "instance_id": str(eligible[0]["instance_id"])}
