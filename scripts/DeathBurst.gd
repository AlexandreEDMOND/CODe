extends Node3D
class_name DeathBurst

@export var cube_count := 14
@export var cube_size := 0.12
@export var speed_min := 3.0
@export var speed_max := 7.0
@export var upward_bias := 0.5
@export var gravity := 12.0
@export var lifetime := 1.1
@export var fade_time := 0.35
@export var base_color := Color(1.0, 0.8, 0.6, 1.0)

var _pieces: Array[MeshInstance3D] = []
var _velocities: Array[Vector3] = []
var _colors: Array[Color] = []
var _time: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	for i in range(cube_count):
		var mesh_instance: MeshInstance3D = MeshInstance3D.new()
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3.ONE * cube_size
		mesh_instance.mesh = box
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var tint: Color = base_color
		tint.r = clamp(tint.r + _rng.randf_range(-0.08, 0.08), 0.0, 1.0)
		tint.g = clamp(tint.g + _rng.randf_range(-0.08, 0.08), 0.0, 1.0)
		tint.b = clamp(tint.b + _rng.randf_range(-0.08, 0.08), 0.0, 1.0)
		material.albedo_color = tint
		mesh_instance.material_override = material
		add_child(mesh_instance)
		_pieces.append(mesh_instance)
		_colors.append(tint)
		var direction: Vector3 = Vector3(
			_rng.randf_range(-1.0, 1.0),
			_rng.randf_range(0.2, 1.0) + upward_bias,
			_rng.randf_range(-1.0, 1.0)
		).normalized()
		var speed: float = _rng.randf_range(speed_min, speed_max)
		_velocities.append(direction * speed)

func _process(delta: float) -> void:
	_time += delta
	for i in range(_pieces.size()):
		var velocity: Vector3 = _velocities[i]
		velocity.y -= gravity * delta
		_velocities[i] = velocity
		_pieces[i].position += velocity * delta
	if _time >= max(0.0, lifetime - fade_time):
		var alpha: float = clamp((lifetime - _time) / max(fade_time, 0.01), 0.0, 1.0)
		for i in range(_pieces.size()):
			var material: StandardMaterial3D = _pieces[i].material_override as StandardMaterial3D
			if material:
				var tint: Color = _colors[i]
				tint.a = base_color.a * alpha
				material.albedo_color = tint
	if _time >= lifetime:
		queue_free()
