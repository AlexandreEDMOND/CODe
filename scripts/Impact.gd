extends Node3D

@export var size := 0.18
@export var lifetime := 0.8
@export var fade_time := 0.25
@export var color := Color(0.08, 0.08, 0.08, 0.8)

@onready var quad: MeshInstance3D = $Quad

var _elapsed: float = 0.0
var _base_alpha: float = 1.0
var _material: StandardMaterial3D = null

func _ready() -> void:
	_base_alpha = color.a
	_material = StandardMaterial3D.new()
	_material.albedo_color = color
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.cull_mode = BaseMaterial3D.CULL_BACK
	_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	quad.material_override = _material

	var mesh := QuadMesh.new()
	mesh.size = Vector2(size, size)
	quad.mesh = mesh

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= lifetime:
		queue_free()
		return

	var fade_start: float = max(0.0, lifetime - fade_time)
	if _elapsed >= fade_start:
		var t: float = (_elapsed - fade_start) / max(0.001, fade_time)
		var new_color := color
		new_color.a = _base_alpha * (1.0 - clamp(t, 0.0, 1.0))
		if _material:
			_material.albedo_color = new_color
