extends CharacterBody3D

signal died(bot, killer_id)

const CHARACTER_SKIN_DIR := "res://models/characters/Models/GLB format"
const LAYER_HITBOX := 8

@export var max_health := 100
@export var character_skin_scale := 1.0
@export var head_height_ratio := 0.22
@export var head_width_ratio := 0.35
@export var torso_width_ratio := 0.5
@export var torso_depth_ratio := 0.85
@export var leg_height_ratio := 0.45
@export var debug_hitboxes := true
@export var movement_enabled := true
@export var move_speed := 2.0
@export var move_segment_time := 1.2
@export var jump_enabled := true
@export var jump_interval := 3.0
@export var jump_velocity := 4.5
@export var network_send_rate := 12.0

@onready var mesh: MeshInstance3D = $Mesh
@onready var body: Node3D = $Body
@onready var body_collision: CollisionShape3D = $CollisionShape3D
@onready var head_hitbox: Area3D = $HeadHitbox
@onready var head_collision: CollisionShape3D = $HeadHitbox/CollisionShape3D
@onready var torso_hitbox: Area3D = $TorsoHitbox
@onready var torso_collision: CollisionShape3D = $TorsoHitbox/CollisionShape3D
@onready var arm_left_hitbox: Area3D = $ArmLeftHitbox
@onready var arm_left_collision: CollisionShape3D = $ArmLeftHitbox/CollisionShape3D
@onready var arm_right_hitbox: Area3D = $ArmRightHitbox
@onready var arm_right_collision: CollisionShape3D = $ArmRightHitbox/CollisionShape3D
@onready var leg_hitbox: Area3D = $LegHitbox
@onready var leg_collision: CollisionShape3D = $LegHitbox/CollisionShape3D

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var health: int = 0
var dead: bool = false
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var default_collision_layer: int = 0
var default_collision_mask: int = 0
var skin_seed: int = 0
var body_skin_loaded: bool = false
var spawn_index: int = 0
var last_damage_from: int = 0
var move_timer: float = 0.0
var jump_timer: float = 0.0
var send_timer: float = 0.0
var remote_target_transform: Transform3D = Transform3D.IDENTITY

func _ready() -> void:
	rng.randomize()
	health = max_health
	default_collision_layer = collision_layer
	default_collision_mask = collision_mask
	if skin_seed == 0:
		skin_seed = _extract_bot_id()
	_apply_skin()
	if body_skin_loaded:
		mesh.visible = false
	remote_target_transform = global_transform
	if jump_enabled:
		jump_timer = max(0.2, jump_interval * 0.5)

func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		_process_movement(delta)
		_send_state(delta)
	else:
		_process_remote(delta)

func _process_movement(delta: float) -> void:
	if dead:
		velocity = Vector3.ZERO
		return

	move_timer += delta
	var segment_time: float = max(0.2, move_segment_time)
	var phase: int = int(floor(move_timer / segment_time)) % 4
	var direction := Vector3.ZERO
	match phase:
		0:
			direction = Vector3(-1.0, 0.0, 0.0) # gauche
		1:
			direction = Vector3(0.0, 0.0, -1.0) # devant
		2:
			direction = Vector3(1.0, 0.0, 0.0) # droite
		_:
			direction = Vector3(0.0, 0.0, 1.0) # recule

	if movement_enabled:
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed * 4.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, move_speed * 4.0 * delta)

	if not is_on_floor():
		velocity.y -= gravity * delta
	elif jump_enabled and jump_interval > 0.0:
		jump_timer -= delta
		if jump_timer <= 0.0:
			velocity.y = jump_velocity
			jump_timer = jump_interval

	move_and_slide()

func _process_remote(delta: float) -> void:
	global_transform = global_transform.interpolate_with(
		remote_target_transform,
		min(1.0, delta * 12.0)
	)

func _send_state(delta: float) -> void:
	send_timer -= delta
	if send_timer > 0.0:
		return
	send_timer = 1.0 / max(1.0, network_send_rate)
	rpc("client_receive_state", global_transform)

@rpc("authority", "unreliable")
func client_receive_state(state_transform: Transform3D) -> void:
	if multiplayer.is_server():
		return
	remote_target_transform = state_transform

func apply_damage(amount: float, _from_peer_id: int = 0) -> void:
	if not multiplayer.is_server():
		return
	if dead:
		return

	last_damage_from = _from_peer_id
	health = max(health - int(round(amount)), 0)
	if health <= 0:
		dead = true
		rpc("set_dead", true)
		emit_signal("died", self, last_damage_from)

@rpc("any_peer", "reliable", "call_local")
func set_dead(value: bool) -> void:
	dead = value
	mesh.visible = (not value) and (not body_skin_loaded)
	if body:
		body.visible = not value
	collision_layer = 0 if value else default_collision_layer
	collision_mask = 0 if value else default_collision_mask
	if value:
		velocity = Vector3.ZERO

@rpc("any_peer", "reliable", "call_local")
func respawn_at(spawn_transform: Transform3D, new_health: int) -> void:
	global_transform = spawn_transform
	velocity = Vector3.ZERO
	dead = false
	health = new_health
	mesh.visible = not body_skin_loaded
	if body:
		body.visible = true
	collision_layer = default_collision_layer
	collision_mask = default_collision_mask
	remote_target_transform = spawn_transform

func _apply_skin() -> void:
	if body == null:
		return
	var skin_path: String = _pick_skin_path(CHARACTER_SKIN_DIR, "character-", skin_seed)
	var skin_node: Node3D = _instantiate_skin(skin_path)
	if skin_node == null:
		return
	body.add_child(skin_node)
	skin_node.scale = Vector3.ONE * character_skin_scale
	body_skin_loaded = true
	_update_hitboxes_to_skin(skin_node)

func _extract_bot_id() -> int:
	if name.begins_with("Bot_"):
		return int(name.replace("Bot_", ""))
	return int(rng.randi())

func _pick_skin_path(dir_path: String, prefix: String, seed: int) -> String:
	var files: Array[String] = _list_glb_files(dir_path, prefix)
	if files.is_empty():
		return ""
	var index: int = int(abs(seed)) % files.size()
	return files[index]

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

func _instantiate_skin(path: String) -> Node3D:
	if path == "":
		return null
	var ext: String = path.get_extension().to_lower()
	if ext == "glb" or ext == "gltf":
		return _load_gltf_scene(path)
	var res := load(path)
	if res is PackedScene:
		var node := (res as PackedScene).instantiate()
		if node is Node3D:
			return node
		return null
	if res is Mesh:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = res as Mesh
		return mesh_instance
	return null

func _load_gltf_scene(path: String) -> Node3D:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file(path, state)
	if err != OK:
		return null
	var scene := doc.generate_scene(state)
	if scene is Node3D:
		return scene
	return null

func _update_hitboxes_to_skin(skin_root: Node3D) -> void:
	if body_collision == null or head_hitbox == null or head_collision == null:
		return
	var entries: Array[Dictionary] = _collect_mesh_entries(skin_root)
	if entries.size() >= 4:
		var remaining: Array[Dictionary] = entries.duplicate()
		var head_entry: Dictionary = _pick_head_entry(remaining)
		remaining.erase(head_entry)

		var leg_entry: Dictionary = {}
		if entries.size() >= 5 and remaining.size() > 0:
			leg_entry = _pick_legs_entry(remaining)
			if not leg_entry.is_empty():
				remaining.erase(leg_entry)

		var arm_left_entry: Dictionary = _pick_arm_entry(remaining, true)
		if not arm_left_entry.is_empty():
			remaining.erase(arm_left_entry)
		var arm_right_entry: Dictionary = _pick_arm_entry(remaining, false)
		if not arm_right_entry.is_empty():
			remaining.erase(arm_right_entry)
		var torso_entry: Dictionary = _pick_torso_entry(remaining)

		var torso_aabb := AABB()
		var leg_aabb := AABB()
		if not torso_entry.is_empty():
			torso_aabb = torso_entry["aabb"]
		if not leg_entry.is_empty():
			leg_aabb = leg_entry["aabb"]
		elif not torso_entry.is_empty():
			var split: Dictionary = _split_torso_for_legs(torso_aabb)
			torso_aabb = split["torso"]
			leg_aabb = split["legs"]
		if leg_aabb.size.length() > 0.001 and torso_aabb.size.length() > 0.001:
			leg_aabb = _match_leg_width_to_torso(leg_aabb, torso_aabb)

		_set_hitbox_from_aabb(head_hitbox, head_collision, head_entry["aabb"])
		if not torso_entry.is_empty():
			_set_hitbox_from_aabb(torso_hitbox, torso_collision, torso_aabb)
		if not arm_left_entry.is_empty():
			_set_hitbox_from_aabb(arm_left_hitbox, arm_left_collision, arm_left_entry["aabb"])
		if not arm_right_entry.is_empty():
			_set_hitbox_from_aabb(arm_right_hitbox, arm_right_collision, arm_right_entry["aabb"])
		if leg_aabb.size.length() > 0.001:
			_set_hitbox_from_aabb(leg_hitbox, leg_collision, leg_aabb)

		_update_hitbox_debug(head_hitbox, head_entry["aabb"].size, Color(1, 0.1, 0.1, 0.5))
		if not torso_entry.is_empty():
			_update_hitbox_debug(torso_hitbox, torso_aabb.size, Color(0.1, 1, 0.1, 0.35))
		if not arm_left_entry.is_empty():
			_update_hitbox_debug(arm_left_hitbox, arm_left_entry["aabb"].size, Color(1, 0.9, 0.1, 0.35))
		if not arm_right_entry.is_empty():
			_update_hitbox_debug(arm_right_hitbox, arm_right_entry["aabb"].size, Color(1, 0.9, 0.1, 0.35))
		if leg_aabb.size.length() > 0.001:
			_update_hitbox_debug(leg_hitbox, leg_aabb.size, Color(0.1, 0.6, 1, 0.35))
		return

	var aabb: AABB = _compute_skin_aabb(skin_root)
	if aabb.size.length() <= 0.01:
		return
	var center: Vector3 = aabb.position + aabb.size * 0.5

	var head_height: float = max(0.2, aabb.size.y * head_height_ratio)
	var head_width: float = max(0.2, min(aabb.size.x, aabb.size.z) * head_width_ratio)
	var head_size := Vector3(head_width, head_height, head_width)
	var head_center := Vector3(
		center.x,
		aabb.position.y + aabb.size.y - (head_height * 0.5),
		center.z
	)
	var head_shape := BoxShape3D.new()
	head_shape.size = head_size
	head_collision.shape = head_shape
	head_hitbox.position = head_center

	var body_height: float = max(0.2, aabb.size.y - head_height)
	var torso_width: float = max(0.2, aabb.size.x * torso_width_ratio)
	var torso_depth: float = max(0.2, aabb.size.z * torso_depth_ratio)
	var leg_height: float = max(0.2, body_height * leg_height_ratio)
	leg_height = min(leg_height, body_height * 0.8)
	var torso_height: float = max(0.2, body_height - leg_height)
	var torso_center := Vector3(
		center.x,
		aabb.position.y + leg_height + torso_height * 0.5,
		center.z
	)
	var torso_shape := BoxShape3D.new()
	torso_shape.size = Vector3(torso_width, torso_height, torso_depth)
	torso_collision.shape = torso_shape
	torso_hitbox.position = torso_center

	var leg_center := Vector3(
		center.x,
		aabb.position.y + leg_height * 0.5,
		center.z
	)
	var leg_shape := BoxShape3D.new()
	leg_shape.size = Vector3(torso_width, leg_height, torso_depth)
	leg_collision.shape = leg_shape
	leg_hitbox.position = leg_center

	var arm_width: float = max(0.15, (aabb.size.x - torso_width) * 0.5)
	var arm_size := Vector3(arm_width, torso_height, torso_depth)
	var arm_offset_x: float = (torso_width * 0.5) + (arm_width * 0.5)
	var arm_left_center := Vector3(center.x - arm_offset_x, torso_center.y, center.z)
	var arm_right_center := Vector3(center.x + arm_offset_x, torso_center.y, center.z)
	var arm_shape := BoxShape3D.new()
	arm_shape.size = arm_size
	arm_left_collision.shape = arm_shape
	arm_right_collision.shape = arm_shape
	arm_left_hitbox.position = arm_left_center
	arm_right_hitbox.position = arm_right_center

	_update_hitbox_debug(head_hitbox, head_size, Color(1, 0.1, 0.1, 0.5))
	_update_hitbox_debug(torso_hitbox, torso_shape.size, Color(0.1, 1, 0.1, 0.35))
	_update_hitbox_debug(arm_left_hitbox, arm_size, Color(1, 0.9, 0.1, 0.35))
	_update_hitbox_debug(arm_right_hitbox, arm_size, Color(1, 0.9, 0.1, 0.35))
	_update_hitbox_debug(leg_hitbox, leg_shape.size, Color(0.1, 0.6, 1, 0.35))

func _compute_skin_aabb(skin_root: Node3D) -> AABB:
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(skin_root, meshes)
	if meshes.is_empty():
		return AABB()
	var body_inverse: Transform3D = global_transform.affine_inverse()
	var combined: AABB = AABB()
	var has_aabb: bool = false
	for mesh in meshes:
		var local_aabb: AABB = mesh.get_aabb()
		var to_body: Transform3D = body_inverse * mesh.global_transform
		var transformed: AABB = _transform_aabb(local_aabb, to_body)
		if not has_aabb:
			combined = transformed
			has_aabb = true
		else:
			combined = combined.merge(transformed)
	return combined

func _collect_mesh_entries(skin_root: Node3D) -> Array[Dictionary]:
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(skin_root, meshes)
	var entries: Array[Dictionary] = []
	if meshes.is_empty():
		return entries
	var body_inverse: Transform3D = body.global_transform.affine_inverse()
	for mesh in meshes:
		var local_aabb: AABB = mesh.get_aabb()
		var to_body: Transform3D = body_inverse * mesh.global_transform
		var transformed: AABB = _transform_aabb(local_aabb, to_body)
		var center: Vector3 = transformed.position + transformed.size * 0.5
		var volume: float = transformed.size.x * transformed.size.y * transformed.size.z
		entries.append({"aabb": transformed, "center": center, "volume": volume})
	return entries

func _pick_head_entry(entries: Array[Dictionary]) -> Dictionary:
	var best: Dictionary = entries[0]
	for entry in entries:
		if entry["center"].y > best["center"].y:
			best = entry
	return best

func _pick_arm_entry(entries: Array[Dictionary], left: bool) -> Dictionary:
	if entries.is_empty():
		return {}
	var best: Dictionary = entries[0]
	for entry in entries:
		if left:
			if entry["center"].x < best["center"].x:
				best = entry
		else:
			if entry["center"].x > best["center"].x:
				best = entry
	return best

func _pick_torso_entry(entries: Array[Dictionary]) -> Dictionary:
	if entries.is_empty():
		return {}
	var best: Dictionary = entries[0]
	for entry in entries:
		if entry["volume"] > best["volume"]:
			best = entry
	return best

func _pick_legs_entry(entries: Array[Dictionary]) -> Dictionary:
	if entries.is_empty():
		return {}
	var best: Dictionary = entries[0]
	for entry in entries:
		if entry["center"].y < best["center"].y:
			best = entry
	return best

func _set_hitbox_from_aabb(area: Area3D, shape_node: CollisionShape3D, aabb: AABB) -> void:
	if area == null or shape_node == null:
		return
	var box := BoxShape3D.new()
	box.size = aabb.size
	shape_node.shape = box
	var body_offset: Vector3 = body.position if body else Vector3.ZERO
	area.position = aabb.position + aabb.size * 0.5 + body_offset

func _collect_meshes(node: Node, out_meshes: Array[MeshInstance3D]) -> void:
	for child in node.get_children():
		var child_node: Node = child
		if child_node is MeshInstance3D:
			out_meshes.append(child_node as MeshInstance3D)
		if child_node.get_child_count() > 0:
			_collect_meshes(child_node, out_meshes)

func _transform_aabb(aabb: AABB, xform: Transform3D) -> AABB:
	var points: Array[Vector3] = [
		aabb.position,
		aabb.position + Vector3(aabb.size.x, 0.0, 0.0),
		aabb.position + Vector3(0.0, aabb.size.y, 0.0),
		aabb.position + Vector3(0.0, 0.0, aabb.size.z),
		aabb.position + Vector3(aabb.size.x, aabb.size.y, 0.0),
		aabb.position + Vector3(aabb.size.x, 0.0, aabb.size.z),
		aabb.position + Vector3(0.0, aabb.size.y, aabb.size.z),
		aabb.position + aabb.size
	]
	var min_v: Vector3 = xform * points[0]
	var max_v: Vector3 = min_v
	for i in range(1, points.size()):
		var p: Vector3 = xform * points[i]
		min_v = Vector3(min(min_v.x, p.x), min(min_v.y, p.y), min(min_v.z, p.z))
		max_v = Vector3(max(max_v.x, p.x), max(max_v.y, p.y), max(max_v.z, p.z))
	return AABB(min_v, max_v - min_v)

func _split_torso_for_legs(aabb: AABB) -> Dictionary:
	var leg_height: float = max(0.2, aabb.size.y * leg_height_ratio)
	leg_height = min(leg_height, aabb.size.y * 0.8)
	var torso_height: float = max(0.2, aabb.size.y - leg_height)
	var legs_aabb := AABB(aabb.position, Vector3(aabb.size.x, leg_height, aabb.size.z))
	var torso_aabb := AABB(aabb.position + Vector3(0.0, leg_height, 0.0), Vector3(aabb.size.x, torso_height, aabb.size.z))
	return {"torso": torso_aabb, "legs": legs_aabb}

func _match_leg_width_to_torso(leg_aabb: AABB, torso_aabb: AABB) -> AABB:
	var leg_size := leg_aabb.size
	leg_size.x = torso_aabb.size.x
	var torso_center_x: float = torso_aabb.position.x + torso_aabb.size.x * 0.5
	var leg_pos := leg_aabb.position
	leg_pos.x = torso_center_x - leg_size.x * 0.5
	return AABB(leg_pos, leg_size)

func _update_hitbox_debug(hitbox: Area3D, size: Vector3, color: Color) -> void:
	if not debug_hitboxes or hitbox == null:
		return
	var mesh_instance: MeshInstance3D = hitbox.get_node_or_null("DebugMesh") as MeshInstance3D
	if mesh_instance == null:
		mesh_instance = MeshInstance3D.new()
		mesh_instance.name = "DebugMesh"
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mesh_instance.material_override = material
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		hitbox.add_child(mesh_instance)
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
