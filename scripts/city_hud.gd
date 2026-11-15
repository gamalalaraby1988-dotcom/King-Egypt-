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
signal group_gather_invite_requested(position: Vector3)
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
var player_block_button: Button
var player_report_reason: OptionButton
var player_report_details: LineEdit
var blocked_players_box: VBoxContainer
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
var local_player_code := ""
var _pending_direct_open_player_code := ""
var _group_channel_button: Button
var _friends_channel_button: Button
var _unread_group_messages := 0
var _unread_direct_by_friend: Dictionary = {}
var _friend_buttons: Dictionary = {}
var _friend_base_labels: Dictionary = {}
var _direct_conversation_to_friend: Dictionary = {}
var _friend_to_conversation: Dictionary = {}
var selected_friend_conversation_id := ""
var social_group_create_button: Button
var social_group_invite_button: Button
var social_invites_box: VBoxContainer
var social_chat_dock_button: Button
var _seen_realtime_message_ids: Dictionary = {}
var _pending_group_invite_response_id := ""
var invitation_overlay: Control
var _apartment_invite_mode := false
var moderation_button: Button
var moderation_panel: PanelContainer
var moderation_reports_box: VBoxContainer
var moderation_status_label: Label
var display_name_panel: PanelContainer
var display_name_input: LineEdit
var display_name_status: Label

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
	_build_display_name_panel()
	_build_player_interaction_popup()
	_build_group_popup()
	_build_group_chat_popup()
	_build_social_chat_panel()
	_build_invitation_overlay()
	_build_moderation_panel()
	if not SocialChatManager.operation_completed.is_connected(_on_social_operation_completed):
		SocialChatManager.operation_completed.connect(_on_social_operation_completed)
	if not SocialChatManager.operation_failed.is_connected(_on_social_operation_failed):
		SocialChatManager.operation_failed.connect(_on_social_operation_failed)
	if not SocialChatManager.realtime_event.is_connected(_on_social_realtime_event):
		SocialChatManager.realtime_event.connect(_on_social_realtime_event)
	if not SocialChatManager.realtime_status_changed.is_connected(_on_social_realtime_status):
		SocialChatManager.realtime_status_changed.connect(_on_social_realtime_status)
	if not AuthManager.session_changed.is_connected(_on_social_account_session_changed):
		AuthManager.session_changed.connect(_on_social_account_session_changed)
	if AuthManager.is_authenticated():
		_on_social_authenticated(AuthManager.get_authenticated_user_id(), AuthManager.get_authenticated_email())
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
	if _apartment_invite_mode and not _is_inside_private_apartment():
		_apartment_invite_mode = false
	_update_group_gather_visibility()

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
	if section == "profile":
		_open_display_name_panel()
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
	player_popup.offset_top = -235
	player_popup.offset_bottom = 235
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
	player_block_button = Button.new()
	player_block_button.name = "BlockSelectedPlayer"
	player_block_button.text = "حظر اللاعب"
	player_block_button.pressed.connect(_on_player_block)
	content.add_child(player_block_button)
	player_report_reason = OptionButton.new()
	player_report_reason.add_item("مضايقة أو إساءة", 0)
	player_report_reason.add_item("رسائل مزعجة / سبام", 1)
	player_report_reason.add_item("اسم غير مناسب", 2)
	player_report_reason.add_item("غش أو استغلال", 3)
	player_report_reason.add_item("سبب آخر", 4)
	content.add_child(player_report_reason)
	player_report_details = LineEdit.new()
	player_report_details.placeholder_text = "تفاصيل إضافية (اختياري)"
	content.add_child(player_report_details)
	var report := Button.new()
	report.text = "⚠ إرسال البلاغ"
	report.pressed.connect(_on_player_report)
	content.add_child(report)
	player_action_status = Label.new()
	player_action_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_action_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	player_action_status.add_theme_color_override("font_color", Color(1.0, 0.91, 0.69))
	content.add_child(player_action_status)


func open_player_interaction(player_data: Dictionary) -> void:
	# البيانات المتوقعة: player_id, display_name, level, account_age, avatar_text.
	selected_player_id = str(player_data.get("player_code", player_data.get("player_id", ""))).strip_edges().to_upper()
	if not SocialChatManager.is_valid_player_code(selected_player_id):
		selected_player_id = ""
	if is_instance_valid(player_block_button):
		player_block_button.visible = not selected_player_id.is_empty()
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


func _on_player_block() -> void:
	if not _has_selected_player():
		player_action_status.text = "تعذر حظر اللاعب: رمز اللاعب غير صالح."
		return
	SocialChatManager.block_player(selected_player_id)
	player_action_status.text = "جارٍ إرسال طلب الحظر إلى الخادم..."


func _on_player_report() -> void:
	if not _has_selected_player():
		player_action_status.text = "تعذر تجهيز البلاغ: رمز اللاعب غير متاح."
		return
	player_report_requested.emit(selected_player_id)
	var reasons := ["harassment", "spam", "inappropriate_name", "cheating", "other"]
	var reason := reasons[player_report_reason.selected] if is_instance_valid(player_report_reason) else "other"
	var details := player_report_details.text if is_instance_valid(player_report_details) else ""
	SocialChatManager.report_player(selected_player_id, reason, details)
	player_action_status.text = "جارٍ إرسال البلاغ إلى خادم الإشراف..."


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
	group_meeting_point_button.text = "📣 دعوة للتجمع"
	group_meeting_point_button.custom_minimum_size.y = 44
	group_meeting_point_button.pressed.connect(_request_group_gather_invite)
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
		group_meeting_point_button.visible = local_is_leader and has_other_members and not _is_inside_private_apartment()
	if is_instance_valid(group_follow_button):
		group_follow_button.visible = not local_is_leader and has_other_members
	if (local_is_leader or not has_other_members) and group_follow_enabled:
		group_follow_enabled = false
		group_follow_mode_requested.emit(false)
		if is_instance_valid(group_follow_button):
			group_follow_button.text = "🚶 التحرك مع القائد"


func _is_inside_private_apartment() -> bool:
	return is_instance_valid(main_scene) and main_scene.has_method("is_player_inside_private_apartment") and bool(main_scene.call("is_player_inside_private_apartment"))


func _update_group_gather_visibility() -> void:
	if not is_instance_valid(group_meeting_point_button):
		return
	group_meeting_point_button.visible = _is_local_group_leader() and group_members.size() > 1 and not _is_inside_private_apartment()


func _request_group_gather_invite() -> void:
	if not _is_local_group_leader():
		group_meeting_status.text = "دعوة التجمع متاحة لقائد المجموعة فقط."
		return
	if group_members.size() < 2:
		group_meeting_status.text = "تحتاج المجموعة إلى القائد وعضو واحد على الأقل."
		return
	if _is_inside_private_apartment():
		group_meeting_status.text = "لا يمكن إرسال دعوة التجمع من داخل الشقة."
		_update_group_gather_visibility()
		return
	var player := main_scene.get_node_or_null("Player") as Node3D if is_instance_valid(main_scene) else null
	if not is_instance_valid(player):
		group_meeting_status.text = "تعذر تحديد موقع القائد الحالي."
		return
	group_gather_invite_requested.emit(player.global_position)
	group_meeting_status.text = "لم تُرسل الدعوة بعد: خدمة التجمع بين الأجهزة لم تُربط بالخادم حتى الآن."


func _is_local_group_leader() -> bool:
	if group_members.is_empty():
		return false
	var leader: Dictionary = group_members[0]
	var leader_id := str(leader.get("player_id", ""))
	return (leader_id == "local_leader" or (not local_player_code.is_empty() and leader_id == local_player_code)) and bool(leader.get("is_leader", false))


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


func _build_invitation_overlay() -> void:
	var overlay_script := load("res://scripts/invitation_overlay.gd") as Script
	if overlay_script == null:
		push_warning("تعذر تحميل نافذة الدعوات الموحدة.")
		return
	invitation_overlay = Control.new()
	invitation_overlay.name = "UnifiedInvitationOverlay"
	invitation_overlay.set_script(overlay_script)
	root.add_child(invitation_overlay)
	invitation_overlay.connect("invitation_accepted", Callable(self, "_on_invitation_accepted"))
	invitation_overlay.connect("invitation_declined", Callable(self, "_on_invitation_declined"))
	invitation_overlay.connect("invitation_expired", Callable(self, "_on_invitation_expired"))


func _build_social_chat_panel() -> void:
	# نافذة موحدة وثابتة على يمين الشاشة؛ تترك مساحة المدينة وأزرار الحركة ظاهرة.
	social_chat_dock_button = Button.new()
	var dock := social_chat_dock_button
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
	panel_style.bg_color = Color(0.035, 0.055, 0.075, 0.84)
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
	close.pressed.connect(func():
		social_chat_panel.visible = false
		_apartment_invite_mode = false
	)
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
		if channel == "الأصدقاء":
			_friends_channel_button = channel_button
		elif channel == "المجموعة":
			_group_channel_button = channel_button

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
	var blocked_heading := Label.new()
	blocked_heading.text = "🚫 المحظورون"
	blocked_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	friends_column.add_child(blocked_heading)
	var blocked_refresh := Button.new()
	blocked_refresh.text = "تحديث المحظورين"
	blocked_refresh.pressed.connect(_refresh_blocked_players)
	friends_column.add_child(blocked_refresh)
	var blocked_scroll := ScrollContainer.new()
	blocked_scroll.custom_minimum_size.y = 76
	friends_column.add_child(blocked_scroll)
	blocked_players_box = VBoxContainer.new()
	blocked_players_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	blocked_scroll.add_child(blocked_players_box)
	var blocked_placeholder := Label.new()
	blocked_placeholder.text = "لا توجد بيانات"
	blocked_players_box.add_child(blocked_placeholder)

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
	social_invites_box = VBoxContainer.new()
	social_invites_box.name = "PendingGroupInvitations"
	conversation.add_child(social_invites_box)
	moderation_button = Button.new()
	moderation_button.text = "🛡 لوحة الإشراف"
	moderation_button.visible = false
	moderation_button.pressed.connect(_open_moderation_panel)
	conversation.add_child(moderation_button)
	social_group_create_button = Button.new()
	social_group_create_button.text = "إنشاء مجموعة (حتى 4 لاعبين)"
	social_group_create_button.pressed.connect(_create_social_group)
	social_group_create_button.visible = false
	conversation.add_child(social_group_create_button)
	social_group_invite_button = Button.new()
	social_group_invite_button.name = "InviteSelectedFriendToGroup"
	social_group_invite_button.text = "دعوة الصديق المحدد للمجموعة"
	social_group_invite_button.pressed.connect(_invite_selected_friend_to_group)
	social_group_invite_button.visible = false
	conversation.add_child(social_group_invite_button)
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



func _build_moderation_panel() -> void:
	moderation_panel = PanelContainer.new()
	moderation_panel.name = "SecureModerationPanel"
	moderation_panel.anchor_left = 0.5
	moderation_panel.anchor_right = 0.5
	moderation_panel.anchor_top = 0.5
	moderation_panel.anchor_bottom = 0.5
	moderation_panel.offset_left = -250
	moderation_panel.offset_right = 250
	moderation_panel.offset_top = -285
	moderation_panel.offset_bottom = 285
	moderation_panel.visible = false
	moderation_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(moderation_panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 7)
	moderation_panel.add_child(layout)
	var heading := Label.new()
	heading.text = "🛡 مراجعة بلاغات اللاعبين"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_color_override("font_color", Color(0.92, 0.76, 0.42))
	layout.add_child(heading)
	moderation_status_label = Label.new()
	moderation_status_label.text = "تظهر البلاغات المعلقة وقيد المراجعة للمشرفين المعتمدين فقط."
	moderation_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(moderation_status_label)
	var refresh := Button.new()
	refresh.text = "تحديث البلاغات"
	refresh.pressed.connect(func(): SocialChatManager.list_moderation_reports())
	layout.add_child(refresh)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)
	moderation_reports_box = VBoxContainer.new()
	moderation_reports_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(moderation_reports_box)
	var close := Button.new()
	close.text = "إغلاق لوحة الإشراف"
	close.pressed.connect(func(): moderation_panel.visible = false)
	layout.add_child(close)


func _open_moderation_panel() -> void:
	if not is_instance_valid(moderation_panel) or not is_instance_valid(moderation_button) or not moderation_button.visible:
		return
	moderation_panel.visible = true
	moderation_status_label.text = "جارٍ تحميل البلاغات من الخادم..."
	SocialChatManager.list_moderation_reports()


func _render_moderation_reports(data: Variant) -> void:
	for child in moderation_reports_box.get_children():
		child.queue_free()
	if not data is Array:
		moderation_status_label.text = "لم تصل قائمة البلاغات بصيغة صحيحة."
		return
	for report in data:
		if not report is Dictionary:
			continue
		var report_id := str(report.get("report_id", ""))
		var card := VBoxContainer.new()
		card.add_theme_constant_override("separation", 4)
		moderation_reports_box.add_child(card)
		var reason_names := {
			"harassment": "مضايقة",
			"spam": "رسائل مزعجة",
			"inappropriate_name": "اسم غير مناسب",
			"cheating": "غش",
			"other": "سبب آخر"
		}
		var title := Label.new()
		title.text = "بلاغ: %s — الحالة: %s" % [str(reason_names.get(str(report.get("reason", "")), "سبب آخر")), str(report.get("status", ""))]
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_child(title)
		var people := Label.new()
		people.text = "المبلّغ: %s (%s)\nالمبلّغ ضده: %s (%s)" % [
			str(report.get("reporter_display_name", "لاعب")),
			str(report.get("reporter_player_code", "")),
			str(report.get("reported_display_name", "لاعب")),
			str(report.get("reported_player_code", ""))
		]
		people.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_child(people)
		var details := Label.new()
		details.text = "التفاصيل: " + str(report.get("details", ""))
		details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_child(details)
		var actions := HBoxContainer.new()
		card.add_child(actions)
		var reviewing := Button.new()
		reviewing.text = "بدء المراجعة"
		reviewing.pressed.connect(func(): SocialChatManager.set_moderation_report_status(report_id, "reviewing"))
		actions.add_child(reviewing)
		var resolved := Button.new()
		resolved.text = "تم الحل"
		resolved.pressed.connect(func(): SocialChatManager.set_moderation_report_status(report_id, "resolved"))
		actions.add_child(resolved)
		var dismissed := Button.new()
		dismissed.text = "رفض البلاغ"
		dismissed.pressed.connect(func(): SocialChatManager.set_moderation_report_status(report_id, "dismissed"))
		actions.add_child(dismissed)
		if str(report.get("status", "")) == "reviewing":
			reviewing.disabled = true
	if moderation_reports_box.get_child_count() == 0:
		var empty := Label.new()
		empty.text = "لا توجد بلاغات معلقة أو قيد المراجعة."
		moderation_reports_box.add_child(empty)
	moderation_status_label.text = "عدد البلاغات المعروضة: %d" % moderation_reports_box.get_child_count()


func _build_display_name_panel() -> void:
	display_name_panel = PanelContainer.new()
	display_name_panel.name = "DisplayNamePanel"
	display_name_panel.anchor_left = 0.5
	display_name_panel.anchor_right = 0.5
	display_name_panel.anchor_top = 0.5
	display_name_panel.anchor_bottom = 0.5
	display_name_panel.offset_left = -175
	display_name_panel.offset_right = 175
	display_name_panel.offset_top = -125
	display_name_panel.offset_bottom = 125
	display_name_panel.visible = false
	display_name_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(display_name_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	display_name_panel.add_child(box)
	var heading := Label.new()
	heading.text = "👤 اسم اللاعب"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 21)
	box.add_child(heading)
	display_name_input = LineEdit.new()
	display_name_input.placeholder_text = "اكتب الاسم الجديد (حتى 24 حرفًا)"
	display_name_input.max_length = 24
	box.add_child(display_name_input)
	display_name_status = Label.new()
	display_name_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	display_name_status.text = "يُسمح بتغيير الاسم مرة واحدة يوميًا."
	box.add_child(display_name_status)
	var actions := HBoxContainer.new()
	box.add_child(actions)
	var save := Button.new()
	save.text = "حفظ الاسم"
	save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save.pressed.connect(func(): SocialChatManager.change_my_display_name(display_name_input.text))
	actions.add_child(save)
	var close := Button.new()
	close.text = "إغلاق"
	close.pressed.connect(func(): display_name_panel.visible = false)
	actions.add_child(close)

func _open_display_name_panel() -> void:
	if not is_instance_valid(display_name_panel):
		return
	display_name_panel.visible = true
	if AuthManager.is_authenticated():
		display_name_status.text = "جارٍ تحميل بيانات الاسم من الخادم..."
		SocialChatManager.get_my_display_name()
	else:
		display_name_status.text = "سجّل الدخول أولًا لتغيير اسم اللاعب."

func _open_social_chat_panel() -> void:
	if not is_instance_valid(social_chat_panel):
		return
	social_chat_panel.visible = true
	_refresh_unread_indicators()
	if AuthManager.is_authenticated():
		SocialChatManager.list_chat_group_invites()
		_refresh_blocked_players()
	if is_instance_valid(social_chat_input):
		social_chat_input.grab_focus()


func open_apartment_invite_picker() -> void:
	if not _is_inside_private_apartment():
		social_chat_status.text = "دعوة زيارة الشقة متاحة من داخل الشقة فقط."
		return
	_apartment_invite_mode = true
	_open_social_chat_panel()
	social_chat_status.text = "اختر صديقًا من القائمة لإعداد دعوة زيارة الشقة."
	_refresh_social_friends()


func _on_social_account_session_changed(_previous_user_id: String, current_user_id: String, _generation: int) -> void:
	# The social HUD is account-owned too: never leave the previous account's
	# friends, group, unread counters, or moderation state visible after a switch.
	selected_friend_code = ""
	selected_friend_conversation_id = ""
	_pending_direct_open_player_code = ""
	local_player_code = ""
	_direct_conversation_to_friend.clear()
	_friend_to_conversation.clear()
	_unread_direct_by_friend.clear()
	_unread_group_messages = 0
	_seen_realtime_message_ids.clear()
	pending_group_invites.clear()
	_pending_group_invite_response_id = ""
	_apartment_invite_mode = false
	group_meeting_position = Vector3.ZERO
	group_follow_enabled = false
	for marker_value in group_member_markers.values():
		if is_instance_valid(marker_value):
			marker_value.queue_free()
	group_member_markers.clear()
	if is_instance_valid(invitation_overlay):
		invitation_overlay.call("clear_pending_invitations")
	if is_instance_valid(blocked_players_box):
		for child in blocked_players_box.get_children():
			child.queue_free()
		var blocked_empty := Label.new()
		blocked_empty.text = "سجّل الدخول لعرض قائمة الحظر"
		blocked_players_box.add_child(blocked_empty)
	if is_instance_valid(player_popup):
		player_popup.visible = false
	group_members.clear()
	group_members.append({"player_id": "local_leader", "display_name": "أنت", "is_leader": true})
	_friend_buttons.clear()
	_friend_base_labels.clear()
	for child in social_friends_box.get_children():
		child.queue_free()
	for child in social_invites_box.get_children():
		child.queue_free()
	if is_instance_valid(social_chat_log):
		social_chat_log.clear()
	if is_instance_valid(social_chat_input):
		social_chat_input.clear()
	if is_instance_valid(moderation_button):
		moderation_button.visible = false
	if is_instance_valid(moderation_panel):
		moderation_panel.visible = false
	if is_instance_valid(social_chat_status):
		social_chat_status.text = "جارٍ تجهيز بيانات الحساب..." if not current_user_id.is_empty() else "تم تسجيل الخروج."
	_refresh_unread_indicators()
	_refresh_group_popup()
	if not current_user_id.is_empty() and AuthManager.is_authenticated():
		_on_social_authenticated(current_user_id, AuthManager.get_authenticated_email())


func _on_social_authenticated(_user_id: String, _email: String) -> void:
	SocialChatManager.connect_realtime()
	SocialChatManager.get_realtime_identity()


func _refresh_social_friends() -> void:
	if AuthManager.is_authenticated():
		SocialChatManager.list_friends()
		_refresh_blocked_players()


func _refresh_blocked_players() -> void:
	if AuthManager.is_authenticated():
		SocialChatManager.list_blocked_players()


func _send_friend_request_from_search() -> void:
	if not is_instance_valid(friend_search_input):
		return
	var code := friend_search_input.text.strip_edges().to_upper()
	if code.length() != 10:
		social_chat_status.text = "أدخل رمز اللاعب المكوّن من 10 أحرف."
		return
	SocialChatManager.send_friend_request(code)


func _on_social_friend_selected(player_code: String) -> void:
	if not SocialChatManager._pending_action.is_empty():
		social_chat_status.text = "انتظر اكتمال عملية التواصل الحالية قبل تبديل المحادثة."
		return
	if _apartment_invite_mode:
		_apartment_invite_mode = false
		social_chat_status.text = "تم اختيار الصديق، لكن لم تُرسل دعوة: خدمة دعوات الشقق الخادمية غير موجودة بعد."
		return
	social_chat_channel = "الأصدقاء"
	selected_friend_code = player_code
	_pending_direct_open_player_code = player_code
	selected_friend_conversation_id = ""
	social_chat_log.clear()
	social_chat_status.text = "جارٍ فتح محادثة الصديق..."
	if is_instance_valid(social_group_invite_button):
		social_group_invite_button.visible = (social_chat_channel == "المجموعة")
	SocialChatManager.open_direct_conversation(player_code)


func _on_social_operation_completed(action: String, data: Variant) -> void:
	match action:
		"blocked_list":
			for child in blocked_players_box.get_children():
				child.queue_free()
			if data is Array:
				for blocked in data:
					if not blocked is Dictionary:
						continue
					var code := str(blocked.get("player_code", ""))
					var display_name := str(blocked.get("display_name", "لاعب"))
					var unblock_button := Button.new()
					unblock_button.text = "إلغاء: " + display_name.substr(0, 12)
					unblock_button.pressed.connect(func():
						SocialChatManager.unblock_player(code)
					)
					blocked_players_box.add_child(unblock_button)
			if blocked_players_box.get_child_count() == 0:
				var empty_blocked := Label.new()
				empty_blocked.text = "قائمة الحظر فارغة"
				blocked_players_box.add_child(empty_blocked)
		"unblock_player":
			social_chat_status.text = "نتيجة إلغاء الحظر: " + str(data)
			if str(data) == "unblocked":
				_refresh_blocked_players()
		"report_player":
			player_action_status.text = "نتيجة البلاغ: " + str(data)
			if str(data) == "report_submitted":
				player_popup.visible = false
		"block_player":
			player_action_status.text = "نتيجة الحظر: " + str(data)
			if str(data) == "blocked":
				player_popup.visible = false
				_refresh_blocked_players()
		"friends_list":
			_friend_buttons.clear()
			_friend_base_labels.clear()
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
					_friend_buttons[code] = friend_button
					_friend_base_labels[code] = friend_button.text
					_update_friend_unread_badge(code)
			if social_friends_box.get_child_count() == 0:
				var empty_label := Label.new()
				empty_label.text = "لا يوجد أصدقاء بعد"
				social_friends_box.add_child(empty_label)
			social_chat_status.text = "تم تحميل قائمة الأصدقاء من الخادم."
			SocialChatManager.get_chat_group()
		"display_name_get":
			if is_instance_valid(display_name_status):
				if data is Array and not data.is_empty() and data[0] is Dictionary:
					var profile: Dictionary = data[0]
					display_name_input.text = str(profile.get("display_name", ""))
					display_name_status.text = "يمكنك تغيير الاسم مرة واحدة يوميًا. يعود السماح عند منتصف الليل بتوقيت مصر."
				else:
					display_name_status.text = "تعذر تحميل اسم اللاعب."
		"display_name_change":
			if data is Array and not data.is_empty() and data[0] is Dictionary:
				var result: Dictionary = data[0]
				if bool(result.get("success", false)):
					display_name_input.text = str(result.get("current_display_name", ""))
					display_name_status.text = "تم تغيير الاسم بنجاح. التغيير التالي بعد منتصف الليل بتوقيت مصر."
				else:
					var code := str(result.get("error_code", "unknown"))
					var messages := {
						"daily_limit_reached": "لقد غيّرت اسمك اليوم بالفعل. يمكنك تغييره مجددًا بعد منتصف الليل بتوقيت مصر.",
						"name_unchanged": "هذا هو اسمك الحالي بالفعل.",
						"display_name_taken": "هذا الاسم مستخدم من لاعب آخر. اختر اسمًا مختلفًا.",
						"invalid_display_name": "الاسم غير صالح. استخدم من 1 إلى 24 حرفًا.",
						"authentication_required": "انتهت جلسة الدخول. سجّل الدخول مجددًا.",
						"test_account_not_linked": "حساب اللاعب غير مربوط بعد. أعد تجهيز حساب الاختبار."
					}
					display_name_status.text = str(messages.get(code, "لم يتم تغيير الاسم. حاول مرة أخرى."))
			else:
				display_name_status.text = "تعذر تأكيد تغيير الاسم من الخادم."
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
					if not _pending_direct_open_player_code.is_empty():
						_direct_conversation_to_friend[selected_friend_conversation_id] = _pending_direct_open_player_code
						_friend_to_conversation[_pending_direct_open_player_code] = selected_friend_conversation_id
						_unread_direct_by_friend.erase(_pending_direct_open_player_code)
						_update_friend_unread_badge(_pending_direct_open_player_code)
						_pending_direct_open_player_code = ""
					_refresh_unread_indicators()
					SocialChatManager.subscribe_direct_chat(selected_friend_conversation_id)
					SocialChatManager.read_direct_messages(selected_friend_conversation_id)
				else:
					social_chat_status.text = "تعذر فتح المحادثة: " + str(result.get("error_code", "unknown"))
		"direct_read":
			if social_chat_channel != "الأصدقاء" or selected_friend_conversation_id.is_empty():
				return
			if not selected_friend_code.is_empty():
				_unread_direct_by_friend.erase(selected_friend_code)
				_update_friend_unread_badge(selected_friend_code)
			_refresh_unread_indicators()
			social_chat_log.clear()
			if data is Array:
				var ordered: Array = data.duplicate()
				ordered.reverse()
				for item in ordered:
					if not item is Dictionary:
						continue
					var sender := "أنت" if bool(item.get("sender_is_me", false)) else "الصديق"
					var body := str(item.get("body", "")).replace("[", "(").replace("]", ")")
					social_chat_log.append_text("[color=gold][" + sender + "][/color] " + body + "\n")
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
		"chat_identity":
			local_player_code = ""
			if data is Array and not data.is_empty() and data[0] is Dictionary:
				var identity: Dictionary = data[0]
				var candidate_code := str(identity.get("player_code", "")).strip_edges().to_upper()
				if SocialChatManager.is_valid_player_code(candidate_code):
					local_player_code = candidate_code
					SocialChatManager.set_realtime_player_code(local_player_code)
				else:
					social_chat_status.text = "تعذر التحقق من رمز اللاعب؛ ستظل بقية بيانات التواصل قيد التحميل."
			SocialChatManager.check_moderator_access()
		"moderator_check":
			var allowed := data is bool and data
			if is_instance_valid(moderation_button):
				moderation_button.visible = allowed
			SocialChatManager.list_chat_group_invites()
		"moderation_reports":
			_render_moderation_reports(data)
		"moderation_update":
			moderation_status_label.text = "نتيجة تحديث البلاغ: " + str(data)
			if str(data) == "status_updated":
				SocialChatManager.list_moderation_reports()
		"chat_invites":
			_refresh_social_invite_cards(data)
			SocialChatManager.list_friends()
		"group_info":
			group_members.clear()
			var active_group_id := ""
			if data is Array:
				for member in data:
					if member is Dictionary:
						active_group_id = str(member.get("group_id", active_group_id))
						group_members.append({"player_id": str(member.get("player_code", "")), "display_name": str(member.get("display_name", "لاعب")), "is_leader": bool(member.get("is_leader", false))})
			SocialChatManager.subscribe_group_chat(active_group_id)
			if group_members.is_empty():
				group_members = [{"player_id":"local_leader", "display_name":"أنت", "is_leader":true}]
				if is_instance_valid(social_group_create_button):
					social_group_create_button.visible = (social_chat_channel == "المجموعة")
				if is_instance_valid(social_group_invite_button):
					social_group_invite_button.visible = false
				if social_chat_channel == "المجموعة" and is_instance_valid(social_chat_log):
					social_chat_log.clear()
				social_chat_status.text = "لا توجد مجموعة متصلة. أنشئ مجموعتك للبدء."
			else:
				if is_instance_valid(social_group_create_button):
					social_group_create_button.visible = false
				if is_instance_valid(social_group_invite_button):
					social_group_invite_button.visible = (social_chat_channel == "المجموعة" and not selected_friend_code.is_empty())
				social_chat_status.text = "تم تحميل أعضاء المجموعة من الخادم."
				if social_chat_channel == "المجموعة":
					SocialChatManager.read_chat_messages("group")
			_refresh_group_popup()
		"group_invite":
			social_chat_status.text = "نتيجة دعوة المجموعة: " + str(data)
			SocialChatManager.get_chat_group()
		"group_invite_response":
			social_chat_status.text = "نتيجة الرد على الدعوة: " + str(data)
			if str(data) == "accepted" or str(data) == "declined":
				_remove_social_invite_card(_pending_group_invite_response_id)
				_pending_group_invite_response_id = ""
			if str(data) == "accepted":
				SocialChatManager.get_chat_group()
		"chat_send":
			if data is Array and not data.is_empty() and data[0] is Dictionary and bool(data[0].get("success", false)):
				social_chat_input.clear()
				SocialChatManager.read_chat_messages("group" if social_chat_channel == "المجموعة" else "public")
			else:
				var reason := str(data[0].get("error_code", "unknown")) if data is Array and not data.is_empty() and data[0] is Dictionary else "unknown"
				social_chat_status.text = "لم تُرسل الرسالة: " + reason
		"chat_read":
			if social_chat_channel == "المجموعة":
				_unread_group_messages = 0
				_refresh_unread_indicators()
			social_chat_log.clear()
			if data is Array:
				var ordered_chat: Array = data.duplicate()
				ordered_chat.reverse()
				for item in ordered_chat:
					if not item is Dictionary:
						continue
					var sender_name := "أنت" if bool(item.get("sender_is_me", false)) else str(item.get("sender_name", "لاعب"))
					var safe_body := str(item.get("body", "")).replace("[", "(").replace("]", ")")
					social_chat_log.append_text("[color=gold][" + sender_name + "][/color] " + safe_body + "\n")
			social_chat_status.text = "المحادثة متصلة بالخادم."
		_:
			social_chat_status.text = "اكتملت العملية: " + action


func _on_social_operation_failed(action: String, message: String) -> void:
	if action == "display_name_get" or action == "display_name_change":
		if is_instance_valid(display_name_status):
			display_name_status.text = "تعذر تنفيذ العملية: " + message
		return
	if is_instance_valid(social_chat_status):
		social_chat_status.text = "تعذر تنفيذ " + action + ": " + message
	# Keep the account hydration chain sequential, but do not let one failed
	# endpoint prevent independent friends/group data from loading.
	if not AuthManager.is_authenticated():
		return
	match action:
		"chat_identity":
			local_player_code = ""
			SocialChatManager.check_moderator_access()
		"moderator_check":
			if is_instance_valid(moderation_button):
				moderation_button.visible = false
			SocialChatManager.list_chat_group_invites()
		"chat_invites":
			SocialChatManager.list_friends()
		"friends_list":
			SocialChatManager.get_chat_group()
		"group_info":
			SocialChatManager.subscribe_group_chat("")
			group_members = [{"player_id": "local_leader", "display_name": "أنت", "is_leader": true}]
			_refresh_group_popup()


func _on_social_realtime_status(status: String) -> void:
	if is_instance_valid(social_chat_status):
		social_chat_status.text = status


func _on_social_realtime_event(topic: String, event_name: String, payload: Dictionary) -> void:
	if event_name == "group_invite" or event_name == "group_meeting_invite" or event_name == "apartment_invite":
		# Accept invitations only from the private topic bound to this player's verified code.
		if not SocialChatManager.is_valid_player_code(local_player_code) or topic != "chat:invites:" + local_player_code:
			return
		var invitation := payload.duplicate(true)
		invitation["type"] = event_name
		if not invitation.has("invite_id"):
			invitation["invite_id"] = str(invitation.get("id", ""))
		if event_name == "group_invite":
			invitation["title"] = "دعوة للانضمام إلى المجموعة"
			invitation["body"] = "دعاك %s للانضمام إلى مجموعته." % str(payload.get("inviter_name", "لاعب"))
		elif event_name == "group_meeting_invite":
			invitation["title"] = "دعوة للتجمع"
			invitation["body"] = "قائد المجموعة يدعوك للتجمع في موقعه الحالي."
		else:
			invitation["title"] = "دعوة لزيارة شقة"
			invitation["body"] = "دعاك %s لزيارة شقته." % str(payload.get("host_name", "لاعب"))
		if is_instance_valid(invitation_overlay):
			invitation_overlay.call("enqueue_invitation", invitation)
		if is_instance_valid(social_chat_dock_button):
			social_chat_dock_button.text = "💬 🔴"
		return
	if event_name != "chat_message" and event_name != "direct_message":
		return
	var should_show := false
	if topic == "chat:public:messages" and social_chat_channel == "العامة" and social_chat_panel.visible:
		should_show = true
	elif topic.begins_with("chat:group:") and social_chat_channel == "المجموعة" and social_chat_panel.visible:
		should_show = true
	elif topic.begins_with("chat:direct:") and topic == "chat:direct:" + selected_friend_conversation_id and social_chat_channel == "الأصدقاء" and social_chat_panel.visible:
		should_show = true
	if not should_show or not is_instance_valid(social_chat_log):
		if topic.begins_with("chat:group:"):
			_unread_group_messages += 1
		elif topic.begins_with("chat:direct:"):
			var conversation_id := topic.trim_prefix("chat:direct:")
			var friend_code := str(_direct_conversation_to_friend.get(conversation_id, ""))
			if not friend_code.is_empty():
				_unread_direct_by_friend[friend_code] = int(_unread_direct_by_friend.get(friend_code, 0)) + 1
				_update_friend_unread_badge(friend_code)
		_refresh_unread_indicators()
		return
	var message_id := str(payload.get("message_id", ""))
	if not message_id.is_empty() and _seen_realtime_message_ids.has(message_id):
		return
	if not message_id.is_empty():
		_seen_realtime_message_ids[message_id] = true
	if topic.begins_with("chat:group:"):
		_unread_group_messages = 0
	elif topic.begins_with("chat:direct:"):
		var active_friend_code := str(_direct_conversation_to_friend.get(selected_friend_conversation_id, selected_friend_code))
		if not active_friend_code.is_empty():
			_unread_direct_by_friend.erase(active_friend_code)
			_update_friend_unread_badge(active_friend_code)
	_refresh_unread_indicators()
	var sender := str(payload.get("sender_name", "لاعب"))
	var safe_body := str(payload.get("body", "")).replace("[", "(").replace("]", ")")
	social_chat_log.append_text("[color=gold][" + sender + "][/color] " + safe_body + "\n")


func _refresh_social_invite_cards(data: Variant) -> void:
	if is_instance_valid(social_invites_box):
		for child in social_invites_box.get_children():
			child.queue_free()
		social_invites_box.visible = false
	if data is Array:
		for invite in data:
			if invite is Dictionary:
				_add_social_group_invite_card(invite)


func _add_social_group_invite_card(invite: Dictionary) -> void:
	if not is_instance_valid(invitation_overlay):
		return
	var item := invite.duplicate(true)
	item["type"] = "group_invite"
	item["title"] = "دعوة للانضمام إلى المجموعة"
	item["body"] = "دعاك %s للانضمام إلى مجموعته." % str(invite.get("inviter_name", "لاعب"))
	invitation_overlay.call("enqueue_invitation", item)


func _on_invitation_accepted(invitation: Dictionary) -> void:
	var kind := str(invitation.get("type", ""))
	if kind == "group_invite":
		_pending_group_invite_response_id = str(invitation.get("invite_id", ""))
		SocialChatManager.respond_chat_group_invite(_pending_group_invite_response_id, true)
	else:
		social_chat_status.text = "القبول غير متاح: لم تُربط خدمة هذا النوع من الدعوات بالخادم بعد."


func _on_invitation_declined(invitation: Dictionary) -> void:
	var kind := str(invitation.get("type", ""))
	if kind == "group_invite":
		_pending_group_invite_response_id = str(invitation.get("invite_id", ""))
		SocialChatManager.respond_chat_group_invite(_pending_group_invite_response_id, false)
	else:
		social_chat_status.text = "تم رفض الدعوة."


func _on_invitation_expired(invitation: Dictionary) -> void:
	if str(invitation.get("type", "")) == "group_invite":
		_pending_group_invite_response_id = str(invitation.get("invite_id", ""))
		SocialChatManager.respond_chat_group_invite(_pending_group_invite_response_id, false)
		social_chat_status.text = "انتهت صلاحية دعوة المجموعة بعد 30 ثانية."


func _respond_to_social_group_invite(invite_id: String, accepted: bool) -> void:
	_pending_group_invite_response_id = invite_id
	SocialChatManager.respond_chat_group_invite(invite_id, accepted)


func _remove_social_invite_card(invite_id: String) -> void:
	if not is_instance_valid(social_invites_box):
		return
	for child in social_invites_box.get_children():
		if child.has_meta("invite_id") and str(child.get_meta("invite_id")) == invite_id:
			child.queue_free()
	social_invites_box.visible = social_invites_box.get_child_count() > 0


func _update_friend_unread_badge(player_code: String) -> void:
	var friend_button: Button = _friend_buttons.get(player_code) as Button
	if not is_instance_valid(friend_button):
		return
	var base_label := str(_friend_base_labels.get(player_code, player_code))
	var unread := int(_unread_direct_by_friend.get(player_code, 0))
	friend_button.text = base_label if unread <= 0 else base_label + "\n🔴 " + str(unread)


func _refresh_unread_indicators() -> void:
	var direct_total := 0
	for value in _unread_direct_by_friend.values():
		direct_total += int(value)
	if is_instance_valid(_group_channel_button):
		_group_channel_button.text = "المجموعة" if _unread_group_messages <= 0 else "المجموعة 🔴 " + str(_unread_group_messages)
	if is_instance_valid(_friends_channel_button):
		_friends_channel_button.text = "الأصدقاء" if direct_total <= 0 else "الأصدقاء 🔴 " + str(direct_total)
	if is_instance_valid(social_chat_dock_button):
		var total := _unread_group_messages + direct_total
		social_chat_dock_button.text = "💬" if total <= 0 else "💬 🔴 " + str(total)


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
		_unread_group_messages = 0
		_refresh_unread_indicators()
		social_chat_status.text = "جارٍ تحميل المجموعة ورسائلها..."
		if is_instance_valid(social_group_create_button):
			social_group_create_button.visible = group_members.size() <= 1
		if is_instance_valid(social_group_invite_button):
			social_group_invite_button.visible = not selected_friend_code.is_empty()
		SocialChatManager.get_chat_group()
	else:
		if is_instance_valid(social_group_create_button):
			social_group_create_button.visible = false
		if is_instance_valid(social_group_invite_button):
			social_group_invite_button.visible = false
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
