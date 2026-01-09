extends CharacterBody3D

signal died(bot)

const CHARACTER_SKIN_DIR := "res://models/characters/Models/GLB format"

@export var max_health := 100
@export var character_skin_scale := 1.0

@onready var mesh: MeshInstance3D = $Mesh
@onready var body: Node3D = $Body

var health: int = 0
var dead: bool = false
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
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
	if skin_seed == 0:
		skin_seed = _extract_bot_id()
	_apply_skin()
	if body_skin_loaded:
		mesh.visible = false

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
