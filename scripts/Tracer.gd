extends Node3D

@export var start_pos: Vector3 = Vector3.ZERO
@export var end_pos: Vector3 = Vector3.ZERO
@export var speed: float = 140.0
@export var width: float = 0.04
@export var color: Color = Color(1.0, 0.9, 0.6, 0.8)
@export var segment_length: float = 2.0
@export var max_time: float = 0.0

var _mesh: MeshInstance3D
var _dir: Vector3 = Vector3.ZERO
var _distance: float = 0.0
var _traveled: float = 0.0
var _time_alive: float = 0.0

func _ready() -> void:
	_dir = end_pos - start_pos
	_distance = _dir.length()
	if _distance <= 0.001:
		queue_free()
		return
	_dir = _dir / _distance

	_mesh = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, width, segment_length)
	_mesh.mesh = mesh

	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission = color
	material.emission_energy_multiplier = 1.3
	_mesh.material_override = material
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)
	_update_transform()

func _process(delta: float) -> void:
	_time_alive += delta
	if max_time > 0.0 and _time_alive >= max_time:
		queue_free()
		return
	_traveled += speed * delta
	if _traveled >= _distance + segment_length:
		queue_free()
		return
	_update_transform()

func _update_transform() -> void:
	var head_dist: float = min(_traveled, _distance)
	var tail_dist: float = max(0.0, head_dist - segment_length)
	var center_dist: float = (head_dist + tail_dist) * 0.5
	var length: float = max(0.05, head_dist - tail_dist)
	var mesh: BoxMesh = _mesh.mesh as BoxMesh
	mesh.size = Vector3(width, width, length)
	var up: Vector3 = Vector3.UP
	if abs(_dir.dot(up)) > 0.98:
		up = Vector3.FORWARD
	global_transform = Transform3D(Basis().looking_at(_dir, up), start_pos + _dir * center_dist)
