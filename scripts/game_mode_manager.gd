extends Node
## إدارة اختيار وضع اللعب والاتصال الاختياري بخادم ENet.
## لا توجد بيانات حساب أو مكافآت سحابية هنا؛ يظل الحفظ المحلي هو المصدر الحالي.

signal status_changed(message: String)
signal online_connected

enum Mode { UNSELECTED, OFFLINE, ONLINE }
var current_mode: Mode = Mode.UNSELECTED
var connection_state := "disconnected"
var peer: ENetMultiplayerPeer

func select_offline() -> void:
	if peer != null:
		peer.close()
		peer = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	current_mode = Mode.OFFLINE
	connection_state = "offline"
	status_changed.emit("أنت تلعب الآن دون إنترنت. تقدمك محفوظ محليًا على هذا الجهاز.")

func connect_online(address: String, port: int = 2456) -> void:
	var host := address.strip_edges()
	if host.is_empty() or port < 1 or port > 65535:
		status_changed.emit("عنوان الخادم أو المنفذ غير صالح.")
		return
	if peer != null:
		peer.close()
		peer = null
	peer = ENetMultiplayerPeer.new()
	var error := peer.create_client(host, port)
	if error != OK:
		connection_state = "connection_failed"
		status_changed.emit("تعذر بدء الاتصال: %s" % error_string(error))
		peer = null
		return
	multiplayer.multiplayer_peer = peer
	current_mode = Mode.ONLINE
	connection_state = "connecting"
	if not multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.connect(_on_connected_to_server)
	if not multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.connect(_on_connection_failed)
	if not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.connect(_on_server_disconnected)
	status_changed.emit("جارٍ الاتصال بخادم اللعب الجماعي...")

func _on_connected_to_server() -> void:
	connection_state = "connected"
	status_changed.emit("تم الاتصال بخادم اللعب الجماعي.")
	online_connected.emit()

func _on_connection_failed() -> void:
	connection_state = "connection_failed"
	current_mode = Mode.UNSELECTED
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	peer = null
	status_changed.emit("فشل الاتصال. يمكنك اختيار اللعب دون إنترنت أو المحاولة لاحقًا.")

func _on_server_disconnected() -> void:
	connection_state = "disconnected"
	current_mode = Mode.UNSELECTED
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	peer = null
	status_changed.emit("انقطع اتصال الخادم. تقدمك المحلي لم يتغير؛ اختر وضع اللعب مجددًا.")
