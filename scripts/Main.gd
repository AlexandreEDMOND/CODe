extends Node3D

@export var server_port := 7777
@export var max_clients := 8
@export var bot_count := 3
@export var shooter_bot_enabled := true
@export var shooter_bot_spawn_index := 4
@export var shooter_bot_interval := 3.0
@export var shooter_bot_damage := 12.0
@export var player_respawn_delay := 2.5
@export var bot_respawn_delay := 2.0
@export var player_spawn_index := 0
@export var bot_spawn_start_index := 1
@export var kill_feed_max := 5
@export var kill_feed_duration := 4.0

@onready var players_root := $Players
@onready var bots_root := $Bots
@onready var spawn_points := $SpawnPoints.get_children()
@onready var info_label := $HUD/InfoLabel
@onready var kill_feed_label := $HUD/KillFeed

var player_scene := preload("res://scenes/Player.tscn")
var bot_scene := preload("res://scenes/Bot.tscn")
var rng := RandomNumberGenerator.new()
var next_bot_id := 1
var kill_feed_entries: Array[Dictionary] = []
var kill_feed_counter: int = 0

func _ready() -> void:
	rng.randomize()
	_ensure_input_actions()
	_sort_spawn_points()

	var mode := _get_arg_value("--mode", "host")
	server_port = int(_get_arg_value("--port", str(server_port)))

	if mode == "join":
		var ip := _get_arg_value("--ip", "127.0.0.1")
		_start_client(ip)
	else:
		_start_host()

func _ensure_input_actions() -> void:
	var key_actions := {
		"move_forward": [KEY_W, KEY_UP, KEY_Z],
		"move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT, KEY_Q],
		"move_right": [KEY_D, KEY_RIGHT],
		"jump": [KEY_SPACE],
		"sprint": [KEY_SHIFT],
		"reload": [KEY_R]
	}

	for action in key_actions.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for keycode in key_actions[action]:
			var ev := InputEventKey.new()
			ev.keycode = keycode
			if not InputMap.action_has_event(action, ev):
				InputMap.action_add_event(action, ev)

	if not InputMap.has_action("fire"):
		InputMap.add_action("fire")
		var mouse_ev := InputEventMouseButton.new()
		mouse_ev.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("fire", mouse_ev)
	else:
		var mouse_ev := InputEventMouseButton.new()
		mouse_ev.button_index = MOUSE_BUTTON_LEFT
		if not InputMap.action_has_event("fire", mouse_ev):
			InputMap.action_add_event("fire", mouse_ev)

	if not InputMap.has_action("aim"):
		InputMap.add_action("aim")
		var aim_ev := InputEventMouseButton.new()
		aim_ev.button_index = MOUSE_BUTTON_RIGHT
		InputMap.action_add_event("aim", aim_ev)
		var aim_key := InputEventKey.new()
		aim_key.keycode = KEY_V
		InputMap.action_add_event("aim", aim_key)

func _start_host() -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(server_port, max_clients)
	if err != OK:
		_set_info("Server error: %s" % error_string(err))
		return

	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	_spawn_player(multiplayer.get_unique_id())
	_spawn_bots()
	_spawn_shooter_bot()
	_set_info("Hosting on port %d" % server_port)

func _start_client(ip: String) -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, server_port)
	if err != OK:
		_set_info("Client error: %s" % error_string(err))
		return

	multiplayer.multiplayer_peer = peer
	_set_info("Joining %s:%d" % [ip, server_port])

func _on_peer_connected(peer_id: int) -> void:
	_spawn_player(peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	var node := players_root.get_node_or_null("Player_%d" % peer_id)
	if node:
		node.queue_free()

func _spawn_player(peer_id: int) -> void:
	if spawn_points.is_empty():
		return
	var spawn_transform := _get_spawn_transform(player_spawn_index)
	rpc("spawn_player", peer_id, spawn_transform)

@rpc("authority", "reliable", "call_local")
func spawn_player(peer_id: int, spawn_transform: Transform3D) -> void:
	var player := player_scene.instantiate()
	player.name = "Player_%d" % peer_id
	player.global_transform = spawn_transform
	player.set_multiplayer_authority(peer_id)
	player.spawn_index = player_spawn_index
	player.character_skin_seed = peer_id
	player.weapon_skin_seed = peer_id
	players_root.add_child(player)
	player.died.connect(_on_player_died)

func _spawn_bots() -> void:
	if not multiplayer.is_server():
		return
	for i in range(bot_count):
		var spawn_index := bot_spawn_start_index + i
		var spawn_transform := _get_spawn_transform(spawn_index)
		rpc("spawn_bot", next_bot_id, spawn_transform, spawn_index)
		next_bot_id += 1

func _spawn_shooter_bot() -> void:
	if not multiplayer.is_server() or not shooter_bot_enabled:
		return
	var spawn_transform := _get_spawn_transform(shooter_bot_spawn_index)
	rpc("spawn_shooter_bot", next_bot_id, spawn_transform, shooter_bot_spawn_index)
	next_bot_id += 1

@rpc("authority", "reliable", "call_local")
func spawn_bot(bot_id: int, spawn_transform: Transform3D, spawn_index: int) -> void:
	var bot := bot_scene.instantiate()
	bot.name = "Bot_%d" % bot_id
	bot.global_transform = spawn_transform
	bot.set_multiplayer_authority(1)
	bot.spawn_index = spawn_index
	bot.skin_seed = bot_id
	bots_root.add_child(bot)
	bot.died.connect(_on_bot_died)

@rpc("authority", "reliable", "call_local")
func spawn_shooter_bot(bot_id: int, spawn_transform: Transform3D, spawn_index: int) -> void:
	var bot := bot_scene.instantiate()
	bot.name = "Bot_Shooter_%d" % bot_id
	bot.global_transform = spawn_transform
	bot.set_multiplayer_authority(1)
	bot.spawn_index = spawn_index
	bot.skin_seed = bot_id
	bot.movement_enabled = false
	bot.jump_enabled = false
	bot.shooting_enabled = true
	bot.shoot_interval = shooter_bot_interval
	bot.shoot_damage = shooter_bot_damage
	bots_root.add_child(bot)
	bot.died.connect(_on_bot_died)

func _on_player_died(player: Node, killer_id: int) -> void:
	if not multiplayer.is_server():
		return
	if not is_instance_valid(player):
		return

	var headshot: bool = player.last_hit_was_headshot
	_broadcast_kill(player.name, killer_id, false, headshot)
	await get_tree().create_timer(player_respawn_delay).timeout
	if not is_instance_valid(player):
		return
	var spawn_transform := _get_spawn_transform(player.spawn_index)
	player.rpc("respawn_at", spawn_transform, player.max_health)

func _on_bot_died(bot: Node, killer_id: int) -> void:
	if not multiplayer.is_server():
		return
	if not is_instance_valid(bot):
		return

	var headshot: bool = bot.last_hit_was_headshot
	_broadcast_kill(bot.name, killer_id, true, headshot)
	await get_tree().create_timer(bot_respawn_delay).timeout
	if not is_instance_valid(bot):
		return
	var spawn_transform := _get_spawn_transform(bot.spawn_index)
	bot.rpc("respawn_at", spawn_transform, bot.max_health)

func _sort_spawn_points() -> void:
	spawn_points.sort_custom(func(a, b): return a.name < b.name)

func _get_spawn_transform(index: int) -> Transform3D:
	if spawn_points.is_empty():
		return Transform3D.IDENTITY
	var safe_index: int = clampi(index, 0, spawn_points.size() - 1)
	var marker: Node3D = spawn_points[safe_index]
	return marker.global_transform

func _set_info(text: String) -> void:
	if info_label:
		info_label.text = text

@rpc("authority", "reliable", "call_local")
func add_kill_feed(message: String) -> void:
	if kill_feed_label == null:
		return
	kill_feed_counter += 1
	var entry := {"id": kill_feed_counter, "text": message}
	kill_feed_entries.append(entry)
	while kill_feed_entries.size() > kill_feed_max:
		kill_feed_entries.pop_front()
	_update_kill_feed_label()
	var entry_id: int = kill_feed_counter
	await get_tree().create_timer(kill_feed_duration).timeout
	_remove_kill_entry(entry_id)

func _remove_kill_entry(entry_id: int) -> void:
	for i in range(kill_feed_entries.size()):
		if kill_feed_entries[i]["id"] == entry_id:
			kill_feed_entries.remove_at(i)
			break
	_update_kill_feed_label()

func _update_kill_feed_label() -> void:
	if kill_feed_label == null:
		return
	var lines: Array[String] = []
	for entry in kill_feed_entries:
		lines.append(entry["text"])
	kill_feed_label.text = "\n".join(lines)

func _broadcast_kill(victim_name: String, killer_id: int, victim_is_bot: bool, headshot: bool) -> void:
	var killer_name := _get_killer_name(killer_id)
	var victim_label := victim_name
	if victim_is_bot:
		victim_label = victim_name.replace("Bot_", "Bot ")
	else:
		victim_label = victim_name.replace("Player_", "Player ")
	var message := "%s -> %s" % [killer_name, victim_label]
	if headshot:
		message += " (HEADSHOT)"
	rpc("add_kill_feed", message)

func _get_killer_name(killer_id: int) -> String:
	if killer_id <= 0:
		return "World"
	return "Player %d" % killer_id

func _get_arg_value(flag: String, default_value: String) -> String:
	var args := OS.get_cmdline_args()
	for i in range(args.size()):
		var arg := args[i]
		if arg.begins_with(flag + "="):
			return arg.split("=")[1]
		if arg == flag and i + 1 < args.size():
			return args[i + 1]
	return default_value
