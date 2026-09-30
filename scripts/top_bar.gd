# scripts/top_bar.gd
extends Control

signal avatar_pressed
signal settings_pressed
signal back_pressed

var avatar_btn: Control
var avatar_icon: TextureRect
var avatar_name_lbl: Label

var back_btn: TextureButton
var settings_btn: TextureButton

var coins_label: Label
var points_label: Label
var streak_label: Label

var stats_banner: Control
var banner_tex: TextureRect
var current_screen: String = "map"

func _ready():
	set_anchors_preset(Control.PRESET_TOP_WIDE)
	anchor_left = 0.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 0.0
	offset_left = 0
	offset_right = 0
	offset_top = 0
	offset_bottom = 80
	custom_minimum_size = Vector2(450, 80)
	size.y = 80
	z_index = 100
	z_as_relative = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	GameState.stats_updated.connect(_on_stats_updated)
	GameState.profile_changed.connect(_on_profile_changed)
	_refresh()

func _build_ui():
	var safe_sz = UIHelper.get_viewport_safe_size(self)
	var cur_w = safe_sz.x
	size.x = cur_w
	
	# Center Stats Banner
	stats_banner = Control.new()
	stats_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stats_banner)
	
	banner_tex = TextureRect.new()
	banner_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	banner_tex.stretch_mode = TextureRect.STRETCH_SCALE
	banner_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_tex.texture = UIHelper.load_texture_safe("res://assets/images/mainmap/topuimap_item_1.png")
	stats_banner.add_child(banner_tex)
	
	# Coins Label (left cutout trough)
	coins_label = Label.new()
	coins_label.text = "0"
	coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coins_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	coins_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats_banner.add_child(coins_label)
	
	# Points Label (center cutout trough)
	points_label = Label.new()
	points_label.text = "0"
	points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	points_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	points_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats_banner.add_child(points_label)
	
	# Streak Label (right cutout trough)
	streak_label = Label.new()
	streak_label.text = "0"
	streak_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	streak_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	streak_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats_banner.add_child(streak_label)
	
	# Left: Avatar Card + Name Pill (direct Button for 100% reliable click reception)
	avatar_btn = Button.new()
	avatar_btn.flat = true
	avatar_btn.custom_minimum_size = Vector2(72, 70)
	avatar_btn.size = Vector2(72, 70)
	avatar_btn.position = Vector2(12, 6)
	avatar_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	avatar_btn.focus_mode = Control.FOCUS_NONE
	avatar_btn.z_index = 5
	avatar_btn.pressed.connect(func():
		AudioManager.play_sfx("click")
		avatar_pressed.emit()
	)
	add_child(avatar_btn)
	
	var circle = Panel.new()
	circle.size = Vector2(50, 50)
	circle.position = Vector2(11, 0)
	circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var c_style = StyleBoxFlat.new()
	c_style.bg_color = Color(0.55, 0.82, 1.0)
	c_style.set_corner_radius_all(25)
	c_style.border_color = Color.WHITE
	c_style.border_width_left = 2
	c_style.border_width_top = 2
	c_style.border_width_right = 2
	c_style.border_width_bottom = 2
	circle.add_theme_stylebox_override("panel", c_style)
	avatar_btn.add_child(circle)
	
	avatar_icon = TextureRect.new()
	avatar_icon.size = Vector2(42, 42)
	avatar_icon.position = Vector2(4, 4)
	avatar_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	avatar_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	circle.add_child(avatar_icon)
	
	var name_pill = Panel.new()
	name_pill.size = Vector2(72, 20)
	name_pill.position = Vector2(0, 44)
	name_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pill_style = StyleBoxFlat.new()
	pill_style.bg_color = Color(0.20, 0.48, 0.78)
	pill_style.set_corner_radius_all(10)
	pill_style.border_color = Color.WHITE
	pill_style.border_width_left = 1.5
	pill_style.border_width_top = 1.5
	pill_style.border_width_right = 1.5
	pill_style.border_width_bottom = 1.5
	name_pill.add_theme_stylebox_override("panel", pill_style)
	avatar_btn.add_child(name_pill)
	
	avatar_name_lbl = Label.new()
	avatar_name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_pill.add_child(avatar_name_lbl)
	avatar_name_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	avatar_name_lbl.offset_left = 2
	avatar_name_lbl.offset_top = 0
	avatar_name_lbl.offset_right = -2
	avatar_name_lbl.offset_bottom = 0
	avatar_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	avatar_name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	avatar_name_lbl.clip_text = false
	avatar_name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	UIHelper.apply_bubbly_label(avatar_name_lbl, 11, Color.WHITE, true)
	avatar_name_lbl.add_theme_color_override("font_color", Color.WHITE)
	avatar_name_lbl.add_theme_color_override("font_shadow_color", Color(0.04, 0.12, 0.28, 0.85))
	avatar_name_lbl.add_theme_constant_override("shadow_offset_x", 0)
	avatar_name_lbl.add_theme_constant_override("shadow_offset_y", 1)
	
	# Left: Back Button (shown on subpages)
	back_btn = UIHelper.create_image_button("res://assets/images/shop/blue_back_button.png", Vector2(46, 46))
	back_btn.position = Vector2(16, 16)
	back_btn.size = Vector2(46, 46)
	back_btn.z_index = 5
	back_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	back_btn.focus_mode = Control.FOCUS_NONE
	back_btn.visible = false
	back_btn.pressed.connect(func(): back_pressed.emit())
	add_child(back_btn)
	
	# Right: Settings Button
	settings_btn = UIHelper.create_image_button("res://assets/images/settings/settings_icon.png", Vector2(44, 44))
	settings_btn.position = Vector2(cur_w - 56, 14)
	settings_btn.size = Vector2(44, 44)
	settings_btn.z_index = 5
	settings_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	settings_btn.focus_mode = Control.FOCUS_NONE
	settings_btn.pressed.connect(func(): settings_pressed.emit())
	add_child(settings_btn)
	
	_relayout()

func _notification(what: int):
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_relayout()

func _relayout():
	var safe_sz = UIHelper.get_viewport_safe_size(self)
	var cur_w = safe_sz.x
	size.x = cur_w
	
	# Responsive banner dimensions:
	# Native aspect ratio of topuimap_item_1.png is ~4.89 (1042 x 213)
	var banner_w = clamp(cur_w * 0.58, 288.0, 360.0)
	var banner_h = banner_w / 4.89
	
	var bar_h = max(80.0, banner_h + 16.0)
	size.y = bar_h
	custom_minimum_size.y = bar_h
	offset_bottom = bar_h
	
	# Left element: Avatar on map, or Back button on subpages
	if avatar_btn:
		avatar_btn.position = Vector2(8.0, (bar_h - avatar_btn.size.y) * 0.5)
	if back_btn:
		back_btn.position = Vector2(14.0, (bar_h - back_btn.size.y) * 0.5)
		
	# Right element: Settings gear button
	if settings_btn:
		settings_btn.position = Vector2(cur_w - 52.0, (bar_h - settings_btn.size.y) * 0.5)
		
	# Center the banner between left elements and right elements
	var left_limit = 8.0 + 72.0 + 8.0
	var right_limit = (cur_w - 52.0) - 8.0
	var mid_x = (left_limit + right_limit) * 0.5
	var banner_x = mid_x - (banner_w * 0.5)
	var banner_y = (bar_h - banner_h) * 0.5
	
	if stats_banner:
		stats_banner.size = Vector2(banner_w, banner_h)
		stats_banner.custom_minimum_size = Vector2(banner_w, banner_h)
		stats_banner.position = Vector2(banner_x, banner_y)
		
	if banner_tex:
		banner_tex.size = Vector2(banner_w, banner_h)
		banner_tex.custom_minimum_size = Vector2(banner_w, banner_h)
		banner_tex.position = Vector2.ZERO
		
	# Slot placement according to topuimap_item_1.png design:
	# Vertically, the dark blue recessed troughs span from 15% to 57% of banner height (midpoint: 36%)
	# Baked "Coins", "Points", "Streak" text is in the lower shelf from 62% to 88%
	var trough_y = banner_h * 0.15
	var trough_h = banner_h * 0.42
	var num_font_sz = int(round(banner_h * 0.28))
	
	if coins_label:
		# Slot 1: Starts after the gold coin (14.5%) to star edge (36.0%), centered over "Coins"
		coins_label.position = Vector2(banner_w * 0.145, trough_y)
		coins_label.size = Vector2(banner_w * 0.215, trough_h)
		_style_stat_label(coins_label, num_font_sz)
		
	if points_label:
		# Slot 2: Centered directly over the "Points" text (46.5% to 65.0%) + 5px right offset
		points_label.position = Vector2(banner_w * 0.465 + 10.0, trough_y)
		points_label.size = Vector2(banner_w * 0.185, trough_h)
		_style_stat_label(points_label, num_font_sz)
		
	if streak_label:
		# Slot 3: Centered directly over the "Streak" text (77.5% to 94.5%) + 5px right offset
		streak_label.position = Vector2(banner_w * 0.775 + 5.0, trough_y)
		streak_label.size = Vector2(banner_w * 0.170, trough_h)
		_style_stat_label(streak_label, num_font_sz)

func _style_stat_label(lbl: Label, font_size: int):
	UIHelper.apply_bubbly_label(lbl, font_size, Color.WHITE, true)
	lbl.add_theme_color_override("font_outline_color", Color(0.08, 0.22, 0.45, 0.95))
	lbl.add_theme_constant_override("outline_size", 2)
	lbl.add_theme_color_override("font_shadow_color", Color(0.04, 0.12, 0.25, 0.6))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 2)

func set_screen(screen_name: String):
	current_screen = screen_name
	var is_map = (current_screen == "map")
	avatar_btn.visible = is_map
	back_btn.visible = not is_map
	stats_banner.visible = true
	_refresh()

func _refresh():
	var p = GameState.get_active_profile()
	if p.is_empty():
		var all_p = GameState.get_profiles()
		if all_p.size() > 0:
			p = all_p[0]
	if p.is_empty(): return
	
	var char_id = p.get("avatar", "chip")
	if avatar_icon:
		avatar_icon.texture = UIHelper.get_char_texture(char_id)
	
	var raw_name = str(p.get("name", "Player")).strip_edges()
	if raw_name == "":
		raw_name = "Player"
	
	if avatar_name_lbl:
		avatar_name_lbl.text = raw_name.to_upper()
		var n_len = raw_name.length()
		var f_sz = 11
		if n_len > 9:
			f_sz = 8
		elif n_len > 6:
			f_sz = 9
		UIHelper.apply_bubbly_label(avatar_name_lbl, f_sz, Color.WHITE, true)
		avatar_name_lbl.add_theme_color_override("font_color", Color.WHITE)
		avatar_name_lbl.add_theme_color_override("font_shadow_color", Color(0.04, 0.12, 0.28, 0.85))
		avatar_name_lbl.add_theme_constant_override("shadow_offset_x", 0)
		avatar_name_lbl.add_theme_constant_override("shadow_offset_y", 1)
	
	if coins_label:
		coins_label.text = str(int(round(float(p.get("coins", 0)))))
	if points_label:
		points_label.text = str(int(round(float(p.get("points", 0)))))
	if streak_label:
		streak_label.text = str(int(round(float(p.get("streak", 0)))))

func _on_stats_updated(_p):
	_refresh()

func _on_profile_changed(_p):
	_refresh()
