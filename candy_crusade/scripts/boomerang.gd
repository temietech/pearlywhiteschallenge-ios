extends CharacterBody3D
class_name Boomerang

signal returned(boomerang: Node3D)

## Toothbrush boomerang: flies out flat to the swipe end point while spinning
## horizontally around the world Y axis, then instantly reverses on its FIRST
## outward collision. The return leg is a pass-through: collisions are disabled
## and it translates manually, damaging every enemy it flies through exactly
## once until it frees itself near the thrower (or after a lifetime). Level-3
## boomerangs shove minions on every hit; a killing blow always knocks the body
## back before its death burst.

const SPEED := 22.0
const END_REACH_DISTANCE := 1.5
const OUTBOUND_FALLBACK_TIME := 2.2
const LIFETIME := 4.0
const DAMAGE := 1
const RETURN_DISTANCE := 0.4
const SPIN_SPEED := 40.0
const HOMING_FACTOR := 5.0
## Pass-through hit radius on the return leg (planar XZ distance from the
## boomerang to a minion center), matching roughly the outward physical hit
## envelope so the toothbrush damages minions it sweeps through.
const PASS_HIT_RADIUS := 0.9
const KNOCK_HIT_STRENGTH := 6.0
const KNOCK_KILL_STRENGTH := 10.0

var weapon_level := 1
var max_lifetime := 3.0
var _pivot: Node3D

var _age := 0.0
var _velocity := Vector3.ZERO
var _end_point := Vector3.ZERO
var _return_target := Vector3.ZERO
var _returning := false
var _chain_hit_count: int = 0
const MAX_CHAIN_HITS: int = 3
var _current_chain_target: Node3D = null
## Every enemy that has already taken damage this flight (the outward first hit
## or any return pass-through) is kept here so each minion is hit at most once.
var _damaged := {}

@onready var _mesh: Node3D = $Model


func _ready() -> void:
	collision_mask = 2 # Layer 2: Enemies only (no ground terrain collisions)
	_pivot = Node3D.new()
	_pivot.name = "Pivot"
	add_child(_pivot)
	var existing_model = get_node_or_null("Model")
	if existing_model != null:
		existing_model.reparent(_pivot)
		_mesh = existing_model
	_apply_model_for_level()


func _apply_model_for_level() -> void:
	var game = get_node_or_null("/root/Game")
	weapon_level = 1
	if game != null:
		weapon_level = clampi(int(game.get("boomerang_level")), 1, 3)
	max_lifetime = 3.0 if weapon_level == 1 else 6.0
	
	var model_path := ""
	if game != null and game.has_method("get_weapon_model_path"):
		model_path = game.get_weapon_model_path("boomerang", weapon_level)
	elif weapon_level == 2:
		model_path = "res://assets/candy_crusade/models/Goldbrushlvl2.glb"
	elif weapon_level == 3:
		model_path = "res://assets/candy_crusade/models/BubbleBrush.glb"
	else:
		model_path = "res://assets/candy_crusade/models/brush_boomerang.glb"
	
	if model_path != "" and (ResourceLoader.exists(model_path) or FileAccess.file_exists(model_path)):
		var scene = load(model_path)
		if scene != null:
			var current_model = _pivot.get_node_or_null("Model")
			if current_model != null:
				current_model.name = "OldModel"
				current_model.queue_free()
			var new_model = scene.instantiate() as Node3D
			new_model.name = "Model"
			new_model.rotation = Vector3(-1.5708, 0, 0)
			new_model.scale = Vector3(0.35, 0.35, 0.35)
			if game != null and game.has_method("apply_model_materials"):
				game.apply_model_materials(new_model, model_path)
			_pivot.add_child(new_model)
			_mesh = new_model


func setup(end_point: Vector3, return_target: Vector3) -> void:
	_end_point = Vector3(end_point.x, global_position.y, end_point.z)
	_return_target = Vector3(return_target.x, global_position.y, return_target.z)
	var outbound := _end_point - global_position
	outbound.y = 0.0
	if outbound.length_squared() >= 0.0001:
		_velocity = outbound.normalized() * SPEED
	else:
		_velocity = Vector3(0, 0, -SPEED)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= max_lifetime:
		returned.emit(self)
		queue_free()
		return
	if _pivot != null:
		_pivot.rotate_y(SPIN_SPEED * delta)

	if _returning:
		_physics_return(delta)
		return
	_physics_outbound(delta)


func _physics_outbound(delta: float) -> void:
	# Level 3 Chain homing towards current chain target
	if weapon_level >= 3 and _current_chain_target != null and is_instance_valid(_current_chain_target):
		if not _current_chain_target.get("_dead") and not _current_chain_target.is_queued_for_deletion():
			var to_target := _current_chain_target.global_position - global_position
			to_target.y = 0.0
			if to_target.length_squared() > 0.001:
				var target_vel := to_target.normalized() * (SPEED * 1.35)
				_velocity = _velocity.lerp(target_vel, clampf(14.0 * delta, 0.0, 1.0))
		else:
			_current_chain_target = _find_next_chain_target()
			if _current_chain_target == null:
				_begin_return_leg()
				return

	var dist_to_end := Vector2(global_position.x - _end_point.x, global_position.z - _end_point.z).length()
	var reached_end := dist_to_end <= END_REACH_DISTANCE
	if (reached_end and _current_chain_target == null) or _age >= OUTBOUND_FALLBACK_TIME:
		if weapon_level >= 3 and _chain_hit_count == 0:
			_current_chain_target = _find_next_chain_target()
			if _current_chain_target == null:
				_begin_return_leg()
				return
		else:
			_begin_return_leg()
			return
	
	# Deep cave threshold: bounce back immediately if traveling deep inside the cave
	if global_position.z <= -13.5:
		_begin_return_leg(Vector3(0, 0, 1))
		return

	var hit := move_and_collide(_velocity * delta)
	if hit:
		var body := hit.get_collider()
		_on_outbound_hit(body, hit.get_normal())
		return

	# Proximity guarantee on outbound leg as well
	var targets: Array = get_tree().get_nodes_in_group("minions") + get_tree().get_nodes_in_group("bosses")
	for target in targets:
		if target is Node3D and not _damaged.has(target) and not target.get("_dead") and not target.is_queued_for_deletion():
			var t_node := target as Node3D
			var to_target_node := t_node.global_position - global_position
			to_target_node.y = 0.0
			var hit_radius := PASS_HIT_RADIUS * 1.5 if target.is_in_group("bosses") else PASS_HIT_RADIUS
			if to_target_node.length() <= hit_radius:
				_on_outbound_hit(target)
				return


func _on_outbound_hit(target: Node, hit_normal: Vector3 = Vector3.ZERO) -> void:
	_damage_enemy(target, false)
	
	if weapon_level >= 3:
		_chain_hit_count += 1
		if _chain_hit_count < MAX_CHAIN_HITS:
			_current_chain_target = _find_next_chain_target()
			if _current_chain_target != null:
				var to_next := _current_chain_target.global_position - global_position
				to_next.y = 0.0
				_velocity = to_next.normalized() * (SPEED * 1.35)
				return
		# Finished chain hits or no more alive enemies
		_begin_return_leg(hit_normal)
	else:
		_begin_return_leg(hit_normal)


func _find_next_chain_target() -> Node3D:
	var candidates: Array = get_tree().get_nodes_in_group("minions") + get_tree().get_nodes_in_group("bosses")
	var closest: Node3D = null
	var min_dist: float = 999.0
	for candidate in candidates:
		if candidate is Node3D and not _damaged.has(candidate) and not candidate.get("_dead") and not candidate.is_queued_for_deletion():
			var d := global_position.distance_to((candidate as Node3D).global_position)
			if d < min_dist:
				min_dist = d
				closest = candidate as Node3D
	return closest


func _physics_return(delta: float) -> void:
	var to_target := _return_target - global_position
	to_target.y = 0.0
	# Smoothly finish return when reaching within 1m of thrower or crossing thrower plane
	if to_target.length() <= 1.0 or global_position.z >= _return_target.z - 0.2:
		returned.emit(self)
		queue_free()
		return
	# Return leg: smooth homing back to the thrower without oscillating
	var target_velocity := to_target.normalized() * SPEED
	_velocity = _velocity.lerp(target_velocity, clampf(HOMING_FACTOR * delta, 0.0, 1.0))
	_velocity.y = 0.0
	# Pass-through: translate manually and damage by distance; the boomerang is
	# not stopped by anything on the way back.
	global_position += _velocity * delta
	
	var targets: Array = get_tree().get_nodes_in_group("minions") + get_tree().get_nodes_in_group("bosses")
	for target in targets:
		if target is Node3D and not _damaged.has(target) and not target.get("_dead") and not target.is_queued_for_deletion():
			var t_node := target as Node3D
			var to_target_node := t_node.global_position - global_position
			to_target_node.y = 0.0
			var hit_radius := PASS_HIT_RADIUS * 1.5 if target.is_in_group("bosses") else PASS_HIT_RADIUS
			if to_target_node.length() <= hit_radius:
				# Return leg = boomerang comes back from behind enemies → hits their BACK (from_behind = true)
				_damage_enemy(target, true)


## Switches to the return leg: collision shape off so nothing blocks the
## pass-through, and the velocity flipped smoothly toward the thrower.
func _begin_return_leg(collision_normal: Vector3 = Vector3.ZERO) -> void:
	if _returning:
		return
	_returning = true
	_current_chain_target = null
	var collision := get_node_or_null("Collision")
	if collision != null:
		collision.set_deferred("disabled", true)
	
	if collision_normal.length_squared() > 0.01:
		_spawn_bounce_sparks(global_position, collision_normal)
	
	var back := _return_target - global_position
	back.y = 0.0
	if back.length_squared() > 0.0001:
		_velocity = back.normalized() * SPEED


func _spawn_bounce_sparks(pos: Vector3, normal: Vector3) -> void:
	var burst := CPUParticles3D.new()
	burst.amount = 10
	burst.lifetime = 0.35
	burst.one_shot = true
	burst.explosiveness = 0.95
	var sm := SphereMesh.new()
	sm.radius = 0.04
	sm.height = 0.08
	burst.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.9, 0.45) # Crisp golden spark
	burst.material_override = mat
	burst.direction = normal
	burst.spread = 70.0
	burst.initial_velocity_min = 2.0
	burst.initial_velocity_max = 4.5
	if get_parent() != null:
		get_parent().add_child(burst)
	else:
		get_tree().current_scene.add_child(burst)
	burst.global_position = pos
	get_tree().create_timer(0.5).timeout.connect(burst.queue_free)


func _spawn_tiny_pieces_explosion(pos: Vector3) -> void:
	var burst := CPUParticles3D.new()
	burst.amount = 45
	burst.lifetime = 0.65
	burst.one_shot = true
	burst.explosiveness = 0.98
	
	var sm := SphereMesh.new()
	sm.radius = 0.022
	sm.height = 0.044
	burst.mesh = sm
	
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.4, 0.8) # Vibrant candy pieces
	burst.material_override = mat
	
	burst.direction = Vector3(0, 1, 0)
	burst.spread = 180.0
	burst.initial_velocity_min = 3.5
	burst.initial_velocity_max = 7.5
	burst.gravity = Vector3(0, -9.8, 0)
	burst.scale_amount_min = 0.08
	burst.scale_amount_max = 0.32
	
	if get_parent() != null:
		get_parent().add_child(burst)
	else:
		get_tree().current_scene.add_child(burst)
	burst.global_position = pos + Vector3(0, 0.25, 0)
	get_tree().create_timer(0.8).timeout.connect(burst.queue_free)


func _calculate_damage() -> int:
	match weapon_level:
		1: return 1
		2: return 3
		3: return 10
		_: return 1


## Damages a minion once (first hit only) and applies the knockback rules: a
## hit that will kill knocks the minion back so the visible body tosses before
## the burst; level-3 boomerangs shove on every hit. Returns true when damage
## was actually dealt.
func _damage_enemy(body: Node, from_behind: bool = false) -> bool:
	if body == null or not is_instance_valid(body) or body.is_queued_for_deletion() or body.get("_dead") == true:
		return false
	if not body.has_method("take_damage"):
		return false
	if _damaged.has(body):
		return false
	_damaged[body] = true
	var remaining: float = 999.0
	if "health" in body:
		remaining = float(body.get("health"))
	
	var dmg: float = _calculate_damage()
	var will_kill := remaining <= dmg
	
	if weapon_level >= 3 and body is Node3D:
		_spawn_tiny_pieces_explosion((body as Node3D).global_position)
		
	# Pass from_behind so minion knows which way to tilt
	body.call("take_damage", dmg, from_behind)
	if body.has_method("knockback") and not from_behind:
		var away := _velocity
		away.y = 0.0
		if away.length_squared() > 0.0001:
			var dir := away.normalized()
			if will_kill:
				dir.y = 0.5
				dir = dir.normalized()
				body.knockback(dir, 16.0)
			else:
				body.knockback(dir, 8.0)
	return true
