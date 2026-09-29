extends Node
class_name RegionController

## Finite region flow. Lovable can later call select_region(index) when its
## progression reaches a region; the pause-menu dev controls use the same API.

@export var blue_candor_scene: PackedScene
@export var spawner_path: NodePath = NodePath("../EnemySpawner")
@export var hud_path: NodePath = NodePath("../HUD")

@export var initial_region: int = -1

var _region_index := 0
var _wave_index := 0
var _boss: Node3D

@onready var _spawner: Node3D = get_node(spawner_path) as Node3D
@onready var _hud = get_node(hud_path)

const REGIONS := [
	{"name": "Level 1: Candy Cave", "waves": [5], "boss_health": 12, "spawn_z": -13.8, "spawn_y": 0.2, "minion_scale": 0.35, "camera_y": 0.80, "camera_pitch": -5.0},
	{"name": "Level 2: Sugar Bridge", "waves": [7, 8], "boss_health": 15, "spawn_z": -13.8, "spawn_y": 0.2, "minion_scale": 0.35, "camera_y": 0.80, "camera_pitch": -5.0},
	{"name": "Level 3: Plain Path", "waves": [9, 10, 11], "boss_health": 18, "spawn_z": -13.8, "spawn_y": 0.2, "minion_scale": 0.35, "camera_y": 0.15, "camera_pitch": -1.0},
	{"name": "Level 4: Enamel Border", "waves": [12, 13, 14, 15], "boss_health": 22, "spawn_z": -13.8, "spawn_y": 0.2, "minion_scale": 0.35, "camera_y": 0.80, "camera_pitch": -5.0},
]


func _ready() -> void:
	add_to_group("region_controller")
	_spawner.wave_finished.connect(_on_wave_finished)
	
	var bridge = get_node_or_null("/root/GameBridge")
	if bridge != null and bridge.has_signal("session_ready"):
		bridge.session_ready.connect(func(_p):
			var start_idx := _get_initial_region_index()
			select_region(start_idx)
		)
		
	# Boot into the level being tested (from open scene, editor visibility, inspector, or last saved test)
	var start_idx := _get_initial_region_index()
	call_deferred("select_region", start_idx)


func _get_initial_region_index() -> int:
	# 1. Check if a test level was requested via running a level scene directly
	var game = get_node_or_null("/root/Game")
	if game != null and "test_level_index" in game:
		var test_idx = int(game.get("test_level_index"))
		if test_idx >= 0 and test_idx < REGIONS.size():
			return test_idx
	
	# 2. Check inspector export override on RegionController
	if initial_region >= 0 and initial_region < REGIONS.size():
		return initial_region
	
	# 3. Check active GameState profile day
	var game_state = get_node_or_null("/root/GameState")
	if game_state != null and game_state.has_method("get_active_profile"):
		var p: Dictionary = game_state.get_active_profile()
		if not p.is_empty():
			var cur_node: int = int(p.get("currentNode", 1))
			var cur_day: int = game_state.day_for_node(cur_node) if game_state.has_method("day_for_node") else 1
			if cur_day >= 28:
				return 3 # Level 4 (Day 28+)
			elif cur_day < 9:
				return 0 # Level 1 (Days 1-8)
			elif cur_day < 19:
				return 1 # Level 2 (Days 9-18)
			else:
				return 2 # Level 3 (Days 19-27)

	# 4. Check if the user toggled visibility of a specific level in the editor (under Regions)
	var regions_node = get_node_or_null("../Regions")
	if regions_node != null:
		var children = regions_node.get_children()
		var visible_idx := -1
		var visible_count := 0
		for i in range(children.size()):
			var c := children[i] as Node3D
			if c != null and c.visible:
				visible_idx = i
				visible_count += 1
		if visible_count == 1 and visible_idx >= 0:
			return visible_idx
	
	# 5. Check if there is a saved preview level from a recent test session
	if FileAccess.file_exists("user://preview_level.txt"):
		var f := FileAccess.open("user://preview_level.txt", FileAccess.READ)
		if f != null:
			var txt := f.get_as_text().strip_edges()
			f.close()
			if txt.is_valid_int():
				var saved_idx := txt.to_int()
				if saved_idx >= 0 and saved_idx < REGIONS.size():
					return saved_idx
	
	return 0


func select_region(index: int) -> void:
	_region_index = clampi(index, 0, REGIONS.size() - 1)
	_wave_index = 0
	
	# Save the active testing level so future preview launches remember it
	var f := FileAccess.open("user://preview_level.txt", FileAccess.WRITE)
	if f != null:
		f.store_string(str(_region_index))
		f.close()
	
	_spawner.clear_minions()
	if is_instance_valid(_boss):
		_boss.queue_free()
	for crate in get_tree().get_nodes_in_group("ammo_crates"):
		crate.queue_free()
	for coin in get_tree().get_nodes_in_group("coins"):
		coin.queue_free()
	for candy in get_tree().get_nodes_in_group("boss_candies"):
		candy.queue_free()
	var proj_node = get_node_or_null("../Projectiles")
	if proj_node != null:
		for p in proj_node.get_children():
			if p.name != "AimReticle" and p.name != "TrajectoryArc":
				p.queue_free()

	var bridge = get_node_or_null("/root/GameBridge")
	if bridge != null and bridge.has_method("reset_run_metrics"):
		bridge.reset_run_metrics()

	_hud.hide_region_cleared()
	get_tree().paused = false
	var player = get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("reset_player"):
		player.reset_player()
	apply_camera_to_player(player)
	_ensure_environment_collisions()
	_update_region_models()
	if bridge != null and bridge.is_boss:
		_spawn_blue_candor()
	elif _region_index == 0 and _hud != null and _hud.has_method("show_level1_instructions_modal"):
		_hud.show_level1_instructions_modal(func():
			_start_wave()
		)
	else:
		_start_wave()


func apply_camera_to_player(player_node: Node = null) -> void:
	var p = player_node
	if p == null:
		p = get_tree().get_first_node_in_group("player")
	if p != null and p.has_method("set_camera_profile"):
		var reg: Dictionary = REGIONS[_region_index]
		var cy: float = float(reg.get("camera_y", 0.80))
		var cz: float = float(reg.get("camera_z", 0.60))
		var cp: float = float(reg.get("camera_pitch", -5.0))
		p.set_camera_profile(Vector3(0.0, cy, cz), Vector3(cp, 0.0, 0.0))


var _collision_ensured_regions: Dictionary = {}

func _ensure_environment_collisions() -> void:
	if _collision_ensured_regions.get(_region_index, false):
		return
	var regions_node = get_node_or_null("../Regions")
	if regions_node == null:
		return
	var children = regions_node.get_children()
	if _region_index < 0 or _region_index >= children.size():
		return
	var active_region_node = children[_region_index]
	if active_region_node == null:
		return
	for child in active_region_node.find_children("*", "MeshInstance3D", true, false):
		var mi = child as MeshInstance3D
		if mi != null and mi.mesh != null:
			var has_col := false
			for subchild in mi.get_children():
				if subchild is StaticBody3D:
					has_col = true
					subchild.collision_layer = 1
					subchild.collision_mask = 0
					break
			if not has_col:
				mi.create_trimesh_collision()
				for subchild in mi.get_children():
					if subchild is StaticBody3D:
						subchild.collision_layer = 1
						subchild.collision_mask = 0
	_collision_ensured_regions[_region_index] = true


func _update_region_models() -> void:
	var regions_node = get_node_or_null("../Regions")
	if regions_node != null:
		var children = regions_node.get_children()
		for i in range(children.size()):
			var child = children[i] as Node3D
			if child != null:
				var is_active := (i == _region_index)
				child.visible = is_active
				child.process_mode = Node.PROCESS_MODE_INHERIT if is_active else Node.PROCESS_MODE_DISABLED
				if is_active:
					_clean_level_3d_meshes(child)
				# Enable collisions only on the active level so inactive environments never block weapons or terrain raycasts
				for body in child.find_children("*", "StaticBody3D", true, false):
					(body as StaticBody3D).collision_layer = 1 if is_active else 0
				for col in child.find_children("*", "CollisionShape3D", true, false):
					(col as CollisionShape3D).disabled = not is_active


func _clean_level_3d_meshes(root_node: Node) -> void:
	if root_node == null:
		return
	for node in root_node.find_children("*", "Node", true, false):
		var n_name := node.name.to_lower()
		var is_title := false
		if n_name.contains("text") or n_name.contains("title") or n_name.contains("logo") \
			or n_name.contains("crusade") or n_name.contains("candycrusade") \
			or n_name.contains("banner") or n_name.contains("sign") or n_name.contains("heading") \
			or n_name.contains("font") or n_name.contains("letter"):
			is_title = true
		if node is MeshInstance3D:
			var mi := node as MeshInstance3D
			if mi.mesh != null:
				var m_name := mi.mesh.resource_name.to_lower()
				if m_name.contains("text") or m_name.contains("title") or m_name.contains("logo") \
					or m_name.contains("crusade") or m_name.contains("banner") or m_name.contains("sign"):
					is_title = true
		if is_title:
			if node is Node3D:
				(node as Node3D).visible = false
				(node as Node3D).position = Vector3(0, -9999, 0)
				(node as Node3D).process_mode = Node.PROCESS_MODE_DISABLED
			if node is CollisionObject3D:
				(node as CollisionObject3D).collision_layer = 0
				(node as CollisionObject3D).collision_mask = 0


func _start_wave() -> void:
	var region: Dictionary = REGIONS[_region_index]
	var waves: Array = region["waves"]
	var speed_multiplier := 1.0 + _region_index * 0.30 + _wave_index * 0.15
	var wander_amplitude := 0.10 + _region_index * 0.08 + _wave_index * 0.10
	_hud.set_region_status(str(region["name"]), _wave_index + 1, waves.size(), false)
	_spawner.spawn_z = float(region.get("spawn_z", -13.8))
	_spawner.spawn_y = float(region.get("spawn_y", 0.2))
	_spawner.set("minion_scale", float(region.get("minion_scale", 0.35)))
	_spawner.start_wave(int(waves[_wave_index]), speed_multiplier, wander_amplitude, _region_index + 1)
	
	# All levels start with 2 minions out at the front (-6.0, -9.6), and 1 emerging from the back (-13.2)
	_spawner.prepopulate(3, -6.0, 3.6)


func _on_wave_finished() -> void:
	_wave_index += 1
	var waves: Array = REGIONS[_region_index]["waves"]
	if _wave_index < waves.size():
		_start_wave()
	else:
		_spawn_blue_candor()


func _spawn_blue_candor() -> void:
	if blue_candor_scene == null:
		return
	_hud.set_region_status(str(REGIONS[_region_index]["name"]), _wave_index, _wave_index, true)
	_boss = blue_candor_scene.instantiate() as Node3D
	# Configure before entering the tree: Blue Candor's _ready() initializes its
	# current health from this region-specific maximum.
	var base_hp: int = int(REGIONS[_region_index]["boss_health"])
	var bridge = get_node_or_null("/root/GameBridge")
	if bridge != null:
		base_hp = int(round(float(base_hp) * bridge.get_difficulty_health_mult()))
	_boss.set("max_health", base_hp)
	add_child(_boss)
	var spawn_z: float = float(REGIONS[_region_index].get("spawn_z", -13.8))
	var spawn_y: float = float(REGIONS[_region_index].get("spawn_y", 0.2))
	_boss.global_position = Vector3(0.0, spawn_y, spawn_z)
	_boss.died.connect(_on_boss_died)
	if _hud.has_method("update_boss_health"):
		_boss.health_changed.connect(_hud.update_boss_health)


func get_current_region_index() -> int:
	return _region_index


func get_total_regions() -> int:
	return REGIONS.size()


func get_region_name(index: int = -1) -> String:
	var idx := _region_index if index < 0 else clampi(index, 0, REGIONS.size() - 1)
	return str(REGIONS[idx]["name"])


func restart_region() -> void:
	select_region(_region_index)


func next_region() -> void:
	if _region_index + 1 < REGIONS.size():
		select_region(_region_index + 1)
	else:
		select_region(0)


func _on_boss_died() -> void:
	var bridge = get_node_or_null("/root/GameBridge")
	if bridge != null:
		bridge.boss_defeated = true
	# Give Blue Candor time to complete his defeat collapse onto the ground before opening the end page
	await get_tree().create_timer(1.2).timeout
	_hud.show_region_cleared(str(REGIONS[_region_index]["name"]))

