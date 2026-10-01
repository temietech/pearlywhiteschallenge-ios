extends Area3D
class_name AmmoCrate

## Interactive 3D ammo chest: spawns when a minion is defeated.
## Shows AmmoChestClosed.glb in idle, and AmmoChestOpen.glb when tapped.
## On tap: pops open, and an ammo item emerges to hover above the chest:
##   - Toothpaste bullets: bundle of 3 (3D models, hover & spin)
##   - Battery (level 2/3) or Brush (level 1): 1 item (3D model, hovers & spins)
##   - Mouthwash: 1 flask (3D model matching level 1, 2, or 3, hovers & spins)
##   - Floss: 1 floss (2D sprite, hovers & bounces up and down in size, does not spin)

signal opened

const PurpleStars = preload("res://candy_crusade/scripts/purple_stars.gd")

const MODEL_CLOSED_PATH := "res://assets/candy_crusade/models/AmmoChestClosed.glb"
const MODEL_OPEN_PATH := "res://assets/candy_crusade/models/AmmoChestOpen.glb"

static var _cached_scenes: Dictionary = {}

static func get_cached_scene(path: String) -> PackedScene:
	if path == "":
		return null
	if not _cached_scenes.has(path):
		if ResourceLoader.exists(path):
			_cached_scenes[path] = load(path)
		elif FileAccess.file_exists(path):
			var gltf := GLTFDocument.new()
			var state := GLTFState.new()
			var err := gltf.append_from_file(path, state)
			if err == OK:
				var scene := PackedScene.new()
				var root := gltf.generate_scene(state)
				scene.pack(root)
				_cached_scenes[path] = scene
	return _cached_scenes.get(path)

const TARGET_CHEST_WIDTH := 0.52
const BOB_SPEED := 3.2
const BOB_HEIGHT := 0.025
const LIFETIME := 16.0
const OPEN_DISPLAY_TIME := 1.0
const LOOT_HOVER_Y := 0.74
## Items are normalised to ~0.22m. With the 75 degree camera, 0.5m away x 1.1 scale fills
## ~55% of the screen width on a normal phone and ~70% on a very tall one (big, never clipped).
const LOOT_CLOSEUP_DIST := 0.50   # metres in front of the camera
const LOOT_CLOSEUP_SCALE := 1.1   # how big the item gets when it's up close

var _age := 0.0
var _base_y := 0.06
var _collected := false
var _is_opening := false

var _mesh_root: Node3D
var _closed_model: Node3D
var _open_model: Node3D
var _aura_particles: CPUParticles3D
var _collision_shape: CollisionShape3D

# Ejected loot item tracking
var _loot_item_root: Node3D
var _loot_visual: Node3D
var _loot_is_spinning := false
var _loot_is_bouncing_size := false
var _loot_anim_time := 0.0
var _loot_rising := false


func _ready() -> void:
	add_to_group("ammo_crates")
	collision_layer = 4 # Layer 3 / bit 4 for pickups
	collision_mask = 0
	input_ray_pickable = true
	input_event.connect(_on_area_input_event)
	
	_base_y = global_position.y
	_setup_models()
	_setup_collision()
	_setup_aura_particles()
	_play_spawn_animation()
	call_deferred("_snap_to_ground")


func _on_area_input_event(_cam: Camera3D, event: InputEvent, _pos: Vector3, _norm: Vector3, _shape_idx: int) -> void:
	if _collected or _is_opening:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		collect()
	elif event is InputEventScreenTouch and event.pressed:
		collect()


func _snap_to_ground() -> void:
	var space_state := get_world_3d().direct_space_state
	if space_state == null:
		return
	var from_pos := Vector3(global_position.x, global_position.y + 2.5, global_position.z)
	var to_pos := Vector3(global_position.x, global_position.y - 3.0, global_position.z)
	var query := PhysicsRayQueryParameters3D.create(from_pos, to_pos)
	query.collision_mask = 1 # Environment / Lane
	var hit := space_state.intersect_ray(query)
	if hit and hit.has("position"):
		# Lift 0.04 m so the chest body sits cleanly on the surface, never inside it
		global_position.y = hit["position"].y + 0.04
		_base_y = global_position.y


func _setup_models() -> void:
	_mesh_root = Node3D.new()
	_mesh_root.name = "MeshRoot"
	add_child(_mesh_root)
	
	var has_custom_models := false
	var closed_scene := get_cached_scene(MODEL_CLOSED_PATH)
	var open_scene := get_cached_scene(MODEL_OPEN_PATH)
	if closed_scene != null and open_scene != null:
		_closed_model = closed_scene.instantiate() as Node3D
		_open_model = open_scene.instantiate() as Node3D
		if _closed_model != null and _open_model != null:
			_closed_model.name = "ClosedChest"
			_open_model.name = "OpenChest"
			_mesh_root.add_child(_closed_model)
			_mesh_root.add_child(_open_model)
			has_custom_models = true
				
	if has_custom_models:
		_align_and_scale_chests()
	else:
		_build_procedural_fallback()


func _get_relative_transform_to(child: Node3D, root: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var curr: Node = child
	while curr != null and curr != root:
		if curr is Node3D:
			t = (curr as Node3D).transform * t
		curr = curr.get_parent()
	return t


func _measure_model(node: Node3D) -> AABB:
	var total_box := AABB()
	var has_box := false
	for child in node.find_children("*", "VisualInstance3D", true, false):
		var vi := child as VisualInstance3D
		if vi != null and vi.has_method("get_aabb"):
			var local_box: AABB = vi.get_aabb()
			var child_trans: Transform3D = _get_relative_transform_to(vi, node)
			var transformed_box := child_trans * local_box
			if not has_box:
				total_box = transformed_box
				has_box = true
			else:
				total_box = total_box.merge(transformed_box)
	return total_box


func _align_and_scale_chests() -> void:
	var closed_box := _measure_model(_closed_model)
	var open_box := _measure_model(_open_model)
	
	var max_dim := maxf(closed_box.size.x, maxf(closed_box.size.y, closed_box.size.z))
	var s := 1.0
	if max_dim > 0.01:
		s = TARGET_CHEST_WIDTH / max_dim
	else:
		s = 0.70
		
	_closed_model.scale = Vector3(s, s, s)
	_open_model.scale = Vector3(s, s, s)
	
	# Center X and Z, ground Y at 0
	var offset := Vector3.ZERO
	if max_dim > 0.01:
		offset = Vector3(-closed_box.get_center().x * s, -closed_box.position.y * s, -closed_box.get_center().z * s)
	_closed_model.position = offset
	_open_model.position = offset
	
	# Detect orientation: if lid opens toward +Z, the front faces -Z, so rotate 180 to face camera
	if open_box.size.z > 0.01 and closed_box.size.z > 0.01:
		var delta_neg_z: float = closed_box.position.z - open_box.position.z
		var delta_pos_z: float = open_box.end.z - closed_box.end.z
		if delta_pos_z > delta_neg_z + 0.02:
			_mesh_root.rotation_degrees.y = 180.0
		var delta_pos_x: float = open_box.end.x - closed_box.end.x
		var delta_neg_x: float = closed_box.position.x - open_box.position.x
		if delta_pos_x > 0.05 and delta_pos_x > delta_neg_z:
			_mesh_root.rotation_degrees.y = 90.0
		elif delta_neg_x > 0.05 and delta_neg_x > delta_neg_z:
			_mesh_root.rotation_degrees.y = -90.0
			
	_closed_model.visible = true
	_open_model.visible = false


func _build_procedural_fallback() -> void:
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(0.44, 0.36, 0.44)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.75, 0.95)
	mat.metallic = 0.3
	mat.roughness = 0.4
	var box_inst := MeshInstance3D.new()
	box_inst.mesh = box_mesh
	box_inst.material_override = mat
	box_inst.position.y = 0.18
	_mesh_root.add_child(box_inst)


func _setup_collision() -> void:
	_collision_shape = get_node_or_null("CollisionShape3D") as CollisionShape3D
	if _collision_shape == null:
		_collision_shape = CollisionShape3D.new()
		_collision_shape.name = "CollisionShape3D"
		var sphere := SphereShape3D.new()
		sphere.radius = 0.28
		_collision_shape.shape = sphere
		add_child(_collision_shape)
	else:
		var sphere := SphereShape3D.new()
		sphere.radius = 0.28
		_collision_shape.shape = sphere
	_collision_shape.position = Vector3(0, 0.18, 0)


func _setup_aura_particles() -> void:
	_aura_particles = CPUParticles3D.new()
	_aura_particles.name = "AuraParticles"
	_aura_particles.amount = 10
	_aura_particles.lifetime = 1.2
	_aura_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_aura_particles.emission_sphere_radius = 0.26
	_aura_particles.direction = Vector3.UP
	_aura_particles.spread = 35.0
	_aura_particles.gravity = Vector3(0, 0.35, 0)
	_aura_particles.initial_velocity_min = 0.20
	_aura_particles.initial_velocity_max = 0.55
	_aura_particles.scale_amount_min = 0.04
	_aura_particles.scale_amount_max = 0.09
	
	var sm := SphereMesh.new()
	sm.radius = 0.035
	sm.height = 0.070
	_aura_particles.mesh = sm
	
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.85, 0.35, 0.75)
	_aura_particles.material_override = mat
	
	add_child(_aura_particles)
	_aura_particles.position = Vector3(0, 0.18, 0)


func _play_spawn_animation() -> void:
	_mesh_root.position.y = 0.22
	_mesh_root.scale = Vector3(0.3, 0.3, 0.3)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_mesh_root, "position:y", 0.0, 0.28).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(_mesh_root, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _physics_process(delta: float) -> void:
	if _is_opening or _collected:
		if _loot_item_root != null and is_instance_valid(_loot_item_root):
			_loot_anim_time += delta
			
			if _loot_is_spinning and _loot_visual != null and is_instance_valid(_loot_visual):
				_loot_visual.rotate_y(2.0 * delta)
				
			if _loot_is_bouncing_size and _loot_visual != null and is_instance_valid(_loot_visual):
				var s := 1.0 + sin(_loot_anim_time * 6.5) * 0.18
				_loot_visual.scale = Vector3(s, s, s)
		return
		
	_age += delta
	if _age >= LIFETIME:
		_despawn_expired()
		return
		
	if _mesh_root != null:
		# Bob upward from floor surface, never dip into ground
		_mesh_root.position.y = (sin(_age * BOB_SPEED) + 1.0) * 0.5 * BOB_HEIGHT
		_mesh_root.rotation.z = sin(_age * 2.0) * deg_to_rad(2.5)
		
	if _age >= LIFETIME - 3.0:
		visible = (fmod(_age * 8.0, 1.0) > 0.3)


func _despawn_expired() -> void:
	_collected = true
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ZERO, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)


func open() -> void:
	collect()


func collect() -> void:
	if _collected or _is_opening:
		return
	_collected = true
	_is_opening = true
	remove_from_group("ammo_crates")
	input_ray_pickable = false
	if _collision_shape != null:
		_collision_shape.disabled = true
		_collision_shape.set_deferred("disabled", true)
	opened.emit()
	
	if _aura_particles != null:
		_aura_particles.emitting = false
		
	_play_open_sequence()


func _play_open_sequence() -> void:
	var base_scale := _mesh_root.scale
	_mesh_root.rotation.z = 0.0
	
	# Subtle camera punch for physical weight
	var player = get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("apply_camera_shake"):
		player.apply_camera_shake(0.10)
	
	var tw := create_tween()
	# 1. Anticipation squash
	tw.tween_property(_mesh_root, "scale", Vector3(base_scale.x * 1.25, base_scale.y * 0.65, base_scale.z * 1.25), 0.08)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	# 2. POP OPEN & HOP INTO THE AIR!
	tw.tween_callback(func():
		if _closed_model != null:
			_closed_model.visible = false
		if _open_model != null:
			_open_model.visible = true
			var anim_players = _open_model.find_children("*", "AnimationPlayer", true, false)
			if not anim_players.is_empty():
				var ap := anim_players[0] as AnimationPlayer
				var list := ap.get_animation_list()
				if not list.is_empty():
					ap.play(list[0])
		_spawn_open_burst_fx()
		_spawn_loot_item()
	)
	
	# Chest jumps up off the ground with an energetic bounce
	var hop_tw := create_tween()
	hop_tw.set_parallel(true)
	hop_tw.tween_property(_mesh_root, "position:y", 0.16, 0.12)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	hop_tw.tween_property(_mesh_root, "rotation_degrees:z", 7.0, 0.12)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	hop_tw.tween_property(_mesh_root, "scale", Vector3(base_scale.x * 0.88, base_scale.y * 1.30, base_scale.z * 0.88), 0.12)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Land back down with a juicy double bounce
	hop_tw.chain().tween_property(_mesh_root, "position:y", 0.0, 0.24)\
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	hop_tw.parallel().tween_property(_mesh_root, "rotation_degrees:z", 0.0, 0.24)\
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	hop_tw.parallel().tween_property(_mesh_root, "scale", base_scale, 0.24)\
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		
	# 4. Open chest sits proudly on the lane while item is presented
	tw.tween_interval(OPEN_DISPLAY_TIME)
	
	# 5. Graceful shrink and remove chest
	tw.tween_property(_mesh_root, "scale", Vector3.ZERO, 0.25)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)


func _spawn_open_burst_fx() -> void:
	var container := get_parent()
	if container == null:
		return
	
	# 1. Radiant Golden Light Pillar shooting straight up from the chest cavity
	var pillar := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.06
	cyl.bottom_radius = 0.18
	cyl.height = 1.8
	pillar.mesh = cyl
	var pillar_mat := StandardMaterial3D.new()
	pillar_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pillar_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pillar_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	pillar_mat.albedo_color = Color(1.0, 0.94, 0.45, 0.90)
	pillar.material_override = pillar_mat
	container.add_child(pillar)
	pillar.global_position = global_position + Vector3(0, 0.90, 0)
	pillar.scale = Vector3(0.20, 1.0, 0.20)
	
	var p_tw := pillar.create_tween()
	p_tw.set_parallel(true)
	p_tw.tween_property(pillar, "scale", Vector3(1.6, 1.0, 1.6), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	p_tw.tween_property(pillar_mat, "albedo_color:a", 0.0, 0.45).set_delay(0.12).set_trans(Tween.TRANS_QUAD)
	p_tw.chain().tween_callback(pillar.queue_free)
	
	# 2. Expanding Golden Shockwave Ring sweeping across the ground
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.14
	torus.outer_radius = 0.22
	ring.mesh = torus
	var ring_mat := StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	ring_mat.albedo_color = Color(1.0, 0.88, 0.35, 0.95)
	ring.material_override = ring_mat
	container.add_child(ring)
	ring.global_position = global_position + Vector3(0, 0.035, 0)
	
	var r_tw := ring.create_tween()
	r_tw.set_parallel(true)
	r_tw.tween_property(ring, "scale", Vector3(3.8, 1.0, 3.8), 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	r_tw.tween_property(ring_mat, "albedo_color:a", 0.0, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	r_tw.chain().tween_callback(ring.queue_free)

	# 3. High-velocity celebratory sparkle & starburst fountain
	var burst := CPUParticles3D.new()
	burst.amount = 54
	burst.lifetime = 0.65
	burst.one_shot = true
	burst.explosiveness = 0.97
	
	var sm := SphereMesh.new()
	sm.radius = 0.035
	sm.height = 0.070
	burst.mesh = sm
	
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(1.0, 0.92, 0.35)
	burst.material_override = mat
	
	burst.direction = Vector3(0, 1, 0)
	burst.spread = 65.0
	burst.initial_velocity_min = 3.2
	burst.initial_velocity_max = 6.8
	burst.gravity = Vector3(0, -7.0, 0)
	burst.scale_amount_min = 0.15
	burst.scale_amount_max = 0.45
	
	container.add_child(burst)
	burst.global_position = global_position + Vector3(0, 0.16, 0)
	get_tree().create_timer(0.9).timeout.connect(burst.queue_free)

	# 4. Radiant purple stars burst popping out of the chest
	PurpleStars.spawn_burst(global_position + Vector3(0, 0.45, 0), get_tree(), 14, 1.25)


# =========================================================================
# LOOT ITEM EMERGE & ANIMATION SYSTEM
# =========================================================================

func _spawn_loot_item() -> void:
	# Only drop ammo for weapons the player has actually unlocked
	var all_types := {"toothpaste": "paste", "boomerang": "brush", "mouthwash": "wash", "floss": "floss"}
	var item_types: Array = []
	var loot_bridge = get_node_or_null("/root/GameBridge")
	for t in all_types:
		var unlocked := true
		if loot_bridge != null and loot_bridge.has_method("get_weapon_level"):
			unlocked = int(loot_bridge.get_weapon_level(all_types[t])) >= 1
		if unlocked:
			item_types.append(t)
	if item_types.is_empty():
		item_types = ["boomerang"]
	var chosen_type: String = item_types.pick_random()
	
	_loot_item_root = Node3D.new()
	_loot_item_root.name = "LootItemRoot"
	_loot_item_root.top_level = true
	get_tree().current_scene.add_child(_loot_item_root)
	
	var spawn_pos := global_position + Vector3(0, 0.44, 0)
	_loot_item_root.global_position = spawn_pos
	_loot_item_root.scale = Vector3(0.12, 0.12, 0.12)
	
	var label_text := ""
	var label_color := Color.WHITE
	var item_lvl := 1
	
	match chosen_type:
		"toothpaste":
			item_lvl = _get_pistol_level()
			_loot_visual = _create_toothpaste_bundle()
			_loot_is_spinning = true
			_loot_is_bouncing_size = false
			if item_lvl >= 3:
				label_text = "+3 BUBBLE TOOTHPASTE!"
			else:
				label_text = "+3 TOOTHPASTE (LVL %d)!" % item_lvl
			label_color = Color(0.35, 0.88, 1.0)
			_grant_ammo("pistol", 3)
		"boomerang", "battery", "brush":
			item_lvl = _get_brush_level()
			if item_lvl >= 3:
				_loot_visual = _create_brush_item()
				label_text = "+1 BUBBLE BRUSH!"
			elif item_lvl == 2:
				_loot_visual = _create_battery_item()
				label_text = "+1 BATTERY (LVL 2)!"
			else:
				_loot_visual = _create_brush_item()
				label_text = "+1 BRUSH (LVL 1)!"
			_loot_is_spinning = true
			_loot_is_bouncing_size = false
			label_color = Color(1.0, 0.88, 0.25)
			_grant_ammo("boomerang", 1)
		"mouthwash":
			item_lvl = _get_mouthwash_level()
			_loot_visual = _create_mouthwash_item()
			_loot_is_spinning = true
			_loot_is_bouncing_size = false
			if item_lvl >= 3:
				label_text = "+1 BUBBLE MOUTHWASH!"
			else:
				label_text = "+1 MOUTHWASH (LVL %d)!" % item_lvl
			label_color = Color(0.78, 0.45, 1.0)
			_grant_ammo("grenade", 1)
		"floss":
			item_lvl = _get_floss_level()
			_loot_visual = _create_floss_item()
			_loot_is_spinning = false
			_loot_is_bouncing_size = true
			if item_lvl >= 3:
				label_text = "+1 BUBBLE FLOSS!"
			else:
				label_text = "+1 FLOSS (LVL %d)!" % item_lvl
			label_color = Color(0.92, 1.0, 0.95)
			_grant_ammo("lasso", 1)
		
	if _loot_visual != null:
		_loot_item_root.add_child(_loot_visual)
	
	var card_target_key := ""
	match chosen_type:
		"toothpaste", "pistol", "paste":
			card_target_key = "pistol"
		"boomerang", "battery", "brush":
			card_target_key = "boomerang"
		"mouthwash", "grenade", "wash":
			card_target_key = "grenade"
		"floss", "lasso":
			card_target_key = "lasso"
			
	# Determine target showcase position: comfortable distance in front of camera
	var cam: Camera3D = get_viewport().get_camera_3d() if get_viewport() != null else null
	var target_pos: Vector3 = spawn_pos + Vector3(0, LOOT_HOVER_Y, 0)
	if cam != null and is_instance_valid(cam):
		var fwd := -cam.global_transform.basis.z.normalized()
		var up := cam.global_transform.basis.y.normalized()
		# Bring the item RIGHT UP to the camera (~0.40m away, centred) so it fills the screen
		target_pos = cam.global_position + fwd * LOOT_CLOSEUP_DIST + up * (-0.02)
		_loot_item_root.look_at(cam.global_position, Vector3.UP)
		_loot_item_root.rotate_y(PI) # face camera
		
	var loot_node := _loot_item_root
	var card_key_copy := card_target_key
	
	# Self-contained spin animation on the visual node
	if _loot_is_spinning and _loot_visual != null:
		var spin_tw := loot_node.create_tween().set_loops()
		spin_tw.tween_property(_loot_visual, "rotation:y", TAU, 2.2).as_relative()
		
	# 1. Fly up out of the chest and zoom right up to the camera, growing big
	var rise_tw := loot_node.create_tween()
	rise_tw.set_parallel(true)
	rise_tw.tween_property(loot_node, "global_position", target_pos, 0.55)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	rise_tw.tween_property(loot_node, "scale", Vector3.ONE * LOOT_CLOSEUP_SCALE, 0.50)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		
	# 2. Arrive in front of camera: trigger celebratory sparkles
	var tree := loot_node.get_tree()
	rise_tw.chain().tween_callback(func():
		if is_instance_valid(loot_node) and loot_node.get_tree() != null:
			spawn_foreground_sparkles(target_pos, loot_node.get_tree())
	)
	
	# 3. Hold close-up in front of the screen
	rise_tw.chain().tween_interval(1.2)
	
	# 4. Fade out smoothly and remove completely
	rise_tw.chain().tween_callback(func():
		if not is_instance_valid(loot_node):
			return
		start_loot_fade_out(loot_node, 0.40, func():
			var cur_tree := loot_node.get_tree() if is_instance_valid(loot_node) else null
			var hud = cur_tree.get_first_node_in_group("hud") if cur_tree != null else null
			if hud == null and cur_tree != null and cur_tree.current_scene != null:
				hud = cur_tree.current_scene.find_child("HUD", true, false)
			if hud != null and hud.has_method("bounce_card"):
				hud.bounce_card(card_key_copy)
				
			if is_instance_valid(loot_node):
				loot_node.queue_free()
		)
	)
	
	# 5. Safety fallback timer - absolute guarantee that the item disappears
	if tree != null:
		tree.create_timer(2.8).timeout.connect(func():
			if is_instance_valid(loot_node):
				loot_node.queue_free()
		)


func _grant_ammo(weapon_name: String, amount: int) -> void:
	var bridge = get_node_or_null("/root/GameBridge")
	if bridge != null:
		bridge.coins_collected += 5
	var game = get_node_or_null("/root/Game")
	if game != null and game.has_method("add_ammo"):
		game.add_ammo(weapon_name, amount)


func _align_model_upright(node: Node3D) -> void:
	var box := _measure_model(node)
	# If model's longest dimension is Z, rotate -90 on X so it stands vertically (+Y)
	if box.size.z > box.size.y * 1.25 and box.size.z > box.size.x:
		node.rotation_degrees.x = -90.0
	# If model's longest dimension is X, rotate 90 on Z so it stands vertically (+Y)
	elif box.size.x > box.size.y * 1.25 and box.size.x > box.size.z:
		node.rotation_degrees.z = 90.0


func _normalize_and_center_model(node: Node3D, target_size: float = 0.22) -> void:
	var box := _measure_model(node)
	var max_dim := maxf(box.size.x, maxf(box.size.y, box.size.z))
	var s := target_size / max_dim if max_dim > 0.001 else target_size
	node.scale = Vector3(s, s, s)
	if max_dim > 0.001:
		node.position = -box.get_center() * s


## Toothpaste bullets: bundle of 3 (3D models arranged in a neat trio, smaller & clearly separated)
func _create_toothpaste_bundle() -> Node3D:
	var bundle_root := Node3D.new()
	bundle_root.name = "ToothpasteBundle"
	
	var bullet_path := _get_bullet_model_path()
	var bullet_scene := get_cached_scene(bullet_path)
	if bullet_scene == null:
		bullet_scene = get_cached_scene("res://assets/candy_crusade/models/level1pistolbullet.glb")

	# Splayed 3-bullet fan with generous separation so they never touch or overlap
	var offsets := [
		Vector3(-0.095, -0.01, 0.0),
		Vector3(0.0, 0.025, -0.02),
		Vector3(0.095, -0.01, 0.0)
	]
	var tilts := [
		Vector3(0.0, 0.0, 9.0),
		Vector3(-3.0, 0.0, 0.0),
		Vector3(0.0, 0.0, -9.0)
	]
	
	for i in range(3):
		var b_holder := Node3D.new()
		b_holder.position = offsets[i]
		b_holder.rotation_degrees = tilts[i]
		bundle_root.add_child(b_holder)
		
		if bullet_scene != null:
			var b_inst := bullet_scene.instantiate() as Node3D
			var game = get_node_or_null("/root/Game")
			if game != null and game.has_method("apply_model_materials"):
				game.apply_model_materials(b_inst, bullet_path)
			b_holder.add_child(b_inst)
			_align_model_upright(b_inst)
			_normalize_and_center_model(b_inst, 0.13)
		else:
			var cm := CapsuleMesh.new()
			cm.radius = 0.016
			cm.height = 0.10
			var mi := MeshInstance3D.new()
			mi.mesh = cm
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.3, 0.85, 1.0)
			mi.material_override = mat
			b_holder.add_child(mi)
			
	return bundle_root


## Brush: one 3D toothbrush boomerang model (for Level 1 brush before battery upgrade)
func _create_brush_item() -> Node3D:
	var holder := Node3D.new()
	holder.name = "BrushItem"
	
	var brush_path := "res://assets/candy_crusade/models/brush_boomerang.glb"
	var brush_scene := get_cached_scene(brush_path)
	if brush_scene != null:
		var b_inst := brush_scene.instantiate() as Node3D
		var game = get_node_or_null("/root/Game")
		if game != null and game.has_method("apply_model_materials"):
			game.apply_model_materials(b_inst, brush_path)
		holder.add_child(b_inst)
		_align_model_upright(b_inst)
		_normalize_and_center_model(b_inst, 0.26)
	else:
		var box_mesh := BoxMesh.new()
		box_mesh.size = Vector3(0.04, 0.24, 0.04)
		var mi := MeshInstance3D.new()
		mi.mesh = box_mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.85, 0.25)
		mi.material_override = mat
		holder.add_child(mi)
		
	return holder


## Battery: one 3D battery model
func _create_battery_item() -> Node3D:
	var holder := Node3D.new()
	holder.name = "BatteryItem"
	
	var batt_path := _get_battery_model_path()
	var batt_scene := get_cached_scene(batt_path)
	if batt_scene == null:
		batt_scene = get_cached_scene("res://assets/candy_crusade/models/Level2BrushBattery.glb")
		
	if batt_scene != null:
		var b_inst := batt_scene.instantiate() as Node3D
		var game = get_node_or_null("/root/Game")
		if game != null and game.has_method("apply_model_materials"):
			game.apply_model_materials(b_inst, batt_path)
		holder.add_child(b_inst)
		_align_model_upright(b_inst)
		_normalize_and_center_model(b_inst, 0.30)
	else:
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.045
		cyl.bottom_radius = 0.045
		cyl.height = 0.22
		var mi := MeshInstance3D.new()
		mi.mesh = cyl
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.85, 0.25)
		mi.material_override = mat
		holder.add_child(mi)
		
	return holder


## Mouthwash: one 3D mouthwash flask model (level 1, 2, or 3, spins & hovers)
func _create_mouthwash_item() -> Node3D:
	var holder := Node3D.new()
	holder.name = "MouthwashItem"
	
	var mw_path := _get_mouthwash_model_path()
	var mw_scene := get_cached_scene(mw_path)
	if mw_scene == null:
		mw_scene = get_cached_scene("res://assets/candy_crusade/models/mouthwash_blast.glb")
		
	if mw_scene != null:
		var mw_inst := mw_scene.instantiate() as Node3D
		var game = get_node_or_null("/root/Game")
		if game != null and game.has_method("apply_model_materials"):
			game.apply_model_materials(mw_inst, mw_path)
		holder.add_child(mw_inst)
		_align_model_upright(mw_inst)
		_normalize_and_center_model(mw_inst, 0.32)
	else:
		var sph := SphereMesh.new()
		sph.radius = 0.065
		sph.height = 0.13
		var mi := MeshInstance3D.new()
		mi.mesh = sph
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.75, 0.4, 1.0)
		mi.material_override = mat
		holder.add_child(mi)
		
	return holder


static var _cached_textures: Dictionary = {}

static func get_cached_texture(path: String) -> Texture2D:
	if path == "":
		return null
	if not _cached_textures.has(path):
		if ResourceLoader.exists(path):
			_cached_textures[path] = load(path)
	return _cached_textures.get(path)


## Floss: one 2D floss item (Sprite3D billboard, bounces up and down in size)
func _create_floss_item() -> Node3D:
	var holder := Node3D.new()
	holder.name = "FlossItem"
	
	var floss_path := _get_floss_texture_path()
	var tex: Texture2D = get_cached_texture(floss_path)
	if tex == null:
		tex = get_cached_texture("res://assets/candy_crusade/models/level1flosstring.png")
		
	if tex != null:
		var spr := Sprite3D.new()
		spr.texture = tex
		spr.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		spr.no_depth_test = false
		spr.render_priority = 14
		
		# Auto-size to ~0.34m visual height
		var img_h: float = float(tex.get_height())
		if img_h > 0.0:
			spr.pixel_size = 0.34 / img_h
		else:
			spr.pixel_size = 0.00085
			
		holder.add_child(spr)
	else:
		var qm := QuadMesh.new()
		qm.size = Vector2(0.30, 0.30)
		var mi := MeshInstance3D.new()
		mi.mesh = qm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.9, 0.95, 1.0)
		mi.material_override = mat
		holder.add_child(mi)
		
	return holder


func _create_level_badge_3d(lvl: int, _col: Color) -> Node3D:
	var badge_root := Node3D.new()
	badge_root.name = "LevelBadge3D"
	
	# Little backing quad pill / plate for contrast
	var bg := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.20, 0.09)
	bg.mesh = qm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.no_depth_test = true
	mat.render_priority = 15
	mat.albedo_color = Color(0.04, 0.08, 0.18, 0.88)
	bg.material_override = mat
	badge_root.add_child(bg)
	
	# Foreground Label3D: "LVL 1", "LVL 2", "BUBBLE"
	var lbl := Label3D.new()
	lbl.name = "BadgeLabel"
	if lvl >= 3:
		lbl.text = "BUBBLE"
		lbl.font_size = 22
		qm.size = Vector2(0.24, 0.09)
	else:
		lbl.text = "LVL %d" % lvl
		lbl.font_size = 26
	lbl.outline_size = 6
	lbl.outline_modulate = Color(0.02, 0.04, 0.10, 1.0)
	lbl.modulate = Color(1.0, 0.94, 0.35)
	lbl.pixel_size = 0.0035
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.render_priority = 16
	badge_root.add_child(lbl)
	
	return badge_root


func _get_bullet_model_path() -> String:
	var lvl := _get_pistol_level()
	var path := "res://assets/candy_crusade/models/level%dpistolbullet.glb" % lvl
	if ResourceLoader.exists(path):
		return path
	return "res://assets/candy_crusade/models/level1pistolbullet.glb"


func _get_pistol_level() -> int:
	var game = get_node_or_null("/root/Game")
	var lvl: int = 1
	if game != null and "pistol_level" in game:
		lvl = clampi(int(game.get("pistol_level")), 1, 3)
	var bridge = get_node_or_null("/root/GameBridge")
	if bridge != null and bridge.has_method("get_weapon_level"):
		var b_lvl: int = int(bridge.get_weapon_level("paste"))
		if b_lvl <= 0:
			b_lvl = int(bridge.get_weapon_level("pistol"))
		if b_lvl > 0:
			lvl = clampi(b_lvl, 1, 3)
	return lvl


func _get_brush_level() -> int:
	var game = get_node_or_null("/root/Game")
	var lvl: int = 1
	if game != null and "boomerang_level" in game:
		lvl = clampi(int(game.get("boomerang_level")), 1, 3)
	elif game != null and "brush_level" in game:
		lvl = clampi(int(game.get("brush_level")), 1, 3)
	var bridge = get_node_or_null("/root/GameBridge")
	if bridge != null and bridge.has_method("get_weapon_level"):
		var b_lvl: int = int(bridge.get_weapon_level("brush"))
		if b_lvl <= 0:
			b_lvl = int(bridge.get_weapon_level("boomerang"))
		if b_lvl > 0:
			lvl = clampi(b_lvl, 1, 3)
	return lvl


func _get_battery_model_path() -> String:
	var lvl := _get_brush_level()
	if lvl >= 3 and ResourceLoader.exists("res://assets/candy_crusade/models/Level3BrushBattery.glb"):
		return "res://assets/candy_crusade/models/Level3BrushBattery.glb"
	return "res://assets/candy_crusade/models/Level2BrushBattery.glb"


func _get_mouthwash_level() -> int:
	var game = get_node_or_null("/root/Game")
	var lvl: int = 1
	if game != null and "grenade_level" in game:
		lvl = clampi(int(game.get("grenade_level")), 1, 3)
	elif game != null and "wash_level" in game:
		lvl = clampi(int(game.get("wash_level")), 1, 3)
	var bridge = get_node_or_null("/root/GameBridge")
	if bridge != null and bridge.has_method("get_weapon_level"):
		var b_lvl: int = int(bridge.get_weapon_level("wash"))
		if b_lvl <= 0:
			b_lvl = int(bridge.get_weapon_level("grenade"))
		if b_lvl > 0:
			lvl = clampi(b_lvl, 1, 3)
	return lvl


func _get_mouthwash_model_path() -> String:
	var lvl := _get_mouthwash_level()
	if lvl == 2 and ResourceLoader.exists("res://assets/candy_crusade/models/MWashGold2.glb"):
		return "res://assets/candy_crusade/models/MWashGold2.glb"
	elif lvl >= 3 and ResourceLoader.exists("res://assets/candy_crusade/models/MWashBubble3.glb"):
		return "res://assets/candy_crusade/models/MWashBubble3.glb"
	elif ResourceLoader.exists("res://assets/candy_crusade/models/mouthwash_blast.glb"):
		return "res://assets/candy_crusade/models/mouthwash_blast.glb"
	return "res://assets/candy_crusade/models/mouthwash_blast.glb"


func _get_floss_level() -> int:
	var game = get_node_or_null("/root/Game")
	var lvl: int = 1
	if game != null and "floss_level" in game:
		lvl = clampi(int(game.get("floss_level")), 1, 3)
	elif game != null and "lasso_level" in game:
		lvl = clampi(int(game.get("lasso_level")), 1, 3)
	var bridge = get_node_or_null("/root/GameBridge")
	if bridge != null and bridge.has_method("get_weapon_level"):
		var b_lvl: int = int(bridge.get_weapon_level("floss"))
		if b_lvl <= 0:
			b_lvl = int(bridge.get_weapon_level("lasso"))
		if b_lvl > 0:
			lvl = clampi(b_lvl, 1, 3)
	return lvl


func _get_floss_texture_path() -> String:
	var lvl := _get_floss_level()
	var path := "res://assets/candy_crusade/models/level%dflosstring.png" % lvl
	if ResourceLoader.exists(path) or FileAccess.file_exists(path):
		return path
	return "res://assets/candy_crusade/models/level1flosstring.png"


func _spawn_floating_loot_text(text: String, col: Color, at_pos: Vector3 = Vector3.ZERO, cam: Camera3D = null) -> void:
	var lbl := Label3D.new()
	lbl.text = text
	lbl.font_size = 32
	lbl.outline_size = 8
	lbl.outline_modulate = Color(0.04, 0.08, 0.16, 0.95)
	lbl.modulate = col
	lbl.pixel_size = 0.0040
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.render_priority = 20
	
	get_tree().current_scene.add_child(lbl)
	var spawn_pos := at_pos
	if spawn_pos == Vector3.ZERO:
		spawn_pos = global_position + Vector3(0, 1.05, 0)
	else:
		var up_vec := Vector3.UP
		if cam != null and is_instance_valid(cam):
			up_vec = cam.global_transform.basis.y.normalized()
		spawn_pos += up_vec * 0.28
	lbl.global_position = spawn_pos
	
	var move_up := Vector3.UP
	if cam != null and is_instance_valid(cam):
		move_up = cam.global_transform.basis.y.normalized()
		
	lbl.scale = Vector3(0.5, 0.5, 0.5)
	var tw := lbl.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "global_position", spawn_pos + move_up * 0.22, 2.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.45).set_delay(2.45)
	tw.chain().tween_callback(lbl.queue_free)


static func spawn_foreground_sparkles(pos: Vector3, tree: SceneTree) -> void:
	if tree == null or tree.current_scene == null:
		return
	var burst := CPUParticles3D.new()
	burst.amount = 26
	burst.lifetime = 0.50
	burst.one_shot = true
	burst.explosiveness = 0.92
	
	var sm := SphereMesh.new()
	sm.radius = 0.018
	sm.height = 0.036
	burst.mesh = sm
	
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(1.0, 0.95, 0.45, 0.95)
	burst.material_override = mat
	
	burst.direction = Vector3(0, 1, 0)
	burst.spread = 180.0
	burst.initial_velocity_min = 0.35
	burst.initial_velocity_max = 1.05
	burst.gravity = Vector3(0, -0.7, 0)
	burst.scale_amount_min = 0.10
	burst.scale_amount_max = 0.25
	
	tree.current_scene.add_child(burst)
	burst.global_position = pos
	tree.create_timer(0.65).timeout.connect(burst.queue_free)


static func start_loot_fade_out(root: Node3D, duration: float, on_complete: Callable) -> void:
	if root == null or not is_instance_valid(root):
		if on_complete.is_valid():
			on_complete.call()
		return

	var mats: Array[StandardMaterial3D] = []
	var sprs: Array[Sprite3D] = []
	
	var nodes_to_check: Array[Node] = [root]
	while not nodes_to_check.is_empty():
		var n: Node = nodes_to_check.pop_back()
		for child in n.get_children():
			nodes_to_check.push_back(child)
			
		if n is Sprite3D:
			sprs.append(n as Sprite3D)
		elif n is MeshInstance3D:
			var mi := n as MeshInstance3D
			if mi.material_override != null and mi.material_override is StandardMaterial3D:
				var sm := (mi.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
				sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				mi.material_override = sm
				mats.append(sm)
			elif mi.mesh != null:
				for s_idx in range(mi.mesh.get_surface_count()):
					var surf_mat := mi.get_surface_override_material(s_idx)
					if surf_mat == null:
						surf_mat = mi.mesh.surface_get_material(s_idx)
					if surf_mat != null and surf_mat is StandardMaterial3D:
						var sm := (surf_mat as StandardMaterial3D).duplicate() as StandardMaterial3D
						sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
						mi.set_surface_override_material(s_idx, sm)
						mats.append(sm)
					else:
						var sm := StandardMaterial3D.new()
						sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
						mi.set_surface_override_material(s_idx, sm)
						mats.append(sm)
			else:
				var sm := StandardMaterial3D.new()
				sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				mi.material_override = sm
				mats.append(sm)

	var tw := root.create_tween()
	tw.set_parallel(true)
	tw.tween_method(func(alpha: float):
		for sm in mats:
			if is_instance_valid(sm):
				sm.albedo_color.a = alpha
		for spr in sprs:
			if is_instance_valid(spr):
				spr.modulate.a = alpha
	, 1.0, 0.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(root, "scale", Vector3.ZERO, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	if on_complete.is_valid():
		tw.chain().tween_callback(on_complete)


