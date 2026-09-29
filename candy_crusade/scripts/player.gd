extends Node3D

## Stationary turret player. Camera looks down -Z (toward the horizon).
## Gesture weapons, all driven by the same press/drag/release cycle so mouse
## and touch behave identically (the mouse is never captured):
##   - Quick tap: fires one toothpaste projectile, delayed by TAP_DELAY so a
##     fast second tap can be recognized as a floss lasso before the shot.
##   - Hold: after TAP_DELAY the pistol rapid-fires along the flat aim through
##     the current pointer while held. A per-press swipe lock cancels the
##     pistol as soon as the pointer moves ~20 px, so swipes never fire the
##     pistol while holds within the radius still do.
##   - Swipe up: boomerang toothbrush. It flies out to the exact 3D point the
##     release ended on (muzzle-height plane), spinning flat, and instantly
##     returns on its first outward hit.
##   - Drag down: mouthwash grenade. The downward pull snaps through 5 fixed
##     throw tiers (tiny..max), with a live landing reticle snapping to the
##     same 5 lane points while charging.
##   - Double-tap: floss lasso freezes Game.floss_level nearest minions and
##     casts a visible string plus a thick white rope coil around each one.

@export var projectile_scene: PackedScene
@export var boomerang_scene: PackedScene
@export var grenade_scene: PackedScene
@export var projectiles_parent: NodePath = NodePath("../Projectiles")

const PISTOL_COOLDOWN := 0.13
const GESTURE_THRESHOLD := 50.0
## Tap-delay: a press must stay down this long before it becomes a hold, and a
## quick release schedules its single pistol shot this long after release. The
## delay (< DOUBLE_TAP_WINDOW) is what lets a fast second tap cancel the first
## shot and turn the pair into a floss lasso with zero pistol fire.
const TAP_DELAY := 0.22
const DOUBLE_TAP_WINDOW := 0.45
const DOUBLE_TAP_MAX_DISTANCE := 140.0
const FREEZE_RANGE := 30.0
const FREEZE_DURATION := 2.2
const LASSO_THICKNESS := 0.0165
const LASSO_SPIN_TIME := 0.4
const LASSO_FADE_TIME := 0.4
## Per-press swipe lock: while the pointer stays within this many pixels of
## the press position the press is a hold (pistol rapid-fire). Once it moves
## beyond the threshold the press is a swipe/drag and the pistol stops firing.
const SWIPE_LOCK_THRESHOLD := 20.0
## Boomerang outbound cap: the swipe end point is clamped to this far from the
## muzzle (and used as the fallback when the release ray never crosses the
## muzzle-height plane) so the toothbrush always returns inside LIFETIME.
const BOOMERANG_OUTBOUND_MAX := 22.0
## Height at which the toothbrush boomerang flies along the lane. Leveled with
## minion torso/head height (0.46 m; lane ground is at Y ~0.20 m) so it floats
## cleanly above the floor in full view and slices through minion bodies.
const BOOMERANG_FLIGHT_HEIGHT := 0.46
## Grenade pull: the drag between GESTURE_THRESHOLD and GRENADE_MAX_PULL is
## Continuous slingshot pull: pull ratio scales smoothly from GESTURE_THRESHOLD
## up to GRENADE_MAX_PULL, mapping continuously to forward and vertical impulse.
## RigidBody mass is 1, so impulse ~= launch velocity.
const GRENADE_MAX_PULL := 300.0
const GRENADE_GRAVITY := 9.8
## Floor reticle height above the lane top (avoids z-fighting).
const RETICLE_HEIGHT := 0.03
## Rope coil wrap constants (replaces the old wireframe web): a thick white
## string helically coiled around the frozen minion's body plus one loop
## around its head.
const LASSO_COIL_SEGMENTS := 12
const LASSO_COIL_TURNS := 2.0
const LASSO_COIL_RADIUS := 0.06
const LASSO_HEAD_LOOP_SEGMENTS := 8
const LASSO_HEAD_RADIUS := 0.05

var _pistol_cooldown := 0.0
var _pressed := false
var _press_pos := Vector2.ZERO

@export var max_health := 100
var health: int = 100
signal health_changed(new_health: int, max_health: int)
signal died
signal weapon_activated(weapon_name: String)
signal shield_updated(active: bool, durability_ratio: float, remaining_shields: int)

# Fluoride Shield System (lasts 3 minion collisions, 5 bonbon collisions, 1 Blue Candor collision)
const SHIELD_MAX_DURABILITY := 15.0
var _has_shield := false
var _shield_durability := 0.0
var _shield_root: Node3D = null
var _shield_mesh: MeshInstance3D = null
var _shield_aura: CPUParticles3D = null
var _shield_material: StandardMaterial3D = null

var _drag_total := Vector2.ZERO
var _pointer_pos := Vector2.ZERO
var _swipe_locked := false
## Tap state machine (see TAP_DELAY/DOUBLE_TAP_WINDOW): _press_started_at and
## _press_pending track the current press, which stays pending (no pistol
## fire) until TAP_DELAY elapses while held and resolves it to a hold.
## _press_consumed marks the second press of a consumed double tap so neither
## tap ever fires. After a quick tap releases, _pending_single_shot schedules
## exactly one pistol shot at _single_shot_at, aimed at _single_shot_aim,
## unless a second tap arrives first.
var _press_started_at := 0.0
var _press_pending := false
var _press_consumed := false
var _pending_single_shot := false
var _single_shot_at := 0.0
var _single_shot_aim := Vector2.ZERO
var _last_tap_time := -1.0
var _last_tap_pos := Vector2.ZERO
var _hold_shot_fired := false
var _shake_time := 0.0
var _aim_reticle: Node3D
var _grenade_in_flight := false
var _trajectory_mesh_instance: MeshInstance3D
var _immediate_mesh: ImmediateMesh
var _trajectory_material: StandardMaterial3D
var current_selected_weapon: String = "pistol"
var _pistol_rest_position := Vector3.ZERO
var _pistol_rest_rotation := Vector3.ZERO
var _pistol_recoil: Tween

@onready var _camera: Camera3D = $Camera3D
@onready var _muzzle: Node3D = $Camera3D/Muzzle
@onready var _pistol: Node3D = $Camera3D/Pistol

var _brush: Node3D
var _brush_rest_position := Vector3(-0.11, -0.13, -0.50)
var _brush_rest_rotation := Vector3(10.0, 0.0, 0.0) # Upright, bristles facing camera
var _brush_rest_scale := Vector3(0.082, 0.082, 0.082)
var _brush_in_flight: int = 0
var _brush_tween: Tween

var _flask: Node3D
var _flask_rest_position := Vector3(0.08, -0.16, -0.42)
var _flask_rest_rotation := Vector3(5.0, 0.0, 0.0)
var _flask_rest_scale := Vector3(0.060, 0.060, 0.060)
var _flask_tween: Tween
var _flask_restore_tween: Tween

var _action_origin: Node3D
var _active_lassos: Array[Dictionary] = []

var _camera_rest_position: Vector3 = Vector3(0.0, 0.8, 0.6)
var _camera_rest_rotation: Vector3 = Vector3(-5.0, 0.0, 0.0)


func set_camera_profile(pos: Vector3, rot_deg: Vector3 = Vector3(-5.0, 0.0, 0.0)) -> void:
	_camera_rest_position = pos
	_camera_rest_rotation = rot_deg
	if _camera != null and is_instance_valid(_camera):
		_camera.transform.origin = _camera_rest_position
		_camera.rotation_degrees = _camera_rest_rotation


func _ready() -> void:
	add_to_group("player")
	health = max_health
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Camera above the plane looking down to match concept art
	_camera.transform.origin = _camera_rest_position
	_camera.rotation_degrees = _camera_rest_rotation
	var rc = get_node_or_null("../RegionController")
	if rc != null and rc.has_method("apply_camera_to_player"):
		rc.apply_camera_to_player(self)
	
	# Pistol positioning — lower-right of screen matching concept art.
	# Scaled down by 30% (0.144 -> 0.1008) and positioned in camera view frustum.
	_pistol.scale = Vector3(0.1008, 0.1008, 0.1008)
	_pistol.position = Vector3(0.26, -0.18, -0.52)
	_pistol.rotation_degrees = Vector3(15.0, -12.0, -10.0) # Tilted: bristles up-left, handle down-right
	_pistol_rest_position = _pistol.position
	_pistol_rest_rotation = _pistol.rotation_degrees
	
	# Muzzle at the barrel/bristle tip of the pistol model in camera space.
	_muzzle.position = Vector3(0.16, -0.12, -0.63)
	_make_aim_reticle()
	_make_trajectory_arc()

	# Brush viewmodel — lower-left of screen, standing tall facing player
	_brush = Node3D.new()
	_brush.name = "Brush"
	_camera.add_child(_brush)
	_brush.position = _brush_rest_position
	_brush.rotation_degrees = _brush_rest_rotation
	_brush.scale = _brush_rest_scale

	# Mouthwash viewmodel — lower center of screen, compact bottle
	_flask = Node3D.new()
	_flask.name = "Flask"
	_camera.add_child(_flask)
	_flask.position = _flask_rest_position
	_flask.rotation_degrees = _flask_rest_rotation
	_flask.scale = _flask_rest_scale

	# Action origin for Floss (locked at bottom center)
	_action_origin = Node3D.new()
	_camera.add_child(_action_origin)
	_action_origin.position = Vector3(0, -0.4, -1.0)

	# Initial visibility strictly according to active weapon
	_pistol.visible = (current_selected_weapon == "pistol")
	_brush.visible = (current_selected_weapon == "boomerang")
	_flask.visible = (current_selected_weapon == "grenade")

	var game = get_node_or_null("/root/Game")
	if game != null:
		if game.has_signal("weapon_level_changed"):
			game.weapon_level_changed.connect(func(w_name: String, lvl: int):
				if w_name == "pistol":
					_update_pistol_model(lvl)
				elif w_name == "boomerang":
					_update_brush_model(lvl)
				elif w_name == "grenade":
					_update_flask_model(lvl)
			)
		_update_pistol_model(int(game.get("pistol_level")))
		_update_brush_model(int(game.get("boomerang_level")))
		_update_flask_model(int(game.get("grenade_level")))
	else:
		_update_pistol_model(1)
		_update_brush_model(1)
		_update_flask_model(1)

	var bridge = get_node_or_null("/root/GameBridge")
	if bridge != null:
		if bridge.has_signal("weapon_auto_switched"):
			bridge.weapon_auto_switched.connect(func(_b_id: String, int_id: String):
				set_selected_weapon(int_id)
			)
		if bridge.has_signal("session_ready"):
			bridge.session_ready.connect(func(_p):
				set_selected_weapon(bridge.equipped)
				check_auto_apply_shield()
			)
		if bridge.get("initialized") == true:
			set_selected_weapon(bridge.equipped)
			check_auto_apply_shield()
		else:
			check_auto_apply_shield()
	else:
		check_auto_apply_shield()


func set_selected_weapon(w_name: String) -> void:
	var bridge = get_node_or_null("/root/GameBridge")
	if bridge != null:
		if bridge.is_weapon_locked(w_name):
			return
		current_selected_weapon = bridge.to_internal_weapon(w_name)
	else:
		current_selected_weapon = w_name
	
	if current_selected_weapon == "pistol":
		show_pistol()
		hide_brush()
		hide_flask()
	elif current_selected_weapon == "boomerang":
		hide_pistol()
		show_brush()
		hide_flask()
	elif current_selected_weapon == "grenade":
		hide_pistol()
		hide_brush()
		show_flask()
	else:
		hide_pistol()
		hide_brush()
		hide_flask()


func _update_flask_model(level: int) -> void:
	if _flask == null:
		return
	var game = get_node_or_null("/root/Game")
	var model_path := ""
	if game != null and game.has_method("get_weapon_model_path"):
		model_path = game.get_weapon_model_path("grenade", level)
	elif level == 2:
		model_path = "res://assets/candy_crusade/models/MWashGold2.glb"
	elif level == 3:
		model_path = "res://assets/candy_crusade/models/MWashBubble3.glb"
	else:
		model_path = "res://assets/candy_crusade/models/mouthwash_blast.glb"

	if model_path == "" or not (ResourceLoader.exists(model_path) or FileAccess.file_exists(model_path)):
		return

	var scene = load(model_path)
	if scene == null:
		return

	var old_model = _flask.get_node_or_null("Model")
	if old_model != null:
		old_model.name = "OldModel"
		old_model.queue_free()

	var new_model = scene.instantiate() as Node3D
	new_model.name = "Model"
	new_model.position = Vector3.ZERO
	new_model.rotation = Vector3.ZERO
	new_model.scale = Vector3.ONE
	if game != null and game.has_method("apply_model_materials"):
		game.apply_model_materials(new_model, model_path)
	_flask.add_child(new_model)


func _update_pistol_model(level: int) -> void:
	if _pistol == null:
		return
	var game = get_node_or_null("/root/Game")
	var model_path := ""
	if game != null and game.has_method("get_weapon_model_path"):
		model_path = game.get_weapon_model_path("pistol", level)
	elif level == 2:
		model_path = "res://assets/candy_crusade/models/PasteGold2.glb"
	elif level == 3:
		model_path = "res://assets/candy_crusade/models/PasteBubble3.glb"
	else:
		model_path = "res://assets/candy_crusade/models/toothpaste_pistol.glb"

	if model_path == "" or not (ResourceLoader.exists(model_path) or FileAccess.file_exists(model_path)):
		return

	var scene = load(model_path)
	if scene == null:
		return

	var target_transform := Transform3D(
		Vector3(0.2700249, -0.13522255, -0.9533107),
		Vector3(0.26560348, 0.96213526, -0.061242305),
		Vector3(0.9254947, -0.23666573, 0.2957164),
		Vector3(-1.03074, -0.34212065, -0.30092216)
	)
	var old_model = _pistol.get_node_or_null("Model")
	if old_model != null:
		target_transform = old_model.transform
		old_model.name = "OldModel"
		old_model.queue_free()

	var new_model = scene.instantiate() as Node3D
	new_model.name = "Model"
	new_model.transform = target_transform
	if game != null and game.has_method("apply_model_materials"):
		game.apply_model_materials(new_model, model_path)
	_pistol.add_child(new_model)


func _update_brush_model(level: int) -> void:
	if _brush == null:
		return
	var game = get_node_or_null("/root/Game")
	var model_path := ""
	if game != null and game.has_method("get_weapon_model_path"):
		model_path = game.get_weapon_model_path("boomerang", level)
	elif level == 2:
		model_path = "res://assets/candy_crusade/models/Goldbrushlvl2.glb"
	elif level == 3:
		model_path = "res://assets/candy_crusade/models/BubbleBrush.glb"
	else:
		model_path = "res://assets/candy_crusade/models/brush_boomerang.glb"

	if model_path == "" or not (ResourceLoader.exists(model_path) or FileAccess.file_exists(model_path)):
		return

	var scene = load(model_path)
	if scene == null:
		return

	var old_model = _brush.get_node_or_null("Model")
	if old_model != null:
		old_model.name = "OldModel"
		old_model.queue_free()

	var new_model = scene.instantiate() as Node3D
	new_model.name = "Model"
	new_model.position = Vector3.ZERO
	new_model.rotation = Vector3.ZERO
	new_model.scale = Vector3.ONE
	if game != null and game.has_method("apply_model_materials"):
		game.apply_model_materials(new_model, model_path)
	_brush.add_child(new_model)


func trigger_haptic_vibration(pattern_ms: Array = [60]):
	if OS.has_feature("web"):
		var js_code = "if (navigator && navigator.vibrate) { navigator.vibrate(" + str(pattern_ms) + "); }"
		JavaScriptBridge.eval(js_code)

func take_damage(amount: int) -> void:
	if health <= 0:
		return
	if has_active_shield():
		if absorb_hit("minion"):
			trigger_haptic_vibration([30, 40, 30])
			return
	var bridge = get_node_or_null("/root/GameBridge")

	if bridge != null:
		bridge.player_damaged = true
		amount = int(round(float(amount) * bridge.get_difficulty_damage_mult()))
	health = maxi(0, health - amount)
	health_changed.emit(health, max_health)
	_shake_time = 0.3
	trigger_haptic_vibration([80, 50, 80])
	if health <= 0:
		died.emit()

func reset_player() -> void:
	health = max_health
	health_changed.emit(health, max_health)
	_pressed = false
	_press_pending = false
	_pending_single_shot = false
	_swipe_locked = false
	_press_consumed = false
	_hold_shot_fired = false
	_shake_time = 0.0
	_camera.transform.origin = _camera_rest_position
	_camera.rotation_degrees = _camera_rest_rotation
	_reset_brush_transform()
	_reset_flask_transform()
	if is_instance_valid(_aim_reticle):
		_aim_reticle.visible = false
	_grenade_in_flight = false
	if is_instance_valid(_trajectory_mesh_instance):
		_trajectory_mesh_instance.visible = false
	_brush_in_flight = 0
	for item in _active_lassos:
		var root = item.get("root")
		if is_instance_valid(root):
			root.queue_free()
	_active_lassos.clear()
	check_auto_apply_shield()

func take_candy_hit() -> void:
	if absorb_hit("bonbon"):
		trigger_haptic_vibration([40, 30, 40])
		return
	_shake_time = 0.5
	trigger_haptic_vibration([120, 60, 120])
	var spawner = get_tree().get_first_node_in_group("spawner")
	if spawner and spawner.has_method("reduce_score"):
		spawner.reduce_score(5)


func apply_camera_shake(duration: float = 0.15) -> void:
	_shake_time = maxf(_shake_time, duration)


func _process(delta: float) -> void:
	_pistol_cooldown = maxf(_pistol_cooldown - delta, 0.0)
	# Camera shake
	if _shake_time > 0.0:
		_shake_time -= delta
		var offset = Vector3(randf_range(-0.06, 0.06), randf_range(-0.06, 0.06), 0)
		_camera.transform.origin = _camera_rest_position + offset
	else:
		_camera.transform.origin = _camera_rest_position

	# Fluoride Shield idle floating & subtle pulse
	if _has_shield and _shield_root != null and is_instance_valid(_shield_root):
		var st := Time.get_ticks_msec() * 0.002
		_shield_root.position.y = 0.45 + sin(st) * 0.015
		
	# Live grenade landing reticle while the downward pull-back is charging.
	_update_aim_reticle()

	# A released quick tap fires its single delayed shot now if no second tap
	# arrived in time to cancel it (a second tap clears _pending_single_shot
	# inside _begin_press, so a double tap never fires this shot).
	if _pending_single_shot and _now_secs() >= _single_shot_at:
		_pending_single_shot = false
		_last_tap_time = -1.0
		_fire_pistol_at(_single_shot_aim)
	# Clean up any lassos whose target has died or been knocked away from the floss
	for i in range(_active_lassos.size() - 1, -1, -1):
		var lasso: Dictionary = _active_lassos[i]
		var root = lasso.get("root")
		var tgt = lasso.get("target")
		
		if not is_instance_valid(root) or (root is Object and root.is_queued_for_deletion()):
			_active_lassos.remove_at(i)
			continue
			
		if not is_instance_valid(tgt) or (tgt is Object and tgt.is_queued_for_deletion()):
			if is_instance_valid(root):
				root.queue_free()
			_active_lassos.remove_at(i)
			continue
			
		if tgt.get("_dead") == true:
			if is_instance_valid(root):
				root.queue_free()
			_active_lassos.remove_at(i)
			continue
			
		var center: Vector3 = lasso.get("center", Vector3.ZERO)
		var max_dist: float = lasso.get("radius", 0.5)
		var tgt_flat := Vector3(tgt.global_position.x, 0.0, tgt.global_position.z)
		var center_flat := Vector3(center.x, 0.0, center.z)
		if tgt_flat.distance_to(center_flat) > max_dist:
			if is_instance_valid(root):
				root.queue_free()
			_active_lassos.remove_at(i)
			continue

	# Hold-to-fire: a press stays silent while pending; once TAP_DELAY elapses
	# while held it is a hold, and the pistol fires along the flat aim through
	# the current pointer (see SWIPE_LOCK_THRESHOLD) but only ONCE.
	if _pressed and not _swipe_locked and not _press_consumed:
		if _press_pending and _now_secs() - _press_started_at >= TAP_DELAY:
			_press_pending = false
		if not _press_pending and _pistol_cooldown <= 0.0 and not _hold_shot_fired:
			_hold_shot_fired = true
			fire_pistol()


## Wall-clock seconds, used for both the tap-delay and double-tap windows so
## press/release timing is consistent across mouse and touch.
func _now_secs() -> float:
	return Time.get_ticks_msec() / 1000.0


func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and not _pressed:
			_begin_press(event.position)
		elif not event.pressed and _pressed:
			_end_press(event.position)
	elif event is InputEventMouseMotion:
		_pointer_pos = event.position
		if _pressed:
			_drag_total = event.position - _press_pos
			_check_swipe_lock(event.position)
			_update_swipe_brush_viewmodel()
			_update_pullback_flask_viewmodel()
	elif event is InputEventScreenTouch:
		if event.index != 0:
			return
		if event.pressed and not _pressed:
			_begin_press(event.position)
		elif not event.pressed and _pressed:
			_end_press(event.position)
	elif event is InputEventScreenDrag and event.index == 0:
		_pointer_pos = event.position
		if _pressed:
			_drag_total = event.position - _press_pos
			_check_swipe_lock(event.position)
			_update_swipe_brush_viewmodel()
			_update_pullback_flask_viewmodel()


func show_pistol() -> void:
	if _pistol == null:
		return
	if _pistol_recoil != null and _pistol_recoil.is_valid():
		_pistol_recoil.kill()
	_pistol.visible = true
	_pistol.position = _pistol_rest_position
	_pistol.rotation_degrees = _pistol_rest_rotation
	hide_brush()
	hide_flask()


func hide_pistol() -> void:
	if _pistol == null:
		return
	if _pistol_recoil != null and _pistol_recoil.is_valid():
		_pistol_recoil.kill()
	_pistol.visible = false
	_pistol.position = _pistol_rest_position
	_pistol.rotation_degrees = _pistol_rest_rotation


func show_brush() -> void:
	if _brush == null:
		return
	if _brush_tween != null and _brush_tween.is_valid():
		_brush_tween.kill()
	_brush.position = _brush_rest_position
	_brush.rotation_degrees = _brush_rest_rotation
	_brush.scale = _brush_rest_scale
	if _brush_in_flight <= 0:
		_brush.visible = true
	else:
		_brush.visible = false
	hide_pistol()
	hide_flask()


func hide_brush() -> void:
	if _brush == null:
		return
	if _brush_tween != null and _brush_tween.is_valid():
		_brush_tween.kill()
	_brush.visible = false
	_brush.position = _brush_rest_position
	_brush.rotation_degrees = _brush_rest_rotation


func show_flask() -> void:
	if _flask == null:
		return
	if _flask_tween != null and _flask_tween.is_valid():
		_flask_tween.kill()
	if _flask_restore_tween != null and _flask_restore_tween.is_valid():
		_flask_restore_tween.kill()
	_flask.position = _flask_rest_position
	_flask.rotation_degrees = _flask_rest_rotation
	_flask.scale = _flask_rest_scale
	_flask.visible = true
	hide_pistol()
	hide_brush()


func hide_flask() -> void:
	if _flask == null:
		return
	if _flask_tween != null and _flask_tween.is_valid():
		_flask_tween.kill()
	if _flask_restore_tween != null and _flask_restore_tween.is_valid():
		_flask_restore_tween.kill()
	_flask.visible = false
	_flask.position = _flask_rest_position
	_flask.rotation_degrees = _flask_rest_rotation


func _update_pullback_flask_viewmodel() -> void:
	if _flask == null:
		return
	# When dragging downward, pull back the mouthwash flask toward the player
	if _drag_total.y >= 8.0:
		hide_pistol()
		hide_brush()
		_flask.visible = true
		var p: float = clampf((_drag_total.y - 8.0) / (GRENADE_MAX_PULL - 8.0), 0.0, 1.0)
		var shake := Vector3.ZERO
		if p >= 0.85:
			shake = Vector3(randf_range(-0.003, 0.003), randf_range(-0.003, 0.003), randf_range(-0.003, 0.003))
		# Pull backward slightly while staying low and tilting upright
		var offset := Vector3(-_drag_total.x * 0.0002, 0.015 * p, 0.035 * p) + shake
		_flask.position = _flask_rest_position + offset
		_flask.rotation_degrees = Vector3(_flask_rest_rotation.x + 22.0 * p, _flask_rest_rotation.y, _flask_rest_rotation.z)
	elif current_selected_weapon == "grenade":
		_flask.visible = true
		_flask.position = _flask_rest_position
		_flask.rotation_degrees = _flask_rest_rotation
	else:
		_flask.visible = false


func _reset_flask_transform() -> void:
	if _flask == null:
		return
	if current_selected_weapon != "grenade":
		_flask.visible = false
		return
	if _flask_tween != null and _flask_tween.is_valid():
		_flask_tween.kill()
	_flask_tween = _flask.create_tween()
	_flask_tween.set_parallel(true)
	_flask_tween.tween_property(_flask, "position", _flask_rest_position, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_flask_tween.tween_property(_flask, "rotation_degrees", _flask_rest_rotation, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _update_swipe_brush_viewmodel() -> void:
	if _brush == null or _brush_in_flight > 0:
		return
	# When dragging upward, brush raises upright facing camera in anticipation
	if _drag_total.y < -5.0:
		if _pistol != null and _pistol.visible:
			_pistol.visible = false
		_brush.visible = true
		
		var p: float = clampf(-_drag_total.y / GESTURE_THRESHOLD, 0.0, 1.0)
		var current_pitch: float = _brush_rest_rotation.x - 8.0 * p
		var current_pos: Vector3 = _brush_rest_position.lerp(_brush_rest_position + Vector3(0.01, 0.05, -0.04), p)
		
		_brush.position = current_pos
		_brush.rotation_degrees = Vector3(current_pitch, _brush_rest_rotation.y, _brush_rest_rotation.z)
	elif current_selected_weapon == "boomerang" and _brush_in_flight <= 0:
		_brush.position = _brush_rest_position
		_brush.rotation_degrees = _brush_rest_rotation


func _reset_brush_transform() -> void:
	if _brush == null or _brush_in_flight > 0:
		return
	if current_selected_weapon != "boomerang":
		_brush.visible = false
		return
	if _brush_tween != null and _brush_tween.is_valid():
		_brush_tween.kill()
	_brush_tween = _brush.create_tween()
	_brush_tween.set_parallel(true)
	_brush_tween.tween_property(_brush, "position", _brush_rest_position, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_brush_tween.tween_property(_brush, "rotation_degrees", _brush_rest_rotation, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _on_boomerang_returned() -> void:
	_brush_in_flight = maxi(0, _brush_in_flight - 1)
	if _brush_in_flight == 0 and current_selected_weapon == "boomerang" and _brush != null:
		_brush.visible = true
		# Spring catch bounce: snaps smoothly back to upright facing camera!
		_brush.position = _brush_rest_position + Vector3(0.02, -0.03, -0.03)
		_brush.rotation_degrees = Vector3(30.0, _brush_rest_rotation.y, _brush_rest_rotation.z)
		if _brush_tween != null and _brush_tween.is_valid():
			_brush_tween.kill()
		_brush_tween = _brush.create_tween()
		_brush_tween.set_parallel(true)
		_brush_tween.tween_property(_brush, "position", _brush_rest_position, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_brush_tween.tween_property(_brush, "rotation_degrees", _brush_rest_rotation, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Once the pointer leaves the ~20 px hold radius this press is a swipe/drag:
## the pistol stops firing immediately while drag/release keep feeding the
## gesture classification untouched.
func _check_swipe_lock(pos: Vector2) -> void:
	if not _swipe_locked and (pos - _press_pos).length() > SWIPE_LOCK_THRESHOLD:
		_swipe_locked = true


func _begin_press(pos: Vector2) -> void:
	var ray_start = _camera.project_ray_origin(pos)
	var ray_end = ray_start + _camera.project_ray_normal(pos) * 60.0
	var space_state = get_world_3d().direct_space_state

	# 1. Incoming boss candies interception (highest defense priority)
	if space_state != null:
		var candy_query = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
		candy_query.collision_mask = 2 # Projectiles / Enemies
		candy_query.collide_with_areas = true
		candy_query.collide_with_bodies = true
		var candy_hit = space_state.intersect_ray(candy_query)
		if candy_hit and candy_hit.get("collider") != null:
			var col = candy_hit.get("collider")
			if col.is_in_group("boss_candies") and col.has_method("pop"):
				col.pop()
				return

	var candies := get_tree().get_nodes_in_group("boss_candies")
	for candy in candies:
		var c_node := candy as Node3D
		if c_node != null and is_instance_valid(c_node):
			if _camera.is_position_behind(c_node.global_position):
				continue
			var c_screen := _camera.unproject_position(c_node.global_position)
			var pop_dist := 45.0 * maxf(1.0, c_node.scale.x * 0.8)
			if pos.distance_to(c_screen) < pop_dist:
				if c_node.has_method("pop"):
					c_node.pop()
				return

	# 2. Check if the player is aiming at / tapping an ENEMY (Minions or Boss).
	# If an enemy is in the ray, this tap is definitively an ATTACK, NOT a chest open!
	var tapped_enemy := false
	if space_state != null:
		var enemy_query = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
		enemy_query.collision_mask = 2 # Enemies (Minions, Boss)
		enemy_query.collide_with_bodies = true
		enemy_query.collide_with_areas = false
		var enemy_hit = space_state.intersect_ray(enemy_query)
		if enemy_hit and enemy_hit.get("collider") != null:
			var e_col = enemy_hit.get("collider")
			if e_col.is_in_group("minions") or e_col.is_in_group("boss") or e_col.is_in_group("bosses"):
				tapped_enemy = true

	# Also check screen proximity for minions: if player tapped near a minion, prioritize attacking the minion!
	if not tapped_enemy:
		var minions := get_tree().get_nodes_in_group("minions")
		for minion in minions:
			var m_node := minion as Node3D
			if m_node != null and is_instance_valid(m_node) and not m_node.get("_dead"):
				if _camera.is_position_behind(m_node.global_position):
					continue
				var m_screen := _camera.unproject_position(m_node.global_position + Vector3(0, 0.35, 0))
				if pos.distance_to(m_screen) < 42.0:
					tapped_enemy = true
					break

	# 3. Check for Molar Coins: tapping a coin collects it immediately without firing any pistol shot!
	if space_state != null:
		var coin_query = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
		coin_query.collision_mask = 4 # Pickups (coins & crates)
		coin_query.collide_with_areas = true
		coin_query.collide_with_bodies = false
		var coin_hit = space_state.intersect_ray(coin_query)
		if coin_hit and coin_hit.get("collider") != null:
			var col = coin_hit.get("collider")
			if (col.is_in_group("coins") or col.name.contains("Coin")) and col.has_method("collect"):
				if not col.get("_collected"):
					col.call("collect")
					return

	var active_coins := get_tree().get_nodes_in_group("coins")
	for coin in active_coins:
		var c_node := coin as Node3D
		if c_node != null and is_instance_valid(c_node):
			if c_node.get("_collected") == true:
				continue
			if _camera.is_position_behind(c_node.global_position):
				continue
			var c_screen := _camera.unproject_position(c_node.global_position + Vector3(0, 0.12, 0))
			if pos.distance_to(c_screen) < 40.0:
				if c_node.has_method("collect"):
					c_node.call("collect")
				return

	# 4. Only if the tap is NOT aimed at an enemy, check for unopened ammo chests
	if not tapped_enemy:
		# Direct 3D Raycast to closed ammo chest
		if space_state != null:
			var pickup_query = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
			pickup_query.collision_mask = 4 # Pickups (ammo crates)
			pickup_query.collide_with_areas = true
			pickup_query.collide_with_bodies = false
			var pickup_hit = space_state.intersect_ray(pickup_query)
			if pickup_hit and pickup_hit.get("collider") != null:
				var col = pickup_hit.get("collider")
				if (col.is_in_group("ammo_crates") or col.name.contains("Crate")) and col.has_method("collect"):
					if not col.get("_collected") and not col.get("_is_opening"):
						col.call("collect")
						return

		# Accurate screen-space tap for closed chests (tight 36px radius, ONLY closed chests)
		var crates := get_tree().get_nodes_in_group("ammo_crates")
		for crate in crates:
			var c_node := crate as Node3D
			if c_node != null and is_instance_valid(c_node):
				if c_node.get("_collected") == true or c_node.get("_is_opening") == true:
					continue
				if _camera.is_position_behind(c_node.global_position):
					continue
				var chest_center := c_node.global_position + Vector3(0, 0.18, 0)
				var c_screen := _camera.unproject_position(chest_center)
				if pos.distance_to(c_screen) < 36.0:
					if c_node.has_method("collect"):
						c_node.call("collect")
					return
		
	_pressed = true
	_press_pos = pos
	_drag_total = Vector2.ZERO
	_pointer_pos = pos
	_swipe_locked = false
	_press_consumed = false
	_hold_shot_fired = false
	_press_started_at = _now_secs()
	_press_pending = true
	# A second tap arriving within DOUBLE_TAP_WINDOW of the previous tap release
	# is a double tap: fire the floss lasso now, cancel any pending pistol shot,
	# and mark this tap consumed so neither tap fires a pistol projectile.
	var dt := _now_secs() - _last_tap_time
	var tap_dist := (pos - _last_tap_pos).length()
	if _last_tap_time > 0.0 and dt <= DOUBLE_TAP_WINDOW and tap_dist <= DOUBLE_TAP_MAX_DISTANCE:
		_pending_single_shot = false
		_press_pending = false
		_press_consumed = true
		_last_tap_time = -1.0
		_reset_brush_transform()
		_reset_flask_transform()
		throw_lasso(pos)
		return


func _end_press(pos: Vector2) -> void:
	_pressed = false
	_drag_total = pos - _press_pos
	if _press_consumed:
		_reset_brush_transform()
		_reset_flask_transform()
		return
	
	# Upward swipe (at least GESTURE_THRESHOLD = 50px) triggers Boomerang Toothbrush
	if _drag_total.y <= -GESTURE_THRESHOLD or (_drag_total.length() >= GESTURE_THRESHOLD and _drag_total.y < -30.0):
		_reset_flask_transform()
		_press_pending = false
		_pending_single_shot = false
		throw_boomerang()
	# Pulling downward triggers Mouthwash Slingshot catapult
	elif _drag_total.y >= GESTURE_THRESHOLD:
		_reset_brush_transform()
		_press_pending = false
		_pending_single_shot = false
		throw_grenade()
	else:
		_reset_flask_transform()
		_reset_brush_transform()
		# Direct tap / release ALWAYS aims and fires the paste pistol at the tapped spot
		if _press_pending and not _swipe_locked:
			_press_pending = false
			_last_tap_time = _now_secs()
			_last_tap_pos = pos
			_single_shot_at = _last_tap_time + TAP_DELAY
			_single_shot_aim = pos
			_pending_single_shot = true


## Hold-fire entry: fires along the current pointer aim.
func fire_pistol() -> void:
	_fire_pistol_at(_pointer_pos)


## Fires exactly one pistol projectile aimed through screen position aim_pos
## (the live pointer for hold-fire, the stored release point for the delayed
## single-tap shot) and starts the cooldown.
func _fire_pistol_at(aim_pos: Vector2) -> void:
	var bridge = get_node_or_null("/root/GameBridge")
	if bridge != null and bridge.is_weapon_locked("paste"):
		return
	var game = get_node_or_null("/root/Game")
	if game != null:
		if not game.can_fire_weapon("pistol"):
			_notify_out_of_ammo("Toothpaste Tubes")
			return
		game.consume_ammo("pistol")

	_pistol_cooldown = PISTOL_COOLDOWN
	set_selected_weapon("pistol")
	weapon_activated.emit("pistol")

	# Gun remains fixed facing the front on the lower-right of the screen
	_pistol_rest_position = Vector3(0.26, -0.18, -0.52)
	_pistol_rest_rotation = Vector3(15.0, -12.0, -10.0)
	_muzzle.position = Vector3(0.16, -0.12, -0.63)

	var shot := projectile_scene.instantiate() as Node3D
	if shot == null:
		return
	var container := _container()
	container.add_child(shot)
	shot.global_position = _muzzle.global_position

	if _pistol_recoil != null and _pistol_recoil.is_valid():
		_pistol_recoil.kill()
	_pistol.position = _pistol_rest_position
	_pistol.rotation_degrees = _pistol_rest_rotation
	_pistol.visible = true
	hide_brush()
	_pistol_recoil = _pistol.create_tween()
	_pistol_recoil.set_parallel(true)
	# Move back (positional kick scaled to pistol size, snappy recovery)
	_pistol_recoil.tween_property(_pistol, "position", _pistol_rest_position + Vector3(0, 0.015, 0.08), 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_pistol_recoil.tween_property(_pistol, "position", _pistol_rest_position, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).set_delay(0.07)
	# Tilt backward (angular kick)
	var kick_rot := _pistol_rest_rotation + Vector3(18.0, 0.0, 0.0)
	_pistol_recoil.tween_property(_pistol, "rotation_degrees", kick_rot, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_pistol_recoil.tween_property(_pistol, "rotation_degrees", _pistol_rest_rotation, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).set_delay(0.07)

	# Calculate true 3D flight direction straight toward tapped point/enemy
	var aim_dir := _pistol_aim_dir_at(aim_pos)
	var p_lvl: int = int(game.get("pistol_level")) if game != null else 1
	shot.call("setup", aim_dir, p_lvl)


## Calculates the 3D world target corresponding to the tapped screen position.
## Prioritizes direct enemy raycast, then minion-height horizontal plane (Y=0.35),
## and falls back to a forward camera ray for horizon/sky taps.
func _aim_target_world(screen_pos: Vector2) -> Vector3:
	var ray_origin := _camera.project_ray_origin(screen_pos)
	var ray_dir := _camera.project_ray_normal(screen_pos)
	
	# 1. Direct hit on an enemy
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_dir * 80.0)
	query.collision_mask = 2 # Layer 2: Enemies
	var hit := space_state.intersect_ray(query)
	if hit and hit.get("collider") != null:
		return hit.get("position", ray_origin + ray_dir * 80.0)
	
	# 2. Intersection with minion center height plane (Y = 0.35)
	var target_y := 0.35
	if absf(ray_dir.y) > 0.0001:
		var t := (target_y - ray_origin.y) / ray_dir.y
		if t > 0.0:
			return ray_origin + ray_dir * t
	
	# 3. Tap near or above horizon
	return ray_origin + ray_dir * 45.0


func _pistol_aim_dir_at(screen_pos: Vector2) -> Vector3:
	var muzzle_pos := _muzzle.global_position
	var target := _aim_target_world(screen_pos)
	var dir := target - muzzle_pos
	if dir.length_squared() >= 0.001:
		return dir.normalized()
	return Vector3(0, 0, -1)


func _flat_pistol_dir() -> Vector3:
	return _pistol_aim_dir_at(_pointer_pos)


func _flat_pistol_dir_at(screen_pos: Vector2) -> Vector3:
	return _pistol_aim_dir_at(screen_pos)


## The world point where the camera ray through a screen position meets the
## minion-height horizontal plane (Y = 0.35).
func _plane_crossing(screen_pos: Vector2) -> Vector3:
	var origin := _camera.project_ray_origin(screen_pos)
	var ray := _camera.project_ray_normal(screen_pos)
	if absf(ray.y) <= 0.0001:
		return Vector3.ZERO
	var target_y := 0.35
	var t := (target_y - origin.y) / ray.y
	if t <= 0.0:
		return Vector3.ZERO
	return origin + ray * t


func throw_boomerang() -> void:
	hide_pistol()
	var bridge = get_node_or_null("/root/GameBridge")
	if bridge != null and bridge.is_weapon_locked("brush"):
		_reset_brush_transform()
		return
	var game = get_node_or_null("/root/Game")
	if game != null:
		if not game.can_fire_weapon("boomerang"):
			var a_name := "Brushes"
			if bridge != null and bridge.get_ammo_key_for_weapon("brush") == "battery":
				a_name = "Battery"
			_notify_out_of_ammo(a_name)
			_reset_brush_transform()
			return
		game.consume_ammo("boomerang")

	set_selected_weapon("boomerang")
	weapon_activated.emit("boomerang")
	if boomerang_scene == null:
		_reset_brush_transform()
		return

	# Hide the left-hand brush viewmodel as it takes flight as the projectile!
	if _brush != null:
		_brush.visible = false

	var boomerang := boomerang_scene.instantiate() as Node3D
	if boomerang == null:
		_reset_brush_transform()
		return
	var container := _container()
	container.add_child(boomerang)

	# Launch from brush X/Z position, dynamically leveled to current enemy/lane height
	var flight_height := _get_boomerang_flight_height()
	var brush_x: float = _brush.global_position.x if _brush != null else 0.0
	var brush_z: float = _brush.global_position.z if _brush != null else 0.0
	var spawn_pos := Vector3(brush_x, flight_height, brush_z)
	boomerang.global_position = spawn_pos
	_brush_in_flight += 1

	boomerang.call("setup", _boomerang_end_point(flight_height), spawn_pos)

	var finished := false
	var on_finish := func(_b = null):
		if finished:
			return
		finished = true
		_on_boomerang_returned()
	if boomerang.has_signal("returned"):
		boomerang.connect("returned", on_finish, CONNECT_ONE_SHOT)
	boomerang.tree_exited.connect(on_finish, CONNECT_ONE_SHOT)


func _get_boomerang_flight_height() -> float:
	# 1. Target active minions' torso level
	var minions := get_tree().get_nodes_in_group("minions")
	var valid_y: Array[float] = []
	for m in minions:
		if is_instance_valid(m) and not m.get("_dead"):
			valid_y.append(m.global_position.y)
	if not valid_y.is_empty():
		valid_y.sort()
		var median_y: float = valid_y[valid_y.size() / 2]
		return median_y + 0.22

	# 2. Target active boss torso level
	var bosses := get_tree().get_nodes_in_group("bosses")
	for b in bosses:
		if is_instance_valid(b) and not b.get("_dead"):
			return b.global_position.y + 0.45

	# 3. Raycast down to lane surface in front of player
	var space_state := get_world_3d().direct_space_state
	if space_state != null:
		var q := PhysicsRayQueryParameters3D.create(Vector3(0, 5.0, -4.0), Vector3(0, -5.0, -4.0))
		q.collision_mask = 1
		var hit := space_state.intersect_ray(q)
		if hit and hit.has("position"):
			return hit["position"].y + 0.24

	return BOOMERANG_FLIGHT_HEIGHT


## The outbound target of the toothbrush: aims through the 3D world target
## corresponding to the swipe release position (prioritizing direct enemy hit,
## then lane ground plane), extending to the far end of the minion lane
## (Z <= -14.0) so it never reverses prematurely or flies off-screen into walls.
func _boomerang_end_point(flight_height: float = 0.46) -> Vector3:
	var brush_x: float = _brush.global_position.x if _brush != null else 0.0
	var brush_z: float = _brush.global_position.z if _brush != null else 0.0
	var start_pos := Vector3(brush_x, flight_height, brush_z)
	var release_screen := _press_pos + _drag_total
	
	# 1. 3D world target point aimed by the swipe release
	var target_3d := _aim_target_world(release_screen)
	
	# 2. Horizontal flight direction from launcher through the aimed point
	var aim_dir := target_3d - start_pos
	aim_dir.y = 0.0
	if aim_dir.length_squared() >= 0.001:
		aim_dir = aim_dir.normalized()
	else:
		aim_dir = Vector3(0, 0, -1)
	
	# Ensure the boomerang ALWAYS flies forward down -Z (never backward or purely sideways)
	if aim_dir.z >= -0.15:
		aim_dir.z = -1.0
		aim_dir = aim_dir.normalized()
		
	# Moderate lateral angle so a swipe aimed at a lane hits that lane without flying off-screen into walls
	# Lane width is ~3.6m (±1.8m) over 14m distance: clamp lateral ratio |X/Z| to <= 0.40
	if absf(aim_dir.x) > 0.40:
		aim_dir.x = signf(aim_dir.x) * 0.40
		aim_dir.z = -sqrt(maxf(1.0 - aim_dir.x * aim_dir.x, 0.1))
	
	# 3. Fly down the full length of the lane to the cave threshold (Z <= -14.0)
	var travel_dist := 18.0
	var end_pt := start_pos + aim_dir * travel_dist
	end_pt.y = flight_height
	if end_pt.z > -14.0:
		end_pt.z = -14.0
	return end_pt


func throw_grenade() -> void:
	hide_pistol()
	hide_brush()
	set_selected_weapon("grenade")
	var bridge = get_node_or_null("/root/GameBridge")
	if bridge != null and bridge.is_weapon_locked("wash"):
		return
	var game = get_node_or_null("/root/Game")
	if game != null:
		if not game.can_fire_weapon("grenade"):
			_notify_out_of_ammo("Mouthwash Vials")
			return
		game.consume_ammo("grenade")

	weapon_activated.emit("grenade")
	if grenade_scene == null:
		return
	var grenade := grenade_scene.instantiate() as Node3D
	if grenade == null:
		return
	var container := _container()
	container.add_child(grenade)

	var info := _calculate_grenade_trajectory()
	var launch_pos: Vector3 = info["launch_pos"]
	var impulse: Vector3 = info["impulse"]
	var landing_pos: Vector3 = info["landing_pos"]
	var duration: float = info["duration"]

	# Keep the bullseye visible at the target landing point until impact!
	var reticle := _ensure_aim_reticle()
	if reticle != null:
		reticle.global_position = landing_pos
		reticle.visible = true
	_grenade_in_flight = true

	var on_exploded := func(_p = null):
		_grenade_in_flight = false
		if is_instance_valid(_aim_reticle):
			_aim_reticle.visible = false

	if grenade.has_signal("exploded_at"):
		grenade.connect("exploded_at", on_exploded, CONNECT_ONE_SHOT)
	grenade.tree_exited.connect(on_exploded, CONNECT_ONE_SHOT)

	# Launch mouthwash directly along the exact trajectory arc to the center of the bullseye dot!
	if grenade.has_method("setup_trajectory"):
		grenade.call("setup_trajectory", launch_pos, impulse, landing_pos, duration, GRENADE_GRAVITY)
	else:
		grenade.global_position = launch_pos
		grenade.call("setup", impulse)

	# Fling the viewmodel flask forward and briefly hide it
	if _flask != null:
		if _flask_tween != null and _flask_tween.is_valid():
			_flask_tween.kill()
		_flask_tween = _flask.create_tween()
		_flask_tween.tween_property(_flask, "position", _flask_rest_position + Vector3(0, 0.05, -0.2), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_flask_tween.tween_callback(func():
			_flask.visible = false
		)
		if _flask_restore_tween != null and _flask_restore_tween.is_valid():
			_flask_restore_tween.kill()
		_flask_restore_tween = create_tween()
		_flask_restore_tween.tween_interval(0.4)
		_flask_restore_tween.tween_callback(func():
			if current_selected_weapon == "grenade" and _flask != null:
				_flask.position = _flask_rest_position
				_flask.rotation_degrees = _flask_rest_rotation
				_flask.visible = true
		)


func _get_grenade_pull_ratio() -> float:
	var pull := maxf(_drag_total.y - GESTURE_THRESHOLD, 0.0)
	return clampf(pull / (GRENADE_MAX_PULL - GESTURE_THRESHOLD), 0.0, 1.0)


func _get_grenade_throw_impulse() -> Vector3:
	var p := _get_grenade_pull_ratio()
	# Smooth continuous parabolic impulse across full lane length
	var v_up := lerpf(2.8, 7.6, p)
	var v_fwd := lerpf(3.5, 15.0, p)
	# Continuous lateral steering: dragging left throws right, dragging right throws left
	var v_x := clampf(-_drag_total.x * 0.04, -5.0, 5.0)
	return Vector3(v_x, v_up, -v_fwd)


func throw_lasso(screen_pos: Vector2) -> void:
	hide_pistol()
	hide_brush()
	set_selected_weapon("lasso")
	var bridge = get_node_or_null("/root/GameBridge")
	if bridge != null and bridge.is_weapon_locked("floss"):
		return
	var game = get_node_or_null("/root/Game")
	if game != null:
		if not game.can_fire_weapon("lasso"):
			_notify_out_of_ammo("Floss Spools")
			return
		game.consume_ammo("lasso")

	weapon_activated.emit("lasso")

	var floss_lvl := 1
	if game != null:
		floss_lvl = clampi(int(game.get("floss_level")), 1, 3)

	var max_targets := 1
	if floss_lvl == 2:
		max_targets = 3
	elif floss_lvl >= 3:
		max_targets = 5

	var candidates: Array = get_tree().get_nodes_in_group("minions") + get_tree().get_nodes_in_group("bosses")
	var scored_unfrozen: Array[Dictionary] = []
	var scored_any: Array[Dictionary] = []
	
	for candidate in candidates:
		var enemy := candidate as Node3D
		if enemy == null or not is_instance_valid(enemy):
			continue
		if enemy.get("_dead") == true:
			continue
		var enemy_pos := enemy.global_position + Vector3(0, 0.3, 0)
		if _camera.is_position_behind(enemy_pos):
			continue
		var enemy_screen := _camera.unproject_position(enemy_pos)
		var d := screen_pos.distance_to(enemy_screen)
		
		var already_frozen: bool = false
		if enemy.get("_frozen_time") != null and enemy.get("_frozen_time") > 0.0:
			already_frozen = true
			
		if not already_frozen:
			scored_unfrozen.append({"node": enemy, "dist": d})
		else:
			scored_any.append({"node": enemy, "dist": d})

	scored_unfrozen.sort_custom(func(a, b): return a["dist"] < b["dist"])
	scored_any.sort_custom(func(a, b): return a["dist"] < b["dist"])

	var targets_to_hit: Array[Node3D] = []
	for item in scored_unfrozen:
		if targets_to_hit.size() < max_targets:
			targets_to_hit.append(item["node"])
			
	# If fewer unfrozen targets than max, fill remaining slots with already-frozen targets to re-freeze
	if targets_to_hit.size() < max_targets:
		for item in scored_any:
			if targets_to_hit.size() < max_targets and not targets_to_hit.has(item["node"]):
				targets_to_hit.append(item["node"])

	if targets_to_hit.is_empty():
		var target_pos = _plane_crossing(screen_pos)
		if target_pos == Vector3.ZERO:
			target_pos = _camera.project_ray_origin(screen_pos) + _camera.project_ray_normal(screen_pos) * 50.0
		_animate_lasso(target_pos, null, floss_lvl)
	else:
		for tgt in targets_to_hit:
			_animate_lasso(tgt.global_position, tgt, floss_lvl)


func _animate_lasso(end_pos: Vector3, target: Node3D, level: int = 1) -> void:
	var container := _container()
	var start_pos: Vector3 = _action_origin.global_position
	
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	match level:
		1:
			material.albedo_color = Color(1.0, 1.0, 1.0, 1.0) # Pure white dental floss
		2:
			material.albedo_color = Color(1.0, 0.84, 0.22, 1.0) # Golden floss
		3:
			material.albedo_color = Color(0.25, 0.78, 1.0, 1.0) # Radiant blue floss
		_:
			material.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	
	var wrap_root := Node3D.new()
	container.add_child(wrap_root)
	
	# Clean up on target removal or root exit
	if target != null and is_instance_valid(target):
		target.tree_exited.connect(func():
			if is_instance_valid(wrap_root):
				wrap_root.queue_free()
		)
	wrap_root.tree_exited.connect(func():
		for i in range(_active_lassos.size() - 1, -1, -1):
			if _active_lassos[i].get("root") == wrap_root:
				_active_lassos.remove_at(i)
	)

	# Main connecting beam
	var beam_cyl := CylinderMesh.new()
	beam_cyl.top_radius = LASSO_THICKNESS
	beam_cyl.bottom_radius = LASSO_THICKNESS
	beam_cyl.height = 0.001
	beam_cyl.material = material
	
	var beam_mesh := MeshInstance3D.new()
	beam_mesh.mesh = beam_cyl
	wrap_root.add_child(beam_mesh)
	
	var update_beam = func(pA: Vector3, pB: Vector3):
		if not is_instance_valid(beam_mesh):
			return
		var dist := pA.distance_to(pB)
		if dist < 0.001:
			beam_cyl.height = 0.001
			return
		beam_cyl.height = dist
		var dir := (pB - pA).normalized()
		var up := Vector3.UP
		if absf(dir.dot(up)) > 0.999:
			up = Vector3.FORWARD
		beam_mesh.global_position = pA + dir * (dist * 0.5)
		beam_mesh.look_at(pA + dir * dist, up)
		beam_mesh.rotate_object_local(Vector3.RIGHT, PI / 2.0)

	if target != null and is_instance_valid(target):
		var is_boss: bool = target.is_in_group("bosses") or target.is_in_group("boss") or target.name.contains("BlueCandor") or target.name.contains("Boss")
		var s_factor: float = (target.scale.x / 0.35) if not is_boss else target.scale.x
		var ring_y_offset: float = (0.90 * s_factor) if is_boss else (0.18 * s_factor)
		var rx: float = (1.10 * s_factor) if is_boss else (0.34 * s_factor)
		var rz: float = (1.10 * s_factor) if is_boss else (0.28 * s_factor)
		var max_dist: float = (2.5 * s_factor) if is_boss else (1.5 * s_factor)
		
		var initial_target_pos := target.global_position
		var initial_dist := start_pos.distance_to(initial_target_pos)
		var reach_time: float = clampf(remap(initial_dist, 3.5, 12.0, 0.4, 0.8), 0.4, 0.8)
		
		var fly_tween := wrap_root.create_tween()
		var fly_step = func(p: float):
			if not is_instance_valid(wrap_root):
				return
			var cur_pos := target.global_position if (target != null and is_instance_valid(target)) else initial_target_pos
			var anchor := cur_pos + Vector3(0.0, ring_y_offset, rz)
			var cur_tip := start_pos.lerp(anchor, p)
			update_beam.call(start_pos, cur_tip)
			
		fly_tween.tween_method(fly_step, 0.001, 1.0, reach_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		
		fly_tween.tween_callback(func():
			if not is_instance_valid(wrap_root):
				return
			if target == null or not is_instance_valid(target) or target.get("_dead") == true:
				wrap_root.queue_free()
				return
				
			# 1. Damage target upon contact & freeze in place so floss wraps around it
			if level >= 3:
				if is_boss:
					target.call("take_damage", 20.0)
					if target.has_method("freeze"):
						target.call("freeze", FREEZE_DURATION)
				else:
					# Level 3 Minion: Freeze for 2.2s so minion stays in place while wrapped
					if target.has_method("freeze"):
						target.call("freeze", 2.2)
					target.call("take_damage", 1.0)
			else:
				var floss_dmg: float = 1.0 if level == 1 else 3.0
				target.call("take_damage", floss_dmg)
				if target.has_method("freeze"):
					target.call("freeze", FREEZE_DURATION)
				
			# 2. Lock final beam position
			var frozen_pos := target.global_position
			var front_edge := frozen_pos + Vector3(0.0, ring_y_offset, rz)
			update_beam.call(start_pos, front_edge)
			
			# 3. Register active lasso
			_active_lassos.append({
				"root": wrap_root,
				"target": target,
				"center": frozen_pos,
				"radius": max_dist
			})
			
			# 4. Generate the snug 24-segment loop around the minion's body
			var loop_pts: Array[Vector3] = [front_edge]
			for j in range(1, 25):
				var frac := float(j) / 24.0
				var theta := frac * TAU + (PI / 2.0)
				loop_pts.append(Vector3(frozen_pos.x + cos(theta) * rx, frozen_pos.y + ring_y_offset, frozen_pos.z + sin(theta) * rz))
			loop_pts.append(front_edge)
			
			# 5. Build and sequentially animate loop segments
			var loop_tween := wrap_root.create_tween()
			for j in range(loop_pts.size() - 1):
				var pA := loop_pts[j]
				var pB := loop_pts[j + 1]
				var seg_len := pA.distance_to(pB)
				if seg_len < 0.001:
					continue
				var seg_dir := (pB - pA).normalized()
				var seg_cyl := CylinderMesh.new()
				seg_cyl.top_radius = LASSO_THICKNESS
				seg_cyl.bottom_radius = LASSO_THICKNESS
				seg_cyl.height = 0.001
				seg_cyl.material = material
				
				var seg_mesh := MeshInstance3D.new()
				seg_mesh.mesh = seg_cyl
				wrap_root.add_child(seg_mesh)
				
				var seg_up := Vector3.UP
				if absf(seg_dir.dot(seg_up)) > 0.999:
					seg_up = Vector3.FORWARD
				seg_mesh.global_position = pA
				seg_mesh.look_at(pA + seg_dir * maxf(seg_len, 0.1), seg_up)
				seg_mesh.rotate_object_local(Vector3.RIGHT, PI / 2.0)
				
				var seg_step = func(l: float, _m: MeshInstance3D, _c: CylinderMesh, _pA: Vector3, _d: Vector3):
					if is_instance_valid(_m):
						_c.height = l
						_m.global_position = _pA + _d * (l * 0.5)
						
				loop_tween.tween_method(seg_step.bind(seg_mesh, seg_cyl, pA, seg_dir), 0.001, seg_len, LASSO_SPIN_TIME / 24.0)
				
			# 6. Hold duration:
			# For Level 3: minion stays wrapped in place for 2.0s total, then bursts into tiny little squares!
			if level >= 3 and not is_boss:
				var hold_time := maxf(2.0 - LASSO_SPIN_TIME, 0.1)
				loop_tween.tween_interval(hold_time)
				loop_tween.tween_callback(func():
					if target != null and is_instance_valid(target) and not target.get("_dead"):
						if target.has_method("burst_into_tiny_squares"):
							target.burst_into_tiny_squares()
						else:
							target.call("take_damage", 9999.0)
					if is_instance_valid(wrap_root):
						wrap_root.queue_free()
				)
			else:
				# Level 1 & 2 standard hold and fade
				loop_tween.tween_interval(maxf(FREEZE_DURATION - LASSO_SPIN_TIME - LASSO_FADE_TIME, 0.0))
				loop_tween.tween_property(material, "albedo_color:a", 0.0, LASSO_FADE_TIME)
				loop_tween.tween_callback(wrap_root.queue_free)
		)
	else:
		# Missed shot
		var miss_dist := start_pos.distance_to(end_pos)
		var miss_reach: float = clampf(remap(miss_dist, 3.5, 12.0, 0.4, 0.8), 0.4, 0.8)
		var miss_tween := wrap_root.create_tween()
		var miss_step = func(p: float):
			if not is_instance_valid(wrap_root):
				return
			var cur_tip := start_pos.lerp(end_pos, p)
			update_beam.call(start_pos, cur_tip)
		miss_tween.tween_method(miss_step, 0.001, 1.0, miss_reach).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		miss_tween.tween_property(material, "albedo_color:a", 0.0, 0.2)
		miss_tween.tween_callback(wrap_root.queue_free)



## Turns the completed swipe (press -> release) into a flat 3D fallback
## direction: 2D swipe X maps to world X (left/right across the lane) and 2D
## swipe Y maps to world Z (swiping up the screen throws forward down -Z).
## Y is always 0 so the toothbrush flies parallel to the ground at muzzle
## height and never climbs into the sky. Used only when the release ray does
## not cross the muzzle-height plane.
func _boomerang_direction() -> Vector3:
	var forward_px := maxf(-_drag_total.y, 1.0)
	var lateral_px := _drag_total.x
	var dir := Vector3(lateral_px, 0.0, -forward_px)
	if dir.length_squared() < 0.0001:
		dir = Vector3(0, 0, -1)
	return dir.normalized()


func _get_mouthwash_launch_pos() -> Vector3:
	if _flask != null and is_instance_valid(_flask):
		return _flask.global_position
	return _camera.to_global(Vector3(0.0, -0.10, -0.50))


func _calculate_grenade_trajectory() -> Dictionary:
	var impulse := _get_grenade_throw_impulse()
	var launch_pos := _get_mouthwash_launch_pos()
	var v_y := impulse.y
	var h := maxf(launch_pos.y - RETICLE_HEIGHT, 0.01)
	var t := (v_y + sqrt(v_y * v_y + 2.0 * GRENADE_GRAVITY * h)) / GRENADE_GRAVITY
	
	var nominal_land := Vector3(launch_pos.x + impulse.x * t, RETICLE_HEIGHT, launch_pos.z + impulse.z * t)
	
	# Raycast downward at the landing (X, Z) against the environment to find exact floor height
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(Vector3(nominal_land.x, 6.0, nominal_land.z), Vector3(nominal_land.x, -3.0, nominal_land.z))
	query.collision_mask = 1 # Environment layer
	var hit := space_state.intersect_ray(query)
	var final_land := nominal_land
	if hit and hit.collider != null:
		var floor_y: float = hit.position.y
		final_land.y = floor_y + 0.02 # Rest right on top of floor surface
		var floor_h := maxf(launch_pos.y - floor_y, 0.01)
		t = (v_y + sqrt(v_y * v_y + 2.0 * GRENADE_GRAVITY * floor_h)) / GRENADE_GRAVITY
		final_land.x = launch_pos.x + impulse.x * t
		final_land.z = launch_pos.z + impulse.z * t
	
	return {
		"launch_pos": launch_pos,
		"impulse": impulse,
		"landing_pos": final_land,
		"duration": t
	}


func _grenade_land_point(_tier: int = 0) -> Vector3:
	var info := _calculate_grenade_trajectory()
	return info["landing_pos"]


## Shows the landing reticle while a downward pull-back is charging and hides
## it at all other times. Draws a single continuous, smooth arched line/ribbon
## from the mouthwash bottle directly to the exact bullseye center dot.
func _update_aim_reticle() -> void:
	var reticle := _ensure_aim_reticle()
	if reticle == null:
		return
	var charging := _pressed and _drag_total.y >= GESTURE_THRESHOLD
	if not charging:
		if not _grenade_in_flight:
			reticle.visible = false
		if is_instance_valid(_trajectory_mesh_instance):
			_trajectory_mesh_instance.visible = false
		return
	hide_pistol()
	hide_brush()
	
	var info := _calculate_grenade_trajectory()
	var launch_pos: Vector3 = info["launch_pos"]
	var impulse: Vector3 = info["impulse"]
	var point: Vector3 = info["landing_pos"]
	var total_time: float = info["duration"]
	
	reticle.global_position = point
	reticle.visible = true

	var game = get_node_or_null("/root/Game")
	var mw_lvl := 1
	if game != null:
		if "grenade_level" in game:
			mw_lvl = clampi(int(game.get("grenade_level")), 1, 3)
		elif "wash_level" in game:
			mw_lvl = clampi(int(game.get("wash_level")), 1, 3)
	var bridge = get_node_or_null("/root/GameBridge")
	if bridge != null and bridge.has_method("get_weapon_level"):
		var b_lvl: int = int(bridge.get_weapon_level("wash"))
		if b_lvl <= 0:
			b_lvl = int(bridge.get_weapon_level("grenade"))
		if b_lvl > 0:
			mw_lvl = clampi(b_lvl, 1, 3)

	var arc_col: Color
	var main_col: Color
	var inner_col: Color
	var dot_col: Color
	var disc_col: Color

	match mw_lvl:
		1:
			# 1 is Blue
			arc_col = Color(0.2, 0.8, 1.0, 0.88)
			main_col = Color(0.15, 0.75, 1.0, 0.95)
			inner_col = Color(0.35, 0.88, 1.0, 0.95)
			dot_col = Color(0.7, 0.95, 1.0, 1.0)
			disc_col = Color(0.15, 0.75, 1.0, 0.18)
		2:
			# 2 is Gold
			arc_col = Color(1.0, 0.84, 0.28, 0.92)
			main_col = Color(1.0, 0.82, 0.22, 0.95)
			inner_col = Color(1.0, 0.92, 0.45, 0.95)
			dot_col = Color(1.0, 0.98, 0.75, 1.0)
			disc_col = Color(1.0, 0.84, 0.25, 0.22)
		3:
			# 3 is Sparkly Blue (radiant aqua with animated diamond shimmer pulse)
			var shimmer: float = (sin(Time.get_ticks_msec() * 0.009) * 0.5 + 0.5) * 0.25
			arc_col = Color(0.25 + shimmer, 0.92, 1.0, 0.96)
			main_col = Color(0.2 + shimmer, 0.9, 1.0, 0.98)
			inner_col = Color(0.6 + shimmer * 0.5, 1.0, 1.0, 1.0)
			dot_col = Color(0.9, 1.0, 1.0, 1.0)
			disc_col = Color(0.2, 0.92, 1.0, 0.28)
		_:
			arc_col = Color(0.2, 0.8, 1.0, 0.88)
			main_col = Color(0.15, 0.75, 1.0, 0.95)
			inner_col = Color(0.35, 0.88, 1.0, 0.95)
			dot_col = Color(0.7, 0.95, 1.0, 1.0)
			disc_col = Color(0.15, 0.75, 1.0, 0.18)

	if _trajectory_material != null:
		_trajectory_material.albedo_color = arc_col

	var blast_r := 1.1
	match mw_lvl:
		1: blast_r = 1.1
		2: blast_r = 2.0
		3: blast_r = 3.2

	var splash := reticle.get_node_or_null("SplashDisc") as MeshInstance3D
	if splash != null:
		splash.scale = Vector3(blast_r, 1.0, blast_r)
		if splash.mesh != null and splash.mesh.material is StandardMaterial3D:
			(splash.mesh.material as StandardMaterial3D).albedo_color = disc_col
	var outer := reticle.get_node_or_null("OuterRing") as MeshInstance3D
	if outer != null:
		outer.scale = Vector3(blast_r, 1.0, blast_r)
		if outer.mesh != null and outer.mesh.material is StandardMaterial3D:
			(outer.mesh.material as StandardMaterial3D).albedo_color = main_col
	var inner := reticle.get_node_or_null("InnerRing") as MeshInstance3D
	if inner != null:
		inner.scale = Vector3(blast_r, 1.0, blast_r)
		if inner.mesh != null and inner.mesh.material is StandardMaterial3D:
			(inner.mesh.material as StandardMaterial3D).albedo_color = inner_col
	var dot := reticle.get_node_or_null("CenterDot") as MeshInstance3D
	if dot != null and dot.mesh != null and dot.mesh.material is StandardMaterial3D:
		(dot.mesh.material as StandardMaterial3D).albedo_color = dot_col
	var arrow_target := reticle.get_node_or_null("TargetArrow") as MeshInstance3D
	if arrow_target != null:
		if arrow_target.mesh != null and arrow_target.mesh.material is StandardMaterial3D:
			(arrow_target.mesh.material as StandardMaterial3D).albedo_color = main_col
		var horiz_dir := Vector3(impulse.x, 0, impulse.z)
		if horiz_dir.length_squared() > 0.01:
			var norm_dir := horiz_dir.normalized()
			arrow_target.position = -norm_dir * (blast_r * 0.6)
			var look_targ := arrow_target.position + norm_dir
			arrow_target.look_at(look_targ, Vector3.UP)
			arrow_target.rotate_object_local(Vector3.RIGHT, -PI * 0.5)

	# Update smooth continuous arched trajectory ribbon directly to the center of the bullseye
	var arc := _ensure_trajectory_arc()
	if arc != null and _immediate_mesh != null:
		arc.visible = true
		_immediate_mesh.clear_surfaces()
		_immediate_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, _trajectory_material)
		var steps := 32
		var cam_pos := _camera.global_position
		var pts: Array[Vector3] = []
		for i in range(steps + 1):
			var t := total_time * (float(i) / float(steps))
			var p := launch_pos + impulse * t + 0.5 * Vector3(0, -GRENADE_GRAVITY, 0) * t * t
			pts.append(p)
		
		# Generate camera-facing quad strip ribbon
		for i in range(steps + 1):
			var p := pts[i]
			var tangent := Vector3.ZERO
			if i == 0:
				tangent = (pts[1] - pts[0]).normalized()
			elif i == steps:
				tangent = (pts[steps] - pts[steps - 1]).normalized()
			else:
				tangent = (pts[i + 1] - pts[i - 1]).normalized()
			
			var to_cam := (cam_pos - p).normalized()
			var half_w := 0.024
			var side := tangent.cross(to_cam).normalized() * half_w
			if side.length_squared() < 0.0001:
				side = Vector3(half_w, 0, 0)
			_immediate_mesh.surface_add_vertex(p - side)
			_immediate_mesh.surface_add_vertex(p + side)
		_immediate_mesh.surface_end()


func _ensure_aim_reticle() -> Node3D:
	if not is_instance_valid(_aim_reticle):
		_make_aim_reticle()
	return _aim_reticle


func _ensure_trajectory_arc() -> MeshInstance3D:
	if not is_instance_valid(_trajectory_mesh_instance):
		_make_trajectory_arc()
	return _trajectory_mesh_instance


func _make_trajectory_arc() -> void:
	if is_instance_valid(_trajectory_mesh_instance):
		_trajectory_mesh_instance.queue_free()
	_immediate_mesh = ImmediateMesh.new()
	_trajectory_material = StandardMaterial3D.new()
	_trajectory_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_trajectory_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_trajectory_material.albedo_color = Color(0.2, 0.8, 1.0, 0.85)
	_trajectory_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_trajectory_material.no_depth_test = true
	_trajectory_material.render_priority = 8
	
	_trajectory_mesh_instance = MeshInstance3D.new()
	_trajectory_mesh_instance.name = "TrajectoryArc"
	_trajectory_mesh_instance.mesh = _immediate_mesh
	_trajectory_mesh_instance.material_override = _trajectory_material
	_trajectory_mesh_instance.visible = false
	_trajectory_mesh_instance.top_level = true
	add_child(_trajectory_mesh_instance)


func _notify_out_of_ammo(weapon_name: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("show_out_of_ammo"):
		hud.show_out_of_ammo(weapon_name)
	else:
		_spawn_floating_alert("Out of %s!" % weapon_name, Color(1.0, 0.35, 0.35))


func _spawn_floating_alert(text: String, color: Color) -> void:
	var lbl := Label3D.new()
	lbl.text = text
	lbl.font_size = 36
	lbl.outline_size = 8
	lbl.outline_modulate = Color(0.2, 0.02, 0.02, 0.95)
	lbl.modulate = color
	lbl.pixel_size = 0.0065
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.render_priority = 20
	
	var spawn_pos := _camera.global_position + _camera.project_ray_normal(get_viewport().get_visible_rect().size * 0.5) * 2.0
	get_tree().current_scene.add_child(lbl)
	lbl.global_position = spawn_pos
	
	lbl.scale = Vector3(0.5, 0.5, 0.5)
	var tw := lbl.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "global_position:y", spawn_pos.y + 0.35, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.3).set_delay(0.5)
	tw.chain().tween_callback(lbl.queue_free)


## Builds the multi-ring luminous bullseye reticle (outer ring, inner ring,
## center pip, and splash indicator disc) under the projectiles container.
func _make_aim_reticle() -> void:
	var reticle := Node3D.new()
	reticle.name = "AimReticle"

	var bullseye_color := Color(0.15, 0.75, 1.0, 0.95)

	# Outer Ring
	var outer_mat := StandardMaterial3D.new()
	outer_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	outer_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	outer_mat.albedo_color = bullseye_color
	outer_mat.no_depth_test = true
	outer_mat.render_priority = 10

	var outer_torus := TorusMesh.new()
	outer_torus.inner_radius = 0.94
	outer_torus.outer_radius = 1.00
	outer_torus.material = outer_mat

	var outer_ring := MeshInstance3D.new()
	outer_ring.name = "OuterRing"
	outer_ring.mesh = outer_torus
	reticle.add_child(outer_ring)

	# Inner Ring
	var inner_mat := StandardMaterial3D.new()
	inner_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	inner_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	inner_mat.albedo_color = Color(0.35, 0.88, 1.0, 0.95)
	inner_mat.no_depth_test = true
	inner_mat.render_priority = 10

	var inner_torus := TorusMesh.new()
	inner_torus.inner_radius = 0.44
	inner_torus.outer_radius = 0.50
	inner_torus.material = inner_mat

	var inner_ring := MeshInstance3D.new()
	inner_ring.name = "InnerRing"
	inner_ring.mesh = inner_torus
	reticle.add_child(inner_ring)

	# Center Dot
	var dot_mat := StandardMaterial3D.new()
	dot_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dot_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dot_mat.albedo_color = Color(0.7, 0.95, 1.0, 1.0)
	dot_mat.no_depth_test = true
	dot_mat.render_priority = 11

	var dot_mesh := CylinderMesh.new()
	dot_mesh.top_radius = 0.08
	dot_mesh.bottom_radius = 0.08
	dot_mesh.height = 0.02
	dot_mesh.material = dot_mat

	var dot := MeshInstance3D.new()
	dot.name = "CenterDot"
	dot.mesh = dot_mesh
	reticle.add_child(dot)

	# Subtle glowing splash area disc
	var disc_mat := StandardMaterial3D.new()
	disc_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	disc_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	disc_mat.albedo_color = Color(0.15, 0.75, 1.0, 0.18)
	disc_mat.no_depth_test = true
	disc_mat.render_priority = 9

	var disc_mesh := CylinderMesh.new()
	disc_mesh.top_radius = 1.00
	disc_mesh.bottom_radius = 1.00
	disc_mesh.height = 0.005
	disc_mesh.material = disc_mat

	var disc := MeshInstance3D.new()
	disc.name = "SplashDisc"
	disc.mesh = disc_mesh
	reticle.add_child(disc)

	# Directional Target Arrow Pointer pointing toward the bullseye center
	var arrow_mat := StandardMaterial3D.new()
	arrow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	arrow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	arrow_mat.albedo_color = bullseye_color
	arrow_mat.no_depth_test = true
	arrow_mat.render_priority = 11

	var arrow_prism := PrismMesh.new()
	arrow_prism.size = Vector3(0.24, 0.36, 0.04)
	arrow_prism.material = arrow_mat

	var arrow_node := MeshInstance3D.new()
	arrow_node.name = "TargetArrow"
	arrow_node.mesh = arrow_prism
	arrow_node.rotation_degrees = Vector3(90, 0, 0)
	arrow_node.position = Vector3(0, 0.02, -0.45)
	reticle.add_child(arrow_node)

	if is_instance_valid(_aim_reticle):
		_aim_reticle.queue_free()
	reticle.top_level = true
	add_child(reticle)
	reticle.visible = false
	_aim_reticle = reticle


func _container() -> Node3D:
	var container := get_node_or_null(projectiles_parent) as Node3D
	if container == null:
		return self
	return container


# =========================================================================
# FLUORIDE SHIELD SYSTEM
# =========================================================================

func has_active_shield() -> bool:
	return _has_shield and _shield_durability > 0.0


func get_shield_durability_ratio() -> float:
	return (_shield_durability / SHIELD_MAX_DURABILITY) if _has_shield else 0.0


func check_auto_apply_shield() -> void:
	var bridge = get_node_or_null("/root/GameBridge")
	var has_available := false
	if bridge != null and bridge.has_method("has_fluoride_shield"):
		has_available = bridge.has_fluoride_shield()
	elif Game != null and Game.has_method("has_fluoride_shield"):
		has_available = Game.has_fluoride_shield()
		
	if has_available:
		# Consume 1 from inventory to auto-apply to the active game
		if bridge != null and bridge.has_method("consume_fluoride_shield"):
			bridge.consume_fluoride_shield()
		elif Game != null and Game.has_method("consume_fluoride_shield"):
			Game.consume_fluoride_shield()
		activate_fluoride_shield(false)
	else:
		_has_shield = false
		if _shield_root != null and is_instance_valid(_shield_root):
			_shield_root.visible = false
		_emit_shield_update()


func activate_fluoride_shield(is_redeploy: bool = false) -> void:
	_has_shield = true
	_shield_durability = SHIELD_MAX_DURABILITY
	_ensure_shield_visual()
	if _shield_root != null and is_instance_valid(_shield_root):
		_shield_root.visible = true
		_shield_root.scale = Vector3.ZERO
		var tw := create_tween()
		tw.tween_property(_shield_root, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		
	_emit_shield_update()
	var banner_text := "Fluoride Shield Activated!" if not is_redeploy else "Fluoride Shield Redeployed!"
	_spawn_floating_shield_text(banner_text, Color(0.35, 1.0, 0.95))


func absorb_hit(hit_type: String) -> bool:
	if not _has_shield or _shield_durability <= 0.0:
		return false
		
	var cost := 5.0 # Minion collision: lasts 3 times (15 / 3 = 5.0)
	if hit_type == "bonbon":
		cost = 3.0 # Bonbon collision: lasts 5 times (15 / 5 = 3.0)
	elif hit_type == "blue_candor" or hit_type == "boss":
		cost = 15.0 # Blue Candor collision: lasts 1 time (15 / 1 = 15.0)
		
	_shield_durability = maxf(0.0, _shield_durability - cost)
	_play_shield_impact_fx(hit_type)
	_emit_shield_update()
	
	if _shield_durability <= 0.0:
		_on_shield_depleted()
		
	return true


func _emit_shield_update() -> void:
	var ratio := (_shield_durability / SHIELD_MAX_DURABILITY) if _has_shield else 0.0
	var remaining_shields := 0
	var bridge = get_node_or_null("/root/GameBridge")
	if bridge != null and bridge.has_method("get_fluoride_shield_count"):
		remaining_shields = bridge.get_fluoride_shield_count()
	elif Game != null and Game.has_method("get_fluoride_shield_count"):
		remaining_shields = Game.get_fluoride_shield_count()
		
	shield_updated.emit(_has_shield, ratio, remaining_shields)
	var game = get_node_or_null("/root/Game")
	if game != null and game.has_signal("shield_status_changed"):
		game.shield_status_changed.emit(_has_shield, ratio, remaining_shields)


func _on_shield_depleted() -> void:
	_has_shield = false
	_play_shield_break_fx()
	
	# Check if player has another shield in inventory to auto-apply
	var bridge = get_node_or_null("/root/GameBridge")
	var has_more := false
	if bridge != null and bridge.has_method("consume_fluoride_shield"):
		has_more = bridge.consume_fluoride_shield()
	elif Game != null and Game.has_method("consume_fluoride_shield"):
		has_more = Game.consume_fluoride_shield()
		
	if has_more:
		get_tree().create_timer(0.25).timeout.connect(func():
			if is_instance_valid(self):
				activate_fluoride_shield(true)
		)
	else:
		_emit_shield_update()


func get_shield_z() -> float:
	return -1.6


func _ensure_shield_visual() -> void:
	if _shield_root != null and is_instance_valid(_shield_root):
		return
		
	_shield_root = Node3D.new()
	_shield_root.name = "FluorideShieldVisual"
	add_child(_shield_root)
	_shield_root.position = Vector3(0.0, 0.65, -1.6)
	
	# Translucent semi-circle energy forcefield barrier curving forward
	_shield_mesh = MeshInstance3D.new()
	_shield_mesh.name = "EnergyBarrier"
	_shield_mesh.mesh = _create_semi_circle_mesh(1.80, 1.30, 0.50)
	
	_shield_material = StandardMaterial3D.new()
	_shield_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_shield_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_shield_material.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	_shield_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_shield_material.albedo_color = Color(0.20, 0.85, 1.0, 0.28)
	_shield_mesh.material_override = _shield_material
	_shield_root.add_child(_shield_mesh)
	
	# Top & Bottom glowing energy rails
	var rail_mat := StandardMaterial3D.new()
	rail_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rail_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rail_mat.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	rail_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	rail_mat.albedo_color = Color(0.40, 0.95, 1.0, 0.85)
	
	var top_rail := MeshInstance3D.new()
	top_rail.mesh = _create_semi_circle_mesh(1.84, 0.035, 0.51)
	top_rail.position = Vector3(0.0, 0.65, 0.0)
	top_rail.material_override = rail_mat
	_shield_root.add_child(top_rail)
	
	var btm_rail := MeshInstance3D.new()
	btm_rail.mesh = _create_semi_circle_mesh(1.84, 0.035, 0.51)
	btm_rail.position = Vector3(0.0, -0.65, 0.0)
	btm_rail.material_override = rail_mat
	_shield_root.add_child(btm_rail)
	
	# Left & Right energy emitter posts
	var post_mat := StandardMaterial3D.new()
	post_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	post_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	post_mat.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	post_mat.albedo_color = Color(0.35, 0.90, 1.0, 0.90)
	
	var post_cyl := CylinderMesh.new()
	post_cyl.top_radius = 0.035
	post_cyl.bottom_radius = 0.035
	post_cyl.height = 1.32
	
	var left_post := MeshInstance3D.new()
	left_post.mesh = post_cyl
	left_post.position = Vector3(-0.90, 0.0, -0.50)
	left_post.material_override = post_mat
	_shield_root.add_child(left_post)
	
	var right_post := MeshInstance3D.new()
	right_post.mesh = post_cyl
	right_post.position = Vector3(0.90, 0.0, -0.50)
	right_post.material_override = post_mat
	_shield_root.add_child(right_post)
	
	# Soft upward drifting sparkles across the barrier volume
	_shield_aura = CPUParticles3D.new()
	_shield_aura.name = "ShieldAuraParticles"
	_shield_aura.amount = 14
	_shield_aura.lifetime = 1.2
	_shield_aura.explosiveness = 0.0
	_shield_aura.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_shield_aura.emission_box_extents = Vector3(0.80, 0.60, 0.03)
	_shield_aura.gravity = Vector3(0, 0.15, 0)
	_shield_aura.scale_amount_min = 0.04
	_shield_aura.scale_amount_max = 0.12
	
	var sm := SphereMesh.new()
	sm.radius = 0.015
	sm.height = 0.030
	_shield_aura.mesh = sm
	
	var aura_mat := StandardMaterial3D.new()
	aura_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	aura_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	aura_mat.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	aura_mat.albedo_color = Color(0.40, 1.0, 0.95, 0.70)
	_shield_aura.material_override = aura_mat
	_shield_root.add_child(_shield_aura)


func _create_semi_circle_mesh(width: float = 1.8, height: float = 0.85, curve_depth: float = 0.50) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := 24
	var half_h := height * 0.5
	
	for i in range(segments):
		var t0 := float(i) / float(segments)
		var t1 := float(i + 1) / float(segments)
		var a0 := -PI * 0.5 + t0 * PI
		var a1 := -PI * 0.5 + t1 * PI
		
		var x0 := sin(a0) * (width * 0.5)
		var z0 := (cos(a0) - 1.0) * curve_depth
		var x1 := sin(a1) * (width * 0.5)
		var z1 := (cos(a1) - 1.0) * curve_depth
		
		var n0 := Vector3(sin(a0), 0.0, -cos(a0)).normalized()
		var n1 := Vector3(sin(a1), 0.0, -cos(a1)).normalized()
		
		var p0_top := Vector3(x0, half_h, z0)
		var p0_bot := Vector3(x0, -half_h, z0)
		var p1_top := Vector3(x1, half_h, z1)
		var p1_bot := Vector3(x1, -half_h, z1)
		
		# Double-sided triangles for semi-circular barrier
		st.set_normal(n0)
		st.set_uv(Vector2(t0, 0))
		st.add_vertex(p0_top)
		st.set_normal(n1)
		st.set_uv(Vector2(t1, 0))
		st.add_vertex(p1_top)
		st.set_normal(n0)
		st.set_uv(Vector2(t0, 1))
		st.add_vertex(p0_bot)
		
		st.set_normal(n0)
		st.set_uv(Vector2(t0, 1))
		st.add_vertex(p0_bot)
		st.set_normal(n1)
		st.set_uv(Vector2(t1, 0))
		st.add_vertex(p1_top)
		st.set_normal(n1)
		st.set_uv(Vector2(t1, 1))
		st.add_vertex(p1_bot)
		
	return st.commit()


func _play_shield_impact_fx(hit_type: String) -> void:
	if _shield_root != null and is_instance_valid(_shield_root):
		_shield_root.scale = Vector3(1.08, 1.08, 1.08)
		var tw := create_tween()
		tw.tween_property(_shield_root, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		
	if _shield_material != null:
		_shield_material.albedo_color = Color(0.45, 0.95, 1.0, 0.65)
		var tw_col := create_tween()
		tw_col.tween_property(_shield_material, "albedo_color", Color(0.20, 0.85, 1.0, 0.22), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		
	var burst := CPUParticles3D.new()
	burst.amount = 18
	burst.lifetime = 0.45
	burst.one_shot = true
	burst.explosiveness = 0.95
	var sm := SphereMesh.new()
	sm.radius = 0.025
	sm.height = 0.05
	burst.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	mat.albedo_color = Color(0.35, 1.0, 0.95, 0.95)
	burst.material_override = mat
	burst.spread = 180.0
	burst.initial_velocity_min = 1.5
	burst.initial_velocity_max = 3.5
	burst.gravity = Vector3.ZERO
	get_tree().current_scene.add_child(burst)
	burst.global_position = Vector3(0.0, 0.45, -1.6)
	get_tree().create_timer(0.6).timeout.connect(burst.queue_free)
	
	var label_msg := "SHIELD BLOCKED!"
	if hit_type == "bonbon":
		label_msg = "BONBON DEFLECTED!"
	elif hit_type == "blue_candor" or hit_type == "boss":
		label_msg = "BOSS ATTACK BLOCKED!"
	_spawn_floating_shield_text(label_msg, Color(0.35, 1.0, 0.95))


func _play_shield_break_fx() -> void:
	if _shield_root != null and is_instance_valid(_shield_root):
		var tw := create_tween()
		tw.tween_property(_shield_root, "scale", Vector3(1.20, 1.20, 1.20), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(_shield_root, "scale", Vector3.ZERO, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.chain().tween_callback(func():
			if _shield_root != null:
				_shield_root.visible = false
		)
		
	var burst := CPUParticles3D.new()
	burst.amount = 32
	burst.lifetime = 0.65
	burst.one_shot = true
	burst.explosiveness = 0.98
	var qm := QuadMesh.new()
	qm.size = Vector2(0.08, 0.08)
	burst.mesh = qm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	mat.albedo_color = Color(0.4, 0.95, 1.0, 0.85)
	burst.material_override = mat
	burst.spread = 180.0
	burst.initial_velocity_min = 2.5
	burst.initial_velocity_max = 5.5
	burst.gravity = Vector3(0, -4.0, 0)
	get_tree().current_scene.add_child(burst)
	burst.global_position = Vector3(0.0, 0.45, -1.6)
	get_tree().create_timer(0.8).timeout.connect(burst.queue_free)
	
	_spawn_floating_shield_text("SHIELD BROKEN!", Color(1.0, 0.45, 0.45))


func _spawn_floating_shield_text(text: String, col: Color) -> void:
	var lbl := Label3D.new()
	lbl.text = text
	lbl.font_size = 28
	lbl.outline_size = 6
	lbl.outline_modulate = Color(0.05, 0.1, 0.2, 1.0)
	lbl.modulate = col
	lbl.pixel_size = 0.0032
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.render_priority = 25
	
	get_tree().current_scene.add_child(lbl)
	var spawn_pos := Vector3(0.0, 0.95, -1.6)
	lbl.global_position = spawn_pos
	
	var tw := lbl.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "scale", Vector3(1.15, 1.15, 1.15), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "global_position:y", spawn_pos.y + 0.30, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.28).set_delay(0.40)
	tw.chain().tween_callback(lbl.queue_free)

