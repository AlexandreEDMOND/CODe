extends Control

var minimap: Node = null

func _draw() -> void:
	if minimap == null:
		return
	if minimap.has_method("draw_overlay"):
		minimap.draw_overlay(self)
