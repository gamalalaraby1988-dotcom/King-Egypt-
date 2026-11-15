extends CanvasLayer
## Temporary TEST-project email OTP panel.
## It verifies Auth only; it deliberately does not link a player identity.

var _email_input: LineEdit
var _otp_input: LineEdit
var _status_label: Label
var _send_button: Button
var _verify_button: Button

func _ready() -> void:
	layer = 80
	_build_ui()
	AuthManager.otp_sent.connect(_on_otp_sent)
	AuthManager.authenticated.connect(_on_authenticated)
	AuthManager.authentication_failed.connect(_on_authentication_failed)

func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.name = "AuthBackdrop"
	backdrop.color = Color(0.025, 0.035, 0.045, 0.92)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 390)
	center.add_child(panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	panel.add_child(content)

	var title := Label.new()
	title.text = "𓂀  KING OF EGYPT CITY  𓂀"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.88, 0.68, 0.30))
	content.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "تسجيل الدخول الآمن — بيئة الاختبار"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(subtitle)

	var email_label := Label.new()
	email_label.text = "البريد الإلكتروني"
	content.add_child(email_label)

	_email_input = LineEdit.new()
	_email_input.placeholder_text = "أدخل بريدك الإلكتروني"
	_email_input.custom_minimum_size = Vector2(0, 48)
	_email_input.clear_button_enabled = true
	content.add_child(_email_input)

	_send_button = Button.new()
	_send_button.text = "إرسال رمز التحقق"
	_send_button.custom_minimum_size = Vector2(0, 48)
	_send_button.pressed.connect(_request_otp)
	content.add_child(_send_button)

	var otp_label := Label.new()
	otp_label.text = "رمز التحقق المكوّن من 6 أرقام"
	content.add_child(otp_label)

	_otp_input = LineEdit.new()
	_otp_input.placeholder_text = "000000"
	_otp_input.max_length = 6
	_otp_input.custom_minimum_size = Vector2(0, 48)
	_otp_input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	content.add_child(_otp_input)

	_verify_button = Button.new()
	_verify_button.text = "تأكيد الرمز"
	_verify_button.custom_minimum_size = Vector2(0, 48)
	_verify_button.disabled = true
	_verify_button.pressed.connect(_verify_otp)
	content.add_child(_verify_button)

	_status_label = Label.new()
	_status_label.text = "هذه شاشة اختبار؛ لن يتم ربط الحساب قبل التحقق."
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_color_override("font_color", Color(0.88, 0.82, 0.66))
	content.add_child(_status_label)

func _request_otp() -> void:
	var email := _email_input.text.strip_edges()
	_send_button.disabled = true
	_status_label.text = "جارٍ طلب رمز التحقق..."
	if not AuthManager.request_email_otp(email):
		_send_button.disabled = false

func _verify_otp() -> void:
	_verify_button.disabled = true
	_status_label.text = "جارٍ التحقق من الرمز..."
	if not AuthManager.verify_email_otp(_email_input.text, _otp_input.text):
		_verify_button.disabled = false

func _on_otp_sent(_email: String) -> void:
	_send_button.disabled = false
	_verify_button.disabled = false
	_status_label.text = "إذا كان البريد مسجلًا ومسموحًا له بتسجيل الدخول، فسيصلك رمز. أدخله هنا."

func _on_authenticated(_user_id: String, email: String) -> void:
	_send_button.disabled = true
	_verify_button.disabled = true
	_email_input.editable = false
	_otp_input.editable = false
	_status_label.text = "تم التحقق من البريد بنجاح: " + email + "\nلم يتم ربط حساب لاعب بعد؛ يلزم تنفيذ الربط الخادمي الآمن."

func _on_authentication_failed(message: String) -> void:
	_send_button.disabled = false
	_verify_button.disabled = false
	_status_label.text = message
