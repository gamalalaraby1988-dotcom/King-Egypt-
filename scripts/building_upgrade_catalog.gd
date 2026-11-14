extends RefCounted
## كتالوج المباني القابلة للتطوير في KING OF EGYPT CITY.
## هذا الملف يعرّف المحتوى والهيكل فقط؛ لا يحدد أسعارًا أو يخصم عملة.

const LEVELS: Array[Dictionary] = [
	{"level": 1, "name": "ناشئ"},
	{"level": 2, "name": "متطور"},
	{"level": 3, "name": "متقدم"},
	{"level": 4, "name": "متميز"},
	{"level": 5, "name": "ملكي متكامل"}
]

const STAFF_GRADES: Array[Dictionary] = [
	{"grade": 1, "name": "مبتدئ"},
	{"grade": 2, "name": "مؤهل"},
	{"grade": 3, "name": "محترف"},
	{"grade": 4, "name": "خبير"},
	{"grade": 5, "name": "متميز"}
]

const STAFF_SLOTS_BY_LEVEL: Array[int] = [2, 3, 4, 5, 6]

const BUILDINGS: Array[Dictionary] = [
	{"id":"royal_hotel","name":"الفندق الملكي","roles":["موظف استقبال","موظف خدمة غرف","عامل نظافة","موظف حجوزات"]},
	{"id":"pharaonic_museum","name":"المتحف الفرعوني","roles":["مرشد متحف","موظف استقبال","مسؤول معروضات","موظف تذاكر"]},
	{"id":"royal_restaurant","name":"المطعم الملكي","roles":["طاهٍ","مساعد طاهٍ","مقدم طعام","موظف استقبال"]},
	{"id":"shopping_center","name":"مركز التسوق","roles":["موظف مبيعات","موظف خدمة عملاء","أمين مخزن","مشرف نظافة"]},
	{"id":"royal_bank","name":"البنك الملكي","roles":["موظف خدمة عملاء","صراف","موظف حسابات","مسؤول أمن"]},
	{"id":"hospital","name":"المستشفى","roles":["طبيب","ممرض","موظف استقبال","فني مختبر"]},
	{"id":"car_showroom","name":"معرض السيارات","roles":["مستشار مبيعات","موظف استقبال","فني فحص","موظف تسليم"]},
	{"id":"cinema","name":"السينما","roles":["موظف تذاكر","مشغل عرض","موظف ضيافة","مشرف قاعة"]},
	{"id":"sports_club","name":"النادي الرياضي","roles":["مدرب","موظف استقبال","مشرف صالة","مسؤول معدات"]},
	{"id":"supermarket","name":"السوبر ماركت","roles":["أمين صندوق","موظف أرفف","أمين مخزن","خدمة عملاء"]},
	{"id":"royal_police","name":"مركز الشرطة الملكي","roles":["ضابط استقبال بلاغات","ضابط دورية","محقق","مسؤول سجلات"]},
	{"id":"fire_rescue","name":"مركز الإطفاء والإنقاذ","roles":["رجل إطفاء","مسعف إنقاذ","سائق مركبة طوارئ","مسؤول معدات"]},
	{"id":"royal_university","name":"الجامعة الملكية","roles":["أستاذ","محاضر","موظف شؤون طلاب","أمين مكتبة"]},
	{"id":"royal_library","name":"المكتبة الملكية","roles":["أمين مكتبة","موظف إعارة","باحث","موظف استقبال"]},
	{"id":"royal_theater","name":"المسرح الملكي","roles":["ممثل","فني إضاءة","فني صوت","منظم عروض"]},
	{"id":"royal_event_hall","name":"قاعة الاحتفالات الملكية","roles":["منظم حفلات","موظف استقبال","فني صوت وإضاءة","موظف ضيافة"]},
	{"id":"royal_cafe","name":"الكافيه الملكي","roles":["باريستا","مقدم طلبات","موظف استقبال","عامل نظافة"]},
	{"id":"royal_bakery","name":"المخبز الملكي","roles":["خباز","مساعد خباز","موظف مبيعات","مسؤول تجهيز"]},
	{"id":"royal_factory","name":"المصنع الملكي","roles":["مشغل إنتاج","فني صيانة","مراقب جودة","أمين مخزن"]},
	{"id":"car_service_center","name":"مركز صيانة السيارات","roles":["ميكانيكي","فني كهرباء سيارات","فني إطارات","موظف استقبال"]},
	{"id":"royal_fuel_station","name":"محطة الوقود الملكية","roles":["موظف محطة","فني صيانة","أمين صندوق","مشرف سلامة"]},
	{"id":"train_station","name":"محطة القطار","roles":["موظف تذاكر","موظف أرصفة","مراقب حركة","موظف خدمة ركاب"]},
	{"id":"royal_marina","name":"المرسى الملكي","roles":["موظف رصيف","مرشد رحلات","فني قوارب","موظف استقبال"]},
	{"id":"tourism_center","name":"مركز السياحة","roles":["مرشد سياحي","موظف حجوزات","موظف استقبال","منظم رحلات"]},
	{"id":"royal_jewelry","name":"متجر المجوهرات الملكي","roles":["صائغ","مستشار مبيعات","خبير أحجار","مسؤول أمن"]},
	{"id":"electronics_store","name":"متجر الإلكترونيات","roles":["مستشار أجهزة","فني إلكترونيات","موظف مبيعات","موظف مخزن"]},
	{"id":"fashion_store","name":"متجر الأزياء","roles":["مستشار أزياء","موظف مبيعات","منسق عرض","أمين مخزن"]},
	{"id":"royal_aquarium","name":"الأكواريوم الملكي","roles":["أخصائي أحياء مائية","معتني أحواض","مرشد زوار","فني أنظمة مياه"]},
	{"id":"royal_zoo","name":"حديقة الحيوانات الملكية","roles":["طبيب بيطري","معتني حيوانات","مرشد زوار","مسؤول تغذية"]},
	{"id":"water_park","name":"المدينة المائية","roles":["منقذ سباحة","موظف استقبال","فني صيانة مياه","مشرف ألعاب"]}
]

static func get_buildings() -> Array[Dictionary]:
	return BUILDINGS.duplicate(true)

static func get_building(building_id: String) -> Dictionary:
	for building in BUILDINGS:
		if str(building.get("id", "")) == building_id:
			return building.duplicate(true)
	return {}

static func get_level_data(level: int) -> Dictionary:
	if level < 1 or level > LEVELS.size():
		return {}
	return LEVELS[level - 1].duplicate(true)

static func get_staff_slots(level: int) -> int:
	if level < 1 or level > STAFF_SLOTS_BY_LEVEL.size():
		return 0
	return STAFF_SLOTS_BY_LEVEL[level - 1]

static func get_staff_grades() -> Array[Dictionary]:
	return STAFF_GRADES.duplicate(true)

static func is_valid_building(building_id: String) -> bool:
	return not get_building(building_id).is_empty()
