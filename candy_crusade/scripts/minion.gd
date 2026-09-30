extends CharacterBody3D
class_name Minion

## Sugar minion: spawns at the horizon and marches +Z toward the player turret.
## Takes toothpaste hits, flashes white, and bursts into particles when killed.
## Can be frozen in place by the floss lasso (ice tint, no movement). Boomerang
## hits can knock it: a non-lethal hit from a level-3 boomerang shoves the body
## with a decaying velocity, and a killing blow launches the visible body up and
## away in a gravity arc (upward knock Y, pulled back down by GRAVITY each
## physics frame) before the death burst plays as it falls.

signal died

const PurpleStars = preload("res://candy_crusade/scripts/purple_stars.gd")

const WALK_SPEED := 0.55
const MAX_HEALTH: float = 3.0
const REACH_Z := -0.5
## Knock velocity is removed this many m/s per second (linear decay).
const KNOCK_DECAY := 14.0
## Downward acceleration applied to the knock Y so a launched killing blow arcs
## up and falls back down instead of rolling away along the lane.
const GRAVITY := 9.8
## How long a killing blow keeps the visible body flying (rising through the
## arc, then starting to fall) before the death burst plays.
const DEATH_TOSS_TIME := 0.75
const HIT_STUN_TIME := 0.7
const DEFAULT_DEATH_LAUNCH_STRENGTH := 22.0
const DEATH_HORIZONTAL_DECAY := 2.0
const MINION_SEPARATION_RADIUS := 0.55
const MINION_SEPARATION_SPEED := 1.5
const CAVE_RUSH_SPEED := 3.6
const CAVE_EXIT_Z := -9.5
const CAVE_DECEL_END_Z := -7.6

var health: float = MAX_HEALTH
var _dead := false
var _is_cave_rushing := false
var _frozen_time := 0.0
var _knock_velocity := Vector3.ZERO
var _hit_stun_time := 0.0
var _speed_multiplier := 1.0
var _wander_amplitude := 0.0
var _wander_time := 0.0
var _wander_phase := 0.0
var _previous_wander_offset := 0.0
var _hit_from_behind := false   # true = back-hit: tilt forward, no slide
var drops_ammo := false

const HIT_MODEL_PATH := "res://assets/candy_crusade/models/BonbonMinionHit.glb"
static var _cached_minion_hit_scene: PackedScene = null
static var _has_attempted_minion_hit_cache := false

var _hit_model: Node3D
var _hit_model_timer := 0.0

@onready var _body: MeshInstance3D = $Body
@onready var _head: MeshInstance3D = $Head
@onready var _burst: CPUParticles3D = $Burst
@onready var _collision: CollisionShape3D = $Collision


var variant: String = "standard"

@export var minion_scale := 0.35

func set_minion_scale(s: float) -> void:
	minion_scale = s
	scale = Vector3(s, s, s)


func set_drops_ammo(val: bool) -> void:
	drops_ammo = val


func set_variant(v_name: String) -> void:
	variant = v_name
	var base_hp := 3
	match v_name:
		"runner":
			base_hp = 1
			_speed_multiplier = 1.75
			set_minion_scale(0.28)
		"brute":
			base_hp = 6
			_speed_multiplier = 0.65
			set_minion_scale(0.46)
		_:
			base_hp = 3
			_speed_multiplier = 1.0
			set_minion_scale(0.35)
	var bridge = get_node_or_null("/root/GameBridge")
	if bridge != null:
		base_hp = maxi(1, int(round(float(base_hp) * bridge.get_difficulty_health_mult())))
	health = base_hp


func _ready() -> void:
	add_to_group("minions")
	scale = Vector3(minion_scale, minion_scale, minion_scale)
	_setup_hit_model()
	call_deferred("_align_model_to_feet")
	call_deferred("_snap_to_ground", 0.0)


func _setup_hit_model() -> void:
	if not _has_attempted_minion_hit_cache:
		_has_attempted_minion_hit_cache = true
		if ResourceLoader.exists(HIT_MODEL_PATH):
			_cached_minion_hit_scene = load(HIT_MODEL_PATH)
		elif FileAccess.file_exists(HIT_MODEL_PATH):
			var gltf := GLTFDocument.new()
			var state := GLTFState.new()
			var err := gltf.append_from_file(HIT_MODEL_PATH, state)
			if err == OK:
				var scene := PackedScene.new()
				var root := gltf.generate_scene(state)
				scene.pack(root)
				_cached_minion_hit_scene = scene

	if _cached_minion_hit_scene != null:
		_hit_model = _cached_minion_hit_scene.instantiate() as Node3D
		if _hit_model != null:
			_hit_model.name = "HitModel"
			_hit_model.visible = false
			add_child(_hit_model)
			if has_node("Model"):
				_hit_model.transform = $Model.transform


func _show_hit_model(show_hit: bool) -> void:
	if _hit_model == null:
		return
	if has_node("Model"):
		$Model.visible = not show_hit
	_hit_model.visible = show_hit


var _model_feet_aligned := false

func _align_model_to_feet() -> void:
	if _model_feet_aligned:
		return
	if not has_node("Model"):
		return
	$Model.position.y = 0.0
	var lowest_y := INF
	for child in $Model.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		if mi and mi.mesh:
			var trans := transform.affine_inverse() * mi.global_transform
			var local_box: AABB = trans * mi.mesh.get_aabb()
			lowest_y = minf(lowest_y, local_box.position.y)
	if lowest_y < INF:
		$Model.position.y = -lowest_y + 0.08
		_model_feet_aligned = true
	if _hit_model != null and is_instance_valid(_hit_model):
		_hit_model.position = $Model.position


func _cast_ground_ray(space_state: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1
	query.exclude = [get_rid()]
	return space_state.intersect_ray(query)


var _has_snapped_to_ground := false

func _snap_to_ground(delta: float = 0.0) -> void:
	var space_state := get_world_3d().direct_space_state
	if space_state == null:
		return
	var ray_start_y := maxf(global_position.y + 1.2, 2.0)
	var ray_end_y := global_position.y - 3.5
	
	# 1. Primary check at minion's current position
	var hit := _cast_ground_ray(space_state, Vector3(global_position.x, ray_start_y, global_position.z), Vector3(global_position.x, ray_end_y, global_position.z))
	
	# 2. Fallback to lane center X = 0 if wandering near edge misses
	if not (hit and hit.has("position")) and absf(global_position.x) > 0.04:
		hit = _cast_ground_ray(space_state, Vector3(0.0, ray_start_y, global_position.z), Vector3(0.0, ray_end_y, global_position.z))
	
	# 3. Offsets for polygon seams
	if not (hit and hit.has("position")):
		hit = _cast_ground_ray(space_state, Vector3(global_position.x - 0.15, ray_start_y, global_position.z), Vector3(global_position.x - 0.15, ray_end_y, global_position.z))
	if not (hit and hit.has("position")):
		hit = _cast_ground_ray(space_state, Vector3(global_position.x + 0.15, ray_start_y, global_position.z), Vector3(global_position.x + 0.15, ray_end_y, global_position.z))
	
	if hit and hit.has("position"):
		var target_y: float = hit["position"].y
		# Walkable surface ceiling guard
		if target_y > 3.5:
			return
		if not _has_snapped_to_ground or delta <= 0.0:
			global_position.y = target_y
			_has_snapped_to_ground = true
		else:
			if target_y > global_position.y:
				# Immediate snap up on rising terrain so minion never sinks into slopes
				global_position.y = target_y
			else:
				# Snappy smooth descent on downward slopes
				global_position.y = lerpf(global_position.y, target_y, clampf(35.0 * delta, 0.0, 1.0))


func _physics_process(delta: float) -> void:
	if _dead:
		return
	
	if _hit_model != null and is_instance_valid(_hit_model) and has_node("Model"):
		_hit_model.transform = $Model.transform
		
	if _hit_model_timer > 0.0:
		_hit_model_timer = maxf(_hit_model_timer - delta, 0.0)
		if _hit_model_timer <= 0.0 and not _dead and _frozen_time <= 0.0:
			_show_hit_model(false)
	
	# Dynamically follow terrain height (hills, slopes, dips)
	_snap_to_ground(delta)
	
	# Cave rush speed: minions starting or spawning in the cave sprint out fast, then slow to normal walk
	if global_position.z < CAVE_EXIT_Z:
		_is_cave_rushing = true
	
	var current_walk_speed := WALK_SPEED * _speed_multiplier
	var wander_weight := 1.0
	var rush_tilt := 0.0
	
	if _is_cave_rushing:
		if global_position.z < CAVE_EXIT_Z:
			# Fast sprint while inside the cave
			current_walk_speed = CAVE_RUSH_SPEED * _speed_multiplier
			wander_weight = 0.0
			rush_tilt = deg_to_rad(14.0) # Energetic forward sprint lean
		elif global_position.z < CAVE_DECEL_END_Z:
			# Smoothly decelerate from sprint to normal walk speed as they emerge
			var t := (global_position.z - CAVE_EXIT_Z) / (CAVE_DECEL_END_Z - CAVE_EXIT_Z)
			current_walk_speed = lerpf(CAVE_RUSH_SPEED * _speed_multiplier, WALK_SPEED * _speed_multiplier, t)
			wander_weight = t
			rush_tilt = lerpf(deg_to_rad(14.0), 0.0, t)
		else:
			_is_cave_rushing = false
	
	var was_stunned := _hit_stun_time > 0.0
	if _hit_stun_time > 0.0:
		_hit_stun_time = maxf(_hit_stun_time - delta, 0.0)
		# Tilt direction depends on which side the hit came from:
		#   front hit → tilt back (head away from player, -X rotation)
		#   back hit  → tilt forward (head dips toward player, +X rotation)
		var tilt_target := deg_to_rad(20.0) if _hit_from_behind else deg_to_rad(-20.0)
		if has_node("Model"):
			$Model.rotation.x = lerp_angle($Model.rotation.x, tilt_target, 10.0 * delta)
		if _hit_stun_time <= 0.0:
			_hit_from_behind = false
		# Back-hit stun: completely lock position — no separation force, no velocity, no walk
		if _hit_from_behind:
			return
	else:
		if has_node("Model"):
			$Model.rotation.x = lerp_angle($Model.rotation.x, rush_tilt, 10.0 * delta)
	
	if _frozen_time > 0.0:
		_frozen_time -= delta
		if _frozen_time <= 0.0:
			if _hit_model_timer <= 0.0 and not _dead:
				_show_hit_model(false)
		_decay_knock(delta)
		return
	# Constant +Z march toward the turret; an active knock impulse shoves the
	# body back (away from the player) with decay on top of the march.
	_separate_from_nearby_minions(delta)
	_avoid_chests(delta)
	global_position += _knock_velocity * delta
	if _hit_stun_time <= 0.0:
		global_position.z += current_walk_speed * delta
		_wander_time += delta
		var wander_offset := sin(_wander_phase + _wander_time * 2.2) * _wander_amplitude * wander_weight
		global_position.x += wander_offset - _previous_wander_offset
		_previous_wander_offset = wander_offset
	# Re-apply solid minion collision and chest avoidance so movement never penetrates
	_separate_from_nearby_minions(delta)
	_avoid_chests(delta)
	# Re-snap to ground at newly advanced position so feet never lag behind terrain
	_snap_to_ground(delta)
	# Keep model upright (no waddle)
	if has_node("Model"):
		$Model.rotation.z = 0.0
	
	_decay_knock(delta)
	
	var stop_z := REACH_Z
	var player := get_tree().get_first_node_in_group("player")
	var has_shield := false
	if player != null and player.has_method("has_active_shield") and player.has_active_shield():
		has_shield = true
		var base_z := -1.6
		if player.has_method("get_shield_z"):
			base_z = player.get_shield_z()
		var norm_x := clampf(global_position.x / 0.90, -1.0, 1.0)
		stop_z = base_z - 0.50 * (1.0 - norm_x * norm_x)

	if global_position.z >= stop_z:
		if has_shield:
			# Stopped firmly at the semi-circle barrier surface — NEVER pass through
			global_position.z = stop_z - 0.08
			var blocked := false
			if player != null and player.has_method("absorb_hit"):
				blocked = player.absorb_hit("minion")
			if blocked:
				PurpleStars.spawn_burst(global_position + Vector3(0, 0.25, 0), get_tree(), 12, 0.7)
				take_damage(1.0, false) # Minion takes damage from barrier contact
				knockback(Vector3(0, 0, -1), 3.0) # Knock minion back down the lane (halved)
			else:
				var game = get_node_or_null("/root/Game")
				if game != null and game.has_method("reset_combo"):
					game.reset_combo()
				if player and player.has_method("take_damage"):
					player.take_damage(5)
				queue_free()
		else:
			var game = get_node_or_null("/root/Game")
			if game != null and game.has_method("reset_combo"):
				game.reset_combo()
			if player and player.has_method("take_damage"):
				player.take_damage(5)
			queue_free()



func _separate_from_nearby_minions(_delta: float) -> void:
	var my_radius := 0.25 * (minion_scale / 0.35)
	
	for candidate in get_tree().get_nodes_in_group("minions"):
		var other: Node3D = candidate as Node3D
		if other == null or other == self or bool(other.get("_dead")) or other.is_queued_for_deletion():
			continue
			
		var o_scale: float = float(other.get("minion_scale")) if other.get("minion_scale") != null else 0.35
		var other_radius: float = 0.25 * (o_scale / 0.35)
		var min_dist: float = my_radius + other_radius # combined physical radius (~0.50m)
		
		var dx: float = global_position.x - other.global_position.x
		var dz: float = global_position.z - other.global_position.z
		var dist_sq: float = dx * dx + dz * dz
		
		if dist_sq >= min_dist * min_dist:
			continue
			
		var dist: float = sqrt(maxf(dist_sq, 0.00001))
		var penetration: float = min_dist - dist
		
		# Normal direction from other -> self
		var nx: float = dx / dist
		var nz: float = dz / dist
		if dist <= 0.001:
			var sign_x: float = 1.0 if get_instance_id() > other.get_instance_id() else -1.0
			nx = sign_x
			nz = 0.0
			
		# If one minion is stationary/frozen/stunned, the other absorbs 100% of displacement
		var o_frozen: float = float(other.get("_frozen_time")) if other.get("_frozen_time") != null else 0.0
		var o_stun: float = float(other.get("_hit_stun_time")) if other.get("_hit_stun_time") != null else 0.0
		var o_behind: bool = bool(other.get("_hit_from_behind"))
		var other_immobile: bool = (o_frozen > 0.0 or (o_stun > 0.0 and o_behind))
		var self_immobile: bool = (_frozen_time > 0.0 or (_hit_stun_time > 0.0 and _hit_from_behind))
		
		var push_weight: float = 0.5
		if other_immobile and not self_immobile:
			push_weight = 1.0
		elif self_immobile and not other_immobile:
			push_weight = 0.0
			
		# Immediate solid physical displacement along collision normal
		global_position.x += nx * (penetration * push_weight)
		global_position.z += nz * (penetration * push_weight)
		
		# If self is marching behind other (+Z direction) and colliding into other's back:
		if dz < 0.0 and absf(dx) < min_dist * 0.75:
			# Block forward Z push through other's body
			global_position.z = minf(global_position.z, other.global_position.z - sqrt(maxf(min_dist * min_dist - dx * dx, 0.001)))
			
	global_position.x = clampf(global_position.x, -0.72, 0.72)


func _avoid_chests(delta: float) -> void:
	var crates := get_tree().get_nodes_in_group("ammo_crates")
	if crates.is_empty():
		return
	
	var clearance := 0.58 * (minion_scale / 0.35)
	var lookahead_z := 2.8
	
	for node in crates:
		var crate := node as Node3D
		if crate == null or not is_instance_valid(crate) or crate.is_queued_for_deletion():
			continue
		# Open and unopened chests are both physical obstacles on the path until deleted
		
		var crate_pos := crate.global_position
		var dx := global_position.x - crate_pos.x
		var dz := global_position.z - crate_pos.z
		
		# Minion approaches from -Z toward +Z: check range [-lookahead_z, clearance]
		if dz < -lookahead_z or dz > clearance:
			continue
		
		# If lateral distance is already plenty wide, no avoidance needed
		if absf(dx) >= clearance * 1.25:
			continue
		
		# Determine avoidance direction:
		# If chest is right of center (> 0.15), steer left where lane is wider
		# If chest is left of center (< -0.15), steer right where lane is wider
		var go_right: bool
		if crate_pos.x > 0.15:
			go_right = false
		elif crate_pos.x < -0.15:
			go_right = true
		else:
			if absf(dx) > 0.02:
				go_right = (dx > 0.0)
			else:
				go_right = (crate_pos.x <= 0.0)
		
		var target_x: float = crate_pos.x + (clearance * 1.12 if go_right else -clearance * 1.12)
		
		# 1. Predictive steering: as minion marches toward chest, curve smoothly around it early
		if dz < 0.0:
			var approach_factor := clampf(1.0 - (absf(dz) / lookahead_z), 0.0, 1.0)
			var steer_step := (target_x - global_position.x) * approach_factor * 8.0 * delta
			global_position.x += steer_step
		
		# 2. Hard obstacle boundary: NEVER let the minion penetrate or overlap the chest
		dx = global_position.x - crate_pos.x
		dz = global_position.z - crate_pos.z
		var dist_sq := dx * dx + dz * dz
		if dist_sq < clearance * clearance:
			var req_dx := sqrt(maxf(clearance * clearance - dz * dz, 0.01))
			if go_right:
				global_position.x = maxf(global_position.x, crate_pos.x + req_dx)
			else:
				global_position.x = minf(global_position.x, crate_pos.x - req_dx)
			# Block forward Z push if directly colliding with the front of the chest
			if dz < -0.05 and absf(dx) < clearance * 0.7:
				global_position.z = minf(global_position.z, crate_pos.z - sqrt(maxf(clearance * clearance - dx * dx, 0.01)))
	
	global_position.x = clampf(global_position.x, -0.72, 0.72)


## Freezes the minion in place for the given duration; shows hit model with full textures.
func freeze(duration: float) -> void:
	if _dead:
		return
	_frozen_time = maxf(_frozen_time, duration)
	_show_hit_model(true)


## WaveController supplies the escalating movement profile before this minion
## begins marching. Later waves are faster and weave more aggressively.
func configure_wave(speed_multiplier: float, wander_amplitude: float, wander_phase: float) -> void:
	_speed_multiplier *= maxf(speed_multiplier, 0.1)
	_wander_amplitude = maxf(wander_amplitude, 0.0)
	_wander_phase = wander_phase
	_previous_wander_offset = sin(_wander_phase) * _wander_amplitude


## from_behind=true → boomerang/back hit: tilt forward, no slide.
## from_behind=false (default) → pistol/front hit: tilt back, slide away.
func take_damage(amount: float, from_behind: bool = false) -> void:
	if _dead or amount <= 0.0:
		return
	if _frozen_time > 0.0:
		amount = 9999.0
	health -= amount
	_hit_stun_time = HIT_STUN_TIME
	_hit_model_timer = 0.45
	_show_hit_model(true)
	_hit_from_behind = from_behind
	if from_behind:
		# Back hit: freeze in place — no slide, just tilt forward
		_knock_velocity = Vector3.ZERO
	else:
		# Front hit: slide back away from the player
		knockback(Vector3(0, 0, -1), 1.42)
	if health <= 0.001:
		_spawn_floating_text("+100", Color(0.25, 1.0, 0.35), true)
		die()
	else:
		_spawn_floating_text("+10", Color(1.0, 0.92, 0.2), false)


func _spawn_floating_text(text: String, color: Color, is_kill: bool = false) -> void:
	var lbl := Label3D.new()
	lbl.text = text
	lbl.font_size = 32 if is_kill else 26
	lbl.outline_size = 7 if is_kill else 5
	lbl.outline_modulate = Color(0.08, 0.04, 0.12, 0.95)
	lbl.modulate = color
	lbl.pixel_size = 0.0055
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.render_priority = 12 if is_kill else 10
	
	var jitter_x := randf_range(-0.05, 0.05)
	# Minion model height scaled to minion size; position label right above the head
	var spawn_y := global_position.y + (0.38 * (minion_scale / 0.35))
	var spawn_pos := Vector3(global_position.x + jitter_x, spawn_y, global_position.z)
	get_tree().current_scene.add_child(lbl)
	lbl.global_position = spawn_pos
	
	# Punchy pop-in scale
	lbl.scale = Vector3(0.65, 0.65, 0.65)
	var tw := lbl.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "scale", Vector3.ONE, 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	var rise_height := 0.30 if is_kill else 0.22
	var duration := 0.75 if is_kill else 0.60
	var fade_delay := 0.45 if is_kill else 0.32
	var fade_time := duration - fade_delay
	
	tw.tween_property(lbl, "global_position:y", spawn_pos.y + rise_height, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if not is_kill:
		tw.tween_property(lbl, "global_position:z", spawn_pos.z + 0.12, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, fade_time).set_delay(fade_delay)
	tw.chain().tween_callback(lbl.queue_free)


## Shoves the minion backward with an impulse that decays over time. dir should
## point away from the attacker (usually the player) and may carry an upward Y
## (a lethal boomerang launch); strength is the initial speed in m/s. Frozen
## minions hold position until they thaw.
func knockback(dir: Vector3, strength: float) -> void:
	if _dead or strength <= 0.0 or dir.length_squared() <= 0.0001:
		return
	_knock_velocity = dir.normalized() * strength
	_current_knock_decay = strength / 0.7


func die() -> void:
	if _dead:
		return
	_dead = true
	remove_from_group("minions")
	collision_layer = 0
	_show_hit_model(true)
	_hit_model_timer = 999.0
	
	# Combo streak & drops
	var game = get_node_or_null("/root/Game")
	if game != null and game.has_method("register_combo_hit"):
		game.register_combo_hit()
	
	if drops_ammo:
		_spawn_ammo_crate()

	# Purple star burst & flying molar coin drops on minion defeat
	PurpleStars.spawn_burst(global_position + Vector3(0, 0.35, 0), get_tree(), 8, 0.9)
	_spawn_minion_coins()

	# Every defeated minion is force-launched diagonally up and away. This is
	# deliberately much stronger than a hit shove, so the body crosses the lane
	# rather than spinning in place before it fades.
	var sign_x = 1.0 if randf() > 0.5 else -1.0
	_knock_velocity = Vector3(sign_x * 8.0, 5.0, -8.0).normalized() * maxf(
		DEFAULT_DEATH_LAUNCH_STRENGTH,
		_knock_velocity.length()
	)
	died.emit()
	_collision.set_deferred("disabled", true)
	# Remove lasso web wraps (children tagged lasso_wrap) so a frozen minion
	# that dies early never leaves floating webbing behind.
	for child in get_children():
		if child.is_in_group("lasso_wrap"):
			child.queue_free()
	if _knock_velocity.length_squared() > 0.0001:
		# Killing toss: keep the body visible while the upward launch arcs over
		# under gravity and the body starts to fall, then play the burst. The
		# decay bleeds off the horizontal drift while GRAVITY pulls the Y back
		# down, so the corpse flies up and away instead of rolling back.
		var toss_left := DEATH_TOSS_TIME
		while is_inside_tree() and toss_left > 0.0:
			var dt := maxf(get_physics_process_delta_time(), 0.001)
			toss_left -= dt
			global_position += _knock_velocity * dt
			if has_node("Model"):
				$Model.rotation.y += 20.0 * dt
				$Model.rotation.x += 10.0 * dt
				if _hit_model != null and is_instance_valid(_hit_model):
					_hit_model.rotation = $Model.rotation
			# Preserve the upward launch and bleed only a little horizontal speed;
			# gravity supplies the arc without converting it to an on-the-spot spin.
			_knock_velocity.x = move_toward(_knock_velocity.x, 0.0, DEATH_HORIZONTAL_DECAY * dt)
			_knock_velocity.z = move_toward(_knock_velocity.z, 0.0, DEATH_HORIZONTAL_DECAY * dt)
			_knock_velocity.y -= GRAVITY * dt
			await get_tree().physics_frame
	# Fade only after the airborne arc, so the defeated minion visibly flies
	# away before it disappears into the burst.
	var body_fade := StandardMaterial3D.new()
	body_fade.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	body_fade.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	body_fade.albedo_color = Color(0.62, 0.24, 0.75, 1.0)
	var head_fade := StandardMaterial3D.new()
	head_fade.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	head_fade.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	head_fade.albedo_color = Color(1.0, 0.85, 0.68, 1.0)
	_body.material_override = body_fade
	_head.material_override = head_fade
	var fade := create_tween()
	fade.set_parallel(true)
	fade.tween_property(body_fade, "albedo_color:a", 0.0, 0.18)
	fade.tween_property(head_fade, "albedo_color:a", 0.0, 0.18)
	_set_model_visible(false)
	_burst.restart()
	_burst.emitting = true
	await get_tree().create_timer(0.8).timeout
	queue_free()


## Level 3 Floss destruction: minion stays in place and bursts into tiny little candy squares!
func burst_into_tiny_squares() -> void:
	if _dead:
		return
	_dead = true
	remove_from_group("minions")
	collision_layer = 0
	_collision.set_deferred("disabled", true)
	_show_hit_model(false)
	_set_model_visible(false)
	
	_spawn_floating_text("+100", Color(0.25, 1.0, 0.35), true)
	
	# Combo streak & drops
	var game = get_node_or_null("/root/Game")
	if game != null and game.has_method("register_combo_hit"):
		game.register_combo_hit()
	
	if drops_ammo:
		_spawn_ammo_crate()
		
	# Purple star burst & flying molar coin drops
	PurpleStars.spawn_burst(global_position + Vector3(0, 0.35, 0), get_tree(), 12, 1.1)
	_spawn_minion_coins()
		
	died.emit()
	
	# Particle burst of tiny little squares / cubes!
	var burst := CPUParticles3D.new()
	burst.amount = 54
	burst.lifetime = 0.75
	burst.one_shot = true
	burst.explosiveness = 0.96
	
	var bm := BoxMesh.new()
	bm.size = Vector3(0.065, 0.065, 0.065)
	burst.mesh = bm
	
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.35, 0.85, 1.0)
	burst.material_override = mat
	
	burst.direction = Vector3(0, 1, 0)
	burst.spread = 180.0
	burst.initial_velocity_min = 2.5
	burst.initial_velocity_max = 5.8
	burst.gravity = Vector3(0, -9.8, 0)
	burst.scale_amount_min = 0.6
	burst.scale_amount_max = 1.3
	
	get_tree().current_scene.add_child(burst)
	burst.global_position = global_position + Vector3(0, 0.30, 0)
	
	# Camera subtle shake for punchy feel
	var player = get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("apply_camera_shake"):
		player.apply_camera_shake(0.12)
		
	await get_tree().create_timer(0.85).timeout
	burst.queue_free()
	queue_free()


func _spawn_minion_coins() -> void:
	var coin_count := 0
	match variant:
		"runner":
			if randf() < 0.45:
				coin_count = 1
		"brute":
			coin_count = 2
		_:
			if randf() < 0.55:
				coin_count = 1
				
	if coin_count > 0:
		_spawn_coins(coin_count)


static var _cached_coin_scene: PackedScene = null

func _spawn_coins(count: int = 1) -> void:
	if _cached_coin_scene == null and ResourceLoader.exists("res://candy_crusade/molar_coin.tscn"):
		_cached_coin_scene = load("res://candy_crusade/molar_coin.tscn")
	if _cached_coin_scene == null:
		return
	for i in range(count):
		var coin = _cached_coin_scene.instantiate() as Node3D
		if coin != null:
			get_tree().current_scene.add_child(coin)
			var spread_x := randf_range(-1.3, 1.3)
			var spread_y := randf_range(3.2, 4.6)
			var spread_z := randf_range(-1.0, 1.0)
			if coin.has_method("launch"):
				coin.call("launch", global_position + Vector3(0, 0.35, 0), Vector3(spread_x, spread_y, spread_z))
			else:
				coin.global_position = global_position


static var _cached_crate_scene: PackedScene = null

func _spawn_ammo_crate() -> void:
	if _cached_crate_scene == null and ResourceLoader.exists("res://candy_crusade/ammo_crate.tscn"):
		_cached_crate_scene = load("res://candy_crusade/ammo_crate.tscn")
	if _cached_crate_scene:
		var crate = _cached_crate_scene.instantiate() as Node3D
		if crate:
			get_tree().current_scene.add_child(crate)
			crate.global_position = global_position



var _current_knock_decay := 14.0

func _decay_knock(delta: float) -> void:
	_knock_velocity = _knock_velocity.move_toward(Vector3.ZERO, _current_knock_decay * delta)


func _set_model_visible(is_visible: bool) -> void:
	if not is_visible:
		if has_node("Model"):
			$Model.visible = false
		if _hit_model != null and is_instance_valid(_hit_model):
			_hit_model.visible = false
		for node in find_children("*", "MeshInstance3D", true, false):
			(node as MeshInstance3D).visible = false
	else:
		_show_hit_model(_hit_model_timer > 0.0 or _dead)
