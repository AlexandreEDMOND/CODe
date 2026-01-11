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
@onready var pause_menu := $HUD/PauseMenu
@onready var name_edit := $HUD/PauseMenu/Panel/MenuHBox/LeftVBox/NameRow/NameEdit
@onready var sensitivity_slider := $HUD/PauseMenu/Panel/MenuHBox/LeftVBox/SensitivityRow/SensitivitySlider
@onready var sensitivity_value := $HUD/PauseMenu/Panel/MenuHBox/LeftVBox/SensitivityRow/SensitivityValue
@onready var character_skin_option := $HUD/PauseMenu/Panel/MenuHBox/LeftVBox/CharacterRow/CharacterSkinOption
@onready var weapon_skin_option := $HUD/PauseMenu/Panel/MenuHBox/LeftVBox/WeaponRow/WeaponSkinOption
@onready var close_button := $HUD/PauseMenu/Panel/MenuHBox/LeftVBox/ButtonsRow/CloseButton
@onready var preview_pivot := $HUD/PauseMenu/Panel/MenuHBox/RightVBox/PreviewViewportContainer/PreviewViewport/PreviewRoot/PreviewPivot
@onready var preview_camera := $HUD/PauseMenu/Panel/MenuHBox/RightVBox/PreviewViewportContainer/PreviewViewport/PreviewRoot/PreviewCamera
@onready var scoreboard_panel := $HUD/Scoreboard
@onready var scoreboard_label := $HUD/Scoreboard/ScoreboardLabel
@onready var minimap = $HUD/Minimap

var player_scene := preload("res://scenes/Player.tscn")
var bot_scene := preload("res://scenes/Bot.tscn")
var rng := RandomNumberGenerator.new()
var next_bot_id := 1
var kill_feed_entries: Array[Dictionary] = []
var kill_feed_counter: int = 0
var menu_open: bool = false
var character_skin_files: Array[String] = []
var weapon_skin_files: Array[String] = []
var preview_skin: Node3D = null
const SENS_MIN := 0.001
const SENS_MAX := 0.01
var scoreboard_visible: bool = false
var player_stats: Dictionary = {}

func _ready() -> void:
	rng.randomize()
	_ensure_input_actions()
	_sort_spawn_points()
	_connect_menu()

	var mode := _get_arg_value("--mode", "host")
	server_port = int(_get_arg_value("--port", str(server_port)))

	if mode == "join":
		var ip := _get_arg_value("--ip", "127.0.0.1")
		_start_client(ip)
	else:
		_start_host()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_toggle_menu()
		return
	if event is InputEventKey and event.keycode == KEY_TAB:
		if event.pressed:
			_set_scoreboard_visible(true)
		elif not event.pressed and not event.echo:
			_set_scoreboard_visible(false)

func _connect_menu() -> void:
	if close_button:
		close_button.pressed.connect(_close_menu)
	if sensitivity_slider:
		sensitivity_slider.value_changed.connect(_on_sensitivity_changed)
	if name_edit:
		name_edit.text_submitted.connect(_on_name_submitted)
		name_edit.focus_exited.connect(_on_name_focus_exited)
	if character_skin_option:
		character_skin_option.item_selected.connect(_on_character_skin_selected)
	if weapon_skin_option:
		weapon_skin_option.item_selected.connect(_on_weapon_skin_selected)

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

	if not InputMap.has_action("scoreboard"):
		InputMap.add_action("scoreboard")
		var tab_ev := InputEventKey.new()
		tab_ev.keycode = KEY_TAB
		InputMap.action_add_event("scoreboard", tab_ev)

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
	_ensure_player_stats(peer_id)
	_spawn_player(peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	var node := players_root.get_node_or_null("Player_%d" % peer_id)
	if node:
		node.queue_free()
	if player_stats.has(peer_id):
		player_stats.erase(peer_id)
	_broadcast_scoreboard()

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
	player.weapon_skin_seed = 0
	players_root.add_child(player)
	player.died.connect(_on_player_died)
	_ensure_player_stats(peer_id)
	_update_scoreboard()

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
	var victim_id := player.get_multiplayer_authority()
	_increment_death(victim_id)
	if killer_id > 0:
		_increment_kill(killer_id)
	_update_scoreboard()
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

func _set_scoreboard_visible(value: bool) -> void:
	scoreboard_visible = value
	if scoreboard_panel:
		scoreboard_panel.visible = value
	if value:
		_update_scoreboard()

func register_shot(shooter_name: String, position: Vector3) -> void:
	if multiplayer.is_server():
		rpc("client_register_shot", shooter_name, position)
	else:
		_register_shot_local(shooter_name, position)

@rpc("any_peer", "unreliable", "call_local")
func client_register_shot(shooter_name: String, position: Vector3) -> void:
	_register_shot_local(shooter_name, position)

func _register_shot_local(shooter_name: String, position: Vector3) -> void:
	if minimap:
		minimap.call("register_shot", shooter_name, position)

func _ensure_player_stats(peer_id: int) -> void:
	if not player_stats.has(peer_id):
		player_stats[peer_id] = {"kills": 0, "deaths": 0}
		_broadcast_scoreboard()

func _increment_kill(peer_id: int) -> void:
	_ensure_player_stats(peer_id)
	player_stats[peer_id]["kills"] = player_stats[peer_id]["kills"] + 1
	_broadcast_scoreboard()

func _increment_death(peer_id: int) -> void:
	_ensure_player_stats(peer_id)
	player_stats[peer_id]["deaths"] = player_stats[peer_id]["deaths"] + 1
	_broadcast_scoreboard()

func _update_scoreboard() -> void:
	if scoreboard_label == null:
		return
	var lines: Array[String] = []
	lines.append("SCOREBOARD")
	lines.append("Name                K   D")
	for peer_id in player_stats.keys():
		var peer_id_int: int = int(peer_id)
		var entry: Dictionary = player_stats[peer_id]
		var name := "Player %d" % peer_id_int
		var node: Node = players_root.get_node_or_null("Player_%d" % peer_id_int)
		if node and node.has_method("get_display_name"):
			name = node.get_display_name()
		lines.append("%-18s %3d %3d" % [name, entry["kills"], entry["deaths"]])
	scoreboard_label.text = "\n".join(lines)

func _broadcast_scoreboard() -> void:
	if multiplayer.is_server():
		rpc("client_set_scoreboard", player_stats)
	else:
		_update_scoreboard()

@rpc("any_peer", "reliable", "call_local")
func client_set_scoreboard(stats: Dictionary) -> void:
	player_stats = stats.duplicate(true)
	_update_scoreboard()

func _toggle_menu() -> void:
	menu_open = not menu_open
	if pause_menu:
		pause_menu.visible = menu_open
	if menu_open:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		_populate_menu_options()
		_sync_menu_from_player()
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	var player = _get_local_player()
	if player and player.has_method("set_menu_open"):
		player.set_menu_open(menu_open)

func _close_menu() -> void:
	if menu_open:
		_toggle_menu()

func _apply_menu_cosmetics() -> void:
	var player = _get_local_player()
	if player == null:
		return
	var name_value := ""
	if name_edit:
		name_value = name_edit.text
	var char_index := _get_selected_index(character_skin_option)
	var weapon_index := _get_selected_index(weapon_skin_option)
	if player.has_method("request_cosmetics"):
		player.request_cosmetics(name_value, char_index, weapon_index)

func _on_name_submitted(_text: String) -> void:
	_apply_menu_cosmetics()

func _on_name_focus_exited() -> void:
	_apply_menu_cosmetics()

func _on_sensitivity_changed(value: float) -> void:
	if sensitivity_value:
		sensitivity_value.text = "%d" % int(round(value))
	var player = _get_local_player()
	if player and player.has_method("set_mouse_sensitivity"):
		player.set_mouse_sensitivity(_ui_to_sensitivity(value))

func _populate_menu_options() -> void:
	if character_skin_files.is_empty():
		character_skin_files = _list_glb_files("res://models/characters/Models/GLB format", "character-")
	if weapon_skin_files.is_empty():
		weapon_skin_files = _list_glb_files("res://models/weapons/Models/GLB format", "blaster-")
	if character_skin_option and character_skin_option.get_item_count() == 0:
		for i in range(character_skin_files.size()):
			character_skin_option.add_item(_pretty_skin_name(character_skin_files[i]), i)
	if weapon_skin_option and weapon_skin_option.get_item_count() == 0:
		for i in range(weapon_skin_files.size()):
			weapon_skin_option.add_item(_pretty_skin_name(weapon_skin_files[i]), i)

func _sync_menu_from_player() -> void:
	var player = _get_local_player()
	if player == null:
		return
	if name_edit:
		if player.has_method("get_display_name"):
			name_edit.text = player.get_display_name()
		else:
			name_edit.text = player.name
	if sensitivity_slider:
		var ui_value := _sensitivity_to_ui(player.mouse_sensitivity)
		sensitivity_slider.value = ui_value
		_on_sensitivity_changed(ui_value)
	if character_skin_option and character_skin_files.size() > 0:
		var idx := _seed_to_index(player.character_skin_seed, character_skin_files.size())
		character_skin_option.select(idx)
		_update_character_preview(idx)
	if weapon_skin_option and weapon_skin_files.size() > 0:
		var widx := _seed_to_index(player.weapon_skin_seed, weapon_skin_files.size())
		weapon_skin_option.select(widx)

func _get_selected_index(option: OptionButton) -> int:
	if option == null:
		return 0
	return max(0, option.get_selected_id())

func _on_character_skin_selected(index: int) -> void:
	_update_character_preview(index)
	_apply_menu_cosmetics()

func _on_weapon_skin_selected(_index: int) -> void:
	_apply_menu_cosmetics()

func _seed_to_index(seed: int, count: int) -> int:
	if count <= 0:
		return 0
	return int(abs(seed)) % count

func _ui_to_sensitivity(value: float) -> float:
	var t: float = clamp(value / 100.0, 0.0, 1.0)
	return lerp(SENS_MIN, SENS_MAX, t)

func _sensitivity_to_ui(value: float) -> float:
	var t: float = 0.0
	if SENS_MAX > SENS_MIN:
		t = (value - SENS_MIN) / (SENS_MAX - SENS_MIN)
	return clamp(t, 0.0, 1.0) * 100.0

func _list_glb_files(dir_path: String, prefix: String) -> Array[String]:
	var files: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return files
	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		if not dir.current_is_dir():
			var lower := file.to_lower()
			if lower.ends_with(".glb") and (prefix == "" or file.begins_with(prefix)):
				files.append(dir_path + "/" + file)
		file = dir.get_next()
	dir.list_dir_end()
	files.sort()
	return files

func _pretty_skin_name(path: String) -> String:
	var file := path.get_file()
	var name := file.get_basename()
	return name.replace("_", " ").replace("-", " ")

func _update_character_preview(index: int) -> void:
	if preview_pivot == null:
		return
	if preview_skin:
		preview_skin.queue_free()
		preview_skin = null
	if index < 0 or index >= character_skin_files.size():
		return
	var skin_node: Node3D = _instantiate_skin(character_skin_files[index])
	if skin_node == null:
		return
	preview_skin = skin_node
	preview_pivot.add_child(preview_skin)
	preview_skin.scale = Vector3.ONE * 0.8
	preview_skin.position = Vector3(0.0, -0.35, 0.0)
	preview_skin.rotation = Vector3(0.0, 0.0, 0.0)
	if preview_camera:
		preview_camera.look_at(preview_pivot.global_transform.origin + Vector3(0.0, 1.0, 0.0), Vector3.UP)

func _instantiate_skin(path: String) -> Node3D:
	if path == "":
		return null
	var ext: String = path.get_extension().to_lower()
	if ext == "glb" or ext == "gltf":
		return _load_gltf_scene(path)
	var res: Resource = load(path)
	if res is PackedScene:
		var node: Node = (res as PackedScene).instantiate()
		if node is Node3D:
			return node
		return null
	if res is Mesh:
		var mesh_instance: MeshInstance3D = MeshInstance3D.new()
		mesh_instance.mesh = res as Mesh
		return mesh_instance
	return null

func _load_gltf_scene(path: String) -> Node3D:
	var doc: GLTFDocument = GLTFDocument.new()
	var state: GLTFState = GLTFState.new()
	var err: int = doc.append_from_file(path, state)
	if err != OK:
		return null
	var scene: Node = doc.generate_scene(state)
	if scene is Node3D:
		return scene
	return null

func _get_local_player() -> Node:
	if players_root == null:
		return null
	var peer_id := multiplayer.get_unique_id()
	return players_root.get_node_or_null("Player_%d" % peer_id)

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
		var victim_node: Node = players_root.get_node_or_null(victim_name)
		if victim_node and victim_node.has_method("get_display_name"):
			victim_label = victim_node.get_display_name()
		else:
			victim_label = victim_name.replace("Player_", "Player ")
	var message := "%s -> %s" % [killer_name, victim_label]
	if headshot:
		message += " (HEADSHOT)"
	rpc("add_kill_feed", message)

func _get_killer_name(killer_id: int) -> String:
	if killer_id <= 0:
		return "World"
	var player_node: Node = players_root.get_node_or_null("Player_%d" % killer_id)
	if player_node and player_node.has_method("get_display_name"):
		return player_node.get_display_name()
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
