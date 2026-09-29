extends Node

## JavaScript Bridge for Candy Crusade (Godot 4 Web Export)
## Facilitates two-way communication between host web application (Lovable/React)
## and the Godot minigame via window.postMessage.
## Also acts as the central authority for session state, weapon tiers, and consumable ammo.

signal session_ready(data: Dictionary)
signal ammo_changed(weapon_or_ammo_key: String, count: int)
signal battery_charge_changed(used: int, needed: int)
signal weapon_locked_state_changed(weapon_key: String, is_locked: bool)
signal weapon_auto_switched(new_weapon_bridge_id: String, new_weapon_internal_id: String)
signal game_over_reported(payload: Dictionary)
signal exit_game_requested()
signal power_up_changed(power_up_key: String, count: int)

const BRIDGE_VERSION := 1

# Session state received from INIT_GAME
var player_id: String = ""
var player_name: String = "Player"
var character_id: String = "chip" # chip, flora, dash, blaze, ash, penelope, nibbles, spark, sparkette
var day: int = 1
var node_id: int = 1
var is_boss: bool = false
var difficulty: String = "medium" # easy | medium | hard
var coins: int = 0
var points: int = 0
var muted: bool = false
var equipped: String = "paste"

# Weapon id -> owned upgrade level. 0 = LOCKED, 1..3 = owned tier.
var weapon_levels: Dictionary = {
	"brush": 0,
	"paste": 0,
	"wash": 0,
	"floss": 0
}

# Consumable finite ammo, id -> count.
var ammo: Dictionary = {
	"brushes": 0,
	"battery": 0,
	"tubes": 0,
	"spools": 0,
	"vials": 0
}

var power_ups: Dictionary = {
	"shield": 0,
	"freeze": 0
}

var _battery_charges_used: int = 0

var initialized: bool = false
var _js_callback = null
var _init_timer: float = 0.0
var _requested_state: bool = false
var _applied_fallback: bool = false

# Run metrics tracking
var run_start_time: float = 0.0
var minions_defeated: int = 0
var coins_collected: int = 0
var player_damaged: bool = false
var boss_defeated: bool = false
var _game_over_sent: bool = false

const WEAPON_MAP_TO_INTERNAL := {
	"brush": "boomerang",
	"paste": "pistol",
	"wash": "grenade",
	"floss": "lasso"
}

const WEAPON_MAP_TO_BRIDGE := {
	"boomerang": "brush",
	"pistol": "paste",
	"grenade": "wash",
	"lasso": "floss"
}

const CHARACTER_PORTRAITS := {
	"ash": "res://assets/candy_crusade/characters/Ash.jpeg",
	"blaze": "res://assets/candy_crusade/characters/Blaze.jpeg",
	"nibbles": "res://assets/candy_crusade/characters/Chef Nibbles.jpeg",
	"chip": "res://assets/candy_crusade/characters/Chip.jpeg",
	"dash": "res://assets/candy_crusade/characters/Dash.jpeg",
	"flora": "res://assets/candy_crusade/characters/Flora.jpeg",
	"penelope": "res://assets/candy_crusade/characters/Penelope.jpeg",
	"spark": "res://assets/candy_crusade/characters/Spark.jpeg",
	"sparkette": "res://assets/candy_crusade/characters/Sparkette.jpeg"
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	run_start_time = Time.get_ticks_msec() / 1000.0
	
	if OS.has_feature("web"):
		_js_callback = JavaScriptBridge.create_callback(_on_host_message)
		var window := JavaScriptBridge.get_interface("window")
		if window != null:
			window.addEventListener("message", _js_callback)
		send_game_ready()
	else:
		var gs = get_node_or_null("/root/GameState")
		if gs != null and gs.has_method("get_active_profile") and not gs.get_active_profile().is_empty():
			init_from_game_state()
		else:
			_apply_init(_debug_payload())


func _process(delta: float) -> void:
	if not initialized and OS.has_feature("web") and not _applied_fallback:
		_init_timer += delta
		if _init_timer >= 1.0 and not _requested_state:
			_requested_state = true
			send_request_state()
		elif _init_timer >= 2.0:
			_applied_fallback = true
			_apply_init(_debug_fallback_payload())


func _on_host_message(args: Array) -> void:
	if args.is_empty():
		return
	var event = args[0]
	if event == null:
		return
	var data = event.data
	if data == null:
		return
		
	var dict_data: Dictionary = _js_to_dict(data)
	if dict_data.is_empty():
		return
		
	var msg_type = dict_data.get("type", "")
	match msg_type:
		"INIT_GAME":
			var payload = dict_data.get("payload", {})
			if typeof(payload) == TYPE_DICTIONARY:
				_apply_init(payload)
		_:
			pass


func _js_to_dict(js_obj) -> Dictionary:
	if typeof(js_obj) == TYPE_DICTIONARY:
		return js_obj
	if typeof(js_obj) == TYPE_STRING:
		var parsed = JSON.parse_string(js_obj)
		if typeof(parsed) == TYPE_DICTIONARY:
			return parsed
	if not OS.has_feature("web"):
		return {}
	JavaScriptBridge.eval("window.__pwStringify = window.__pwStringify || function(o){try{return typeof o === 'string' ? o : JSON.stringify(o||{});}catch(e){return '{}';}};", true)
	var window := JavaScriptBridge.get_interface("window")
	if window == null:
		return {}
	var text: String = str(window.__pwStringify(js_obj))
	var parsed = JSON.parse_string(text)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _post(msg: Dictionary) -> void:
	if not OS.has_feature("web"):
		print("[GameBridge Outgoing] ", JSON.stringify(msg))
		return
	var text := JSON.stringify(msg)
	JavaScriptBridge.eval("if (window.parent) { window.parent.postMessage(JSON.parse(%s), '*'); }" % [JSON.stringify(text)], true)


func reset_run_metrics() -> void:
	_game_over_sent = false
	run_start_time = Time.get_ticks_msec() / 1000.0
	minions_defeated = 0
	coins_collected = 0
	player_damaged = false
	boss_defeated = false
	_battery_charges_used = 0


func _apply_init(p: Dictionary) -> void:
	player_id = str(p.get("playerId", ""))
	player_name = str(p.get("playerName", "Player"))
	character_id = str(p.get("characterId", "chip")).to_lower()
	day = int(p.get("day", 1))
	node_id = int(p.get("nodeId", 1))
	is_boss = bool(p.get("isBoss", false))
	difficulty = str(p.get("difficulty", "medium")).to_lower()
	coins = int(p.get("coins", 0))
	points = int(p.get("points", 0))
	muted = bool(p.get("muted", false))
	equipped = str(p.get("equipped", "brush")).to_lower()
	
	var w: Dictionary = p.get("weapons", {})
	for k in ["brush", "paste", "wash", "floss"]:
		var int_k := to_internal_weapon(k)
		if w.has(k):
			weapon_levels[k] = clampi(int(w.get(k, 0)), 0, 3)
		elif w.has(int_k):
			weapon_levels[k] = clampi(int(w.get(int_k, 0)), 0, 3)
		else:
			weapon_levels[k] = 0
			
	var a: Dictionary = p.get("ammo", {})
	var ammo_aliases := {
		"brushes": ["brushes", "brush"],
		"battery": ["battery", "batteries"],
		"tubes": ["tubes", "toothpaste", "paste"],
		"spools": ["spools", "string", "floss"],
		"vials": ["vials", "bottles", "wash", "mouthwash"]
	}
	for ak in ammo_aliases:
		ammo[ak] = 0
		for alias in ammo_aliases[ak]:
			if a.has(alias):
				ammo[ak] = maxi(0, int(a.get(alias, 0)))
				break
		
	var pu: Dictionary = p.get("powerUps", {})
	var shield_count: int = 0
	for s_key in ["shield", "fluoride_shield", "fluorideShield", "fluoride"]:
		if pu.has(s_key):
			shield_count = maxi(shield_count, int(pu.get(s_key, 0)))
	var freeze_count: int = 0
	for f_key in ["freeze", "streak_freeze", "streakFreeze"]:
		if pu.has(f_key):
			freeze_count = maxi(freeze_count, int(pu.get(f_key, 0)))
			
	power_ups = {
		"shield": shield_count,
		"freeze": freeze_count
	}
	
	AudioServer.set_bus_mute(0, muted)
	
	initialized = true
	reset_run_metrics()
	
	# If currently equipped weapon is locked or out of ammo, auto-switch
	if is_weapon_locked(equipped) or not can_fire(equipped):
		var avail := get_first_available_weapon()
		if avail != "":
			equipped = avail
			
	_battery_charges_used = 0
	var b_info := get_battery_charge_info()
	battery_charge_changed.emit(b_info["used"], b_info["needed"])

	_sync_to_game_state()
	session_ready.emit(p)


func _sync_to_game_state() -> void:
	var game = get_node_or_null("/root/Game")
	if game == null:
		return
	if "pistol_level" in game:
		game.pistol_level = weapon_levels.get("paste", 0)
	if "boomerang_level" in game:
		game.boomerang_level = weapon_levels.get("brush", 0)
	if "grenade_level" in game:
		game.grenade_level = weapon_levels.get("wash", 0)
	if "floss_level" in game:
		game.floss_level = weapon_levels.get("floss", 0)
	if "fluoride_shields" in game:
		game.fluoride_shields = power_ups.get("shield", 0)


# =========================================================================
# FLUORIDE SHIELD & POWER-UP HELPERS
# =========================================================================

func has_fluoride_shield() -> bool:
	return int(power_ups.get("shield", 0)) > 0


func get_fluoride_shield_count() -> int:
	return maxi(0, int(power_ups.get("shield", 0)))


func consume_fluoride_shield() -> bool:
	var cur: int = int(power_ups.get("shield", 0))
	if cur <= 0:
		return false
	power_ups["shield"] = cur - 1
	power_up_changed.emit("shield", power_ups["shield"])
	_sync_to_game_state()
	return true


# =========================================================================
# WEAPON & AMMO HELPERS
# =========================================================================

func to_internal_weapon(weapon_id: String) -> String:
	var lower := weapon_id.to_lower()
	return WEAPON_MAP_TO_INTERNAL.get(lower, lower)


func to_bridge_weapon(weapon_id: String) -> String:
	var lower := weapon_id.to_lower()
	return WEAPON_MAP_TO_BRIDGE.get(lower, lower)


func get_weapon_level(weapon_id: String) -> int:
	var b_id := to_bridge_weapon(weapon_id)
	return weapon_levels.get(b_id, 0)


func set_weapon_level(weapon_id: String, level: int) -> void:
	var b_id := to_bridge_weapon(weapon_id)
	var cl_lvl := clampi(level, 0, 3)
	weapon_levels[b_id] = cl_lvl
	var is_locked := cl_lvl <= 0
	weapon_locked_state_changed.emit(b_id, is_locked)
	weapon_locked_state_changed.emit(to_internal_weapon(b_id), is_locked)
	if is_locked and (equipped == b_id or equipped == to_internal_weapon(b_id)):
		var avail := get_first_available_weapon()
		if avail != "":
			equipped = avail
			weapon_auto_switched.emit(equipped, to_internal_weapon(equipped))


func is_weapon_locked(weapon_id: String) -> bool:
	return get_weapon_level(weapon_id) <= 0


func get_ammo_key_for_weapon(weapon_id: String) -> String:
	var b_id := to_bridge_weapon(weapon_id)
	match b_id:
		"brush":
			return "battery"
		"paste":
			return "tubes"
		"wash":
			return "vials"
		"floss":
			return "spools"
	return ""


func get_ammo_for_weapon(weapon_id: String) -> int:
	var a_key := get_ammo_key_for_weapon(weapon_id)
	if a_key == "":
		return 0
	return ammo.get(a_key, 0)


func can_fire(weapon_id: String) -> bool:
	if is_weapon_locked(weapon_id):
		return false
	var a_key := get_ammo_key_for_weapon(weapon_id)
	if a_key == "":
		return false
	return ammo.get(a_key, 0) > 0


func get_battery_charge_info() -> Dictionary:
	var lvl := get_weapon_level("brush")
	var needed := 1
	if lvl == 2:
		needed = 3
	elif lvl >= 3:
		needed = 7
	return {"used": _battery_charges_used, "needed": needed}


func consume_ammo(weapon_id: String) -> bool:
	if not can_fire(weapon_id):
		return false
	var a_key := get_ammo_key_for_weapon(weapon_id)
	if a_key == "" or ammo.get(a_key, 0) <= 0:
		return false
		
	var b_id := to_bridge_weapon(weapon_id)
	var int_id := to_internal_weapon(weapon_id)
	
	if b_id == "brush" and a_key == "battery":
		var lvl := get_weapon_level("brush")
		var needed := 3 if lvl == 2 else (7 if lvl >= 3 else 1)
		_battery_charges_used += 1
		battery_charge_changed.emit(_battery_charges_used, needed)
		if _battery_charges_used >= needed:
			_battery_charges_used = 0
			ammo[a_key] = maxi(0, ammo[a_key] - 1)
			ammo_changed.emit(a_key, ammo[a_key])
			ammo_changed.emit(b_id, ammo[a_key])
			ammo_changed.emit(int_id, ammo[a_key])
			battery_charge_changed.emit(_battery_charges_used, needed)
	else:
		ammo[a_key] = maxi(0, ammo[a_key] - 1)
		ammo_changed.emit(a_key, ammo[a_key])
		ammo_changed.emit(b_id, ammo[a_key])
		ammo_changed.emit(int_id, ammo[a_key])
	
	# If currently used weapon ran out of ammo, auto-switch
	if ammo[a_key] <= 0:
		var next_w := get_first_available_weapon()
		if next_w != "" and next_w != b_id:
			equipped = next_w
			weapon_auto_switched.emit(equipped, to_internal_weapon(equipped))
			
	return true


func add_ammo_count(ammo_key: String, count: int) -> void:
	if ammo.has(ammo_key):
		ammo[ammo_key] += count
		ammo_changed.emit(ammo_key, ammo[ammo_key])
		# Also emit weapon key if relevant
		for b_w in ["brush", "paste", "wash", "floss"]:
			if get_ammo_key_for_weapon(b_w) == ammo_key:
				ammo_changed.emit(b_w, ammo[ammo_key])
				ammo_changed.emit(to_internal_weapon(b_w), ammo[ammo_key])


func add_weapon_ammo(weapon_id: String, count: int) -> void:
	var a_key := get_ammo_key_for_weapon(weapon_id)
	if a_key != "":
		add_ammo_count(a_key, count)


func get_first_available_weapon() -> String:
	# Priority order: brush, paste, wash, floss
	for k in ["brush", "paste", "wash", "floss"]:
		if not is_weapon_locked(k) and can_fire(k):
			return k
	# Secondary check: any unlocked weapon even if 0 ammo
	for k in ["brush", "paste", "wash", "floss"]:
		if not is_weapon_locked(k):
			return k
	return ""


func get_character_portrait_path(c_id: String = "") -> String:
	var cid := c_id.to_lower() if c_id != "" else character_id.to_lower()
	return CHARACTER_PORTRAITS.get(cid, "res://assets/candy_crusade/characters/Chip.jpeg")


# =========================================================================
# DIFFICULTY SCALING
# =========================================================================

func get_difficulty_speed_mult() -> float:
	match difficulty:
		"easy": return 0.85
		"hard": return 1.25
		_: return 1.0


func get_difficulty_health_mult() -> float:
	match difficulty:
		"easy": return 0.85
		"hard": return 1.25
		_: return 1.0


func get_difficulty_damage_mult() -> float:
	match difficulty:
		"easy": return 0.80
		"hard": return 1.30
		_: return 1.0


# =========================================================================
# OUTGOING MESSAGES
# =========================================================================

func send_game_ready() -> void:
	_post({"type": "GAME_READY", "version": BRIDGE_VERSION, "payload": {}})


func send_request_state() -> void:
	_post({"type": "REQUEST_STATE", "version": BRIDGE_VERSION, "payload": {}})


func send_exit_game() -> void:
	exit_game_requested.emit()
	_post({"type": "EXIT_GAME", "version": BRIDGE_VERSION, "payload": {}})


func send_game_error(message: String, detail: String = "") -> void:
	_post({
		"type": "GAME_ERROR",
		"version": BRIDGE_VERSION,
		"payload": {
			"message": message,
			"detail": detail
		}
	})


func send_game_over(result: String, score: int, coins_col: int,
		minions: int, boss_def: bool, ammo_left: Dictionary,
		objectives: Array, duration: float) -> void:
	if _game_over_sent:
		return
	_game_over_sent = true
	
	var validated_result := "VICTORY" if result.to_upper() == "VICTORY" else "DEFEAT"
	
	# Ensure ammo_left has all 5 keys
	var complete_ammo := {
		"brushes": int(ammo_left.get("brushes", ammo.get("brushes", 0))),
		"battery": int(ammo_left.get("battery", ammo.get("battery", 0))),
		"tubes": int(ammo_left.get("tubes", ammo.get("tubes", 0))),
		"spools": int(ammo_left.get("spools", ammo.get("spools", 0))),
		"vials": int(ammo_left.get("vials", ammo.get("vials", 0)))
	}
	
	var payload := {
		"result": validated_result,
		"score": score,
		"coinsCollected": coins_col,
		"minionsDefeated": minions,
		"bossDefeated": boss_def,
		"ammoRemaining": complete_ammo,
		"objectives": objectives,
		"durationSeconds": int(duration),
	}
	
	game_over_reported.emit(payload)
	sync_rewards_to_game_state(payload)
	_post({"type": "GAME_OVER", "version": BRIDGE_VERSION, "payload": payload})
	get_tree().paused = true


func init_from_game_state(override_boss: bool = false) -> void:
	var gs = get_node_or_null("/root/GameState")
	if gs == null or not gs.has_method("get_active_profile"):
		_apply_init(_debug_payload())
		return
	var p: Dictionary = gs.get_active_profile()
	if p.is_empty():
		_apply_init(_debug_payload())
		return
	
	var cur_node: int = int(p.get("currentNode", 1))
	var cur_day: int = gs.day_for_node(cur_node)
	var is_boss_match: bool = override_boss or (cur_day == 28)
	var ammo_data: Dictionary = p.get("ammo", {})
	var wep_data: Dictionary = p.get("weaponLevels", {})
	
	var payload := {
		"playerId": str(p.get("id", "player")),
		"playerName": str(p.get("name", "Player")),
		"characterId": str(p.get("character", "chip")),
		"day": cur_day,
		"nodeId": cur_node,
		"isBoss": is_boss_match,
		"difficulty": "medium",
		"coins": int(p.get("coins", 0)),
		"points": int(p.get("points", 0)),
		"weapons": {
			"brush": int(wep_data.get("brush", 1)),
			"paste": int(wep_data.get("paste", 1)),
			"wash": int(wep_data.get("wash", 0)),
			"floss": int(wep_data.get("floss", 0))
		},
		"equipped": "paste",
		"ammo": {
			"brushes": int(ammo_data.get("brushes", 10)),
			"battery": int(ammo_data.get("battery", ammo_data.get("batteries", 0))),
			"tubes": int(ammo_data.get("tubes", ammo_data.get("toothpaste", 0))),
			"spools": int(ammo_data.get("spools", ammo_data.get("string", 0))),
			"vials": int(ammo_data.get("vials", ammo_data.get("bottles", 0)))
		},
		"powerUps": p.get("inventory", {})
	}
	_apply_init(payload)


func sync_rewards_to_game_state(payload: Dictionary) -> void:
	var gs = get_node_or_null("/root/GameState")
	if gs == null or not gs.has_method("get_active_profile"):
		return
	var score: int = int(payload.get("score", 0))
	var coins_collected: int = int(payload.get("coinsCollected", 0))
	if score > 0 and gs.has_method("add_points"):
		gs.add_points(score)
	if coins_collected > 0:
		if gs.has_method("add_coins"):
			gs.add_coins(coins_collected)
		elif gs.has_method("add_molar_coins"):
			gs.add_molar_coins(coins_collected)
	
	# Sync remaining ammo back to profile
	var ammo_left: Dictionary = payload.get("ammoRemaining", {})
	var p: Dictionary = gs.get_active_profile()
	if not p.is_empty() and p.has("ammo"):
		if ammo_left.has("brushes"):
			p["ammo"]["brushes"] = int(ammo_left["brushes"])
		if ammo_left.has("tubes"):
			p["ammo"]["tubes"] = int(ammo_left["tubes"])
			p["ammo"]["toothpaste"] = int(ammo_left["tubes"])
		if ammo_left.has("battery"):
			p["ammo"]["battery"] = int(ammo_left["battery"])
			p["ammo"]["batteries"] = int(ammo_left["battery"])
		if ammo_left.has("vials"):
			p["ammo"]["vials"] = int(ammo_left["vials"])
			p["ammo"]["bottles"] = int(ammo_left["vials"])
		if ammo_left.has("spools"):
			p["ammo"]["spools"] = int(ammo_left["spools"])
			p["ammo"]["string"] = int(ammo_left["spools"])
		if gs.has_method("save_game"):
			gs.save_game()
		elif gs.has_method("save_profiles"):
			gs.save_profiles()


# =========================================================================
# FALLBACK PAYLOADS
# =========================================================================

func _debug_payload() -> Dictionary:
	return {
		"playerId": "debug_editor",
		"playerName": "Temi",
		"characterId": "chip",
		"day": 1,
		"nodeId": 1,
		"isBoss": false,
		"difficulty": "medium",
		"coins": 100,
		"points": 500,
		"muted": false,
		"weapons": {
			"brush": 1,
			"paste": 1,
			"wash": 1,
			"floss": 1
		},
		"equipped": "paste",
		"ammo": {
			"brushes": 25,
			"battery": 25,
			"tubes": 54,
			"spools": 40,
			"vials": 25
		},
		"powerUps": {
			"shield": 1,
			"freeze": 0
		}
	}


func _debug_fallback_payload() -> Dictionary:
	return {
		"playerId": "guest",
		"playerName": "Player",
		"characterId": "chip",
		"day": 1,
		"nodeId": 1,
		"isBoss": false,
		"difficulty": "medium",
		"coins": 0,
		"points": 0,
		"muted": false,
		"weapons": {
			"brush": 1,
			"paste": 1,
			"wash": 1,
			"floss": 1
		},
		"equipped": "paste",
		"ammo": {
			"brushes": 25,
			"battery": 25,
			"tubes": 54,
			"spools": 40,
			"vials": 25
		},
		"powerUps": {
			"shield": 1,
			"freeze": 0
		}
	}

