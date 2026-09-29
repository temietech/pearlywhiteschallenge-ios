extends CharacterBody3D
class_name BlueCandor

signal died
signal health_changed(new_health: int, max_health: int)

@export var max_health: int = 18
@export var move_speed: float = 0.675
@export var candy_scene: PackedScene
@export var boss_scale: float = 0.8

const PurpleStars = preload("res://candy_crusade/scripts/purple_stars.gd")

const HIT_STUN_TIME := 0.7
const CANDY_THROW_INTERVAL := 5.0
const CAVE_RUSH_SPEED := 2.8
const CAVE_EXIT_Z := -9.5
const CAVE_DECEL_END_Z := -7.6

var health: float
var _dead := false
var _is_cave_rushing := false
var _wander_time := 0.0
var _hit_stun_time := 0.0
var _frozen_time := 0.0
var _candy_throw_left := CANDY_THROW_INTERVAL

const HIT_MODEL_PATH := "res://assets/candy_crusade/models/BlueCandorHit.glb"
static var _cached_boss_hit_scene: PackedScene = null
static var _has_attempted_boss_hit_cache := false

var _hit_model: Node3D
var _hit_model_timer := 0.0

@onready var _body: MeshInstance3D = $Body
@onready var _head: MeshInstance3D = $Head


func _ready() -> void:
	scale = Vector3(boss_scale, boss_scale, boss_scale)
	health = max_health
	add_to_group("bosses")
	_setup_hit_model()
	call_deferred("_align_model_to_feet")
	call_deferred("_snap_to_ground", 0.0)
	call_deferred("_emit_initial_health")


func _setup_hit_model() -> void:
	if not _has_attempted_boss_hit_cache:
		_has_attempted_boss_hit_cache = true
		if ResourceLoader.exists(HIT_MODEL_PATH):
			_cached_boss_hit_scene = load(HIT_MODEL_PATH)
		elif FileAccess.file_exists(HIT_MODEL_PATH):
			var gltf := GLTFDocument.new()
			var state := GLTFState.new()
			var err := gltf.append_from_file(HIT_MODEL_PATH, state)
			if err == OK:
				var scene := PackedScene.new()
				var root := gltf.generate_scene(state)
				scene.pack(root)
				_cached_boss_hit_scene = scene

	if _cached_boss_hit_scene != null:
		_hit_model = _cached_boss_hit_scene.instantiate() as Node3D
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

func _emit_initial_health() -> void:
	health_changed.emit(health, max_health)


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
			var trans := global_transform.affine_inverse() * mi.global_transform
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
	var ray_start_y := maxf(global_position.y + 1.6, 2.5)
	var ray_end_y := global_position.y - 3.5
	
	# 1. Primary check at Blue Candor's current position
	var hit := _cast_ground_ray(space_state, Vector3(global_position.x, ray_start_y, global_position.z), Vector3(global_position.x, ray_end_y, global_position.z))
	
	# 2. If primary ray misses (e.g. lateral weave near bridge edge), sample lane center X = 0
	if not (hit and hit.has("position")) and absf(global_position.x) > 0.04:
		hit = _cast_ground_ray(space_state, Vector3(0.0, ray_start_y, global_position.z), Vector3(0.0, ray_end_y, global_position.z))
	
	# 3. Offsets for trimesh edge seams
	if not (hit and hit.has("position")):
		hit = _cast_ground_ray(space_state, Vector3(global_position.x - 0.2, ray_start_y, global_position.z), Vector3(global_position.x - 0.2, ray_end_y, global_position.z))
	if not (hit and hit.has("position")):
		hit = _cast_ground_ray(space_state, Vector3(global_position.x + 0.2, ray_start_y, global_position.z), Vector3(global_position.x + 0.2, ray_end_y, global_position.z))
	
	if hit and hit.has("position"):
		var target_y: float = hit["position"].y
		# Walkable terrain surface is never above 3.5m across all levels
		if target_y > 3.5:
			return
		if not _has_snapped_to_ground or delta <= 0.0:
			global_position.y = target_y
			_has_snapped_to_ground = true
		else:
			if target_y > global_position.y:
				# Immediate snap up on rising terrain so boss never sinks into slopes
				global_position.y = target_y
			else:
				# Snappy smooth descent on downward slopes
				global_position.y = lerpf(global_position.y, target_y, clampf(35.0 * delta, 0.0, 1.0))


const GRAVITY := 20.0

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
	
	if _is_retreating:
		# During retreat, _retreat_tween moves Z back to the cave mouth.
		# Smoothly center X while actively steering/pushing around any chests in the path
		global_position.x = lerpf(global_position.x, 0.0, 5.0 * delta)
		_avoid_chests(delta)
		_snap_to_ground(0.0)
		return
	
	if _frozen_time > 0.0:
		_frozen_time = maxf(_frozen_time - delta, 0.0)
		if _frozen_time <= 0.0:
			if _hit_model_timer <= 0.0 and not _dead:
				_show_hit_model(false)
			_remove_floss_wrap()
		return
	if _hit_stun_time > 0.0:
		_hit_stun_time = maxf(_hit_stun_time - delta, 0.0)
		return
	
	# Cave rush speed: Blue Candor charges out of the cave fast before slowing to normal boss speed
	if global_position.z < CAVE_EXIT_Z:
		_is_cave_rushing = true
	
	var current_move_speed := move_speed
	var wander_weight := 1.0
	
	if _is_cave_rushing:
		if global_position.z < CAVE_EXIT_Z:
			current_move_speed = CAVE_RUSH_SPEED
			wander_weight = 0.0
			# Postpone candy throws until emerging into the open
			_candy_throw_left = maxf(_candy_throw_left, 1.5)
		elif global_position.z < CAVE_DECEL_END_Z:
			var t := (global_position.z - CAVE_EXIT_Z) / (CAVE_DECEL_END_Z - CAVE_EXIT_Z)
			current_move_speed = lerpf(CAVE_RUSH_SPEED, move_speed, t)
			wander_weight = t
		else:
			_is_cave_rushing = false
	
	_wander_time += delta
	_candy_throw_left -= delta
	if _candy_throw_left <= 0.0:
		_throw_candy()
		_candy_throw_left = CANDY_THROW_INTERVAL
	global_position.z += current_move_speed * delta
	global_position.x += cos(_wander_time * 1.4) * 0.35 * delta * wander_weight
	# Actively steer and push around any ammo chests in the lane
	_avoid_chests(delta)
	# Re-snap to ground at newly advanced position so feet never lag behind terrain
	var target_reach_z := -0.75
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("has_active_shield") and player.has_active_shield():
		if player.has_method("get_shield_z"):
			target_reach_z = player.get_shield_z()
		else:
			target_reach_z = -1.6
	if not _is_retreating and global_position.z >= target_reach_z:
		_on_reached_player(target_reach_z)


func _avoid_chests(delta: float) -> void:
	var crates := get_tree().get_nodes_in_group("ammo_crates")
	if crates.is_empty():
		return
	
	var clearance := 0.72 * (boss_scale / 0.8)
	var lookahead_z := 1.5
	
	for node in crates:
		var crate := node as Node3D
		if crate == null or not is_instance_valid(crate) or crate.is_queued_for_deletion():
			continue
		if crate.get("_collected"):
			continue
		
		var crate_pos := crate.global_position
		var dx := global_position.x - crate_pos.x
		var dz := global_position.z - crate_pos.z
		
		# Only check chests within reasonable distance along Z
		if dz < -lookahead_z or dz > clearance:
			continue
		
		# If lateral distance is already plenty wide, no avoidance needed
		if absf(dx) >= clearance * 1.25:
			continue
		
		var go_right: bool
		if crate_pos.x > 0.15:
			go_right = false # Chest is on the right, steer around its left
		elif crate_pos.x < -0.15:
			go_right = true # Chest is on the left, steer around its right
		else:
			if absf(dx) > 0.02:
				go_right = (dx > 0.0)
			else:
				go_right = (crate_pos.x <= 0.0)
		
		var target_x: float = crate_pos.x + (clearance * 1.10 if go_right else -clearance * 1.10)
		
		# 1. Predictive lateral steering: smoothly steer boss around the chest
		if dz < 0.0:
			var approach_factor := clampf(1.0 - (absf(dz) / lookahead_z), 0.0, 1.0)
			var steer_step := (target_x - global_position.x) * approach_factor * 5.0 * delta
			global_position.x += steer_step
		
		# 2. Hard obstacle boundary: NEVER let Blue Candor penetrate or overlap the chest
		dx = global_position.x - crate_pos.x
		dz = global_position.z - crate_pos.z
		var dist_sq := dx * dx + dz * dz
		if dist_sq < clearance * clearance:
			var req_dx := sqrt(maxf(clearance * clearance - dz * dz, 0.01))
			if go_right:
				global_position.x = maxf(global_position.x, crate_pos.x + req_dx)
			else:
				global_position.x = minf(global_position.x, crate_pos.x - req_dx)
	
	global_position.x = clampf(global_position.x, -0.75, 0.75)


var _is_retreating := false
var _retreat_tween: Tween = null

func _on_reached_player(reach_z: float = -0.75) -> void:
	if _dead or _is_retreating:
		return
	
	_is_retreating = true
	global_position.z = reach_z
	
	var player := get_tree().get_first_node_in_group("player")
	var blocked_by_shield := false
	if player != null and player.has_method("absorb_hit"):
		blocked_by_shield = player.absorb_hit("blue_candor")
		
	if not blocked_by_shield:
		# 1. Deduct points / score
		var spawner = get_tree().get_first_node_in_group("spawner")
		if spawner and spawner.has_method("reduce_score"):
			spawner.reduce_score(20)
		
		var bridge = get_node_or_null("/root/GameBridge")
		if bridge != null and "points" in bridge:
			bridge.points = maxi(0, bridge.points - 20)
		
		var game = get_node_or_null("/root/Game")
		if game != null and game.has_method("reset_combo"):
			game.reset_combo()
		
		# 2. Damage player & trigger heavy camera shake
		if player != null:
			if player.has_method("apply_camera_shake"):
				player.apply_camera_shake(0.55)
			if player.has_method("take_damage"):
				player.take_damage(20)
		
		# 3. Floating penalty text right in front of the screen
		_spawn_floating_text("-20 PTS!", Color(1.0, 0.25, 0.25), true)
	else:
		# Blocked by Fluoride Shield: No damage, no points deducted, combo preserved!
		_spawn_floating_text("SHIELD BLOCKED!", Color(0.35, 1.0, 0.95), true)

	
	# 4. Cancel any running knockbacks or retreats
	if _knock_tween != null and _knock_tween.is_valid():
		_knock_tween.kill()
	if _retreat_tween != null and _retreat_tween.is_valid():
		_retreat_tween.kill()
	
	# 5. Animate Blue Candor retreating rapidly back up the lane
	var target_retreat_z := -9.5
	_retreat_tween = create_tween()
	_retreat_tween.set_parallel(true)
	_retreat_tween.tween_property(self, "global_position:z", target_retreat_z, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Model recoil / bounce tilt during retreat
	_retreat_tween.tween_property($Model, "rotation:x", deg_to_rad(-20.0), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_retreat_tween.tween_property($Model, "rotation:x", 0.0, 0.6).set_delay(0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if _hit_model != null and is_instance_valid(_hit_model):
		_retreat_tween.tween_property(_hit_model, "rotation:x", deg_to_rad(-20.0), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_retreat_tween.tween_property(_hit_model, "rotation:x", 0.0, 0.6).set_delay(0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# 6. Once back at the cave mouth, begin approaching again!
	_retreat_tween.chain().tween_callback(func():
		_is_retreating = false
		_is_cave_rushing = true
		_candy_throw_left = 2.5
	)


func take_damage(amount: float, from_behind: bool = false) -> void:
	if _dead or amount <= 0.0:
		return
	var capped_amount := minf(amount, 40.0) # Safety cap so boss takes up to full L3 mouthwash damage
	health -= capped_amount
	if _frozen_time > 0.0:
		# Floss-wrapped + hit combo: double damage on Blue Candor (not insta-kill)
		health -= capped_amount
	health_changed.emit(maxi(0, int(ceil(health))), int(max_health))
	_hit_stun_time = HIT_STUN_TIME
	_hit_model_timer = 0.50
	_show_hit_model(true)
	
	if not from_behind:
		knockback(Vector3(0, 0, -1), 5.0)
	
	# Tilt animation (tilt forward if hit from behind, tilt back if hit from front)
	if not _is_retreating:
		if _tilt_tween != null and _tilt_tween.is_valid():
			_tilt_tween.kill()
		var tilt_angle := deg_to_rad(30.0) if from_behind else deg_to_rad(-30.0)
		_tilt_tween = create_tween()
		_tilt_tween.tween_property($Model, "rotation:x", tilt_angle, 0.1)
		_tilt_tween.tween_property($Model, "rotation:x", 0.0, 0.6)
		if _hit_model != null and is_instance_valid(_hit_model):
			_tilt_tween.parallel().tween_property(_hit_model, "rotation:x", tilt_angle, 0.1)
			_tilt_tween.parallel().tween_property(_hit_model, "rotation:x", 0.0, 0.6)
	
	if health <= 0.001:
		_die()
	else:
		_spawn_floating_text("+20", Color(1.0, 0.92, 0.2), false)


var _tilt_tween: Tween
var _knock_tween: Tween

func knockback(dir: Vector3, strength: float) -> void:
	if _dead or _is_retreating or strength <= 0.0 or dir.length_squared() <= 0.0001:
		return
	if _knock_tween != null and _knock_tween.is_valid():
		_knock_tween.kill()
	var push := dir.normalized() * (strength * 0.1)
	_knock_tween = create_tween()
	# Only push horizontally (Z and X); NEVER touch Y so ground tracking remains unbroken
	_knock_tween.tween_property(self, "global_position:z", global_position.z + push.z, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if absf(push.x) > 0.001:
		_knock_tween.parallel().tween_property(self, "global_position:x", global_position.x + push.x, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func freeze(duration: float) -> void:
	if not _dead:
		_frozen_time = maxf(_frozen_time, duration)
		_show_hit_model(true)
		_create_floss_wrap()


func _create_floss_wrap() -> void:
	if has_node("FlossWrap"):
		return
	var wrap := Node3D.new()
	wrap.name = "FlossWrap"
	add_child(wrap)
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.52 * boss_scale
	ring_mesh.outer_radius = 0.62 * boss_scale
	var ring_mat := StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.albedo_color = Color(0.85, 1.0, 0.95)
	for y_offset in [0.7 * boss_scale, 1.3 * boss_scale]:
		var mi := MeshInstance3D.new()
		mi.mesh = ring_mesh
		mi.material_override = ring_mat
		mi.position.y = y_offset
		mi.rotation_degrees = Vector3(randf_range(-12, 12), randf_range(0, 360), randf_range(-12, 12))
		wrap.add_child(mi)


func _remove_floss_wrap() -> void:
	var wrap := get_node_or_null("FlossWrap")
	if wrap != null:
		wrap.queue_free()


## Fires a tappable candy straight toward the player's camera screen.
func _throw_candy() -> void:
	if candy_scene == null:
		return
	var candy := candy_scene.instantiate() as Node3D
	if candy == null:
		return
	var parent := get_parent() if get_parent() != null else self
	parent.add_child(candy)
	candy.global_position = global_position + Vector3(0.0, 1.4 * boss_scale, 0.0)
	
	# Find active camera to target the player's screen directly
	var cam: Camera3D = get_viewport().get_camera_3d() if get_viewport() != null else null
	if cam == null:
		var player := get_tree().get_first_node_in_group("player") as Node3D
		if player != null:
			cam = player.get_node_or_null("Camera3D") as Camera3D
	
	var target: Vector3
	if cam != null:
		# In camera view space, -Z is forward. Sitting at z = -0.25 is right in front of the lens on screen.
		# Scatter across the viewport frame so each candy heads toward a slightly different part of the screen.
		var screen_scatter := Vector3(
			randf_range(-0.20, 0.20),
			randf_range(-0.12, 0.12),
			-0.25
		)
		target = cam.global_transform * screen_scatter
	else:
		var player := get_tree().get_first_node_in_group("player") as Node3D
		var player_pos := player.global_position if player != null else Vector3.ZERO
		target = player_pos + Vector3(randf_range(-0.20, 0.20), 0.8 + randf_range(-0.1, 0.1), 0.35)
	
	var distance := global_position.distance_to(target)
	# A smooth, readable arc height so the candy is never launched off-screen into the sky
	var arc_height := clampf(distance * 0.05, 0.3, 0.65)
	candy.call("launch", candy.global_position, target, arc_height)


func _spawn_floating_text(text: String, color: Color, is_big: bool = false) -> void:
	var lbl := Label3D.new()
	lbl.text = text
	lbl.font_size = 36 if is_big else 28
	lbl.outline_size = 8 if is_big else 6
	lbl.outline_modulate = Color(0.08, 0.04, 0.12, 0.95)
	lbl.modulate = color
	lbl.pixel_size = 0.007
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.render_priority = 15 if is_big else 10
	
	var jitter_x := randf_range(-0.12 * boss_scale, 0.12 * boss_scale)
	# Blue Candor model top is ~2.32m; position label right above his head
	var spawn_y := global_position.y + (2.32 * boss_scale)
	var spawn_pos := Vector3(global_position.x + jitter_x, spawn_y, global_position.z)
	get_tree().current_scene.add_child(lbl)
	lbl.global_position = spawn_pos
	
	lbl.scale = Vector3(0.7, 0.7, 0.7)
	var tw := lbl.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	var rise := 0.40 if is_big else 0.28
	var duration := 0.85 if is_big else 0.65
	var fade_delay := 0.50 if is_big else 0.35
	var fade_time := duration - fade_delay
	
	tw.tween_property(lbl, "global_position:y", spawn_pos.y + rise, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, fade_time).set_delay(fade_delay)
	tw.chain().tween_callback(lbl.queue_free)


func _die() -> void:
	if _dead:
		return
	_dead = true
	died.emit()
	remove_from_group("bosses")
	collision_layer = 0
	_show_hit_model(true)
	_hit_model_timer = 999.0
	
	# Stop physics processing so he halts immediately in place
	set_physics_process(false)
	
	# Disable collision so bullets and interaction pass through
	if has_node("Collision"):
		$Collision.set_deferred("disabled", true)
	
	# Cancel any running hit animations, knockbacks, or retreats
	_is_retreating = false
	if _retreat_tween != null and _retreat_tween.is_valid():
		_retreat_tween.kill()
	if _tilt_tween != null and _tilt_tween.is_valid():
		_tilt_tween.kill()
	if _knock_tween != null and _knock_tween.is_valid():
		_knock_tween.kill()
	
	_remove_floss_wrap()
	
	# Clear any pending boss candies in flight
	for candy in get_tree().get_nodes_in_group("boss_candies"):
		if is_instance_valid(candy):
			candy.queue_free()
	
	# Floating victory banner
	_spawn_floating_text("DEFEATED!", Color(1.0, 0.85, 0.2), true)
	
	# Purple star burst & flying molar coins celebration on boss defeat
	PurpleStars.spawn_burst(global_position + Vector3(0, 0.90, 0), get_tree(), 24, 1.6)
	_spawn_boss_coins(6)
	
	# Animate Blue Candor collapsing backward onto the ground and remaining there
	var fall_tween := create_tween()
	fall_tween.set_parallel(true)
	# Tilt backward flat onto the floor with a satisfying bounce
	if has_node("Model"):
		fall_tween.tween_property($Model, "rotation:x", deg_to_rad(-86.0), 0.8).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		# Slight natural sideways angle for a rested defeat pose
		fall_tween.tween_property($Model, "rotation:z", deg_to_rad(6.0), 0.8).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		# Settle model elevation so his back rests cleanly on the ground
		fall_tween.tween_property($Model, "position:y", 0.25, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		# Slight backward shift as feet stay anchored while torso falls back
		fall_tween.tween_property($Model, "position:z", -0.3, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if _hit_model != null and is_instance_valid(_hit_model):
		fall_tween.tween_property(_hit_model, "rotation:x", deg_to_rad(-86.0), 0.8).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		fall_tween.tween_property(_hit_model, "rotation:z", deg_to_rad(6.0), 0.8).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		fall_tween.tween_property(_hit_model, "position:y", 0.25, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		fall_tween.tween_property(_hit_model, "position:z", -0.3, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Note: We do NOT call queue_free() so Blue Candor stays lying on the ground!


static var _cached_coin_scene: PackedScene = null

func _spawn_boss_coins(count: int = 6) -> void:
	if _cached_coin_scene == null and ResourceLoader.exists("res://candy_crusade/molar_coin.tscn"):
		_cached_coin_scene = load("res://candy_crusade/molar_coin.tscn")
	if _cached_coin_scene == null:
		return
	for i in range(count):
		var coin = _cached_coin_scene.instantiate() as Node3D
		if coin != null:
			get_tree().current_scene.add_child(coin)
			var angle := randf_range(0.0, TAU)
			var speed := randf_range(1.6, 3.2)
			var spread_x := cos(angle) * speed
			var spread_y := randf_range(4.2, 6.2)
			var spread_z := sin(angle) * speed
			if coin.has_method("launch"):
				coin.call("launch", global_position + Vector3(0, 0.8, 0), Vector3(spread_x, spread_y, spread_z))
			else:
				coin.global_position = global_position

