extends Node
## Online play over WebSockets (the only transport browsers allow).
##
## Client: connects to `tfpp/multiplayer/server_url` (or a `?server=` URL
## parameter on the web). With no URL, or while the server is unreachable, the
## game is simply single-player. Each client simulates its own movement and
## shares its position; the server relays it to everyone else.
##
## Dedicated server: `godot --headless --path . -- --server [--port=9080] [--bind=127.0.0.1]`

const DEFAULT_PORT := 9080
const SEND_INTERVAL := 0.05
const RETRY_INTERVAL := 5.0
## Positions far outside the arena are ignored.
const ARENA_LIMIT := 60.0
const RemotePlayer := preload("res://scripts/remote_player.gd")

var is_dedicated_server := false
var server_url := ""
var connected := false
var _send_timer := 0.0
var _retry_timer := 0.0
var _connecting := false
var _avatars := {}


func _ready() -> void:
	var args := _user_args()
	if args.has("server") or OS.has_feature("dedicated_server"):
		_start_server(int(args.get("port", DEFAULT_PORT)), str(args.get("bind", "127.0.0.1")))
		return
	server_url = str(ProjectSettings.get_setting("tfpp/multiplayer/server_url", ""))
	if OS.has_feature("web"):
		var override = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('server') || ''")
		if override is String and (override.begins_with("wss://") or override.begins_with("ws://")):
			server_url = override
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_disconnected)
	multiplayer.server_disconnected.connect(_on_disconnected)
	multiplayer.peer_disconnected.connect(_remove_avatar)
	_connect()


func _user_args() -> Dictionary:
	var result := {}
	for arg in OS.get_cmdline_user_args():
		var pair := arg.trim_prefix("--").split("=", true, 1)
		result[pair[0]] = pair[1] if pair.size() > 1 else ""
	return result


func _start_server(port: int, bind: String) -> void:
	is_dedicated_server = true
	Engine.max_fps = 60
	var peer := WebSocketMultiplayerPeer.new()
	var error := peer.create_server(port, bind)
	if error != OK:
		push_error("Multiplayer server could not listen on %s:%d (error %d)" % [bind, port, error])
		get_tree().quit(1)
		return
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(func(id: int) -> void: print("Player %d joined (%d online)" % [id, player_count()]))
	multiplayer.peer_disconnected.connect(func(id: int) -> void: print("Player %d left (%d online)" % [id, player_count()]))
	print("Multiplayer server listening on %s:%d" % [bind, port])


func _connect() -> void:
	if server_url.is_empty() or _connecting:
		return
	var peer := WebSocketMultiplayerPeer.new()
	if peer.create_client(server_url) != OK:
		_retry_timer = RETRY_INTERVAL
		return
	_connecting = true
	multiplayer.multiplayer_peer = peer


func _on_connected() -> void:
	_connecting = false
	connected = true


func _on_disconnected() -> void:
	_connecting = false
	connected = false
	multiplayer.multiplayer_peer = null
	for id in _avatars.keys():
		_remove_avatar(id)
	_retry_timer = RETRY_INTERVAL


## Players online including this one; 0 when offline.
func player_count() -> int:
	if is_dedicated_server:
		return multiplayer.get_peers().size()
	if not connected:
		return 0
	# Peer 1 is the dedicated server, not a player.
	var count := 1
	for id in multiplayer.get_peers():
		if id != 1:
			count += 1
	return count


func _physics_process(delta: float) -> void:
	if is_dedicated_server:
		return
	if not connected:
		if not _connecting and not server_url.is_empty():
			_retry_timer -= delta
			if _retry_timer <= 0.0:
				_connect()
		return
	_send_timer -= delta
	if _send_timer > 0.0:
		return
	_send_timer = SEND_INTERVAL
	var scene := get_tree().current_scene
	if scene == null:
		return
	var player := scene.get_node_or_null("Player") as Node3D
	if player:
		_player_state.rpc(player.global_position, player.rotation.y)


## Sent by each client; the server relays it to every other client.
@rpc("any_peer", "call_remote", "unreliable_ordered")
func _player_state(player_position: Vector3, yaw: float) -> void:
	if is_dedicated_server:
		return
	var id := multiplayer.get_remote_sender_id()
	if id <= 1 or not player_position.is_finite() or player_position.length() > ARENA_LIMIT:
		return
	var avatar = _avatars.get(id)
	if not is_instance_valid(avatar):
		var scene := get_tree().current_scene
		if scene == null:
			return
		avatar = RemotePlayer.new()
		avatar.name = "RemotePlayer%d" % id
		avatar.peer_id = id
		scene.add_child(avatar)
		_avatars[id] = avatar
	avatar.apply_state(player_position, wrapf(yaw, -PI, PI))


func _remove_avatar(id: int) -> void:
	var avatar = _avatars.get(id)
	_avatars.erase(id)
	if is_instance_valid(avatar):
		avatar.queue_free()
