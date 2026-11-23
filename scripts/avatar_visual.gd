extends Node3D
## المرحلة 11: ملامح وجه وشعر أولية، مع نقاط تركيب لأصول الملابس والشعر النهائية.
## جميع الأشكال الحالية Placeholder هندسية وليست نماذج فنية أو Rig نهائيًا.

const SKIN := Color("#c98f68")
const HAIR := Color("#241b18")
const EYE_WHITE := Color("#f4eee4")
const EYE_DARK := Color("#29211e")
const OUTFIT_SCENES := {
	"men_formal": "res://assets/outfits/men_formal.tscn",
	"women_formal": "res://assets/outfits/women_formal.tscn",
	"urban_casual": "res://assets/outfits/urban_casual.tscn",
	"sport": "res://assets/outfits/sport.tscn"
}
const HAIR_SCENES := {
	"short": "res://assets/hairstyles/short.tscn",
	"long": "res://assets/hairstyles/long.tscn",
	"curly": "res://assets/hairstyles/curly.tscn"
}

var parts: Dictionary = {}
var current_outfit := "default"
var current_hairstyle := "short"
var outfit_mount: Node3D
var hair_mount: Node3D
var motion_state := "idle"
var motion_speed := 0.0
var motion_time := 0.0
var animated_defaults: Dictionary = {}
var phone_using := false
var phone_visual: Node3D
var phone_screen_viewport: SubViewport
var phone_screen_content: VBoxContainer
signal phone_app_pressed(app_id: String)

func _ready() -> void:
	_build_base_character()
	_build_face()
	_build_hair_placeholders()
	apply_outfit(current_outfit)
	apply_hairstyle(current_hairstyle)
	_cache_animation_defaults()
	_build_phone_visual()

func set_motion_state(state: String, speed: float = 0.0) -> void:
	motion_state = state if ["idle", "walk", "run", "sit", "talk", "wave", "celebrate", "disappointed", "clap", "dance", "cry", "heart"].has(state) else "idle"
	motion_speed = maxf(speed, 0.0)


func set_phone_using(enabled: bool) -> void:
	phone_using = enabled
	if is_instance_valid(phone_visual):
		phone_visual.visible = enabled


func _build_phone_visual() -> void:
	# الهاتف مثبت في اليد اليمنى نفسها، وليس عائمًا في موضع مستقل من الجسم.
	var right_arm := parts.get("RightArm") as MeshInstance3D
	if not is_instance_valid(right_arm):
		return
	phone_visual = Node3D.new()
	phone_visual.name = "PlayerPhoneVisual"
	# إزاحة معكوسة لدوران الذراع: تنقل الهاتف من مستوى الكتف إلى مركز الصدر.
	# دوران الذراع حول Z يرفع الإحداثي المحلي الموجب Y نحو الكتف؛ لذلك نستخدم Y سالبًا.
	phone_visual.position = Vector3(-0.36, -0.13, -0.27)
	phone_visual.rotation = Vector3(-0.08, 0.10, 0.42)
	phone_visual.visible = false
	right_arm.add_child(phone_visual)
	# حافظ على مركز الهاتف عند أمام أسفل الوجه حتى مع دوران الذراع حول مفصل الكتف.
	phone_visual.global_position = to_global(Vector3(0.0, 1.43, -0.27))
	_orient_phone_screen_to_head()
	var body := MeshInstance3D.new()
	body.name = "PhoneBody"
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(0.13, 0.22, 0.025)
	body.mesh = body_mesh
	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = Color("#171a20")
	body_material.metallic = 0.48
	body_material.roughness = 0.32
	body.material_override = body_material
	phone_visual.add_child(body)
	# كف اليد خلف الهاتف والإبهام على الحافة، لإظهار مسكة طبيعية.
	var palm := MeshInstance3D.new()
	palm.name = "RightHandPalm"
	var palm_mesh := SphereMesh.new()
	palm_mesh.radius = 1.0
	palm_mesh.height = 2.0
	palm.mesh = palm_mesh
	palm.scale = Vector3(0.078, 0.092, 0.052)
	# راحة اليد خلف الهاتف، على الجهة البعيدة عن وجه الشخصية.
	palm.position = Vector3(0.0, -0.005, -0.043)
	palm.material_override = _material(SKIN)
	phone_visual.add_child(palm)
	var thumb := MeshInstance3D.new()
	thumb.name = "RightHandThumb"
	var thumb_mesh := CapsuleMesh.new()
	thumb_mesh.radius = 0.018
	thumb_mesh.height = 0.075
	thumb.mesh = thumb_mesh
	thumb.position = Vector3(-0.066, -0.005, 0.031)
	thumb.rotation.z = -0.35
	thumb.material_override = _material(SKIN)
	phone_visual.add_child(thumb)
	# أصابع ملتفة فوق الحافة الأمامية لتظهر قبضة واضحة بدل هاتف عائم.
	for finger_index in range(3):
		var finger := MeshInstance3D.new()
		finger.name = "RightHandFinger_%d" % finger_index
		var finger_mesh := CapsuleMesh.new()
		finger_mesh.radius = 0.012
		finger_mesh.height = 0.064
		finger.mesh = finger_mesh
		finger.position = Vector3(0.061, -0.067 + float(finger_index) * 0.062, 0.031)
		finger.rotation.z = 0.16
		finger.material_override = _material(SKIN)
		phone_visual.add_child(finger)
	var screen := MeshInstance3D.new()
	screen.name = "PhoneScreen"
	var screen_mesh := BoxMesh.new()
	screen_mesh.size = Vector3(0.112, 0.192, 0.003)
	screen.mesh = screen_mesh
	# الشاشة على جهة +Z لتواجه وجه الشخصية الموجود أمام الهاتف.
	screen.position.z = 0.014
	phone_visual.add_child(screen)

	# شاشة فعلية داخل المجسم: تعرض نفس بيانات قائمة الهاتف التي ترسلها واجهة المدينة.
	phone_screen_viewport = SubViewport.new()
	phone_screen_viewport.name = "PhoneScreenViewport"
	phone_screen_viewport.size = Vector2i(256, 448)
	phone_screen_viewport.transparent_bg = false
	phone_screen_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var screen_root := PanelContainer.new()
	screen_root.name = "PhoneScreenRoot"
	screen_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen_root.add_theme_stylebox_override("panel", _make_phone_screen_style())
	phone_screen_viewport.add_child(screen_root)
	phone_screen_content = VBoxContainer.new()
	phone_screen_content.add_theme_constant_override("separation", 8)
	screen_root.add_child(phone_screen_content)
	var screen_material := StandardMaterial3D.new()
	screen_material.albedo_texture = phone_screen_viewport.get_texture()
	screen_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	screen_material.emission_enabled = true
	screen_material.emission_energy_multiplier = 0.8
	screen.material_override = screen_material
	phone_visual.add_child(phone_screen_viewport)
	var phone_screen_area := Area3D.new()
	phone_screen_area.name = "PhoneScreenTouchArea"
	phone_screen_area.input_ray_pickable = true
	phone_screen_area.position.z = 0.016
	var touch_shape := CollisionShape3D.new()
	var touch_box := BoxShape3D.new()
	touch_box.size = Vector3(0.112, 0.192, 0.008)
	touch_shape.shape = touch_box
	phone_screen_area.add_child(touch_shape)
	phone_visual.add_child(phone_screen_area)
	phone_screen_area.input_event.connect(_on_phone_screen_input_event)
	set_phone_screen_content("هاتف اللاعب", ["الأصدقاء", "المحادثات", "المركبات", "الحيوانات الأليفة"])


func _make_phone_screen_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#101a25")
	style.border_color = Color("#c6a45b")
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	return style


func set_phone_screen_content(title: String, entries: Array[String]) -> void:
	# التوافق مع النداءات القديمة: شاشة الجهاز تعرض رموز التطبيقات فقط دون نصوص.
	set_phone_screen_icons(["🚘", "👥", "⚙️", "🏠", "🗺️", "💬", "📋", "🎁", "👤"])


func set_phone_screen_icons(icons: Array[String]) -> void:
	if not is_instance_valid(phone_screen_content):
		return
	for child in phone_screen_content.get_children():
		child.queue_free()
	var icon_grid := GridContainer.new()
	icon_grid.name = "PhoneAppIconGrid"
	icon_grid.columns = 3
	icon_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icon_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	icon_grid.add_theme_constant_override("h_separation", 7)
	icon_grid.add_theme_constant_override("v_separation", 9)
	phone_screen_content.add_child(icon_grid)
	var app_ids := ["garage", "friends", "settings", "safe_return", "map", "messages", "missions", "rewards", "profile"]
	for index in range(icons.size()):
		var glyph: String = icons[index]
		var app_id: String = app_ids[index] if index < app_ids.size() else ""
		var icon_button := Button.new()
		icon_button.text = glyph
		icon_button.tooltip_text = app_id
		icon_button.pressed.connect(_emit_phone_app_pressed.bind(app_id))
		icon_button.custom_minimum_size = Vector2(58, 66)
		icon_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		icon_button.add_theme_font_size_override("font_size", 29)
		icon_button.add_theme_color_override("font_color", Color("#f5e6c5"))
		icon_button.add_theme_stylebox_override("normal", _make_phone_icon_style())
		icon_button.add_theme_stylebox_override("hover", _make_phone_icon_style())
		icon_button.add_theme_stylebox_override("pressed", _make_phone_icon_style())
		icon_button.focus_mode = Control.FOCUS_NONE
		icon_grid.add_child(icon_button)


func _emit_phone_app_pressed(app_id: String) -> void:
	if not app_id.is_empty():
		phone_app_pressed.emit(app_id)


func _on_phone_screen_input_event(_camera: Camera3D, event: InputEvent, world_position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if not is_instance_valid(phone_screen_viewport):
		return
	var local_position := phone_visual.to_local(world_position)
	var forwarded := event.duplicate() as InputEvent
	var screen_point := Vector2(
		(local_position.x / 0.112 + 0.5) * float(phone_screen_viewport.size.x),
		(0.5 - local_position.y / 0.192) * float(phone_screen_viewport.size.y)
	)
	if forwarded is InputEventMouse:
		(forwarded as InputEventMouse).position = screen_point
		phone_screen_viewport.push_input(forwarded, true)
	elif forwarded is InputEventScreenTouch:
		(forwarded as InputEventScreenTouch).position = screen_point
		phone_screen_viewport.push_input(forwarded, true)
	elif forwarded is InputEventScreenDrag:
		(forwarded as InputEventScreenDrag).position = screen_point
		phone_screen_viewport.push_input(forwarded, true)


func _make_phone_icon_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#172535")
	style.border_color = Color("#c6a45b")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 3
	style.content_margin_right = 3
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	return style


func _orient_phone_screen_to_head() -> void:
	if not is_instance_valid(phone_visual) or not parts.has("Head"):
		return
	var phone_head := parts["Head"] as MeshInstance3D
	# look_at يجعل المحور -Z نحو الهدف؛ نعكس الهدف كي يصبح +Z، وهو اتجاه سطح الشاشة، نحو الوجه.
	phone_visual.look_at(phone_visual.global_position * 2.0 - phone_head.global_position, Vector3.UP)


func _process(delta: float) -> void:
	motion_time += delta
	var intensity := 1.0 if motion_state == "walk" else (1.35 if motion_state == "run" else (0.55 if motion_state == "celebrate" else 0.0))
	var cycle_speed := 7.0 if motion_state == "walk" else 11.0
	var swing := sin(motion_time * cycle_speed) * 0.48 * intensity
	var bob := absf(sin(motion_time * cycle_speed * 2.0)) * 0.045 * intensity
	_restore_animation_defaults()
	if phone_using:
		# تثبيت وضعية الهاتف أثناء الحركة: الذراع اليمنى والرأس يظلان في وضع الاستخدام.
		if parts.has("RightArm"):
			var phone_arm := parts["RightArm"] as MeshInstance3D
			phone_arm.rotation = Vector3(-0.10, 0.0, -0.78)
		if is_instance_valid(phone_visual):
			# الذراع تحمل الهاتف، لكن موضعه النهائي يبقى أمام أسفل الوجه عند مستوى الذقن.
			phone_visual.global_position = to_global(Vector3(0.0, 1.43, -0.27))
			_orient_phone_screen_to_head()
		if parts.has("Head") and is_instance_valid(phone_visual):
			# وجّه الوجه نحو الهاتف فعليًا بدل زاوية ثابتة؛ يعود الرأس لوضعه الطبيعي عند إخفاء الهاتف.
			var phone_head := parts["Head"] as MeshInstance3D
			phone_head.look_at(phone_visual.global_position, Vector3.UP)
		if parts.has("TorsoBase"):
			(parts["TorsoBase"] as MeshInstance3D).rotation.x = -0.025
		# استمر في تحريك الساقين والذراع اليسرى عند المشي أو الجري دون إسقاط الهاتف.
		if motion_state == "walk" or motion_state == "run":
			var phone_bob := absf(sin(motion_time * cycle_speed * 2.0)) * 0.045 * intensity
			if parts.has("TorsoBase"):
				(parts["TorsoBase"] as MeshInstance3D).position.y += phone_bob
			for limb_name in ["LeftArm", "LeftLeg", "RightLeg"]:
				if parts.has(limb_name):
					var limb := parts[limb_name] as MeshInstance3D
					var limb_sign := -1.0 if limb_name in ["LeftArm", "RightLeg"] else 1.0
					limb.rotation.x = swing * limb_sign
		return
	if motion_state == "talk":
		if parts.has("TorsoBase"):
			(parts["TorsoBase"] as MeshInstance3D).rotation.x = sin(motion_time * 3.2) * 0.035
		if parts.has("Head"):
			(parts["Head"] as MeshInstance3D).rotation.x = sin(motion_time * 4.1) * 0.065
		return
	if motion_state == "wave":
		if parts.has("RightArm"):
			var waving_arm := parts["RightArm"] as MeshInstance3D
			waving_arm.rotation.z = 1.05
			waving_arm.rotation.x = sin(motion_time * 8.0) * 0.42
		return
	if motion_state == "clap":
		var clap_phase := absf(sin(motion_time * 8.5))
		if parts.has("LeftArm"):
			(parts["LeftArm"] as MeshInstance3D).rotation = Vector3(-0.12, 0.0, -0.92 - clap_phase * 0.18)
		if parts.has("RightArm"):
			(parts["RightArm"] as MeshInstance3D).rotation = Vector3(-0.12, 0.0, 0.92 + clap_phase * 0.18)
		if parts.has("TorsoBase"):
			(parts["TorsoBase"] as MeshInstance3D).position.y += clap_phase * 0.025
		return
	if motion_state == "dance":
		var dance_phase := sin(motion_time * 5.2)
		if parts.has("TorsoBase"):
			(parts["TorsoBase"] as MeshInstance3D).rotation.z = dance_phase * 0.16
			(parts["TorsoBase"] as MeshInstance3D).position.y += absf(dance_phase) * 0.055
		if parts.has("LeftArm"):
			(parts["LeftArm"] as MeshInstance3D).rotation.z = -0.85 - dance_phase * 0.32
			(parts["LeftArm"] as MeshInstance3D).rotation.x = cos(motion_time * 5.2) * 0.28
		if parts.has("RightArm"):
			(parts["RightArm"] as MeshInstance3D).rotation.z = 0.85 + dance_phase * 0.32
			(parts["RightArm"] as MeshInstance3D).rotation.x = -cos(motion_time * 5.2) * 0.28
		if parts.has("LeftLeg"):
			(parts["LeftLeg"] as MeshInstance3D).rotation.x = sin(motion_time * 5.2) * 0.24
		if parts.has("RightLeg"):
			(parts["RightLeg"] as MeshInstance3D).rotation.x = -sin(motion_time * 5.2) * 0.24
		return
	if motion_state == "cry":
		if parts.has("Head"):
			(parts["Head"] as MeshInstance3D).rotation.x = 0.28 + sin(motion_time * 5.0) * 0.035
		if parts.has("TorsoBase"):
			(parts["TorsoBase"] as MeshInstance3D).rotation.x = 0.20
		if parts.has("LeftArm"):
			(parts["LeftArm"] as MeshInstance3D).rotation.z = -0.34
			(parts["LeftArm"] as MeshInstance3D).rotation.x = -0.20
		if parts.has("RightArm"):
			(parts["RightArm"] as MeshInstance3D).rotation.z = 0.34
			(parts["RightArm"] as MeshInstance3D).rotation.x = -0.20
		return
	if motion_state == "heart":
		if parts.has("LeftArm"):
			(parts["LeftArm"] as MeshInstance3D).rotation = Vector3(-0.28, 0.0, -1.02)
		if parts.has("RightArm"):
			(parts["RightArm"] as MeshInstance3D).rotation = Vector3(-0.28, 0.0, 1.02)
		if parts.has("TorsoBase"):
			(parts["TorsoBase"] as MeshInstance3D).rotation.x = -0.035
		return
	if motion_state == "celebrate":
		if parts.has("TorsoBase"):
			(parts["TorsoBase"] as MeshInstance3D).position.y += absf(sin(motion_time * 8.0)) * 0.12
		if parts.has("LeftArm"):
			(parts["LeftArm"] as MeshInstance3D).rotation.z = -1.15
		if parts.has("RightArm"):
			(parts["RightArm"] as MeshInstance3D).rotation.z = 1.15
		return
	if motion_state == "disappointed":
		if parts.has("TorsoBase"):
			(parts["TorsoBase"] as MeshInstance3D).rotation.x = 0.16
		if parts.has("Head"):
			(parts["Head"] as MeshInstance3D).rotation.x = 0.18
		if parts.has("LeftArm"):
			(parts["LeftArm"] as MeshInstance3D).rotation.z = -0.22
		if parts.has("RightArm"):
			(parts["RightArm"] as MeshInstance3D).rotation.z = 0.22
		return
	if motion_state == "sit":
		if parts.has("TorsoBase"):
			(parts["TorsoBase"] as MeshInstance3D).position.y = 0.91
		if parts.has("LeftLeg"):
			(parts["LeftLeg"] as MeshInstance3D).rotation.x = -1.05
			(parts["LeftLeg"] as MeshInstance3D).position.y = 0.30
		if parts.has("RightLeg"):
			(parts["RightLeg"] as MeshInstance3D).rotation.x = -1.05
			(parts["RightLeg"] as MeshInstance3D).position.y = 0.30
		if parts.has("LeftArm"):
			(parts["LeftArm"] as MeshInstance3D).rotation.z = -0.75
		if parts.has("RightArm"):
			(parts["RightArm"] as MeshInstance3D).rotation.z = 0.75
		return
	if parts.has("TorsoBase"):
		(parts["TorsoBase"] as MeshInstance3D).position.y += bob
	for limb_name in ["LeftArm", "RightArm", "LeftLeg", "RightLeg"]:
		if parts.has(limb_name):
			var limb := parts[limb_name] as MeshInstance3D
			var sign := -1.0 if limb_name in ["LeftArm", "RightLeg"] else 1.0
			if limb_name.ends_with("Arm"):
				limb.rotation.x = swing * sign
			else:
				limb.rotation.x = -swing * sign

func _cache_animation_defaults() -> void:
	for limb_name in ["TorsoBase", "Head", "LeftArm", "RightArm", "LeftLeg", "RightLeg"]:
		if parts.has(limb_name):
			var limb := parts[limb_name] as MeshInstance3D
			animated_defaults[limb_name] = {"position": limb.position, "rotation": limb.rotation}

func _restore_animation_defaults() -> void:
	for limb_name in animated_defaults:
		if parts.has(limb_name):
			var limb := parts[limb_name] as MeshInstance3D
			var defaults: Dictionary = animated_defaults[limb_name]
			limb.position = defaults["position"]
			limb.rotation = defaults["rotation"]

func _build_base_character() -> void:
	var skin_mat := _material(SKIN)
	var body_mat := _material(Color("#41658b"))
	var shoe_mat := _material(Color("#29231f"))
	_add_capsule("Head", 0.22, 0.46, Vector3(0, 1.68, 0), skin_mat)
	_add_capsule("Neck", 0.09, 0.20, Vector3(0, 1.42, 0), skin_mat)
	_add_capsule("TorsoBase", 0.27, 0.72, Vector3(0, 1.08, 0), body_mat)
	_add_capsule("LeftArm", 0.105, 0.62, Vector3(-0.36, 1.08, 0), skin_mat)
	_add_capsule("RightArm", 0.105, 0.62, Vector3(0.36, 1.08, 0), skin_mat)
	_add_capsule("LeftLeg", 0.13, 0.78, Vector3(-0.15, 0.43, 0), body_mat)
	_add_capsule("RightLeg", 0.13, 0.78, Vector3(0.15, 0.43, 0), body_mat)
	_add_box("LeftShoe", Vector3(0.22, 0.12, 0.34), Vector3(-0.15, 0.08, -0.055), _material(shoe_mat.albedo_color))
	_add_box("RightShoe", Vector3(0.22, 0.12, 0.34), Vector3(0.15, 0.08, -0.055), _material(shoe_mat.albedo_color))

	# طبقات بديلة مؤقتة؛ يمكن استبدالها بمشاهد مستقلة من مجلد assets/outfits.
	_add_capsule("JacketLayer", 0.292, 0.76, Vector3(0, 1.08, -0.012), _material(Color("#202735")))
	_add_capsule("ShirtLayer", 0.205, 0.59, Vector3(0, 1.10, -0.045), _material(Color("#e8e6df")))
	_add_box("TieLayer", Vector3(0.055, 0.34, 0.035), Vector3(0, 1.13, -0.16), _material(Color("#9d3030")))
	_add_cylinder("SkirtLayer", 0.30, 0.52, Vector3(0, 0.72, 0), _material(Color("#8b3152")))
	_add_capsule("WomenFormalTopLayer", 0.285, 0.72, Vector3(0, 1.08, -0.012), _material(Color("#8b3152")))
	_add_capsule("CasualTopLayer", 0.29, 0.74, Vector3(0, 1.08, -0.012), _material(Color("#426f64")))
	_add_capsule("SportTopLayer", 0.29, 0.74, Vector3(0, 1.08, -0.012), _material(Color("#d56a28")))

	outfit_mount = Node3D.new()
	outfit_mount.name = "OutfitMount"
	add_child(outfit_mount)
	hair_mount = Node3D.new()
	hair_mount.name = "HairMount"
	add_child(hair_mount)

func _build_face() -> void:
	var white := _material(EYE_WHITE)
	var dark := _material(EYE_DARK)
	var skin := _material(Color("#b97c59"))
	var mouth := _material(Color("#713e39"))
	# الوجه يتجه إلى -Z؛ تفاصيل صغيرة لتظل خفيفة على الهاتف.
	_add_sphere("LeftEyeWhite", Vector3(0.075, 0.055, 0.035), Vector3(-0.085, 1.72, -0.197), white)
	_add_sphere("RightEyeWhite", Vector3(0.075, 0.055, 0.035), Vector3(0.085, 1.72, -0.197), white)
	_add_sphere("LeftPupil", Vector3(0.027, 0.034, 0.018), Vector3(-0.085, 1.72, -0.229), dark)
	_add_sphere("RightPupil", Vector3(0.027, 0.034, 0.018), Vector3(0.085, 1.72, -0.229), dark)
	_add_box("LeftEyebrow", Vector3(0.13, 0.025, 0.025), Vector3(-0.085, 1.805, -0.202), dark)
	_add_box("RightEyebrow", Vector3(0.13, 0.025, 0.025), Vector3(0.085, 1.805, -0.202), dark)
	_add_sphere("Nose", Vector3(0.045, 0.065, 0.055), Vector3(0, 1.635, -0.218), skin)
	_add_box("Mouth", Vector3(0.09, 0.018, 0.018), Vector3(0, 1.565, -0.211), mouth)
	_add_sphere("LeftEar", Vector3(0.045, 0.09, 0.07), Vector3(-0.218, 1.66, 0), _material(SKIN))
	_add_sphere("RightEar", Vector3(0.045, 0.09, 0.07), Vector3(0.218, 1.66, 0), _material(SKIN))
	# اجمع ملامح الوجه تحت الرأس حتى تتحرك العينان والأنف والفم معه عند النظر للهاتف.
	var head := parts.get("Head") as Node3D
	if is_instance_valid(head):
		for part_name in ["LeftEyeWhite", "RightEyeWhite", "LeftPupil", "RightPupil", "LeftEyebrow", "RightEyebrow", "Nose", "Mouth", "LeftEar", "RightEar"]:
			var face_part := parts.get(part_name) as Node3D
			if is_instance_valid(face_part):
				face_part.reparent(head, true)

func _build_hair_placeholders() -> void:
	_add_sphere("ShortHairCap", Vector3(0.235, 0.13, 0.235), Vector3(0, 1.88, 0.005), _material(HAIR))
	_add_sphere("LongHairBack", Vector3(0.22, 0.30, 0.12), Vector3(0, 1.69, 0.13), _material(HAIR))
	_add_sphere("CurlyHairCap", Vector3(0.25, 0.17, 0.25), Vector3(0, 1.87, 0.005), _material(Color("#35251f")))
	for i in range(5):
		var x := -0.16 + float(i) * 0.08
		_add_sphere("Curl_%d" % i, Vector3(0.07, 0.07, 0.07), Vector3(x, 1.91, -0.09), _material(Color("#35251f")))
	# اربط الشعر بالرأس أيضًا كي تبقى تفاصيله متناسقة مع حركة النظر.
	var head := parts.get("Head") as Node3D
	if is_instance_valid(head):
		for part_name in ["ShortHairCap", "LongHairBack", "CurlyHairCap", "Curl_0", "Curl_1", "Curl_2", "Curl_3", "Curl_4"]:
			var hair_part := parts.get(part_name) as Node3D
			if is_instance_valid(hair_part):
				hair_part.reparent(head, true)


func _set_part_color(part_name: String, color: Color) -> void:
	if not parts.has(part_name):
		return
	var mesh_instance := parts[part_name] as MeshInstance3D
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	mesh_instance.material_override = material

func apply_outfit(outfit_id: String) -> void:
	current_outfit = outfit_id
	var ids := ["JacketLayer", "ShirtLayer", "TieLayer", "SkirtLayer", "WomenFormalTopLayer", "CasualTopLayer", "SportTopLayer"]
	for part_id in ids:
		_set_visible(part_id, false)
	_set_visible("TorsoBase", outfit_id == "default")
	_set_visible("LeftLeg", outfit_id != "women_formal")
	_set_visible("RightLeg", outfit_id != "women_formal")
	_set_visible("LeftArm", true)
	_set_visible("RightArm", true)
	if outfit_id == "men_formal":
		_set_visible("JacketLayer", true)
		_set_visible("ShirtLayer", true)
		_set_visible("TieLayer", true)
	elif outfit_id == "women_formal":
		_set_visible("SkirtLayer", true)
		_set_visible("WomenFormalTopLayer", true)
	elif outfit_id == "urban_casual":
		_set_visible("CasualTopLayer", true)
	elif outfit_id == "sport":
		_set_visible("SportTopLayer", true)
	var external_outfit := _apply_external_scene(outfit_mount, OUTFIT_SCENES.get(outfit_id, ""))
	if external_outfit:
		for part_id in ids:
			_set_visible(part_id, false)

func apply_hairstyle(hairstyle_id: String) -> void:
	current_hairstyle = hairstyle_id if HAIR_SCENES.has(hairstyle_id) else "short"
	_set_visible("ShortHairCap", current_hairstyle == "short")
	_set_visible("LongHairBack", current_hairstyle == "long")
	_set_visible("CurlyHairCap", current_hairstyle == "curly")
	for i in range(5):
		_set_visible("Curl_%d" % i, current_hairstyle == "curly")
	var external_hair := _apply_external_scene(hair_mount, HAIR_SCENES.get(current_hairstyle, ""))
	if external_hair:
		_set_visible("ShortHairCap", false)
		_set_visible("LongHairBack", false)
		_set_visible("CurlyHairCap", false)
		for i in range(5):
			_set_visible("Curl_%d" % i, false)

func _apply_external_scene(mount: Node3D, scene_path: String) -> bool:
	for child in mount.get_children():
		mount.remove_child(child)
		child.queue_free()
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		return false
	var packed := load(scene_path) as PackedScene
	if packed != null:
		mount.add_child(packed.instantiate())
		return true
	return false

func _set_visible(part_name: String, is_visible: bool) -> void:
	if parts.has(part_name):
		(parts[part_name] as MeshInstance3D).visible = is_visible

func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.82
	return mat

func _add_capsule(part_name: String, radius: float, height: float, pos: Vector3, mat: Material) -> void:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	_add_mesh(part_name, mesh, pos, mat)

func _add_cylinder(part_name: String, radius: float, height: float, pos: Vector3, mat: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.72
	mesh.bottom_radius = radius
	mesh.height = height
	_add_mesh(part_name, mesh, pos, mat)

func _add_box(part_name: String, dimensions: Vector3, pos: Vector3, mat: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	_add_mesh(part_name, mesh, pos, mat)

func _add_sphere(part_name: String, dimensions: Vector3, pos: Vector3, mat: Material) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	var instance := MeshInstance3D.new()
	instance.name = part_name
	instance.mesh = mesh
	instance.scale = dimensions
	instance.position = pos
	instance.material_override = mat
	add_child(instance)
	parts[part_name] = instance

func _add_mesh(part_name: String, mesh: Mesh, pos: Vector3, mat: Material) -> void:
	var instance := MeshInstance3D.new()
	instance.name = part_name
	instance.mesh = mesh
	instance.position = pos
	instance.material_override = mat
	add_child(instance)
	parts[part_name] = instance


## Founder appearance: black and gold, with no separate wardrobe system.
func apply_founder_style() -> void:
	if get_node_or_null("FounderVisual") != null:
		return
	apply_outfit("default")
	_set_part_color("TorsoBase", Color("#171717"))
	_set_part_color("LeftLeg", Color("#171717"))
	_set_part_color("RightLeg", Color("#171717"))

	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color("#d6ad55")
	gold.metallic = 0.72
	gold.roughness = 0.28

	var royal := Node3D.new()
	royal.name = "FounderVisual"
	add_child(royal)

	var crown_band := MeshInstance3D.new()
	crown_band.name = "CrownBand"
	var band_mesh := CylinderMesh.new()
	band_mesh.top_radius = 0.235
	band_mesh.bottom_radius = 0.235
	band_mesh.height = 0.075
	crown_band.mesh = band_mesh
	crown_band.position = Vector3(0, 1.91, 0)
	crown_band.material_override = gold
	royal.add_child(crown_band)

	for i in range(5):
		var angle := TAU * float(i) / 5.0
		var point := MeshInstance3D.new()
		point.name = "CrownPoint_%d" % i
		var point_mesh := CylinderMesh.new()
		point_mesh.top_radius = 0.0
		point_mesh.bottom_radius = 0.045
		point_mesh.height = 0.16
		point.mesh = point_mesh
		point.position = Vector3(cos(angle) * 0.19, 2.015, sin(angle) * 0.19)
		point.material_override = gold
		royal.add_child(point)

	var chest_emblem := MeshInstance3D.new()
	chest_emblem.name = "FounderChestEmblem"
	var emblem_mesh := SphereMesh.new()
	emblem_mesh.radius = 0.075
	emblem_mesh.height = 0.12
	chest_emblem.mesh = emblem_mesh
	chest_emblem.position = Vector3(0, 1.24, -0.255)
	chest_emblem.material_override = gold
	royal.add_child(chest_emblem)

	var belt := MeshInstance3D.new()
	belt.name = "FounderGoldBelt"
	var belt_mesh := BoxMesh.new()
	belt_mesh.size = Vector3(0.43, 0.055, 0.045)
	belt.mesh = belt_mesh
	belt.position = Vector3(0, 0.83, -0.255)
	belt.material_override = gold
	royal.add_child(belt)
