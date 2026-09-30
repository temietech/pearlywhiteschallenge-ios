# scripts/combat_screen.gd
extends Control

signal combat_finished(victory: bool)

var is_boss_fight: bool = false
var _sub_viewport_container: SubViewportContainer = null
var _sub_viewport: SubViewport = null
var _game_scene: Node = null
var _last_victory: bool = false
var _session_completed: bool = false
var _is_setup: bool = false
var _setup_called: bool = false

var _loading_overlay: Control = null
var _sir_crown_rect: TextureRect = null
var _loading_label: Label = null
var _spinner: Control = null

# Custom rotating loading circle spinner widget
class LoadingCircleSpinner extends Control:
	var angle: float = 0.0
	var radius: float = 24.0
	var thickness: float = 5.0
	var ring_color: Color = Color(0.32, 0.76, 1.0) # Bright vibrant cyan
	var bg_color: Color = Color(1, 1, 1, 0.22)
	
	func _init(p_radius: float = 24.0, p_thickness: float = 5.0):
		process_mode = Node.PROCESS_MODE_ALWAYS
		radius = p_radius
		thickness = p_thickness
		custom_minimum_size = Vector2(radius * 2.6, radius * 2.6)
		size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		
	func _draw():
		var center = size * 0.5
		# Background full track
		draw_arc(center, radius, 0, TAU, 40, bg_color, thickness, true)
		# Rotating spinner arc (approx 135 degrees arc length)
		var start_rad = angle
		var end_rad = angle + (PI * 1.25)
		draw_arc(center, radius, start_rad, end_rad, 40, ring_color, thickness, true)
		
	func _process(delta: float):
		angle += delta * 6.2
		if angle >= TAU:
			angle -= TAU
		queue_redraw()

func _ready() -> void:
	anchors_preset = Control.PRESET_FULL_RECT
	anchor_right = 1.0
	anchor_bottom = 1.0
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	_build_game_container()
	_build_loading_overlay()
	_connect_bridge()
	call_deferred("_check_auto_setup")

func _check_auto_setup() -> void:
	if not _setup_called and not _is_setup:
		setup_fight(false)

func _exit_tree() -> void:
	# Ensure the tree is unpaused when exiting combat
	get_tree().paused = false
	GameState._candy_in_use = false

func setup_fight(is_boss: bool = false) -> void:
	_setup_called = true
	if not is_node_ready():
		await ready
	if _is_setup:
		return
	_is_setup = true
	is_boss_fight = is_boss
	_session_completed = false
	_last_victory = false
	
	# Only show the loading screen if Candy Crusade isn't preloaded yet
	if not GameState.is_candy_crusade_ready():
		_show_loading_overlay()
	else:
		_loading_overlay.visible = false
	GameState._candy_in_use = true
	
	# Determine region/level from day progression
	var p: Dictionary = GameState.get_active_profile()
	var cur_node: int = int(p.get("currentNode", 1)) if not p.is_empty() else 1
	var cur_day: int = GameState.day_for_node(cur_node) if not p.is_empty() else 1
	
	# Level rule: 1st Candy Crusade = Level 1, 2nd = Level 2, ... (capped at Level 4)
	var region_idx: int = clampi(GameState.get_candy_crusade_number(cur_node) - 1, 0, 3)
	print("[CandyCrusade] node ", cur_node, " day ", cur_day, " -> fight #", GameState.get_candy_crusade_number(cur_node), " -> level ", region_idx + 1)

	# Initialize GameBridge with active profile
	var bridge = get_node_or_null("/root/GameBridge")
	if bridge != null and bridge.has_method("init_from_game_state"):
		bridge.init_from_game_state(false)
	
	var game = get_node_or_null("/root/Game")
	if game != null:
		game.test_level_index = region_idx
	
	# Instantiate Candy Crusade 3D main world
	_load_3d_world(region_idx)

func _build_game_container() -> void:
	# Background Base
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.08, 0.05, 0.15, 1.0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	
	# SubViewportContainer filling full screen
	_sub_viewport_container = SubViewportContainer.new()
	_sub_viewport_container.name = "SubViewportContainer"
	_sub_viewport_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sub_viewport_container.anchor_right = 1.0
	_sub_viewport_container.anchor_bottom = 1.0
	_sub_viewport_container.stretch = true
	_sub_viewport_container.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_sub_viewport_container)
	
	# SubViewport with physics picking and local inputs
	_sub_viewport = SubViewport.new()
	_sub_viewport.name = "SubViewport"
	_sub_viewport.handle_input_locally = true
	_sub_viewport.physics_object_picking = true
	_sub_viewport.size = Vector2i(720, 1280)
	_sub_viewport.process_mode = Node.PROCESS_MODE_ALWAYS
	_sub_viewport_container.add_child(_sub_viewport)

func _build_loading_overlay() -> void:
	_loading_overlay = Control.new()
	_loading_overlay.name = "LoadingOverlay"
	_loading_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_loading_overlay.anchor_right = 1.0
	_loading_overlay.anchor_bottom = 1.0
	_loading_overlay.z_index = 60
	_loading_overlay.z_as_relative = false
	_loading_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_loading_overlay)
	
	# Background themed gradient panel
	var bg_panel = Panel.new()
	bg_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg_st = StyleBoxFlat.new()
	bg_st.bg_color = Color(0.07, 0.11, 0.22, 1.0) # Deep midnight arena blue
	bg_panel.add_theme_stylebox_override("panel", bg_st)
	_loading_overlay.add_child(bg_panel)
	
	# Centered Layout Container
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_loading_overlay.add_child(center)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	center.add_child(vbox)
	
	# Sir Crown Mascot Icon
	var crown_tex = UIHelper.load_texture_safe("res://assets/images/characters/SirCrown-nobg.png")
	if not crown_tex:
		crown_tex = UIHelper.load_texture_safe("res://assets/images/brushing/brushingmascot.png")
		
	_sir_crown_rect = TextureRect.new()
	_sir_crown_rect.texture = crown_tex
	_sir_crown_rect.custom_minimum_size = Vector2(170, 170)
	_sir_crown_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sir_crown_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_sir_crown_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_sir_crown_rect.pivot_offset = Vector2(85, 85)
	vbox.add_child(_sir_crown_rect)
	
	# Spacer
	var sp1 = Control.new()
	sp1.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(sp1)
	
	# Loading Circle Spinner
	_spinner = LoadingCircleSpinner.new(24.0, 5.0)
	vbox.add_child(_spinner)
	
	# "LOADING..." text
	_loading_label = Label.new()
	_loading_label.text = "LOADING..."
	_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(_loading_label, 22, Color.WHITE, true)
	_loading_label.add_theme_color_override("font_shadow_color", Color(0.15, 0.45, 0.85, 0.9))
	_loading_label.add_theme_constant_override("shadow_offset_x", 0)
	_loading_label.add_theme_constant_override("shadow_offset_y", 2)
	vbox.add_child(_loading_label)
	
	# Subtitle / Hint
	var sub_lbl = Label.new()
	sub_lbl.text = "Preparing Candy Crusade..."
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(sub_lbl, 13, Color(0.70, 0.86, 1.0))
	vbox.add_child(sub_lbl)

func _show_loading_overlay() -> void:
	if _loading_overlay:
		_loading_overlay.visible = true
		_loading_overlay.modulate = Color.WHITE

func _hide_loading_overlay() -> void:
	UIHelper.dismiss_candy_crusade_loading_overlay(self)
	if _loading_overlay and _loading_overlay.visible:
		var tw = create_tween()
		tw.tween_property(_loading_overlay, "modulate:a", 0.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_callback(func():
			if _loading_overlay:
				_loading_overlay.visible = false
		)

func _load_3d_world(region_idx: int) -> void:
	if _game_scene != null and is_instance_valid(_game_scene):
		_game_scene.queue_free()
		_game_scene = null

	# Preloaded at app start by GameState (waits only if that hasn't finished yet)
	var scene_res: PackedScene = await GameState.get_candy_crusade_scene()

	if scene_res == null:
		push_error("Failed to load res://candy_crusade/main.tscn")
		_hide_loading_overlay()
		return
		
	_game_scene = scene_res.instantiate()
	_game_scene.process_mode = Node.PROCESS_MODE_PAUSABLE
	_sub_viewport.add_child(_game_scene)
	
	# Select targeted region on RegionController
	var rc = _game_scene.get_node_or_null("RegionController")
	if rc != null and rc.has_method("select_region"):
		rc.call_deferred("select_region", region_idx)
		
	# Let the first frame render before revealing the arena
	await get_tree().process_frame
	_hide_loading_overlay()


func _connect_bridge() -> void:
	var bridge = get_node_or_null("/root/GameBridge")
	if bridge != null:
		if not bridge.is_connected("game_over_reported", _on_game_over):
			bridge.connect("game_over_reported", _on_game_over)
		if not bridge.is_connected("exit_game_requested", _on_exit_requested):
			bridge.connect("exit_game_requested", _on_exit_requested)

func _on_game_over(payload: Dictionary) -> void:
	var result_str: String = str(payload.get("result", "DEFEAT")).to_upper()
	_last_victory = (result_str == "VICTORY")
	if _last_victory:
		AudioManager.play_sfx("victory")
	_session_completed = true
	
	# Points and coins are already added by GameBridge.sync_rewards_to_game_state()
	# (adding them here as well paid every reward twice).
	
	# Track defeated enemies in profile
	var minions: int = int(payload.get("minionsDefeated", 0))
	if minions > 0:
		GameState.increment_stat("minions_defeated", minions)
	# Every Candy Crusade win counts as one "Sweet Defeat" of Blue Candor
	if _last_victory:
		GameState.increment_stat("bosses_defeated", 1)

func _on_exit_requested() -> void:
	get_tree().paused = false
	UIHelper.dismiss_candy_crusade_loading_overlay(self)
	combat_finished.emit(_last_victory)

func _on_exit_pressed() -> void:
	AudioManager.play_sfx("click")
	get_tree().paused = false
	UIHelper.dismiss_candy_crusade_loading_overlay(self)
	combat_finished.emit(_last_victory)
