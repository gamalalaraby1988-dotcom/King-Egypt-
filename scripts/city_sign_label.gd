extends Label3D
## A small reusable 3D label that follows the selected game/device language.

@export var translation_key: String = "city_center"
@export var prefix: String = ""

func _ready() -> void:
	font_size = 48
	pixel_size = 0.006
	outline_size = 10
	modulate = Color(1.0, 0.91, 0.68)
	billboard = BaseMaterial3D.BILLBOARD_DISABLED
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Explicit bidi direction prevents Arabic glyph order from being inferred incorrectly on 3D signs.
	text_direction = TextServer.DIRECTION_RTL if CityLanguage.get_language() == "ar" else TextServer.DIRECTION_LTR
	# Keep translated sign text aligned with the physical board instead of facing the camera independently.
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	CityLanguage.language_changed.connect(_refresh_text)
	_refresh_text()

func _exit_tree() -> void:
	if CityLanguage.language_changed.is_connected(_refresh_text):
		CityLanguage.language_changed.disconnect(_refresh_text)

func _refresh_text() -> void:
	var language := CityLanguage.get_language()
	text_direction = TextServer.DIRECTION_RTL if language == "ar" else TextServer.DIRECTION_LTR
	text = prefix + CityLanguage.translate(translation_key)
