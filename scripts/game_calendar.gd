extends Node
## مصدر موحد لتاريخ اللعبة؛ يطابق توقيت مصر المستخدم في جدول الوظائف.

const EGYPT_UTC_OFFSET_SECONDS := 7200
const MONTHLY_SEASON_DURATION_SECONDS := 30 * 24 * 60 * 60

static func egypt_day_key_for_unix_time(unix_timestamp: int) -> String:
	var date := Time.get_datetime_dict_from_unix_time(unix_timestamp + EGYPT_UTC_OFFSET_SECONDS)
	return "%04d-%02d-%02d" % [int(date.year), int(date.month), int(date.day)]

## يحسب نهاية موسم بازل مدته 30 يومًا بالضبط من وقت بداية صادر عن الخادم (UTC).
## لا يحدد بداية الموسم؛ يجب أن تأتي من سجل الموسم الخادمي.
static func monthly_season_end_unix(start_unix: int) -> int:
	if start_unix <= 0:
		return 0
	return start_unix + MONTHLY_SEASON_DURATION_SECONDS

## يعيد رقم يوم الموسم من 0 إلى 29، أو -1 إذا كان خارج الموسم/المدخل غير صالح.
## current_unix يجب أن يكون وقت الخادم، وليس ساعة جهاز اللاعب.
static func monthly_season_day_index(start_unix: int, current_unix: int) -> int:
	var end_unix := monthly_season_end_unix(start_unix)
	if end_unix == 0 or current_unix < start_unix or current_unix >= end_unix:
		return -1
	return int((current_unix - start_unix) / 86400)

func get_egypt_datetime() -> Dictionary:
	return Time.get_datetime_dict_from_unix_time(int(Time.get_unix_time_from_system()) + EGYPT_UTC_OFFSET_SECONDS)

func get_egypt_day_key() -> String:
	return egypt_day_key_for_unix_time(int(Time.get_unix_time_from_system()))
