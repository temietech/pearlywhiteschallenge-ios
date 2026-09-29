extends Area3D
class_name MolarCoin

## 3D Molar Coin pickup that flies out of defeated minions or spawns on the floor.
## Tapping a coin collects it immediately without firing any pistol shots.

const MODEL_PATH := "res://assets/candy_crusade/models/molarcoin.glb"
const PurpleStars = preload("res://candy_crusade/scripts/purple_stars.gd")
const LIFETIME := 22.0

var _mesh_root: Node3D
var _coin_model: Node3D
var _collision_shape: CollisionShape3D
var _aura_particles: CPUParticles3D
var _collected := false
var _is_airborne := false
var _velocity := Vector3.ZERO
var _age := 0.0
var _base_y := 0.08

static var _cached_coin_scene: PackedScene = null
static var _has_attempted_coin_cache := false


static func get_cached_scene(path: String) -> PackedScene:
	if path == "":
		return null
	if not _has_attempted_coin_cache:
		_has_attempted_coin_cache = true
		if ResourceLoader.exists(path):
			_cached_coin_scene = load(path)
		elif FileAccess.file_exists(path):
			var gltf := GLTFDocument.new()
			var state := GLTFState.new()
			var err := gltf.append_from_file(path, state)
			if err == OK:
				var scene := PackedScene.new()
				var root := gltf.generate_scene(state)
				scene.pack(root)
				_cached_coin_scene = scene
	return _cached_coin_scene


func _ready() -> void:
	add_to_group("coins")
	collision_layer = 4 # Layer 3 / bit 4 for pickups
	collision_mask = 0
	input_ray_pickable = true
	input_event.connect(_on_input_event)
	
	_setup_models()
	_setup_collision()
	_setup_aura_particles()
	
	if not _is_airborne:
		call_deferred("_snap_to_ground")


func _setup_models() -> void:
	_mesh_root = Node3D.new()
	_mesh_root.name = "MeshRoot"
	add_child(_mesh_root)
	
	var scene := get_cached_scene(MODEL_PATH)
	if scene != null:
		_coin_model = scene.instantiate() as Node3D
		if _coin_model != null:
			_coin_model.name = "MolarCoinModel"
			_mesh_root.add_child(_coin_model)
			_normalize_and_center_model(_coin_model, 0.13)
			
			var gold_mat := StandardMaterial3D.new()
			gold_mat.albedo_color = Color(1.0, 0.82, 0.15)
			gold_mat.metallic = 0.88
			gold_mat.roughness = 0.20
			gold_mat.emission_enabled = true
			gold_mat.emission = Color(0.95, 0.72, 0.10)
			gold_mat.emission_energy_multiplier = 0.35
			_apply_gold_material_recursive(_coin_model, gold_mat)
	else:
		_build_procedural_coin()


func _apply_gold_material_recursive(node: Node, gold_mat: Material) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = gold_mat
	for child in node.get_children():
		_apply_gold_material_recursive(child, gold_mat)


func _build_procedural_coin() -> void:
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.065
	cyl.bottom_radius = 0.065
	cyl.height = 0.025
	var mi := MeshInstance3D.new()
	mi.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.25)
	mat.metallic = 0.88
	mat.roughness = 0.20
	mat.emission_enabled = true
	mat.emission = Color(0.95, 0.75, 0.10)
	mat.emission_energy_multiplier = 0.35
	mi.material_override = mat
	mi.rotation_degrees.x = 90.0
	_mesh_root.add_child(mi)


func _normalize_and_center_model(node: Node3D, target_size: float = 0.13) -> void:
	var total_box := AABB()
	var has_box := false
	for child in node.find_children("*", "VisualInstance3D", true, false):
		var vi := child as VisualInstance3D
		if vi != null and vi.visible:
			var trans := _get_relative_transform_to(vi, node)
			var aabb := trans * vi.get_aabb()
			if not has_box:
				total_box = aabb
				has_box = true
			else:
				total_box = total_box.merge(aabb)
				
	var max_dim := maxf(total_box.size.x, maxf(total_box.size.y, total_box.size.z))
	var s := target_size / max_dim if max_dim > 0.001 else target_size
	node.scale = Vector3(s, s, s)
	if max_dim > 0.001:
		node.position = Vector3(-total_box.get_center().x * s, -total_box.position.y * s, -total_box.get_center().z * s)


func _get_relative_transform_to(child: Node3D, root: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var curr: Node = child
	while curr != null and curr != root:
		if curr is Node3D:
			t = (curr as Node3D).transform * t
		curr = curr.get_parent()
	return t


func _setup_collision() -> void:
	_collision_shape = CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.35
	_collision_shape.shape = sphere
	_collision_shape.position = Vector3(0, 0.12, 0)
	add_child(_collision_shape)


func _setup_aura_particles() -> void:
	_aura_particles = CPUParticles3D.new()
	_aura_particles.name = "AuraParticles"
	_aura_particles.amount = 8
	_aura_particles.lifetime = 0.85
	_aura_particles.explosiveness = 0.0
	_aura_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_aura_particles.emission_sphere_radius = 0.16
	_aura_particles.direction = Vector3(0, 1, 0)
	_aura_particles.spread = 45.0
	_aura_particles.initial_velocity_min = 0.2
	_aura_particles.initial_velocity_max = 0.6
	_aura_particles.gravity = Vector3(0, 0.2, 0)
	_aura_particles.scale_amount_min = 0.08
	_aura_particles.scale_amount_max = 0.20
	
	var sm := SphereMesh.new()
	sm.radius = 0.012
	sm.height = 0.024
	_aura_particles.mesh = sm
	
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(1.0, 0.90, 0.35, 0.85)
	_aura_particles.material_override = mat
	
	add_child(_aura_particles)
	_aura_particles.position = Vector3(0, 0.12, 0)


func launch(start_pos: Vector3, custom_vel: Vector3 = Vector3.ZERO) -> void:
	global_position = start_pos
	_is_airborne = true
	if custom_vel != Vector3.ZERO:
		_velocity = custom_vel
	else:
		_velocity = Vector3(
			randf_range(-1.3, 1.3),
			randf_range(3.2, 4.8),
			randf_range(-1.1, 1.1)
		)


func spawn_on_floor(pos: Vector3) -> void:
	global_position = pos + Vector3(0, 0.35, 0)
	_is_airborne = false
	_base_y = pos.y + 0.16
	var tw := create_tween()
	tw.tween_property(self, "global_position:y", _base_y, 0.25).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func _on_input_event(_cam: Camera3D, event: InputEvent, _pos: Vector3, _norm: Vector3, _shape_idx: int) -> void:
	if _collected:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		collect()
	elif event is InputEventScreenTouch and event.pressed:
		get_viewport().set_input_as_handled()
		collect()


func _physics_process(delta: float) -> void:
	if _collected:
		return
		
	if _is_airborne:
		_velocity.y -= 10.5 * delta
		_velocity.x = move_toward(_velocity.x, 0.0, 0.8 * delta)
		_velocity.z = move_toward(_velocity.z, 0.0, 0.8 * delta)
		global_position += _velocity * delta
		
		if _mesh_root != null:
			_mesh_root.rotate_y(6.0 * delta)
			_mesh_root.rotate_x(3.5 * delta)
			
		if global_position.y <= _base_y:
			global_position.y = _base_y
			if _velocity.y < -1.8:
				_velocity.y = -_velocity.y * 0.42
				_velocity.x *= 0.6
				_velocity.z *= 0.6
			else:
				_is_airborne = false
				_velocity = Vector3.ZERO
				if _mesh_root != null:
					_mesh_root.rotation.x = 0.0
					_mesh_root.rotation.z = 0.0
				_snap_to_ground()
		return
		
	_age += delta
	if _age >= LIFETIME:
		_despawn()
		return
		
	if _mesh_root != null:
		_mesh_root.rotate_y(3.0 * delta)
		_mesh_root.position.y = 0.05 + sin(_age * 3.8) * 0.025
		
	if _age >= LIFETIME - 3.5:
		visible = (fmod(_age * 8.0, 1.0) > 0.3)


func _snap_to_ground() -> void:
	var space_state := get_world_3d().direct_space_state
	if space_state == null:
		return
	var from_pos := Vector3(global_position.x, global_position.y + 1.8, global_position.z)
	var to_pos := Vector3(global_position.x, global_position.y - 2.5, global_position.z)
	var query := PhysicsRayQueryParameters3D.create(from_pos, to_pos)
	query.collision_mask = 1
	var hit := space_state.intersect_ray(query)
	if hit and hit.has("position"):
		global_position.y = hit["position"].y + 0.16
		_base_y = global_position.y


func collect() -> void:
	if _collected:
		return
	_collected = true
	remove_from_group("coins")
	input_ray_pickable = false
	if _collision_shape != null:
		_collision_shape.set_deferred("disabled", true)
	if _aura_particles != null:
		_aura_particles.emitting = false
		
	# Award coin to GameBridge
	var bridge = get_node_or_null("/root/GameBridge")
	if bridge != null:
		bridge.coins_collected += 1
		bridge.coins += 1
	
	# Spawn floating +1 label
	_spawn_floating_plus_one()
	
	# Purple star burst on coin pickup
	PurpleStars.spawn_burst(global_position + Vector3(0, 0.15, 0), get_tree(), 8, 0.75)
	
	# Collection pickup zoom & fade tween
	var cam: Camera3D = get_viewport().get_camera_3d() if get_viewport() != null else null
	var target_pos := global_position + Vector3(0, 0.8, 0)
	if cam != null and is_instance_valid(cam):
		var fwd := -cam.global_transform.basis.z.normalized()
		var up := cam.global_transform.basis.y.normalized()
		target_pos = cam.global_position + fwd * 1.2 + up * 0.4
		
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "global_position", target_pos, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector3.ZERO, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(queue_free)


func _spawn_floating_plus_one() -> void:
	var lbl := Label3D.new()
	lbl.text = "+1"
	lbl.font_size = 28
	lbl.outline_size = 6
	lbl.outline_modulate = Color(0.12, 0.06, 0.0, 1.0)
	lbl.modulate = Color(1.0, 0.88, 0.25)
	lbl.pixel_size = 0.0035
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.render_priority = 22
	
	get_tree().current_scene.add_child(lbl)
	var spawn_pos := global_position + Vector3(0, 0.25, 0)
	lbl.global_position = spawn_pos
	
	var tw := lbl.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "scale", Vector3(1.2, 1.2, 1.2), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "global_position:y", spawn_pos.y + 0.35, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.25).set_delay(0.35)
	tw.chain().tween_callback(lbl.queue_free)


func _despawn() -> void:
	_collected = true
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ZERO, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)
