extends Node
## خدمة محفظة محلية موحدة. الخادم الموثوق مطلوب لحماية اقتصاد اللعب الجماعي.

const PROFILE_PATH := "user://kings_city_profile.cfg"
const TEMP_PATH := "user://kings_city_profile.wallet.tmp"
const BACKUP_PATH := "user://kings_city_profile.pre_wallet_backup.cfg"
const SCHEMA_VERSION := 1
const MAX_BALANCE := 2000000000
const CURRENCIES := ["money", "chips", "gems"]

var balances: Dictionary = {"money": 0, "chips": 0, "gems": 0}
var receipts: Dictionary = {}
var ledger: Array = []
var initialized := false
var integrity_blocked := false

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

	if stored_version == SCHEMA_VERSION and stored_balances is Dictionary:
		for currency in CURRENCIES:
			var value: Variant = stored_balances.get(currency, null)
			if not _valid_amount(value):
				push_error("Wallet: invalid saved balance; wallet initialization stopped.")
				return false
			balances[currency] = int(value)
		# لا تختَر بين profile وwallet عند التعارض؛ أوقف التهيئة للمراجعة.
		for currency in ["money", "chips"]:
			var legacy_value: Variant = config.get_value("profile", currency, null)
			if not _valid_amount(legacy_value) or int(legacy_value) != int(balances[currency]):
				push_error("Wallet: profile/%s conflicts with wallet balance; initialization stopped for manual review." % currency)
				return false
		receipts = stored_receipts if stored_receipts is Dictionary else {}
		ledger = stored_ledger if stored_ledger is Array else []
		initialized = true
		return true

	# لا تعِد تفسير مخطط محفظة موجود أو إصدار غير معروف على أنه ملف قديم.
	if stored_version != 0 or stored_balances != null:
		push_error("Wallet: unsupported or incomplete wallet schema; migration stopped to protect saved data.")
		return false

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
	if not initialized or integrity_blocked or not CURRENCIES.has(currency):
		return 0
	if not _refresh_legacy_balances():
		return 0
	return int(balances[currency])

func get_balances() -> Dictionary:
	if not initialized or integrity_blocked:
		return {}
	if not _refresh_legacy_balances():
		return {}
	return balances.duplicate(true)

func _refresh_legacy_balances() -> bool:
	# الحقلان القديمان يجب أن يطابقا المحفظة تمامًا؛ لا تتم مزامنتهما باختيار أحدهما.
	var config := ConfigFile.new()
	if config.load(PROFILE_PATH) != OK:
		integrity_blocked = true
		initialized = false
		push_error("Wallet: profile file is missing or unreadable; economic operations are blocked.")
		return false
	for currency in ["money", "chips"]:
		var value: Variant = config.get_value("profile", currency, null)
		if not _valid_amount(value) or int(value) != int(balances[currency]):
			integrity_blocked = true
			initialized = false
			push_error("Wallet: profile/%s differs from wallet; economic operations are blocked for manual review." % currency)
			return false
	return true

func save_profile_update(config: ConfigFile, money_value: int, chips_value: int) -> bool:
	# حفظ بيانات اللاعب وتغيير أرصدته وسجل المحفظة في الملف الذري نفسه.
	if not initialized or integrity_blocked or not _valid_amount(money_value) or not _valid_amount(chips_value):
		return false
	if not _refresh_legacy_balances():
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
	if not _atomic_save(config):
		return false
	balances = next_balances
	ledger = next_ledger
	return true

func save_profile_metadata(config: ConfigFile) -> bool:
	# حفظ الإعدادات والتقدم غير الاقتصادي عبر نفس مسار الحفظ الذري للمحفظة.
	if not initialized or integrity_blocked or not _refresh_legacy_balances():
		return false
	var money_value: Variant = config.get_value("profile", "money", null)
	var chips_value: Variant = config.get_value("profile", "chips", null)
	if not _valid_amount(money_value) or not _valid_amount(chips_value):
		return false
	if int(money_value) != int(balances["money"]) or int(chips_value) != int(balances["chips"]):
		push_warning("Wallet: metadata save rejected a balance change outside a wallet transaction.")
		return false
	config.set_value("wallet", "schema_version", SCHEMA_VERSION)
	config.set_value("wallet", "balances", balances)
	config.set_value("wallet", "receipts", receipts)
	config.set_value("wallet", "ledger", ledger)
	return _atomic_save(config)

func get_recent_transactions(limit: int = 5) -> Array:
	var result: Array = []
	var count := mini(maxi(limit, 0), 20)
	for index in range(ledger.size() - 1, maxi(ledger.size() - count - 1, -1), -1):
		result.append(ledger[index].duplicate(true))
	return result

func has_transaction(transaction_id: String) -> bool:
	return receipts.has(transaction_id)

func purchase_once(transaction_id: String, currency: String, amount: int, reason: String, profile_updates: Dictionary = {}) -> bool:
	# يطبق الخصم وتحديث الملكية/الإيصال في الملف نفسه؛ لا توجد ملكية دون خصم ناجح.
	if not initialized or integrity_blocked or transaction_id.strip_edges().is_empty() or not CURRENCIES.has(currency):
		return false
	if not _refresh_legacy_balances():
		return false
	if amount < 0 or amount > MAX_BALANCE or receipts.has(transaction_id):
		return false
	var config := ConfigFile.new()
	if config.load(PROFILE_PATH) != OK:
		return false
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
	if not initialized or integrity_blocked or transaction_id.strip_edges().is_empty() or not CURRENCIES.has(currency):
		return false
	if not _refresh_legacy_balances():
		return false
	if amount <= 0 or amount > MAX_BALANCE or receipts.has(transaction_id):
		return false
	var config := ConfigFile.new()
	if config.load(PROFILE_PATH) != OK:
		return false
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
	if not _atomic_save(config):
		return false
	balances = next_balances
	receipts = next_receipts
	ledger = next_ledger
	return true

func _persist_wallet(config: ConfigFile) -> bool:
	# اكتب حقلي التوافق القديمين عند إنشاء ملف محفظة جديد/ترحيل قديم.
	# بدون ذلك سيعتبر فحص الاتساق القيم المفقودة تعارضًا ويوقف أول حفظ للاعب جديد.
	config.set_value("profile", "money", int(balances["money"]))
	config.set_value("profile", "chips", int(balances["chips"]))
	config.set_value("wallet", "schema_version", SCHEMA_VERSION)
	config.set_value("wallet", "balances", balances)
	config.set_value("wallet", "receipts", receipts)
	config.set_value("wallet", "ledger", ledger)
	if not _atomic_save(config):
		return false
	initialized = true
	return true

func _atomic_save(config: ConfigFile) -> bool:
	if config.save(TEMP_PATH) != OK:
		return false
	var original_exists := FileAccess.file_exists(PROFILE_PATH)
	if original_exists and not FileAccess.file_exists(BACKUP_PATH):
		if DirAccess.copy_absolute(ProjectSettings.globalize_path(PROFILE_PATH), ProjectSettings.globalize_path(BACKUP_PATH)) != OK:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_PATH))
			return false
	var original_path := ProjectSettings.globalize_path(PROFILE_PATH)
	var temp_path := ProjectSettings.globalize_path(TEMP_PATH)
	var backup_path := ProjectSettings.globalize_path(BACKUP_PATH)
	if original_exists:
		var rotate_error := DirAccess.rename_absolute(original_path, backup_path + ".pending")
		if rotate_error != OK:
			DirAccess.remove_absolute(temp_path)
			return false
		var install_error := DirAccess.rename_absolute(temp_path, original_path)
		if install_error != OK:
			DirAccess.rename_absolute(backup_path + ".pending", original_path)
			return false
		DirAccess.remove_absolute(backup_path + ".pending")
	else:
		if DirAccess.rename_absolute(temp_path, original_path) != OK:
			DirAccess.remove_absolute(temp_path)
			return false
	return true

func _valid_amount(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0.0 and float(value) <= float(MAX_BALANCE) and floorf(float(value)) == float(value)
