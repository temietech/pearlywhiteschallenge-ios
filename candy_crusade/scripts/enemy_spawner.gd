extends Node3D
class_name EnemySpawner

## Spawns batches of minions at a far -Z point on an interval, capped by the
## number of minions currently alive. Emits score_changed when a minion dies.

signal score_changed(new_score: int)
signal wave_finished

@export var minion_scene: PackedScene
@export_range(0.2, 10.0) var spawn_interval := 4.0
@export_range(1, 5) var minions_per_batch := 1
@export_range(1, 30) var max_alive := 6
@export var spawn_z := -17.0
@export var lane_half_width := 0.6
@export var spawn_y := 0.0 # Minion root sits on the lane surface (y = 0).
@export var minion_scale := 0.35

var _score := 0
var _wave_active := false
var _remaining_to_spawn := 0
var _spawn_timer := 0.0
var _wave_speed_multiplier := 1.0
var _wave_wander_amplitude := 0.0
var _last_lane_idx := -1


var current_level := 1
var _total_wave_minions := 0
var _spawned_minions_count := 0
var _ammo_drop_indices: Dictionary = {}


var _spontaneous_coin_timer := 5.0


func _ready() -> void:
	add_to_group("spawner")


func reduce_score(amount: int) -> void:
	_score = maxi(0, _score - amount)
	score_changed.emit(_score)


func _process(delta: float) -> void:
	if not _wave_active:
		return
		
	_spontaneous_coin_timer -= delta
	if _spontaneous_coin_timer <= 0.0:
		_spontaneous_coin_timer = randf_range(6.5, 11.0)
		_spawn_spontaneous_coin()
		
	if _remaining_to_spawn <= 0:
		_check_wave_finished()
		return
	_spawn_timer -= delta
	if _spawn_timer > 0.0:
		return
	var active_minions := 0
	for child in get_children():
		if not child.is_queued_for_deletion() and not child.get("_dead"):
			active_minions += 1
	var free_slots := max_alive - active_minions
	if free_slots <= 0:
		return
	var count := mini(_remaining_to_spawn, mini(minions_per_batch, free_slots))
	spawn_batch(count)
	_remaining_to_spawn -= count
	_spawn_timer = spawn_interval


## Begins one finite wave. A later wave can supply higher movement values
## without making the region's baseline configuration permanent.
func start_wave(total_minions: int, speed_multiplier: float, wander_amplitude: float, level_num: int = 1) -> void:
	clear_minions()
	current_level = level_num
	_total_wave_minions = maxi(total_minions, 0)
	_remaining_to_spawn = _total_wave_minions
	_spawned_minions_count = 0
	
	# Determine guaranteed ammo drops per user specification:
	# Level 1: 2, Level 2: 3, Level 3: 5, Level 4: 7
	var drops_needed := 2
	match current_level:
		1: drops_needed = 2
		2: drops_needed = 3
		3: drops_needed = 5
		4: drops_needed = 7
		_: drops_needed = maxi(2, int(round(_total_wave_minions * 0.35)))
	
	_ammo_drop_indices.clear()
	if _total_wave_minions > 0 and drops_needed > 0:
		drops_needed = mini(drops_needed, _total_wave_minions)
		var step: float = float(_total_wave_minions) / float(drops_needed + 1)
		for k in range(drops_needed):
			var target_idx := int(round(step * (k + 1))) - 1
			target_idx = clampi(target_idx, 0, _total_wave_minions - 1)
			_ammo_drop_indices[target_idx] = true

	# Exact spawn interval scaling per user specification:
	# Level 1: 3.0s, Level 2: 2.8s, Level 3: 2.4s, Level 4: 2.0s
	match current_level:
		1:
			spawn_interval = 3.0
			minions_per_batch = 1
			max_alive = 4
		2:
			spawn_interval = 2.8
			minions_per_batch = 1
			max_alive = 5
		3:
			spawn_interval = 2.4
			minions_per_batch = 1
			max_alive = 6
		4:
			spawn_interval = 2.0
			minions_per_batch = 2
			max_alive = 7
		_:
			spawn_interval = maxf(1.6, 2.0 - (current_level - 4) * 0.3)
			minions_per_batch = 2
			max_alive = 8

	var d_mult: float = 1.0
	var bridge = get_node_or_null("/root/GameBridge")
	if bridge != null:
		d_mult = bridge.get_difficulty_speed_mult()
	_wave_speed_multiplier = speed_multiplier * d_mult
	_wave_wander_amplitude = wander_amplitude
	_wave_active = true
	_spawn_timer = 0.1

func prepopulate(count: int, z_start: float, z_step: float) -> void:
	var lane_centers = [-0.6, 0.0, 0.6]
	count = mini(count, _remaining_to_spawn)
	for i in range(count):
		var minion := minion_scene.instantiate() as Node3D
		if minion == null:
			continue
		if minion.has_method("set_variant"):
			var roll := randf()
			if roll < 0.20:
				minion.call("set_variant", "runner")
			elif roll < 0.32:
				minion.call("set_variant", "brute")
			else:
				minion.call("set_variant", "standard")
		elif minion.has_method("set_minion_scale"):
			minion.call("set_minion_scale", minion_scale)
			
		var should_drop := _ammo_drop_indices.has(_spawned_minions_count)
		if minion.has_method("set_drops_ammo"):
			minion.call("set_drops_ammo", should_drop)
		_spawned_minions_count += 1
		
		add_child(minion)
		
		var idx := randi() % 3
		if idx == _last_lane_idx:
			idx = (_last_lane_idx + 1 + (randi() % 2)) % 3
		_last_lane_idx = idx
		
		minion.global_position = Vector3(
			lane_centers[idx],
			spawn_y,
			z_start - i * z_step
		)
		if minion.has_method("configure_wave"):
			minion.call("configure_wave", _wave_speed_multiplier, _wave_wander_amplitude, randf_range(0.0, TAU))
		minion.connect("died", _on_minion_died)
		minion.tree_exited.connect(_on_minion_exited)
		
	_remaining_to_spawn -= count
	if _remaining_to_spawn <= 0:
		_spawn_timer = 9999.0
	else:
		_spawn_timer = spawn_interval


func clear_minions() -> void:
	_wave_active = false
	for minion in get_children():
		if minion.is_connected("tree_exited", _on_minion_exited):
			minion.tree_exited.disconnect(_on_minion_exited)
		if minion.is_connected("died", _on_minion_died):
			minion.died.disconnect(_on_minion_died)
		minion.queue_free()


func spawn_batch(count: int) -> void:
	var lane_centers = [-0.6, 0.0, 0.6]
	for i in count:
		var minion := minion_scene.instantiate() as Node3D
		if minion == null:
			return
		if minion.has_method("set_variant"):
			var roll := randf()
			if roll < 0.22:
				minion.call("set_variant", "runner")
			elif roll < 0.35:
				minion.call("set_variant", "brute")
			else:
				minion.call("set_variant", "standard")
		elif minion.has_method("set_minion_scale"):
			minion.call("set_minion_scale", minion_scale)
			
		var should_drop := _ammo_drop_indices.has(_spawned_minions_count)
		if minion.has_method("set_drops_ammo"):
			minion.call("set_drops_ammo", should_drop)
		_spawned_minions_count += 1
		
		add_child(minion)
		
		var idx := randi() % 3
		if idx == _last_lane_idx:
			idx = (_last_lane_idx + 1 + (randi() % 2)) % 3
		_last_lane_idx = idx
		
		minion.global_position = Vector3(
			lane_centers[idx],
			spawn_y,
			spawn_z - i * 2.2
		)
		if minion.has_method("configure_wave"):
			minion.call(
				"configure_wave",
				_wave_speed_multiplier,
				_wave_wander_amplitude,
				randf_range(0.0, TAU)
			)
		minion.connect("died", _on_minion_died)
		minion.tree_exited.connect(_on_minion_exited)


func _on_minion_died() -> void:
	var bridge = get_node_or_null("/root/GameBridge")
	if bridge != null:
		bridge.minions_defeated += 1
	var mult: float = 1.0
	var game = get_node_or_null("/root/Game")
	if game != null and game.has_method("get_combo_multiplier"):
		mult = game.get_combo_multiplier()
	_score += int(round(1.0 * mult))
	score_changed.emit(_score)


func _on_minion_exited() -> void:
	call_deferred("_check_wave_finished")


func _check_wave_finished() -> void:
	if not _wave_active or _remaining_to_spawn > 0:
		return
	var alive_minions := 0
	for child in get_children():
		if child.is_in_group("minions") and not child.get("_dead") and not child.is_queued_for_deletion():
			alive_minions += 1
	if alive_minions == 0:
		_wave_active = false
		wave_finished.emit()


static var _cached_floor_coin_scene: PackedScene = null

func _spawn_spontaneous_coin() -> void:
	if not _wave_active:
		return
	var active_coins = get_tree().get_nodes_in_group("coins")
	if active_coins.size() >= 4:
		return
	if _cached_floor_coin_scene == null and ResourceLoader.exists("res://candy_crusade/molar_coin.tscn"):
		_cached_floor_coin_scene = load("res://candy_crusade/molar_coin.tscn")
	if _cached_floor_coin_scene == null:
		return
	var coin = _cached_floor_coin_scene.instantiate() as Node3D
	if coin != null:
		get_tree().current_scene.add_child(coin)
		var lane_options: Array[float] = [-0.55, 0.0, 0.55]
		var lane_x: float = lane_options.pick_random()
		var rand_z: float = randf_range(-4.5, -11.5)
		if coin.has_method("spawn_on_floor"):
			coin.call("spawn_on_floor", Vector3(lane_x, spawn_y, rand_z))
		else:
			coin.global_position = Vector3(lane_x, spawn_y + 0.06, rand_z)


