class_name CityJobsCatalog
extends RefCounted
## Approved delivery professions. Coordinates reuse existing city buildings and the open fuel station.

const FUEL_STATION := Vector3(-75.0, 0.15, 38.0)
const JOBS := {
	"parcel_shipping": {
		"title": "توصيل الشحنات",
		"description": "استلم الشحنات من مكتب الوظائف، وسلّم 3 طرود في المدينة، ثم عُد بالسيارة إلى محطة الوقود.",
		"cargo": "طرد شحن",
		"stops": [Vector3(-23.0, 0.15, -23.5), Vector3(6.5, 0.15, 6.4), Vector3(66.5, 0.15, -23.5)]
	},
	"postal_mail": {
		"title": "توصيل البريد",
		"description": "وزّع 3 رسائل بريدية على وجهاتها، ثم عُد بالسيارة إلى محطة الوقود.",
		"cargo": "حقيبة بريد",
		"stops": [Vector3(36.5, 0.15, -23.5), Vector3(81.5, 0.15, 20.9), Vector3(66.5, 0.15, 6.4)]
	},
	"pizza_delivery": {
		"title": "توصيل البيتزا",
		"description": "استلم طلبات البيتزا وسلّم 4 طلبات، ثم عُد بالسيارة إلى محطة الوقود.",
		"cargo": "علبة بيتزا",
		"stops": [Vector3(66.5, 0.15, -23.5), Vector3(-53.5, 0.15, 6.4), Vector3(6.5, 0.15, 6.4), Vector3(-23.0, 0.15, -23.5)]
	},
	"pharmacy_orders": {
		"title": "توصيل طلبات الصيدلية",
		"description": "سلّم 3 طلبات صيدلية إلى وجهاتها، ثم عُد بالسيارة إلى محطة الوقود.",
		"cargo": "كيس صيدلية",
		"stops": [Vector3(66.5, 0.15, 6.4), Vector3(-53.5, 0.15, 36.4), Vector3(36.5, 0.15, 36.4)]
	},
	"flowers_gifts": {
		"title": "توصيل الزهور والهدايا",
		"description": "سلّم 3 باقات وهدايا بعناية، ثم عُد بالسيارة إلى محطة الوقود.",
		"cargo": "باقة أو هدية",
		"stops": [Vector3(-53.5, 0.15, 6.4), Vector3(6.5, 0.15, 6.4), Vector3(-53.5, 0.15, 36.4)]
	},
	"home_orders": {
		"title": "توصيل طلبات المنازل",
		"description": "سلّم 4 طلبات إلى وجهات سكنية في المدينة، ثم عُد بالسيارة إلى محطة الوقود.",
		"cargo": "طلب منزلي",
		"stops": [Vector3(-53.5, 0.15, 36.4), Vector3(-53.5, 0.15, 66.4), Vector3(-23.5, 0.15, 66.4), Vector3(6.5, 0.15, 66.4)]
	},
	"luggage_delivery": {
		"title": "توصيل الأمتعة والحقائب",
		"description": "انقل 3 حقائب بين نقاط السفر والخدمات، ثم عُد بالسيارة إلى محطة الوقود.",
		"cargo": "حقيبة سفر",
		"stops": [Vector3(81.5, 0.15, 20.9), Vector3(81.5, 0.15, 43.4), Vector3(66.5, 0.15, 6.4)]
	}
}

static func get_job_ids() -> Array[String]:
	var ids: Array[String] = []
	for key in JOBS.keys():
		ids.append(str(key))
	return ids

static func get_job(job_id: String) -> Dictionary:
	var value: Variant = JOBS.get(job_id, {})
	return value.duplicate(true) if value is Dictionary else {}

static func is_approved_job(job_id: String) -> bool:
	return JOBS.has(job_id)
