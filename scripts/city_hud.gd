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
var gems_label: Button
var phone_popup: PanelContainer
var vehicle_store_list: VBoxContainer
var vehicle_store_status: Label
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
var season_popup: PanelContainer
var season_fill_button: Button
var social_popup: PanelContainer
var social_friend_list: VBoxContainer
var social_chat_log: RichTextLabel
var social_chat_input: LineEdit
var social_status_label: Label
var social_active_tab := "friends"


const GROUP_MAX_MEMBERS := 4
const GROUP_CHAT_MAX_LENGTH := 300

const SECTIONS := {
	"profile": ["الملف الشخصي", "عرض مستوى اللاعب وخبرته وإعدادات الحساب والشخصية."],
	"missions": ["المهام والإنجازات", "تابع مهام المدينة والوظائف والإنجازات اليومية. أكمل النشاط من موقعه داخل المدينة."],
	"rewards": ["المكافآت اليومية", "راجع الأنشطة اليومية واستلم مكافآتك بعد إكمال شروطها."],
	"events": ["مركز الفعاليات", "الفعاليات المخطط لها: مهرجان الحيوانات لمدة 7 أيام، حفلات اللاعبين، وتحديات المدينة. ستظهر مواعيد الفعاليات ومؤقتاتها ومكافآتها عند تفعيل نظام الفعاليات المتصل."],
	"season": ["الموسم الشهري", "الموسم مدته 30 يومًا ويتكون من 10 مستويات، مع مهلة 72 ساعة للمستوى الجاري. أدوات الموسم تُكتسب من نشاط مؤهل وتُخزن في مخزن مستقل؛ لا تُستهلك إلا عند اختيار ملء المستوى. لا يوجد موسم نشط أو مكافآت قابلة للاستلام حتى يجهز الخادم بيانات الموسم ويربطها بالواجهة."],
	"phone": ["هاتف اللاعب", "متجر المركبات وإدارة المركبة المختارة."],
	"map": ["خريطة المدينة", "استكشف مناطق المدينة واتبع اللافتات الإرشادية للوصول إلى الأماكن والمباني."],
	"social": ["الأصدقاء والتواصل", "ابحث عن صديق باستخدام رمز اللاعب الفريد، أو اضغط على شخصية لاعب لعرض قائمة التفاعل."],
	"group": ["مجموعتي", "مجموعة صغيرة من أربعة لاعبين كحد أقصى: قائد وثلاثة أعضاء."],
	"chat": ["المحادثة", "افتح محادثة مجموعتك للتواصل مع أعضائها. الرسائل بين الأجهزة تحتاج اتصال الخادم."],
	"emotes": ["التعبيرات والحركات", "اختر تعبير وجه أو حركة اجتماعية للشخصية. الحركات المتاحة تظهر هنا عند ربط مكتبة التعبيرات."],
	"party": ["حفلة في المدينة", "تبدأ الحفلة بعد الدفع وتستمر 20 ثانية بالضبط. لا يوجد حد عددي اعتباطي للمشاركين؛ وتُمنح المكافآت وفق المشاركة الفعلية والتحقق ومنع التكرار."],
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
	_build_social_popup()
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


func _unhandled_input(event: InputEvent) -> void:
	var pressed := false
	var pointer_position := Vector2.ZERO
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = event.pressed
		pointer_position = event.position
	elif event is InputEventScreenTouch:
		pressed = event.pressed
		pointer_position = event.position
	if not pressed:
		return
	var open_popups: Array = [popup, phone_popup, player_popup, group_popup, group_chat_popup, social_popup, season_popup]
	for panel in open_popups:
		if is_instance_valid(panel) and panel.visible and panel.get_global_rect().has_point(pointer_position):
			return
	for panel in open_popups:
		if is_instance_valid(panel):
			panel.visible = false


func _build() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# أزرار المدينة على اليسار؛ نترك الجانب الأيمن لنافذة الأصدقاء والمحادثات.
	_build_season_entry()
	var dock := PanelContainer.new()
	dock.name = "LeftCityDock"
	dock.anchor_left = 0.012
	dock.anchor_right = 0.012
	dock.anchor_top = 0.15
	dock.anchor_bottom = 0.68
	dock.offset_left = 0
	dock.offset_right = 143
	dock.add_theme_stylebox_override("panel", _make_hud_panel_style())
	root.add_child(dock)

	var scroll := ScrollContainer.new()
	scroll.name = "CityDockScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dock.add_child(scroll)

	var actions := VBoxContainer.new()
	actions.name = "CityDockActions"
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_theme_constant_override("separation", 4)
	scroll.add_child(actions)

	money_label = _make_button(actions, "ذهب: 0 +", "wallet")
	chips_label = _make_button(actions, "رقائق: 0 +", "wallet")
	gems_label = _make_button(actions, "جواهر: 0", "wallet")
	_make_button(actions, "👤 الملف", "profile")
	_make_button(actions, "📜 المهام", "missions")
	_make_button(actions, "🎁 المكافآت", "rewards")
	_make_button(actions, "🏆 الإنجازات", "missions")
	_make_button(actions, "👑 الفعاليات", "events")
	_make_button(actions, "📱 الهاتف", "phone")
	_make_button(actions, "🗺 الخريطة", "map")
	_make_button(actions, "🐈 الحيوانات", "pets")
	_make_button(actions, "💬 محادثة", "chat")
	_make_button(actions, "👥 أصدقاء", "social")
	_make_button(actions, "🛡 مجموعتي", "group")
	_make_button(actions, "😊 تعبيرات", "emotes")
	_make_button(actions, "🎉 حفلة", "party")
	_make_button(actions, "⚙ الإعدادات", "settings")

	popup = PanelContainer.new()
	popup.anchor_left = 0.5
	popup.anchor_right = 0.5
	popup.anchor_top = 0.5
	popup.anchor_bottom = 0.5
	popup.offset_left = -190
	popup.offset_right = 190
	popup.offset_top = -145
	popup.offset_bottom = 145
	popup.visible = false
	popup.mouse_filter = Control.MOUSE_FILTER_STOP
	popup.add_theme_stylebox_override("panel", _make_hud_panel_style())
	root.add_child(popup)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	popup.add_child(content)
	var header := HBoxContainer.new()
	content.add_child(header)
	popup_title = Label.new()
	popup_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	popup_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup_title.add_theme_font_size_override("font_size", 22)
	header.add_child(popup_title)
	var close := Button.new()
	close.text = "✕"
	close.custom_minimum_size = Vector2(38, 34)
	close.pressed.connect(func(): popup.visible = false)
	header.add_child(close)
	popup_body = Label.new()
	popup_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	popup_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(popup_body)



func _build_season_entry() -> void:
	# أيقونة مستقلة أعلى يسار الشاشة؛ تترك مساحة المدينة وأزرار التحكم دون حجب.
	var entry := Button.new()
	entry.name = "MonthlySeasonEntry"
	entry.text = "👑\nالموسم"
	entry.tooltip_text = "الموسم الشهري"
	entry.custom_minimum_size = Vector2(58, 58)
	entry.anchor_left = 0.012
	entry.anchor_right = 0.012
	entry.anchor_top = 0.075
	entry.anchor_bottom = 0.075
	entry.offset_left = 0
	entry.offset_right = 58
	entry.offset_top = 0
	entry.offset_bottom = 58
	entry.add_theme_font_size_override("font_size", 14)
	entry.add_theme_color_override("font_color", Color(1.0, 0.86, 0.48))
	entry.add_theme_stylebox_override("normal", _make_hud_panel_style())
	entry.pressed.connect(_open_season_window)
	root.add_child(entry)
	_build_season_window()


func _build_season_window() -> void:
	season_popup = PanelContainer.new()
	season_popup.name = "MonthlySeasonWindow"
	season_popup.anchor_left = 0.5
	season_popup.anchor_right = 0.5
	season_popup.anchor_top = 0.5
	season_popup.anchor_bottom = 0.5
	var viewport_size := get_viewport().get_visible_rect().size
	var panel_width := clampf(viewport_size.x * 0.90, 280.0, 440.0)
	var panel_height := clampf(viewport_size.y * 0.72, 400.0, 560.0)
	season_popup.offset_left = -panel_width * 0.5
	season_popup.offset_right = panel_width * 0.5
	season_popup.offset_top = -panel_height * 0.5
	season_popup.offset_bottom = panel_height * 0.5
	season_popup.visible = false
	season_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	season_popup.add_theme_stylebox_override("panel", _make_hud_panel_style())
	root.add_child(season_popup)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 9)
	season_popup.add_child(content)

	var header := HBoxContainer.new()
	content.add_child(header)
	var heading := Label.new()
	heading.text = "👑 الموسم الشهري"
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 21)
	header.add_child(heading)
	var close := Button.new()
	close.text = "✕"
	close.custom_minimum_size = Vector2(38, 34)
	close.pressed.connect(func(): season_popup.visible = false)
	header.add_child(close)

	var summary := Label.new()
	summary.text = "مدة الموسم: 30 يومًا  •  10 مستويات"
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(summary)

	var state := Label.new()
	state.name = "SeasonServerState"
	state.text = "لا يوجد موسم نشط متصل بالخادم حاليًا."
	state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	state.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(state)

	var level := Label.new()
	level.text = "المستوى الحالي: — من 10"
	level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(level)

	var timer := Label.new()
	timer.text = "مهلة المستوى: تبدأ عند تفعيل الموسم — 72 ساعة"
	timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(timer)

	var inventory := Label.new()
	inventory.text = "مخزون أدوات الموسم: غير متاح قبل ربط بيانات الخادم"
	inventory.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inventory.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(inventory)

	var rewards := Label.new()
	rewards.text = "المكافآت والمستويات تظهر بعد تجهيز أصول الموسم وربطها بالخادم."
	rewards.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rewards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(rewards)

	season_fill_button = Button.new()
	season_fill_button.name = "SeasonFillLevelButton"
	season_fill_button.text = "ملء المستوى"
	season_fill_button.disabled = true
	season_fill_button.tooltip_text = "يتاح بعد اتصال بيانات الموسم والتحقق الخادمي من المخزون."
	season_fill_button.custom_minimum_size.y = 46
	content.add_child(season_fill_button)

	var note := Label.new()
	note.text = "فتح هذه النافذة لا يستهلك أي أدوات. التعبئة لا تعمل إلا بعد تأكيد الخادم."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(note)


func _open_season_window() -> void:
	if is_instance_valid(popup):
		popup.visible = false
	if is_instance_valid(season_popup):
		season_popup.visible = true


func _build_social_popup() -> void:
	social_popup = PanelContainer.new()
	social_popup.name = "SocialHubPopup"
	var viewport_width := get_viewport().get_visible_rect().size.x
	var panel_width := clampf(viewport_width * 0.40, 205.0, 300.0)
	social_popup.anchor_left = 1.0
	social_popup.anchor_right = 1.0
	social_popup.anchor_top = 0.02
	social_popup.anchor_bottom = 0.98
	social_popup.offset_left = -panel_width - 7.0
	social_popup.offset_right = -7.0
	social_popup.visible = false
	social_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	social_popup.add_theme_stylebox_override("panel", _make_hud_panel_style())
	root.add_child(social_popup)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	social_popup.add_child(outer)

	var header := HBoxContainer.new()
	outer.add_child(header)
	var heading := Label.new()
	heading.text = "الأصدقاء والمحادثات"
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 20)
	heading.add_theme_color_override("font_color", Color(0.94, 0.82, 0.55))
	header.add_child(heading)
	var close := Button.new()
	close.text = "✕"
	close.custom_minimum_size = Vector2(36, 36)
	close.pressed.connect(func(): social_popup.visible = false)
	header.add_child(close)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	outer.add_child(tabs)
	var friends_tab := Button.new()
	friends_tab.text = "الأصدقاء"
	friends_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	friends_tab.pressed.connect(_show_social_tab.bind("friends"))
	tabs.add_child(friends_tab)
	var public_tab := Button.new()
	public_tab.text = "العامة"
	public_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	public_tab.pressed.connect(_show_social_tab.bind("public"))
	tabs.add_child(public_tab)

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 6)
	outer.add_child(columns)

	var friends_panel := PanelContainer.new()
	friends_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	friends_panel.custom_minimum_size.x = 78
	columns.add_child(friends_panel)
	var friends_column := VBoxContainer.new()
	friends_column.add_theme_constant_override("separation", 6)
	friends_panel.add_child(friends_column)
	var friends_heading := Label.new()
	friends_heading.text = "قائمة اللاعبين"
	friends_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	friends_column.add_child(friends_heading)
	var friends_scroll := ScrollContainer.new()
	friends_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	friends_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	friends_column.add_child(friends_scroll)
	social_friend_list = VBoxContainer.new()
	social_friend_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	friends_scroll.add_child(social_friend_list)

	var chat_panel := PanelContainer.new()
	chat_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(chat_panel)
	var chat_column := VBoxContainer.new()
	chat_column.add_theme_constant_override("separation", 6)
	chat_panel.add_child(chat_column)
	var chat_heading := Label.new()
	chat_heading.text = "المحادثة"
	chat_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chat_column.add_child(chat_heading)
	social_chat_log = RichTextLabel.new()
	social_chat_log.bbcode_enabled = true
	social_chat_log.fit_content = false
	social_chat_log.scroll_following = true
	social_chat_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	social_chat_log.custom_minimum_size = Vector2(0, 180)
	chat_column.add_child(social_chat_log)
	social_chat_input = LineEdit.new()
	social_chat_input.placeholder_text = "بانتظار ربط خدمة المحادثة"
	social_chat_input.editable = false
	chat_column.add_child(social_chat_input)

	social_status_label = Label.new()
	social_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	social_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer.add_child(social_status_label)
	_show_social_tab("friends")


func _open_social_popup(tab: String = "friends") -> void:
	if not is_instance_valid(social_popup):
		_build_social_popup()
	_show_social_tab(tab)
	social_popup.visible = true
	for panel in [popup, phone_popup, player_popup, group_popup, group_chat_popup]:
		if is_instance_valid(panel):
			panel.visible = false


func _show_social_tab(tab: String) -> void:
	social_active_tab = tab
	if not is_instance_valid(social_friend_list) or not is_instance_valid(social_chat_log):
		return
	for child in social_friend_list.get_children():
		child.queue_free()
	if tab == "friends":
		var empty_friends := Label.new()
		empty_friends.text = "لا توجد قائمة أصدقاء متصلة بعد."
		empty_friends.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		social_friend_list.add_child(empty_friends)
		social_chat_log.text = "اختر صديقًا من القائمة لعرض المحادثة الخاصة."
		social_chat_input.placeholder_text = "المحادثة الخاصة تحتاج اتصال الحسابات"
		social_status_label.text = "تصميم النافذة جاهز؛ قائمة الأصدقاء والرسائل الحقيقية تنتظر ربط خدمة الحسابات."
	else:
		var empty_players := Label.new()
		empty_players.text = "لا توجد قائمة لاعبين متصلين بعد."
		empty_players.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		social_friend_list.add_child(empty_players)
		social_chat_log.text = "ستظهر رسائل المدينة هنا بعد ربط خدمة المحادثة العامة."
		social_chat_input.placeholder_text = "المحادثة العامة غير متصلة بعد"
		social_status_label.text = "واجهة المحادثة العامة موضوعة؛ الإرسال والاستقبال الفعليان لم يُفعّلا بعد."


func _make_hud_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.045, 0.06, 0.88)
	style.border_color = Color(0.72, 0.57, 0.29, 0.82)
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left = 5
	style.content_margin_right = 5
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style

func _make_button(parent: Control, caption: String, section: String) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(126, 34)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 12)
	button.pressed.connect(_on_button_pressed.bind(section))
	parent.add_child(button)
	return button

func _on_button_pressed(section: String) -> void:
	if section == "wallet":
		_open_section("phone")
		return
	if section == "settings":
		_open_section("settings")
		return
	_open_section(section)

func _open_section(section: String) -> void:
	if not SECTIONS.has(section):
		return
	if section == "phone":
		_open_vehicle_store_phone()
		return
	if section == "social":
		_open_social_popup("friends")
		return
	if section == "chat":
		_open_social_popup("public")
		return
	popup_title.text = str(SECTIONS[section][0])
	popup_body.text = str(SECTIONS[section][1])
	if section == "group":
		_open_group_popup()
		return
	if section == "rewards":
		var daily := main_scene.get_node_or_null("DailyActivities") if is_instance_valid(main_scene) else null
		if is_instance_valid(daily) and is_instance_valid(daily.get("root_panel")):
			daily.root_panel.visible = true
			popup_body.text += "\nتم فتح لوحة الأنشطة اليومية الموجودة في اللعبة."
	if section == "map":
		var city_map := main_scene.get_node_or_null("CityMapHUD/CityMap") if is_instance_valid(main_scene) else null
		if is_instance_valid(city_map):
			for method_name in ["open_map", "show_map", "toggle_map", "_toggle_map"]:
				if city_map.has_method(method_name):
					city_map.call(method_name)
					break
	popup.visible = true

func _open_vehicle_store_phone() -> void:
	if is_instance_valid(popup):
		popup.visible = false
	if not is_instance_valid(phone_popup):
		_build_vehicle_store_phone()
	_refresh_vehicle_store_phone()
	phone_popup.visible = true

func _build_vehicle_store_phone() -> void:
	phone_popup = PanelContainer.new()
	phone_popup.name = "VehicleStorePhone"
	# الهاتف لوحة جانبية عمودية ملتصقة باليمين، وتترك أكبر مساحة ممكنة للمدينة.
	var viewport_width := get_viewport().get_visible_rect().size.x
	var panel_width := clampf(viewport_width * 0.42, 220.0, 300.0)
	phone_popup.anchor_left = 1.0
	phone_popup.anchor_right = 1.0
	phone_popup.anchor_top = 0.02
	phone_popup.anchor_bottom = 0.98
	phone_popup.offset_left = -panel_width - 7.0
	phone_popup.offset_right = -7.0
	phone_popup.offset_top = 0.0
	phone_popup.offset_bottom = 0.0
	phone_popup.add_theme_stylebox_override("panel", _make_hud_panel_style())
	phone_popup.visible = false
	phone_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(phone_popup)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	phone_popup.add_child(content)
	var header := HBoxContainer.new()
	content.add_child(header)
	var heading := Label.new()
	heading.text = "هاتف اللاعب — متجر المركبات"
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 20)
	header.add_child(heading)
	var close_phone := Button.new()
	close_phone.text = "✕"
	close_phone.custom_minimum_size = Vector2(38, 34)
	close_phone.pressed.connect(func(): phone_popup.visible = false)
	header.add_child(close_phone)
	var wallet_line := Label.new()
	wallet_line.name = "VehicleStoreWalletLine"
	wallet_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(wallet_line)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)
	vehicle_store_list = VBoxContainer.new()
	vehicle_store_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vehicle_store_list)
	vehicle_store_status = Label.new()
	vehicle_store_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(vehicle_store_status)
	var close_button := Button.new()
	close_button.text = "إغلاق الهاتف"
	close_button.pressed.connect(func(): phone_popup.visible = false)
	content.add_child(close_button)

func _refresh_vehicle_store_phone() -> void:
	if not is_instance_valid(vehicle_store_list):
		return
	for child in vehicle_store_list.get_children():
		child.queue_free()
	var catalog: Dictionary = VehicleStoreManager.get_catalog()
	var owned: Array = VehicleStoreManager.get_owned_vehicles()
	var selected := VehicleStoreManager.get_selected_vehicle_id()
	for vehicle_id in catalog:
		var offer: Dictionary = catalog[vehicle_id]
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 3)
		vehicle_store_list.add_child(row)
		var label := Label.new()
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var price := int(offer.get("price", -1))
		var currency := str(offer.get("currency", "money"))
		var currency_name := "جوهرة" if currency == "gems" else "رقاقة" if currency == "chips" else "جنيه"
		var status := "مملوكة" if owned.has(vehicle_id) else ("السعر لم يعتمد بعد" if price < 0 else ("مجانية" if price == 0 else "%d %s" % [price, currency_name]))
		if selected == str(vehicle_id):
			status += " • مختارة"
		label.text = "%s — %s — %s" % [str(offer.get("name", vehicle_id)), str(offer.get("country", "")), status]
		row.add_child(label)
		var action := Button.new()
		action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if owned.has(vehicle_id):
			action.text = "المركبة المختارة" if selected == str(vehicle_id) else "اختيار المركبة"
			action.disabled = selected == str(vehicle_id)
			action.pressed.connect(_select_vehicle_from_phone.bind(str(vehicle_id)))
		else:
			action.text = "شراء" if price >= 0 else "غير متاح حتى اعتماد السعر"
			action.disabled = price < 0
			action.pressed.connect(_buy_vehicle_from_phone.bind(str(vehicle_id)))
		row.add_child(action)
	if owned.has("horus_2030"):
		var colors_heading := Label.new()
		colors_heading.text = "ألوان Horus 2030"
		colors_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vehicle_store_list.add_child(colors_heading)
		var owned_colors: Array = VehicleStoreManager.get_owned_horus_colors()
		for color_id in VehicleStoreManager.get_horus_colors():
			var color: Dictionary = VehicleStoreManager.get_horus_colors()[color_id]
			var color_button := Button.new()
			var price := int(color.get("price", -1))
			if owned_colors.has(color_id):
				color_button.text = "%s — مملوك / اختيار" % str(color.get("name", color_id))
				color_button.pressed.connect(_select_horus_color_from_phone.bind(str(color_id)))
			else:
				color_button.text = "شراء %s — %d جوهرة" % [str(color.get("name", color_id)), price]
				color_button.pressed.connect(_buy_horus_color_from_phone.bind(str(color_id)))
			vehicle_store_list.add_child(color_button)
	var wallet_line := phone_popup.find_child("VehicleStoreWalletLine", true, false) as Label
	if is_instance_valid(wallet_line):
		wallet_line.text = "المال: %d   الرقائق: %d   الجواهر: %d" % [
			WalletManager.get_balance("money"),
			WalletManager.get_balance("chips"),
			WalletManager.get_balance("gems")
		]

func _buy_vehicle_from_phone(vehicle_id: String) -> void:
	if VehicleStoreManager.purchase_vehicle(vehicle_id):
		vehicle_store_status.text = "تم الشراء وحفظ الملكية والخصم معًا."
	else:
		vehicle_store_status.text = "لم يتم الشراء: تحقق من السعر المعتمد والرصيد والملكية."
	_refresh_vehicle_store_phone()
	_refresh_wallet()

func _select_vehicle_from_phone(vehicle_id: String) -> void:
	if VehicleStoreManager.select_vehicle(vehicle_id):
		vehicle_store_status.text = "تم اختيار المركبة. ستُستخدم عند الاستدعاء التالي."
	else:
		vehicle_store_status.text = "تعذر اختيار مركبة غير مملوكة."
	_refresh_vehicle_store_phone()

func _buy_horus_color_from_phone(color_id: String) -> void:
	if VehicleStoreManager.purchase_horus_color(color_id):
		vehicle_store_status.text = "تم شراء اللون وحفظه."
	else:
		vehicle_store_status.text = "لم يتم شراء اللون: تحقق من امتلاك Horus والرصيد."
	_refresh_vehicle_store_phone()
	_refresh_wallet()

func _select_horus_color_from_phone(color_id: String) -> void:
	if VehicleStoreManager.select_horus_color(color_id):
		vehicle_store_status.text = "تم اختيار اللون المملوك."
	else:
		vehicle_store_status.text = "لا يمكن اختيار لون غير مملوك."
	_refresh_vehicle_store_phone()

func _refresh_wallet() -> void:
	if not is_instance_valid(mission_manager):
		return
	if is_instance_valid(money_label):
		money_label.text = "ذهب: %d  +" % floori(float(mission_manager.get("money")))
	if is_instance_valid(chips_label):
		chips_label.text = "رقائق: %d  +" % floori(float(mission_manager.get("chips")))
	if is_instance_valid(gems_label):
		gems_label.text = "جواهر: %d" % WalletManager.get_balance("gems")


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
	close.text = "✕"
	close.custom_minimum_size = Vector2(38, 34)
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
	var header := HBoxContainer.new()
	box.add_child(header)
	var heading := Label.new()
	heading.text = "💬 محادثة المجموعة"
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 22)
	header.add_child(heading)
	var close_top := Button.new()
	close_top.text = "✕"
	close_top.custom_minimum_size = Vector2(38, 34)
	close_top.pressed.connect(func(): group_chat_popup.visible = false)
	header.add_child(close_top)
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
