@tool
extends Node

## Global Candy Crusade state, autoloaded as Game.

signal weapon_level_changed(weapon_name: String, level: int)
signal ammo_changed(weapon_name: String, current_ammo: int, total_spent: int)
signal battery_charge_changed(used: int, needed: int)
signal combo_changed(current_combo: int, multiplier: float)
signal shield_status_changed(active: bool, durability_ratio: float, remaining_shields: int)
signal game_completed(payload: Dictionary)

var _is_loading_levels := false

## Weapon levels (0 = Locked, 1 = Standard, 2 = Gold, 3 = Bubble)
var pistol_level := 1:
	set(val):
		pistol_level = clampi(val, 0, 3)
		if not _is_loading_levels and not Engine.is_editor_hint():
			_save_weapon_levels()
		weapon_level_changed.emit("pistol", pistol_level)
		weapon_level_changed.emit("paste", pistol_level)
		var b = get_node_or_null("/root/GameBridge")
		if b != null and b.has_method("get_weapon_level") and b.get_weapon_level("paste") != pistol_level:
			b.set_weapon_level("paste", pistol_level)

var boomerang_level := 1:
	set(val):
		boomerang_level = clampi(val, 0, 3)
		if not _is_loading_levels and not Engine.is_editor_hint():
			_save_weapon_levels()
		weapon_level_changed.emit("boomerang", boomerang_level)
		weapon_level_changed.emit("brush", boomerang_level)
		var b = get_node_or_null("/root/GameBridge")
		if b != null and b.has_method("get_weapon_level") and b.get_weapon_level("brush") != boomerang_level:
			b.set_weapon_level("brush", boomerang_level)

var grenade_level := 1:
	set(val):
		grenade_level = clampi(val, 0, 3)
		if not _is_loading_levels and not Engine.is_editor_hint():
			_save_weapon_levels()
		weapon_level_changed.emit("grenade", grenade_level)
		weapon_level_changed.emit("wash", grenade_level)
		var b = get_node_or_null("/root/GameBridge")
		if b != null and b.has_method("get_weapon_level") and b.get_weapon_level("wash") != grenade_level:
			b.set_weapon_level("wash", grenade_level)

var floss_level := 1:
	set(val):
		floss_level = clampi(val, 0, 3)
		if not _is_loading_levels and not Engine.is_editor_hint():
			_save_weapon_levels()
		weapon_level_changed.emit("floss", floss_level)
		weapon_level_changed.emit("lasso", floss_level)
		var b = get_node_or_null("/root/GameBridge")
		if b != null and b.has_method("get_weapon_level") and b.get_weapon_level("floss") != floss_level:
			b.set_weapon_level("floss", floss_level)

## Developer Mode toggle
var dev_mode: bool = false

## Preview / Testing level override (-1 = auto/default, 0 = Lvl 1, 1 = Lvl 2, etc.)
var test_level_index := -1

## Consumable ammo inventory (from Lovable payload or defaults)
var ammo_toothpaste: int = 54
var ammo_batteries: int = 20
var ammo_bottles: int = 15
var ammo_string: int = 25
var _battery_charges_used: int = 0

## Real-time ammo consumption tracking
var ammo_spent: Dictionary = {
	"pistol": 0,
	"boomerang": 0,
	"grenade": 0,
	"lasso": 0
}

## Fluoride Shield powerup inventory
var fluoride_shields: int = 1

func has_fluoride_shield() -> bool:
	var b = get_node_or_null("/root/GameBridge")
	if b != null and b.has_method("has_fluoride_shield"):
		return b.has_fluoride_shield()
	return fluoride_shields > 0

func get_fluoride_shield_count() -> int:
	var b = get_node_or_null("/root/GameBridge")
	if b != null and b.has_method("get_fluoride_shield_count"):
		return b.get_fluoride_shield_count()
	return maxi(0, fluoride_shields)

func consume_fluoride_shield() -> bool:
	var b = get_node_or_null("/root/GameBridge")
	if b != null and b.has_method("consume_fluoride_shield"):
		var ok: bool = b.consume_fluoride_shield()
		fluoride_shields = b.get_fluoride_shield_count()
		return ok
	if fluoride_shields > 0:
		fluoride_shields -= 1
		return true
	return false


## Chain Combo System
var combo_streak: int = 0
var max_combo: int = 0

const WEAPON_MODELS := {
	"pistol": {
		1: "res://assets/candy_crusade/models/toothpaste_pistol.glb",
		2: "res://assets/candy_crusade/models/PasteGold2.glb",
		3: "res://assets/candy_crusade/models/PasteBubble3.glb",
	},
	"boomerang": {
		1: "res://assets/candy_crusade/models/brush_boomerang.glb",
		2: "res://assets/candy_crusade/models/Goldbrushlvl2.glb",
		3: "res://assets/candy_crusade/models/BubbleBrush.glb",
	},
	"grenade": {
		1: "res://assets/candy_crusade/models/mouthwash_blast.glb",
		2: "res://assets/candy_crusade/models/MWashGold2.glb",
		3: "res://assets/candy_crusade/models/MWashBubble3.glb",
	}
}

const WEAPON_ICONS := {
	"pistol": {
		1: "res://assets/candy_crusade/ui/Lvl1Paste.png",
		2: "res://assets/candy_crusade/ui/PasteGold2.png",
		3: "res://assets/candy_crusade/ui/BubblePaste.png",
	},
	"paste": {
		1: "res://assets/candy_crusade/ui/Lvl1Paste.png",
		2: "res://assets/candy_crusade/ui/PasteGold2.png",
		3: "res://assets/candy_crusade/ui/BubblePaste.png",
	},
	"boomerang": {
		1: "res://assets/candy_crusade/ui/brushweapon_1.png",
		2: "res://assets/candy_crusade/ui/brushlvl2.png",
		3: "res://assets/candy_crusade/ui/BubbleBrush.png",
	},
	"brush": {
		1: "res://assets/candy_crusade/ui/brushweapon_1.png",
		2: "res://assets/candy_crusade/ui/brushlvl2.png",
		3: "res://assets/candy_crusade/ui/BubbleBrush.png",
	},
	"grenade": {
		1: "res://assets/candy_crusade/ui/MouthwashBlast-1.png",
		2: "res://assets/candy_crusade/ui/WashGold2.png",
		3: "res://assets/candy_crusade/ui/BubbleWash.png",
	},
	"wash": {
		1: "res://assets/candy_crusade/ui/MouthwashBlast-1.png",
		2: "res://assets/candy_crusade/ui/WashGold2.png",
		3: "res://assets/candy_crusade/ui/BubbleWash.png",
	},
	"lasso": {
		1: "res://assets/candy_crusade/ui/flossweapon.png",
		2: "res://assets/candy_crusade/ui/flossweapon_2.png",
		3: "res://assets/candy_crusade/ui/BubbleFloss.png",
	},
	"floss": {
		1: "res://assets/candy_crusade/ui/flossweapon.png",
		2: "res://assets/candy_crusade/ui/flossweapon_2.png",
		3: "res://assets/candy_crusade/ui/BubbleFloss.png",
	}
}


func _init() -> void:
	_cleanup_stale_temp_files()


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_load_weapon_levels()
	var bridge = get_node_or_null("/root/GameBridge")
	if bridge != null:
		if bridge.has_signal("session_ready"):
			bridge.session_ready.connect(func(_p): _sync_from_bridge())
		if bridge.has_signal("ammo_changed"):
			bridge.ammo_changed.connect(func(key: String, count: int):
				ammo_changed.emit(key, count, 0)
			)
		if bridge.has_signal("battery_charge_changed"):
			bridge.battery_charge_changed.connect(func(used: int, needed: int):
				battery_charge_changed.emit(used, needed)
			)
		if bridge.get("initialized") == true:
			_sync_from_bridge()


func _sync_from_bridge() -> void:
	var bridge = get_node_or_null("/root/GameBridge")
	if bridge == null:
		return
	pistol_level = int(bridge.get_weapon_level("paste"))
	boomerang_level = int(bridge.get_weapon_level("brush"))
	grenade_level = int(bridge.get_weapon_level("wash"))
	floss_level = int(bridge.get_weapon_level("floss"))


func get_weapon_icon_path(weapon: String, level: int = -1) -> String:
	var canonical_key := weapon.to_lower().strip_edges()
	match canonical_key:
		"paste": canonical_key = "pistol"
		"brush": canonical_key = "boomerang"
		"wash": canonical_key = "grenade"
		"floss": canonical_key = "lasso"
	if not WEAPON_ICONS.has(canonical_key):
		return ""
	if level < 0:
		match canonical_key:
			"pistol": level = pistol_level
			"boomerang": level = boomerang_level
			"grenade": level = grenade_level
			"lasso": level = floss_level
			_: level = 1
	level = clampi(level, 1, 3)
	return WEAPON_ICONS[canonical_key].get(level, "")


func get_weapon_model_path(weapon: String, level: int = -1) -> String:
	if not WEAPON_MODELS.has(weapon):
		return ""
	if level < 0:
		match weapon:
			"pistol": level = pistol_level
			"boomerang": level = boomerang_level
			"grenade": level = grenade_level
			_: level = 1
	level = clampi(level, 1, 3)
	return WEAPON_MODELS[weapon].get(level, "")


## Material overrides for models whose imported glTF PBR maps have metallic=1 roughness=0
## which renders black in gl_compatibility mode without environment reflections.
var _model_materials: Dictionary = {}

func get_model_material(model_path: String) -> Material:
	if _model_materials.has(model_path):
		return _model_materials[model_path]
	
	var mat_path := ""
	if "Goldbrushlvl2" in model_path:
		mat_path = "res://assets/candy_crusade/models/Goldbrushlvl2_material.tres"
	elif "PasteGold2" in model_path:
		mat_path = "res://assets/candy_crusade/models/PasteGold2_material.tres"
	elif "MWashGold2" in model_path:
		mat_path = "res://assets/candy_crusade/models/MWashGold2_material.tres"
	elif "Level2BrushBattery" in model_path:
		mat_path = "res://assets/candy_crusade/models/Level2BrushBattery_material.tres"
	
	if mat_path != "" and (ResourceLoader.exists(mat_path) or FileAccess.file_exists(mat_path)):
		var loaded = load(mat_path) as Material
		if loaded != null:
			_model_materials[model_path] = loaded
			return loaded
	
	# Programmatic fallback if .tres file is ever missing
	if "Goldbrushlvl2" in model_path:
		var mat := StandardMaterial3D.new()
		mat.resource_name = "Goldbrushlvl2_Material"
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.albedo_color = Color(1.0, 0.95, 0.85, 1.0)
		if ResourceLoader.exists("res://assets/candy_crusade/models/Goldbrushlvl2_0.jpg"):
			var albedo_tex = load("res://assets/candy_crusade/models/Goldbrushlvl2_0.jpg")
			mat.albedo_texture = albedo_tex
			mat.emission_enabled = true
			mat.emission = Color(0.25, 0.18, 0.04, 1.0)
			mat.emission_energy_multiplier = 0.35
			mat.emission_texture = albedo_tex
		if ResourceLoader.exists("res://assets/candy_crusade/models/Goldbrushlvl2_2.jpg"):
			mat.normal_enabled = true
			mat.normal_scale = 1.0
			mat.normal_texture = load("res://assets/candy_crusade/models/Goldbrushlvl2_2.jpg")
		mat.metallic = 0.45
		mat.metallic_specular = 0.85
		mat.roughness = 0.28
		mat.rim_enabled = true
		mat.rim = 0.45
		mat.rim_tint = 0.5
		_model_materials[model_path] = mat
		return mat
	
	return null

func apply_model_materials(node: Node, model_path: String) -> void:
	var mat := get_model_material(model_path)
	if mat != null:
		_apply_material_to_node_recursive(node, mat)

func _apply_material_to_node_recursive(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		mi.material_override = mat
		if mi.mesh != null:
			for s in range(mi.mesh.get_surface_count()):
				mi.set_surface_override_material(s, mat)
	for child in node.get_children():
		_apply_material_to_node_recursive(child, mat)


func set_all_weapon_levels(lvl: int) -> void:
	var cl := clampi(lvl, 1, 3)
	pistol_level = cl
	boomerang_level = cl
	grenade_level = cl
	floss_level = cl


## Ammo Logic
func get_ammo_count(weapon_name: String) -> int:
	var bridge = get_node_or_null("/root/GameBridge")
	if bridge != null:
		return bridge.get_ammo_for_weapon(weapon_name)
	match weapon_name:
		"pistol": return ammo_toothpaste
		"boomerang": return ammo_batteries
		"grenade": return ammo_bottles
		"lasso": return ammo_string
	return 0


func can_fire_weapon(weapon_name: String) -> bool:
	var bridge = get_node_or_null("/root/GameBridge")
	if bridge != null:
		return bridge.can_fire(weapon_name)
	match weapon_name:
		"pistol": return ammo_toothpaste > 0 and pistol_level > 0
		"boomerang": return ammo_batteries > 0 and boomerang_level > 0
		"grenade": return ammo_bottles > 0 and grenade_level > 0
		"lasso": return ammo_string > 0 and floss_level > 0
	return false


func get_battery_charge_info() -> Dictionary:
	var bridge = get_node_or_null("/root/GameBridge")
	if bridge != null and bridge.has_method("get_battery_charge_info"):
		return bridge.get_battery_charge_info()
	var needed := 3 if boomerang_level == 2 else (7 if boomerang_level >= 3 else 1)
	return {"used": _battery_charges_used, "needed": needed}


func consume_ammo(weapon_name: String) -> bool:
	var bridge = get_node_or_null("/root/GameBridge")
	if bridge != null:
		var ok: bool = bridge.consume_ammo(weapon_name)
		if ok:
			var int_name: String = bridge.to_internal_weapon(weapon_name)
			if ammo_spent.has(int_name):
				ammo_spent[int_name] += 1
		return ok
	if not can_fire_weapon(weapon_name):
		return false
	match weapon_name:
		"pistol":
			ammo_toothpaste = maxi(0, ammo_toothpaste - 1)
			ammo_spent["pistol"] += 1
			ammo_changed.emit("pistol", ammo_toothpaste, ammo_spent["pistol"])
		"boomerang":
			var needed := 3 if boomerang_level == 2 else (7 if boomerang_level >= 3 else 1)
			_battery_charges_used += 1
			battery_charge_changed.emit(_battery_charges_used, needed)
			if _battery_charges_used >= needed:
				_battery_charges_used = 0
				ammo_batteries = maxi(0, ammo_batteries - 1)
				ammo_spent["boomerang"] += 1
				ammo_changed.emit("boomerang", ammo_batteries, ammo_spent["boomerang"])
				battery_charge_changed.emit(_battery_charges_used, needed)
		"grenade":
			ammo_bottles = maxi(0, ammo_bottles - 1)
			ammo_spent["grenade"] += 1
			ammo_changed.emit("grenade", ammo_bottles, ammo_spent["grenade"])
		"lasso":
			ammo_string = maxi(0, ammo_string - 1)
			ammo_spent["lasso"] += 1
			ammo_changed.emit("lasso", ammo_string, ammo_spent["lasso"])
	return true


func add_ammo(weapon_name: String, amount: int) -> void:
	var bridge = get_node_or_null("/root/GameBridge")
	if bridge != null:
		bridge.add_weapon_ammo(weapon_name, amount)
		return
	match weapon_name:
		"pistol":
			ammo_toothpaste += amount
			ammo_changed.emit("pistol", ammo_toothpaste, ammo_spent["pistol"])
		"boomerang":
			ammo_batteries += amount
			ammo_changed.emit("boomerang", ammo_batteries, ammo_spent["boomerang"])
		"grenade":
			ammo_bottles += amount
			ammo_changed.emit("grenade", ammo_bottles, ammo_spent["grenade"])
		"lasso":
			ammo_string += amount
			ammo_changed.emit("lasso", ammo_string, ammo_spent["lasso"])


func refill_all_ammo(amount: int = 50) -> void:
	var bridge = get_node_or_null("/root/GameBridge")
	if bridge != null:
		for a_key in ["brushes", "battery", "tubes", "spools", "vials"]:
			bridge.add_ammo_count(a_key, amount)
		return
	ammo_toothpaste += amount
	ammo_batteries += amount
	ammo_bottles += amount
	ammo_string += amount
	ammo_changed.emit("pistol", ammo_toothpaste, ammo_spent["pistol"])
	ammo_changed.emit("boomerang", ammo_batteries, ammo_spent["boomerang"])
	ammo_changed.emit("grenade", ammo_bottles, ammo_spent["grenade"])
	ammo_changed.emit("lasso", ammo_string, ammo_spent["lasso"])


## Chain Combo System
func register_combo_hit() -> float:
	combo_streak += 1
	if combo_streak > max_combo:
		max_combo = combo_streak
	var mult: float = minf(1.0 + (combo_streak - 1) * 0.2, 5.0)
	combo_changed.emit(combo_streak, mult)
	return mult


func reset_combo() -> void:
	if combo_streak > 0:
		combo_streak = 0
		combo_changed.emit(0, 1.0)


func get_combo_multiplier() -> float:
	if combo_streak <= 1:
		return 1.0
	return minf(1.0 + (combo_streak - 1) * 0.2, 5.0)


## Lovable Bridge
func init_from_payload(payload: Dictionary) -> void:
	if payload.has("weapons"):
		var w = payload["weapons"]
		if w.has("pistol"): pistol_level = int(w["pistol"])
		if w.has("boomerang"): boomerang_level = int(w["boomerang"])
		if w.has("grenade"): grenade_level = int(w["grenade"])
		if w.has("lasso"): floss_level = int(w["lasso"])
	if payload.has("ammo"):
		var a = payload["ammo"]
		if a.has("toothpaste"): ammo_toothpaste = int(a["toothpaste"])
		if a.has("batteries"): ammo_batteries = int(a["batteries"])
		if a.has("bottles"): ammo_bottles = int(a["bottles"])
		if a.has("string"): ammo_string = int(a["string"])
		var bridge = get_node_or_null("/root/GameBridge")
		if bridge != null:
			bridge.ammo["tubes"] = ammo_toothpaste
			bridge.ammo["battery"] = ammo_batteries
			bridge.ammo["vials"] = ammo_bottles
			bridge.ammo["spools"] = ammo_string
	if payload.has("region"):
		test_level_index = int(payload["region"]) - 1
	ammo_spent = {"pistol": 0, "boomerang": 0, "grenade": 0, "lasso": 0}
	combo_streak = 0
	max_combo = 0


func get_completion_payload(outcome: String, score: int, region: int) -> Dictionary:
	return {
		"outcome": outcome,
		"region": region + 1,
		"score": score,
		"max_combo": max_combo,
		"ammo_spent": ammo_spent.duplicate(),
		"ammo_remaining": {
			"toothpaste": get_ammo_count("pistol"),
			"batteries": get_ammo_count("boomerang"),
			"bottles": get_ammo_count("grenade"),
			"string": get_ammo_count("lasso")
		}
	}


func send_completion_to_lovable(outcome_val = "victory", score: int = 0, region: int = -1) -> void:
	var outcome_str := "victory"
	if typeof(outcome_val) == TYPE_BOOL:
		outcome_str = "victory" if outcome_val else "defeat"
	elif typeof(outcome_val) == TYPE_STRING:
		outcome_str = outcome_val

	var reg := region
	if reg < 0:
		reg = test_level_index
	var payload := get_completion_payload(outcome_str, score, reg)
	game_completed.emit(payload)
	
	var bridge = get_node_or_null("/root/GameBridge")
	if bridge != null:
		var result_str := "VICTORY" if outcome_str.to_lower() == "victory" else "DEFEAT"
		var dur: float = (Time.get_ticks_msec() / 1000.0) - float(bridge.get("run_start_time"))
		var minions: int = int(bridge.get("minions_defeated"))
		var coins: int = int(bridge.get("coins_collected"))
		var is_boss: bool = bool(bridge.get("is_boss"))
		var boss_def: bool = (result_str == "VICTORY" and is_boss)
		var no_dmg: bool = not bool(bridge.get("player_damaged"))
		var objectives := [
			{ "id": "no_damage", "label": "Flawless Smile", "completed": no_dmg },
			{ "id": "all_plaque_cleared", "label": "Every Cavity Cleared", "completed": (result_str == "VICTORY") }
		]
		bridge.send_game_over(result_str, score, coins, minions, boss_def, bridge.get("ammo"), objectives, dur)


func _cleanup_stale_temp_files() -> void:
	var dir := DirAccess.open("user://")
	if dir != null:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.begins_with("weapon_levels.txt") and file_name.ends_with(".tmp"):
				dir.remove(file_name)
			file_name = dir.get_next()


func _save_weapon_levels() -> void:
	if Engine.is_editor_hint() or _is_loading_levels:
		return
	var f := FileAccess.open("user://weapon_levels.txt", FileAccess.WRITE)
	if f != null:
		f.store_line(str(pistol_level))
		f.store_line(str(boomerang_level))
		f.store_line(str(grenade_level))
		f.store_line(str(floss_level))
		f.close()


func _load_weapon_levels() -> void:
	if Engine.is_editor_hint():
		return
	if not FileAccess.file_exists("user://weapon_levels.txt"):
		return
	var f := FileAccess.open("user://weapon_levels.txt", FileAccess.READ)
	if f == null:
		return
	var l1 := f.get_line().strip_edges()
	var l2 := f.get_line().strip_edges()
	var l3 := f.get_line().strip_edges()
	var l4 := f.get_line().strip_edges()
	f.close()
	f = null

	_is_loading_levels = true
	if l1.is_valid_int(): pistol_level = clampi(l1.to_int(), 0, 3)
	if l2.is_valid_int(): boomerang_level = clampi(l2.to_int(), 0, 3)
	if l3.is_valid_int(): grenade_level = clampi(l3.to_int(), 0, 3)
	if l4.is_valid_int(): floss_level = clampi(l4.to_int(), 0, 3)
	_is_loading_levels = false

