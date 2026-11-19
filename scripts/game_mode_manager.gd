extends Node
## دورة موحدة لاختيار اللعب المحلي والاتصال الجماعي.
## جلسات Online تستخدم WSS/TLS؛ لا يُقبل اتصال نقل غير مشفر.

signal status_changed(message: String)
signal mode_changed(mode: int)
signal online_connected
signal online_disconnected

enum Mode { UNSELECTED, OFFLINE, ONLINE }

var current_mode: Mode = Mode.UNSELECTED
var connection_state := "disconnected"
var peer: WebSocketMultiplayerPeer


func is_online_ready() -> bool:
	return current_mode == Mode.ONLINE and connection_state == "connected"


func select_offline() -> void:
	AuthoritativeGameServer.clear_client_session()
	_close_active_peer()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	current_mode = Mode.OFFLINE
	connection_state = "offline"
	mode_changed.emit(current_mode)
	status_changed.emit("أنت تلعب الآن دون إنترنت. تقدمك المحلي محفوظ على هذا الجهاز.")


func connect_online(address: String, port: int = 2456) -> void:
	var endpoint := address.strip_edges()
	if endpoint.is_empty() or port < 1 or port > 65535:
		status_changed.emit("عنوان الخادم أو المنفذ غير صالح.")
		return
	if not endpoint.begins_with("wss://"):
		if endpoint.contains("://") or endpoint.contains("/") or endpoint.contains(" "):
			status_changed.emit("يجب إدخال اسم نطاق الخادم فقط أو عنوان wss:// كامل.")
			return
		endpoint = "wss://%s:%d" % [endpoint, port]
	if connection_state == "connecting" or is_online_ready():
		status_changed.emit("يوجد اتصال Online قائم أو جارٍ بالفعل.")
		return

	_close_active_peer()
	peer = WebSocketMultiplayerPeer.new()
	var error := peer.create_client(endpoint)
	if error != OK:
		peer = null
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
		current_mode = Mode.UNSELECTED
		connection_state = "connection_failed"
		status_changed.emit("تعذر بدء اتصال WSS الآمن: %s" % error_string(error))
		return

	multiplayer.multiplayer_peer = peer
	current_mode = Mode.UNSELECTED
	connection_state = "connecting"
	_connect_lifecycle_signals()
	status_changed.emit("جارٍ الاتصال بالخادم. لن يبدأ وضع Online قبل تأكيد الاتصال.")


func disconnect_online() -> void:
	AuthoritativeGameServer.clear_client_session()
	if peer == null and not is_online_ready():
		return
	_close_active_peer()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	current_mode = Mode.UNSELECTED
	connection_state = "disconnected"
	mode_changed.emit(current_mode)
	status_changed.emit("تم إنهاء جلسة Online. اختر وضع اللعب للمتابعة.")
	online_disconnected.emit()


func _connect_lifecycle_signals() -> void:
	if not multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.connect(_on_connected_to_server)
	if not multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.connect(_on_connection_failed)
	if not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.connect(_on_server_disconnected)


func _close_active_peer() -> void:
	if peer != null:
		peer.close()
		peer = null


func _on_connected_to_server() -> void:
	if connection_state != "connecting":
		return
	connection_state = "connected"
	current_mode = Mode.ONLINE
	mode_changed.emit(current_mode)
	status_changed.emit("تم إنشاء اتصال WSS مشفر. جارٍ التحقق من حساب اللاعب.")
	online_connected.emit()


func _on_connection_failed() -> void:
	AuthoritativeGameServer.clear_client_session()
	_close_active_peer()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	current_mode = Mode.UNSELECTED
	connection_state = "connection_failed"
	mode_changed.emit(current_mode)
	status_changed.emit("فشل الاتصال. لم يتم الدخول إلى Online؛ يمكنك اختيار Offline أو المحاولة لاحقًا.")


func _on_server_disconnected() -> void:
	AuthoritativeGameServer.clear_client_session()
	_close_active_peer()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	current_mode = Mode.UNSELECTED
	connection_state = "disconnected"
	mode_changed.emit(current_mode)
	status_changed.emit("انقطع اتصال الخادم. تم إيقاف جلسة Online؛ تقدمك المحلي لم يتغير.")
	online_disconnected.emit()
