extends Label3D
## A small reusable 3D label that follows the selected game/device language.

@export var translation_key: String = "city_center"
@export var prefix: String = ""

func _ready() -> void:
	font_size = 48
	pixel_size = 0.006
	outline_size = 10
	modulate = Color(1.0, 0.91, 0.68)
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	shadow_casting_setting = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	CityLanguage.language_changed.connect(_refresh_text)
	_refresh_text()

func _exit_tree() -> void:
	if CityLanguage.language_changed.is_connected(_refresh_text):
		CityLanguage.language_changed.disconnect(_refresh_text)

func _refresh_text() -> void:
	text = prefix + CityLanguage.translate(translation_key)
