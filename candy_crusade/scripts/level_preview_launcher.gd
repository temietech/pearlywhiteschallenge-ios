extends Node3D
class_name LevelPreviewLauncher

## Automatically redirects to main.tscn with this level selected
## whenever this level scene is opened and played directly in the preview/editor.

@export var level_index: int = 0


func _ready() -> void:
	# Detect if this scene was run directly as the root scene (e.g. Play Scene / editor preview)
	if get_tree().current_scene == self:
		var game = get_node_or_null("/root/Game")
		if game != null:
			game.set("test_level_index", level_index)
		var file = FileAccess.open("user://preview_level.txt", FileAccess.WRITE)
		if file != null:
			file.store_string(str(level_index))
			file.close()
		get_tree().change_scene_to_file("res://candy_crusade/main.tscn")
