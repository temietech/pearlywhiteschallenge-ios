@tool
extends CanvasLayer
class_name HUD

@onready var _spawner: Node = get_node_or_null("../EnemySpawner")
@onready var _player: Node = get_node_or_null("../Player")

var _player_hp_bar: ProgressBar
var _boss_hp_bar: ProgressBar
var _boss_hp_label: Label
var _region_label: Label
var _wave_label: Label

var _clear_panel: Control
var _boss_avatar_container: Control
var _dev_panel: PanelContainer
var _pause_panel: Control

var _weapon_cards: Dictionary = {}
var _weapon_tweens: Dictionary = {}
var _current_active_weapon: String = "pistol"
var _ammo_labels: Dictionary = {}
var _combo_container: PanelContainer
var _combo_label: Label
var _out_of_ammo_popup: Label
var _player_avatar_rect: TextureRect
var _player_name_label: Label
var _item_window_texture: Texture2D = null
var _cached_ui_textures: Dictionary = {}
var _clear_title_banner: TextureRect
var _clear_stars_container: HBoxContainer
var _clear_score_label: Label
var _in_game_coin_label: Label

var _shield_badge: HBoxContainer
var _shield_bar: ProgressBar
var _shield_label: Label
var _shield_icon: TextureRect

# Bottom weapon bar reference (used to auto-fade when minions are close)
var _weapon_bar: Control = null
var _weapon_bar_target_alpha := 1.0
var _weapon_bar_fade_tween: Tween = null

func _ready() -> void:
	_ensure_custom_ui_assets()
	if Engine.is_editor_hint():
		return
	add_to_group("hud")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	
	get_tree().node_added.connect(func(n: Node):
		if n.is_in_group("bosses") or n.is_in_group("boss") or n.name.contains("BlueCandor"):
			_connect_boss(n)
	)
	for b in get_tree().get_nodes_in_group("bosses"):
		_connect_boss(b)
	
	if _player:
		if _player.has_signal("health_changed"):
			_player.connect("health_changed", _on_player_health_changed)
		if _player.has_signal("weapon_activated"):
			_player.connect("weapon_activated", _on_weapon_activated)
		if _player.has_signal("died"):
			_player.connect("died", _on_player_died)
		if _player.has_signal("shield_updated"):
			_player.connect("shield_updated", _on_player_shield_updated)
	
	var bridge = get_node_or_null("/root/GameBridge")
	if bridge != null:
		if bridge.has_signal("session_ready"):
			bridge.session_ready.connect(func(_p):
				_update_avatar_display()
				_update_player_name()
				_refresh_all_cards()
				if bridge.equipped != "":
					_highlight_weapon(bridge.to_internal_weapon(bridge.equipped))
			)
		if bridge.has_signal("ammo_changed"):
			bridge.ammo_changed.connect(func(key: String, _count: int):
				_update_ammo_display(key)
			)
		if bridge.has_signal("battery_charge_changed"):
			bridge.battery_charge_changed.connect(func(_used: int, _needed: int):
				_update_battery_pips()
			)
		if bridge.has_signal("weapon_auto_switched"):
			bridge.weapon_auto_switched.connect(func(_b_id: String, int_id: String):
				_highlight_weapon(int_id)
			)
		if bridge.get("initialized") == true:
			_update_avatar_display()
			_update_player_name()
			_refresh_all_cards()

	var game = get_node_or_null("/root/Game")
	if game != null:
		if game.has_signal("weapon_level_changed"):
			game.weapon_level_changed.connect(func(w_key: String, lvl: int):
				var c_key := w_key
				if c_key == "floss": c_key = "lasso"
				elif c_key == "paste": c_key = "pistol"
				elif c_key == "brush": c_key = "boomerang"
				elif c_key == "wash": c_key = "grenade"
				if _weapon_cards.has(c_key):
					_update_card_icon(_weapon_cards[c_key], c_key, lvl)
				_update_ammo_display(c_key)
			)
		if game.has_signal("ammo_changed"):
			game.ammo_changed.connect(func(w_key: String, _cur: int, _sp: int):
				_update_ammo_display(w_key)
			)
		if game.has_signal("battery_charge_changed"):
			game.battery_charge_changed.connect(func(_used: int, _needed: int):
				_update_battery_pips()
			)
		if game.has_signal("combo_changed"):
			game.combo_changed.connect(_on_combo_changed)
		if game.has_signal("shield_status_changed"):
			game.shield_status_changed.connect(_on_player_shield_updated)

	_refresh_all_cards()
	var default_w := "pistol"
	if bridge != null and bridge.equipped != "":
		default_w = bridge.to_internal_weapon(bridge.equipped)
	call_deferred("_highlight_weapon", default_w)


func _refresh_all_cards() -> void:
	for key in ["pistol", "boomerang", "grenade", "lasso"]:
		if _weapon_cards.has(key):
			_update_card_icon(_weapon_cards[key], key)
		_update_ammo_display(key)
	_update_battery_pips()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or _weapon_bar == null:
		return
	# Fade the bottom weapon bar out when any enemy is close enough
	# to be hidden beneath it. Minions walk in +Z toward the player
	# (who sits at Z=0). REACH_Z = -0.5, so danger starts ~z > -5.
	var closest_z := -999.0
	for minion in get_tree().get_nodes_in_group("minions"):
		if minion is Node3D and not minion.get("_dead") and not minion.is_queued_for_deletion():
			var mz: float = (minion as Node3D).global_position.z
			if mz > closest_z:
				closest_z = mz
	for boss in get_tree().get_nodes_in_group("bosses"):
		if boss is Node3D and not boss.get("_dead") and not boss.is_queued_for_deletion():
			var bz: float = (boss as Node3D).global_position.z
			if bz > closest_z:
				closest_z = bz

	# Fade zone: start fading at z = -6.0, fully transparent at z = -2.0
	const FADE_START_Z := -6.0
	const FADE_END_Z   := -2.0
	var target_alpha: float
	if closest_z >= FADE_END_Z:
		target_alpha = 0.08   # Almost invisible — just a ghost hint
	elif closest_z <= FADE_START_Z:
		target_alpha = 1.0    # Full opacity when enemies are far away
	else:
		var t := (closest_z - FADE_START_Z) / (FADE_END_Z - FADE_START_Z)
		target_alpha = lerpf(1.0, 0.08, clampf(t, 0.0, 1.0))

	if absf(target_alpha - _weapon_bar_target_alpha) > 0.02:
		_weapon_bar_target_alpha = target_alpha
		if _weapon_bar_fade_tween != null and _weapon_bar_fade_tween.is_valid():
			_weapon_bar_fade_tween.kill()
		_weapon_bar_fade_tween = create_tween()
		_weapon_bar_fade_tween.tween_property(
			_weapon_bar, "modulate:a", target_alpha, 0.3
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	if _in_game_coin_label != null:
		var bridge = get_node_or_null("/root/GameBridge")
		var current_coins: int = int(bridge.get("coins_collected")) if bridge != null else 0
		_in_game_coin_label.text = str(current_coins)


func _on_player_died() -> void:
	var score := 0
	if _spawner and "_score" in _spawner:
		score = int(_spawner.get("_score"))
	var reg := 0
	var controller = get_tree().get_first_node_in_group("region_controller")
	if controller and controller.has_method("get_current_region_index"):
		reg = controller.get_current_region_index()
		
	var bridge = get_node_or_null("/root/GameBridge")
	if bridge != null:
		var dur: float = (Time.get_ticks_msec() / 1000.0) - float(bridge.get("run_start_time"))
		var minions: int = int(bridge.get("minions_defeated"))
		var coins: int = int(bridge.get("coins_collected"))
		var objectives := [
			{ "id": "no_damage", "label": "Flawless Smile", "completed": false },
			{ "id": "all_plaque_cleared", "label": "Every Cavity Cleared", "completed": false }
		]
		bridge.send_game_over("DEFEAT", score, coins, minions, false, bridge.get("ammo"), objectives, dur)
	else:
		var game = get_node_or_null("/root/Game")
		if game != null and game.has_method("send_completion_to_lovable"):
			game.send_completion_to_lovable("defeat", score, reg)

	call_deferred("show_defeat_screen")

func _on_weapon_activated(weapon_name: String) -> void:
	_highlight_weapon(weapon_name)
	if _player != null and _player.has_method("set_selected_weapon"):
		_player.call("set_selected_weapon", weapon_name)

func _on_player_health_changed(current: int, maximum: int) -> void:
	if _player_hp_bar:
		_player_hp_bar.max_value = maximum
		_player_hp_bar.value = current


func _on_player_shield_updated(active: bool, ratio: float, remaining_shields: int) -> void:
	if _shield_badge == null:
		return
	if active:
		_shield_badge.visible = true
		if _shield_bar != null:
			_shield_bar.value = ratio * 100.0
		if _shield_label != null:
			if remaining_shields > 0:
				_shield_label.text = "SHIELD (+%d)" % remaining_shields
			else:
				_shield_label.text = "SHIELD"
		# Punch bounce animation on update
		var tw := create_tween()
		tw.tween_property(_shield_badge, "scale", Vector2(1.12, 1.12), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(_shield_badge, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		if _shield_badge.visible:
			var tw := create_tween()
			tw.tween_property(_shield_badge, "modulate:a", 0.0, 0.25)
			tw.tween_callback(func():
				if _shield_badge:
					_shield_badge.visible = false
					_shield_badge.modulate.a = 1.0
			)


func _build_ui() -> void:
	# Combat Crosshair Reticle centered on screen
	var reticle_tex = _get_ui_texture("crosshair_reticle")
	if reticle_tex != null:
		var reticle_center = CenterContainer.new()
		reticle_center.set_anchors_preset(Control.PRESET_FULL_RECT)
		reticle_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(reticle_center)
		
		var reticle = TextureRect.new()
		reticle.texture = reticle_tex
		reticle.custom_minimum_size = Vector2(40, 40)
		reticle.size = Vector2(40, 40)
		reticle.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		reticle.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		reticle.modulate = Color(1.0, 1.0, 1.0, 0.75)
		reticle_center.add_child(reticle)

	var top_margin = MarginContainer.new()
	top_margin.add_theme_constant_override("margin_top", 38)
	top_margin.add_theme_constant_override("margin_left", 15)
	top_margin.add_theme_constant_override("margin_right", 15)
	top_margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	add_child(top_margin)

	# Combo multiplier display
	var combo_center := CenterContainer.new()
	combo_center.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	combo_center.offset_top = 80
	combo_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(combo_center)
	
	_combo_container = PanelContainer.new()
	_combo_container.custom_minimum_size = Vector2(190, 36)
	_combo_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var combo_sb := StyleBoxFlat.new()
	combo_sb.bg_color = Color(0.12, 0.08, 0.28, 0.90)
	combo_sb.border_color = Color(1.0, 0.8, 0.2, 0.95)
	combo_sb.set_border_width_all(2)
	combo_sb.set_corner_radius_all(12)
	combo_sb.shadow_color = Color(1.0, 0.55, 0.0, 0.45)
	combo_sb.shadow_size = 8
	combo_sb.content_margin_left = 14
	combo_sb.content_margin_right = 14
	combo_sb.content_margin_top = 4
	combo_sb.content_margin_bottom = 4
	_combo_container.add_theme_stylebox_override("panel", combo_sb)
	combo_center.add_child(_combo_container)
	
	_combo_label = Label.new()
	_combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_combo_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_combo_label.add_theme_font_size_override("font_size", 16)
	_combo_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.25))
	_combo_label.add_theme_color_override("font_outline_color", Color(0.15, 0.05, 0.02))
	_combo_label.add_theme_constant_override("outline_size", 5)
	_combo_label.text = "COMBO x2 (1.2x)"
	_combo_container.add_child(_combo_label)
	_combo_container.visible = false
	
	var top_hbox = HBoxContainer.new()
	top_margin.add_child(top_hbox)
	
	var player_hbox = HBoxContainer.new()
	player_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	top_hbox.add_child(player_hbox)
	
	var p_avatar = Panel.new()
	p_avatar.custom_minimum_size = Vector2(50, 50)
	p_avatar.clip_contents = true
	var sb_circle = StyleBoxFlat.new()
	sb_circle.bg_color = Color(0.12, 0.16, 0.24, 0.95)
	sb_circle.border_color = Color(0.3, 0.85, 1.0, 0.9)
	sb_circle.border_width_left = 2
	sb_circle.border_width_top = 2
	sb_circle.border_width_right = 2
	sb_circle.border_width_bottom = 2
	sb_circle.corner_radius_top_left = 25
	sb_circle.corner_radius_top_right = 25
	sb_circle.corner_radius_bottom_left = 25
	sb_circle.corner_radius_bottom_right = 25
	p_avatar.add_theme_stylebox_override("panel", sb_circle)
	player_hbox.add_child(p_avatar)
	
	_player_avatar_rect = TextureRect.new()
	_player_avatar_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_player_avatar_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_player_avatar_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_player_avatar_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p_avatar.add_child(_player_avatar_rect)
	_update_avatar_display()
	
	var p_vbox = VBoxContainer.new()
	p_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	p_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_hbox.add_child(p_vbox)
	
	_player_name_label = Label.new()
	_player_name_label.text = "Player"
	_player_name_label.add_theme_font_size_override("font_size", 14)
	_player_name_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	_player_name_label.add_theme_color_override("font_outline_color", Color(0.08, 0.12, 0.22))
	_player_name_label.add_theme_constant_override("outline_size", 3)
	_update_player_name()
	p_vbox.add_child(_player_name_label)
	
	var hp_hbox = HBoxContainer.new()
	hp_hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	hp_hbox.add_theme_constant_override("separation", 6)
	p_vbox.add_child(hp_hbox)
	
	var heart_tex = _get_ui_texture("heart_candy.jpg")
	if heart_tex != null:
		var heart_icon = TextureRect.new()
		heart_icon.texture = heart_tex
		heart_icon.custom_minimum_size = Vector2(20, 20)
		heart_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		heart_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		heart_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hp_hbox.add_child(heart_icon)

	_player_hp_bar = ProgressBar.new()
	_player_hp_bar.custom_minimum_size = Vector2(110, 14)
	_player_hp_bar.show_percentage = false
	_player_hp_bar.value = 100
	var sb_bg = StyleBoxFlat.new()
	sb_bg.bg_color = Color(0.1, 0.08, 0.18, 0.85)
	sb_bg.set_corner_radius_all(7)
	var p_sb_fg = StyleBoxFlat.new()
	p_sb_fg.bg_color = Color(0.24, 0.88, 0.45)
	p_sb_fg.set_corner_radius_all(7)
	p_sb_fg.border_color = Color(0.75, 1.0, 0.85, 0.8)
	p_sb_fg.set_border_width_all(1)
	_player_hp_bar.add_theme_stylebox_override("background", sb_bg)
	_player_hp_bar.add_theme_stylebox_override("fill", p_sb_fg)
	hp_hbox.add_child(_player_hp_bar)
	
	var coin_box = HBoxContainer.new()
	coin_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	coin_box.add_theme_constant_override("separation", 5)
	p_vbox.add_child(coin_box)
	
	var coin_tex = _get_ui_texture("coin_candy.jpg")
	if coin_tex != null:
		var c_icon = TextureRect.new()
		c_icon.texture = coin_tex
		c_icon.custom_minimum_size = Vector2(16, 16)
		c_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		c_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		c_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		coin_box.add_child(c_icon)
		
	_in_game_coin_label = Label.new()
	_in_game_coin_label.text = "0"
	_in_game_coin_label.add_theme_font_size_override("font_size", 12)
	_in_game_coin_label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.35))
	_in_game_coin_label.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.16))
	_in_game_coin_label.add_theme_constant_override("outline_size", 3)
	coin_box.add_child(_in_game_coin_label)

	# Fluoride Shield Status Badge
	_shield_badge = HBoxContainer.new()
	_shield_badge.alignment = BoxContainer.ALIGNMENT_BEGIN
	_shield_badge.add_theme_constant_override("separation", 5)
	p_vbox.add_child(_shield_badge)
	
	_shield_icon = TextureRect.new()
	_shield_icon.custom_minimum_size = Vector2(16, 16)
	_shield_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_shield_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_shield_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shield_badge.add_child(_shield_icon)
	
	var shield_tex: Texture2D = _get_shield_icon_texture()
	if shield_tex != null:
		_shield_icon.texture = shield_tex
		
	_shield_bar = ProgressBar.new()
	_shield_bar.custom_minimum_size = Vector2(70, 10)
	_shield_bar.show_percentage = false
	_shield_bar.value = 100
	var sb_sh_bg = StyleBoxFlat.new()
	sb_sh_bg.bg_color = Color(0.08, 0.12, 0.20, 0.85)
	sb_sh_bg.set_corner_radius_all(5)
	var sb_sh_fg = StyleBoxFlat.new()
	sb_sh_fg.bg_color = Color(0.25, 0.92, 1.0)
	sb_sh_fg.set_corner_radius_all(5)
	sb_sh_fg.border_color = Color(0.7, 1.0, 1.0, 0.85)
	sb_sh_fg.set_border_width_all(1)
	_shield_bar.add_theme_stylebox_override("background", sb_sh_bg)
	_shield_bar.add_theme_stylebox_override("fill", sb_sh_fg)
	_shield_badge.add_child(_shield_bar)
	
	_shield_label = Label.new()
	_shield_label.text = "SHIELD"
	_shield_label.add_theme_font_size_override("font_size", 10)
	_shield_label.add_theme_color_override("font_color", Color(0.35, 1.0, 0.95))
	_shield_label.add_theme_color_override("font_outline_color", Color(0.06, 0.12, 0.2))
	_shield_label.add_theme_constant_override("outline_size", 2)
	_shield_badge.add_child(_shield_label)
	_shield_badge.visible = false

	
	# Modern glossy Level & Wave Pill Banner
	var center_wrapper = CenterContainer.new()
	center_wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_hbox.add_child(center_wrapper)

	var level_card = PanelContainer.new()
	level_card.custom_minimum_size = Vector2(180, 46)
	var lc_sb := StyleBoxFlat.new()
	lc_sb.bg_color = Color(0.08, 0.15, 0.30, 0.90)
	lc_sb.border_color = Color(0.40, 0.85, 1.0, 0.95)
	lc_sb.set_border_width_all(2)
	lc_sb.set_corner_radius_all(15)
	lc_sb.shadow_color = Color(0.0, 0.05, 0.15, 0.45)
	lc_sb.shadow_size = 8
	lc_sb.content_margin_left = 14
	lc_sb.content_margin_right = 14
	lc_sb.content_margin_top = 4
	lc_sb.content_margin_bottom = 4
	level_card.add_theme_stylebox_override("panel", lc_sb)
	center_wrapper.add_child(level_card)

	var center_vbox = VBoxContainer.new()
	center_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center_vbox.add_theme_constant_override("separation", 2)
	level_card.add_child(center_vbox)

	_region_label = Label.new()
	_region_label.text = "LEVEL 1: CANDY CAVE"
	_region_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_region_label.add_theme_font_size_override("font_size", 13)
	_region_label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.40))
	_region_label.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.16, 0.95))
	_region_label.add_theme_constant_override("outline_size", 4)
	center_vbox.add_child(_region_label)

	_wave_label = Label.new()
	_wave_label.text = "WAVE 1 OF 1"
	_wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wave_label.add_theme_font_size_override("font_size", 10)
	_wave_label.add_theme_color_override("font_color", Color(0.50, 0.92, 1.0))
	_wave_label.add_theme_color_override("font_outline_color", Color(0.06, 0.08, 0.18, 0.95))
	_wave_label.add_theme_constant_override("outline_size", 3)
	center_vbox.add_child(_wave_label)

	_boss_avatar_container = HBoxContainer.new()
	_boss_avatar_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_boss_avatar_container.alignment = BoxContainer.ALIGNMENT_END
	_boss_avatar_container.add_theme_constant_override("separation", 8)
	top_hbox.add_child(_boss_avatar_container)
	
	var b_vbox = VBoxContainer.new()
	b_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	b_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_boss_avatar_container.add_child(b_vbox)
	
	var b_header = HBoxContainer.new()
	b_header.alignment = BoxContainer.ALIGNMENT_END
	b_header.add_theme_constant_override("separation", 6)
	b_vbox.add_child(b_header)
	
	var b_title = Label.new()
	b_title.text = "BLUE CANDOR"
	b_title.add_theme_font_size_override("font_size", 12)
	b_title.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
	b_title.add_theme_color_override("font_outline_color", Color(0.04, 0.08, 0.18))
	b_title.add_theme_constant_override("outline_size", 3)
	b_header.add_child(b_title)

	_boss_hp_label = Label.new()
	_boss_hp_label.text = "0/0"
	_boss_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_boss_hp_label.add_theme_font_size_override("font_size", 12)
	_boss_hp_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	_boss_hp_label.add_theme_color_override("font_outline_color", Color(0.04, 0.08, 0.18))
	_boss_hp_label.add_theme_constant_override("outline_size", 3)
	b_header.add_child(_boss_hp_label)
	
	_boss_hp_bar = ProgressBar.new()
	_boss_hp_bar.custom_minimum_size = Vector2(110, 14)
	_boss_hp_bar.show_percentage = false
	var b_sb_fg = StyleBoxFlat.new()
	b_sb_fg.bg_color = Color(0.95, 0.22, 0.32)
	b_sb_fg.set_corner_radius_all(7)
	b_sb_fg.border_color = Color(1.0, 0.65, 0.7, 0.8)
	b_sb_fg.set_border_width_all(1)
	_boss_hp_bar.add_theme_stylebox_override("background", sb_bg)
	_boss_hp_bar.add_theme_stylebox_override("fill", b_sb_fg)
	b_vbox.add_child(_boss_hp_bar)
	
	var b_avatar = Panel.new()
	b_avatar.custom_minimum_size = Vector2(52, 52)
	b_avatar.clip_contents = true
	var sb_circle2 = StyleBoxFlat.new()
	sb_circle2.bg_color = Color(0.12, 0.46, 1.0)
	sb_circle2.set_corner_radius_all(26)
	b_avatar.add_theme_stylebox_override("panel", sb_circle2)
	var boss_tex = _get_ui_texture("boss_candor_avatar.jpg")
	if boss_tex != null:
		var b_tex_rect = TextureRect.new()
		b_tex_rect.texture = boss_tex
		b_tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		b_tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		b_tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		b_avatar.add_child(b_tex_rect)
	_boss_avatar_container.add_child(b_avatar)
	_boss_avatar_container.visible = false
	
	var pause_btn = TextureButton.new()
	pause_btn.custom_minimum_size = Vector2(42, 42)
	pause_btn.ignore_texture_size = true
	pause_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	pause_btn.pivot_offset = Vector2(21, 21)
	pause_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var pause_tex = UIHelper.get_pause_button_texture() if UIHelper else null
	if not pause_tex:
		pause_tex = _get_ui_texture("btn_pause")
	if pause_tex != null:
		pause_btn.texture_normal = pause_tex
	else:
		var fb_lbl = Label.new()
		fb_lbl.text = "||"
		fb_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		fb_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fb_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		fb_lbl.add_theme_font_size_override("font_size", 18)
		pause_btn.add_child(fb_lbl)
	pause_btn.mouse_entered.connect(func():
		var tw = create_tween()
		tw.tween_property(pause_btn, "scale", Vector2(1.12, 1.12), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	)
	pause_btn.mouse_exited.connect(func():
		var tw = create_tween()
		tw.tween_property(pause_btn, "scale", Vector2.ONE, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	)
	pause_btn.pressed.connect(_toggle_pause_menu)
	top_hbox.add_child(pause_btn)
	
	# Bottom Weapon UI
	_ensure_weapon_assets()
	
	var bot_margin = MarginContainer.new()
	bot_margin.add_theme_constant_override("margin_bottom", 0)
	bot_margin.add_theme_constant_override("margin_left", 8)
	bot_margin.add_theme_constant_override("margin_right", 8)
	bot_margin.add_theme_constant_override("margin_top", 0)
	# Anchor to the full bottom strip, extending flush to the bottom edge
	bot_margin.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bot_margin.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bot_margin.custom_minimum_size = Vector2(0, 140)
	bot_margin.offset_bottom = 0
	bot_margin.offset_top = -140
	bot_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bot_margin.visible = true
	add_child(bot_margin)
	_weapon_bar = bot_margin
	
	var main_bar = Control.new()
	main_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_bar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bot_margin.add_child(main_bar)

	# Sleek semi-transparent frosted candy glass panel
	var bar_panel = Panel.new()
	bar_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bar_sb := StyleBoxFlat.new()
	bar_sb.bg_color = Color(0.06, 0.10, 0.22, 0.72)
	bar_sb.corner_radius_top_left = 22
	bar_sb.corner_radius_top_right = 22
	bar_sb.corner_radius_bottom_left = 0
	bar_sb.corner_radius_bottom_right = 0
	bar_sb.border_width_top = 2
	bar_sb.border_width_left = 2
	bar_sb.border_width_right = 2
	bar_sb.border_color = Color(0.35, 0.75, 1.0, 0.6)
	bar_sb.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	bar_sb.shadow_size = 8
	bar_panel.add_theme_stylebox_override("panel", bar_sb)
	bar_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_bar.add_child(bar_panel)

	var content_margin = MarginContainer.new()
	content_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	content_margin.add_theme_constant_override("margin_top", 6)
	content_margin.add_theme_constant_override("margin_bottom", 6)
	content_margin.add_theme_constant_override("margin_left", 8)
	content_margin.add_theme_constant_override("margin_right", 8)
	content_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_bar.add_child(content_margin)
	
	var cards_hbox = HBoxContainer.new()
	cards_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	cards_hbox.add_theme_constant_override("separation", 8)
	cards_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_margin.add_child(cards_hbox)
	
	var card_keys = ["pistol", "boomerang", "grenade", "lasso"]
	
	for key in card_keys:
		var card_node = _create_custom_weapon_card(cards_hbox, key)
		_weapon_cards[key] = card_node
	
	_build_dev_and_clear_panels()


func _ensure_custom_ui_assets() -> void:
	var user_star := "C:/Users/temie/.gemini/antigravity/brain/3823790e-41b4-4203-b448-e4af1191da65/.user_uploaded/media_1790359057804.png"
	var dest_star := ProjectSettings.globalize_path("res://assets/candy_crusade/ui/star_candy.png")
	var dest_gold := ProjectSettings.globalize_path("res://assets/candy_crusade/ui/star_gold.png")
	var sorted_star := ProjectSettings.globalize_path("res://assets/images/candycrusadegame/star.png")
	if FileAccess.file_exists(user_star):
		DirAccess.make_dir_recursive_absolute(dest_star.get_base_dir())
		DirAccess.copy_absolute(user_star, dest_star)
		DirAccess.copy_absolute(user_star, dest_gold)
		DirAccess.make_dir_recursive_absolute(sorted_star.get_base_dir())
		DirAccess.copy_absolute(user_star, sorted_star)


func _get_window_texture() -> Texture2D:
	var candidates := [
		"res://assets/images/badgescreen/game_blue_windo_b.png",
		"res://assets/images/shop/game_blue_windo_b.png",
		"res://assets/images/candytrap/game_blue_windo_b.png",
		"res://assets/images/misc/game_blue_windo_b.png"
	]
	for p in candidates:
		var t = UIHelper.load_texture_safe(p)
		if t != null:
			return t
	return null


static func _make_image_transparent(src: Image, is_circular: bool = false, circle_ratio: float = 0.45) -> Image:
	var img := src.duplicate() as Image
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	
	if is_circular:
		var cx := float(w) * 0.5
		var cy := float(h) * 0.5
		var max_r := float(w) * circle_ratio
		var feather := maxf(2.0, float(w) * 0.015)
		
		for y in range(h):
			for x in range(w):
				var dx := float(x) - cx
				var dy := float(y) - cy
				var d := sqrt(dx * dx + dy * dy)
				if d >= max_r:
					img.set_pixel(x, y, Color(0, 0, 0, 0))
				elif d > max_r - feather:
					var factor: float = (max_r - d) / feather
					var c := img.get_pixel(x, y)
					c.a *= clampf(factor, 0.0, 1.0)
					img.set_pixel(x, y, c)
				else:
					var c := img.get_pixel(x, y)
					var max_v := maxf(c.r, maxf(c.g, c.b))
					if max_v < 0.16 and d > max_r * 0.88:
						var rim_a := clampf((max_v - 0.08) / 0.08, 0.0, 1.0)
						c.a *= rim_a
						img.set_pixel(x, y, c)
		return img

	# BFS flood-fill from all 4 outer borders through connected dark pixels
	var visited := PackedByteArray()
	visited.resize(w * h)
	visited.fill(0)
	
	var c_tl := img.get_pixel(0, 0)
	var c_tr := img.get_pixel(w - 1, 0)
	var c_bl := img.get_pixel(0, h - 1)
	var c_br := img.get_pixel(w - 1, h - 1)
	var bg_peak := maxf(
		maxf(c_tl.r, maxf(c_tl.g, c_tl.b)),
		maxf(maxf(c_tr.r, maxf(c_tr.g, c_tr.b)),
		maxf(maxf(c_bl.r, maxf(c_bl.g, c_bl.b)), maxf(c_br.r, maxf(c_br.g, c_br.b))))
	)
	var cutoff_hard := maxf(0.18, bg_peak + 0.05)
	var cutoff_soft := cutoff_hard + 0.14
	
	var q_x: Array[int] = []
	var q_y: Array[int] = []
	
	for x in range(w):
		q_x.append(x)
		q_y.append(0)
		visited[x] = 1
		q_x.append(x)
		q_y.append(h - 1)
		visited[(h - 1) * w + x] = 1
		
	for y in range(1, h - 1):
		q_x.append(0)
		q_y.append(y)
		visited[y * w] = 1
		q_x.append(w - 1)
		q_y.append(y)
		visited[y * w + (w - 1)] = 1
		
	var head := 0
	while head < q_x.size():
		var x: int = q_x[head]
		var y: int = q_y[head]
		head += 1
		
		var c := img.get_pixel(x, y)
		var val := maxf(c.r, maxf(c.g, c.b))
		
		if val <= cutoff_hard:
			img.set_pixel(x, y, Color(0, 0, 0, 0))
		elif val < cutoff_soft:
			var a := clampf((val - cutoff_hard) / (cutoff_soft - cutoff_hard), 0.0, 1.0)
			c.a = a
			if a > 0.02:
				var scale_f := 1.0 / maxf(a, 0.4)
				c.r = clampf(c.r * scale_f, 0.0, 1.0)
				c.g = clampf(c.g * scale_f, 0.0, 1.0)
				c.b = clampf(c.b * scale_f, 0.0, 1.0)
			img.set_pixel(x, y, c)
			continue
		else:
			continue
			
		var n_coords := [[x + 1, y], [x - 1, y], [x, y + 1], [x, y - 1]]
		for nc in n_coords:
			var nx: int = nc[0]
			var ny: int = nc[1]
			if nx >= 0 and nx < w and ny >= 0 and ny < h:
				var idx := ny * w + nx
				if visited[idx] == 0:
					visited[idx] = 1
					var p := img.get_pixel(nx, ny)
					var p_val := maxf(p.r, maxf(p.g, p.b))
					if p_val < cutoff_soft:
						q_x.append(nx)
						q_y.append(ny)
						
	return img


func _get_ui_texture(asset_key: String) -> Texture2D:
	var base_name := asset_key.get_file().get_basename()
	if _cached_ui_textures.has(base_name) and _cached_ui_textures[base_name] != null:
		return _cached_ui_textures[base_name]
		
	var candidates := [
		"res://assets/images/candycrusadegame/" + base_name + ".png",
		"res://assets/images/candycrusadegame/" + base_name + ".jpg",
		"res://assets/candy_crusade/ui/" + base_name + ".png",
		"res://assets/candy_crusade/ui/" + base_name + ".png",
		"res://assets/candy_crusade/ui/" + base_name + ".jpg",
		"res://assets/candy_crusade/ui/" + base_name + ".jpg"
	]
	var tex: Texture2D = null
	for path in candidates:
		if ResourceLoader.exists(path):
			tex = load(path)
			if tex != null:
				break
		elif FileAccess.file_exists(path):
			var img := Image.load_from_file(path)
			if img and not img.is_empty():
				tex = ImageTexture.create_from_image(img)
				if tex != null:
					break
				
	if tex != null:
		_cached_ui_textures[base_name] = tex
		_cached_ui_textures[asset_key] = tex
	return tex


func _get_shield_icon_texture() -> Texture2D:
	var candidates := [
		"res://assets/candy_crusade/ui/fluorideshield.png",
		"res://assets/candy_crusade/ui/fluorideshield.png",
		"res://assets/images/shop/fluorideshield.png",
		"res://assets/images/shop/fluorideshield.png"
	]
	for path in candidates:
		if ResourceLoader.exists(path):
			return load(path)
		elif FileAccess.file_exists(path):
			var img := Image.load_from_file(path)
			if img and not img.is_empty():
				return ImageTexture.create_from_image(img)
	# Procedural shield icon if file not found
	var pimg := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	pimg.fill(Color(0, 0, 0, 0))
	for y in range(16):
		for x in range(16):
			var dx: float = absf(x - 7.5) / 7.5
			var dy: float = float(y) / 15.0
			if dy >= dx * 0.4 and dy <= 1.0 - dx * 0.6:
				pimg.set_pixel(x, y, Color(0.3, 0.95, 1.0, 0.95))
	return ImageTexture.create_from_image(pimg)



func _connect_boss(boss: Node) -> void:
	if boss == null:
		return
	if boss.has_signal("health_changed") and not boss.health_changed.is_connected(set_boss_health):
		boss.health_changed.connect(set_boss_health)
	if boss.has_signal("died") and not boss.died.is_connected(_on_boss_died):
		boss.died.connect(_on_boss_died)
	var hp: int = int(boss.get("health"))
	var max_hp: int = int(boss.get("max_health"))
	if max_hp > 0:
		set_boss_health(hp, max_hp)


func set_boss_health(current: int, maximum: int) -> void:
	if _boss_avatar_container == null:
		return
	_boss_avatar_container.visible = (current > 0)
	_boss_avatar_container.modulate.a = 1.0
	if _boss_hp_bar != null:
		_boss_hp_bar.max_value = maximum
		_boss_hp_bar.value = current
	if _boss_hp_label != null:
		_boss_hp_label.text = "%d / %d" % [current, maximum]


func _on_boss_died() -> void:
	if _boss_hp_bar != null:
		_boss_hp_bar.value = 0
	if _boss_hp_label != null:
		_boss_hp_label.text = "DEFEATED!"
	var tw := create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(_boss_avatar_container, "modulate:a", 0.0, 0.6)
	tw.tween_callback(func():
		if _boss_avatar_container:
			_boss_avatar_container.visible = false
	)


func _get_item_window_texture() -> Texture2D:
	if _item_window_texture != null:
		return _item_window_texture
	var candidates := [
		"res://assets/candy_crusade/ui/ItemWindow.png",
		"res://assets/candy_crusade/ui/ItemWindow.png"
	]
	for path in candidates:
		if ResourceLoader.exists(path):
			_item_window_texture = load(path)
			if _item_window_texture != null: break
		elif FileAccess.file_exists(path):
			var img := Image.load_from_file(path)
			if img and not img.is_empty():
				_item_window_texture = ImageTexture.create_from_image(img)
				if _item_window_texture != null: break
	return _item_window_texture


func _create_custom_weapon_card(parent: Control, key: String) -> Control:
	var col = VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(col)

	# 1. Weapon Name Label Above
	var name_lbl = Label.new()
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 10)
	name_lbl.add_theme_constant_override("outline_size", 2)
	name_lbl.add_theme_color_override("font_outline_color", Color(0.06, 0.12, 0.24, 0.95))
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	match key:
		"pistol":
			name_lbl.text = "PASTE"
			name_lbl.add_theme_color_override("font_color", Color(0.96, 0.40, 0.40))
		"boomerang":
			name_lbl.text = "BRUSH"
			name_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
		"grenade":
			name_lbl.text = "WASH"
			name_lbl.add_theme_color_override("font_color", Color(0.35, 0.80, 1.0))
		"lasso":
			name_lbl.text = "FLOSS"
			name_lbl.add_theme_color_override("font_color", Color(0.40, 0.92, 0.55))
			
	col.add_child(name_lbl)
	col.set_meta("title_lbl", name_lbl)

	# 2. Tile Center (ItemWindow.png glossy bubble square)
	var tile_wrapper = CenterContainer.new()
	tile_wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(tile_wrapper)

	var tile = Control.new()
	tile.custom_minimum_size = Vector2(68, 68)
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile_wrapper.add_child(tile)
	col.set_meta("tile", tile)

	# Background: ItemWindow.png
	var bg_rect = TextureRect.new()
	bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var item_tex = _get_item_window_texture()
	if item_tex != null:
		bg_rect.texture = item_tex
	else:
		var tile_panel = Panel.new()
		tile_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		var fb_sb = StyleBoxFlat.new()
		fb_sb.bg_color = Color(0.15, 0.35, 0.55, 0.85)
		fb_sb.set_corner_radius_all(14)
		fb_sb.border_color = Color(0.65, 0.90, 1.0, 0.8)
		fb_sb.set_border_width_all(2)
		tile_panel.add_theme_stylebox_override("panel", fb_sb)
		tile.add_child(tile_panel)
	tile.add_child(bg_rect)

	# Weapon Icon
	var tex_rect = TextureRect.new()
	tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	tex_rect.offset_left = 4
	tex_rect.offset_top = 4
	tex_rect.offset_right = -4
	tex_rect.offset_bottom = -4
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex_rect.modulate = Color(1.0, 1.0, 1.0, 1.0)
	tile.add_child(tex_rect)
	col.set_meta("tex_rect", tex_rect)

	# Selection Golden Outline Halo
	var highlight_panel = Panel.new()
	highlight_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	highlight_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hl_sb = StyleBoxFlat.new()
	hl_sb.draw_center = false
	hl_sb.border_color = Color(1.0, 0.92, 0.35, 1.0)
	hl_sb.set_border_width_all(3)
	hl_sb.set_corner_radius_all(14)
	hl_sb.shadow_color = Color(0.2, 0.85, 1.0, 0.85)
	hl_sb.shadow_size = 6
	highlight_panel.add_theme_stylebox_override("panel", hl_sb)
	highlight_panel.visible = false
	tile.add_child(highlight_panel)
	col.set_meta("highlight_panel", highlight_panel)

	# Little Level Badge Pill at top-right of tile ("L1", "L2", "BUBBLE")
	var lvl_pill = PanelContainer.new()
	lvl_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lvl_sb = StyleBoxFlat.new()
	lvl_sb.bg_color = Color(0.06, 0.15, 0.32, 0.90)
	lvl_sb.border_color = Color(1.0, 0.86, 0.28, 0.90)
	lvl_sb.set_border_width_all(1)
	lvl_sb.set_corner_radius_all(5)
	lvl_sb.content_margin_left = 3
	lvl_sb.content_margin_right = 3
	lvl_sb.content_margin_top = 1
	lvl_sb.content_margin_bottom = 1
	lvl_pill.add_theme_stylebox_override("panel", lvl_sb)
	lvl_pill.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	lvl_pill.offset_left = -32
	lvl_pill.offset_top = 2
	lvl_pill.offset_right = -2
	lvl_pill.offset_bottom = 16
	
	var lvl_lbl = Label.new()
	lvl_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lvl_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lvl_lbl.add_theme_font_size_override("font_size", 8)
	lvl_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.40))
	lvl_lbl.add_theme_color_override("font_outline_color", Color(0.04, 0.08, 0.16, 0.95))
	lvl_lbl.add_theme_constant_override("outline_size", 2)
	lvl_lbl.text = "L1"
	lvl_pill.add_child(lvl_lbl)
	tile.add_child(lvl_pill)
	col.set_meta("lvl_pill", lvl_pill)
	col.set_meta("lvl_lbl", lvl_lbl)

	# Locked overlay placeholder
	var lock_overlay = CenterContainer.new()
	lock_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	lock_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lock_overlay.visible = false
	tile.add_child(lock_overlay)
	col.set_meta("lock_overlay", lock_overlay)

	# 3. Ammo Number Pill Below
	var ammo_center = CenterContainer.new()
	ammo_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(ammo_center)

	var ammo_pill = PanelContainer.new()
	ammo_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ammo_pill.custom_minimum_size = Vector2(48, 22)
	var pill_sb = StyleBoxFlat.new()
	pill_sb.bg_color = Color(0.08, 0.22, 0.42, 0.85)
	pill_sb.border_color = Color(0.45, 0.85, 1.0, 0.8)
	pill_sb.set_border_width_all(1)
	pill_sb.set_corner_radius_all(10)
	pill_sb.content_margin_left = 6
	pill_sb.content_margin_right = 6
	pill_sb.content_margin_top = 1
	pill_sb.content_margin_bottom = 1
	ammo_pill.add_theme_stylebox_override("panel", pill_sb)
	ammo_center.add_child(ammo_pill)

	var ammo_lbl = Label.new()
	ammo_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ammo_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ammo_lbl.add_theme_font_size_override("font_size", 12)
	ammo_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6))
	ammo_lbl.add_theme_color_override("font_outline_color", Color(0.04, 0.08, 0.16, 0.95))
	ammo_lbl.add_theme_constant_override("outline_size", 3)
	ammo_lbl.text = "0"
	ammo_pill.add_child(ammo_lbl)
	_ammo_labels[key] = ammo_lbl

	if key == "boomerang":
		var pips_lbl = Label.new()
		pips_lbl.name = "ChargePips"
		pips_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pips_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		pips_lbl.add_theme_font_size_override("font_size", 10)
		pips_lbl.add_theme_color_override("font_color", Color(0.35, 0.95, 1.0))
		pips_lbl.add_theme_color_override("font_outline_color", Color(0.04, 0.08, 0.16, 0.95))
		pips_lbl.add_theme_constant_override("outline_size", 3)
		pips_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(pips_lbl)
		col.set_meta("charge_pips", pips_lbl)

	_update_card_icon(col, key)

	return col


func _update_avatar_display() -> void:
	if _player_avatar_rect == null:
		return
	var bridge = get_node_or_null("/root/GameBridge")
	var path := ""
	if bridge != null:
		path = bridge.get_character_portrait_path(bridge.character_id)
	else:
		path = "res://assets/candy_crusade/characters/Chip.jpeg"
	if ResourceLoader.exists(path) or FileAccess.file_exists(path):
		var tex = load(path)
		if tex != null:
			_player_avatar_rect.texture = tex


func _update_player_name() -> void:
	if _player_name_label == null:
		return
	var bridge = get_node_or_null("/root/GameBridge")
	if bridge != null and bridge.player_name != "":
		_player_name_label.text = str(bridge.player_name)


func _update_ammo_display(key: String) -> void:
	if not _ammo_labels.has(key):
		return
	var lbl: Label = _ammo_labels[key]
	var bridge = get_node_or_null("/root/GameBridge")
	var game = get_node_or_null("/root/Game")
	
	if bridge != null and bridge.is_weapon_locked(key):
		lbl.text = "LOCKED"
		lbl.add_theme_font_size_override("font_size", 9)
		lbl.add_theme_color_override("font_color", Color(0.65, 0.70, 0.85, 0.75))
		return
		
	var count: int = 0
	if bridge != null:
		count = bridge.get_ammo_for_weapon(key)
	elif game != null:
		count = game.get_ammo_count(key)
		
	if count < 0:
		lbl.text = "∞"
		lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6))
	else:
		lbl.text = str(count)
		if count == 0:
			lbl.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
		else:
			lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6))

	if key == "boomerang" or key == "brush" or key == "battery":
		_update_battery_pips()


func _update_battery_pips() -> void:
	if not _weapon_cards.has("boomerang"):
		return
	var card: Control = _weapon_cards["boomerang"]
	var pips_lbl: Label = card.get_meta("charge_pips", null)
	if pips_lbl == null:
		return
		
	var bridge = get_node_or_null("/root/GameBridge")
	var game = get_node_or_null("/root/Game")
	var lvl := 1
	if bridge != null:
		lvl = bridge.get_weapon_level("brush")
	elif game != null:
		lvl = int(game.get("boomerang_level"))
		
	if lvl < 2:
		pips_lbl.text = ""
		return
		
	var info: Dictionary = {}
	if bridge != null and bridge.has_method("get_battery_charge_info"):
		info = bridge.get_battery_charge_info()
	elif game != null and game.has_method("get_battery_charge_info"):
		info = game.get_battery_charge_info()
		
	var used: int = int(info.get("used", 0))
	var needed: int = int(info.get("needed", 3 if lvl == 2 else 7))
	var left := maxi(0, needed - used)
	
	if needed == 3:
		var s := ""
		for i in range(needed):
			s += "● " if i < left else "○ "
		pips_lbl.text = s.strip_edges()
	elif needed == 7:
		var s := ""
		for i in range(needed):
			s += "●" if i < left else "○"
		pips_lbl.text = s
	else:
		pips_lbl.text = ""


func _on_combo_changed(streak: int, multiplier: float) -> void:
	if _combo_container == null or _combo_label == null:
		return
	if streak < 2:
		var fade_tw := create_tween()
		fade_tw.tween_property(_combo_container, "modulate:a", 0.0, 0.2)
		fade_tw.tween_callback(func(): _combo_container.visible = false)
		return
	
	_combo_container.visible = true
	_combo_container.modulate.a = 1.0
	_combo_label.text = "COMBO x%d (%.1fx)!" % [streak, multiplier]
	
	# Bounce pop animation
	_combo_container.pivot_offset = _combo_container.size * 0.5
	var pop_tw := create_tween()
	pop_tw.tween_property(_combo_container, "scale", Vector2(1.22, 1.22), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop_tw.tween_property(_combo_container, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func show_out_of_ammo(weapon_name: String) -> void:
	if _out_of_ammo_popup != null and is_instance_valid(_out_of_ammo_popup):
		_out_of_ammo_popup.queue_free()
	
	var lbl := Label.new()
	lbl.text = "OUT OF %s!" % weapon_name.to_upper()
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	lbl.add_theme_color_override("font_outline_color", Color(0.2, 0.02, 0.02))
	lbl.add_theme_constant_override("outline_size", 6)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.set_anchors_preset(Control.PRESET_CENTER)
	lbl.offset_top = -120
	lbl.offset_bottom = -80
	lbl.grow_horizontal = Control.GROW_DIRECTION_BOTH
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lbl)
	_out_of_ammo_popup = lbl
	
	lbl.pivot_offset = lbl.size * 0.5
	lbl.scale = Vector2(0.7, 0.7)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "position:y", lbl.position.y - 30.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.3).set_delay(0.5)
	tw.chain().tween_callback(lbl.queue_free)


func _update_card_icon(card: Control, key: String, level: int = -1) -> void:
	var tex_rect: TextureRect = card.get_meta("tex_rect") if card.has_meta("tex_rect") else null
	if tex_rect == null:
		return
	var bridge = get_node_or_null("/root/GameBridge")
	var game = get_node_or_null("/root/Game")
	
	var is_locked: bool = false
	var effective_lvl := level
	if effective_lvl < 0:
		if bridge != null and bridge.get("initialized") == true:
			effective_lvl = bridge.get_weapon_level(key)
		elif game != null:
			match key:
				"pistol", "paste": effective_lvl = game.pistol_level
				"boomerang", "brush": effective_lvl = game.boomerang_level
				"grenade", "wash": effective_lvl = game.grenade_level
				"lasso", "floss": effective_lvl = game.floss_level
		else:
			effective_lvl = 1

	if bridge != null and bridge.get("initialized") == true:
		is_locked = bridge.is_weapon_locked(key)
	else:
		is_locked = (effective_lvl <= 0)
		
	var lock_overlay = card.get_meta("lock_overlay") if card.has_meta("lock_overlay") else null
	if lock_overlay != null:
		lock_overlay.visible = false

	var lvl_pill = card.get_meta("lvl_pill") if card.has_meta("lvl_pill") else null
	var lvl_lbl: Label = card.get_meta("lvl_lbl") if card.has_meta("lvl_lbl") else null
	if lvl_lbl != null:
		var display_lvl := clampi(effective_lvl if effective_lvl > 0 else 1, 1, 3)
		if display_lvl >= 3:
			lvl_lbl.text = "BUBBLE"
		else:
			lvl_lbl.text = "L%d" % display_lvl
	if lvl_pill != null:
		lvl_pill.visible = not is_locked

	if is_locked:
		var lock_path := "res://assets/images/misc/metal_lock_icon.png"
		var lock_tex: Texture2D = null
		if ResourceLoader.exists(lock_path):
			lock_tex = load(lock_path)
		elif FileAccess.file_exists(lock_path):
			var img := Image.load_from_file(lock_path)
			if img and not img.is_empty():
				lock_tex = ImageTexture.create_from_image(img)
		if lock_tex == null:
			var fb_path := "res://assets/images/scrapbook/metal_lock_icon.png"
			if ResourceLoader.exists(fb_path):
				lock_tex = load(fb_path)
		if lock_tex != null:
			tex_rect.texture = lock_tex
		tex_rect.modulate = Color(0.88, 0.90, 0.98, 0.88)
	else:
		var path := ""
		if game != null and game.has_method("get_weapon_icon_path"):
			path = game.get_weapon_icon_path(key, effective_lvl)
		if path == "":
			var req_lvl := clampi(effective_lvl, 1, 3)
			match key:
				"pistol", "paste":
					match req_lvl:
						2: path = "res://assets/images/candycrusadegame/paste_pistol_2_front.png"
						3: path = "res://assets/images/candycrusadegame/paste_pistol_3_front.png"
						_: path = "res://assets/images/candycrusadegame/pasteweapon.png"
				"boomerang", "brush":
					path = "res://assets/images/candycrusadegame/brushweapon.png"
				"grenade", "wash":
					path = "res://assets/images/candycrusadegame/washweapon.png"
				"lasso", "floss":
					match req_lvl:
						2: path = "res://assets/images/candycrusadegame/flossweapon.png"
						3: path = "res://assets/images/candycrusadegame/dental_floss_icon.png"
						_: path = "res://assets/images/candycrusadegame/flossweapon.png"
		if path != "":
			var tex: Texture2D = null
			var alt_path := path.replace("res://assets/candy_crusade/ui/", "res://assets/candy_crusade/ui/")
			for p in [path, alt_path]:
				if ResourceLoader.exists(p):
					tex = load(p)
					if tex != null: break
				elif FileAccess.file_exists(p):
					var img := Image.load_from_file(p)
					if img and not img.is_empty():
						tex = ImageTexture.create_from_image(img)
						if tex != null: break
			if tex != null:
				tex_rect.texture = tex
		tex_rect.modulate = Color(1.0, 1.0, 1.0, 1.0)


func _highlight_weapon(weapon_name: String) -> void:
	_current_active_weapon = weapon_name
	var bridge = get_node_or_null("/root/GameBridge")
	for key in _weapon_cards.keys():
		var col: Control = _weapon_cards[key]
		var is_locked: bool = bridge != null and bridge.is_weapon_locked(key)
		var is_active: bool = (str(key) == weapon_name) and not is_locked
		
		if _weapon_tweens.has(key) and is_instance_valid(_weapon_tweens[key]):
			_weapon_tweens[key].kill()
			
		var tw := create_tween()
		_weapon_tweens[key] = tw
		
		var tile: Control = col.get_meta("tile") if col.has_meta("tile") else null
		var highlight_panel: Control = col.get_meta("highlight_panel") if col.has_meta("highlight_panel") else null
		var tex_rect: TextureRect = col.get_meta("tex_rect") if col.has_meta("tex_rect") else null
		
		if tile != null:
			tile.pivot_offset = tile.size * 0.5
		
		if is_active:
			if highlight_panel != null:
				highlight_panel.visible = true
			if tile != null:
				tw.tween_property(tile, "scale", Vector2(1.08, 1.08), 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				tw.tween_property(tile, "scale", Vector2(1.04, 1.04), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
			if tex_rect != null:
				tex_rect.modulate = Color(1.0, 1.0, 1.0, 1.0)
		else:
			if highlight_panel != null:
				highlight_panel.visible = false
			if tile != null:
				tw.tween_property(tile, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			if tex_rect != null:
				tex_rect.modulate = Color(0.88, 0.90, 0.98, 0.88) if is_locked else Color(1.0, 1.0, 1.0, 1.0)


func bounce_card(weapon_name: String) -> void:
	var c_key := weapon_name
	if c_key == "toothpaste" or c_key == "paste": c_key = "pistol"
	elif c_key == "brush" or c_key == "battery": c_key = "boomerang"
	elif c_key == "mouthwash" or c_key == "wash": c_key = "grenade"
	elif c_key == "floss": c_key = "lasso"
	
	if not _weapon_cards.has(c_key):
		return
	var col: Control = _weapon_cards[c_key]
	var tile: Control = col.get_meta("tile") if col.has_meta("tile") else null
	if tile == null:
		return
	tile.pivot_offset = tile.size * 0.5
	
	# Kill any existing tween on this card
	if _weapon_tweens.has(c_key) and is_instance_valid(_weapon_tweens[c_key]):
		_weapon_tweens[c_key].kill()
		
	var tw := create_tween()
	_weapon_tweens[c_key] = tw
	# Juicy punch: scales up big (1.32x) with TRANS_BACK then rebounds with bounce
	tw.tween_property(tile, "scale", Vector2(1.32, 1.32), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var rest_scale := Vector2(1.04, 1.04) if (_current_active_weapon == c_key) else Vector2.ONE
	tw.tween_property(tile, "scale", rest_scale, 0.28).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	
	# Flash the golden highlight border momentarily
	var highlight_panel: Control = col.get_meta("highlight_panel") if col.has_meta("highlight_panel") else null
	if highlight_panel != null:
		highlight_panel.visible = true
		if _current_active_weapon != c_key:
			get_tree().create_timer(0.45).timeout.connect(func():
				if is_instance_valid(highlight_panel) and _current_active_weapon != c_key:
					highlight_panel.visible = false
			)


func _ensure_weapon_assets() -> void:
	var base_dir := "res://assets/candy_crusade/ui"
	var all_exist := true
	var card_names := ["paste_pistol", "brush_boomerang", "gum_grenade", "floss_lasso"]
	for c_name in card_names:
		if not FileAccess.file_exists(base_dir + "/" + c_name + ".png"):
			all_exist = false
			break
			
	if all_exist:
		return
		
	var source_path := "res://assets/candy_crusade/ui/weapon_bar_source.jpg"
	if not (ResourceLoader.exists(source_path) or FileAccess.file_exists(source_path)):
		return
		
	var src := Image.load_from_file(source_path)
	if src == null or src.is_empty():
		return
		
	src.convert(Image.FORMAT_RGBA8)
	var w := src.get_width()
	var h := src.get_height()
	
	var min_x := w
	var max_x := 0
	var min_y := h
	var max_y := 0
	
	for y in range(0, h, 2):
		for x in range(0, w, 2):
			var c := src.get_pixel(x, y)
			if c.r < 0.93 or c.g < 0.93 or c.b < 0.93:
				if x < min_x: min_x = x
				if x > max_x: max_x = x
				if y < min_y: min_y = y
				if y > max_y: max_y = y
				
	if min_x >= max_x or min_y >= max_y:
		min_x = int(w * 0.03)
		max_x = int(w * 0.97)
		min_y = int(h * 0.05)
		max_y = int(h * 0.95)
		
	var cw := max_x - min_x
	var ch := max_y - min_y
	
	_clean_outer_white(src, min_x, min_y, max_x, max_y)
	
	var full_rect := Rect2i(min_x, min_y, cw, ch)
	var full_bar := src.get_region(full_rect)
	full_bar.save_png(base_dir + "/weapon_bar_full.png")
	
	var card_defs = [
		{"name": "paste_pistol", "x0": 0.015, "x1": 0.260},
		{"name": "brush_boomerang", "x0": 0.260, "x1": 0.500},
		{"name": "gum_grenade", "x0": 0.500, "x1": 0.740},
		{"name": "floss_lasso", "x0": 0.740, "x1": 0.985}
	]
	
	for def: Dictionary in card_defs:
		var x0: float = def["x0"]
		var x1: float = def["x1"]
		var c_name: String = def["name"]
		var cx: int = min_x + int(cw * x0)
		var c_width: int = int(cw * (x1 - x0))
		var cy: int = min_y + int(ch * 0.04)
		var c_height: int = int(ch * 0.92)
		cx = clampi(cx, 0, w - 1)
		cy = clampi(cy, 0, h - 1)
		c_width = mini(c_width, w - cx)
		c_height = mini(c_height, h - cy)
		
		var card_img: Image = src.get_region(Rect2i(cx, cy, c_width, c_height))
		card_img.save_png(base_dir + "/" + c_name + ".png")


func _clean_outer_white(img: Image, min_x: int, min_y: int, max_x: int, max_y: int) -> void:
	var iw := img.get_width()
	var ih := img.get_height()
	for y in range(ih):
		for x in range(iw):
			var c := img.get_pixel(x, y)
			if c.r > 0.94 and c.g > 0.94 and c.b > 0.94:
				if x <= min_x + 8 or x >= max_x - 8 or y <= min_y + 8 or y >= max_y - 8:
					img.set_pixel(x, y, Color(1, 1, 1, 0))

func set_region_status(region_name: String, _wave: int, _total_waves: int, boss_active: bool) -> void:
	if _region_label != null:
		_region_label.text = region_name.to_upper()
	if _wave_label != null:
		if boss_active:
			_wave_label.text = "BOSS BATTLE"
			_wave_label.add_theme_color_override("font_color", Color(1.0, 0.40, 0.45))
		elif _total_waves > 1:
			_wave_label.text = "WAVE %d OF %d" % [_wave, _total_waves]
			_wave_label.add_theme_color_override("font_color", Color(0.45, 0.95, 1.0))
		else:
			_wave_label.text = "WAVE 1 OF 1"
			_wave_label.add_theme_color_override("font_color", Color(0.45, 0.95, 1.0))
	if _boss_avatar_container != null:
		_boss_avatar_container.visible = boss_active

func update_boss_health(current: int, maximum: int) -> void:
	if _boss_hp_bar:
		_boss_hp_bar.max_value = maximum
		_boss_hp_bar.value = current
		_boss_hp_label.text = "%d/%d" % [current, maximum]

func _create_modern_ui_button(btn_key: String, fallback_text: String, fallback_color: Color, btn_size: Vector2) -> Control:
	var tex = UIHelper.get_button_texture(btn_key) if UIHelper else null
	if tex != null:
		var tb = TextureButton.new()
		tb.texture_normal = tex
		tb.ignore_texture_size = true
		tb.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		tb.custom_minimum_size = btn_size
		tb.pivot_offset = btn_size * 0.5
		tb.mouse_entered.connect(func():
			var tw = tb.create_tween()
			tw.tween_property(tb, "scale", Vector2(1.06, 1.06), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		)
		tb.mouse_exited.connect(func():
			var tw = tb.create_tween()
			tw.tween_property(tb, "scale", Vector2.ONE, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		)
		return tb
	else:
		var btn = Button.new()
		btn.text = fallback_text
		btn.custom_minimum_size = btn_size
		btn.add_theme_font_size_override("font_size", 14)
		var sb = StyleBoxFlat.new()
		sb.bg_color = fallback_color
		sb.set_corner_radius_all(14)
		sb.border_color = Color(1, 1, 1, 0.6)
		sb.set_border_width_all(1)
		sb.shadow_color = Color(0, 0, 0, 0.25)
		sb.shadow_size = 4
		btn.add_theme_stylebox_override("normal", sb)
		var sb_h = sb.duplicate()
		sb_h.bg_color = fallback_color.lightened(0.15)
		btn.add_theme_stylebox_override("hover", sb_h)
		btn.pivot_offset = btn_size * 0.5
		btn.mouse_entered.connect(func():
			var tw = btn.create_tween()
			tw.tween_property(btn, "scale", Vector2(1.04, 1.04), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		)
		btn.mouse_exited.connect(func():
			var tw = btn.create_tween()
			tw.tween_property(btn, "scale", Vector2.ONE, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		)
		return btn


func _build_dev_and_clear_panels() -> void:
	# ==========================================
	# 1. PAUSE OVERLAY
	# ==========================================
	_pause_panel = ColorRect.new()
	_pause_panel.name = "PauseOverlay"
	_pause_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_panel.color = Color(0.04, 0.06, 0.14, 0.82)
	_pause_panel.process_mode = Node.PROCESS_MODE_ALWAYS

	var p_center = CenterContainer.new()
	p_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_panel.add_child(p_center)

	var p_card_w := 310.0
	var p_modal_info = UIHelper.create_modal_card(p_card_w, "portrait")
	var p_card = p_modal_info["root"]
	p_card.name = "PauseCard"
	p_card.mouse_filter = Control.MOUSE_FILTER_STOP
	p_center.add_child(p_card)

	# Top-Right Close Cross Button on card root Control (not inside a PanelContainer)
	var p_close_btn = UIHelper.create_close_button(Vector2(28, 28))
	p_close_btn.position = Vector2(p_modal_info["width"] - 38.0, 10.0)
	p_close_btn.pressed.connect(_unpause_game)
	p_card.add_child(p_close_btn)

	var p_vbox = VBoxContainer.new()
	p_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	p_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	p_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	p_vbox.add_theme_constant_override("separation", 10)
	p_modal_info["content"].add_child(p_vbox)

	var p_title = Label.new()
	p_title.text = "PAUSED"
	p_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p_title.add_theme_font_size_override("font_size", 26)
	p_title.add_theme_color_override("font_color", Color(1.0, 0.90, 0.35))
	p_title.add_theme_color_override("font_outline_color", Color(0.12, 0.06, 0.02, 0.95))
	p_title.add_theme_constant_override("outline_size", 5)
	p_vbox.add_child(p_title)

	var p_sub = Label.new()
	p_sub.text = "Candy Crusade"
	p_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p_sub.add_theme_font_size_override("font_size", 12)
	p_sub.add_theme_color_override("font_color", Color(0.70, 0.90, 1.0, 0.95))
	p_vbox.add_child(p_sub)

	# Action Buttons
	var resume_btn = _create_modern_ui_button("resume", "▶  RESUME", Color(0.18, 0.65, 0.42), Vector2(210, 44))
	resume_btn.pressed.connect(_unpause_game)
	p_vbox.add_child(resume_btn)

	var restart_btn = _create_modern_ui_button("restart", "↺  RESTART", Color(0.20, 0.52, 0.88), Vector2(210, 44))
	restart_btn.pressed.connect(_restart_level)
	p_vbox.add_child(restart_btn)

	var p_exit_btn = _create_modern_ui_button("return to map", "◀  RETURN TO MAP", Color(0.70, 0.22, 0.35), Vector2(210, 44))
	p_exit_btn.pressed.connect(_exit_to_map)
	p_vbox.add_child(p_exit_btn)

	# Collapsible Developer Cheats
	var dev_toggle_btn = Button.new()
	dev_toggle_btn.text = "Dev Cheats"
	dev_toggle_btn.flat = true
	dev_toggle_btn.add_theme_font_size_override("font_size", 11)
	dev_toggle_btn.add_theme_color_override("font_color", Color(0.65, 0.70, 0.85, 0.85))
	p_vbox.add_child(dev_toggle_btn)

	var dev_box = VBoxContainer.new()
	dev_box.visible = false
	dev_box.add_theme_constant_override("separation", 4)
	p_vbox.add_child(dev_box)

	dev_toggle_btn.pressed.connect(func():
		dev_box.visible = not dev_box.visible
	)

	var is_dev := false
	var root_gs = get_node_or_null("/root/GameState")
	var game_node = get_node_or_null("/root/Game")
	if root_gs != null and root_gs.get("dev_mode") == true:
		is_dev = true
	elif game_node != null and game_node.get("dev_mode") == true:
		is_dev = true
	dev_toggle_btn.visible = is_dev

	for index in 4:
		var btn = Button.new()
		btn.text = "Level %d (Region %d)" % [index + 1, index + 1]
		btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(_select_region.bind(index))
		dev_box.add_child(btn)

	var refill_btn := Button.new()
	refill_btn.text = "Refill Ammo (+54)"
	refill_btn.add_theme_font_size_override("font_size", 11)
	refill_btn.pressed.connect(func():
		var game = get_node_or_null("/root/Game")
		if game != null and game.has_method("refill_all_ammo"):
			game.refill_all_ammo(54)
	)
	dev_box.add_child(refill_btn)

	add_child(_pause_panel)
	_pause_panel.visible = false


	# ==========================================
	# 2. VICTORY / LEVEL CLEAR / DEFEAT OVERLAY
	# ==========================================
	_clear_panel = ColorRect.new()
	_clear_panel.name = "EndPageOverlay"
	_clear_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_clear_panel.color = Color(0.04, 0.06, 0.14, 0.86)
	_clear_panel.process_mode = Node.PROCESS_MODE_ALWAYS

	var c_center = CenterContainer.new()
	c_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clear_panel.add_child(c_center)

	var c_card_w := 330.0
	var modal_info = UIHelper.create_modal_card(c_card_w, "portrait")
	var card = modal_info["root"]
	card.name = "VictoryCard"
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	c_center.add_child(card)

	var c_vbox = VBoxContainer.new()
	c_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	c_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	c_vbox.add_theme_constant_override("separation", 10)
	modal_info["content"].add_child(c_vbox)

	# 1. 3 Large Glossy Gold Stars Rating Row
	_clear_stars_container = HBoxContainer.new()
	_clear_stars_container.name = "StarsHBox"
	_clear_stars_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_clear_stars_container.add_theme_constant_override("separation", 14)
	var star_tex = _get_ui_texture("star_candy")
	if not star_tex:
		star_tex = _get_ui_texture("star_gold")
	if not star_tex:
		star_tex = _get_ui_texture("star")
	for i in range(3):
		var s_wrapper = CenterContainer.new()
		s_wrapper.custom_minimum_size = Vector2(48, 48)
		s_wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		var s_rect = TextureRect.new()
		s_rect.name = "Star%d" % (i + 1)
		s_rect.custom_minimum_size = Vector2(44, 44)
		s_rect.size = Vector2(44, 44)
		s_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		s_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		s_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		s_rect.pivot_offset = Vector2(22, 22)
		if star_tex != null:
			s_rect.texture = star_tex
		s_wrapper.add_child(s_rect)
		_clear_stars_container.add_child(s_wrapper)
	c_vbox.add_child(_clear_stars_container)

	# 2. Title Label
	var c_title = Label.new()
	c_title.name = "Title"
	c_title.text = "VICTORY!"
	c_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c_title.add_theme_font_size_override("font_size", 26)
	c_title.add_theme_color_override("font_color", Color(1.0, 0.90, 0.35))
	c_title.add_theme_color_override("font_outline_color", Color(0.15, 0.07, 0.02, 0.95))
	c_title.add_theme_constant_override("outline_size", 5)
	c_vbox.add_child(c_title)

	# 3. White Rounded Inset Card Container
	var info_panel = PanelContainer.new()
	info_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ip_sb = StyleBoxFlat.new()
	ip_sb.bg_color = Color(1.0, 1.0, 1.0, 0.96)
	ip_sb.border_color = Color(0.85, 0.94, 1.0, 1.0)
	ip_sb.set_border_width_all(2)
	ip_sb.set_corner_radius_all(16)
	ip_sb.shadow_color = Color(0.0, 0.1, 0.3, 0.15)
	ip_sb.shadow_size = 6
	ip_sb.content_margin_left = 12
	ip_sb.content_margin_right = 12
	ip_sb.content_margin_top = 10
	ip_sb.content_margin_bottom = 10
	info_panel.add_theme_stylebox_override("panel", ip_sb)
	c_vbox.add_child(info_panel)

	var ip_vbox = VBoxContainer.new()
	ip_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	ip_vbox.add_theme_constant_override("separation", 5)
	info_panel.add_child(ip_vbox)

	var c_subtitle = Label.new()
	c_subtitle.name = "Subtitle"
	c_subtitle.text = "Region Cleared!"
	c_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c_subtitle.add_theme_font_size_override("font_size", 14)
	c_subtitle.add_theme_color_override("font_color", Color(0.12, 0.30, 0.60))
	c_subtitle.add_theme_constant_override("outline_size", 0)
	ip_vbox.add_child(c_subtitle)

	var c_boss_badge = Label.new()
	c_boss_badge.name = "BossBadge"
	c_boss_badge.text = "Blue Candor Defeated!"
	c_boss_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c_boss_badge.add_theme_font_size_override("font_size", 12)
	c_boss_badge.add_theme_color_override("font_color", Color(0.15, 0.70, 0.45))
	ip_vbox.add_child(c_boss_badge)

	# Score Pill with Coin
	var score_pill = PanelContainer.new()
	score_pill.name = "ScorePill"
	var score_sb = StyleBoxFlat.new()
	score_sb.bg_color = Color(0.92, 0.96, 1.0, 1.0)
	score_sb.border_color = Color(0.70, 0.88, 1.0, 0.9)
	score_sb.set_border_width_all(1)
	score_sb.set_corner_radius_all(12)
	score_sb.content_margin_left = 12
	score_sb.content_margin_right = 12
	score_sb.content_margin_top = 3
	score_sb.content_margin_bottom = 3
	score_pill.add_theme_stylebox_override("panel", score_sb)
	
	var score_hbox = HBoxContainer.new()
	score_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	score_hbox.add_theme_constant_override("separation", 6)
	score_pill.add_child(score_hbox)
	
	var coin_tex = _get_ui_texture("coin_candy.jpg")
	if coin_tex != null:
		var coin_rect = TextureRect.new()
		coin_rect.texture = coin_tex
		coin_rect.custom_minimum_size = Vector2(20, 20)
		coin_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		coin_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		coin_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		score_hbox.add_child(coin_rect)
		
	_clear_score_label = Label.new()
	_clear_score_label.name = "ScoreLabel"
	_clear_score_label.text = "Victory Score: 0"
	_clear_score_label.add_theme_font_size_override("font_size", 13)
	_clear_score_label.add_theme_color_override("font_color", Color(0.10, 0.35, 0.70))
	score_hbox.add_child(_clear_score_label)
	ip_vbox.add_child(score_pill)

	var c_lore = Label.new()
	c_lore.name = "Lore"
	c_lore.text = "The sugar rush has been pacified! Tooth decay repelled."
	c_lore.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c_lore.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c_lore.add_theme_font_size_override("font_size", 10)
	c_lore.add_theme_color_override("font_color", Color(0.35, 0.48, 0.65))
	ip_vbox.add_child(c_lore)

	# 4. Action Buttons Row
	var btn_hbox = HBoxContainer.new()
	btn_hbox.name = "Buttons"
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_theme_constant_override("separation", 10)
	c_vbox.add_child(btn_hbox)

	var replay_btn = _create_modern_ui_button("play again", "↺  PLAY AGAIN", Color(0.20, 0.52, 0.88), Vector2(136, 44))
	replay_btn.name = "ReplayBtn"
	replay_btn.pressed.connect(_on_replay_pressed)
	btn_hbox.add_child(replay_btn)

	var map_btn = _create_modern_ui_button("returntomap", "◀  RETURN TO MAP", Color(0.18, 0.65, 0.42), Vector2(c_card_w - 50.0, 48))
	map_btn.name = "MapBtn"
	map_btn.pressed.connect(_exit_to_map)
	btn_hbox.add_child(map_btn)

	add_child(_clear_panel)
	_clear_panel.visible = false

func show_level1_instructions_modal(on_start: Callable) -> void:
	get_tree().paused = true
	var dlg = UIHelper.create_modal_dialog(self, 300, Color(0.04, 0.08, 0.20, 0.85))
	var overlay = dlg["overlay"]
	var center = dlg["center"]
	
	var card_w := 320.0
	var modal_info = UIHelper.create_modal_card(card_w, "portrait")
	var card = modal_info["root"]
	center.add_child(card)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 10)
	modal_info["content"].add_child(vbox)
	
	var title = Label.new()
	title.text = "LEVEL 1: CANDY CAVE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(title, 18, Color(0.18, 0.44, 0.78), true)
	vbox.add_child(title)
	
	var sub = Label.new()
	sub.text = "HOW TO PLAY"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(sub, 12, Color(0.35, 0.50, 0.70), true)
	vbox.add_child(sub)
	
	var instructions = [
		"1. Tap or Drag to aim your Toothpaste Pistol.",
		"2. Blast incoming candy minions before they reach your tooth!",
		"3. Switch weapons at the bottom to use Boomerangs, Washes & Floss.",
		"4. Defeat Blue Candor's army to protect Mulinia!"
	]
	for inst in instructions:
		var lbl = Label.new()
		lbl.text = inst
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		UIHelper.apply_bubbly_label(lbl, 11, Color(0.20, 0.32, 0.50), false)
		vbox.add_child(lbl)
		
	var start_btn = UIHelper.create_bubbly_button("START BATTLE", UIHelper.VIBRANT_GREEN)
	start_btn.custom_minimum_size = Vector2(220, 44)
	start_btn.pressed.connect(func():
		overlay.queue_free()
		get_tree().paused = false
		if on_start.is_valid():
			on_start.call()
	)
	vbox.add_child(start_btn)

func _toggle_pause_menu() -> void:
	if _pause_panel == null:
		return
	_pause_panel.visible = not _pause_panel.visible
	get_tree().paused = _pause_panel.visible

func _toggle_dev_menu() -> void:
	_toggle_pause_menu()

func _unpause_game() -> void:
	if _pause_panel != null:
		_pause_panel.visible = false
	get_tree().paused = false

func _restart_level() -> void:
	_unpause_game()
	_on_replay_pressed()

func _exit_to_map() -> void:
	if _pause_panel != null:
		_pause_panel.visible = false
	if _clear_panel != null:
		_clear_panel.visible = false
	get_tree().paused = false
	var bridge = get_node_or_null("/root/GameBridge")
	if bridge != null:
		bridge.send_exit_game()
	else:
		get_tree().change_scene_to_file("res://scenes/main.tscn")

func _select_region(index: int) -> void:
	_unpause_game()
	var controller = get_tree().get_first_node_in_group("region_controller")
	if controller != null:
		controller.call("select_region", index)

func show_defeat_screen() -> void:
	if _clear_panel:
		if _clear_stars_container:
			_clear_stars_container.visible = false
		var title := _clear_panel.find_child("Title", true, false) as Label
		if title:
			title.visible = true
			title.text = "TRY AGAIN!"
			title.add_theme_color_override("font_color", Color(1.0, 0.40, 0.45))
		var subtitle := _clear_panel.find_child("Subtitle", true, false) as Label
		if subtitle:
			subtitle.text = "Sugar Rush Overwhelmed You!"
		var boss_badge := _clear_panel.find_child("BossBadge", true, false) as Label
		if boss_badge:
			boss_badge.visible = false
		var lore := _clear_panel.find_child("Lore", true, false) as Label
		if lore:
			lore.text = "Brush off the plaque and give it another shot!"
		var score := 0
		if _spawner and "_score" in _spawner:
			score = int(_spawner.get("_score"))
		if _clear_score_label:
			_clear_score_label.text = "Final Score: %d" % score
		
		# On Defeat: Show BOTH Play Again and Return to Map buttons
		var replay_btn = _clear_panel.find_child("ReplayBtn", true, false)
		if replay_btn:
			replay_btn.visible = true
			replay_btn.custom_minimum_size = Vector2(136, 44)
		var map_btn = _clear_panel.find_child("MapBtn", true, false)
		if map_btn:
			map_btn.visible = true
			map_btn.custom_minimum_size = Vector2(136, 44)
			
		_clear_panel.visible = true
		get_tree().paused = true


func show_region_cleared(region_name: String) -> void:
	var score := 0
	if _spawner and "_score" in _spawner:
		score = int(_spawner.get("_score"))
	var reg := 0
	var controller = get_tree().get_first_node_in_group("region_controller")
	if controller and controller.has_method("get_current_region_index"):
		reg = controller.get_current_region_index()
		
	var bridge = get_node_or_null("/root/GameBridge")
	if bridge != null:
		var dur: float = (Time.get_ticks_msec() / 1000.0) - float(bridge.get("run_start_time"))
		var minions: int = int(bridge.get("minions_defeated"))
		var coins: int = int(bridge.get("coins_collected"))
		var is_boss: bool = bool(bridge.get("is_boss"))
		var no_dmg: bool = not bool(bridge.get("player_damaged"))
		var objectives := [
			{ "id": "no_damage", "label": "Flawless Smile", "completed": no_dmg },
			{ "id": "all_plaque_cleared", "label": "Every Cavity Cleared", "completed": true }
		]
		bridge.send_game_over("VICTORY", score, coins, minions, is_boss, bridge.get("ammo"), objectives, dur)
	else:
		var game = get_node_or_null("/root/Game")
		if game != null and game.has_method("send_completion_to_lovable"):
			game.send_completion_to_lovable("victory", score, reg)

	if _clear_panel:
		if _clear_stars_container:
			_clear_stars_container.visible = true
			for i in range(_clear_stars_container.get_child_count()):
				var wrapper = _clear_stars_container.get_child(i)
				var star_node = wrapper.get_child(0) if wrapper.get_child_count() > 0 else wrapper
				if star_node is Control:
					star_node.scale = Vector2.ZERO
					var s_tw = create_tween()
					s_tw.tween_interval(0.2 + (i * 0.15))
					s_tw.tween_property(star_node, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				
		var title := _clear_panel.find_child("Title", true, false) as Label
		if title:
			title.visible = true
			title.text = "VICTORY!"
			title.add_theme_color_override("font_color", Color(1.0, 0.90, 0.35))
			
		var subtitle := _clear_panel.find_child("Subtitle", true, false) as Label
		if subtitle:
			subtitle.text = "%s Cleared!" % region_name
			
		var boss_badge := _clear_panel.find_child("BossBadge", true, false) as Label
		if boss_badge:
			boss_badge.visible = true
			
		var lore := _clear_panel.find_child("Lore", true, false) as Label
		if lore:
			lore.text = "The sugar rush has been pacified! Tooth decay repelled."
			
		if _clear_score_label:
			_clear_score_label.text = "Victory Score: %d" % score
			
		# On Victory: ONLY show Return to Map button (NO Play Again)
		var replay_btn = _clear_panel.find_child("ReplayBtn", true, false)
		if replay_btn:
			replay_btn.visible = false
			
		var map_btn = _clear_panel.find_child("MapBtn", true, false)
		if map_btn:
			map_btn.visible = true
			map_btn.custom_minimum_size = Vector2(260, 50)

		_clear_panel.visible = true
		get_tree().paused = true

func hide_region_cleared() -> void:
	if _clear_panel:
		_clear_panel.visible = false
	get_tree().paused = false

func _on_replay_pressed() -> void:
	hide_region_cleared()
	var controller = get_tree().get_first_node_in_group("region_controller")
	if controller != null:
		if controller.has_method("restart_region"):
			controller.restart_region()
		else:
			controller.call("select_region", 0)

func _on_next_level_pressed() -> void:
	_exit_to_map()

func _continue_after_clear() -> void:
	_exit_to_map()
