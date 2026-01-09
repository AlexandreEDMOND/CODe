extends CharacterBody3D

signal died(bot)

const CHARACTER_SKIN_DIR := "res://models/characters/Models/GLB format"

@export var move_speed := 3.5
@export var turn_speed := 6.0
@export var roam_radius := 12.0
@export var retarget_min := 2.0
@export var retarget_max := 4.0
@export var reach_threshold := 1.25
@export var acceleration := 12.0
@export var max_health := 100
@export var character_skin_scale := 1.0

@onready var mesh: MeshInstance3D = $Mesh
@onready var body: Node3D = $Body

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var health: int = 0
var dead: bool = false
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var target_position: Vector3 = Vector3.ZERO
var retarget_timer: float = 0.0
var collision_timer: float = 0.0
var home_position: Vector3 = Vector3.ZERO
var target_transform: Transform3D = Transform3D.IDENTITY
var default_collision_layer: int = 0
var default_collision_mask: int = 0
var skin_seed: int = 0
var body_skin_loaded: bool = false
var spawn_index: int = 0

func _ready() -> void:
	rng.randomize()
	health = max_health
	default_collision_layer = collision_layer
	default_collision_mask = collision_mask
	target_transform = global_transform
	home_position = global_transform.origin
	_pick_new_target()
	if skin_seed == 0:
		skin_seed = _extract_bot_id()
	_apply_skin()
	if body_skin_loaded:
		mesh.visible = false

func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		_process_ai(delta)
		move_and_slide()
		rpc("sync_state", global_transform)
	else:
		global_transform = global_transform.interpolate_with(
			target_transform,
			min(1.0, delta * 12.0)
		)

func _process_ai(delta: float) -> void:
	if dead:
		velocity = Vector3.ZERO
		return

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	retarget_timer -= delta
	collision_timer = max(0.0, collision_timer - delta)
	var to_target: Vector3 = target_position - global_transform.origin
	to_target.y = 0.0
	if retarget_timer <= 0.0 or to_target.length() <= reach_threshold:
		_pick_new_target()

	if get_slide_collision_count() > 0 and collision_timer <= 0.0:
		_pick_new_target()
		collision_timer = 0.5

	var move_dir: Vector3 = target_position - global_transform.origin
	move_dir.y = 0.0
	if move_dir.length() > 0.05:
		move_dir = move_dir.normalized()
		var desired_vel: Vector3 = move_dir * move_speed
		velocity.x = move_toward(velocity.x, desired_vel.x, acceleration * delta)
		velocity.z = move_toward(velocity.z, desired_vel.z, acceleration * delta)

		var target_yaw := atan2(-move_dir.x, -move_dir.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, turn_speed * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)

func _pick_new_target() -> void:
	var angle := rng.randf_range(-PI, PI)
	var radius := sqrt(rng.randf()) * roam_radius
	var offset := Vector3(cos(angle), 0.0, sin(angle)) * radius
	target_position = home_position + offset
	retarget_timer = rng.randf_range(retarget_min, retarget_max)

@rpc("unreliable")
func sync_state(state_transform: Transform3D) -> void:
	if multiplayer.is_server():
		return
	target_transform = state_transform

func apply_damage(amount: float, _from_peer_id: int = 0) -> void:
	if not multiplayer.is_server():
		return
	if dead:
		return

	health = max(health - int(round(amount)), 0)
	if health <= 0:
		dead = true
		rpc("set_dead", true)
		emit_signal("died", self)

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
	target_transform = spawn_transform
	home_position = global_transform.origin
	_pick_new_target()

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
