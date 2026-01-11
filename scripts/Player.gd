extends CharacterBody3D

signal died(player, killer_id)

const LAYER_WORLD := 1
const LAYER_PLAYERS := 2
const LAYER_BOTS := 4
const LAYER_HITBOX := 8
const HIT_MASK := LAYER_WORLD | LAYER_HITBOX
const CHARACTER_SKIN_DIR := "res://models/characters/Models/GLB format"
const WEAPON_SKIN_DIR := "res://models/weapons/Models/GLB format"
const TRACER_SCENE := preload("res://scenes/Tracer.tscn")
const IMPACT_SCENE := preload("res://scenes/Impact.tscn")

@export var move_speed := 5.0
@export var sprint_speed := 7.5
@export var jump_velocity := 4.5
@export var mouse_sensitivity := 0.0025
@export var max_pitch := 1.4
@export var fire_rate := 10.0
@export var spread_degrees := 1.2
@export var ads_spread_multiplier := 0.0
@export var recoil_kick_pitch := 2.2
@export var recoil_kick_yaw := 0.9
@export var recoil_return_speed := 10.0
@export var recoil_camera_scale := 0.25
@export var recoil_kick_scale := 0.6
@export var max_distance := 200.0
@export var base_damage := 25.0
@export var min_damage := 12.0
@export var falloff_start := 20.0
@export var falloff_end := 80.0
@export var max_health := 100
@export var tracer_time := 0.08
@export var tracer_speed := 140.0
@export var tracer_width := 0.04
@export var tracer_segment_length := 2.0
@export var tracer_every_n := 1
@export var tracer_color := Color(1.0, 0.9, 0.6, 0.8)
@export var tracer_muzzle_offset := 0.1
@export var show_tracers := true
@export var impact_size := 0.18
@export var impact_lifetime := 0.8
@export var impact_fade_time := 0.25
@export var impact_color := Color(0.08, 0.08, 0.08, 0.8)
@export var impact_offset := 0.02
@export var show_impacts := true
@export var headbob_enabled := true
@export var headbob_frequency := 8.5
@export var headbob_vertical := 0.065
@export var headbob_horizontal := 0.045
@export var headbob_smooth := 12.0
@export var sprint_headbob_multiplier := 1.35
@export var sprint_fov_boost := 8.0
@export var sprint_fov_smooth := 8.0
@export var weapon_bob_enabled := true
@export var weapon_bob_pos_scale := Vector3(0.6, 0.5, 0.0)
@export var weapon_bob_rot_scale := Vector3(1.6, 1.0, 1.2)
@export var weapon_bob_smooth := 10.0
@export var weapon_kick_pos := Vector3(0.0, 0.0, 0.08)
@export var weapon_kick_rot := Vector3(2.0, 0.8, 0.0)
@export var weapon_kick_return := 14.0
@export var ads_fov := 55.0
@export var ads_fov_smooth := 12.0
@export var ads_weapon_pos := Vector3(0.02, -0.14, -0.25)
@export var ads_weapon_rot := Vector3(0.0, 0.0, 0.0)
@export var ads_weapon_smooth := 12.0
@export var ads_move_multiplier := 0.6
@export var damage_overlay_fade := 1.0
@export var damage_arrow_fade := 0.5
@export var low_health_start_ratio := 0.4
@export var low_health_max_intensity := 1.0
@export var show_own_body := false
@export var character_skin_scale := 1.0
@export var weapon_skin_scale := 1.0
@export var head_height_ratio := 0.22
@export var head_width_ratio := 0.35
@export var torso_width_ratio := 0.5
@export var torso_depth_ratio := 0.85
@export var leg_height_ratio := 0.45
@export var debug_hitboxes := false

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
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
@onready var low_health_overlay: ColorRect = get_node_or_null("/root/Main/HUD/LowHealthOverlay") as ColorRect
@onready var damage_arrow_pivot: Control = get_node_or_null("/root/Main/HUD/DamageArrowPivot") as Control
@onready var damage_arrow: ColorRect = get_node_or_null("/root/Main/HUD/DamageArrowPivot/DamageArrow") as ColorRect

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
var shots_fired_count: int = 0
var last_damage_from: int = 0
var last_hit_was_headshot: bool = false
var headbob_phase: float = 0.0
var headbob_offset: Vector3 = Vector3.ZERO
var camera_base_pos: Vector3 = Vector3.ZERO
var camera_base_fov: float = 0.0
var weapon_base_pos: Vector3 = Vector3.ZERO
var weapon_base_rot: Vector3 = Vector3.ZERO
var weapon_bob_pos: Vector3 = Vector3.ZERO
var weapon_bob_rot: Vector3 = Vector3.ZERO
var weapon_kick_pos_current: Vector3 = Vector3.ZERO
var weapon_kick_rot_current: Vector3 = Vector3.ZERO
var ads_blend: float = 0.0
var damage_overlay_intensity: float = 0.0
var damage_arrow_intensity: float = 0.0
var last_damage_source_pos: Vector3 = Vector3.ZERO
var low_health_intensity: float = 0.0

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
	if camera:
		camera_base_pos = camera.position
		camera_base_fov = camera.fov
	if weapon:
		weapon_base_pos = weapon.position
		weapon_base_rot = weapon.rotation

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
	_update_headbob(delta)
	_update_sprint_fov(delta)
	_update_ads(delta)
	_update_damage_feedback(delta)

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
		var aiming: bool = Input.is_action_pressed("aim")
		var speed := move_speed
		if not aiming and Input.is_action_pressed("sprint"):
			speed = sprint_speed
		if aiming:
			speed *= ads_move_multiplier
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

func _update_headbob(delta: float) -> void:
	if not headbob_enabled or camera == null:
		return
	var speed: float = Vector3(velocity.x, 0.0, velocity.z).length()
	var moving: bool = is_on_floor() and speed > 0.1
	if moving:
		var speed_ratio: float = clamp(speed / sprint_speed, 0.4, 1.2)
		var sprinting: bool = Input.is_action_pressed("sprint") and speed_ratio > 0.7
		var intensity: float = sprint_headbob_multiplier if sprinting else 1.0
		headbob_phase += delta * headbob_frequency * speed_ratio
		var vertical := sin(headbob_phase * 2.0) * headbob_vertical * intensity
		var horizontal := cos(headbob_phase) * headbob_horizontal * intensity
		var target := Vector3(horizontal, vertical, 0.0)
		headbob_offset = headbob_offset.lerp(target, min(1.0, delta * headbob_smooth))
		_update_weapon_bob(delta, intensity, true)
	else:
		headbob_offset = headbob_offset.lerp(Vector3.ZERO, min(1.0, delta * headbob_smooth))
		_update_weapon_bob(delta, 1.0, false)
	camera.position = camera_base_pos + headbob_offset

func _update_sprint_fov(delta: float) -> void:
	if camera == null:
		return
	if ads_blend > 0.0:
		return
	var speed: float = Vector3(velocity.x, 0.0, velocity.z).length()
	var sprinting: bool = is_on_floor() and speed > 0.1 and Input.is_action_pressed("sprint")
	var target_fov: float = camera_base_fov + (sprint_fov_boost if sprinting else 0.0)
	camera.fov = lerp(camera.fov, target_fov, min(1.0, delta * sprint_fov_smooth))

func _update_damage_feedback(delta: float) -> void:
	if not is_multiplayer_authority():
		return
	if damage_overlay_intensity > 0.0:
		damage_overlay_intensity = max(0.0, damage_overlay_intensity - damage_overlay_fade * delta)
		_apply_low_health_overlay()
	if damage_arrow_intensity > 0.0:
		damage_arrow_intensity = max(0.0, damage_arrow_intensity - damage_arrow_fade * delta)
		_set_damage_arrow_intensity(damage_arrow_intensity)
		_update_damage_arrow()
	else:
		if damage_arrow:
			damage_arrow.visible = false

func _update_weapon_bob(delta: float, intensity: float, moving: bool) -> void:
	if weapon == null:
		return
	weapon_kick_pos_current = weapon_kick_pos_current.lerp(Vector3.ZERO, min(1.0, delta * weapon_kick_return))
	weapon_kick_rot_current = weapon_kick_rot_current.lerp(Vector3.ZERO, min(1.0, delta * weapon_kick_return))
	if weapon_bob_enabled:
		if moving:
			var pos_target := Vector3(
				headbob_offset.x * weapon_bob_pos_scale.x,
				headbob_offset.y * weapon_bob_pos_scale.y,
				headbob_offset.z * weapon_bob_pos_scale.z
			)
			var rot_target := Vector3(
				deg_to_rad(weapon_bob_rot_scale.x) * sin(headbob_phase * 2.0) * intensity,
				deg_to_rad(weapon_bob_rot_scale.y) * cos(headbob_phase) * intensity,
				deg_to_rad(weapon_bob_rot_scale.z) * sin(headbob_phase) * intensity
			)
			weapon_bob_pos = weapon_bob_pos.lerp(pos_target, min(1.0, delta * weapon_bob_smooth))
			weapon_bob_rot = weapon_bob_rot.lerp(rot_target, min(1.0, delta * weapon_bob_smooth))
		else:
			weapon_bob_pos = weapon_bob_pos.lerp(Vector3.ZERO, min(1.0, delta * weapon_bob_smooth))
			weapon_bob_rot = weapon_bob_rot.lerp(Vector3.ZERO, min(1.0, delta * weapon_bob_smooth))
	else:
		weapon_bob_pos = weapon_bob_pos.lerp(Vector3.ZERO, min(1.0, delta * weapon_bob_smooth))
		weapon_bob_rot = weapon_bob_rot.lerp(Vector3.ZERO, min(1.0, delta * weapon_bob_smooth))
	var ads_pos := weapon_base_pos.lerp(ads_weapon_pos, ads_blend)
	var ads_rot := weapon_base_rot.lerp(ads_weapon_rot, ads_blend)
	weapon.position = ads_pos + weapon_bob_pos + weapon_kick_pos_current
	weapon.rotation = ads_rot + weapon_bob_rot + weapon_kick_rot_current

func _update_ads(delta: float) -> void:
	if not is_multiplayer_authority() or camera == null:
		return
	var aiming: bool = Input.is_action_pressed("aim")
	var target: float = 1.0 if aiming else 0.0
	ads_blend = move_toward(ads_blend, target, ads_weapon_smooth * delta)
	var base_fov: float = camera_base_fov + (sprint_fov_boost if Input.is_action_pressed("sprint") else 0.0)
	var target_fov: float = lerp(base_fov, ads_fov, ads_blend)
	camera.fov = lerp(camera.fov, target_fov, min(1.0, delta * ads_fov_smooth))

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

	var spawn_tracer: bool = _should_spawn_tracer()
	if multiplayer.is_server():
		var end_pos: Vector3 = _do_fire(camera_origin, camera_dir, multiplayer.get_unique_id())
		if spawn_tracer:
			_spawn_tracer_local(muzzle_origin, end_pos)
			_broadcast_tracer(muzzle_origin, end_pos, multiplayer.get_unique_id())
	else:
		var end_pos: Vector3 = _predict_tracer_end(camera_origin, camera_dir)
		if spawn_tracer:
			_spawn_tracer_local(muzzle_origin, end_pos)
		rpc_id(1, "server_fire", camera_origin, camera_dir, muzzle_origin)

func _apply_recoil_kick() -> void:
	var pitch_kick: float = recoil_kick_pitch * rng.randf_range(0.85, 1.15)
	var yaw_kick: float = recoil_kick_yaw * rng.randf_range(-1.0, 1.0)
	var pitch_rad: float = deg_to_rad(pitch_kick)
	var yaw_rad: float = deg_to_rad(yaw_kick)
	var camera_pitch: float = pitch_rad * recoil_camera_scale
	var camera_yaw: float = yaw_rad * recoil_camera_scale
	look_pitch = clamp(look_pitch + camera_pitch, -max_pitch, max_pitch)
	look_yaw += camera_yaw
	recoil_pitch += pitch_rad * recoil_kick_scale
	recoil_yaw += yaw_rad * recoil_kick_scale
	if weapon:
		weapon_kick_pos_current += weapon_kick_pos
		weapon_kick_rot_current += Vector3(
			deg_to_rad(weapon_kick_rot.x),
			deg_to_rad(weapon_kick_rot.y) * rng.randf_range(-1.0, 1.0),
			deg_to_rad(weapon_kick_rot.z)
		)

func _get_spread_direction() -> Vector3:
	var spread: float = spread_degrees
	if ads_blend > 0.0:
		spread = spread_degrees * ads_spread_multiplier
	if spread <= 0.0:
		return -camera.global_transform.basis.z
	var spread_rad: float = deg_to_rad(spread)
	var spread_x: float = rng.randfn(0.0, spread_rad)
	var spread_y: float = rng.randfn(0.0, spread_rad)
	var basis: Basis = camera.global_transform.basis
	var dir: Vector3 = -basis.z
	return (dir + basis.x * spread_x + basis.y * spread_y).normalized()

@rpc("any_peer", "reliable")
func server_fire(origin: Vector3, direction: Vector3, tracer_origin: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var shooter_id: int = multiplayer.get_remote_sender_id()
	var end_pos: Vector3 = _do_fire(origin, direction, shooter_id)
	if _should_spawn_tracer():
		_broadcast_tracer(tracer_origin, end_pos, shooter_id)

func _do_fire(origin: Vector3, direction: Vector3, shooter_id: int) -> Vector3:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		origin,
		origin + direction * max_distance
	)
	query.exclude = _build_query_exclude()
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

	var hit_normal: Vector3 = result["normal"]
	var distance: float = origin.distance_to(result.position)
	var damage := _compute_damage(distance)
	if collider.has_method("apply_damage"):
		var source_pos: Vector3 = global_transform.origin
		collider.apply_damage(damage, shooter_id, false, source_pos)
		if shooter_id == multiplayer.get_unique_id():
			_show_hit_marker()
		elif shooter_id != 0:
			rpc_id(shooter_id, "client_hit_confirm")
	else:
		_spawn_impact_local(result.position, hit_normal)
		_broadcast_impact(result.position, hit_normal, shooter_id)
	return end_pos

func _compute_damage(distance: float) -> float:
	if distance <= falloff_start:
		return base_damage
	if distance >= falloff_end:
		return min_damage
	var t := (distance - falloff_start) / (falloff_end - falloff_start)
	return lerp(base_damage, min_damage, t)

func apply_damage(amount: float, _from_peer_id: int = 0, headshot: bool = false, source_pos: Vector3 = Vector3.ZERO) -> void:
	if not multiplayer.is_server():
		return
	if dead:
		return

	last_damage_from = _from_peer_id
	last_hit_was_headshot = headshot
	health = max(health - int(round(amount)), 0)
	_sync_health_to_owner()
	_send_damage_indicator(source_pos)
	if health <= 0:
		dead = true
		rpc("set_dead", true)
		emit_signal("died", self, last_damage_from)

func _sync_health_to_owner() -> void:
	var owner_id := get_multiplayer_authority()
	if owner_id == multiplayer.get_unique_id():
		_set_local_health(health)
	else:
		rpc_id(owner_id, "client_set_health", health)

func _send_damage_indicator(source_pos: Vector3) -> void:
	var owner_id := get_multiplayer_authority()
	if owner_id == multiplayer.get_unique_id():
		_show_damage_indicator(source_pos)
	else:
		rpc_id(owner_id, "client_show_damage_indicator", source_pos)

@rpc("any_peer", "reliable", "call_local")
func client_show_damage_indicator(source_pos: Vector3) -> void:
	_show_damage_indicator(source_pos)

func _show_damage_indicator(source_pos: Vector3) -> void:
	if not is_multiplayer_authority():
		return
	last_damage_source_pos = source_pos
	damage_overlay_intensity = 1.0
	damage_arrow_intensity = 1.0
	_apply_low_health_overlay()
	_set_damage_arrow_intensity(damage_arrow_intensity)
	_update_damage_arrow()

func _update_damage_arrow() -> void:
	if damage_arrow_pivot == null or damage_arrow == null:
		return
	var to_source := last_damage_source_pos - global_transform.origin
	to_source.y = 0.0
	if to_source.length() <= 0.01:
		damage_arrow.visible = false
		return
	var forward := -global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := global_transform.basis.x
	right.y = 0.0
	right = right.normalized()
	var angle := atan2(to_source.dot(right), to_source.dot(forward))
	damage_arrow_pivot.rotation = angle
	damage_arrow.visible = true

func _set_damage_arrow_intensity(value: float) -> void:
	if damage_arrow:
		var mat_arrow := damage_arrow.material
		if mat_arrow is ShaderMaterial:
			(mat_arrow as ShaderMaterial).set_shader_parameter("intensity", value)

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
	last_hit_was_headshot = false
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
		damage_overlay_intensity = 0.0
		damage_arrow_intensity = 0.0
		_set_damage_arrow_intensity(0.0)
		_apply_low_health_overlay()

func _set_local_health(value: int) -> void:
	var label: Label = get_node_or_null("/root/Main/HUD/HealthLabel") as Label
	if label:
		label.text = "HP: %d" % value
	_update_low_health_overlay(value)

func _update_low_health_overlay(value: int) -> void:
	if low_health_overlay == null:
		return
	var ratio: float = 0.0
	if max_health > 0:
		ratio = float(value) / float(max_health)
	var intensity := 0.0
	if ratio < low_health_start_ratio:
		intensity = (low_health_start_ratio - ratio) / max(low_health_start_ratio, 0.01)
	low_health_intensity = clamp(intensity * low_health_max_intensity, 0.0, 1.0)
	_apply_low_health_overlay()

func _apply_low_health_overlay() -> void:
	if low_health_overlay == null:
		return
	var mat := low_health_overlay.material
	if mat is ShaderMaterial:
		(mat as ShaderMaterial).set_shader_parameter(
			"intensity",
			max(low_health_intensity, damage_overlay_intensity)
		)

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
	_update_hitboxes_to_skin(skin_node)

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

func _build_query_exclude() -> Array[RID]:
	var exclude: Array[RID] = []
	exclude.append(get_rid())
	if head_hitbox:
		exclude.append(head_hitbox.get_rid())
	if torso_hitbox:
		exclude.append(torso_hitbox.get_rid())
	if arm_left_hitbox:
		exclude.append(arm_left_hitbox.get_rid())
	if arm_right_hitbox:
		exclude.append(arm_right_hitbox.get_rid())
	if leg_hitbox:
		exclude.append(leg_hitbox.get_rid())
	return exclude

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

func _should_spawn_tracer() -> bool:
	if not show_tracers:
		return false
	shots_fired_count += 1
	if tracer_every_n <= 1:
		return true
	return (shots_fired_count % tracer_every_n) == 0

func _predict_tracer_end(origin: Vector3, direction: Vector3) -> Vector3:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		origin,
		origin + direction * max_distance
	)
	query.exclude = _build_query_exclude()
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
	var tracer := TRACER_SCENE.instantiate()
	tracer.start_pos = start_pos
	tracer.end_pos = end_pos
	tracer.speed = tracer_speed
	tracer.width = tracer_width
	tracer.color = tracer_color
	tracer.segment_length = tracer_segment_length
	tracer.max_time = tracer_time
	root.add_child(tracer)

func _spawn_impact_local(position: Vector3, normal: Vector3) -> void:
	if not show_impacts:
		return
	var root: Node = get_tree().current_scene
	if root == null:
		return
	var impact := IMPACT_SCENE.instantiate()
	var spawn_pos: Vector3 = position + normal * impact_offset
	var up_dir := Vector3.UP
	if abs(normal.dot(up_dir)) > 0.98:
		up_dir = Vector3.FORWARD
	impact.look_at_from_position(spawn_pos, position - normal, up_dir)
	impact.size = impact_size
	impact.lifetime = impact_lifetime
	impact.fade_time = impact_fade_time
	impact.color = impact_color
	root.add_child(impact)

@rpc("any_peer", "unreliable", "call_local")
func client_spawn_impact(position: Vector3, normal: Vector3) -> void:
	_spawn_impact_local(position, normal)

func _broadcast_impact(position: Vector3, normal: Vector3, shooter_id: int) -> void:
	if not multiplayer.is_server():
		return
	for peer_id: int in multiplayer.get_peers():
		rpc_id(peer_id, "client_spawn_impact", position, normal)

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
