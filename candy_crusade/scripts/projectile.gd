extends CharacterBody3D
class_name Projectile

## Toothpaste blast: flies -Z (toward the horizon) at speed, damages the first
## minion it hits, and frees itself on impact or after its lifetime.

const SPEED := 18.5
const DAMAGE := 1
const LIFETIME := 3.0
## The far edge of the 36 m lane centered at z = -14 m.
const LANE_END_Z := -32.0

static var _bullet_cache: Dictionary = {}

var _velocity := Vector3.ZERO
var _age := 0.0
var weapon_level := 1
var _model_node: Node3D = null
var _trail: CPUParticles3D = null


static func get_bullet_scene(level: int) -> PackedScene:
	if not _bullet_cache.has(level):
		var path := ""
		match level:
			1: path = "res://assets/candy_crusade/models/level1pistolbullet.glb"
			2: path = "res://assets/candy_crusade/models/level2pistolbullet.glb"
			3: path = "res://assets/candy_crusade/models/level3pistolbullet.glb"
			_: path = "res://assets/candy_crusade/models/level1pistolbullet.glb"
		if ResourceLoader.exists(path):
			_bullet_cache[level] = load(path)
		elif FileAccess.file_exists(path):
			var gltf := GLTFDocument.new()
			var state := GLTFState.new()
			var err := gltf.append_from_file(path, state)
			if err == OK:
				var scene := PackedScene.new()
				var root := gltf.generate_scene(state)
				scene.pack(root)
				_bullet_cache[level] = scene
	return _bullet_cache.get(level)


func _ready() -> void:
	collision_mask = 2 # Layer 2: Enemies only (no ground collisions)


func setup(direction: Vector3, level: int = 1) -> void:
	if direction.length_squared() >= 0.001:
		_velocity = direction.normalized() * SPEED
	else:
		_velocity = Vector3(0, 0, -SPEED)
	weapon_level = level

	var bullet_scene := get_bullet_scene(level)
	if bullet_scene != null:
		var inst := bullet_scene.instantiate() as Node3D
		if inst != null:
			if has_node("Mesh"):
				$Mesh.visible = false
			inst.name = "BulletModel"
			add_child(inst)
			var game = get_node_or_null("/root/Game")
			if game != null and game.has_method("apply_model_materials"):
				var path := ""
				match level:
					1: path = "res://assets/candy_crusade/models/level1pistolbullet.glb"
					2: path = "res://assets/candy_crusade/models/level2pistolbullet.glb"
					3: path = "res://assets/candy_crusade/models/level3pistolbullet.glb"
					_: path = "res://assets/candy_crusade/models/level1pistolbullet.glb"
				game.apply_model_materials(inst, path)
			_normalize_bullet_model(inst, 0.16)
			_model_node = inst
			_orient_bullet()

	_create_comet_trail(level)


func _create_comet_trail(level: int) -> void:
	var trail := CPUParticles3D.new()
	trail.name = "CometTrail"
	trail.local_coords = false # Leaves sparkling trail in world space behind the flying bullet
	trail.amount = 36
	trail.lifetime = 0.24
	trail.explosiveness = 0.0
	trail.randomness = 0.3
	trail.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	trail.emission_sphere_radius = 0.025

	var sm := SphereMesh.new()
	sm.radius = 0.030
	sm.height = 0.060
	trail.mesh = sm

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	match level:
		1:
			mat.albedo_color = Color(0.35, 0.92, 1.0, 0.85) # Cyan fresh mint sparkle
		2:
			mat.albedo_color = Color(1.0, 0.86, 0.35, 0.85) # Golden sparkle
		3:
			mat.albedo_color = Color(0.3, 1.0, 0.85, 0.95) # Radiant aqua-bubble sparkle
		_:
			mat.albedo_color = Color(0.35, 0.92, 1.0, 0.85)
	trail.material_override = mat

	trail.gravity = Vector3(0, -0.4, 0)
	trail.scale_amount_min = 0.3
	trail.scale_amount_max = 1.0

	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	trail.scale_amount_curve = curve

	add_child(trail)
	_trail = trail


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


func _normalize_bullet_model(node: Node3D, target_length: float = 0.16) -> void:
	var box := _measure_model(node)
	# Align longest dimension with -Z (forward flight direction) so all bullet models fly oriented identically
	if box.size.y > box.size.z * 1.15 and box.size.y > box.size.x * 1.15:
		node.rotation_degrees.x = 90.0
		box = _measure_model(node)
	elif box.size.x > box.size.z * 1.15 and box.size.x > box.size.y * 1.15:
		node.rotation_degrees.y = 90.0
		box = _measure_model(node)

	var max_dim := maxf(box.size.x, maxf(box.size.y, box.size.z))
	var s := target_length / max_dim if max_dim > 0.001 else 0.04
	node.scale = Vector3(s, s, s)
	if max_dim > 0.001:
		node.position = -box.get_center() * s


func _orient_bullet() -> void:
	if _model_node == null or _velocity.length_squared() <= 0.001:
		return
	var dir := _velocity.normalized()
	var up_vec := Vector3.UP
	if abs(dir.dot(up_vec)) > 0.95:
		up_vec = Vector3.FORWARD
	_model_node.look_at(global_position + dir, up_vec)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		_detach_trail_and_free()
		return
	if global_position.z <= LANE_END_Z:
		_detach_trail_and_free()
		return
	if _velocity == Vector3.ZERO:
		return
	if _model_node != null:
		_model_node.rotate_object_local(Vector3.FORWARD, 18.0 * delta)
	var hit := move_and_collide(_velocity * delta)
	if hit:
		var body := hit.get_collider() as Node
		if body != null and body.has_method("take_damage"):
			_handle_hit(body)
		_spawn_impact_burst(global_position)
		_detach_trail_and_free()


func _spawn_impact_burst(pos: Vector3) -> void:
	var p := get_parent()
	if p == null:
		return
	var burst := CPUParticles3D.new()
	burst.amount = 14
	burst.lifetime = 0.35
	burst.one_shot = true
	burst.explosiveness = 0.9
	var sm := SphereMesh.new()
	sm.radius = 0.025
	sm.height = 0.05
	burst.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(0.4, 0.95, 1.0, 0.9) if weapon_level != 2 else Color(1.0, 0.88, 0.4, 0.9)
	burst.material_override = mat
	burst.gravity = Vector3(0, -5.0, 0)
	burst.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	burst.emission_sphere_radius = 0.06
	burst.direction = Vector3.UP
	burst.initial_velocity_min = 1.0
	burst.initial_velocity_max = 3.0
	p.add_child(burst)
	burst.global_position = pos
	get_tree().create_timer(0.5).timeout.connect(burst.queue_free)


func _detach_trail_and_free() -> void:
	if _trail != null and is_instance_valid(_trail):
		var p := get_parent()
		if p != null:
			_trail.reparent(p)
			_trail.emitting = false
			get_tree().create_timer(0.35).timeout.connect(_trail.queue_free)
			_trail = null
	queue_free()


func _calculate_damage() -> int:
	match weapon_level:
		1: return 1
		2: return 2
		3: return 5
		_: return 1


func _handle_hit(target: Node) -> void:
	var damage := _calculate_damage()
	target.call("take_damage", damage)
	
	# Level 3: Chaining Energy arcs to the next 2 closest minions
	if weapon_level >= 3 and target is Node3D:
		_chain_to_nearby_minions(target as Node3D, damage)


func _chain_to_nearby_minions(origin_target: Node3D, dmg: int = 5) -> void:
	var origin_pos: Vector3 = origin_target.global_position
	var candidates := get_tree().get_nodes_in_group("minions")
	var nearby: Array[Dictionary] = []
	
	for c in candidates:
		var m := c as Node3D
		if m == null or m == origin_target or not is_instance_valid(m):
			continue
		if m.get("_dead") == true:
			continue
		var dist: float = origin_pos.distance_to(m.global_position)
		if dist <= 10.0:
			nearby.append({"minion": m, "dist": dist})
	
	nearby.sort_custom(func(a, b): return a["dist"] < b["dist"])
	
	var chain_count = mini(2, nearby.size())
	for i in range(chain_count):
		var chained_minion: Node3D = nearby[i]["minion"]
		if is_instance_valid(chained_minion):
			_spawn_chain_beam(origin_pos + Vector3(0, 0.4, 0), chained_minion.global_position + Vector3(0, 0.4, 0))
			chained_minion.call("take_damage", dmg)


func _spawn_chain_beam(start_pos: Vector3, end_pos: Vector3) -> void:
	var container := get_parent()
	if container == null:
		return
	
	var beam := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.05
	cyl.bottom_radius = 0.05
	var dist := start_pos.distance_to(end_pos)
	cyl.height = dist
	
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.4, 0.9, 1.0, 0.9)
	beam.mesh = cyl
	beam.material_override = mat
	
	container.add_child(beam)
	beam.global_position = (start_pos + end_pos) * 0.5
	if not start_pos.is_equal_approx(end_pos):
		var dir := (end_pos - beam.global_position).normalized()
		var up := Vector3.UP
		if absf(dir.dot(Vector3.UP)) > 0.99:
			up = Vector3.FORWARD
		beam.look_at(end_pos, up)
		beam.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	
	var tw := beam.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(beam.queue_free)
