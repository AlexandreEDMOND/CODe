extends CharacterBody3D

signal died(player)

const LAYER_WORLD := 1
const LAYER_PLAYERS := 2
const LAYER_BOTS := 4
const HIT_MASK := LAYER_WORLD | LAYER_PLAYERS | LAYER_BOTS
const CHARACTER_SKIN_DIR := "res://models/characters/Models/GLB format"
const WEAPON_SKIN_DIR := "res://models/weapons/Models/GLB format"

@export var move_speed := 5.0
@export var sprint_speed := 7.5
@export var jump_velocity := 4.5
@export var mouse_sensitivity := 0.0025
@export var max_pitch := 1.4
@export var fire_rate := 10.0
@export var spread_degrees := 0.0
@export var recoil_kick_pitch := 2.2
@export var recoil_kick_yaw := 0.9
@export var recoil_return_speed := 10.0
@export var max_distance := 200.0
@export var base_damage := 25.0
@export var min_damage := 12.0
@export var falloff_start := 20.0
@export var falloff_end := 80.0
@export var max_health := 100
@export var tracer_time := 0.08
@export var tracer_width := 0.04
@export var tracer_color := Color(1.0, 0.9, 0.6, 0.8)
@export var tracer_muzzle_offset := 0.1
@export var show_tracers := true
@export var show_own_body := false
@export var character_skin_scale := 1.0
@export var weapon_skin_scale := 1.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var mesh: MeshInstance3D = $Mesh
@onready var body: Node3D = $Body

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var look_yaw: float = 0.0
var look_pitch: float = 0.0
var recoil_pitch: float = 0.0
var recoil_yaw: float = 0.0
var fire_cooldown: float = 0.0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var dead: bool = false
var health: int = 0
var remote_target_transform: Transform3D = Transform3D.IDENTITY
var remote_target_pitch: float = 0.0
var default_collision_layer: int = 0
var default_collision_mask: int = 0
var weapon: Node3D = null
var muzzle: Node3D = null
var hit_marker: Label = null
var hit_marker_token: int = 0
var spawn_index: int = 0
var character_skin_seed: int = 0
var weapon_skin_seed: int = 0
var body_skin_loaded: bool = false
var weapon_skin_loaded: bool = false

func _ready() -> void:
	rng.randomize()
	health = max_health
	default_collision_layer = collision_layer
	default_collision_mask = collision_mask
	remote_target_transform = global_transform
	remote_target_pitch = head.rotation.x
	weapon = get_node_or_null("Head/Camera3D/Weapon") as Node3D
	muzzle = get_node_or_null("Head/Camera3D/Weapon/Muzzle") as Node3D
	hit_marker = get_node_or_null("/root/Main/HUD/HitMarker") as Label
	if character_skin_seed == 0:
		character_skin_seed = get_multiplayer_authority()
	if weapon_skin_seed == 0:
		weapon_skin_seed = get_multiplayer_authority()
	_apply_skins()

	if is_multiplayer_authority():
		camera.current = true
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		_set_local_health(health)
		mesh.visible = false
		if weapon:
			weapon.visible = true
		if hit_marker:
			hit_marker.visible = false
	else:
		camera.current = false
		if weapon:
			weapon.visible = false
	if body:
		body.visible = (not is_multiplayer_authority()) or show_own_body
	if body_skin_loaded:
		mesh.visible = false

func _input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return

	if event is InputEventMouseMotion:
		look_yaw -= event.relative.x * mouse_sensitivity
		look_pitch -= event.relative.y * mouse_sensitivity
		look_pitch = clamp(look_pitch, -max_pitch, max_pitch)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta: float) -> void:
	if is_multiplayer_authority():
		_process_local(delta)
	else:
		_process_remote(delta)

func _process_local(delta: float) -> void:
	_update_recoil(delta)
	_apply_look()
	_handle_fire(delta)

	if dead:
		velocity = Vector3.ZERO
		return

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		if Input.is_action_just_pressed("jump"):
			velocity.y = jump_velocity

	var input_dir := Vector3(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		0.0,
		Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
	)

	if input_dir.length() > 0.01:
		input_dir = input_dir.normalized()
		var speed := sprint_speed if Input.is_action_pressed("sprint") else move_speed
		var basis := global_transform.basis
		var direction := (basis * input_dir).normalized()
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed * 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, move_speed * 10.0 * delta)

	move_and_slide()
	_send_state()

func _process_remote(delta: float) -> void:
	global_transform = global_transform.interpolate_with(
		remote_target_transform,
		min(1.0, delta * 12.0)
	)
	head.rotation.x = lerp(head.rotation.x, remote_target_pitch, delta * 12.0)

func _apply_look() -> void:
	rotation.y = look_yaw + recoil_yaw
	head.rotation.x = clamp(look_pitch + recoil_pitch, -max_pitch, max_pitch)

func _update_recoil(delta: float) -> void:
	recoil_pitch = move_toward(recoil_pitch, 0.0, recoil_return_speed * delta)
	recoil_yaw = move_toward(recoil_yaw, 0.0, recoil_return_speed * delta)

func _handle_fire(delta: float) -> void:
	fire_cooldown = max(0.0, fire_cooldown - delta)
	if dead:
		return
	if not Input.is_action_pressed("fire"):
		return
	if fire_cooldown > 0.0:
		return

	fire_cooldown = 1.0 / fire_rate
	_apply_recoil_kick()

	var camera_origin: Vector3 = camera.global_transform.origin
	var camera_dir: Vector3 = _get_spread_direction()
	var muzzle_origin: Vector3 = camera_origin
	if muzzle:
		muzzle_origin = muzzle.global_transform.origin

	var aim_point: Vector3 = camera_origin + camera_dir * max_distance
	var fire_dir: Vector3 = aim_point - muzzle_origin
	if fire_dir.length() <= 0.001:
		fire_dir = camera_dir
	else:
		fire_dir = fire_dir.normalized()

	if multiplayer.is_server():
		var end_pos: Vector3 = _do_fire(muzzle_origin, fire_dir, multiplayer.get_unique_id())
		_spawn_tracer_local(muzzle_origin, end_pos)
		_broadcast_tracer(muzzle_origin, end_pos, multiplayer.get_unique_id())
	else:
		var end_pos: Vector3 = _predict_tracer_end(muzzle_origin, fire_dir)
		_spawn_tracer_local(muzzle_origin, end_pos)
		rpc_id(1, "server_fire", muzzle_origin, fire_dir)

func _apply_recoil_kick() -> void:
	var pitch_kick: float = recoil_kick_pitch * rng.randf_range(0.85, 1.15)
	var yaw_kick: float = recoil_kick_yaw * rng.randf_range(-1.0, 1.0)
	recoil_pitch += deg_to_rad(pitch_kick)
	recoil_yaw += deg_to_rad(yaw_kick)

func _get_spread_direction() -> Vector3:
	if spread_degrees <= 0.0:
		return -camera.global_transform.basis.z
	var spread_rad: float = deg_to_rad(spread_degrees)
	var spread_x: float = rng.randfn(0.0, spread_rad)
	var spread_y: float = rng.randfn(0.0, spread_rad)
	var basis: Basis = camera.global_transform.basis
	var dir: Vector3 = -basis.z
	return (dir + basis.x * spread_x + basis.y * spread_y).normalized()

@rpc("any_peer", "reliable")
func server_fire(origin: Vector3, direction: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var shooter_id: int = multiplayer.get_remote_sender_id()
	var end_pos: Vector3 = _do_fire(origin, direction, shooter_id)
	_broadcast_tracer(origin, end_pos, shooter_id)

func _do_fire(origin: Vector3, direction: Vector3, shooter_id: int) -> Vector3:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		origin,
		origin + direction * max_distance
	)
	query.exclude = [self]
	query.collision_mask = HIT_MASK
	query.collide_with_areas = true
	query.collide_with_bodies = true

	var result: Dictionary = space.intersect_ray(query)
	var end_pos: Vector3 = origin + direction * max_distance
	if result.is_empty():
		return end_pos

	end_pos = result.position
	var collider: Object = result.get("collider")
	if collider == null:
		return end_pos

	var distance: float = origin.distance_to(result.position)
	var damage := _compute_damage(distance)
	if collider.has_method("apply_damage"):
		collider.apply_damage(damage, shooter_id)
		if shooter_id == multiplayer.get_unique_id():
			_show_hit_marker()
		elif shooter_id != 0:
			rpc_id(shooter_id, "client_hit_confirm")
	return end_pos

func _compute_damage(distance: float) -> float:
	if distance <= falloff_start:
		return base_damage
	if distance >= falloff_end:
		return min_damage
	var t := (distance - falloff_start) / (falloff_end - falloff_start)
	return lerp(base_damage, min_damage, t)

func apply_damage(amount: float, _from_peer_id: int = 0) -> void:
	if not multiplayer.is_server():
		return
	if dead:
		return

	health = max(health - int(round(amount)), 0)
	_sync_health_to_owner()
	if health <= 0:
		dead = true
		rpc("set_dead", true)
		emit_signal("died", self)

func _sync_health_to_owner() -> void:
	var owner_id := get_multiplayer_authority()
	if owner_id == multiplayer.get_unique_id():
		_set_local_health(health)
	else:
		rpc_id(owner_id, "client_set_health", health)

@rpc("any_peer", "reliable")
func client_set_health(value: int) -> void:
	health = clamp(value, 0, max_health)
	if is_multiplayer_authority():
		_set_local_health(health)

@rpc("any_peer", "reliable", "call_local")
func client_hit_confirm() -> void:
	_show_hit_marker()

@rpc("any_peer", "reliable", "call_local")
func set_dead(value: bool) -> void:
	dead = value
	mesh.visible = (not value) and (not is_multiplayer_authority()) and (not body_skin_loaded)
	if body:
		body.visible = (not value) and (show_own_body or (not is_multiplayer_authority()))
	if weapon:
		weapon.visible = (not value) and is_multiplayer_authority()
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
	mesh.visible = (not is_multiplayer_authority()) and (not body_skin_loaded)
	if body:
		body.visible = show_own_body or (not is_multiplayer_authority())
	if weapon:
		weapon.visible = is_multiplayer_authority()
	collision_layer = default_collision_layer
	collision_mask = default_collision_mask
	remote_target_transform = spawn_transform
	remote_target_pitch = 0.0
	if is_multiplayer_authority():
		look_pitch = 0.0
		recoil_pitch = 0.0
		recoil_yaw = 0.0
		_set_local_health(health)

func _set_local_health(value: int) -> void:
	var label: Label = get_node_or_null("/root/Main/HUD/HealthLabel") as Label
	if label:
		label.text = "HP: %d" % value

func _apply_skins() -> void:
	_apply_character_skin()
	_apply_weapon_skin()

func _apply_character_skin() -> void:
	if body == null:
		return
	var skin_path: String = _pick_skin_path(CHARACTER_SKIN_DIR, "character-", character_skin_seed)
	var skin_node: Node3D = _instantiate_skin(skin_path)
	if skin_node == null:
		return
	body.add_child(skin_node)
	skin_node.scale = Vector3.ONE * character_skin_scale
	body_skin_loaded = true

func _apply_weapon_skin() -> void:
	if weapon == null:
		return
	var skin_path: String = _pick_skin_path(WEAPON_SKIN_DIR, "blaster-", weapon_skin_seed)
	var skin_node: Node3D = _instantiate_skin(skin_path)
	if skin_node == null:
		return
	if weapon is MeshInstance3D:
		var weapon_mesh := weapon as MeshInstance3D
		weapon_mesh.mesh = null
	weapon.add_child(skin_node)
	skin_node.scale = Vector3.ONE * weapon_skin_scale
	weapon_skin_loaded = true

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

func _show_hit_marker() -> void:
	if hit_marker == null:
		return
	hit_marker.visible = true
	hit_marker_token += 1
	var token: int = hit_marker_token
	await get_tree().create_timer(0.08).timeout
	if hit_marker == null:
		return
	if hit_marker_token == token:
		hit_marker.visible = false

func _predict_tracer_end(origin: Vector3, direction: Vector3) -> Vector3:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		origin,
		origin + direction * max_distance
	)
	query.exclude = [self]
	query.collision_mask = HIT_MASK
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var result: Dictionary = space.intersect_ray(query)
	if result.is_empty():
		return origin + direction * max_distance
	return result.position

func _spawn_tracer_local(start_pos: Vector3, end_pos: Vector3) -> void:
	if not show_tracers:
		return
	var tracer_start: Vector3 = _get_tracer_start(start_pos, end_pos)
	_spawn_tracer(tracer_start, end_pos)

@rpc("any_peer", "unreliable", "call_local")
func client_spawn_tracer(start_pos: Vector3, end_pos: Vector3) -> void:
	if not show_tracers:
		return
	var tracer_start: Vector3 = _get_tracer_start(start_pos, end_pos)
	_spawn_tracer(tracer_start, end_pos)

func _broadcast_tracer(origin: Vector3, end_pos: Vector3, shooter_id: int) -> void:
	if not multiplayer.is_server():
		return
	var start_pos: Vector3 = origin
	for peer_id: int in multiplayer.get_peers():
		if peer_id == shooter_id:
			continue
		rpc_id(peer_id, "client_spawn_tracer", start_pos, end_pos)

func _get_tracer_start(start_pos: Vector3, end_pos: Vector3) -> Vector3:
	var dir: Vector3 = end_pos - start_pos
	var length: float = dir.length()
	if length <= 0.001:
		return start_pos
	return start_pos + dir.normalized() * tracer_muzzle_offset

func _spawn_tracer(start_pos: Vector3, end_pos: Vector3) -> void:
	var root: Node = get_tree().current_scene
	if root == null:
		return
	var dir: Vector3 = end_pos - start_pos
	var length: float = dir.length()
	if length <= 0.01:
		return
	var mid: Vector3 = start_pos + dir * 0.5
	var up: Vector3 = Vector3.UP
	var dir_norm: Vector3 = dir.normalized()
	if abs(dir_norm.dot(up)) > 0.98:
		up = Vector3.FORWARD

	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(tracer_width, tracer_width, length)

	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = tracer_color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission = tracer_color
	material.emission_energy_multiplier = 1.3

	var inst: MeshInstance3D = MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = material
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inst.global_transform = Transform3D(Basis().looking_at(dir_norm, up), mid)

	root.add_child(inst)
	await get_tree().create_timer(tracer_time).timeout
	if is_instance_valid(inst):
		inst.queue_free()

func _send_state() -> void:
	var pitch: float = head.rotation.x
	if multiplayer.is_server():
		rpc("client_receive_state", global_transform, pitch)
	else:
		rpc_id(1, "server_receive_state", global_transform, pitch)

@rpc("any_peer", "unreliable")
func server_receive_state(state_transform: Transform3D, pitch: float) -> void:
	if not multiplayer.is_server():
		return
	global_transform = state_transform
	head.rotation.x = pitch
	rpc("client_receive_state", state_transform, pitch)

@rpc("unreliable")
func client_receive_state(state_transform: Transform3D, pitch: float) -> void:
	if is_multiplayer_authority():
		return
	remote_target_transform = state_transform
	remote_target_pitch = pitch
