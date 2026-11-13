extends Node
## متجر خفيف: يبيع إطلالات موجودة بالفعل دون إضافة مجسمات أو خامات جديدة.

const SAVE_PATH := "user://kings_city_store.cfg"
const OFFERS := [
	{"id":"men_formal", "name":"بدلة رجالية رسمية", "price":500},
	{"id":"women_formal", "name":"طقم نسائي رسمي", "price":500},
	{"id":"urban_casual", "name":"إطلالة كاجوال", "price":300},
	{"id":"sport", "name":"إطلالة رياضية", "price":250}
]

var mission_manager: Node
var wardrobe_manager: Node
var panel: PanelContainer
var list_box: VBoxContainer
var status_label: Label
var root_control: Control

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "ShopHUD"
	add_child(layer)
	root_control = Control.new()
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root_control)
	panel = PanelContainer.new()
	panel.visible = false
	root_control.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	scroll.add_child(content)
	var heading := Label.new()
	heading.text = "متجر الملابس — منتجات من أصول اللعبة"
	heading.add_theme_font_size_override("font_size", 20)
	content.add_child(heading)
	var note := Label.new()
	note.text = "لا يتم تحميل مجسمات جديدة؛ نستخدم الملابس الموجودة بالفعل."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(note)
	list_box = VBoxContainer.new()
	content.add_child(list_box)
	status_label = Label.new()
	content.add_child(status_label)
	var close_button := Button.new()
	close_button.text = "إغلاق المتجر"
	close_button.pressed.connect(func(): panel.visible = false)
	content.add_child(close_button)
	get_viewport().size_changed.connect(_update_layout)
	_update_layout()

func _update_layout() -> void:
	if not is_instance_valid(root_control) or not is_instance_valid(panel):
		return
	var view := get_viewport().get_visible_rect().size
	var panel_size := Vector2(minf(500.0, maxf(160.0, view.x - 28.0)), minf(520.0, maxf(180.0, view.y - 28.0)))
	panel.size = panel_size
	panel.position = (view - panel_size) * 0.5

func open_shop() -> void:
	_refresh_offers()
	status_label.text = "رصيدك: %d جنيه" % int(mission_manager.money)
	panel.visible = true

func _refresh_offers() -> void:
	for child in list_box.get_children():
		child.queue_free()
	var owned := _owned_items()
	for offer in OFFERS:
		var row := HBoxContainer.new()
		list_box.add_child(row)
		var label := Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var item_id: String = offer.id
		var price: int = int(offer.price)
		if owned.has(item_id):
			label.text = "%s — مملوكة" % offer.name
		else:
			label.text = "%s — %d جنيه" % [offer.name, price]
		row.add_child(label)
		var buy := Button.new()
		buy.text = "تم الشراء" if owned.has(item_id) else "شراء"
		buy.disabled = owned.has(item_id)
		buy.pressed.connect(func(): _buy(item_id))
		row.add_child(buy)

func _buy(item_id: String) -> void:
	if not is_instance_valid(mission_manager):
		status_label.text = "تعذر الوصول إلى ملف اللاعب."
		return
	if _owned_items().has(item_id):
		status_label.text = "هذا المنتج مملوك بالفعل."
		_refresh_offers()
		return
	var offer_price := 0
	for offer in OFFERS:
		if str(offer.id) == item_id:
			offer_price = int(offer.price)
			break
	if int(mission_manager.money) < offer_price:
		status_label.text = "رصيدك لا يكفي لشراء هذا المنتج."
		return
	if not mission_manager.has_method("purchase_outfit") or not mission_manager.purchase_outfit(item_id):
		status_label.text = "لم يكتمل الشراء؛ لم يتم اعتماد الخصم أو الملكية. حاول مرة أخرى."
		return
	if is_instance_valid(wardrobe_manager):
		wardrobe_manager.refresh_ownership()
	status_label.text = "تم الشراء وحفظ الرصيد والملكية معًا. رصيدك الآن: %d جنيه" % int(mission_manager.money)
	_refresh_offers()

func _owned_items() -> Array:
	if is_instance_valid(mission_manager) and mission_manager.has_method("get_owned_outfits"):
		return mission_manager.get_owned_outfits()
	return ["default"]
