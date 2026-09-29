@tool
extends Node3D
class_name EditorCameraGuide

## Visual guide in the 3D editor showing the player's Camera3D, walk lane,
## and enemy spawn line so level environments can be positioned accurately.
## Automatically frees itself at runtime so it never interferes with gameplay.

func _ready() -> void:
	if not Engine.is_editor_hint():
		queue_free()
