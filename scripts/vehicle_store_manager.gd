extends Node
## مرجع ملكية المركبات وعمليات شرائها. لا يمثل وجود هذا الكتالوج توافر مجسمات 3D لكل مركبة.
const SAVE_PATH := "user://kings_city_profile.cfg"
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
	"horus_2030": {"name": "Horus 2030", "country": "مصر", "currency": "gems", "price": -1}
}
const HORUS_COLORS := {
	"obsidian_gold": {"name": "الأسود الملكي", "price": -1},
	"royal_sapphire": {"name": "الأزرق الفرعوني", "price": -1},
	"pharaoh_pearl": {"name": "الأبيض الملكي", "price": -1},
	"golden_horus": {"name": "الذهب الخالص", "price": -1}
}
var selected_vehicle_id := "toyota_corolla"

func get_catalog() -> Dictionary:
	return VEHICLES.duplicate(true)

func get_vehicle(vehicle_id: String) -> Dictionary:
	return VEHICLES.get(vehicle_id, {}).duplicate(true)

func get_owned_vehicles() -> Array:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
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
	if config.load(SAVE_PATH) == OK:
		var stored := str(config.get_value("profile", "selected_vehicle_id", "toyota_corolla"))
		if has_vehicle(stored):
			selected_vehicle_id = stored
	return selected_vehicle_id if has_vehicle(selected_vehicle_id) else "toyota_corolla"

func select_vehicle(vehicle_id: String) -> bool:
	if not has_vehicle(vehicle_id):
		return false
	var config := ConfigFile.new()
	var err := config.load(SAVE_PATH)
	if err != OK and FileAccess.file_exists(SAVE_PATH):
		return false
	config.set_value("profile", "selected_vehicle_id", vehicle_id)
	if not WalletManager.save_profile_update(config, WalletManager.get_balance("money"), WalletManager.get_balance("chips")):
		return false
	selected_vehicle_id = vehicle_id
	return true

func purchase_vehicle(_vehicle_id: String) -> bool:
	# الشراء غير متاح قبل اكتمال الاقتصاد الموحد واعتماده واختباره.
	return false

func get_horus_colors() -> Dictionary:
	return HORUS_COLORS.duplicate(true)

func get_owned_horus_colors() -> Array:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return []
	var stored: Variant = config.get_value("profile", "owned_horus_colors", [])
	return stored.duplicate() if stored is Array else []

func purchase_horus_color(_color_id: String) -> bool:
	# لا تُفعّل أسعار أو خصومات ألوان قبل اعتماد الاقتصاد الموحد.
	return false

func select_horus_color(color_id: String) -> bool:
	if not HORUS_COLORS.has(color_id) or not get_owned_horus_colors().has(color_id) or not has_vehicle("horus_2030"):
		return false
	var config := ConfigFile.new()
	var err := config.load(SAVE_PATH)
	if err != OK:
		return false
	config.set_value("profile", "selected_horus_color", color_id)
	return WalletManager.save_profile_update(config, WalletManager.get_balance("money"), WalletManager.get_balance("chips"))
