extends RefCounted
## Approved slot math only. This file does not roll outcomes, debit chips, or enable client play.
## A trusted server controller must consume these rules after server-side RNG and wallet authority exist.

const MACHINE_IDS := [
	"vip_royal_classic",
	"vip_diamond_royale",
	"vip_golden_crown"
]
const REEL_COUNT := 3
const SYMBOL_COUNT := 5
const TOTAL_WEIGHT_BPS := 10000
const SYMBOL_WEIGHTS_BPS := [4000, 3000, 1800, 900, 300]
## Multipliers are stored in tenths: 50 = 5.0x, 5000 = 500.0x.
const TRIPLE_PAYOUT_TENTHS := [50, 100, 300, 1200, 5000]
## Exactly two matching symbols return 0.1x the stake.
const PAIR_PAYOUT_TENTHS := 1
const MIN_BET_CHIPS := 10


static func is_configuration_valid() -> bool:
	if REEL_COUNT != 3 or SYMBOL_COUNT != 5:
		return false
	if SYMBOL_WEIGHTS_BPS.size() != SYMBOL_COUNT or TRIPLE_PAYOUT_TENTHS.size() != SYMBOL_COUNT:
		return false
	var total_weight := 0
	for index in range(SYMBOL_COUNT):
		var weight := int(SYMBOL_WEIGHTS_BPS[index])
		var payout := int(TRIPLE_PAYOUT_TENTHS[index])
		if weight <= 0 or payout <= 0:
			return false
		total_weight += weight
	return total_weight == TOTAL_WEIGHT_BPS and PAIR_PAYOUT_TENTHS == 1 and MIN_BET_CHIPS == 10


static func get_machine_rules(machine_id: String) -> Dictionary:
	if not MACHINE_IDS.has(machine_id) or not is_configuration_valid():
		return {}
	return {
		"machine_id": machine_id,
		"reel_count": REEL_COUNT,
		"symbol_count": SYMBOL_COUNT,
		"symbol_weights_bps": SYMBOL_WEIGHTS_BPS.duplicate(),
		"triple_payout_tenths": TRIPLE_PAYOUT_TENTHS.duplicate(),
		"pair_payout_tenths": PAIR_PAYOUT_TENTHS,
		"minimum_bet_chips": MIN_BET_CHIPS
	}


static func get_payout_multiplier_tenths(symbol_indices: Array) -> int:
	if symbol_indices.size() != REEL_COUNT:
		return 0
	var counts: Dictionary = {}
	for symbol_variant in symbol_indices:
		if not (symbol_variant is int) or int(symbol_variant) < 0 or int(symbol_variant) >= SYMBOL_COUNT:
			return 0
		var symbol_index := int(symbol_variant)
		counts[symbol_index] = int(counts.get(symbol_index, 0)) + 1
	for symbol_index_variant in counts.keys():
		var count := int(counts[symbol_index_variant])
		if count == REEL_COUNT:
			return int(TRIPLE_PAYOUT_TENTHS[int(symbol_index_variant)])
	for count_variant in counts.values():
		if int(count_variant) == 2:
			return PAIR_PAYOUT_TENTHS
	return 0


static func get_theoretical_return_ratio() -> float:
	if not is_configuration_valid():
		return 0.0
	var total_outcome_weight := pow(float(TOTAL_WEIGHT_BPS), float(REEL_COUNT))
	var weighted_return := 0.0
	for index in range(SYMBOL_COUNT):
		var weight := float(SYMBOL_WEIGHTS_BPS[index])
		var triple_weight := pow(weight, 3.0)
		weighted_return += triple_weight * float(TRIPLE_PAYOUT_TENTHS[index]) / 10.0
		var exactly_two_weight := 3.0 * weight * weight * (float(TOTAL_WEIGHT_BPS) - weight)
		weighted_return += exactly_two_weight * float(PAIR_PAYOUT_TENTHS) / 10.0
	return weighted_return / total_outcome_weight
