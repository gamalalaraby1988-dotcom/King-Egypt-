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
var party_station_popup: PanelContainer
var party_station_status: Label
var party_station_start_button: Button
var player_name_label: Label
var player_level_label: Label
var player_status_label: Label
var player_avatar_label: Label
var player_action_status: Label
var player_block_button: Button
var player_report_reason: OptionButton
var player_report_details: LineEdit
var player_report_row: HBoxContainer
var player_report_button: Button
var player_report_send_button: Button
var blocked_players_box: VBoxContainer
var player_primary_action_button: Button
var selected_player_is_friend := false
var selected_player_id := ""
var _pending_friend_request_player_code := ""
var _sent_friend_requests: Dictionary = {}
var _pending_player_moderation_action := ""
var _pending_player_moderation_code := ""
var group_members: Array[Dictionary] = [{"player_id":"local_leader", "display_name":"أنت", "is_leader":true}]
var pending_group_invites: Array[String] = []
var group_popup: PanelContainer
var group_invite_popup: PanelContainer
var group_invite_list: VBoxContainer
var group_invite_status: Label
var group_invite_button: Button
var _group_invite_friends_cache: Array = []
var _pending_group_invite_code := ""
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

var social_chat_panel: PanelContainer
var social_chat_log: RichTextLabel
var social_chat_input: LineEdit
var social_chat_status: Label
var social_chat_location_button: Button
var shared_location_direction_arrow: Label
var shared_location_follow_active := false
var shared_location_follow_target := Vector3.ZERO
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
var _pending_direct_read_conversation_id := ""
var _pending_direct_send_conversation_id := ""
var social_group_create_button: Button
var social_group_invite_button: Button
var social_invites_box: VBoxContainer
var social_chat_dock_button: Button
const REALTIME_MESSAGE_DEDUPE_LIMIT := 500
var _seen_realtime_message_ids: Dictionary = {}
var _seen_realtime_message_order: Array[String] = []
var _pending_group_invite_response_id := ""
var _deferred_group_invite_responses: Array[Dictionary] = []
var invitation_overlay: Control
var _apartment_invite_mode := false
var moderation_button: Button
var moderation_panel: PanelContainer
var moderation_reports_box: VBoxContainer
var moderation_status_label: Label
var display_name_panel: PanelContainer
var display_name_input: LineEdit
var display_name_status: Label
var friends_phone_panel: PanelContainer
var friends_phone_name_label: Label
var friends_phone_code_label: Label
var friends_phone_status: Label
var friends_phone_search: LineEdit
var friends_phone_friends_box: VBoxContainer
var friends_phone_incoming_box: VBoxContainer
var friends_phone_outgoing_box: VBoxContainer
var friends_phone_pages: Dictionary = {}
var friends_phone_active_tab := "friends"
var friends_phone_avatar_label: Label
var friends_phone_badge: Control
var friends_phone_badge_label: Label
var friends_phone_incoming_count := 0

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
	"party": ["حفلة في المدينة", "مدة الحفلة 15 ثانية. يحصل اللاعبون الموجودون داخل حدود دائرة الحفلة المضيئة على المكافآت حسب مستوياتهم. نظام التشغيل والإهداء المتصل يحتاج خدمة الحفلات الخادمية."],
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
	_build_party_station_popup()
	_build_group_popup()
	_build_group_invite_popup()
	_build_group_chat_popup()
	_build_social_chat_panel()
	_build_shared_location_direction_arrow()
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



func _process(_delta: float) -> void:
	if not is_instance_valid(mission_manager) and is_instance_valid(main_scene):
		mission_manager = main_scene.get_node_or_null("MissionManager")
	_refresh_wallet()
	if _apartment_invite_mode and not _is_inside_private_apartment():
		_apartment_invite_mode = false
	_update_group_gather_visibility()
	_update_shared_location_direction_arrow()

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
	_make_friends_icon_button(bottom)
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

func _make_friends_icon_button(parent: Control) -> void:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(118, 42)
	parent.add_child(holder)
	var button := Button.new()
	button.text = "👥 أصدقاء"
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.add_theme_font_size_override("font_size", 14)
	button.pressed.connect(_on_button_pressed.bind("social"))
	holder.add_child(button)
	friends_phone_badge = PanelContainer.new()
	friends_phone_badge.name = "IncomingFriendRequestsBadge"
	friends_phone_badge.anchor_left = 1.0
	friends_phone_badge.anchor_right = 1.0
	friends_phone_badge.anchor_top = 0.0
	friends_phone_badge.anchor_bottom = 0.0
	friends_phone_badge.offset_left = -23
	friends_phone_badge.offset_right = 2
	friends_phone_badge.offset_top = -7
	friends_phone_badge.offset_bottom = 18
	friends_phone_badge.visible = false
	friends_phone_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	friends_phone_badge.add_theme_stylebox_override("panel", _friends_phone_style(Color("#c62828"), Color("#ff7777"), 1))
	holder.add_child(friends_phone_badge)
	friends_phone_badge_label = Label.new()
	friends_phone_badge_label.text = "0"
	friends_phone_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	friends_phone_badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	friends_phone_badge_label.add_theme_color_override("font_color", Color("#ffffff"))
	friends_phone_badge_label.add_theme_font_size_override("font_size", 12)
	friends_phone_badge.add_child(friends_phone_badge_label)

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

func _open_friends_phone_panel() -> void:
	if is_instance_valid(phone_popup):
		phone_popup.visible = false
	if is_instance_valid(popup):
		popup.visible = false
	if not is_instance_valid(friends_phone_panel):
		_build_friends_phone_panel()
	friends_phone_panel.visible = true
	_set_friends_phone_tab("friends")
	if AuthManager.is_authenticated():
		SocialChatManager.get_my_display_name()
		SocialChatManager.list_friends()
		SocialChatManager.list_friend_requests()
		friends_phone_status.text = "جارٍ تحميل بيانات الأصدقاء من الخادم..."
	else:
		friends_phone_status.text = "سجّل الدخول لعرض أصدقائك وطلبات الصداقة."

func _build_friends_phone_panel() -> void:
	friends_phone_panel = PanelContainer.new()
	friends_phone_panel.name = "FriendsManagementPhonePanel"
	friends_phone_panel.anchor_left = 0.5
	friends_phone_panel.anchor_right = 0.5
	friends_phone_panel.anchor_top = 0.5
	friends_phone_panel.anchor_bottom = 0.5
	friends_phone_panel.offset_left = -190
	friends_phone_panel.offset_right = 190
	friends_phone_panel.offset_top = -285
	friends_phone_panel.offset_bottom = 285
	friends_phone_panel.visible = false
	friends_phone_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	friends_phone_panel.add_theme_stylebox_override("panel", _friends_phone_style(Color("#101b2a"), Color("#c49a45"), 3))
	root.add_child(friends_phone_panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 7)
	friends_phone_panel.add_child(outer)
	var header := HBoxContainer.new()
	outer.add_child(header)
	var title := Label.new()
	title.text = "𓂀  الأصدقاء  𓂀"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color("#e8c46b"))
	title.add_theme_font_size_override("font_size", 20)
	header.add_child(title)
	var close := Button.new()
	close.text = "✕"
	close.pressed.connect(func():
		friends_phone_panel.visible = false
		if is_instance_valid(phone_popup):
			phone_popup.visible = true
	)
	header.add_child(close)
	var profile := PanelContainer.new()
	profile.add_theme_stylebox_override("panel", _friends_phone_style(Color("#1b2a3e"), Color("#8e713e"), 1))
	outer.add_child(profile)
	var profile_row := HBoxContainer.new()
	profile.add_child(profile_row)
	friends_phone_avatar_label = Label.new()
	friends_phone_avatar_label.text = "👤"
	friends_phone_avatar_label.custom_minimum_size = Vector2(54, 54)
	friends_phone_avatar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	friends_phone_avatar_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	friends_phone_avatar_label.add_theme_font_size_override("font_size", 30)
	profile_row.add_child(friends_phone_avatar_label)
	var profile_text := VBoxContainer.new()
	profile_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	profile_row.add_child(profile_text)
	friends_phone_name_label = Label.new()
	friends_phone_name_label.text = "اسم اللاعب"
	friends_phone_name_label.add_theme_color_override("font_color", Color("#f1d17b"))
	profile_text.add_child(friends_phone_name_label)
	friends_phone_code_label = Label.new()
	friends_phone_code_label.text = "رمز اللاعب: —"
	profile_text.add_child(friends_phone_code_label)
	var edit_profile := Button.new()
	edit_profile.text = "✏️"
	edit_profile.tooltip_text = "تعديل الاسم والصورة"
	edit_profile.custom_minimum_size = Vector2(48, 48)
	edit_profile.pressed.connect(_open_friends_profile_editor)
	profile_row.add_child(edit_profile)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	outer.add_child(tabs)
	var tab_group := ButtonGroup.new()
	tab_group.allow_unpress = false
	for tab in [{"id":"friends","caption":"الأصدقاء"},{"id":"incoming","caption":"الواردة"},{"id":"outgoing","caption":"المرسلة"}]:
		var tab_button := Button.new()
		tab_button.text = str(tab.caption)
		tab_button.toggle_mode = true
		tab_button.button_group = tab_group
		tab_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab_button.pressed.connect(_set_friends_phone_tab.bind(str(tab.id)))
		tabs.add_child(tab_button)
		friends_phone_pages[str(tab.id)] = {"button":tab_button}
	var page_scroll := ScrollContainer.new()
	page_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_child(page_scroll)
	for tab_id in ["friends", "incoming", "outgoing"]:
		var page := VBoxContainer.new()
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		page.add_theme_constant_override("separation", 6)
		page_scroll.add_child(page)
		friends_phone_pages[tab_id]["page"] = page
	var friends_page: VBoxContainer = friends_phone_pages["friends"]["page"]
	friends_phone_search = LineEdit.new()
	friends_phone_search.placeholder_text = "ابحث برمز اللاعب (10 أحرف)"
	friends_phone_search.max_length = 10
	friends_page.add_child(friends_phone_search)
	var search_button := Button.new()
	search_button.text = "إرسال طلب صداقة"
	search_button.pressed.connect(_send_friend_request_from_friends_phone)
	friends_page.add_child(search_button)
	friends_phone_friends_box = VBoxContainer.new()
	friends_phone_friends_box.add_theme_constant_override("separation", 5)
	friends_page.add_child(friends_phone_friends_box)
	friends_phone_incoming_box = friends_phone_pages["incoming"]["page"]
	friends_phone_outgoing_box = friends_phone_pages["outgoing"]["page"]
	friends_phone_status = Label.new()
	friends_phone_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	friends_phone_status.add_theme_color_override("font_color", Color("#e8c46b"))
	outer.add_child(friends_phone_status)
	var footer := Button.new()
	footer.text = "العودة إلى الهاتف"
	footer.pressed.connect(func(): friends_phone_panel.visible = false)
	outer.add_child(footer)
	_set_friends_phone_tab("friends")

func _set_friends_phone_tab(tab_id: String) -> void:
	friends_phone_active_tab = tab_id
	for key in friends_phone_pages:
		var entry: Dictionary = friends_phone_pages[key]
		if entry.has("page"):
			(entry["page"] as Control).visible = str(key) == tab_id
		if entry.has("button"):
			(entry["button"] as Button).button_pressed = str(key) == tab_id

func _send_friend_request_from_friends_phone() -> void:
	var code := friends_phone_search.text.strip_edges().to_upper() if is_instance_valid(friends_phone_search) else ""
	if not SocialChatManager.is_valid_player_code(code):
		friends_phone_status.text = "أدخل رمز لاعب صحيحًا مكوّنًا من 10 أحرف."
		return
	if SocialChatManager.send_friend_request(code):
		friends_phone_status.text = "جارٍ إرسال طلب الصداقة..."

func _open_friends_profile_editor() -> void:
	if not is_instance_valid(display_name_panel):
		return
	_open_display_name_panel()
	friends_phone_status.text = "يمكن تعديل الاسم من هنا. اختيار صورة الشخصية سيُفعّل بعد ربط حفظ الشخصية الجاهزة بملف اللاعب."

func _friends_phone_style(background: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(12)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style

func _render_friends_phone_list(data: Array) -> void:
	for child in friends_phone_friends_box.get_children():
		child.queue_free()
	for friend in data:
		if not friend is Dictionary:
			continue
		var code := str(friend.get("player_code", ""))
		var name := str(friend.get("display_name", "صديق"))
		var row := HBoxContainer.new()
		friends_phone_friends_box.add_child(row)
		var info := Label.new()
		info.text = "👤  %s\n%s" % [name, code]
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		var chat := Button.new()
		chat.text = "محادثة"
		chat.pressed.connect(_on_social_friend_selected.bind(code))
		row.add_child(chat)
		var remove := Button.new()
		remove.text = "حذف"
		remove.disabled = true
		remove.tooltip_text = "الحذف يحتاج إجراءً خادميًا آمنًا غير متاح حاليًا."
		row.add_child(remove)
	if friends_phone_friends_box.get_child_count() == 0:
		var empty := Label.new()
		empty.text = "لا يوجد أصدقاء بعد."
		friends_phone_friends_box.add_child(empty)


func _make_friend_request_avatar(character_id: String) -> Control:
	var frame := PanelContainer.new()
	frame.name = "FriendRequestAvatar"
	frame.custom_minimum_size = Vector2(76, 76)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#172638")
	style.border_color = Color("#c49a45")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	frame.add_theme_stylebox_override("panel", style)
	if character_id.is_empty():
		var fallback := Label.new()
		fallback.text = "👤"
		fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		fallback.add_theme_font_size_override("font_size", 34)
		frame.add_child(fallback)
		return frame
	var character_id_pattern := RegEx.new()
	character_id_pattern.compile("^[A-Za-z0-9_-]{1,48}$")
	if character_id_pattern.search(character_id) == null:
		var fallback := Label.new()
		fallback.text = "👤"
		fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		fallback.add_theme_font_size_override("font_size", 34)
		frame.add_child(fallback)
		return frame
	var final_path := "res://assets/characters/%s/character.tscn" % character_id
	if not ResourceLoader.exists(final_path):
		var fallback := Label.new()
		fallback.text = "👤"
		fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		fallback.add_theme_font_size_override("font_size", 34)
		frame.add_child(fallback)
		return frame
	var packed := load(final_path) as PackedScene
	if packed == null:
		var fallback := Label.new()
		fallback.text = "👤"
		fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		frame.add_child(fallback)
		return frame
	var viewport_container := SubViewportContainer.new()
	viewport_container.custom_minimum_size = Vector2(76, 76)
	viewport_container.stretch = true
	frame.add_child(viewport_container)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(152, 152)
	viewport.transparent_bg = true
	viewport_container.add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-25, -20, 0)
	light.light_energy = 1.2
	world.add_child(light)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 1.15, 3.8)
	camera.look_at(Vector3(0, 1.0, 0), Vector3.UP)
	camera.current = true
	world.add_child(camera)
	var avatar := packed.instantiate() as Node3D
	if avatar == null:
		viewport_container.queue_free()
		var fallback := Label.new()
		fallback.text = "👤"
		fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		frame.add_child(fallback)
		return frame
	avatar.scale = Vector3.ONE * 0.82
	world.add_child(avatar)
	if avatar.has_method("apply_character_identity"):
		avatar.call("apply_character_identity", character_id)
	return frame


func _render_friends_phone_requests(data: Array) -> void:
	# Rebuild sent-request state from the authoritative server response so the
	# nearby-player action remains correct after reopening the game or HUD.
	var server_sent_requests: Dictionary = {}
	for request in data:
		if not request is Dictionary or str(request.get("direction", "")) != "outgoing":
			continue
		var sent_code := str(request.get("player_code", "")).strip_edges().to_upper()
		if SocialChatManager.is_valid_player_code(sent_code):
			server_sent_requests[sent_code] = true
	_sent_friend_requests = server_sent_requests
	for box in [friends_phone_incoming_box, friends_phone_outgoing_box]:
		for child in box.get_children():
			child.queue_free()
	var incoming_count := 0
	var outgoing_count := 0
	for request in data:
		if not request is Dictionary:
			continue
		var direction := str(request.get("direction", ""))
		var request_id := str(request.get("request_id", ""))
		var code := str(request.get("player_code", ""))
		var name := str(request.get("display_name", "لاعب"))
		var target_box := friends_phone_incoming_box if direction == "incoming" else friends_phone_outgoing_box if direction == "outgoing" else null
		if target_box == null:
			continue
		if direction == "incoming":
			incoming_count += 1
		else:
			outgoing_count += 1
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		target_box.add_child(row)
		var character_id := str(request.get("selected_character_id", request.get("character_id", ""))).strip_edges()
		row.add_child(_make_friend_request_avatar(character_id))
		var details := VBoxContainer.new()
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(details)
		var label := Label.new()
		label.text = "%s\n%s" % [name, code]
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		details.add_child(label)
		var actions := HBoxContainer.new()
		details.add_child(actions)
		if direction == "incoming":
			var accept := Button.new()
			accept.text = "قبول"
			accept.pressed.connect(func(): SocialChatManager.respond_friend_request(request_id, true))
			actions.add_child(accept)
			var decline := Button.new()
			decline.text = "رفض"
			decline.pressed.connect(func(): SocialChatManager.respond_friend_request(request_id, false))
			actions.add_child(decline)
		else:
			var pending := Button.new()
			pending.text = "قيد الانتظار"
			pending.disabled = true
			actions.add_child(pending)
			var cancel := Button.new()
			cancel.text = "إلغاء"
			cancel.disabled = true
			cancel.tooltip_text = "إلغاء الطلب يحتاج إجراءً خادميًا غير متاح حاليًا."
			actions.add_child(cancel)
	if incoming_count == 0:
		var empty_in := Label.new()
		empty_in.text = "لا توجد طلبات واردة."
		friends_phone_incoming_box.add_child(empty_in)
	if outgoing_count == 0:
		var empty_out := Label.new()
		empty_out.text = "لا توجد طلبات مرسلة."
		friends_phone_outgoing_box.add_child(empty_out)

	friends_phone_incoming_count = incoming_count
	_update_friends_phone_request_badge()

func _update_friends_phone_request_badge() -> void:
	if is_instance_valid(friends_phone_badge):
		friends_phone_badge.visible = friends_phone_incoming_count > 0
	if is_instance_valid(friends_phone_badge_label):
		friends_phone_badge_label.text = str(friends_phone_incoming_count)
	if friends_phone_pages.has("incoming"):
		var entry: Dictionary = friends_phone_pages["incoming"]
		if entry.has("button") and is_instance_valid(entry["button"]):
			(entry["button"] as Button).text = "الواردة" if friends_phone_incoming_count == 0 else "الواردة (%d)" % friends_phone_incoming_count

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
	var friends_button := Button.new()
	friends_button.text = "👥  إدارة الأصدقاء"
	friends_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	friends_button.pressed.connect(_open_friends_phone_panel)
	content.add_child(friends_button)
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
	# نافذة تفاعل مضغوطة جدًا؛ لا تحجب الشخصية أو الطريق أو أزرار التحكم.
	player_popup = PanelContainer.new()
	player_popup.name = "PlayerInteractionPopup"
	player_popup.anchor_left = 0.5
	player_popup.anchor_right = 0.5
	player_popup.anchor_top = 0.5
	player_popup.anchor_bottom = 0.5
	player_popup.offset_left = -145
	player_popup.offset_right = 145
	player_popup.offset_top = -86
	player_popup.offset_bottom = 86
	player_popup.visible = false
	player_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.10, 0.075, 0.16, 0.88)
	panel_style.border_color = Color(0.82, 0.66, 0.34, 0.96)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(12)
	panel_style.content_margin_left = 7
	panel_style.content_margin_right = 7
	panel_style.content_margin_top = 6
	panel_style.content_margin_bottom = 6
	player_popup.add_theme_stylebox_override("panel", panel_style)
	root.add_child(player_popup)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	player_popup.add_child(content)

	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 6)
	content.add_child(heading)
	player_avatar_label = Label.new()
	player_avatar_label.text = "👤"
	player_avatar_label.custom_minimum_size = Vector2(34, 34)
	player_avatar_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	player_avatar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_avatar_label.add_theme_font_size_override("font_size", 24)
	heading.add_child(player_avatar_label)

	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.add_theme_constant_override("separation", 0)
	heading.add_child(identity)
	player_name_label = Label.new()
	player_name_label.text = "اسم اللاعب"
	player_name_label.add_theme_font_size_override("font_size", 14)
	player_name_label.add_theme_color_override("font_color", Color.WHITE)
	identity.add_child(player_name_label)
	player_level_label = Label.new()
	player_level_label.add_theme_font_size_override("font_size", 10)
	player_level_label.add_theme_color_override("font_color", Color(0.94, 0.84, 0.61))
	identity.add_child(player_level_label)
	player_status_label = Label.new()
	player_status_label.add_theme_font_size_override("font_size", 9)
	player_status_label.add_theme_color_override("font_color", Color(0.88, 0.85, 1.0))
	identity.add_child(player_status_label)

	var close := Button.new()
	close.text = "✕"
	close.custom_minimum_size = Vector2(26, 26)
	close.pressed.connect(close_player_interaction)
	heading.add_child(close)

	var primary_row := HBoxContainer.new()
	primary_row.add_theme_constant_override("separation", 4)
	content.add_child(primary_row)
	player_primary_action_button = Button.new()
	player_primary_action_button.text = "إضافة صديق"
	player_primary_action_button.custom_minimum_size.y = 32
	player_primary_action_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_primary_action_button.add_theme_font_size_override("font_size", 12)
	player_primary_action_button.pressed.connect(_on_player_primary_action)
	primary_row.add_child(player_primary_action_button)

	var gift_party := Button.new()
	gift_party.text = "🎉 إهداء حفلة"
	gift_party.custom_minimum_size.y = 32
	gift_party.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gift_party.add_theme_font_size_override("font_size", 12)
	gift_party.pressed.connect(_on_player_gift_party)
	primary_row.add_child(gift_party)

	var secondary_row := HBoxContainer.new()
	secondary_row.add_theme_constant_override("separation", 3)
	content.add_child(secondary_row)
	var message_button := Button.new()
	message_button.text = "رسالة"
	message_button.custom_minimum_size.y = 26
	message_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message_button.add_theme_font_size_override("font_size", 10)
	message_button.pressed.connect(_on_player_message)
	secondary_row.add_child(message_button)
	player_block_button = Button.new()
	player_block_button.name = "BlockSelectedPlayer"
	player_block_button.text = "حظر"
	player_block_button.custom_minimum_size.y = 26
	player_block_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_block_button.add_theme_font_size_override("font_size", 10)
	player_block_button.pressed.connect(_on_player_block)
	secondary_row.add_child(player_block_button)
	player_report_button = Button.new()
	player_report_button.text = "إبلاغ"
	player_report_button.custom_minimum_size.y = 26
	player_report_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_report_button.add_theme_font_size_override("font_size", 10)
	player_report_button.pressed.connect(_toggle_player_report_form)
	secondary_row.add_child(player_report_button)

	player_report_row = HBoxContainer.new()
	player_report_row.add_theme_constant_override("separation", 3)
	player_report_row.visible = false
	content.add_child(player_report_row)
	player_report_reason = OptionButton.new()
	player_report_reason.add_item("مضايقة", 0)
	player_report_reason.add_item("سبام", 1)
	player_report_reason.add_item("اسم غير مناسب", 2)
	player_report_reason.add_item("غش", 3)
	player_report_reason.add_item("أخرى", 4)
	player_report_reason.custom_minimum_size = Vector2(82, 26)
	player_report_reason.add_theme_font_size_override("font_size", 9)
	player_report_row.add_child(player_report_reason)
	player_report_details = LineEdit.new()
	player_report_details.placeholder_text = "تفاصيل اختيارية"
	player_report_details.custom_minimum_size.y = 26
	player_report_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_report_details.add_theme_font_size_override("font_size", 9)
	player_report_row.add_child(player_report_details)
	player_report_send_button = Button.new()
	player_report_send_button.text = "إرسال"
	player_report_send_button.custom_minimum_size = Vector2(44, 26)
	player_report_send_button.add_theme_font_size_override("font_size", 9)
	player_report_send_button.pressed.connect(_on_player_report)
	player_report_row.add_child(player_report_send_button)

	player_action_status = Label.new()
	player_action_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_action_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	player_action_status.add_theme_font_size_override("font_size", 9)
	player_action_status.add_theme_color_override("font_color", Color(1.0, 0.91, 0.69))
	content.add_child(player_action_status)


func _toggle_player_report_form() -> void:
	if not _has_selected_player():
		player_action_status.text = "رمز اللاعب غير متاح."
		return
	player_report_row.visible = not player_report_row.visible
	player_report_button.text = "إلغاء" if player_report_row.visible else "إبلاغ"
	if player_report_row.visible:
		player_action_status.text = "اختر سبب البلاغ ثم أرسله."
	else:
		player_action_status.text = ""



func _build_party_station_popup() -> void:
	# نافذة شديدة الصغر في منتصف الشاشة كما اعتمد المستخدم.
	party_station_popup = PanelContainer.new()
	party_station_popup.name = "PartyStationPopup"
	party_station_popup.anchor_left = 0.5
	party_station_popup.anchor_right = 0.5
	party_station_popup.anchor_top = 0.5
	party_station_popup.anchor_bottom = 0.5
	party_station_popup.offset_left = -120
	party_station_popup.offset_right = 120
	party_station_popup.offset_top = -54
	party_station_popup.offset_bottom = 54
	party_station_popup.visible = false
	party_station_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.10, 0.075, 0.16, 0.93)
	panel_style.border_color = Color(0.88, 0.68, 0.30, 0.98)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(12)
	panel_style.content_margin_left = 6
	panel_style.content_margin_right = 6
	panel_style.content_margin_top = 4
	panel_style.content_margin_bottom = 4
	party_station_popup.add_theme_stylebox_override("panel", panel_style)
	root.add_child(party_station_popup)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 2)
	party_station_popup.add_child(content)
	var heading_row := HBoxContainer.new()
	content.add_child(heading_row)
	var heading := Label.new()
	heading.text = "♫ حفلة ملكية"
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_theme_font_size_override("font_size", 12)
	heading.add_theme_color_override("font_color", Color(1.0, 0.82, 0.42))
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	heading_row.add_child(heading)
	var close := Button.new()
	close.text = "×"
	close.custom_minimum_size = Vector2(20, 20)
	close.pressed.connect(close_party_station_window)
	heading_row.add_child(close)
	var price := Label.new()
	price.text = "150 جوهرة  •  15 ثانية"
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price.add_theme_font_size_override("font_size", 10)
	price.add_theme_color_override("font_color", Color(1.0, 0.84, 0.48))
	content.add_child(price)
	party_station_start_button = Button.new()
	party_station_start_button.text = "إقامة حفلة"
	party_station_start_button.custom_minimum_size.y = 27
	party_station_start_button.disabled = true
	party_station_start_button.tooltip_text = "تفعيل الحفلات ينتظر ربط خدمة الحفلات الخادمية."
	content.add_child(party_station_start_button)
	party_station_status = Label.new()
	party_station_status.text = "الخدمة غير متصلة حاليًا"
	party_station_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	party_station_status.add_theme_font_size_override("font_size", 8)
	party_station_status.add_theme_color_override("font_color", Color(1.0, 0.88, 0.68))
	content.add_child(party_station_status)

func open_party_station_window() -> void:
	if is_instance_valid(player_popup):
		player_popup.visible = false
	if is_instance_valid(party_station_popup):
		party_station_popup.visible = true

func close_party_station_window() -> void:
	if is_instance_valid(party_station_popup):
		party_station_popup.visible = false

func _on_player_message() -> void:
	if not _has_selected_player():
		player_action_status.text = "تعذر فتح المحادثة: رمز اللاعب غير متاح."
		return
	if not SocialChatManager._pending_action.is_empty():
		player_action_status.text = "انتظر اكتمال عملية التواصل الحالية."
		return
	var target_code := selected_player_id
	_apartment_invite_mode = false
	social_chat_channel = "الأصدقاء"
	selected_friend_code = target_code
	_pending_direct_open_player_code = target_code
	selected_friend_conversation_id = ""
	_update_shared_location_button_state()
	if is_instance_valid(social_chat_log):
		social_chat_log.clear()
	if is_instance_valid(social_chat_status):
		social_chat_status.text = "جارٍ فتح محادثة اللاعب..."
	_open_social_chat_panel()
	if not SocialChatManager.open_direct_conversation(target_code):
		if _pending_direct_open_player_code == target_code:
			_pending_direct_open_player_code = ""
			social_chat_status.text = "تعذر بدء فتح المحادثة. حاول مرة أخرى."
		return
	close_player_interaction()


static func resolve_friend_action_state(player_code: String, is_friend: bool, sending_code: String, sent_requests: Dictionary) -> Dictionary:
	var target := player_code.strip_edges().to_upper()
	if is_friend:
		return {"text": "دعوة للمجموعة", "disabled": false, "status": ""}
	if target.is_empty():
		return {"text": "إضافة صديق", "disabled": true, "status": "رمز اللاعب غير متاح."}
	if sending_code == target:
		return {"text": "جارٍ إرسال الطلب...", "disabled": true, "status": "جارٍ إرسال طلب الصداقة إلى الخادم..."}
	if sent_requests.has(target):
		return {"text": "تم إرسال طلب الصداقة", "disabled": true, "status": "سبق إرسال طلب صداقة لهذا اللاعب. ينتظر الرد."}
	if not sending_code.is_empty():
		return {"text": "طلب آخر قيد التنفيذ", "disabled": true, "status": "انتظر انتهاء طلب الصداقة الحالي."}
	return {"text": "إضافة صديق", "disabled": false, "status": ""}


static func format_player_presence_status(player_data: Dictionary) -> String:
	for key in ["is_online", "online"]:
		if player_data.has(key) and player_data[key] is bool:
			return "متصل الآن" if bool(player_data[key]) else "غير متصل"
	for key in ["presence", "status"]:
		var value := str(player_data.get(key, "")).strip_edges().to_lower()
		if value in ["online", "متصل"]:
			return "متصل الآن"
		if value in ["offline", "غير متصل"]:
			return "غير متصل"
	return "حالة الاتصال غير متاحة"


func open_player_interaction(player_data: Dictionary) -> void:
	# البيانات المتوقعة: player_id, display_name, level, presence metadata, character_id.
	selected_player_id = str(player_data.get("player_code", player_data.get("player_id", ""))).strip_edges().to_upper()
	if not SocialChatManager.is_valid_player_code(selected_player_id):
		selected_player_id = ""
	if is_instance_valid(player_block_button):
		player_block_button.visible = not selected_player_id.is_empty()
	selected_player_is_friend = bool(player_data.get("is_friend", false))
	if selected_player_is_friend:
		_sent_friend_requests.erase(selected_player_id)
	var friend_action_state := resolve_friend_action_state(selected_player_id, selected_player_is_friend, _pending_friend_request_player_code, _sent_friend_requests)
	player_primary_action_button.disabled = bool(friend_action_state.get("disabled", false))
	player_primary_action_button.text = str(friend_action_state.get("text", "إضافة صديق"))
	var clean_name := str(player_data.get("display_name", "لاعب")).strip_edges().substr(0, 24)
	player_name_label.text = clean_name if not clean_name.is_empty() else "لاعب"
	var clean_level := str(player_data.get("level", "—")).substr(0, 12)
	player_level_label.text = "المستوى %s" % clean_level
	player_status_label.text = format_player_presence_status(player_data)
	var clean_avatar := str(player_data.get("avatar_text", "👤")).substr(0, 8)
	player_avatar_label.text = clean_avatar if not clean_avatar.is_empty() else "👤"
	player_action_status.text = "بيانات اللاعب غير صالحة؛ تعذر تنفيذ التفاعل." if selected_player_id.is_empty() else str(friend_action_state.get("status", ""))
	player_report_row.visible = false
	player_report_button.text = "إبلاغ"
	player_report_details.text = ""
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
		return
	if not _pending_friend_request_player_code.is_empty():
		player_action_status.text = "انتظر انتهاء طلب الصداقة الحالي."
		return
	if not AuthManager.is_authenticated():
		player_action_status.text = "سجّل الدخول أولًا لإرسال طلب صداقة."
		return
	_pending_friend_request_player_code = selected_player_id
	player_primary_action_button.disabled = true
	player_primary_action_button.text = "جارٍ إرسال الطلب..."
	player_action_status.text = "جارٍ إرسال طلب الصداقة إلى الخادم..."
	if not SocialChatManager.send_friend_request(selected_player_id):
		# قد يصدر فشل الطلب تزامنيًا من مدير التواصل؛ لا نترك زرًا عالقًا.
		if _pending_friend_request_player_code == selected_player_id:
			_pending_friend_request_player_code = ""
			player_primary_action_button.disabled = false
			player_primary_action_button.text = "إضافة صديق"


func _on_player_gift_party() -> void:
	if not _has_selected_player():
		player_action_status.text = "تعذر تجهيز الإهداء: رمز اللاعب غير متاح."
		return
	party_gift_requested.emit(selected_player_id)
	player_action_status.text = "تم تحديد اللاعب المستقبِل، لكن الإهداء لم يُرسل: خدمة الحفلات الخادمية غير متصلة بعد."


func _on_player_block() -> void:
	if not _has_selected_player():
		player_action_status.text = "تعذر حظر اللاعب: رمز اللاعب غير صالح."
		return
	if not _pending_player_moderation_action.is_empty():
		player_action_status.text = "انتظر انتهاء إجراء الإشراف الحالي."
		return
	var target_code := selected_player_id
	if SocialChatManager.block_player(target_code):
		_pending_player_moderation_action = "block_player"
		_pending_player_moderation_code = target_code
		player_block_button.disabled = true
		player_action_status.text = "جارٍ إرسال طلب الحظر إلى الخادم..."


func _on_player_report() -> void:
	if not _has_selected_player():
		player_action_status.text = "تعذر تجهيز البلاغ: رمز اللاعب غير متاح."
		return
	if not _pending_player_moderation_action.is_empty():
		player_action_status.text = "انتظر انتهاء إجراء الإشراف الحالي."
		return
	var target_code := selected_player_id
	var reasons := ["harassment", "spam", "inappropriate_name", "cheating", "other"]
	var reason: String = str(reasons[player_report_reason.selected]) if is_instance_valid(player_report_reason) else "other"
	var details := player_report_details.text if is_instance_valid(player_report_details) else ""
	if SocialChatManager.report_player(target_code, reason, details):
		_pending_player_moderation_action = "report_player"
		_pending_player_moderation_code = target_code
		player_report_send_button.disabled = true
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
	group_invite_button = Button.new()
	group_invite_button.name = "InviteGroupMembersButton"
	group_invite_button.text = "👥 دعوة أعضاء"
	group_invite_button.custom_minimum_size.y = 44
	group_invite_button.pressed.connect(_open_group_invite_popup)
	box.add_child(group_invite_button)
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
	group_meeting_status.text = "التجمع يتم عند موقع القائد الحالي داخل المدينة؛ لا توجد نقطة مستقلة."
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


func _build_group_invite_popup() -> void:
	group_invite_popup = PanelContainer.new()
	group_invite_popup.name = "GroupInviteFriendsPopup"
	group_invite_popup.anchor_left = 0.5
	group_invite_popup.anchor_right = 0.5
	group_invite_popup.anchor_top = 0.5
	group_invite_popup.anchor_bottom = 0.5
	group_invite_popup.offset_left = -180
	group_invite_popup.offset_right = 180
	group_invite_popup.offset_top = -230
	group_invite_popup.offset_bottom = 230
	group_invite_popup.visible = false
	group_invite_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.035, 0.055, 0.075, 0.86)
	panel_style.border_color = Color(0.72, 0.55, 0.25, 0.95)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(16)
	panel_style.content_margin_left = 12
	panel_style.content_margin_right = 12
	panel_style.content_margin_top = 12
	panel_style.content_margin_bottom = 12
	group_invite_popup.add_theme_stylebox_override("panel", panel_style)
	root.add_child(group_invite_popup)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 9)
	group_invite_popup.add_child(column)
	var heading := Label.new()
	heading.text = "دعوة أعضاء المجموعة"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 21)
	column.add_child(heading)
	group_invite_status = Label.new()
	group_invite_status.text = "الأصدقاء المتصلون فقط"
	group_invite_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	group_invite_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(group_invite_status)
	var scroll := ScrollContainer.new()
	scroll.name = "GroupInviteFriendsScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	group_invite_list = VBoxContainer.new()
	group_invite_list.name = "GroupInviteFriendsList"
	group_invite_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(group_invite_list)
	var close_button := Button.new()
	close_button.text = "إغلاق"
	close_button.custom_minimum_size.y = 44
	close_button.pressed.connect(func(): group_invite_popup.visible = false)
	column.add_child(close_button)


func _open_group_invite_popup() -> void:
	if group_members.size() >= GROUP_MAX_MEMBERS:
		group_invite_status.text = "المجموعة مكتملة؛ الحد الأقصى أربعة لاعبين."
		group_invite_popup.visible = true
		return
	if not AuthManager.is_authenticated():
		group_invite_status.text = "سجّل الدخول لعرض أصدقائك المتصلين."
		group_invite_popup.visible = true
		return
	group_invite_status.text = "جارٍ تحميل الأصدقاء المتصلين..."
	group_invite_popup.visible = true
	SocialChatManager.list_friends()


func has_group_invite_presence_metadata(friends: Array) -> bool:
	for friend in friends:
		if friend is Dictionary and (friend.has("is_online") or friend.has("online") or friend.has("presence") or friend.has("status")):
			return true
	return false


func get_online_group_invite_friends(friends: Array) -> Array:
	var online_friends: Array = []
	for friend in friends:
		if not friend is Dictionary:
			continue
		var online_value: Variant = friend.get("is_online", friend.get("online", false))
		var presence_value := str(friend.get("presence", friend.get("status", ""))).strip_edges().to_lower()
		if bool(online_value) or presence_value == "online" or presence_value == "متصل":
			online_friends.append(friend)
	return online_friends


func _refresh_group_invite_friends(friends: Array) -> void:
	if not is_instance_valid(group_invite_list):
		return
	for child in group_invite_list.get_children():
		child.queue_free()
	_group_invite_friends_cache = get_online_group_invite_friends(friends)
	if not has_group_invite_presence_metadata(friends):
		group_invite_status.text = "حالة اتصال الأصدقاء غير متاحة من الخادم حاليًا. لم نعرض حالات غير مؤكدة."
		return
	if group_members.size() >= GROUP_MAX_MEMBERS:
		group_invite_status.text = "المجموعة مكتملة؛ لا يمكن إرسال دعوات جديدة."
		return
	if _group_invite_friends_cache.is_empty():
		group_invite_status.text = "لا يوجد أصدقاء متصلون حاليًا."
		return
	group_invite_status.text = "الأصدقاء المتصلون: %d" % _group_invite_friends_cache.size()
	for friend in _group_invite_friends_cache:
		var code := str(friend.get("player_code", "")).strip_edges().to_upper()
		var display_name := str(friend.get("display_name", "صديق")).strip_edges()
		if display_name.is_empty():
			display_name = "صديق"
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		group_invite_list.add_child(row)
		row.add_child(_build_friend_character_portrait(friend))
		var name_column := VBoxContainer.new()
		name_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_column)
		var name_label := Label.new()
		name_label.text = display_name.substr(0, 24)
		name_label.clip_text = true
		name_column.add_child(name_label)
		var online_label := Label.new()
		online_label.text = "متصل"
		online_label.add_theme_color_override("font_color", Color(0.35, 0.85, 0.55, 1.0))
		name_column.add_child(online_label)
		var invite := Button.new()
		invite.text = "دعوة"
		invite.custom_minimum_size = Vector2(76, 42)
		var already_member := _group_contains(code)
		var already_pending := pending_group_invites.has(code)
		invite.disabled = code.is_empty() or not SocialChatManager.is_valid_player_code(code) or already_member or already_pending or group_members.size() >= GROUP_MAX_MEMBERS
		if already_member:
			invite.text = "عضو"
		elif already_pending:
			invite.text = "مُرسلة"
		invite.pressed.connect(_send_group_invite_from_list.bind(code))
		row.add_child(invite)


func get_friend_character_scene_path(friend: Dictionary) -> String:
	# Render only one of the game's own character IDs. Never accept image URLs,
	# arbitrary file paths, or texture payloads from a friend-list response.
	var character_id := str(friend.get("selected_character_id", friend.get("character_id", ""))).strip_edges()
	var supported_ids := [
		"eg_m_adam", "eg_m_omar", "it_m_leon", "fr_m_alex",
		"br_m_matheus", "jp_m_ren", "us_m_lucas", "tr_m_amir",
		"eg_f_layan", "eg_f_nour", "it_f_sofia", "fr_f_emma",
		"br_f_isabella", "jp_f_aika", "us_f_olivia", "tr_f_eileen"
	]
	if not supported_ids.has(character_id):
		return ""
	var final_scene_path := "res://assets/characters/%s/character.tscn" % character_id
	if ResourceLoader.exists(final_scene_path):
		return final_scene_path
	# Until final art assets arrive, use the game's own 3D character scene,
	# not an external portrait or a random stock image.
	var in_game_preview_path := "res://scenes/characters/avatar_visual.tscn"
	return in_game_preview_path if ResourceLoader.exists(in_game_preview_path) else ""


func _build_friend_character_portrait(friend: Dictionary) -> Control:
	var scene_path := get_friend_character_scene_path(friend)
	if scene_path.is_empty():
		var fallback := CenterContainer.new()
		fallback.name = "FriendCharacterPortraitFallback"
		fallback.custom_minimum_size = Vector2(52, 52)
		var silhouette := Label.new()
		silhouette.text = "👤"
		silhouette.add_theme_font_size_override("font_size", 28)
		fallback.add_child(silhouette)
		return fallback

	var portrait := SubViewportContainer.new()
	portrait.name = "FriendCharacterPortrait"
	portrait.custom_minimum_size = Vector2(52, 52)
	portrait.stretch = true
	var viewport := SubViewport.new()
	viewport.name = "FriendCharacterPortraitViewport"
	viewport.size = Vector2i(104, 104)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	portrait.add_child(viewport)

	var world := Node3D.new()
	world.name = "PortraitWorld"
	viewport.add_child(world)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 1.12, -3.2)
	camera.current = true
	camera.basis = Basis.looking_at(Vector3(0, 1.0, 0) - camera.position, Vector3.UP)
	world.add_child(camera)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-24, -18, 0)
	light.light_energy = 1.25
	world.add_child(light)
	var packed := load(scene_path) as PackedScene
	if packed != null:
		var character := packed.instantiate() as Node3D
		if character != null:
			if scene_path == "res://scenes/characters/avatar_visual.tscn" and character.has_method("apply_character_identity"):
				var character_id := str(friend.get("selected_character_id", friend.get("character_id", ""))).strip_edges()
				character.ready.connect(character.apply_character_identity.bind(character_id), CONNECT_ONE_SHOT)
			world.add_child(character)
	return portrait


func _send_group_invite_from_list(player_code: String) -> void:
	var code := player_code.strip_edges().to_upper()
	if not SocialChatManager.is_valid_player_code(code):
		group_invite_status.text = "رمز اللاعب غير صالح."
		return
	if group_members.size() >= GROUP_MAX_MEMBERS:
		group_invite_status.text = "المجموعة مكتملة؛ الحد الأقصى أربعة لاعبين."
		return
	if _group_contains(code) or pending_group_invites.has(code):
		group_invite_status.text = "هذا الصديق عضو بالفعل أو أُرسلت له دعوة."
		return
	pending_group_invites.append(code)
	_pending_group_invite_code = code
	if not SocialChatManager.invite_chat_group_member(code):
		pending_group_invites.erase(code)
		_pending_group_invite_code = ""
		group_invite_status.text = "تعذر إرسال الدعوة الآن."
		_refresh_group_invite_friends(_group_invite_friends_cache)
		return
	group_invite_status.text = "جارٍ إرسال الدعوة إلى الصديق..."
	_refresh_group_invite_friends(_group_invite_friends_cache)
	_refresh_group_popup()


func _open_group_popup() -> void:
	_refresh_group_popup()
	group_popup.visible = true


func _refresh_group_popup() -> void:
	if is_instance_valid(group_invite_button):
		group_invite_button.disabled = group_members.size() >= GROUP_MAX_MEMBERS
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


func can_show_group_gather_button(is_leader: bool, member_count: int, inside_apartment: bool) -> bool:
	return is_leader and member_count > 1 and not inside_apartment


func can_submit_group_invitation_response(pending_invite_id: String, invite_id: String) -> bool:
	return pending_invite_id.strip_edges().is_empty() and SocialChatManager.is_valid_invite_id(invite_id)


func can_receive_social_invitation_event(event_name: String) -> bool:
	return event_name in ["group_invite", "chat_message", "direct_message"]


func build_party_announcement_body(location_name: String) -> String:
	var clean_location := location_name.strip_edges()
	if clean_location.is_empty():
		clean_location = "المدينة"
	return "🎉 بدأت حفلة جديدة في %s! تعالوا شاركونا." % clean_location

func _is_shared_location_position_valid(position: Vector3) -> bool:
	return (
		is_finite(position.x)
		and is_finite(position.y)
		and is_finite(position.z)
		and absf(position.x) <= 250.0
		and absf(position.z) <= 250.0
		and position.y >= -10.0
		and position.y <= 100.0
	)


func build_shared_location_message(position: Vector3) -> String:
	if not _is_shared_location_position_valid(position):
		return ""
	return "KINGLOC1|%s|%s|%s" % [str(snappedf(position.x, 0.001)), str(snappedf(position.y, 0.001)), str(snappedf(position.z, 0.001))]


func parse_shared_location_message(message_body: String) -> Dictionary:
	var parts := message_body.strip_edges().split("|", false)
	if parts.size() != 4 or parts[0] != "KINGLOC1":
		return {}
	for index in range(1, 4):
		if not parts[index].is_valid_float():
			return {}
	var location := Vector3(float(parts[1]), float(parts[2]), float(parts[3]))
	if not _is_shared_location_position_valid(location):
		return {}
	return {"position": location}


func parse_shared_location_uri(uri: String) -> Dictionary:
	if not uri.begins_with("kingloc://"):
		return {}
	var coordinates := uri.trim_prefix("kingloc://").split(",", false)
	if coordinates.size() != 3:
		return {}
	return parse_shared_location_message("KINGLOC1|%s|%s|%s" % [coordinates[0], coordinates[1], coordinates[2]])


func format_public_chat_message(sender_name: String, message_body: String) -> String:
	var clean_sender := sender_name.strip_edges().substr(0, 24)
	if clean_sender.is_empty():
		clean_sender = "لاعب"
	var safe_sender := clean_sender.replace("[", "(").replace("]", ")")
	var location_data := parse_shared_location_message(message_body)
	var clean_body := message_body.strip_edges().replace("[", "(").replace("]", ")")
	if not location_data.is_empty():
		var location: Vector3 = location_data["position"]
		var location_uri := "kingloc://%s,%s,%s" % [str(snappedf(location.x, 0.001)), str(snappedf(location.y, 0.001)), str(snappedf(location.z, 0.001))]
		clean_body = "📍 موقع مشترك — [url=%s]متابعة[/url]" % location_uri
	return "[color=gold][" + safe_sender + "][/color] " + clean_body + "\n"


func _build_shared_location_direction_arrow() -> void:
	shared_location_direction_arrow = Label.new()
	shared_location_direction_arrow.name = "SharedLocationDirectionArrow"
	shared_location_direction_arrow.text = "➤"
	shared_location_direction_arrow.anchor_left = 0.5
	shared_location_direction_arrow.anchor_right = 0.5
	shared_location_direction_arrow.anchor_top = 0.12
	shared_location_direction_arrow.anchor_bottom = 0.12
	shared_location_direction_arrow.offset_left = -9.0
	shared_location_direction_arrow.offset_right = 9.0
	shared_location_direction_arrow.offset_top = -9.0
	shared_location_direction_arrow.offset_bottom = 9.0
	shared_location_direction_arrow.add_theme_font_size_override("font_size", 13)
	shared_location_direction_arrow.add_theme_color_override("font_color", Color(1.0, 0.78, 0.28))
	shared_location_direction_arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shared_location_direction_arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	shared_location_direction_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shared_location_direction_arrow.visible = false
	root.add_child(shared_location_direction_arrow)


func _update_shared_location_direction_arrow() -> void:
	if not is_instance_valid(shared_location_direction_arrow):
		return
	if not shared_location_follow_active:
		shared_location_direction_arrow.visible = false
		return
	if is_instance_valid(main_scene) and main_scene.has_method("is_shared_location_navigation_active") and not bool(main_scene.call("is_shared_location_navigation_active")):
		shared_location_direction_arrow.visible = false
		shared_location_follow_active = false
		return
	var actor: Node3D = main_scene.call("get_shared_location_navigation_actor") if is_instance_valid(main_scene) and main_scene.has_method("get_shared_location_navigation_actor") else null
	if not is_instance_valid(actor):
		shared_location_direction_arrow.visible = false
		shared_location_follow_active = false
		return
	var delta := shared_location_follow_target - actor.global_position
	delta.y = 0.0
	var is_vehicle := bool(main_scene.get("vehicle_occupied")) if is_instance_valid(main_scene) else false
	if should_hide_shared_location_arrow(delta.length(), is_vehicle):
		shared_location_direction_arrow.visible = false
		shared_location_follow_active = false
		return
	var camera := actor.get_node_or_null("CameraPivot/SpringArm3D/Camera3D") as Camera3D
	if not is_instance_valid(camera):
		camera = actor.get_node_or_null("VehicleCameraPivot/SpringArm3D/VehicleCamera") as Camera3D
	if not is_instance_valid(camera):
		shared_location_direction_arrow.visible = false
		return
	var forward := -camera.global_transform.basis.z
	var right := camera.global_transform.basis.x
	shared_location_direction_arrow.rotation = calculate_shared_location_arrow_rotation(delta, forward, right)
	shared_location_direction_arrow.visible = true


func should_hide_shared_location_arrow(distance: float, is_vehicle: bool) -> bool:
	# يجب أن يظل السهم ظاهرًا حتى نفس حد الوصول الفعلي لكل وسيلة حركة.
	var arrival_distance := 2.0 if is_vehicle else 2.5
	return not is_finite(distance) or distance <= arrival_distance


func calculate_shared_location_arrow_rotation(target_delta: Vector3, camera_forward: Vector3, camera_right: Vector3) -> float:
	var flat_direction := target_delta
	flat_direction.y = 0.0
	var flat_forward := camera_forward
	flat_forward.y = 0.0
	var flat_right := camera_right
	flat_right.y = 0.0
	if flat_direction.length_squared() <= 0.000001 or flat_right.length_squared() <= 0.000001:
		return 0.0
	# عند توجيه الكاميرا عموديًا تقريبًا، استنتج الأمام الأفقي من اليمين.
	if flat_forward.length_squared() <= 0.000001:
		flat_forward = Vector3.UP.cross(flat_right)
	if flat_forward.length_squared() <= 0.000001:
		return 0.0
	flat_direction = flat_direction.normalized()
	flat_forward = flat_forward.normalized()
	# أزل مركبة الأمام من اليمين أولًا؛ إسقاط أساس الكاميرا المائل على
	# المستوى الأفقي قد يجعلهما غير متعامدين ويشوّه زاوية السهم.
	flat_right -= flat_forward * flat_right.dot(flat_forward)
	if flat_right.length_squared() <= 0.000001:
		flat_right = flat_forward.cross(Vector3.UP)
	if flat_right.length_squared() <= 0.000001:
		return 0.0
	flat_right = flat_right.normalized()
	var angle := atan2(flat_direction.dot(flat_right), flat_direction.dot(flat_forward))
	return angle - PI * 0.5


func _on_social_chat_meta_clicked(meta: Variant) -> void:
	var location_data := parse_shared_location_uri(str(meta))
	if location_data.is_empty():
		return
	var location: Vector3 = location_data["position"]
	if not is_instance_valid(main_scene) or not main_scene.has_method("begin_shared_location_navigation"):
		social_chat_status.text = "التوجيه إلى الموقع غير متاح حاليًا."
		return
	var started: bool = bool(main_scene.call("begin_shared_location_navigation", location))
	if started:
		shared_location_follow_target = location
		shared_location_follow_active = true
		social_chat_status.text = "بدأت متابعة الموقع. يمكنك إيقافها بالتحكم اليدوي."
	else:
		social_chat_status.text = "تعذر بدء التوجيه؛ أوقف المهمة أو الوظيفة الحالية أولًا."


func _update_shared_location_button_state() -> void:
	if not is_instance_valid(social_chat_location_button):
		return
	var can_share := not resolve_shared_location_chat_destination(social_chat_channel, selected_friend_conversation_id).is_empty()
	social_chat_location_button.disabled = not can_share
	social_chat_location_button.tooltip_text = "مشاركة موقعي في هذه المحادثة" if can_share else "اختر محادثة صالحة أولًا لمشاركة موقعك"


func resolve_shared_location_chat_destination(channel: String, conversation_id: String = "") -> Dictionary:
	match channel:
		"الأصدقاء":
			var normalized_conversation_id := conversation_id.strip_edges()
			if normalized_conversation_id.is_empty():
				return {}
			return {"kind": "direct", "conversation_id": normalized_conversation_id}
		"المجموعة":
			return {"kind": "group"}
		"العامة":
			return {"kind": "public"}
		_:
			return {}


func _share_current_location() -> void:
	if not is_instance_valid(main_scene) or not main_scene.has_method("get_shared_location_navigation_actor"):
		social_chat_status.text = "تعذر تحديد موقعك الحالي."
		return
	var actor: Node3D = main_scene.call("get_shared_location_navigation_actor")
	if not is_instance_valid(actor):
		social_chat_status.text = "تعذر تحديد موقعك الحالي."
		return
	var location_message := build_shared_location_message(actor.global_position)
	if location_message.is_empty():
		social_chat_status.text = "مشاركة الموقع متاحة داخل المدينة حاليًا."
		return
	var destination := resolve_shared_location_chat_destination(social_chat_channel, selected_friend_conversation_id)
	if destination.is_empty():
		social_chat_status.text = "اختر محادثة صالحة أولًا لمشاركة موقعك."
		return
	var sent := false
	match str(destination.get("kind", "")):
		"direct":
			_pending_direct_send_conversation_id = str(destination.get("conversation_id", ""))
			sent = SocialChatManager.send_direct_message(_pending_direct_send_conversation_id, location_message)
			if not sent:
				_pending_direct_send_conversation_id = ""
		"group":
			sent = SocialChatManager.send_chat_message("group", location_message)
		"public":
			sent = SocialChatManager.send_chat_message("public", location_message)
	if sent:
		social_chat_status.text = "جارٍ إرسال موقعك إلى هذه المحادثة..."
	else:
		social_chat_status.text = "تعذر إرسال موقعك الآن. حاول مرة أخرى."


func announce_party_started_in_public_chat(station: Node3D) -> bool:
	# يُستدعى فقط بعد تأكيد بدء الحفلة من خدمة الحفلات الخادمية.
	if not is_instance_valid(station) or not station.is_in_group("party_stations"):
		return false
	var location_name := str(station.get_meta("public_location_name", ""))
	if location_name.strip_edges().is_empty() and station.name == "CampPartyStation":
		location_name = "المخيم"
	return SocialChatManager.send_chat_message("public", build_party_announcement_body(location_name))


func can_accept_social_invitation_payload(topic: String, player_code: String, invite_id: String) -> bool:
	var normalized_code := player_code.strip_edges().to_upper()
	return (
		SocialChatManager.is_valid_player_code(normalized_code)
		and topic == "chat:invites:" + normalized_code
		and SocialChatManager.is_valid_invite_id(invite_id.strip_edges())
	)


func _update_group_gather_visibility() -> void:
	if not is_instance_valid(group_meeting_point_button):
		return
	group_meeting_point_button.visible = can_show_group_gather_button(
		_is_local_group_leader(),
		group_members.size(),
		_is_inside_private_apartment()
	)


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
	# لا نرسل إشارة محلية بلا مستقبِل؛ دعوة التجمع تحتاج خدمة خادمية فعلية.
	group_meeting_status.text = "لم تُرسل الدعوة: خدمة التجمع بين الأجهزة غير مفعّلة بعد."


func _is_local_group_leader() -> bool:
	if group_members.is_empty():
		return false
	var leader: Dictionary = group_members[0]
	var leader_id := str(leader.get("player_id", ""))
	return (leader_id == "local_leader" or (not local_player_code.is_empty() and leader_id == local_player_code)) and bool(leader.get("is_leader", false))


static func can_request_group_invite_for_player(player_code: String, group_size: int, max_members: int, already_member: bool, already_pending: bool) -> bool:
	return (
		SocialChatManager.is_valid_player_code(player_code)
		and group_size >= 1
		and max_members >= 2
		and group_size < max_members
		and not already_member
		and not already_pending
	)


func _request_group_invite(player_id: String) -> void:
	var code := player_id.strip_edges().to_upper()
	if not _is_local_group_leader():
		player_action_status.text = "دعوة أعضاء المجموعة متاحة للقائد فقط."
		return
	if not can_request_group_invite_for_player(code, group_members.size(), GROUP_MAX_MEMBERS, _group_contains(code), pending_group_invites.has(code)):
		if not SocialChatManager.is_valid_player_code(code):
			player_action_status.text = "رمز اللاعب غير صالح."
		elif group_members.size() >= GROUP_MAX_MEMBERS:
			player_action_status.text = "المجموعة مكتملة؛ الحد الأقصى أربعة لاعبين."
		else:
			player_action_status.text = "هذا اللاعب موجود بالفعل أو أُرسلت له دعوة."
		return
	if not AuthManager.is_authenticated():
		player_action_status.text = "سجّل الدخول أولًا لإرسال دعوة المجموعة."
		return
	pending_group_invites.append(code)
	_pending_group_invite_code = code
	player_primary_action_button.disabled = true
	player_primary_action_button.text = "جارٍ إرسال الدعوة..."
	if not SocialChatManager.invite_chat_group_member(code):
		if _pending_group_invite_code == code:
			pending_group_invites.erase(code)
			_pending_group_invite_code = ""
			player_primary_action_button.disabled = false
			player_primary_action_button.text = "دعوة للمجموعة"
		return
	player_action_status.text = "جارٍ إرسال دعوة المجموعة إلى الخادم..."
	group_invite_status.text = "جارٍ إرسال الدعوة إلى اللاعب..."
	_refresh_group_invite_friends(_group_invite_friends_cache)
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
			group_member_removed.emit(player_id)
			break
	if group_members.size() <= 1:
		group_meeting_position = Vector3.ZERO
		if group_follow_enabled:
			group_follow_enabled = false
			group_follow_mode_requested.emit(false)
	_refresh_group_popup()


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


func receive_group_member_positions(_member_positions: Array) -> void:
	# لا نعرض علامات أو دبوسًا مستقلًا لأعضاء المجموعة؛ التجمع مرتبط بموقع القائد الحالي.
	pass


func receive_group_move_order(target_position: Vector3) -> void:
	if not target_position.is_finite():
		if is_instance_valid(group_meeting_status):
			group_meeting_status.text = "تعذر استقبال موقع القائد؛ الإحداثيات غير صالحة."
		return
	group_meeting_position = target_position
	if is_instance_valid(group_meeting_status):
		group_meeting_status.text = "القائد دعا المجموعة للتجمع عند موقعه الحالي داخل المدينة."


func receive_group_meeting_point(position: Vector3, leader_name: String = "قائد المجموعة") -> void:
	if not position.is_finite():
		if is_instance_valid(group_meeting_status):
			group_meeting_status.text = "تعذر استقبال موقع القائد؛ الإحداثيات غير صالحة."
		return
	group_meeting_position = position
	if is_instance_valid(group_meeting_status):
		group_meeting_status.text = "موقع القائد الحالي للتجمع: %s" % leader_name.strip_edges().substr(0, 24)


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
	social_chat_log.meta_clicked.connect(_on_social_chat_meta_clicked)
	social_chat_log.scroll_following = true
	social_chat_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	social_chat_log.text = "[color=gray]لا توجد رسائل متصلة بعد. ستظهر الرسائل عند ربط القناة بالخادم.[/color]"
	conversation.add_child(social_chat_log)
	var composer := HBoxContainer.new()
	composer.add_theme_constant_override("separation", 4)
	conversation.add_child(composer)
	social_chat_input = LineEdit.new()
	social_chat_input.placeholder_text = "اكتب رسالة..."
	social_chat_input.add_theme_font_size_override("font_size", 12)
	social_chat_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	social_chat_input.text_submitted.connect(_submit_social_chat_message)
	composer.add_child(social_chat_input)
	social_chat_location_button = Button.new()
	social_chat_location_button.name = "ShareCurrentLocation"
	social_chat_location_button.text = "📍"
	social_chat_location_button.tooltip_text = "مشاركة موقعي في هذه المحادثة"
	social_chat_location_button.custom_minimum_size = Vector2(38, 38)
	social_chat_location_button.pressed.connect(_share_current_location)
	composer.add_child(social_chat_location_button)
	_update_shared_location_button_state()
	var send := Button.new()
	send.text = "إرسال"
	send.custom_minimum_size = Vector2(54, 38)
	send.pressed.connect(func(): _submit_social_chat_message(social_chat_input.text))
	composer.add_child(send)

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
	# friends, requests, selected player, group, unread counters, or moderation state visible.
	_sent_friend_requests.clear()
	_pending_friend_request_player_code = ""
	# Request counts and rows belong to the previous account; never leave its
	# incoming badge or request names visible after an account switch.
	friends_phone_incoming_count = 0
	if is_instance_valid(friends_phone_incoming_box):
		for child in friends_phone_incoming_box.get_children():
			child.queue_free()
		var incoming_empty := Label.new()
		incoming_empty.text = "لا توجد طلبات واردة."
		friends_phone_incoming_box.add_child(incoming_empty)
	if is_instance_valid(friends_phone_outgoing_box):
		for child in friends_phone_outgoing_box.get_children():
			child.queue_free()
		var outgoing_empty := Label.new()
		outgoing_empty.text = "لا توجد طلبات مرسلة."
		friends_phone_outgoing_box.add_child(outgoing_empty)
	_update_friends_phone_request_badge()
	selected_player_id = ""
	selected_player_is_friend = false
	_pending_player_moderation_action = ""
	_pending_player_moderation_code = ""
	selected_friend_code = ""
	selected_friend_conversation_id = ""
	_update_shared_location_button_state()
	_pending_direct_open_player_code = ""
	_pending_direct_read_conversation_id = ""
	_pending_direct_send_conversation_id = ""
	local_player_code = ""
	_direct_conversation_to_friend.clear()
	_friend_to_conversation.clear()
	_unread_direct_by_friend.clear()
	_unread_group_messages = 0
	_seen_realtime_message_ids.clear()
	_seen_realtime_message_order.clear()
	pending_group_invites.clear()
	_pending_group_invite_response_id = ""
	_deferred_group_invite_responses.clear()
	_apartment_invite_mode = false
	group_meeting_position = Vector3.ZERO
	group_follow_enabled = false
	if is_instance_valid(invitation_overlay):
		invitation_overlay.call("clear_pending_invitations")
	if is_instance_valid(friends_phone_friends_box):
		for child in friends_phone_friends_box.get_children():
			child.queue_free()
		var friends_empty := Label.new()
		friends_empty.text = "جارٍ تحميل أصدقاء الحساب..." if not current_user_id.is_empty() else "سجّل الدخول لعرض أصدقائك."
		friends_phone_friends_box.add_child(friends_empty)
	if is_instance_valid(friends_phone_search):
		friends_phone_search.clear()
	if is_instance_valid(friends_phone_status):
		friends_phone_status.text = "جارٍ تجهيز بيانات الحساب..." if not current_user_id.is_empty() else "سجّل الدخول لعرض أصدقائك وطلبات الصداقة."
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
	SocialChatManager.list_friend_requests()


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
	var target_code := player_code.strip_edges().to_upper()
	if not SocialChatManager.is_valid_player_code(target_code):
		social_chat_status.text = "تعذر فتح المحادثة: رمز الصديق غير صالح."
		return
	social_chat_channel = "الأصدقاء"
	selected_friend_code = target_code
	_pending_direct_open_player_code = target_code
	selected_friend_conversation_id = ""
	_update_shared_location_button_state()
	social_chat_log.clear()
	social_chat_status.text = "جارٍ فتح محادثة الصديق..."
	if is_instance_valid(social_group_invite_button):
		social_group_invite_button.visible = (social_chat_channel == "المجموعة")
	if not SocialChatManager.open_direct_conversation(target_code):
		if _pending_direct_open_player_code == target_code:
			_pending_direct_open_player_code = ""
			social_chat_status.text = "تعذر بدء فتح المحادثة. حاول مرة أخرى."


static func is_player_in_friend_list(player_code: String, friends: Array) -> bool:
	var target := player_code.strip_edges().to_upper()
	if not SocialChatManager.is_valid_player_code(target):
		return false
	for friend in friends:
		if friend is Dictionary and str(friend.get("player_code", "")).strip_edges().to_upper() == target:
			return true
	return false


func _sync_selected_player_friend_state(friends: Array) -> void:
	if not _has_selected_player():
		return
	# The friends list is authoritative in both directions: a removed friendship
	# must not leave the interaction popup offering a group invite indefinitely.
	selected_player_is_friend = is_player_in_friend_list(selected_player_id, friends)
	if selected_player_is_friend:
		_sent_friend_requests.erase(selected_player_id)
	_refresh_selected_player_friend_action_state()


func _refresh_selected_player_friend_action_state() -> void:
	if not _has_selected_player() or not is_instance_valid(player_primary_action_button):
		return
	var action_state := resolve_friend_action_state(
		selected_player_id,
		selected_player_is_friend,
		_pending_friend_request_player_code,
		_sent_friend_requests
	)
	player_primary_action_button.disabled = bool(action_state.get("disabled", false))
	player_primary_action_button.text = str(action_state.get("text", "إضافة صديق"))
	if is_instance_valid(player_action_status):
		player_action_status.text = str(action_state.get("status", ""))


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
			var report_target := _pending_player_moderation_code
			_pending_player_moderation_action = ""
			_pending_player_moderation_code = ""
			if is_instance_valid(player_report_send_button):
				player_report_send_button.disabled = false
			if selected_player_id == report_target:
				player_action_status.text = "نتيجة البلاغ: " + str(data)
			if str(data) == "report_submitted" and selected_player_id == report_target:
				player_popup.visible = false
		"block_player":
			var blocked_target := _pending_player_moderation_code
			_pending_player_moderation_action = ""
			_pending_player_moderation_code = ""
			if is_instance_valid(player_block_button):
				player_block_button.disabled = false
			if selected_player_id == blocked_target:
				player_action_status.text = "نتيجة الحظر: " + str(data)
			if str(data) == "blocked":
				if selected_player_id == blocked_target:
					player_popup.visible = false
				_refresh_blocked_players()
		"friend_requests_list":
			if data is Array:
				_render_friends_phone_requests(data)
				_refresh_selected_player_friend_action_state()
				friends_phone_status.text = "تم تحميل طلبات الصداقة الواردة والمرسلة."
		"friend_request_response":
			friends_phone_status.text = "تم تحديث حالة طلب الصداقة من الخادم."
			SocialChatManager.list_friend_requests()
			SocialChatManager.list_friends()
		"friends_list":
			if data is Array:
				_render_friends_phone_list(data)
				_sync_selected_player_friend_state(data)
			if data is Array and is_instance_valid(group_invite_popup) and group_invite_popup.visible:
				_refresh_group_invite_friends(data)
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
			if is_instance_valid(friends_phone_name_label) and data is Array and not data.is_empty() and data[0] is Dictionary:
				var loaded_profile: Dictionary = data[0]
				friends_phone_name_label.text = str(loaded_profile.get("display_name", "اسم اللاعب"))
				friends_phone_code_label.text = "رمز اللاعب: " + local_player_code
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
					if is_instance_valid(friends_phone_name_label):
						friends_phone_name_label.text = display_name_input.text
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
			var request_result := str(data)
			var completed_player_code := _pending_friend_request_player_code
			_pending_friend_request_player_code = ""
			# احتفظ بنتيجة الخادم حتى لو أُغلقت نافذة الشخصية أو فُتحت شخصية أخرى.
			if not completed_player_code.is_empty():
				if request_result == "sent":
					_sent_friend_requests[completed_player_code] = true
				else:
					_sent_friend_requests.erase(completed_player_code)
			if is_instance_valid(player_primary_action_button) and selected_player_id == completed_player_code and not selected_player_is_friend:
				if request_result == "sent":
					player_primary_action_button.disabled = true
					player_primary_action_button.text = "تم إرسال طلب الصداقة"
					player_action_status.text = "تم إرسال طلب صداقة لهذا اللاعب. ينتظر الرد."
				else:
					player_primary_action_button.disabled = false
					player_primary_action_button.text = "إضافة صديق"
					player_action_status.text = "لم يتم إرسال طلب الصداقة: " + request_result
			if is_instance_valid(social_chat_status):
				social_chat_status.text = "نتيجة طلب الصداقة: " + request_result
			if request_result == "sent":
				if is_instance_valid(friend_search_input):
					friend_search_input.clear()
				_refresh_social_friends()
				SocialChatManager.list_friend_requests()
		"direct_open":
			var requested_friend_code := _pending_direct_open_player_code
			_pending_direct_open_player_code = ""
			if data is Array and not data.is_empty() and data[0] is Dictionary:
				var result: Dictionary = data[0]
				if bool(result.get("success", false)):
					var conversation_id := str(result.get("conversation_id", "")).strip_edges()
					if conversation_id.is_empty():
						social_chat_status.text = "تعذر فتح المحادثة: لم يُرجع الخادم رقم المحادثة."
						return
					if not requested_friend_code.is_empty():
						_direct_conversation_to_friend[conversation_id] = requested_friend_code
						_friend_to_conversation[requested_friend_code] = conversation_id
					var request_is_still_selected := social_chat_channel == "الأصدقاء" and selected_friend_code == requested_friend_code
					if request_is_still_selected:
						selected_friend_conversation_id = conversation_id
						_update_shared_location_button_state()
						_unread_direct_by_friend.erase(requested_friend_code)
						_update_friend_unread_badge(requested_friend_code)
						_refresh_unread_indicators()
						SocialChatManager.subscribe_direct_chat(conversation_id)
						_pending_direct_read_conversation_id = conversation_id
						SocialChatManager.read_direct_messages(conversation_id)
				else:
					social_chat_status.text = "تعذر فتح المحادثة: " + str(result.get("error_code", "unknown"))
			else:
				social_chat_status.text = "تعذر فتح المحادثة: استجابة الخادم غير صالحة."
		"direct_read":
			var read_conversation_id := _pending_direct_read_conversation_id
			_pending_direct_read_conversation_id = ""
			if read_conversation_id.is_empty() or social_chat_channel != "الأصدقاء" or selected_friend_conversation_id != read_conversation_id:
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
					var sender := str(item.get("sender_name", "")).strip_edges()
					if sender.is_empty():
						sender = "أنت" if bool(item.get("sender_is_me", false)) else "الصديق"
					social_chat_log.append_text(format_public_chat_message(sender, str(item.get("body", ""))))
			social_chat_status.text = "محادثة الأصدقاء متصلة."
		"direct_send":
			var sent_conversation_id := _pending_direct_send_conversation_id
			_pending_direct_send_conversation_id = ""
			if data is Array and not data.is_empty() and data[0] is Dictionary and bool(data[0].get("success", false)):
				if social_chat_channel != "الأصدقاء" or selected_friend_conversation_id != sent_conversation_id:
					return
				social_chat_input.clear()
				_pending_direct_read_conversation_id = sent_conversation_id
				SocialChatManager.read_direct_messages(sent_conversation_id)
			else:
				if social_chat_channel == "الأصدقاء" and selected_friend_conversation_id == sent_conversation_id:
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
			var allowed: bool = data is bool and bool(data)
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
						var member_code := str(member.get("player_code", "")).strip_edges().to_upper()
						if not member_code.is_empty():
							pending_group_invites.erase(member_code)
						group_members.append({"player_id": member_code, "display_name": str(member.get("display_name", "لاعب")), "is_leader": bool(member.get("is_leader", false))})
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
			var completed_group_invite_code := _pending_group_invite_code
			_pending_group_invite_code = ""
			social_chat_status.text = "نتيجة دعوة المجموعة: " + str(data)
			group_invite_status.text = "تم إرسال طلب الدعوة إلى الخادم." if str(data) == "sent" else "رد الخادم: " + str(data)
			if str(data) != "sent" and not completed_group_invite_code.is_empty():
				pending_group_invites.erase(completed_group_invite_code)
			if not completed_group_invite_code.is_empty() and selected_player_id == completed_group_invite_code:
				player_action_status.text = "تم إرسال دعوة المجموعة. ينتظر انضمام اللاعب بعد قبولها." if str(data) == "sent" else "لم تُرسل الدعوة: " + str(data)
				player_primary_action_button.disabled = str(data) == "sent"
				player_primary_action_button.text = "تم إرسال الدعوة" if str(data) == "sent" else "دعوة للمجموعة"
			_refresh_group_popup()
			_refresh_group_invite_friends(_group_invite_friends_cache)
			SocialChatManager.get_chat_group()
		"group_invite_response":
			social_chat_status.text = "نتيجة الرد على الدعوة: " + str(data)
			if str(data) == "accepted" or str(data) == "declined":
				_remove_social_invite_card(_pending_group_invite_response_id)
			_pending_group_invite_response_id = ""
			_continue_deferred_group_invite_responses()
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
					var sender_name := str(item.get("sender_name", "")).strip_edges()
					if sender_name.is_empty():
						sender_name = "أنت" if bool(item.get("sender_is_me", false)) else "لاعب"
					social_chat_log.append_text(format_public_chat_message(sender_name, str(item.get("body", ""))))
			social_chat_status.text = "المحادثة متصلة بالخادم."
		_:
			social_chat_status.text = "اكتملت العملية: " + action


func _on_social_operation_failed(action: String, message: String) -> void:
	if action == "group_invite":
		group_invite_status.text = "تعذر إرسال الدعوة: " + message
		var failed_group_invite_code := _pending_group_invite_code
		if not failed_group_invite_code.is_empty():
			pending_group_invites.erase(failed_group_invite_code)
			_pending_group_invite_code = ""
			if selected_player_id == failed_group_invite_code:
				player_primary_action_button.disabled = false
				player_primary_action_button.text = "دعوة للمجموعة"
				player_action_status.text = "تعذر إرسال دعوة المجموعة: " + message
		_refresh_group_invite_friends(_group_invite_friends_cache)
		_refresh_group_popup()
	if action == "group_invite_response":
		_pending_group_invite_response_id = ""
		_continue_deferred_group_invite_responses()
	if action == "display_name_get" or action == "display_name_change":
		if is_instance_valid(display_name_status):
			display_name_status.text = "تعذر تنفيذ العملية: " + message
		return
	if action == "direct_read":
		_pending_direct_read_conversation_id = ""
		return
	if action == "direct_send":
		var failed_send_conversation_id := _pending_direct_send_conversation_id
		_pending_direct_send_conversation_id = ""
		if social_chat_channel == "الأصدقاء" and selected_friend_conversation_id == failed_send_conversation_id:
			social_chat_status.text = "تعذر إرسال الرسالة: " + message
		return
	if action == "direct_open":
		var failed_direct_code := _pending_direct_open_player_code
		_pending_direct_open_player_code = ""
		if not failed_direct_code.is_empty() and selected_friend_code == failed_direct_code and social_chat_channel == "الأصدقاء":
			social_chat_status.text = "تعذر فتح المحادثة: " + message
	if action == "block_player" or action == "report_player":
		var failed_moderation_code := _pending_player_moderation_code
		_pending_player_moderation_action = ""
		_pending_player_moderation_code = ""
		if is_instance_valid(player_block_button):
			player_block_button.disabled = false
		if is_instance_valid(player_report_send_button):
			player_report_send_button.disabled = false
		if action == "report_player" and selected_player_id == failed_moderation_code and is_instance_valid(player_report_row):
			player_report_row.visible = true
			player_report_button.text = "إخفاء البلاغ"
		if is_instance_valid(player_action_status) and selected_player_id == failed_moderation_code:
			player_action_status.text = "تعذر تنفيذ الإجراء: " + message
	if action == "friend_request":
		var failed_player_code := _pending_friend_request_player_code
		_pending_friend_request_player_code = ""
		if is_instance_valid(player_primary_action_button) and not selected_player_is_friend:
			player_primary_action_button.disabled = false
			if selected_player_id == failed_player_code:
				player_primary_action_button.text = "إضافة صديق"
		if is_instance_valid(player_action_status) and selected_player_id == failed_player_code:
			player_action_status.text = "تعذر إرسال طلب الصداقة: " + message
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
	if not can_receive_social_invitation_event(event_name):
		return
	if event_name == "group_invite":
		# Accept invitations only from the private topic bound to this player's verified code.
		var incoming_invite_id := str(payload.get("invite_id", payload.get("id", ""))).strip_edges()
		if not can_accept_social_invitation_payload(topic, local_player_code, incoming_invite_id):
			return
		var invitation := payload.duplicate(true)
		invitation["type"] = event_name
		invitation["invite_id"] = incoming_invite_id
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
	if event_name == "chat_message" and topic != "chat:public:messages" and not topic.begins_with("chat:group:"):
		return
	if event_name == "direct_message" and not topic.begins_with("chat:direct:"):
		return
	# Keep deduplication bounded so long sessions cannot grow memory indefinitely.
	var message_id := str(payload.get("message_id", ""))
	if not _remember_realtime_message_id(message_id):
		return
	var active_group_topic := "chat:group:" + SocialChatManager._realtime_group_id
	var should_show := false
	if topic == "chat:public:messages" and social_chat_channel == "العامة" and social_chat_panel.visible:
		should_show = true
	elif not SocialChatManager._realtime_group_id.is_empty() and topic == active_group_topic and social_chat_channel == "المجموعة" and social_chat_panel.visible:
		should_show = true
	elif not selected_friend_conversation_id.is_empty() and topic == "chat:direct:" + selected_friend_conversation_id and social_chat_channel == "الأصدقاء" and social_chat_panel.visible:
		should_show = true
	if not should_show or not is_instance_valid(social_chat_log):
		if not SocialChatManager._realtime_group_id.is_empty() and topic == active_group_topic:
			_unread_group_messages += 1
		elif topic.begins_with("chat:direct:"):
			var conversation_id := topic.trim_prefix("chat:direct:")
			var friend_code := str(_direct_conversation_to_friend.get(conversation_id, ""))
			if not friend_code.is_empty():
				_unread_direct_by_friend[friend_code] = int(_unread_direct_by_friend.get(friend_code, 0)) + 1
				_update_friend_unread_badge(friend_code)
		_refresh_unread_indicators()
		return
	if topic.begins_with("chat:group:"):
		_unread_group_messages = 0
	elif topic.begins_with("chat:direct:"):
		var active_friend_code := str(_direct_conversation_to_friend.get(selected_friend_conversation_id, selected_friend_code))
		if not active_friend_code.is_empty():
			_unread_direct_by_friend.erase(active_friend_code)
			_update_friend_unread_badge(active_friend_code)
	_refresh_unread_indicators()
	var sender := str(payload.get("sender_name", "لاعب"))
	social_chat_log.append_text(format_public_chat_message(sender, str(payload.get("body", ""))))


func _remember_realtime_message_id(message_id: String) -> bool:
	var clean_id := message_id.strip_edges()
	if clean_id.is_empty():
		return true
	if _seen_realtime_message_ids.has(clean_id):
		return false
	_seen_realtime_message_ids[clean_id] = true
	_seen_realtime_message_order.append(clean_id)
	while _seen_realtime_message_order.size() > REALTIME_MESSAGE_DEDUPE_LIMIT:
		var expired_id: String = str(_seen_realtime_message_order.pop_front())
		_seen_realtime_message_ids.erase(expired_id)
	return true


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
		_submit_group_invitation_response(invitation, true)
	else:
		social_chat_status.text = "تعذر قبول الدعوة: خدمة هذا النوع غير متاحة على الخادم حاليًا."


func _on_invitation_declined(invitation: Dictionary) -> void:
	var kind := str(invitation.get("type", ""))
	if kind == "group_invite":
		_submit_group_invitation_response(invitation, false)
	else:
		# Do not claim a server-side decline when this invitation type has no RPC.
		social_chat_status.text = "لم يُسجَّل رفض الدعوة على الخادم؛ خدمة هذا النوع غير متاحة حاليًا."


func _on_invitation_expired(invitation: Dictionary) -> void:
	var kind := str(invitation.get("type", ""))
	if kind == "group_invite":
		_submit_group_invitation_response(invitation, false)
		social_chat_status.text = "انتهت صلاحية دعوة المجموعة بعد 30 ثانية."
	else:
		social_chat_status.text = "انتهت مهلة الدعوة محليًا؛ لم يتوفر إجراء خادمي لهذا النوع."


func _submit_group_invitation_response(invitation: Dictionary, accepted: bool) -> void:
	# Only one invitation response may own the shared RPC slot. Expired queued
	# invitations are serialized here instead of being silently lost.
	var invite_id := str(invitation.get("invite_id", "")).strip_edges()
	# Validate again at the final RPC boundary so legacy/local UI paths cannot
	# submit malformed identifiers even if they bypass realtime payload checks.
	if not SocialChatManager.is_valid_invite_id(invite_id):
		return
	# Re-check the absolute deadline at the final client RPC boundary too;
	# the overlay's click-time check alone is not enough if processing was delayed.
	accepted = resolve_deferred_invitation_acceptance(
		invitation,
		accepted,
		float(Time.get_unix_time_from_system())
	)
	if not _pending_group_invite_response_id.is_empty():
		if invite_id == _pending_group_invite_response_id:
			return
		for queued_response in _deferred_group_invite_responses:
			if str(queued_response.get("invite_id", "")) == invite_id:
				return
		_deferred_group_invite_responses.append({
				"invite_id": invite_id,
				"invitation": invitation.duplicate(true),
				"accepted": accepted
			})
		return
	_pending_group_invite_response_id = invite_id
	if is_instance_valid(invitation_overlay):
		invitation_overlay.call("set_response_pending", true)
	# The manager emits operation_failed synchronously when an RPC cannot
	# start, and the failure handler releases this slot and advances the queue.
	# Do not advance here as well or one failed request could skip a queued item.
	SocialChatManager.respond_chat_group_invite(invite_id, accepted)


func resolve_deferred_invitation_acceptance(invitation: Dictionary, accepted: bool, now: float) -> bool:
	if not accepted:
		return false
	# A queued acceptance must not outlive the invitation's absolute deadline.
	# Missing deadlines fail closed; the server remains the final authority.
	var expires_at := float(invitation.get("expires_at", 0.0))
	return expires_at > now


func _continue_deferred_group_invite_responses() -> void:
	if not _pending_group_invite_response_id.is_empty():
		return
	if not _deferred_group_invite_responses.is_empty():
		var next_response: Dictionary = _deferred_group_invite_responses.pop_front()
		var next_invitation: Dictionary = next_response.get("invitation", {})
		var requested_acceptance := bool(next_response.get("accepted", false))
		var safe_acceptance := resolve_deferred_invitation_acceptance(
			next_invitation,
			requested_acceptance,
			float(Time.get_unix_time_from_system())
		)
		_submit_group_invitation_response(next_invitation, safe_acceptance)
		return
	if is_instance_valid(invitation_overlay):
		invitation_overlay.call("set_response_pending", false)


func _respond_to_social_group_invite(invite_id: String, accepted: bool) -> void:
	# Keep legacy invite cards on the same serialized response path as the unified overlay.
	_submit_group_invitation_response({
		"invite_id": invite_id,
		"type": "group_invite"
	}, accepted)


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
	_update_shared_location_button_state()
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
		_pending_direct_send_conversation_id = selected_friend_conversation_id
		if not SocialChatManager.send_direct_message(_pending_direct_send_conversation_id, message):
			_pending_direct_send_conversation_id = ""
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
