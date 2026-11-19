extends Node
## Lightweight language service for world signage. Manual choice overrides device locale.

signal language_changed

const SAVE_PATH := "user://kings_city_profile.cfg"
var language_mode: String = "auto"

const TEXTS := {
	"ar": {
		"shop": "المتجر",
		"restaurant": "المطعم",
		"employment": "مركز التوظيف",
		"animal_camp": "مخيم الحيوانات",
		"desert_camp": "المخيم الصحراوي الملكي",
		"pyramids_camp": "الأهرامات وأبو الهول",
		"fuel_station": "محطة الوقود",
		"marina_terminal": "محطة المارينا",
		"royal_yacht_club": "نادي اليخوت",
		"desert_lodge": "نزل المخيم الصحراوي",
		"mountain_temple": "المعبد الملكي",
		"royal_ship": "السفينة الملكية",
		"beach_handball": "ملعب كرة اليد الشاطئي",
		"city_center": "وسط المدينة",
		"main_gate": "البوابة الملكية",
		"harbor": "الميناء",
		"city_guide": "مرشد المدينة",
		"delivery": "التوصيل",
		"maintenance": "الصيانة",
		"map_title": "خريطة المدينة",
		"map_destinations": "الوجهات",
		"hide_map": "إخفاء الخريطة",
		"show_map": "إظهار الخريطة",
		"map_buildings": "مبانٍ",
		"map_jobs": "وظائف",
		"map_staff": "موظفون",
		"region_city_center": "المنطقة المركزية",
		"region_animal_camp": "منطقة مخيم الحيوانات",
		"region_outskirts": "أطراف المدينة",
		"region_entered": "دخلت الآن:",
		"region_boundary": "حدود المناطق",
		"map_north": "شمال",
		"navigation_destination": "الوجهة:",
		"navigation_distance": "المتبقي",
		"navigation_arrived": "وصلت إلى:",
		"navigation_cancel": "إلغاء التوجيه",
		"navigation_recalculating": "خرجت عن المسار — جارٍ إعادة حساب الطريق...",
		"interaction_near": "أنت قريب من:",
		"interaction_press_hint": "اضغط الزر للتفاعل",
		"interaction_approach": "اقترب من مبنى أو لوحة وظيفة أو موظف للتفاعل",
		"interaction_button": "تفاعل",
		"interaction_enter": "دخول / تفاعل",
		"interaction_job": "تفاصيل الوظيفة",
		"interaction_rent": "استئجار حيوان",
		"interaction_shop": "فتح المتجر",
		"interaction_talk": "تحدث",
		"interaction_place": "مكان",
		"interaction_job_name": "وظيفة",
		"interaction_animal_staff": "موظف حيوانات المخيم",
		"interaction_riding_prompt": "أنت تركب أحد حيوانات المخيم",
		"interaction_dismount": "النزول من الحيوان",
		"interaction_dismounted": "نزلت من الحيوان. يمكنك العودة إلى موظف المخيم للركوب مرة أخرى.",
		"interior_title": "مدخل المبنى",
		"interior_pending": "هذا المبنى مخصص للدخول. تصميمه الداخلي ثلاثي الأبعاد لم يُجهّز بعد؛ لن يتم نقلك إلى غرفة غير موجودة.",
		"interior_no_rewards": "لا توجد مكافآت في شاشة المعاينة.",
		"interior_preview_status": "يمكنك الرجوع إلى الشارع أو متابعة أنشطة المبنى المتاحة حاليًا.",
		"interior_view_activities": "عرض أنشطة المبنى",
		"interior_return": "العودة إلى الشارع",
		"interior_activity_status": "هذه الأنشطة متاحة من خارج المبنى في النسخة الحالية.",
		"interior_loading": "جارٍ تجهيز المبنى...",
		"interior_return_loading": "جارٍ تحميل المدينة...",
		"interior_exit": "الخروج إلى المدينة",
		"interior_city_loading": "جارٍ تحميل المدينة والعودة إلى الشارع...",
		"interior_transition_unavailable": "تعذر بدء الانتقال إلى المبنى الآن. حاول مرة أخرى.",
		"interior_shop_staff": "صاحب المتجر",
		"interior_shop_role": "صاحب المحل",
		"interior_shop_dialogue": "أهلًا بك! اضغط للتسوق واختيار ما تحتاج إليه.",
		"interior_restaurant_staff": "موظف المطعم",
		"interior_restaurant_role": "موظف خدمة",
		"interior_restaurant_dialogue": "مرحبًا! يمكنني مساعدتك في طلبات المطعم وأنشطة التوصيل.",
		"interior_employment_staff": "مسؤول التوظيف",
		"interior_employment_role": "مستشار الوظائف",
		"interior_employment_dialogue": "أهلًا بك! راجع لوحة الوظائف لمعرفة الفرص المتاحة وشروطها.",
		"service_npc_no_rewards": "معلومات الموظف — لا توجد مكافأة لهذا الحوار.",
		"service_npc_dialogue_status": "يمكنك إغلاق هذه النافذة ومتابعة استكشاف المبنى.",
		"service_npc_close": "إغلاق"
	},
	"en": {
		"shop": "SHOP",
		"restaurant": "RESTAURANT",
		"employment": "JOB CENTER",
		"animal_camp": "ANIMAL CAMP",
		"desert_camp": "ROYAL DESERT CAMP",
		"pyramids_camp": "PYRAMIDS & SPHINX",
		"fuel_station": "FUEL STATION",
		"marina_terminal": "MARINA TERMINAL",
		"royal_yacht_club": "ROYAL YACHT CLUB",
		"desert_lodge": "DESERT LODGE",
		"mountain_temple": "ROYAL MOUNTAIN TEMPLE",
		"royal_ship": "ROYAL SHIP",
		"beach_handball": "BEACH HANDBALL",
		"city_center": "CITY CENTER",
		"main_gate": "ROYAL GATE",
		"harbor": "HARBOR",
		"city_guide": "CITY GUIDE",
		"delivery": "DELIVERY",
		"maintenance": "MAINTENANCE",
		"map_title": "CITY MAP",
		"map_destinations": "DESTINATIONS",
		"hide_map": "HIDE MAP",
		"show_map": "SHOW MAP",
		"map_buildings": "Buildings",
		"map_jobs": "Jobs",
		"map_staff": "Staff",
		"region_city_center": "CITY CENTER DISTRICT",
		"region_animal_camp": "ANIMAL CAMP AREA",
		"region_outskirts": "CITY OUTSKIRTS",
		"region_entered": "NOW ENTERING:",
		"region_boundary": "REGION BOUNDARIES",
		"map_north": "N",
		"navigation_destination": "DESTINATION:",
		"navigation_distance": "LEFT",
		"navigation_arrived": "ARRIVED AT:",
		"navigation_cancel": "CANCEL NAVIGATION",
		"navigation_recalculating": "OFF ROUTE — RECALCULATING...",
		"interaction_near": "NEARBY:",
		"interaction_press_hint": "Press the button to interact",
		"interaction_approach": "Approach a building, job board, or staff member to interact",
		"interaction_button": "INTERACT",
		"interaction_enter": "ENTER / INTERACT",
		"interaction_job": "JOB DETAILS",
		"interaction_rent": "RENT AN ANIMAL",
		"interaction_shop": "OPEN SHOP",
		"interaction_talk": "TALK",
		"interaction_place": "Place",
		"interaction_job_name": "Job",
		"interaction_animal_staff": "ANIMAL CAMP STAFF",
		"interaction_riding_prompt": "You are riding an animal",
		"interaction_dismount": "DISMOUNT",
		"interaction_dismounted": "You dismounted. Return to the camp staff to ride again.",
		"interior_title": "BUILDING ENTRANCE",
		"interior_pending": "This building is intended to be enterable. Its 3D interior is not ready yet; you will not be sent to a room that does not exist.",
		"interior_no_rewards": "No rewards are available in this preview.",
		"interior_preview_status": "Return to the street or view the building activities currently available.",
		"interior_view_activities": "VIEW BUILDING ACTIVITIES",
		"interior_return": "RETURN TO STREET",
		"interior_activity_status": "These activities are currently available from outside the building.",
		"interior_loading": "LOADING BUILDING...",
		"interior_return_loading": "RETURNING TO CITY...",
		"interior_exit": "RETURN TO CITY",
		"interior_city_loading": "LOADING CITY — RETURNING TO THE STREET...",
		"interior_transition_unavailable": "The building transition is unavailable right now. Please try again.",
		"interior_shop_staff": "SHOP OWNER",
		"interior_shop_role": "SHOPKEEPER",
		"interior_shop_dialogue": "Welcome! Interact with me to browse and choose what you need.",
		"interior_restaurant_staff": "RESTAURANT STAFF",
		"interior_restaurant_role": "SERVICE STAFF",
		"interior_restaurant_dialogue": "Hello! I can help with restaurant orders and delivery activities.",
		"interior_employment_staff": "EMPLOYMENT ADVISOR",
		"interior_employment_role": "CAREER ADVISOR",
		"interior_employment_dialogue": "Welcome! Check the job board for available opportunities and requirements.",
		"service_npc_no_rewards": "Staff information — this dialogue has no reward.",
		"service_npc_dialogue_status": "Close this window when you are ready to explore the building.",
		"service_npc_close": "CLOSE"
	}
}

func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		language_mode = str(config.get_value("settings", "language", "auto"))
	if not ["auto", "ar", "en"].has(language_mode):
		language_mode = "auto"

func get_language() -> String:
	if language_mode == "ar" or language_mode == "en":
		return language_mode
	return "ar" if OS.get_locale().to_lower().begins_with("ar") else "en"

func translate(key: String) -> String:
	var language := get_language()
	var dictionary: Dictionary = TEXTS.get(language, TEXTS["en"])
	return str(dictionary.get(key, key))

func set_language(mode: String) -> void:
	if not ["auto", "ar", "en"].has(mode):
		mode = "auto"
	if language_mode == mode:
		return
	var config := ConfigFile.new()
	var load_error := config.load(SAVE_PATH)
	if load_error != OK and FileAccess.file_exists(SAVE_PATH):
		push_warning("ملف إعدادات اللغة غير قابل للقراءة؛ لم يتم استبداله.")
		return
	config.set_value("settings", "language", mode)
	var save_error := config.save(SAVE_PATH)
	if save_error != OK:
		push_warning("تعذر حفظ إعداد اللغة: %s" % save_error)
		return
	language_mode = mode
	if is_instance_valid(PlayerSyncClient):
		PlayerSyncClient.enqueue_setting_change("locale", mode)
	language_changed.emit()
