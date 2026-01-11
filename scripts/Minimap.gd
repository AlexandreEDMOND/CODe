extends Control

const OVERLAY_SCRIPT := preload("res://scripts/MinimapOverlay.gd")
const MASK_SHADER := preload("res://shaders/minimap_mask.gdshader")

@export var world_radius := 60.0
@export var minimap_height := 60.0
@export var ui_radius := 90.0
@export var border_thickness := 2.0
@export var background_color := Color(0.05, 0.07, 0.09, 0.65)
@export var border_color := Color(1.0, 1.0, 1.0, 0.2)
@export var player_color := Color(0.2, 1.0, 0.6, 0.9)
@export var other_color := Color(1.0, 0.25, 0.25, 0.9)
@export var player_dot_radius := 4.0
@export var other_dot_radius := 3.0
@export var edge_padding := 6.0
@export var shot_ping_duration := 2.4
@export var rotate_with_player := true

var shot_pings: Dictionary = {}
var minimap_viewport: SubViewport = null
var minimap_camera: Camera3D = null
var minimap_texture_rect: TextureRect = null
var overlay: Control = null

@onready var players_root = get_node_or_null("/root/Main/Players")
@onready var bots_root = get_node_or_null("/root/Main/Bots")

func _ready() -> void:
	_setup_viewport()
	_update_viewport_size()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_viewport_size()

func register_shot(name: String, _pos: Vector3) -> void:
	shot_pings[name] = shot_ping_duration

func _process(delta: float) -> void:
	if shot_pings.size() > 0:
		var keys: Array = shot_pings.keys()
		for key in keys:
			shot_pings[key] = float(shot_pings[key]) - delta
			if shot_pings[key] <= 0.0:
				shot_pings.erase(key)
	_update_camera()
	if overlay:
		overlay.queue_redraw()

func _setup_viewport() -> void:
	minimap_viewport = SubViewport.new()
	minimap_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	minimap_viewport.transparent_bg = true
	minimap_viewport.own_world_3d = false
	minimap_viewport.world_3d = get_viewport().world_3d
	add_child(minimap_viewport)

	minimap_camera = Camera3D.new()
	minimap_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	minimap_camera.size = world_radius * 2.0
	minimap_camera.far = max(minimap_height * 3.0, 200.0)
	minimap_camera.near = 0.1
	minimap_camera.current = true
	minimap_viewport.add_child(minimap_camera)

	minimap_texture_rect = TextureRect.new()
	minimap_texture_rect.name = "MinimapTexture"
	minimap_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap_texture_rect.anchor_left = 0.0
	minimap_texture_rect.anchor_top = 0.0
	minimap_texture_rect.anchor_right = 1.0
	minimap_texture_rect.anchor_bottom = 1.0
	minimap_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	minimap_texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
	var mat := ShaderMaterial.new()
	mat.shader = MASK_SHADER
	minimap_texture_rect.material = mat
	add_child(minimap_texture_rect)

	overlay = Control.new()
	overlay.name = "Overlay"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.anchor_left = 0.0
	overlay.anchor_top = 0.0
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.set_script(OVERLAY_SCRIPT)
	overlay.set("minimap", self)
	add_child(overlay)

func _update_viewport_size() -> void:
	if minimap_viewport == null or minimap_texture_rect == null:
		return
	var size_int := Vector2i(max(64, int(size.x)), max(64, int(size.y)))
	minimap_viewport.size = size_int
	minimap_texture_rect.texture = minimap_viewport.get_texture()

func _update_camera() -> void:
	if minimap_camera == null:
		return
	var player: Node3D = _get_local_player()
	if player == null:
		return
	var pos: Vector3 = player.global_transform.origin
	minimap_camera.global_transform.origin = pos + Vector3(0.0, minimap_height, 0.0)
	if rotate_with_player:
		var yaw: float = _get_player_yaw(player)
		minimap_camera.rotation = Vector3(-PI * 0.5, yaw, 0.0)
	else:
		minimap_camera.rotation = Vector3(-PI * 0.5, 0.0, 0.0)

func draw_overlay(canvas: Control) -> void:
	var center: Vector2 = size * 0.5
	var radius: float = min(ui_radius, min(size.x, size.y) * 0.5)
	canvas.draw_arc(center, radius, 0.0, TAU, 64, border_color, border_thickness, true)

	var player: Node3D = _get_local_player()
	if player == null:
		return
	canvas.draw_circle(center, player_dot_radius, player_color)

	var player_pos: Vector3 = player.global_transform.origin
	var player_yaw: float = _get_player_yaw(player)
	for name in shot_pings.keys():
		var target: Node3D = _get_entity_by_name(name)
		if target == null:
			continue
		var offset: Vector3 = target.global_transform.origin - player_pos
		offset.y = 0.0
		var point := Vector2(offset.x, offset.z)
		if rotate_with_player:
			point = _rotate_2d(point, -player_yaw)
		var scale: float = radius / max(world_radius, 0.01)
		point *= scale
		var max_len: float = radius - edge_padding
		if point.length() > max_len:
			point = point.normalized() * max_len
		canvas.draw_circle(center + point, other_dot_radius, other_color)

func _get_entity_by_name(name: String) -> Node3D:
	if players_root:
		var player_node := players_root.get_node_or_null(name) as Node3D
		if player_node:
			return player_node
	if bots_root:
		var bot_node := bots_root.get_node_or_null(name) as Node3D
		if bot_node:
			return bot_node
	return null

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

func _rotate_2d(point: Vector2, angle: float) -> Vector2:
	var cos_a: float = cos(angle)
	var sin_a: float = sin(angle)
	return Vector2(
		point.x * cos_a - point.y * sin_a,
		point.x * sin_a + point.y * cos_a
	)
