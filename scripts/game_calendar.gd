extends Node
## مصدر موحد لتاريخ اللعبة؛ يطابق توقيت مصر المستخدم في جدول الوظائف.

const EGYPT_UTC_OFFSET_SECONDS := 7200

static func egypt_day_key_for_unix_time(unix_timestamp: int) -> String:
	var date := Time.get_datetime_dict_from_unix_time(unix_timestamp + EGYPT_UTC_OFFSET_SECONDS)
	return "%04d-%02d-%02d" % [int(date.year), int(date.month), int(date.day)]

func get_egypt_datetime() -> Dictionary:
	return Time.get_datetime_dict_from_unix_time(int(Time.get_unix_time_from_system()) + EGYPT_UTC_OFFSET_SECONDS)

func get_egypt_day_key() -> String:
	return egypt_day_key_for_unix_time(int(Time.get_unix_time_from_system()))
