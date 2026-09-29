extends Node3D

func _ready() -> void:
	for child in find_children("*", "MeshInstance3D", true, false):
		child.create_trimesh_collision()
