extends Node
## خدمة محفظة محلية موحدة. الخادم الموثوق مطلوب لحماية اقتصاد اللعب الجماعي.

const PROFILE_PATH := "user://kings_city_profile.cfg"
const ProfileConfigStore = preload("res://scripts/profile_config_store.gd")
const TEMP_PATH := "user://kings_city_profile.wallet.tmp"
const BACKUP_PATH := "user://kings_city_profile.pre_wallet_backup.cfg"
const SCHEMA_VERSION := 2
const MAX_BALANCE := 2000000000
const CURRENCIES := ["money", "chips", "gems"]

var balances: Dictionary = {"money": 0, "chips": 0, "gems": 0}
var receipts: Dictionary = {}
var ledger: Array = []
var initialized := false
var integrity_seal := ""
var integrity_warning := false

func _ready() -> void:
	initialize_wallet()

func initialize_wallet() -> bool:
	var config := ConfigFile.new()
	var err := config.load(PROFILE_PATH)
	if err != OK and FileAccess.file_exists(PROFILE_PATH):
		push_error("Wallet: profile file is unreadable; wallet initialization stopped.")
		return false

	var stored_version := int(config.get_value("wallet", "schema_version", 0)) if err == OK else 0
	var stored_balances: Variant = config.get_value("wallet", "balances", null) if err == OK else null
	var stored_receipts: Variant = config.get_value("wallet", "receipts", {}) if err == OK else {}
	var stored_ledger: Variant = config.get_value("wallet", "ledger", []) if err == OK else []

	if stored_version >= 1 and stored_version <= SCHEMA_VERSION and stored_balances is Dictionary:
		for currency in CURRENCIES:
			var value: Variant = stored_balances.get(currency, 0)
			if not _valid_amount(value):
				push_error("Wallet: invalid saved balance; wallet initialization stopped.")
				return false
			balances[currency] = int(value)
		if not (stored_receipts is Dictionary) or not (stored_ledger is Array):
			push_error("Wallet: invalid receipt or ledger data; wallet locked.")
			return false
		receipts = stored_receipts
		ledger = stored_ledger
		var profile_money: Variant = config.get_value("profile", "money", balances["money"])
		var profile_chips: Variant = config.get_value("profile", "chips", balances["chips"])
		if not _valid_amount(profile_money) or not _valid_amount(profile_chips) or int(profile_money) != int(balances["money"]) or int(profile_chips) != int(balances["chips"]):
			integrity_warning = true
			push_error("Wallet: profile and wallet balances differ; currency operations locked.")
			return false
		var saved_seal := str(config.get_value("wallet", "integrity_seal", ""))
		var expected_seal := _compute_integrity_seal(balances, receipts, ledger)
		if not saved_seal.is_empty() and saved_seal != expected_seal:
			integrity_warning = true
			push_error("Wallet: integrity check failed; currency operations locked.")
			return false
		integrity_seal = expected_seal
		if saved_seal.is_empty():
			return _persist_wallet(config)
		initialized = true
		return true

	# One-time migration: carry forward existing money/chips exactly; gems start at zero.
	var legacy_money: Variant = config.get_value("profile", "money", 0) if err == OK else 0
	var legacy_chips: Variant = config.get_value("profile", "chips", 0) if err == OK else 0
	if not _valid_amount(legacy_money) or not _valid_amount(legacy_chips):
		push_error("Wallet: legacy balances invalid; migration stopped to protect player data.")
		return false
	balances = {"money": int(legacy_money), "chips": int(legacy_chips), "gems": 0}
	receipts = {}
	ledger = [{
		"transaction_id": "wallet_migration_v1",
		"kind": "migration",
		"money": int(legacy_money),
		"chips": int(legacy_chips),
		"gems": 0,
		"timestamp": Time.get_datetime_string_from_system(true)
	}]
	return _persist_wallet(config)

func get_balance(currency: String) -> int:
	if not initialized or not CURRENCIES.has(currency):
		return 0
	_refresh_legacy_balances()
	return int(balances[currency])

func get_balances() -> Dictionary:
	if initialized:
		_refresh_legacy_balances()
	return balances.duplicate(true)

func _refresh_legacy_balances() -> void:
	# المحفظة الموثقة هي المرجع؛ لا تقبل تغييرات ملف الملف الشخصي كأرصدة جديدة.
	return

func save_profile_update(config: ConfigFile, money_value: int, chips_value: int) -> bool:
	# في Online لا نكتب اقتصادًا محليًا؛ لا يوجد اعتماد خادمي موصول بعد.
	if _online_economy_locked():
		return false
	# حفظ بيانات اللاعب وتغيير أرصدته وسجل المحفظة في الملف الذري نفسه.
	if not initialized or not _valid_amount(money_value) or not _valid_amount(chips_value):
		return false
	var next_balances := balances.duplicate(true)
	var next_ledger := ledger.duplicate(true)
	var timestamp := Time.get_datetime_string_from_system(true)
	for currency in ["money", "chips"]:
		var target := money_value if currency == "money" else chips_value
		var previous := int(next_balances[currency])
		if previous == target:
			continue
		next_ledger.append({
			"transaction_id": "profile_update_%s_%s" % [currency, str(Time.get_ticks_usec())],
			"kind": "profile_update",
			"currency": currency,
			"amount": absi(target - previous),
			"balance_before": previous,
			"balance_after": target,
			"reason": "Saved through the existing player progression flow",
			"timestamp": timestamp
		})
		next_balances[currency] = target
	config.set_value("profile", "money", money_value)
	config.set_value("profile", "chips", chips_value)
	config.set_value("wallet", "schema_version", SCHEMA_VERSION)
	config.set_value("wallet", "balances", next_balances)
	config.set_value("wallet", "receipts", receipts)
	config.set_value("wallet", "ledger", next_ledger)
	config.set_value("wallet", "integrity_seal", _compute_integrity_seal(next_balances, receipts, next_ledger))
	if not _atomic_save(config):
		return false
	balances = next_balances
	ledger = next_ledger
	return true

func get_recent_transactions(limit: int = 5) -> Array:
	var result: Array = []
	var count := mini(maxi(limit, 0), 20)
	for index in range(ledger.size() - 1, maxi(ledger.size() - count - 1, -1), -1):
		result.append(ledger[index].duplicate(true))
	return result

func has_transaction(transaction_id: String) -> bool:
	return receipts.has(transaction_id)

func purchase_once(transaction_id: String, currency: String, amount: int, reason: String, profile_updates: Dictionary = {}) -> bool:
	# يطبق الخصم محليًا فقط؛ Online ينتظر عملية شراء مؤكدة من الخادم.
	if _online_economy_locked():
		return false
	# يطبق الخصم وتحديث الملكية/الإيصال في الملف نفسه؛ لا توجد ملكية دون خصم ناجح.
	if not initialized or transaction_id.strip_edges().is_empty() or not CURRENCIES.has(currency):
		return false
	if amount < 0 or amount > MAX_BALANCE or receipts.has(transaction_id):
		return false
	var config := ConfigFile.new()
	if config.load(PROFILE_PATH) != OK:
		return false
	_refresh_legacy_balances()
	var current := int(balances[currency])
	if current < amount:
		return false
	var next_value := current - amount
	var next_balances := balances.duplicate(true)
	next_balances[currency] = next_value
	var next_receipts := receipts.duplicate(true)
	var timestamp := Time.get_datetime_string_from_system(true)
	next_receipts[transaction_id] = timestamp
	var next_ledger := ledger.duplicate(true)
	next_ledger.append({
		"transaction_id": transaction_id,
		"kind": "purchase",
		"currency": currency,
		"amount": amount,
		"balance_before": current,
		"balance_after": next_value,
		"reason": reason.substr(0, 120),
		"timestamp": timestamp
	})
	for key in profile_updates:
		config.set_value("profile", str(key), profile_updates[key])
	if currency == "money" or currency == "chips":
		config.set_value("profile", currency, next_value)
	config.set_value("wallet", "schema_version", SCHEMA_VERSION)
	config.set_value("wallet", "balances", next_balances)
	config.set_value("wallet", "receipts", next_receipts)
	config.set_value("wallet", "ledger", next_ledger)
	config.set_value("wallet", "integrity_seal", _compute_integrity_seal(next_balances, next_receipts, next_ledger))
	if not _atomic_save(config):
		return false
	balances = next_balances
	receipts = next_receipts
	ledger = next_ledger
	return true

func credit(transaction_id: String, currency: String, amount: int, reason: String = "") -> bool:
	return _transact(transaction_id, currency, amount, "credit", reason)

func debit(transaction_id: String, currency: String, amount: int, reason: String = "") -> bool:
	return _transact(transaction_id, currency, amount, "debit", reason)

func _transact(transaction_id: String, currency: String, amount: int, kind: String, reason: String) -> bool:
	if _online_economy_locked():
		return false
	if not initialized or transaction_id.strip_edges().is_empty() or not CURRENCIES.has(currency):
		return false
	if amount <= 0 or amount > MAX_BALANCE or receipts.has(transaction_id):
		return false
	var config := ConfigFile.new()
	if config.load(PROFILE_PATH) != OK:
		return false
	_refresh_legacy_balances()
	var current := int(balances[currency])
	if kind == "debit" and current < amount:
		return false
	var next_value := current + amount if kind == "credit" else current - amount
	if next_value < 0 or next_value > MAX_BALANCE:
		return false

	var next_balances := balances.duplicate(true)
	next_balances[currency] = next_value
	var next_receipts := receipts.duplicate(true)
	var timestamp := Time.get_datetime_string_from_system(true)
	next_receipts[transaction_id] = timestamp
	var next_ledger := ledger.duplicate(true)
	next_ledger.append({
		"transaction_id": transaction_id,
		"kind": kind,
		"currency": currency,
		"amount": amount,
		"balance_before": current,
		"balance_after": next_value,
		"reason": reason.substr(0, 120),
		"timestamp": timestamp
	})
	if currency == "money" or currency == "chips":
		config.set_value("profile", currency, next_value)
	config.set_value("wallet", "schema_version", SCHEMA_VERSION)
	config.set_value("wallet", "balances", next_balances)
	config.set_value("wallet", "receipts", next_receipts)
	config.set_value("wallet", "ledger", next_ledger)
	config.set_value("wallet", "integrity_seal", _compute_integrity_seal(next_balances, next_receipts, next_ledger))
	if not _atomic_save(config):
		return false
	balances = next_balances
	receipts = next_receipts
	ledger = next_ledger
	return true


func credit_bundle_once(transaction_id: String, money_amount: int, chips_amount: int, reason: String = "") -> bool:
	# إيداع مكافأتي الكاش والرقائق معًا في معاملة محفظة ذرية واحدة.
	if _online_economy_locked():
		return false
	if not initialized or transaction_id.strip_edges().is_empty() or receipts.has(transaction_id):
		return false
	if money_amount < 0 or chips_amount < 0 or money_amount > MAX_BALANCE or chips_amount > MAX_BALANCE:
		return false
	if money_amount == 0 and chips_amount == 0:
		return true
	var config := ConfigFile.new()
	if config.load(PROFILE_PATH) != OK:
		return false
	var next_balances := balances.duplicate(true)
	var next_receipts := receipts.duplicate(true)
	var next_ledger := ledger.duplicate(true)
	var timestamp := Time.get_datetime_string_from_system(true)
	for currency in ["money", "chips"]:
		var amount := money_amount if currency == "money" else chips_amount
		if amount == 0:
			continue
		var previous := int(next_balances[currency])
		if previous + amount > MAX_BALANCE:
			return false
		next_balances[currency] = previous + amount
		next_ledger.append({
			"transaction_id": transaction_id,
			"kind": "milestone_reward",
			"currency": currency,
			"amount": amount,
			"balance_before": previous,
			"balance_after": previous + amount,
			"reason": reason.substr(0, 120),
			"timestamp": timestamp
		})
	next_receipts[transaction_id] = timestamp
	config.set_value("profile", "money", int(next_balances["money"]))
	config.set_value("profile", "chips", int(next_balances["chips"]))
	config.set_value("wallet", "schema_version", SCHEMA_VERSION)
	config.set_value("wallet", "balances", next_balances)
	config.set_value("wallet", "receipts", next_receipts)
	config.set_value("wallet", "ledger", next_ledger)
	config.set_value("wallet", "integrity_seal", _compute_integrity_seal(next_balances, next_receipts, next_ledger))
	if not _atomic_save(config):
		return false
	balances = next_balances
	receipts = next_receipts
	ledger = next_ledger
	return true

func _persist_wallet(config: ConfigFile) -> bool:
	config.set_value("wallet", "schema_version", SCHEMA_VERSION)
	integrity_seal = _compute_integrity_seal(balances, receipts, ledger)
	config.set_value("wallet", "integrity_seal", integrity_seal)
	config.set_value("wallet", "balances", balances)
	config.set_value("wallet", "receipts", receipts)
	config.set_value("wallet", "ledger", ledger)
	if not _atomic_save(config):
		return false
	initialized = true
	return true

func _atomic_save(config: ConfigFile) -> bool:
	return ProfileConfigStore.save_config_snapshot(config, PROFILE_PATH, TEMP_PATH, BACKUP_PATH)

func _valid_amount(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0.0 and float(value) <= float(MAX_BALANCE) and floorf(float(value)) == float(value)


func _compute_integrity_seal(balance_data: Dictionary, receipt_data: Dictionary, ledger_data: Array) -> String:
	# كشف العبث البسيط بالملفات؛ ليس توقيعًا خادميًا ولا يمنع تعديل التطبيق نفسه.
	var payload := {"balances": balance_data, "receipts": receipt_data, "ledger": ledger_data}
	var canonical := JSON.stringify(payload, "", true, true)
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	context.update(canonical.to_utf8_buffer())
	return context.finish().hex_encode()


func _online_economy_locked() -> bool:
	# ENet يثبت الاتصال فقط، ولا يثبت صلاحية المعاملات أو وجود اقتصاد خادمي موثوق.
	var scene_tree := Engine.get_main_loop() as SceneTree
	if not is_instance_valid(scene_tree) or not is_instance_valid(scene_tree.root):
		return false
	var mode_manager := scene_tree.root.get_node_or_null("GameModeManager")
	return is_instance_valid(mode_manager) and mode_manager.has_method("is_online_ready") and mode_manager.is_online_ready()
