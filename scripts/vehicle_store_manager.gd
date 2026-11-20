extends Node
const ProfileConfigStore = preload("res://scripts/profile_config_store.gd")

func _save_path() -> String:
	return ProfileConfigStore.get_active_profile_path()
## مرجع ملكية المركبات وعمليات شرائها. لا يمثل وجود هذا الكتالوج توافر مجسمات 3D لكل مركبة.
const DEFAULT_OWNED := ["pharaonic_scooter", "toyota_corolla", "hyundai_elantra", "byd_qin_plus"]
const VEHICLES := {
	"pharaonic_scooter": {"name": "السكوتر الفرعوني", "country": "مصر", "currency": "money", "price": 0},
	"toyota_corolla": {"name": "Toyota Corolla", "country": "اليابان", "currency": "money", "price": 0},
	"hyundai_elantra": {"name": "Hyundai Elantra", "country": "كوريا الجنوبية", "currency": "money", "price": 0},
	"byd_qin_plus": {"name": "BYD Qin Plus", "country": "الصين", "currency": "money", "price": 0},
	"mercedes_e_class": {"name": "Mercedes-Benz E-Class", "country": "ألمانيا", "currency": "money", "price": -1},
	"cadillac_ct5": {"name": "Cadillac CT5", "country": "الولايات المتحدة", "currency": "money", "price": -1},
	"rolls_royce_phantom": {"name": "Rolls-Royce Phantom", "country": "بريطانيا", "currency": "gems", "price": -1},
	"lamborghini_revuelto": {"name": "Lamborghini Revuelto", "country": "إيطاليا", "currency": "gems", "price": -1},
	"bugatti_chiron": {"name": "Bugatti Chiron", "country": "فرنسا", "currency": "gems", "price": -1},
	"cadillac_celestiq": {"name": "Cadillac Celestiq", "country": "الولايات المتحدة", "currency": "gems", "price": -1},
	"hongqi_guoli": {"name": "Hongqi Guoli", "country": "الصين", "currency": "gems", "price": -1},
	"fiat_500": {"name": "Fiat 500", "country": "إيطاليا", "currency": "money", "price": -1},
	"mini_cooper_s": {"name": "MINI Cooper S", "country": "بريطانيا", "currency": "gems", "price": -1},
	"horus_2030": {"name": "Horus 2030", "country": "مصر", "currency": "gems", "price": 500}
}
const HORUS_COLORS := {
	"obsidian_gold": {"name": "الأسود الملكي", "price": 200},
	"royal_sapphire": {"name": "الأزرق الفرعوني", "price": 300},
	"pharaoh_pearl": {"name": "الأبيض الملكي", "price": 400},
	"golden_horus": {"name": "الذهب الخالص", "price": 600}
}
var selected_vehicle_id := "toyota_corolla"

func get_catalog() -> Dictionary:
	return VEHICLES.duplicate(true)

func get_vehicle(vehicle_id: String) -> Dictionary:
	return VEHICLES.get(vehicle_id, {}).duplicate(true)

func get_owned_vehicles() -> Array:
	var config := ConfigFile.new()
	if config.load(_save_path()) != OK:
		return DEFAULT_OWNED.duplicate()
	var stored: Variant = config.get_value("profile", "owned_vehicles", DEFAULT_OWNED)
	var result: Array = DEFAULT_OWNED.duplicate()
	if stored is Array:
		for vehicle_id in stored:
			if VEHICLES.has(str(vehicle_id)) and not result.has(str(vehicle_id)):
				result.append(str(vehicle_id))
	return result

func has_vehicle(vehicle_id: String) -> bool:
	return VEHICLES.has(vehicle_id) and get_owned_vehicles().has(vehicle_id)

func get_selected_vehicle_id() -> String:
	var config := ConfigFile.new()
	if config.load(_save_path()) == OK:
		var stored := str(config.get_value("profile", "selected_vehicle_id", "toyota_corolla"))
		if has_vehicle(stored):
			selected_vehicle_id = stored
	return selected_vehicle_id if has_vehicle(selected_vehicle_id) else "toyota_corolla"

func select_vehicle(vehicle_id: String) -> bool:
	if not has_vehicle(vehicle_id):
		return false
	var config := ConfigFile.new()
	var err := config.load(_save_path())
	if err != OK and FileAccess.file_exists(_save_path()):
		return false
	config.set_value("profile", "selected_vehicle_id", vehicle_id)
	if not WalletManager.save_profile_update(config, WalletManager.get_balance("money"), WalletManager.get_balance("chips")):
		return false
	selected_vehicle_id = vehicle_id
	return true

func purchase_vehicle(vehicle_id: String) -> bool:
	if not VEHICLES.has(vehicle_id) or has_vehicle(vehicle_id):
		return false
	var offer: Dictionary = VEHICLES[vehicle_id]
	var price := int(offer.get("price", -1))
	var currency := str(offer.get("currency", ""))
	if price < 0 or not ["money", "chips", "gems"].has(currency):
		return false # السعر غير معتمد بعد؛ لا تخمين ولا شراء.
	var next_owned := get_owned_vehicles()
	next_owned.append(vehicle_id)
	var tx_id := "vehicle_purchase_" + vehicle_id
	if not WalletManager.purchase_once(tx_id, currency, price, "Vehicle purchase: " + vehicle_id, {"owned_vehicles": next_owned}):
		return false
	return true

func get_horus_colors() -> Dictionary:
	return HORUS_COLORS.duplicate(true)

func get_owned_horus_colors() -> Array:
	var config := ConfigFile.new()
	if config.load(_save_path()) != OK:
		return []
	var stored: Variant = config.get_value("profile", "owned_horus_colors", [])
	return stored.duplicate() if stored is Array else []

func purchase_horus_color(color_id: String) -> bool:
	if not HORUS_COLORS.has(color_id) or not has_vehicle("horus_2030"):
		return false
	var owned := get_owned_horus_colors()
	if owned.has(color_id):
		return select_horus_color(color_id)
	var next_owned := owned.duplicate()
	next_owned.append(color_id)
	var price := int(HORUS_COLORS[color_id].price)
	var tx_id := "horus_color_" + color_id
	return WalletManager.purchase_once(tx_id, "gems", price, "Horus 2030 color: " + color_id, {
		"owned_horus_colors": next_owned,
		"selected_horus_color": color_id
	})

func select_horus_color(color_id: String) -> bool:
	if not HORUS_COLORS.has(color_id) or not get_owned_horus_colors().has(color_id) or not has_vehicle("horus_2030"):
		return false
	var config := ConfigFile.new()
	var err := config.load(_save_path())
	if err != OK:
		return false
	config.set_value("profile", "selected_horus_color", color_id)
	return WalletManager.save_profile_update(config, WalletManager.get_balance("money"), WalletManager.get_balance("chips"))
