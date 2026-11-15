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

var social_chat_panel: PanelContainer
var social_chat_log: RichTextLabel
var social_chat_input: LineEdit
var social_chat_status: Label
var social_chat_channel := "العامة"
var social_chat_unread := false
var social_friends_box: VBoxContainer
var friend_search_input: LineEdit
var selected_friend_code := ""
var selected_friend_conversation_id := ""
var social_group_create_button: Button

const GROUP_MAX_MEMBERS := 4
const GROUP_CHAT_MAX_LENGTH := 300

const SECTIONS := {
	"profile": ["الملف الشخصي", "عرض مستوى اللاعب وخبرته وإعدادات الحساب والشخصية."],
	"missions": ["المهام والإنجازات", "تابع مهام المدينة والوظائف والإنجازات اليومية. أكمل النشاط من موقعه داخل المدينة."],
	"rewards": ["المكافآت اليومية", "راجع الأنشطة اليومية واستلم مكافآتك بعد إكمال شروطها."],
	"events": ["مركز الفعاليات", "الفعاليات المخطط لها: مهرجان الحيوانات لمدة 7 أيام، حفلات اللاعبين، وتحديات المدينة. ستظهر مواعيد الفعاليات ومؤقتاتها ومكافآتها عند تفعيل نظام الفعاليات المتصل."],
	"pass": ["تذكرة الموسم", "تذكرة شهرية بجوائز رئيسية متتابعة: شخصية، ثم زي، ثم مركبة، ثم حيوان أليف. تفاصيل الموسم ومكافآته تُعرض عند تفعيل نظام المواسم."],
	"phone": ["هاتف اللاعب", "متجر المركبات وإدارة المركبة المختارة."],
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
	_build_social_chat_panel()
	if not SocialChatManager.operation_completed.is_connected(_on_social_operation_completed):
		SocialChatManager.operation_completed.connect(_on_social_operation_completed)
	if not SocialChatManager.operation_failed.is_connected(_on_social_operation_failed):
		SocialChatManager.operation_failed.connect(_on_social_operation_failed)
	if AuthManager.is_authenticated():
		_refresh_social_friends()
	else:
		AuthManager.authenticated.connect(_on_social_authenticated)
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
	gems_label = _make_button(top, "جواهر: 0", "wallet")

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
	_make_button(right, "📱 الهاتف", "phone")
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
		_open_section("phone")
		return
	if section == "settings":
		_open_section("settings")
		return
	_open_section(section)

func _open_section(section: String) -> void:
	if not SECTIONS.has(section):
		return
	if section == "chat" or section == "social":
		_open_social_chat_panel()
		return
	if section == "phone":
		_open_vehicle_store_phone()
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
	phone_popup.anchor_left = 0.5
	phone_popup.anchor_right = 0.5
	phone_popup.anchor_top = 0.5
	phone_popup.anchor_bottom = 0.5
	phone_popup.offset_left = -190
	phone_popup.offset_right = 190
	phone_popup.offset_top = -285
	phone_popup.offset_bottom = 285
	phone_popup.visible = false
	phone_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(phone_popup)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	phone_popup.add_child(content)
	var heading := Label.new()
	heading.text = "هاتف اللاعب — متجر المركبات"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 20)
	content.add_child(heading)
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
		money_label.text = "ذهب: %d  +" % int(mission_manager.get("money"))
	if is_instance_valid(chips_label):
		chips_label.text = "رقائق: %d  +" % int(mission_manager.get("chips"))
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


func _build_social_chat_panel() -> void:
	# نافذة موحدة وثابتة على يمين الشاشة؛ تترك مساحة المدينة وأزرار الحركة ظاهرة.
	var dock := Button.new()
	dock.name = "PersistentSocialChatButton"
	dock.text = "💬"
	dock.tooltip_text = "فتح الأصدقاء والمحادثات"
	dock.custom_minimum_size = Vector2(54, 54)
	dock.anchor_left = 1.0
	dock.anchor_right = 1.0
	dock.anchor_top = 0.48
	dock.anchor_bottom = 0.48
	dock.offset_left = -68
	dock.offset_right = -12
	dock.offset_top = -27
	dock.offset_bottom = 27
	dock.pressed.connect(_open_social_chat_panel)
	root.add_child(dock)

	social_chat_panel = PanelContainer.new()
	social_chat_panel.name = "FriendsAndChatPanel"
	social_chat_panel.anchor_left = 1.0
	social_chat_panel.anchor_right = 1.0
	social_chat_panel.anchor_top = 0.06
	social_chat_panel.anchor_bottom = 0.94
	social_chat_panel.offset_left = -360
	social_chat_panel.offset_right = -8
	social_chat_panel.visible = false
	social_chat_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.035, 0.055, 0.075, 0.97)
	panel_style.border_color = Color(0.72, 0.55, 0.25, 0.95)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(16)
	panel_style.content_margin_left = 10
	panel_style.content_margin_right = 10
	panel_style.content_margin_top = 10
	panel_style.content_margin_bottom = 10
	social_chat_panel.add_theme_stylebox_override("panel", panel_style)
	root.add_child(social_chat_panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 7)
	social_chat_panel.add_child(layout)
	var header := HBoxContainer.new()
	layout.add_child(header)
	var heading := Label.new()
	heading.text = "𓂀 الأصدقاء والمحادثات"
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_color_override("font_color", Color(0.92, 0.76, 0.42))
	header.add_child(heading)
	var close := Button.new()
	close.text = "✕"
	close.custom_minimum_size = Vector2(38, 36)
	close.pressed.connect(func(): social_chat_panel.visible = false)
	header.add_child(close)

	var channels := HBoxContainer.new()
	channels.add_theme_constant_override("separation", 3)
	layout.add_child(channels)
	for channel in ["الأصدقاء", "المجموعة", "العامة"]:
		var channel_button := Button.new()
		channel_button.text = channel
		channel_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		channel_button.custom_minimum_size.y = 38
		channel_button.add_theme_font_size_override("font_size", 11)
		channel_button.pressed.connect(_select_social_chat_channel.bind(channel))
		channels.add_child(channel_button)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 6)
	layout.add_child(body)
	var friends_column := VBoxContainer.new()
	friends_column.custom_minimum_size.x = 104
	friends_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(friends_column)
	var friends_heading := Label.new()
	friends_heading.text = "👥 الأصدقاء"
	friends_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	friends_column.add_child(friends_heading)
	friend_search_input = LineEdit.new()
	friend_search_input.name = "FriendSearchInput"
	friend_search_input.placeholder_text = "رمز اللاعب (10)"
	friend_search_input.add_theme_font_size_override("font_size", 11)
	friends_column.add_child(friend_search_input)
	var add_friend_button := Button.new()
	add_friend_button.text = "إرسال طلب"
	add_friend_button.pressed.connect(_send_friend_request_from_search)
	friends_column.add_child(add_friend_button)
	var refresh_friends_button := Button.new()
	refresh_friends_button.text = "تحديث"
	refresh_friends_button.pressed.connect(_refresh_social_friends)
	friends_column.add_child(refresh_friends_button)
	var friends_scroll := ScrollContainer.new()
	friends_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	friends_column.add_child(friends_scroll)
	social_friends_box = VBoxContainer.new()
	social_friends_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	friends_scroll.add_child(social_friends_box)
	var friends_placeholder := Label.new()
	friends_placeholder.text = "سجّل الدخول لعرض الأصدقاء"
	friends_placeholder.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	friends_placeholder.add_theme_font_size_override("font_size", 11)
	social_friends_box.add_child(friends_placeholder)

	var conversation := VBoxContainer.new()
	conversation.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	conversation.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(conversation)
	social_chat_status = Label.new()
	social_chat_status.text = "غير متصل بالخادم — عرض تجريبي للواجهة"
	social_chat_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	social_chat_status.add_theme_font_size_override("font_size", 10)
	social_chat_status.add_theme_color_override("font_color", Color(0.95, 0.72, 0.35))
	conversation.add_child(social_chat_status)
	social_group_create_button = Button.new()
	social_group_create_button.text = "إنشاء مجموعة (حتى 4 لاعبين)"
	social_group_create_button.pressed.connect(_create_social_group)
	social_group_create_button.visible = false
	conversation.add_child(social_group_create_button)
	var invite_group_button := Button.new()
	invite_group_button.text = "دعوة الصديق المحدد للمجموعة"
	invite_group_button.pressed.connect(_invite_selected_friend_to_group)
	invite_group_button.visible = false
	invite_group_button.name = "InviteSelectedFriendToGroup"
	conversation.add_child(invite_group_button)
	social_chat_log = RichTextLabel.new()
	social_chat_log.bbcode_enabled = true
	social_chat_log.scroll_following = true
	social_chat_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	social_chat_log.text = "[color=gray]لا توجد رسائل متصلة بعد. ستظهر الرسائل عند ربط القناة بالخادم.[/color]"
	conversation.add_child(social_chat_log)
	social_chat_input = LineEdit.new()
	social_chat_input.placeholder_text = "اكتب رسالة..."
	social_chat_input.add_theme_font_size_override("font_size", 12)
	social_chat_input.text_submitted.connect(_submit_social_chat_message)
	conversation.add_child(social_chat_input)
	var send := Button.new()
	send.text = "إرسال"
	send.custom_minimum_size.y = 38
	send.pressed.connect(func(): _submit_social_chat_message(social_chat_input.text))
	conversation.add_child(send)

	var emoji_row := HBoxContainer.new()
	emoji_row.add_theme_constant_override("separation", 3)
	layout.add_child(emoji_row)
	for emoji in ["😀", "😂", "😍", "❤️", "👍", "🎉", "👑"]:
		var emoji_button := Button.new()
		emoji_button.text = emoji
		emoji_button.custom_minimum_size = Vector2(38, 34)
		emoji_button.pressed.connect(_insert_social_chat_emoji.bind(emoji))
		emoji_row.add_child(emoji_button)


func _open_social_chat_panel() -> void:
	if not is_instance_valid(social_chat_panel):
		return
	social_chat_panel.visible = true
	if AuthManager.is_authenticated():
		_refresh_social_friends()
		SocialChatManager.get_chat_group()
	if is_instance_valid(social_chat_input):
		social_chat_input.grab_focus()


func _on_social_authenticated(_user_id: String, _email: String) -> void:
	_refresh_social_friends()
	SocialChatManager.get_chat_group()


func _refresh_social_friends() -> void:
	if AuthManager.is_authenticated():
		SocialChatManager.list_friends()


func _send_friend_request_from_search() -> void:
	if not is_instance_valid(friend_search_input):
		return
	var code := friend_search_input.text.strip_edges().to_upper()
	if code.length() != 10:
		social_chat_status.text = "أدخل رمز اللاعب المكوّن من 10 أحرف."
		return
	SocialChatManager.send_friend_request(code)


func _on_social_friend_selected(player_code: String) -> void:
	selected_friend_code = player_code
	selected_friend_conversation_id = ""
	social_chat_log.clear()
	social_chat_status.text = "جارٍ فتح محادثة الصديق..."
	SocialChatManager.open_direct_conversation(player_code)


func _on_social_operation_completed(action: String, data: Variant) -> void:
	match action:
		"friends_list":
			for child in social_friends_box.get_children():
				child.queue_free()
			if data is Array:
				for friend in data:
					if not friend is Dictionary:
						continue
					var code := str(friend.get("player_code", ""))
					var display_name := str(friend.get("display_name", "صديق"))
					var friend_button := Button.new()
					friend_button.text = display_name.substr(0, 18) + "\n" + code
					friend_button.custom_minimum_size.y = 48
					friend_button.pressed.connect(_on_social_friend_selected.bind(code))
					social_friends_box.add_child(friend_button)
			if social_friends_box.get_child_count() == 0:
				var empty_label := Label.new()
				empty_label.text = "لا يوجد أصدقاء بعد"
				social_friends_box.add_child(empty_label)
			social_chat_status.text = "تم تحميل قائمة الأصدقاء من الخادم."
		"friend_request":
			social_chat_status.text = "نتيجة طلب الصداقة: " + str(data)
			if str(data) == "sent":
				friend_search_input.clear()
				_refresh_social_friends()
		"direct_open":
			if data is Array and not data.is_empty() and data[0] is Dictionary:
				var result: Dictionary = data[0]
				if bool(result.get("success", false)):
					selected_friend_conversation_id = str(result.get("conversation_id", ""))
					SocialChatManager.read_direct_messages(selected_friend_conversation_id)
				else:
					social_chat_status.text = "تعذر فتح المحادثة: " + str(result.get("error_code", "unknown"))
		"direct_read":
			social_chat_log.clear()
			if data is Array:
				var ordered: Array = data.duplicate()
				ordered.reverse()
				for item in ordered:
					if not item is Dictionary:
						continue
					var sender := "أنت" if bool(item.get("sender_is_me", false)) else "الصديق"
					var body := str(item.get("body", "")).replace("[", "(").replace("]", ")")
					social_chat_log.append_text("[color=gold][" + sender + "][/color] " + body + "\\n")
			social_chat_status.text = "محادثة الأصدقاء متصلة."
		"direct_send":
			if data is Array and not data.is_empty() and data[0] is Dictionary and bool(data[0].get("success", false)):
				social_chat_input.clear()
				SocialChatManager.read_direct_messages(selected_friend_conversation_id)
			else:
				social_chat_status.text = "لم تُرسل الرسالة؛ تحقق من الصداقة والاتصال."
		"group_create":
			if data is Array and not data.is_empty() and data[0] is Dictionary and bool(data[0].get("success", false)):
				social_chat_status.text = "تم إنشاء المجموعة على الخادم."
				SocialChatManager.get_chat_group()
			else:
				social_chat_status.text = "تعذر إنشاء المجموعة."
		"group_info":
			group_members.clear()
			if data is Array:
				for member in data:
					if member is Dictionary:
						group_members.append({"player_id": str(member.get("player_code", "")), "display_name": str(member.get("display_name", "لاعب")), "is_leader": bool(member.get("is_leader", false))})
			if group_members.is_empty():
				group_members = [{"player_id":"local_leader", "display_name":"أنت", "is_leader":true}]
				if is_instance_valid(social_group_create_button):
					social_group_create_button.visible = (social_chat_channel == "المجموعة")
				social_chat_status.text = "لا توجد مجموعة متصلة. أنشئ مجموعتك للبدء."
			else:
				if is_instance_valid(social_group_create_button):
					social_group_create_button.visible = false
				social_chat_status.text = "تم تحميل أعضاء المجموعة من الخادم."
			_refresh_group_popup()
		"group_invite":
			social_chat_status.text = "نتيجة دعوة المجموعة: " + str(data)
			SocialChatManager.get_chat_group()
		"chat_send":
			if data is Array and not data.is_empty() and data[0] is Dictionary and bool(data[0].get("success", false)):
				social_chat_input.clear()
				SocialChatManager.read_chat_messages("group" if social_chat_channel == "المجموعة" else "public")
			else:
				var reason := str(data[0].get("error_code", "unknown")) if data is Array and not data.is_empty() and data[0] is Dictionary else "unknown"
				social_chat_status.text = "لم تُرسل الرسالة: " + reason
		"chat_read":
			social_chat_log.clear()
			if data is Array:
				var ordered_chat: Array = data.duplicate()
				ordered_chat.reverse()
				for item in ordered_chat:
					if item is Dictionary:
						var sender_name := "أنت" if bool(item.get("sender_is_me", false)) else str(item.get("sender_name", "لاعب"))
					var safe_body := str(item.get("body", "")).replace("[", "(").replace("]", ")")
						social_chat_log.append_text("[color=gold][" + sender_name + "][/color] " + safe_body + "\n")
			social_chat_status.text = "المحادثة متصلة بالخادم."
		_:
			social_chat_status.text = "اكتملت العملية: " + action


func _on_social_operation_failed(action: String, message: String) -> void:
	social_chat_status.text = "تعذر تنفيذ " + action + ": " + message


func _select_social_chat_channel(channel: String) -> void:
	if not ["الأصدقاء", "المجموعة", "العامة"].has(channel):
		return
	social_chat_channel = channel
	selected_friend_conversation_id = ""
	if is_instance_valid(social_chat_log):
		social_chat_log.clear()
	if channel == "الأصدقاء":
		_refresh_social_friends()
		social_chat_status.text = "اختر صديقًا من القائمة لفتح محادثته الخاصة."
	elif channel == "المجموعة":
		social_chat_status.text = "جارٍ تحميل المجموعة ورسائلها..."
		if is_instance_valid(social_group_create_button):
			social_group_create_button.visible = group_members.size() <= 1
		SocialChatManager.get_chat_group()
		SocialChatManager.read_chat_messages("group")
	else:
		if is_instance_valid(social_group_create_button):
			social_group_create_button.visible = false
		social_chat_status.text = "جارٍ تحميل الدردشة العامة..."
		SocialChatManager.read_chat_messages("public")


func _insert_social_chat_emoji(emoji: String) -> void:
	if not is_instance_valid(social_chat_input):
		return
	social_chat_input.text += emoji
	social_chat_input.caret_column = social_chat_input.text.length()
	social_chat_input.grab_focus()


func _submit_social_chat_message(raw_message: String) -> void:
	var message := raw_message.strip_edges()
	if message.is_empty():
		return
	if message.length() > GROUP_CHAT_MAX_LENGTH:
		message = message.substr(0, GROUP_CHAT_MAX_LENGTH)
	if social_chat_channel == "الأصدقاء":
		if selected_friend_conversation_id.is_empty():
			social_chat_status.text = "اختر صديقًا أولًا لفتح محادثته."
			return
		SocialChatManager.send_direct_message(selected_friend_conversation_id, message)
	elif social_chat_channel == "المجموعة":
		SocialChatManager.send_chat_message("group", message)
	else:
		SocialChatManager.send_chat_message("public", message)


func _create_social_group() -> void:
	SocialChatManager.create_chat_group()


func _invite_selected_friend_to_group() -> void:
	if selected_friend_code.is_empty():
		social_chat_status.text = "اختر صديقًا أولًا من قائمة الأصدقاء."
		return
	SocialChatManager.invite_chat_group_member(selected_friend_code)


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
