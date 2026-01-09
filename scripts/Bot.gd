extends CharacterBody3D

signal died(bot)

@export var move_speed := 3.5
@export var turn_speed := 4.0
@export var change_dir_min := 1.0
@export var change_dir_max := 3.0
@export var max_health := 100

@onready var mesh: MeshInstance3D = $Mesh

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var health: int = 0
var dead: bool = false
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var move_dir: Vector3 = Vector3.ZERO
var change_timer: float = 0.0
var target_transform: Transform3D = Transform3D.IDENTITY
var default_collision_layer: int = 0
var default_collision_mask: int = 0

func _ready() -> void:
	rng.randomize()
	health = max_health
	default_collision_layer = collision_layer
	default_collision_mask = collision_mask
	target_transform = global_transform

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

	change_timer -= delta
	if change_timer <= 0.0 or move_dir.length() < 0.1:
		_pick_new_direction()

	if get_slide_collision_count() > 0:
		_pick_new_direction()

	velocity.x = move_dir.x * move_speed
	velocity.z = move_dir.z * move_speed

	var target_yaw := atan2(-move_dir.x, -move_dir.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, turn_speed * delta)

func _pick_new_direction() -> void:
	var angle := rng.randf_range(-PI, PI)
	move_dir = Vector3(cos(angle), 0.0, sin(angle)).normalized()
	change_timer = rng.randf_range(change_dir_min, change_dir_max)

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
	mesh.visible = not value
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
	mesh.visible = true
	collision_layer = default_collision_layer
	collision_mask = default_collision_mask
	target_transform = spawn_transform
