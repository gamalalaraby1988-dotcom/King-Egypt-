extends RefCounted
class_name CityMasterPlan
## المرجع الرسمي الوحيد لتوزيع مباني KING OF EGYPT CITY.
## لا تُضاف مبانٍ مرئية خارج BUILDINGS؛ المعالم الطبيعية والطرق والساحات مدرجة منفصلة.
## الكازينو وVIP جناحان داخل القصر الملكي وليسا مبنيين مستقلين.
## المباني المستقلة الأربعة الملغاة لا تعود إلى BUILDINGS؛ دخول الشقة يتم من قائمة النقل السريع المعتمدة.

const BUILDINGS := [
	{"id":"royal_palace","name":"القصر الملكي","district":"المنطقة الملكية","role":"قاعة العرش والاحتفالات والكازينو الأوروبي وصالة VIP والحديقة الداخلية"},
	{"id":"royal_bank","name":"البنك الملكي","district":"المنطقة الملكية","role":"الخدمات المالية داخل المدينة"},

	{"id":"supermarket","name":"السوبر ماركت","district":"المنطقة التجارية","role":"الاحتياجات اليومية"},
	{"id":"market","name":"السوق التجاري","district":"المنطقة التجارية","role":"المحال والأكشاك التجارية"},
	{"id":"employment_center","name":"مركز التوظيف","district":"المنطقة التجارية","role":"الوظائف والتسجيل"},
	{"id":"main_restaurant","name":"المطعم الرئيسي","district":"المنطقة التجارية","role":"المطعم والطلبات"},
	{"id":"royal_cafe","name":"المقهى الملكي","district":"المنطقة التجارية","role":"المقهى والجلوس والتفاعل الاجتماعي"},
	{"id":"commercial_services","name":"مركز الخدمات التجارية","district":"المنطقة التجارية","role":"الخدمات المساندة للمتاجر"},

	{"id":"apartment_palace_1","name":"قصر الشقق الأول","district":"المنطقة السكنية","role":"شقق مستقلة للاعبين"},
	{"id":"apartment_palace_2","name":"قصر الشقق الثاني","district":"المنطقة السكنية","role":"شقق مستقلة للاعبين"},
	{"id":"apartment_palace_3","name":"قصر الشقق الثالث","district":"المنطقة السكنية","role":"شقق مستقلة للاعبين"},
	{"id":"apartment_palace_4","name":"قصر الشقق الرابع","district":"المنطقة السكنية","role":"شقق مستقلة للاعبين"},

	{"id":"cinema","name":"السينما","district":"المنطقة الترفيهية","role":"العروض السينمائية"},
	{"id":"royal_theater","name":"المسرح الملكي","district":"المنطقة الترفيهية","role":"العروض والفعاليات"},
	{"id":"stadium","name":"الملعب الرياضي","district":"المنطقة الترفيهية","role":"الأنشطة والمنافسات الرياضية"},
	{"id":"sports_club","name":"النادي الرياضي","district":"المنطقة الترفيهية","role":"الرياضة واللياقة"},
	{"id":"water_city","name":"المدينة المائية","district":"المنطقة الترفيهية","role":"الأنشطة المائية"},
	{"id":"daily_arcade","name":"مركز DAILY ARCADE","district":"المنطقة الترفيهية","role":"الفعاليات اليومية والماكينات"},

	{"id":"police_station","name":"مركز الشرطة","district":"منطقة الخدمات","role":"الأمن والخدمات الشرطية"},
	{"id":"courthouse","name":"المحكمة","district":"منطقة الخدمات","role":"الخدمات القضائية"},
	{"id":"fire_rescue","name":"مركز الإطفاء والإنقاذ","district":"منطقة الخدمات","role":"الطوارئ والإنقاذ"},
	{"id":"train_station","name":"محطة القطار","district":"منطقة الخدمات","role":"النقل العام"},
	{"id":"fuel_station","name":"محطة الوقود","district":"منطقة الخدمات","role":"خدمة المركبات"},

	{"id":"marina_terminal","name":"محطة المارينا البحرية","district":"منطقة الميناء والنيل","role":"خدمات الميناء والرحلات البحرية"},
	{"id":"royal_yacht_club","name":"نادي اليخوت الملكي","district":"منطقة الميناء والنيل","role":"اليخوت والأنشطة البحرية"},

	{"id":"adventure_center","name":"مركز المغامرات","district":"منطقة المغامرات والجبل","role":"الأنشطة والمغامرات"},
	{"id":"desert_lodge","name":"نزل المخيم الصحراوي الملكي","district":"منطقة المغامرات والجبل","role":"الإقامة والأنشطة الصحراوية"},
	{"id":"mountain_temple","name":"المعبد الملكي أعلى الجبل","district":"منطقة المغامرات والجبل","role":"معلم وموقع استكشاف"}
]


const PALACE_INTERIORS := [
	{"id":"throne_hall","name":"قاعة العرش الملكية"},
	{"id":"celebration_hall","name":"قاعة الاحتفالات"},
	{"id":"european_vip_casino","name":"الكازينو الأوروبي"},
	{"id":"vip_lounge","name":"صالة VIP"},
	{"id":"royal_indoor_garden","name":"الحديقة الملكية الداخلية"}
]

const LANDMARKS := [
	"الأهرامات",
	"أبو الهول",
	"البوابة الملكية",
	"الميدان الملكي",
	"الحدائق والساحات العامة",
	"مارينا النيل",
	"الممشى البحري",
	"مرسى اليخوت",
	"السفينة الملكية",
	"سفينة الحضارات الخمس",
	"طريق الجبل",
	"استراحتا طريق الجبل",
	"منصات المشاهدة",
	"قمة الملوك",
	"المخيم الصحراوي",
	"الطرق الرئيسية والفرعية",
	"مواقف السيارات والجراجات"
]

const CANCELLED_FEATURES := ["المنتجع الملكي"]

static func get_building_count() -> int:
	return BUILDINGS.size()

static func get_building_by_id(building_id: String) -> Dictionary:
	for building in BUILDINGS:
		if str(building.get("id", "")) == building_id:
			return building
	return {}

static func is_approved_building(building_id: String) -> bool:
	return not get_building_by_id(building_id).is_empty()
