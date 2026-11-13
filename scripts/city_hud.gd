extends CanvasLayer
## واجهة المدينة ونافذة التفاعل المنفصلة مع شخصية لاعب آخر.

signal friend_add_requested(player_id: String)
signal group_add_requested(player_id: String)
signal party_gift_requested(player_id: String)
signal player_report_requested(player_id: String)
signal group_invite_requested(player_id: String)
signal group_member_removed(player_id: String)
signal group_chat_message_submitted(message: String)
signal group_meeting_point_requested(position: Vector3)
signal group_follow_mode_requested(enabled: bool)
signal group_leader_move_requested(target_position: Vector3)

var main_scene: Node
var mission_manager: Node
var root: Control
var popup: PanelContainer
var popup_title: Label
var popup_body: Label
var money_label: Button
var chips_label: Button
var player_popup: PanelContainer
var player_name_label: Label
var player_level_label: Label
var player_status_label: Label
var player_avatar_label: Label
var player_action_status: Label
var player_primary_action_button: Button
var selected_player_is_friend := false
var selected_player_id := ""
var group_members: Array[Dictionary] = [{"player_id":"local_leader", "display_name":"أنت", "is_leader":true}]
var pending_group_invites: Array[String] = []
var group_popup: PanelContainer
var group_status_label: Label
var group_members_box: VBoxContainer
var group_chat_popup: PanelContainer
var group_chat_log: RichTextLabel
var group_chat_input: LineEdit
var group_meeting_status: Label
var group_meeting_position := Vector3.ZERO
var group_follow_enabled := false
var group_follow_button: Button
var group_meeting_point_button: Button
var group_move_button: Button
var group_member_markers: Dictionary = {}

const GROUP_MAX_MEMBERS := 4
const GROUP_CHAT_MAX_LENGTH := 300

const SECTIONS := {
	"profile": ["الملف الشخصي", "عرض مستوى اللاعب وخبرته وإعدادات الحساب والشخصية."],
	"missions": ["المهام والإنجازات", "تابع مهام المدينة والوظائف والإنجازات اليومية. أكمل النشاط من موقعه داخل المدينة."],
	"rewards": ["المكافآت اليومية", "راجع الأنشطة اليومية واستلم مكافآتك بعد إكمال شروطها."],
	"events": ["مركز الفعاليات", "الفعاليات المخطط لها: مهرجان الحيوانات لمدة 7 أيام، حفلات اللاعبين، وتحديات المدينة. ستظهر مواعيد الفعاليات ومؤقتاتها ومكافآتها عند تفعيل نظام الفعاليات المتصل."],
	"pass": ["تذكرة الموسم", "تذكرة شهرية بجوائز رئيسية متتابعة: شخصية، ثم زي، ثم مركبة، ثم حيوان أليف. تفاصيل الموسم ومكافآته تُعرض عند تفعيل نظام المواسم."],
	"shop": ["المتجر والعروض", "افتح المتجر لعرض الملابس والعناصر المتاحة. المشتريات تحتاج تأكيدًا واضحًا قبل الدفع."],
	"map": ["خريطة المدينة", "استكشف مناطق المدينة واتبع اللافتات الإرشادية للوصول إلى الأماكن والمباني."],
	"social": ["الأصدقاء والتواصل", "ابحث عن صديق باستخدام رمز اللاعب الفريد، أو اضغط على شخصية لاعب لعرض قائمة التفاعل."],
	"group": ["مجموعتي", "مجموعة صغيرة من أربعة لاعبين كحد أقصى: قائد وثلاثة أعضاء."],
	"chat": ["المحادثة", "افتح محادثة مجموعتك للتواصل مع أعضائها. الرسائل بين الأجهزة تحتاج اتصال الخادم."],
	"emotes": ["التعبيرات والحركات", "اختر تعبير وجه أو حركة اجتماعية للشخصية. الحركات المتاحة تظهر هنا عند ربط مكتبة التعبيرات."],
	"party": ["حفلة في المدينة", "يمكن استضافة حفلة في موقع مناسب. منطقة الحفلة تستوعب حتى 50 لاعبًا، وتُمنح المكافآت لمن يقف داخل حدود المنطقة المضيئة فقط."],
	"pets": ["الحيوانات الأليفة", "تابع حيوانك الأليف ومهرجان الحيوانات، وطوّر الحيوان المؤقت للوصول إلى القط الفرعوني الذهبي."],
	"settings": ["الإعدادات", "اضبط اللغة والصوت وجودة الرسوم بما يناسب جهازك."],
}

func _ready() -> void:
	self.layer = 40
	main_scene = get_parent()
	mission_manager = main_scene.get_node_or_null("MissionManager") if is_instance_valid(main_scene) else null
	_build()
	_build_player_interaction_popup()
	_build_group_popup()
	_build_group_chat_popup()
	_refresh_wallet()


func _exit_tree() -> void:
	# العلامات مضافة إلى المشهد الرئيسي، لذا يجب تنظيفها عند إزالة واجهة المدينة.
	for marker_value in group_member_markers.values():
		if is_instance_valid(marker_value):
			marker_value.queue_free()
	group_member_markers.clear()
	if is_instance_valid(main_scene):
		var meeting_marker := main_scene.get_node_or_null("GroupMeetingMarker")
		if is_instance_valid(meeting_marker):
			meeting_marker.queue_free()

func _process(_delta: float) -> void:
	if not is_instance_valid(mission_manager) and is_instance_valid(main_scene):
		mission_manager = main_scene.get_node_or_null("MissionManager")
	_refresh_wallet()

func _build() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var top := HBoxContainer.new()
	top.anchor_left = 0.18
	top.anchor_right = 0.82
	top.anchor_top = 0.015
	top.anchor_bottom = 0.015
	top.offset_bottom = 52
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 8)
	root.add_child(top)
	money_label = _make_button(top, "ذهب: 0  +", "wallet")
	chips_label = _make_button(top, "رقائق: 0  +", "wallet")

	var left := VBoxContainer.new()
	left.anchor_left = 0.012
	left.anchor_top = 0.15
	left.anchor_bottom = 0.68
	left.offset_right = 150
	left.add_theme_constant_override("separation", 7)
	root.add_child(left)
	_make_button(left, "👤 الملف", "profile")
	_make_button(left, "📜 المهام", "missions")
	_make_button(left, "🎁 المكافآت", "rewards")
	_make_button(left, "🏆 الإنجازات", "missions")

	var right := VBoxContainer.new()
	right.anchor_left = 1.0
	right.anchor_right = 1.0
	right.anchor_top = 0.17
	right.anchor_bottom = 0.72
	right.offset_left = -158
	right.offset_right = -8
	right.add_theme_constant_override("separation", 7)
	root.add_child(right)
	_make_button(right, "👑 الفعاليات", "events")
	_make_button(right, "🎟 الموسم", "pass")
	_make_button(right, "🛍 المتجر", "shop")
	_make_button(right, "🗺 الخريطة", "map")
	_make_button(right, "🐈 الحيوانات", "pets")

	var bottom := HBoxContainer.new()
	bottom.anchor_left = 0.28
	bottom.anchor_right = 0.72
	bottom.anchor_top = 1.0
	bottom.anchor_bottom = 1.0
	bottom.offset_top = -66
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 8)
	root.add_child(bottom)
	_make_button(bottom, "💬 محادثة", "chat")
	_make_button(bottom, "👥 أصدقاء", "social")
	_make_button(bottom, "🛡 مجموعتي", "group")
	_make_button(bottom, "😊 تعبيرات", "emotes")
	_make_button(bottom, "🎉 حفلة", "party")
	_make_button(bottom, "⚙", "settings")

	popup = PanelContainer.new()
	popup.anchor_left = 0.5
	popup.anchor_right = 0.5
	popup.anchor_top = 0.5
	popup.anchor_bottom = 0.5
	popup.offset_left = -210
	popup.offset_right = 210
	popup.offset_top = -145
	popup.offset_bottom = 145
	popup.visible = false
	popup.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(popup)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	popup.add_child(content)
	popup_title = Label.new()
	popup_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup_title.add_theme_font_size_override("font_size", 22)
	content.add_child(popup_title)
	popup_body = Label.new()
	popup_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	popup_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(popup_body)
	var close := Button.new()
	close.text = "إغلاق"
	close.pressed.connect(func(): popup.visible = false)
	content.add_child(close)

func _make_button(parent: Control, caption: String, section: String) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(118, 42)
	button.add_theme_font_size_override("font_size", 14)
	button.pressed.connect(_on_button_pressed.bind(section))
	parent.add_child(button)
	return button

func _on_button_pressed(section: String) -> void:
	if section == "wallet":
		_open_section("shop")
		return
	if section == "settings":
		_open_section("settings")
		return
	_open_section(section)

func _open_section(section: String) -> void:
	if not SECTIONS.has(section):
		return
	popup_title.text = str(SECTIONS[section][0])
	popup_body.text = str(SECTIONS[section][1])
	if section == "group":
		_open_group_popup()
		return
	if section == "chat":
		_open_group_chat()
		return
	if section == "rewards":
		var daily := main_scene.get_node_or_null("DailyActivities") if is_instance_valid(main_scene) else null
		if is_instance_valid(daily) and is_instance_valid(daily.get("root_panel")):
			daily.root_panel.visible = true
			popup_body.text += "\nتم فتح لوحة الأنشطة اليومية الموجودة في اللعبة."
	if section == "shop":
		var shop := main_scene.get_node_or_null("ShopManager") if is_instance_valid(main_scene) else null
		if is_instance_valid(shop) and shop.has_method("open_shop"):
			shop.open_shop()
	if section == "map":
		var city_map := main_scene.get_node_or_null("CityMapHUD/CityMap") if is_instance_valid(main_scene) else null
		if is_instance_valid(city_map):
			for method_name in ["open_map", "show_map", "toggle_map", "_toggle_map"]:
				if city_map.has_method(method_name):
					city_map.call(method_name)
					break
	popup.visible = true

func _refresh_wallet() -> void:
	if not is_instance_valid(mission_manager):
		return
	if is_instance_valid(money_label):
		money_label.text = "ذهب: %d  +" % int(mission_manager.get("money"))
	if is_instance_valid(chips_label):
		chips_label.text = "رقائق: %d  +" % int(mission_manager.get("chips"))


func _build_player_interaction_popup() -> void:
	# نافذة مستقلة عن لوحة الأصدقاء؛ تظهر عند استدعاء open_player_interaction من تفاعل الشخصية.
	player_popup = PanelContainer.new()
	player_popup.name = "PlayerInteractionPopup"
	player_popup.anchor_left = 0.5
	player_popup.anchor_right = 0.5
	player_popup.anchor_top = 0.5
	player_popup.anchor_bottom = 0.5
	player_popup.offset_left = -190
	player_popup.offset_right = 190
	player_popup.offset_top = -190
	player_popup.offset_bottom = 190
	player_popup.visible = false
	player_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.31, 0.23, 0.66, 0.98)
	panel_style.border_color = Color(0.78, 0.65, 0.98, 1.0)
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(28)
	panel_style.content_margin_left = 22
	panel_style.content_margin_right = 22
	panel_style.content_margin_top = 18
	panel_style.content_margin_bottom = 18
	player_popup.add_theme_stylebox_override("panel", panel_style)
	root.add_child(player_popup)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 9)
	player_popup.add_child(content)
	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_END
	content.add_child(top)
	var close := Button.new()
	close.text = "✕"
	close.custom_minimum_size = Vector2(42, 38)
	close.pressed.connect(func(): player_popup.visible = false)
	top.add_child(close)
	player_avatar_label = Label.new()
	player_avatar_label.text = "👤"
	player_avatar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_avatar_label.add_theme_font_size_override("font_size", 54)
	content.add_child(player_avatar_label)
	player_name_label = Label.new()
	player_name_label.text = "اسم اللاعب"
	player_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_name_label.add_theme_font_size_override("font_size", 23)
	player_name_label.add_theme_color_override("font_color", Color.WHITE)
	content.add_child(player_name_label)
	player_level_label = Label.new()
	player_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_level_label.add_theme_color_override("font_color", Color(0.88, 0.85, 1.0))
	content.add_child(player_level_label)
	player_status_label = Label.new()
	player_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_status_label.add_theme_color_override("font_color", Color(0.88, 0.85, 1.0))
	content.add_child(player_status_label)
	player_primary_action_button = Button.new()
	player_primary_action_button.text = "إضافة صديق"
	player_primary_action_button.custom_minimum_size.y = 52
	player_primary_action_button.add_theme_font_size_override("font_size", 22)
	player_primary_action_button.pressed.connect(_on_player_primary_action)
	content.add_child(player_primary_action_button)
	var gift_party := Button.new()
	gift_party.text = "إهداء حفلة"
	gift_party.custom_minimum_size.y = 52
	gift_party.add_theme_font_size_override("font_size", 22)
	gift_party.pressed.connect(_on_player_gift_party)
	content.add_child(gift_party)
	var report := Button.new()
	report.text = "⚠ تقديم بلاغ"
	report.pressed.connect(_on_player_report)
	content.add_child(report)
	player_action_status = Label.new()
	player_action_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_action_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	player_action_status.add_theme_color_override("font_color", Color(1.0, 0.91, 0.69))
	content.add_child(player_action_status)


func open_player_interaction(player_data: Dictionary) -> void:
	# البيانات المتوقعة: player_id, display_name, level, account_age, avatar_text.
	selected_player_id = str(player_data.get("player_id", "")).strip_edges()
	if selected_player_id.is_empty() or selected_player_id.length() > 64 or selected_player_id == "local_leader":
		selected_player_id = ""
	selected_player_is_friend = bool(player_data.get("is_friend", false))
	player_primary_action_button.text = "إضافة للمجموعة" if selected_player_is_friend else "إضافة صديق"
	var clean_name := str(player_data.get("display_name", "لاعب")).strip_edges().substr(0, 24)
	player_name_label.text = clean_name if not clean_name.is_empty() else "لاعب"
	var clean_level := str(player_data.get("level", "—")).substr(0, 12)
	player_level_label.text = "المستوى %s" % clean_level
	player_status_label.text = str(player_data.get("account_age", "")).strip_edges().substr(0, 40)
	var clean_avatar := str(player_data.get("avatar_text", "👤")).substr(0, 8)
	player_avatar_label.text = clean_avatar if not clean_avatar.is_empty() else "👤"
	player_action_status.text = "بيانات اللاعب غير صالحة؛ تعذر تنفيذ التفاعل." if selected_player_id.is_empty() else ""
	player_popup.visible = true


func close_player_interaction() -> void:
	if is_instance_valid(player_popup):
		player_popup.visible = false


func _has_selected_player() -> bool:
	return not selected_player_id.is_empty() and selected_player_id.length() <= 64 and selected_player_id != "local_leader"


func _on_player_primary_action() -> void:
	if not _has_selected_player():
		player_action_status.text = "تعذر تنفيذ الطلب: رمز اللاعب غير متاح."
		return
	if selected_player_is_friend:
		_request_group_invite(selected_player_id)
	else:
		friend_add_requested.emit(selected_player_id)
		player_action_status.text = "تم تجهيز طلب الإضافة؛ الإرسال الفعلي يحتاج اتصال الخادم."


func _on_player_gift_party() -> void:
	if not _has_selected_player():
		player_action_status.text = "تعذر تجهيز الإهداء: رمز اللاعب غير متاح."
		return
	party_gift_requested.emit(selected_player_id)
	player_action_status.text = "تم تجهيز طلب إهداء الحفلة؛ التنفيذ يحتاج خدمة الحفلات المتصلة."


func _on_player_report() -> void:
	if not _has_selected_player():
		player_action_status.text = "تعذر تجهيز البلاغ: رمز اللاعب غير متاح."
		return
	player_report_requested.emit(selected_player_id)
	player_action_status.text = "تم تجهيز البلاغ للمراجعة؛ حفظه وإرساله يحتاج خادم الإشراف."


func _build_group_popup() -> void:
	group_popup = PanelContainer.new()
	group_popup.name = "PlayerGroupPopup"
	group_popup.anchor_left = 0.5
	group_popup.anchor_right = 0.5
	group_popup.anchor_top = 0.5
	group_popup.anchor_bottom = 0.5
	group_popup.offset_left = -220
	group_popup.offset_right = 220
	group_popup.offset_top = -220
	group_popup.offset_bottom = 220
	group_popup.visible = false
	group_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(group_popup)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	group_popup.add_child(box)
	var heading := Label.new()
	heading.text = "👥 مجموعتي"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 24)
	box.add_child(heading)
	group_members_box = VBoxContainer.new()
	group_members_box.add_theme_constant_override("separation", 6)
	box.add_child(group_members_box)
	group_status_label = Label.new()
	group_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	group_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(group_status_label)
	var chat_button := Button.new()
	chat_button.text = "💬 محادثة المجموعة"
	chat_button.custom_minimum_size.y = 44
	chat_button.pressed.connect(_open_group_chat)
	box.add_child(chat_button)
	group_meeting_point_button = Button.new()
	group_meeting_point_button.name = "SetGroupMeetingPointButton"
	group_meeting_point_button.text = "📍 تحديد مكان التجمع هنا"
	group_meeting_point_button.custom_minimum_size.y = 44
	group_meeting_point_button.pressed.connect(_set_group_meeting_point_here)
	box.add_child(group_meeting_point_button)
	group_meeting_status = Label.new()
	group_meeting_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	group_meeting_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	group_meeting_status.text = "لم يتم تحديد مكان تجمع بعد."
	box.add_child(group_meeting_status)
	group_follow_button = Button.new()
	group_follow_button.name = "GroupFollowLeaderButton"
	group_follow_button.text = "🚶 التحرك مع القائد"
	group_follow_button.custom_minimum_size.y = 44
	group_follow_button.pressed.connect(_toggle_group_follow_mode)
	box.add_child(group_follow_button)
	group_move_button = Button.new()
	group_move_button.name = "StartGroupMoveButton"
	group_move_button.text = "📍 بدء التحرك إلى نقطة التجمع"
	group_move_button.custom_minimum_size.y = 44
	group_move_button.pressed.connect(_start_group_move_to_meeting_point)
	box.add_child(group_move_button)
	var close := Button.new()
	close.text = "إغلاق"
	close.pressed.connect(func(): group_popup.visible = false)
	box.add_child(close)
	_refresh_group_popup()


func _open_group_popup() -> void:
	_refresh_group_popup()
	group_popup.visible = true


func _refresh_group_popup() -> void:
	if not is_instance_valid(group_members_box):
		return
	for child in group_members_box.get_children():
		child.queue_free()
	for i in range(GROUP_MAX_MEMBERS):
		var row := HBoxContainer.new()
		group_members_box.add_child(row)
		var label := Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if i < group_members.size():
			var member: Dictionary = group_members[i]
			label.text = ("👑 " if bool(member.get("is_leader", false)) else "👤 ") + str(member.get("display_name", "لاعب"))
			if not bool(member.get("is_leader", false)):
				var remove := Button.new()
				remove.text = "إزالة"
				remove.pressed.connect(_remove_group_member.bind(str(member.get("player_id", ""))))
				row.add_child(label)
				row.add_child(remove)
			else:
				row.add_child(label)
		else:
			label.text = "＋ خانة عضو فارغة"
			row.add_child(label)
	group_status_label.text = "الأعضاء: %d/%d" % [group_members.size(), GROUP_MAX_MEMBERS]
	if not pending_group_invites.is_empty():
		group_status_label.text += "\nدعوات معلقة: %d" % pending_group_invites.size()
	var local_is_leader := _is_local_group_leader()
	var has_other_members := group_members.size() > 1
	if is_instance_valid(group_meeting_point_button):
		group_meeting_point_button.visible = local_is_leader and has_other_members
	if is_instance_valid(group_move_button):
		group_move_button.visible = local_is_leader and has_other_members
	if is_instance_valid(group_follow_button):
		group_follow_button.visible = not local_is_leader and has_other_members
	if (local_is_leader or not has_other_members) and group_follow_enabled:
		group_follow_enabled = false
		group_follow_mode_requested.emit(false)
		if is_instance_valid(group_follow_button):
			group_follow_button.text = "🚶 التحرك مع القائد"


func _is_local_group_leader() -> bool:
	if group_members.is_empty():
		return false
	var leader: Dictionary = group_members[0]
	return str(leader.get("player_id", "")) == "local_leader" and bool(leader.get("is_leader", false))


func _request_group_invite(player_id: String) -> void:
	player_id = player_id.strip_edges()
	if player_id.is_empty() or player_id.length() > 64 or player_id == "local_leader":
		player_action_status.text = "رمز اللاعب غير صالح."
		return
	if group_members.size() >= GROUP_MAX_MEMBERS:
		player_action_status.text = "المجموعة مكتملة؛ الحد الأقصى أربعة لاعبين."
		return
	if _group_contains(player_id) or pending_group_invites.has(player_id):
		player_action_status.text = "هذا اللاعب موجود بالفعل أو أُرسلت له دعوة."
		return
	pending_group_invites.append(player_id)
	group_add_requested.emit(player_id)
	player_action_status.text = "تم تجهيز دعوة المجموعة. لن يُضاف اللاعب إلا بعد قبول الدعوة من الطرف الآخر."
	_refresh_group_popup()


func resolve_group_invitation(player_id: String, accepted: bool, display_name: String = "لاعب") -> void:
	player_id = player_id.strip_edges()
	if player_id.is_empty() or player_id.length() > 64 or not pending_group_invites.has(player_id):
		return
	pending_group_invites.erase(player_id)
	if accepted and group_members.size() < GROUP_MAX_MEMBERS and not _group_contains(player_id):
		var clean_name := display_name.strip_edges().substr(0, 24)
		if clean_name.is_empty():
			clean_name = "لاعب"
		group_members.append({"player_id":player_id, "display_name":clean_name, "is_leader":false})
	_refresh_group_popup()


func _group_contains(player_id: String) -> bool:
	for member in group_members:
		if str(member.get("player_id", "")) == player_id:
			return true
	return false


func _remove_group_member(player_id: String) -> void:
	for i in range(group_members.size() - 1, 0, -1):
		if str(group_members[i].get("player_id", "")) == player_id:
			group_members.remove_at(i)
			_remove_group_member_marker(player_id)
			group_member_removed.emit(player_id)
			break
	if group_members.size() <= 1:
		_clear_group_meeting_marker()
		group_meeting_position = Vector3.ZERO
		if group_follow_enabled:
			group_follow_enabled = false
			group_follow_mode_requested.emit(false)
	_refresh_group_popup()


func _remove_group_member_marker(player_id: String) -> void:
	var marker_value: Variant = group_member_markers.get(player_id, null)
	if is_instance_valid(marker_value):
		marker_value.queue_free()
	group_member_markers.erase(player_id)


func _clear_group_meeting_marker() -> void:
	if not is_instance_valid(main_scene):
		return
	var marker := main_scene.get_node_or_null("GroupMeetingMarker")
	if is_instance_valid(marker):
		marker.queue_free()


func _toggle_group_follow_mode() -> void:
	if _is_local_group_leader():
		group_meeting_status.text = "القائد لا يحتاج إلى متابعة نفسه."
		return
	if group_members.size() <= 1:
		group_meeting_status.text = "انضم إلى مجموعة أولًا لتفعيل متابعة القائد."
		return
	group_follow_enabled = not group_follow_enabled
	group_follow_mode_requested.emit(group_follow_enabled)
	if is_instance_valid(group_follow_button):
		group_follow_button.text = "⏸ إيقاف متابعة القائد" if group_follow_enabled else "🚶 التحرك مع القائد"
	if is_instance_valid(group_meeting_status):
		group_meeting_status.text = "تم طلب متابعة تحرك القائد. يبدأ التحرك الفعلي بعد مزامنة الخادم." if group_follow_enabled else "تم إيقاف متابعة تحرك القائد."


func _start_group_move_to_meeting_point() -> void:
	if not _is_local_group_leader():
		group_meeting_status.text = "هذا الأمر متاح لقائد المجموعة فقط."
		return
	if group_members.size() <= 1:
		group_meeting_status.text = "أضف أعضاء إلى المجموعة أولًا."
		return
	if group_meeting_position == Vector3.ZERO:
		group_meeting_status.text = "حدد مكان التجمع أولًا."
		return
	group_leader_move_requested.emit(group_meeting_position)
	group_meeting_status.text = "تم تجهيز أمر التحرك إلى نقطة التجمع. سيصل للأعضاء عبر الخادم."


func receive_group_member_positions(member_positions: Array) -> void:
	# تستدعى بعد تحقق الخادم من عضوية كل لاعب؛ لا تنشئ شخصيات لعب حقيقية من بيانات غير موثوقة.
	if not is_instance_valid(main_scene) or not main_scene.is_inside_tree():
		return
	var active_ids: Array[String] = []
	for entry in member_positions:
		if not entry is Dictionary:
			continue
		var player_id := str(entry.get("player_id", "")).strip_edges()
		if player_id.is_empty() or player_id.length() > 64 or player_id == "local_leader":
			continue
		if active_ids.has(player_id) or not _group_contains(player_id):
			continue
		var position_value: Variant = entry.get("position", null)
		if not position_value is Vector3:
			continue
		var world_position: Vector3 = position_value
		if not world_position.is_finite():
			continue
		if active_ids.size() >= GROUP_MAX_MEMBERS - 1:
			break
		active_ids.append(player_id)
		var marker: Node3D = group_member_markers.get(player_id)
		if not is_instance_valid(marker) or marker.is_queued_for_deletion():
			group_member_markers.erase(player_id)
			marker = Node3D.new()
			marker.name = "GroupMember_" + player_id.validate_node_name()
			var icon := MeshInstance3D.new()
			var mesh := SphereMesh.new()
			mesh.radius = 0.28
			mesh.height = 0.56
			icon.mesh = mesh
			var material := StandardMaterial3D.new()
			material.albedo_color = Color(0.15, 0.85, 0.55)
			material.emission_enabled = true
			material.emission = Color(0.05, 0.45, 0.25)
			icon.material_override = material
			marker.add_child(icon)
			var name_tag := Label3D.new()
			name_tag.text = str(entry.get("display_name", "عضو المجموعة")).strip_edges().substr(0, 24)
			name_tag.position.y = 0.8
			name_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			name_tag.font_size = 24
			marker.add_child(name_tag)
			main_scene.add_child(marker)
			group_member_markers[player_id] = marker
		var name_tag := marker.get_node_or_null("Label3D") as Label3D
		if is_instance_valid(name_tag):
			var clean_name := str(entry.get("display_name", "عضو المجموعة")).strip_edges().substr(0, 24)
			name_tag.text = clean_name if not clean_name.is_empty() else "عضو المجموعة"
		marker.global_position = world_position + Vector3(0, 0.4, 0)
	for old_id in group_member_markers.keys():
		if not active_ids.has(str(old_id)):
			_remove_group_member_marker(str(old_id))


func receive_group_move_order(target_position: Vector3) -> void:
	if not target_position.is_finite():
		if is_instance_valid(group_meeting_status):
			group_meeting_status.text = "تعذر استقبال موقع التجمع؛ الإحداثيات غير صالحة."
		return
	group_meeting_position = target_position
	_show_group_meeting_marker(target_position)
	if is_instance_valid(group_meeting_status):
		group_meeting_status.text = "القائد بدأ التحرك إلى نقطة التجمع. اتبع العلامة على الخريطة."


func _set_group_meeting_point_here() -> void:
	if not _is_local_group_leader():
		group_meeting_status.text = "تحديد مكان التجمع متاح لقائد المجموعة فقط."
		return
	if group_members.size() <= 1:
		group_meeting_status.text = "أضف عضوًا إلى المجموعة أولًا لتحديد مكان تجمع."
		return
	var player := main_scene.get_node_or_null("Player") as Node3D if is_instance_valid(main_scene) else null
	if not is_instance_valid(player):
		group_meeting_status.text = "تعذر تحديد موقعك الحالي."
		return
	group_meeting_position = player.global_position
	group_meeting_point_requested.emit(group_meeting_position)
	_show_group_meeting_marker(group_meeting_position)
	group_meeting_status.text = "تم تحديد مكان التجمع عند موقعك الحالي. سيظهر للأعضاء بعد ربط الخادم."


func receive_group_meeting_point(position: Vector3, leader_name: String = "قائد المجموعة") -> void:
	if not position.is_finite():
		if is_instance_valid(group_meeting_status):
			group_meeting_status.text = "تعذر استقبال نقطة التجمع؛ الإحداثيات غير صالحة."
		return
	group_meeting_position = position
	_show_group_meeting_marker(position)
	if is_instance_valid(group_meeting_status):
		group_meeting_status.text = "مكان تجمع المجموعة حدده: %s" % leader_name.strip_edges().substr(0, 24)


func _show_group_meeting_marker(position: Vector3) -> void:
	if not position.is_finite() or not is_instance_valid(main_scene):
		return
	_clear_group_meeting_marker()
	var marker := Node3D.new()
	marker.name = "GroupMeetingMarker"
	marker.position = Vector3(position.x, 0.15, position.z)
	main_scene.add_child(marker)
	var ring := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 1.15
	ring_mesh.outer_radius = 1.35
	ring.mesh = ring_mesh
	ring.rotation.x = PI / 2.0
	var ring_material := StandardMaterial3D.new()
	ring_material.albedo_color = Color(0.12, 0.78, 1.0, 0.9)
	ring_material.emission_enabled = true
	ring_material.emission = Color(0.05, 0.55, 1.0)
	ring.material_override = ring_material
	marker.add_child(ring)
	var beacon := MeshInstance3D.new()
	var beacon_mesh := CylinderMesh.new()
	beacon_mesh.top_radius = 0.08
	beacon_mesh.bottom_radius = 0.08
	beacon_mesh.height = 2.8
	beacon.mesh = beacon_mesh
	beacon.position.y = 1.45
	beacon.material_override = ring_material
	marker.add_child(beacon)
	var label := Label3D.new()
	label.text = "مكان تجمع المجموعة"
	label.position.y = 3.1
	label.font_size = 32
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.add_child(label)


func _build_group_chat_popup() -> void:
	group_chat_popup = PanelContainer.new()
	group_chat_popup.name = "GroupChatPopup"
	group_chat_popup.anchor_left = 0.5
	group_chat_popup.anchor_right = 0.5
	group_chat_popup.anchor_top = 0.5
	group_chat_popup.anchor_bottom = 0.5
	group_chat_popup.offset_left = -230
	group_chat_popup.offset_right = 230
	group_chat_popup.offset_top = -250
	group_chat_popup.offset_bottom = 250
	group_chat_popup.visible = false
	group_chat_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(group_chat_popup)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	group_chat_popup.add_child(box)
	var heading := Label.new()
	heading.text = "💬 محادثة المجموعة"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 22)
	box.add_child(heading)	
	group_chat_log = RichTextLabel.new()
	group_chat_log.bbcode_enabled = true
	group_chat_log.scroll_following = true
	group_chat_log.fit_content = false
	group_chat_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	group_chat_log.custom_minimum_size = Vector2(0, 300)
	group_chat_log.text = "[color=gray]رسائل المجموعة ستظهر هنا.[/color]"
	box.add_child(group_chat_log)
	group_chat_input = LineEdit.new()
	group_chat_input.placeholder_text = "اكتب رسالة للمجموعة..."
	group_chat_input.text_submitted.connect(_send_group_chat_message)
	box.add_child(group_chat_input)
	var actions := HBoxContainer.new()
	box.add_child(actions)
	var send := Button.new()
	send.text = "إرسال"
	send.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	send.pressed.connect(func(): _send_group_chat_message(group_chat_input.text))
	actions.add_child(send)
	var close := Button.new()
	close.text = "إغلاق"
	close.pressed.connect(func(): group_chat_popup.visible = false)
	actions.add_child(close)


func _open_group_chat() -> void:
	if not is_instance_valid(group_chat_popup):
		_build_group_chat_popup()
	group_chat_popup.visible = true
	group_popup.visible = false
	group_chat_input.grab_focus()


func _send_group_chat_message(raw_message: String) -> void:
	var message := raw_message.strip_edges()
	if message.is_empty():
		return
	if group_members.size() < 2:
		group_chat_log.append_text("[color=gray]لا يمكن إرسال رسالة قبل انضمام عضو آخر إلى المجموعة.\n[/color]")
		return
	# حد محلي للطول لتجنب الرسائل الضخمة؛ يطبق الخادم الحد نفسه عند ربط الدردشة.
	if message.length() > GROUP_CHAT_MAX_LENGTH:
		message = message.substr(0, GROUP_CHAT_MAX_LENGTH)
	var safe_message := message.replace("[", "(").replace("]", ")")
	if group_chat_log.text == "[color=gray]رسائل المجموعة ستظهر هنا.[/color]":
		group_chat_log.clear()
	group_chat_log.append_text("[color=gold][أنت][/color] " + safe_message + "\n")
	group_chat_message_submitted.emit(message)
	group_chat_input.clear()


func receive_group_chat_message(sender_name: String, message: String) -> void:
	var clean_message := message.strip_edges()
	if clean_message.is_empty() or not is_instance_valid(group_chat_log):
		return
	if group_members.size() < 2:
		return
	# لا تعرض رسائل أطول من الحد المحلي أو أسماء مرسلين غير محدودة.
	clean_message = clean_message.substr(0, GROUP_CHAT_MAX_LENGTH)
	var clean_sender := sender_name.strip_edges().substr(0, 24)
	if clean_sender.is_empty():
		clean_sender = "عضو المجموعة"
	var safe_name := clean_sender.replace("[", "(").replace("]", ")")
	var safe_message := clean_message.replace("[", "(").replace("]", ")")
	if group_chat_log.text == "[color=gray]رسائل المجموعة ستظهر هنا.[/color]":
		group_chat_log.clear()
	group_chat_log.append_text("[color=lightblue][" + safe_name + "][/color] " + safe_message + "\n")
