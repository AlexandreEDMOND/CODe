extends Control

@export var world_radius := 60.0
@export var ui_radius := 90.0
@export var border_thickness := 2.0
@export var background_color := Color(0.05, 0.07, 0.09, 0.65)
@export var border_color := Color(1.0, 1.0, 1.0, 0.2)
@export var player_color := Color(0.2, 1.0, 0.6, 0.9)
@export var other_color := Color(1.0, 0.25, 0.25, 0.9)
@export var player_dot_radius := 4.0
@export var other_dot_radius := 3.0
@export var shot_ping_duration := 2.4

var shot_pings: Dictionary = {}
@onready var players_root = get_node_or_null("/root/Main/Players")
@onready var bots_root = get_node_or_null("/root/Main/Bots")

func register_shot(name: String, _pos: Vector3) -> void:
	shot_pings[name] = shot_ping_duration

func _process(delta: float) -> void:
	if shot_pings.size() > 0:
		var keys: Array = shot_pings.keys()
		for key in keys:
			shot_pings[key] = float(shot_pings[key]) - delta
			if shot_pings[key] <= 0.0:
				shot_pings.erase(key)
	queue_redraw()

func _draw() -> void:
	var center: Vector2 = size * 0.5
	var radius: float = min(ui_radius, min(size.x, size.y) * 0.5)
	draw_circle(center, radius, background_color)
	draw_arc(center, radius, 0.0, TAU, 64, border_color, border_thickness, true)

	var player: Node3D = _get_local_player()
	if player == null:
		return
	draw_circle(center, player_dot_radius, player_color)

	var yaw: float = _get_player_yaw(player)
	var rotation := Basis(Vector3.UP, -yaw)
	var player_pos: Vector3 = player.global_transform.origin
	_draw_entities(players_root, player, player_pos, center, radius, rotation)
	_draw_entities(bots_root, null, player_pos, center, radius, rotation)

func _draw_entities(root: Node, local_player: Node, player_pos: Vector3, center: Vector2, radius: float, rotation: Basis) -> void:
	if root == null:
		return
	var scale: float = radius / max(world_radius, 0.01)
	for child in root.get_children():
		if child == local_player:
			continue
		var name: String = child.name
		if not shot_pings.has(name):
			continue
		if not (child is Node3D):
			continue
		var pos: Vector3 = (child as Node3D).global_transform.origin
		var offset: Vector3 = pos - player_pos
		offset.y = 0.0
		offset = rotation * offset
		var point := Vector2(offset.x, offset.z) * scale
		var max_len: float = radius - 6.0
		if point.length() > max_len:
			point = point.normalized() * max_len
		draw_circle(center + point, other_dot_radius, other_color)

func _get_local_player() -> Node3D:
	var root: Node = players_root
	if root == null:
		root = get_node_or_null("/root/Main/Players")
	if root == null:
		return null
	var peer_id: int = multiplayer.get_unique_id()
	return root.get_node_or_null("Player_%d" % peer_id) as Node3D

func _get_player_yaw(player: Node3D) -> float:
	var camera: Camera3D = player.get_node_or_null("Head/Camera3D") as Camera3D
	if camera:
		return camera.global_transform.basis.get_euler().y
	return player.global_transform.basis.get_euler().y
