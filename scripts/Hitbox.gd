extends Area3D

@export var damage_multiplier := 1.0
@export var instant_kill := false
@export var owner_path := NodePath("..")

func apply_damage(amount: float, from_peer_id: int = 0, _headshot: bool = false, source_pos: Vector3 = Vector3.ZERO) -> void:
	var owner := get_node_or_null(owner_path)
	if owner == null:
		return
	if not owner.has_method("apply_damage"):
		return
	var final_amount := amount * damage_multiplier
	if instant_kill:
		final_amount = 9999.0
	owner.apply_damage(final_amount, from_peer_id, instant_kill, source_pos)
