extends RigidBody3D
class_name Grenade

## Mouthwash grenade: lobbed with gravity along an arched trajectory.
## If it collides with an enemy character (minion or boss) along its flight path,
## it immediately detonates at the collision point. Otherwise, it detonates
## upon reaching the target destination or floor contact. The blast damages
## every enemy inside its radius with an expanding visual shock wave.

const EXPLOSION_RADIUS := 1.1
const DAMAGE := 3
const FUSE := 2.0
const WAVE_SCALE_TIME := 0.3

signal exploded_at(pos: Vector3)

var _exploded := false
var _age := 0.0
var weapon_level := 1
var explosion_radius := 1.1

var _is_trajectory_flight := false
var _start_pos := Vector3.ZERO
var _launch_vel := Vector3.ZERO
var _target_pos := Vector3.ZERO
var _flight_duration := 1.0
var _flight_elapsed := 0.0
var _gravity := 9.8


func setup_trajectory(start_pos: Vector3, impulse: Vector3, target_pos: Vector3, duration: float, gravity: float = 9.8) -> void:
	freeze = true
	_is_trajectory_flight = true
	_start_pos = start_pos
	_launch_vel = impulse
	_target_pos = target_pos
	_flight_duration = maxf(duration, 0.05)
	_flight_elapsed = 0.0
	_gravity = gravity
	global_position = start_pos


func setup(impulse: Vector3) -> void:
	apply_central_impulse(impulse)
	angular_velocity = Vector3(3.0, 1.0, 2.0)


func _ready() -> void:
	collision_mask = 1 | 2
	body_entered.connect(_on_body_entered)
	_apply_model_for_level()


func _apply_model_for_level() -> void:
	var game = get_node_or_null("/root/Game")
	weapon_level = 1
	if game != null:
		weapon_level = clampi(int(game.get("grenade_level")), 1, 3)
	
	match weapon_level:
		1: explosion_radius = 1.1
		2: explosion_radius = 2.0
		3: explosion_radius = 3.2
	
	var model_path := ""
	if game != null and game.has_method("get_weapon_model_path"):
		model_path = game.get_weapon_model_path("grenade", weapon_level)
	elif weapon_level == 2:
		model_path = "res://assets/candy_crusade/models/MWashGold2.glb"
	elif weapon_level == 3:
		model_path = "res://assets/candy_crusade/models/MWashBubble3.glb"
	else:
		model_path = "res://assets/candy_crusade/models/mouthwash_blast.glb"
	
	if model_path != "" and (ResourceLoader.exists(model_path) or FileAccess.file_exists(model_path)):
		var scene = load(model_path)
		if scene != null:
			var current_model = get_node_or_null("Model")
			if current_model != null:
				current_model.name = "OldModel"
				current_model.queue_free()
			var new_model = scene.instantiate() as Node3D
			new_model.name = "Model"
			new_model.scale = Vector3(0.15, 0.15, 0.15)
			add_child(new_model)


func _physics_process(delta: float) -> void:
	if _exploded:
		return
	if _is_trajectory_flight:
		var prev_p := global_position
		_flight_elapsed += delta
		var t := _flight_elapsed
		var target_reached := (t >= _flight_duration)
		var next_p := _target_pos if target_reached else _start_pos + _launch_vel * t + 0.5 * Vector3(0, -_gravity, 0) * t * t

		# Check if the mouthwash bottle collided with any enemy character along the path from prev_p to next_p
		var hit_info := _check_character_collision(prev_p, next_p)
		if not hit_info.is_empty():
			global_position = hit_info.get("position", next_p)
			var hit_collider = hit_info.get("collider")
			explode(hit_collider)
			return

		global_position = next_p
		rotate_object_local(Vector3(1.0, 0.4, 0.2).normalized(), delta * 8.5)

		if target_reached:
			explode()
			return
	else:
		_age += delta
		if _age >= FUSE:
			explode()


func _check_character_collision(from_p: Vector3, to_p: Vector3) -> Dictionary:
	var space_state := get_world_3d().direct_space_state
	if space_state != null:
		# 1. Physics raycast along flight trajectory
		var ray_query := PhysicsRayQueryParameters3D.create(from_p, to_p)
		ray_query.collision_mask = 2 # Layer 2 = enemies (minions, bosses)
		ray_query.collide_with_bodies = true
		ray_query.collide_with_areas = false
		ray_query.exclude = [get_rid()]
		var ray_hit := space_state.intersect_ray(ray_query)
		if not ray_hit.is_empty():
			var collider = ray_hit.get("collider")
			if collider != null and collider.has_method("take_damage") and not collider.get("_dead"):
				return {"position": ray_hit.get("position", to_p), "collider": collider}

		# 2. Physics sphere cast (accounting for bottle physical volume)
		var shape_query := PhysicsShapeQueryParameters3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = 0.20
		shape_query.shape = sphere
		shape_query.collision_mask = 2
		shape_query.collide_with_bodies = true
		shape_query.collide_with_areas = false
		shape_query.exclude = [get_rid()]
		shape_query.transform = Transform3D(Basis(), from_p)
		shape_query.motion = to_p - from_p
		var motion_res := space_state.cast_motion(shape_query)
		if motion_res.size() == 2 and motion_res[0] < 1.0:
			var hit_pos: Vector3 = from_p + (to_p - from_p) * motion_res[0]
			shape_query.transform = Transform3D(Basis(), from_p + (to_p - from_p) * motion_res[1])
			var hits := space_state.intersect_shape(shape_query, 2)
			for h in hits:
				var col = h.get("collider")
				if col != null and col.has_method("take_damage") and not col.get("_dead"):
					return {"position": hit_pos, "collider": col}
			return {"position": hit_pos, "collider": null}

	# 3. Geometric line-segment to character proximity check against active enemies
	var seg := to_p - from_p
	var seg_len_sq := seg.length_squared()
	var candidates: Array = get_tree().get_nodes_in_group("minions") + get_tree().get_nodes_in_group("bosses")
	var closest_hit := {}
	var closest_fraction := 2.0

	for candidate in candidates:
		if not is_instance_valid(candidate) or not (candidate is Node3D):
			continue
		if candidate.get("_dead") == true:
			continue
		var enemy := candidate as Node3D
		var is_boss: bool = enemy.is_in_group("bosses") or enemy.name == "BlueCandor" or enemy.name == "Boss"
		var center_y := 0.9 if is_boss else 0.38
		var hit_r := 1.05 if is_boss else 0.60
		var center := enemy.global_position + Vector3(0, center_y, 0)

		var u := 0.0
		if seg_len_sq > 0.0001:
			u = clampf((center - from_p).dot(seg) / seg_len_sq, 0.0, 1.0)
		var proj := from_p + seg * u
		var dist := proj.distance_to(center)
		if dist <= hit_r:
			if u < closest_fraction:
				closest_fraction = u
				closest_hit = {"position": proj, "collider": enemy}

	if not closest_hit.is_empty():
		return closest_hit

	return {}


func _on_body_entered(body: Node) -> void:
	if not _is_trajectory_flight:
		explode(body if (body != null and body.has_method("take_damage")) else null)


func explode(direct_target: Node = null) -> void:
	if _exploded:
		return
	_exploded = true
	_is_trajectory_flight = false
	exploded_at.emit(global_position)
	# Hold the grenade at its impact point while the blast plays out.
	set_deferred("freeze", true)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO

	# Level 3: Heavy camera shake
	if weapon_level >= 3:
		var player = get_tree().get_first_node_in_group("player")
		if player != null:
			player.set("_shake_time", 0.65)

	# The bottle itself is gone as soon as the magical blast starts; only the
	# particles and expanding wave remain visible.
	var model_node := get_node_or_null("Model") as Node3D
	if model_node != null:
		model_node.visible = false
	for node in find_children("*", "MeshInstance3D", true, false):
		if node.name != "Wave":
			(node as MeshInstance3D).visible = false
	var collision := get_node_or_null("Collision") as CollisionShape3D
	if collision != null:
		collision.set_deferred("disabled", true)
	var burst := $Burst as CPUParticles3D
	if burst != null:
		burst.restart()
		burst.emitting = true
	_start_blast_wave()
	var area := _make_blast_area()

	var damaged_targets: Array[Node] = []

	# Direct hit target takes damage first
	if direct_target != null and is_instance_valid(direct_target):
		_apply_damage_to_body(direct_target)
		damaged_targets.append(direct_target)

	# Direct proximity check to ensure living enemies within explosion_radius get hit
	var all_enemies: Array = get_tree().get_nodes_in_group("minions") + get_tree().get_nodes_in_group("bosses")
	for enemy in all_enemies:
		if is_instance_valid(enemy) and enemy is Node3D and not damaged_targets.has(enemy):
			if enemy.get("_dead") == true:
				continue
			var e_node := enemy as Node3D
			var is_boss: bool = e_node.is_in_group("bosses") or e_node.name == "BlueCandor" or e_node.name == "Boss"
			var center_y := 0.9 if is_boss else 0.38
			var e_center := e_node.global_position + Vector3(0, center_y, 0)
			var effective_r := explosion_radius + (0.9 if is_boss else 0.45)
			if global_position.distance_to(e_center) <= effective_r:
				_apply_damage_to_body(enemy)
				damaged_targets.append(enemy)

	# Give physics space two frames to register Area3D overlaps
	await get_tree().physics_frame
	await get_tree().physics_frame

	if is_instance_valid(area):
		for body in area.get_overlapping_bodies():
			if body != null and not damaged_targets.has(body):
				_apply_damage_to_body(body)
				damaged_targets.append(body)

	# Secondary Chill Effect: ONLY Level 3 Bubble Mouthwash chills & freezes other unaffected minions across the scene
	if weapon_level >= 3:
		for enemy in get_tree().get_nodes_in_group("minions"):
			if is_instance_valid(enemy) and not damaged_targets.has(enemy):
				if enemy.get("_dead") == true:
					continue
				# 1. Take a little damage (1.0 damage)
				if enemy.has_method("take_damage"):
					enemy.call("take_damage", 1.0)
				# 2. Freeze for a bit (3.0s) with hit model expression
				if is_instance_valid(enemy) and not enemy.get("_dead"):
					if enemy.has_method("freeze"):
						enemy.call("freeze", 3.0)

	await get_tree().create_timer(0.7).timeout
	queue_free()


func _calculate_damage() -> int:
	match weapon_level:
		1: return 10
		2: return 20
		3: return 40
		_: return 10


func _apply_damage_to_body(body: Node) -> void:
	if body == null or not is_instance_valid(body) or not body.has_method("take_damage"):
		return
	if body.get("_dead") == true:
		return
	var dmg: float = _calculate_damage()
	body.call("take_damage", dmg)
	# Level 3 Bubble Wash: 5.0s freeze / immobilize to surviving enemies in blast
	if weapon_level >= 3 and body.has_method("freeze") and not body.get("_dead"):
		body.call("freeze", 5.0)


func _make_blast_area() -> Area3D:
	var area := Area3D.new()
	area.name = "Blast"
	area.collision_layer = 0
	area.collision_mask = 2
	area.monitorable = false
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = explosion_radius
	shape.shape = sphere
	area.add_child(shape)
	add_child(area)
	area.global_position = global_position
	return area


func _start_blast_wave() -> void:
	var wave := get_node_or_null("Wave") as MeshInstance3D
	if wave == null:
		return
	wave.visible = true
	wave.scale = Vector3.ONE * 0.2
	var tween := create_tween()
	tween.tween_property(wave, "scale", Vector3.ONE * explosion_radius, WAVE_SCALE_TIME)
	tween.tween_callback(func() -> void:
		if is_instance_valid(wave):
			wave.visible = false
	)
