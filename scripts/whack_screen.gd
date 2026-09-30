# scripts/whack_screen.gd
extends Control

signal game_ended
signal game_won

# Custom Control that draws an authentic 3D elliptical burrow hole
class HoleGraphic extends Control:
	func _draw():
		var w = size.x
		var h = size.y
		if w <= 0.0 or h <= 0.0: return
		var cx = w * 0.5
		var cy = h * 0.52
		
		# 1. Soft ground shadow under and around the dirt mound
		draw_set_transform(Vector2(cx, cy + h * 0.12), 0.0, Vector2((w * 0.52) / 100.0, (h * 0.44) / 100.0))
		draw_circle(Vector2.ZERO, 100.0, Color(0.06, 0.16, 0.04, 0.40))
		
		# 2. Outer dirt mound (warm earthy caramel brown)
		draw_set_transform(Vector2(cx, cy + h * 0.04), 0.0, Vector2((w * 0.49) / 100.0, (h * 0.40) / 100.0))
		draw_circle(Vector2.ZERO, 100.0, Color(0.56, 0.36, 0.18))
		
		# 3. Outer dirt mound shading (darker lower bevel ring)
		draw_set_transform(Vector2(cx, cy + h * 0.06), 0.0, Vector2((w * 0.46) / 100.0, (h * 0.36) / 100.0))
		draw_circle(Vector2.ZERO, 100.0, Color(0.44, 0.26, 0.12))
		
		# 4. Front lip highlight on dirt rim (gives depth)
		draw_set_transform(Vector2(cx, cy + h * 0.10), 0.0, Vector2((w * 0.43) / 100.0, (h * 0.14) / 100.0))
		draw_circle(Vector2.ZERO, 100.0, Color(0.70, 0.48, 0.26, 0.55))
		
		# 5. Inner hole cavity (deep dark burrow)
		draw_set_transform(Vector2(cx, cy - h * 0.02), 0.0, Vector2((w * 0.36) / 100.0, (h * 0.27) / 100.0))
		draw_circle(Vector2.ZERO, 100.0, Color(0.12, 0.06, 0.02))
		
		# 6. Top cavity shadow (deep shadow cast from top rim into hole)
		draw_set_transform(Vector2(cx, cy - h * 0.08), 0.0, Vector2((w * 0.33) / 100.0, (h * 0.16) / 100.0))
		draw_circle(Vector2.ZERO, 100.0, Color(0.04, 0.02, 0.01, 0.95))
		
		# Reset transform
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

var score: int = 0
var misses: int = 0
var time_left: int = 30
var is_playing: bool = false
var is_paused: bool = false
var spawn_speed: float = 0.85

var consecutive_whacks: int = 0
var max_combo: int = 0
var combo_points: int = 0
var combo_coins: int = 0

var timer_node: Timer
var spawn_timer: Timer

var whacked_label: Label
var time_label: Label
var misses_label: Label
var points_val_label: Label
var coins_val_label: Label
var best_label: Label
var combo_banner: PanelContainer
var combo_label: Label

var holes_container: Control
var hole_controls: Array[Control] = []
var minion_buttons: Array[TextureButton] = []
var hole_states: Array[String] = [] # "idle", "up", "hit", "retract"
var hole_tweens: Array[Tween] = []
var last_spawned_hole: int = -1

var bg_rect: TextureRect
var difficulty_modal: Control
var pause_modal: Control
var over_modal: Control
var pause_btn: TextureButton
var title_img: TextureRect
var title_lbl: Label
var best_pill: PanelContainer
var stats_hbox: HBoxContainer
var reward_layer: Control

func _ready():
	set_anchors_preset(Control.PRESET_FULL_RECT)
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_right = 0
	offset_bottom = 0
	_build_ui()
	_relayout()
	var diff = GameState.get_difficulty()
	var spd = 1.05 if diff == "easy" else (0.80 if diff == "medium" else 0.55)
	_start_with_speed(spd)

func _notification(what: int):
	if what == NOTIFICATION_RESIZED:
		if is_node_ready():
			_relayout()

func _build_ui():
	# 1. Background: Authentic Bonbon Bash candy meadow
	bg_rect = TextureRect.new()
	UIHelper.setup_fullscreen_bg(bg_rect)
	bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg_tex = UIHelper.load_texture_safe("res://assets/images/bonbonbashmini/whack_bg.jpg")
	if not bg_tex:
		bg_tex = UIHelper.load_texture_safe("res://assets/images/misc/whack_bg.jpg")
	if not bg_tex:
		bg_tex = UIHelper.load_texture_safe("res://old lovable/src/assets/whack_bg.jpg")
	if not bg_tex:
		bg_tex = UIHelper.load_texture_safe("res://assets/images/candycrusadegame/boss_fight_mini_game_BG_candy.jpg")
	bg_rect.texture = bg_tex
	add_child(bg_rect)
	
	# 2. Top Right Circular Pause Button
	pause_btn = UIHelper.create_circular_pause_button(Vector2(46, 46))
	pause_btn.z_index = 30
	pause_btn.pressed.connect(_on_pause_pressed)
	add_child(pause_btn)
	
	# 3. Title: 3D "BONBON BASH" Title Image with fallback
	var title_tex = UIHelper.load_texture_safe("res://assets/images/titles/bonbonbash_title.png")
	if not title_tex:
		title_tex = UIHelper.load_texture_safe("res://assets/images/titles/bonbonbash_title.png")
	if title_tex:
		title_img = TextureRect.new()
		title_img.texture = title_tex
		title_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		title_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		title_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(title_img)
	else:
		title_lbl = Label.new()
		title_lbl.text = "BONBON BASH"
		title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UIHelper.apply_bubbly_label(title_lbl, 25, Color.WHITE, true)
		add_child(title_lbl)
	
	# 5. Best pill (hidden to remove numbers at top per user request)
	best_pill = PanelContainer.new()
	best_pill.visible = false
	best_label = Label.new()
	best_pill.add_child(best_label)
	add_child(best_pill)
	
	# 6. Stats Pills: POINTS (live count), TIME (countdown), COINS (live count)
	stats_hbox = HBoxContainer.new()
	stats_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	stats_hbox.add_theme_constant_override("separation", 12)
	add_child(stats_hbox)
	
	whacked_label = Label.new()
	misses_label = Label.new()
	points_val_label = Label.new()
	coins_val_label = Label.new()
	
	var pts_pill = _create_icon_badge("POINTS", "res://assets/images/shop/purple_star_points.png", points_val_label)
	stats_hbox.add_child(pts_pill)
	
	time_label = Label.new()
	var time_pill = _create_time_pill(time_label)
	stats_hbox.add_child(time_pill)
	
	var coins_pill = _create_icon_badge("COINS", "res://assets/images/shop/gold_tooth_coin.png", coins_val_label)
	stats_hbox.add_child(coins_pill)
	
	# 7. Combo Banner
	combo_banner = PanelContainer.new()
	combo_banner.size = Vector2(240, 36)
	var cb_st = UIHelper.create_bubbly_panel(18, Color(1, 0.92, 0.3), Color(1, 0.6, 0.1), 2)
	combo_banner.add_theme_stylebox_override("panel", cb_st)
	combo_banner.modulate = Color(1, 1, 1, 0)
	combo_banner.pivot_offset = Vector2(120, 18)
	
	combo_label = Label.new()
	combo_label.text = "COMBO x2!"
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combo_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(combo_label, 13, Color(0.85, 0.25, 0.0), true)
	combo_banner.add_child(combo_label)
	add_child(combo_banner)
	
	# 8. 3x3 Holes Board in Open Meadow Area
	holes_container = Control.new()
	add_child(holes_container)
	
	hole_controls.clear()
	minion_buttons.clear()
	hole_states.clear()
	hole_tweens.clear()
	
	for i in range(9):
		hole_states.append("idle")
		hole_tweens.append(null)
		
		var hole_box = Control.new()
		hole_box.custom_minimum_size = Vector2(180, 104)
		hole_box.size = Vector2(180, 104)
		
		# A. Authentic 3D Hole Graphic (bonbonbash_hole.png)
		var hole_tex = UIHelper.load_texture_safe("res://assets/images/bonbonbashmini/bonbonbash_hole.png")
		if hole_tex:
			var h_img = TextureRect.new()
			h_img.texture = hole_tex
			h_img.set_anchors_preset(Control.PRESET_FULL_RECT)
			h_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			h_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			h_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hole_box.add_child(h_img)
		else:
			var h_graphic = HoleGraphic.new()
			h_graphic.set_anchors_preset(Control.PRESET_FULL_RECT)
			h_graphic.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hole_box.add_child(h_graphic)
		
		# B. Minion Button (pops up out of cavity)
		var m_btn = TextureButton.new()
		m_btn.size = Vector2(160, 115)
		m_btn.position = Vector2(10.0, -45.0)
		m_btn.pivot_offset = Vector2(80.0, 115.0) # Pivot at feet
		m_btn.ignore_texture_size = true
		m_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		m_btn.visible = false
		m_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		m_btn.focus_mode = Control.FOCUS_NONE
		
		var h_idx = i
		m_btn.pressed.connect(func(): _on_hole_clicked(h_idx))
		hole_box.add_child(m_btn)
		minion_buttons.append(m_btn)
		
		# C. Transparent Hit Zone covering the hole and pop-up area
		var hit_zone = Button.new()
		hit_zone.name = "HitZone"
		hit_zone.flat = true
		hit_zone.position = Vector2(-15.0, -60.0)
		hit_zone.size = Vector2(210.0, 170.0)
		hit_zone.focus_mode = Control.FOCUS_NONE
		hit_zone.mouse_filter = Control.MOUSE_FILTER_PASS
		hit_zone.pressed.connect(func(): _on_hole_clicked(h_idx))
		hole_box.add_child(hit_zone)
		
		hole_controls.append(hole_box)
		holes_container.add_child(hole_box)
		
	# 9. Reward Effects Layer (Bursting coins & points)
	reward_layer = Control.new()
	reward_layer.name = "RewardLayer"
	reward_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	reward_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reward_layer.z_index = 50
	add_child(reward_layer)
	
	# 10. Game Timers
	timer_node = Timer.new()
	timer_node.wait_time = 1.0
	timer_node.timeout.connect(_on_tick)
	add_child(timer_node)
	
	spawn_timer = Timer.new()
	spawn_timer.timeout.connect(_on_spawn_tick)
	add_child(spawn_timer)

func _relayout():
	var safe_sz = UIHelper.get_viewport_safe_size(self)
	var cur_w = safe_sz.x
	var cur_h = safe_sz.y
	
	if bg_rect and is_instance_valid(bg_rect):
		bg_rect.size = safe_sz
		bg_rect.position = Vector2.ZERO
	
	if reward_layer:
		reward_layer.size = safe_sz
		reward_layer.position = Vector2.ZERO
	
	if pause_btn:
		pause_btn.position = Vector2(cur_w - 56, 14)
	if title_img and is_instance_valid(title_img):
		var t_w = min(cur_w - 80.0, 360.0)
		var t_h = 72.0
		title_img.position = Vector2((cur_w - t_w) * 0.5, 4)
		title_img.size = Vector2(t_w, t_h)
	elif title_lbl and is_instance_valid(title_lbl):
		var title_w = min(cur_w - 80.0, 370.0)
		title_lbl.position = Vector2((cur_w - title_w) * 0.5, 8)
		title_lbl.size = Vector2(title_w, 48)
		title_lbl.add_theme_font_size_override("font_size", 34)
	if best_pill:
		best_pill.visible = false
	if stats_hbox:
		var stat_w = min(cur_w - 24.0, 390.0)
		stats_hbox.position = Vector2((cur_w - stat_w) * 0.5, 78)
		stats_hbox.size = Vector2(stat_w, 52)
	if combo_banner:
		combo_banner.position = Vector2((cur_w - 240.0) * 0.5, 134)
		
	if holes_container:
		var top_bound = 165.0 + UIHelper.safe_top  # Account for notch/safe area on iPhone
		var bottom_bound = cur_h - 75.0 - UIHelper.safe_bottom # Above foreground candy decorations
		var board_h = max(420.0, bottom_bound - top_bound)
		var board_w = min(cur_w - 24.0, 680.0)

		holes_container.position = Vector2((cur_w - board_w) * 0.5, top_bound)
		holes_container.size = Vector2(board_w, board_h)
		
		var col_spacing = board_w / 3.0
		var row_spacing = board_h / 3.0
		var hole_w = min(210.0, col_spacing * 0.94)
		var hole_h = round(hole_w * 0.58) # Proportional 3D hole height
		
		for r in range(3):
			for c in range(3):
				var idx = r * 3 + c
				if idx < hole_controls.size():
					var hc = hole_controls[idx]
					var hx = c * col_spacing + (col_spacing - hole_w) * 0.5
					var hy = r * row_spacing + (row_spacing - hole_h) * 0.5
					hc.position = Vector2(hx, hy)
					hc.size = Vector2(hole_w, hole_h)
					
					# Reposition minion inside hole
					var m_btn = minion_buttons[idx]
					var m_w = hole_w * 0.88
					var m_h = m_w * 0.72
					m_btn.size = Vector2(m_w, m_h)
					m_btn.position = Vector2((hole_w - m_w) * 0.5, (hole_h * 0.38) - m_h * 0.75)
					m_btn.pivot_offset = Vector2(m_w * 0.5, m_h)
					
					var hit_z = hc.get_node_or_null("HitZone") as Button
					if hit_z:
						hit_z.position = Vector2(-hole_w * 0.08, -m_h * 0.85)
						hit_z.size = Vector2(hole_w * 1.16, hole_h + m_h * 0.85)
					
					for ch in hc.get_children():
						if ch is HoleGraphic:
							ch.queue_redraw()

func _create_icon_badge(title: String, icon_path: String, val_lbl: Label) -> Control:
	var pill = PanelContainer.new()
	pill.custom_minimum_size = Vector2(104, 48)
	var p_style = UIHelper.create_bubbly_panel(22, Color(0.24, 0.48, 0.78, 0.95), Color.WHITE, 1)
	pill.add_theme_stylebox_override("panel", p_style)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 0)
	
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 4)
	
	var ic = TextureRect.new()
	ic.texture = UIHelper.load_texture_safe(icon_path)
	ic.custom_minimum_size = Vector2(14, 14)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hbox.add_child(ic)
	
	var t_lbl = Label.new()
	t_lbl.text = title
	t_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(t_lbl, 9, Color(1, 1, 1, 0.8), true)
	hbox.add_child(t_lbl)
	vbox.add_child(hbox)
	
	val_lbl.text = "0"
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(val_lbl, 16, Color.WHITE, true)
	vbox.add_child(val_lbl)
	
	pill.add_child(vbox)
	return pill

func _create_time_pill(val_lbl: Label) -> Control:
	var pill = PanelContainer.new()
	pill.custom_minimum_size = Vector2(104, 48)
	var p_style = UIHelper.create_bubbly_panel(22, Color(0.24, 0.48, 0.78, 0.95), Color.WHITE, 1)
	pill.add_theme_stylebox_override("panel", p_style)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 0)
	
	var t_lbl = Label.new()
	t_lbl.text = "TIME"
	t_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(t_lbl, 9, Color(1, 1, 1, 0.8), true)
	vbox.add_child(t_lbl)
	
	val_lbl.text = "30s"
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(val_lbl, 16, Color.WHITE, true)
	vbox.add_child(val_lbl)
	
	pill.add_child(vbox)
	return pill

func _create_stat_pill(title: String, initial_val: String, val_lbl: Label) -> Control:
	var pill = PanelContainer.new()
	pill.custom_minimum_size = Vector2(104, 48)
	var p_style = UIHelper.create_bubbly_panel(22, Color(0.24, 0.48, 0.78, 0.95), Color.WHITE, 1)
	pill.add_theme_stylebox_override("panel", p_style)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 0)
	
	var t_lbl = Label.new()
	t_lbl.text = title
	t_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(t_lbl, 9, Color(1, 1, 1, 0.8), true)
	vbox.add_child(t_lbl)
	
	val_lbl.text = initial_val
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(val_lbl, 16, Color.WHITE, true)
	vbox.add_child(val_lbl)
	
	pill.add_child(vbox)
	return pill

# ==========================================================
# MODALS (Always perfectly centered using UIHelper.create_modal_dialog)
# ==========================================================
func _show_difficulty_modal():
	if difficulty_modal and is_instance_valid(difficulty_modal):
		difficulty_modal.queue_free()
		
	var safe_sz = UIHelper.get_viewport_safe_size(self)
	var cur_w = safe_sz.x
	var cur_h = safe_sz.y
	
	var dlg = UIHelper.create_modal_dialog(self, 100)
	difficulty_modal = dlg["overlay"]
	var center = dlg["center"]
	
	# Strict aspect ratio preserved card frame
	var max_card_w = min(cur_w - 40.0, (cur_h - 40.0) / 1.50)
	var card_w = clamp(max_card_w, 260.0, 330.0)
	var modal_info = UIHelper.create_modal_card(card_w, "portrait")
	var card = modal_info["root"]
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(card)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 10)
	modal_info["content"].add_child(vbox)
	
	var heading_box = VBoxContainer.new()
	heading_box.add_theme_constant_override("separation", 2)
	var t_lbl = Label.new()
	t_lbl.text = "BONBON BASH"
	t_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(t_lbl, 22, Color.WHITE, true)
	t_lbl.add_theme_color_override("font_shadow_color", Color(0.12, 0.40, 0.70))
	t_lbl.add_theme_constant_override("shadow_offset_x", 2)
	t_lbl.add_theme_constant_override("shadow_offset_y", 2)
	heading_box.add_child(t_lbl)
	
	var s_lbl = Label.new()
	s_lbl.text = "CHOOSE A DIFFICULTY"
	s_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(s_lbl, 11, Color(0.9, 0.96, 1.0), true)
	heading_box.add_child(s_lbl)
	vbox.add_child(heading_box)
	
	# 1. Easy Button
	var easy_btn = _create_difficulty_button("EASY", "GENTLE AND SLOW", Color(0.18, 0.76, 0.40), func():
		_start_with_speed(1.05)
	)
	vbox.add_child(easy_btn)
	
	# 2. Medium Button
	var med_btn = _create_difficulty_button("MEDIUM", "A FAIR CHALLENGE", Color(0.96, 0.52, 0.12), func():
		_start_with_speed(0.80)
	)
	vbox.add_child(med_btn)
	
	# 3. Hard Button
	var hard_btn = _create_difficulty_button("HARD", "FAST AND FIERCE", Color(0.68, 0.42, 0.94), func():
		_start_with_speed(0.55)
	)
	vbox.add_child(hard_btn)
	
	var foot_lbl = Label.new()
	foot_lbl.text = "Minions pop up slower on Easy and faster on Hard."
	foot_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UIHelper.apply_bubbly_label(foot_lbl, 10, Color.WHITE, true)
	vbox.add_child(foot_lbl)

func _create_difficulty_button(level: String, subtitle: String, bg_color: Color, on_click: Callable) -> Control:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(0, 52)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var normal_style = UIHelper.create_bubbly_panel(26, bg_color, Color.WHITE, 2)
	btn.add_theme_stylebox_override("normal", normal_style)
	btn.add_theme_stylebox_override("hover", normal_style)
	btn.add_theme_stylebox_override("pressed", normal_style)
	
	var hbox = HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 10)
	btn.add_child(hbox)
	
	var l_lbl = Label.new()
	l_lbl.text = level
	UIHelper.apply_bubbly_label(l_lbl, 18, Color.WHITE, true)
	hbox.add_child(l_lbl)
	
	var r_lbl = Label.new()
	r_lbl.text = subtitle
	UIHelper.apply_bubbly_label(r_lbl, 10, Color(1, 1, 1, 0.9), true)
	hbox.add_child(r_lbl)
	
	btn.pressed.connect(func():
		AudioManager.play_sfx("click")
		on_click.call()
	)
	return btn

func _on_pause_pressed():
	AudioManager.play_sfx("click")
	is_paused = true
	
	if timer_node:
		timer_node.paused = true
	if spawn_timer:
		spawn_timer.paused = true
	for tw in hole_tweens:
		if tw and is_instance_valid(tw) and tw.is_valid():
			tw.pause()
	
	if pause_modal and is_instance_valid(pause_modal):
		pause_modal.queue_free()
		
	var safe_sz = UIHelper.get_viewport_safe_size(self)
	var dlg = UIHelper.create_modal_dialog(self, 100)
	pause_modal = dlg["overlay"]
	var center = dlg["center"]
	
	var max_card_w = min(safe_sz.x - 40.0, (safe_sz.y - 40.0) / 1.50)
	var card_w = clamp(max_card_w, 260.0, 320.0)
	var modal_info = UIHelper.create_modal_card(card_w, "portrait")
	var card = modal_info["root"]
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(card)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	modal_info["content"].add_child(vbox)
	
	var title = Label.new()
	title.text = "GAME PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(title, 22, Color.WHITE, true)
	title.add_theme_color_override("font_shadow_color", Color(0.12, 0.40, 0.70))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	vbox.add_child(title)
	
	var btn_w = card_w - 40.0
	var resume_btn = UIHelper.create_themed_button("resume", Vector2(btn_w, 50))
	resume_btn.custom_minimum_size = Vector2(btn_w, 46)
	resume_btn.pressed.connect(func():
		AudioManager.play_sfx("click")
		is_paused = false
		if timer_node:
			timer_node.paused = false
		if spawn_timer:
			spawn_timer.paused = false
		for tw in hole_tweens:
			if tw and is_instance_valid(tw) and tw.is_valid():
				tw.play()
		for i in range(9):
			if hole_states[i] == "up":
				if not hole_tweens[i] or not is_instance_valid(hole_tweens[i]) or not hole_tweens[i].is_valid():
					_retract_minion_at(i)
		if pause_modal and is_instance_valid(pause_modal):
			pause_modal.queue_free()
			pause_modal = null
	)
	vbox.add_child(resume_btn)
	
	var restart_btn = UIHelper.create_themed_button("restart", Vector2(btn_w, 50))
	restart_btn.custom_minimum_size = Vector2(btn_w, 46)
	restart_btn.pressed.connect(func():
		AudioManager.play_sfx("click")
		is_paused = false
		if timer_node:
			timer_node.paused = false
		if spawn_timer:
			spawn_timer.paused = false
		if pause_modal and is_instance_valid(pause_modal):
			pause_modal.queue_free()
			pause_modal = null
		_reset_all_holes()
		var diff = GameState.get_difficulty()
		var spd = 1.05 if diff == "easy" else (0.80 if diff == "medium" else 0.55)
		_start_with_speed(spd)
	)
	vbox.add_child(restart_btn)
	
	var quit_btn = UIHelper.create_themed_button("exitgame", Vector2(btn_w, 50))
	quit_btn.custom_minimum_size = Vector2(btn_w, 46)
	quit_btn.pressed.connect(func():
		AudioManager.play_sfx("click")
		is_playing = false
		is_paused = false
		if timer_node:
			timer_node.stop()
			timer_node.paused = false
		if spawn_timer:
			spawn_timer.stop()
			spawn_timer.paused = false
		_reset_all_holes()
		if pause_modal and is_instance_valid(pause_modal):
			pause_modal.queue_free()
			pause_modal = null
		game_ended.emit()
	)
	vbox.add_child(quit_btn)

func _on_game_over():
	is_playing = false
	is_paused = false
	if timer_node:
		timer_node.stop()
	if spawn_timer:
		spawn_timer.stop()
	if pause_btn:
		pause_btn.visible = false
	_reset_all_holes()
	
	var p = GameState.get_active_profile()
	var prev_best = p.get("bestWhack", 0) if p else 0
	if p and score > prev_best:
		p["bestWhack"] = score
		
	var coins_won = score * 2 + combo_coins
	var pts_won = score * 10 + combo_points
	GameState.add_molar_coins(coins_won)
	GameState.add_points(pts_won)
	GameState.save_game()
	
	AudioManager.play_sfx("cheer")
	
	if over_modal and is_instance_valid(over_modal):
		over_modal.queue_free()
		over_modal = null
		
	var safe_sz = UIHelper.get_viewport_safe_size(self)
	var dlg = UIHelper.create_modal_dialog(self, 250)
	over_modal = dlg["overlay"]
	var center = dlg["center"]
	
	var max_card_w = min(safe_sz.x - 32.0, (safe_sz.y - 40.0) / 1.45)
	# Window size reduced by 20% (compact, snug card)
	var card_w = clamp(max_card_w, 300.0, 380.0)
	var modal_info = UIHelper.create_modal_card(card_w, "portrait")
	var card = modal_info["root"]
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(card)
	
	modal_info["content"].add_theme_constant_override("margin_left", 14)
	modal_info["content"].add_theme_constant_override("margin_right", 14)
	modal_info["content"].add_theme_constant_override("margin_top", 16)
	modal_info["content"].add_theme_constant_override("margin_bottom", 16)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	modal_info["content"].add_child(vbox)
	
	# Doubled impact Title
	var t = Label.new()
	t.text = "TIME'S UP!"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(t, 24, Color.WHITE, true)
	t.add_theme_color_override("font_shadow_color", Color(0.08, 0.28, 0.58, 0.95))
	t.add_theme_constant_override("shadow_offset_x", 0)
	t.add_theme_constant_override("shadow_offset_y", 3)
	t.add_theme_color_override("font_outline_color", Color(0.10, 0.35, 0.65))
	t.add_theme_constant_override("outline_size", 4)
	vbox.add_child(t)
	
	var stats_panel = PanelContainer.new()
	var sp_st = UIHelper.create_bubbly_panel(18, Color(1, 1, 1, 0.95), Color(0.72, 0.88, 1.0), 3)
	sp_st.content_margin_left = 14
	sp_st.content_margin_right = 14
	sp_st.content_margin_top = 12
	sp_st.content_margin_bottom = 12
	stats_panel.add_theme_stylebox_override("panel", sp_st)
	
	var stats_box = VBoxContainer.new()
	stats_box.add_theme_constant_override("separation", 8)
	
	var w_row = Label.new()
	w_row.text = "Whacked: %d Minions" % score
	w_row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(w_row, 15, Color(0.12, 0.36, 0.68), true)
	stats_box.add_child(w_row)
	
	var c_row = Label.new()
	c_row.text = "Best Combo: x%d" % max_combo
	c_row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(c_row, 14, Color(0.92, 0.42, 0.08), true)
	stats_box.add_child(c_row)
	
	# Rewards row with doubled 48x48 icons and 20pt bold text
	var rew_hbox = HBoxContainer.new()
	rew_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	rew_hbox.add_theme_constant_override("separation", 14)
	
	# Coins pill
	var coin_badge = UIHelper.create_reward_badge("res://assets/images/congratulations/gold_tooth_coin.png", "%d Coins" % coins_won, Color(0.86, 0.55, 0.05), 116.0, 40.0)
	rew_hbox.add_child(coin_badge)
	
	# Points pill
	var pt_badge = UIHelper.create_reward_badge("res://assets/images/shop/purple_star_points.png", "%d Points" % pts_won, Color(0.58, 0.28, 0.82), 116.0, 40.0)
	rew_hbox.add_child(pt_badge)
	
	stats_box.add_child(rew_hbox)
	stats_panel.add_child(stats_box)
	vbox.add_child(stats_panel)
	
	# Doubled prominent RETURN TO MAP Button
	var btn_w = clamp(card_w - 24.0, 200.0, 260.0)
	var btn_h = 56.0
	var cont_btn = UIHelper.create_themed_button("returntomap", Vector2(btn_w, btn_h))
	if not cont_btn.texture_normal:
		cont_btn = UIHelper.create_bubbly_button("RETURN TO MAP", UIHelper.VIBRANT_GREEN)
		cont_btn.custom_minimum_size = Vector2(btn_w, 48)
	else:
		cont_btn.custom_minimum_size = Vector2(btn_w, btn_h)
		cont_btn.size = Vector2(btn_w, btn_h)
	cont_btn.pivot_offset = Vector2(btn_w * 0.5, btn_h * 0.5)
		
	cont_btn.pressed.connect(func():
		AudioManager.play_sfx("click")
		_reset_all_holes()
		if over_modal and is_instance_valid(over_modal):
			over_modal.queue_free()
			over_modal = null
		game_won.emit()
	)
	
	var bc = CenterContainer.new()
	bc.add_child(cont_btn)
	vbox.add_child(bc)
	
	# Bouncy pop-in animation
	var card_h = modal_info["height"] if modal_info.has("height") else card_w * 1.50
	card.pivot_offset = Vector2(card_w * 0.5, card_h * 0.5)
	card.scale = Vector2(0.85, 0.85)
	card.modulate.a = 0.0
	var tw = card.create_tween().set_parallel(true)
	tw.tween_property(card, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "modulate:a", 1.0, 0.15)

# ==========================================================
# GAMEPLAY LOOP & BUG-FREE MINION STATE MACHINE
# ==========================================================
func _start_with_speed(spd: float):
	spawn_speed = spd
	if difficulty_modal:
		difficulty_modal.queue_free()
		difficulty_modal = null
	
	_reset_all_holes()
	
	score = 0
	misses = 0
	time_left = 30
	consecutive_whacks = 0
	max_combo = 0
	combo_points = 0
	combo_coins = 0
	is_playing = true
	is_paused = false
	
	whacked_label.text = "0"
	misses_label.text = "0"
	time_label.text = "30s"
	if points_val_label:
		points_val_label.text = "0"
	if coins_val_label:
		coins_val_label.text = "0"
	
	var p = GameState.get_active_profile()
	best_label.text = "BEST: %d WHACKS IN 30S" % p.get("bestWhack", 0)
	
	spawn_timer.wait_time = spawn_speed
	spawn_timer.start()
	timer_node.start()

func _on_spawn_tick():
	if not is_playing or is_paused: return
	
	# Find idle holes
	var idle_indices: Array[int] = []
	for i in range(9):
		if hole_states[i] == "idle" and i != last_spawned_hole:
			idle_indices.append(i)
			
	if idle_indices.is_empty():
		for i in range(9):
			if hole_states[i] == "idle":
				idle_indices.append(i)
				
	if idle_indices.is_empty():
		return # All holes currently in use
		
	var chosen = idle_indices[randi() % idle_indices.size()]
	last_spawned_hole = chosen
	_popup_minion_at(chosen)

func _popup_minion_at(idx: int):
	hole_states[idx] = "up"
	
	if hole_tweens[idx] and is_instance_valid(hole_tweens[idx]):
		hole_tweens[idx].kill()
		hole_tweens[idx] = null
		
	var btn = minion_buttons[idx]
	btn.texture_normal = UIHelper.load_texture_safe("res://assets/images/candycrusadegame/BonBon-Minion.png")
	btn.visible = true
	btn.modulate = Color.WHITE
	btn.scale = Vector2(0.15, 0.15)
	
	var tw = create_tween()
	hole_tweens[idx] = tw
	tw.tween_property(btn, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Stay up duration decreases slightly with score
	var up_time = max(0.42, spawn_speed * 0.90 - float(score) * 0.012)
	tw.tween_interval(up_time)
	tw.tween_callback(func():
		if is_playing and hole_states[idx] == "up":
			_retract_minion_at(idx)
	)

func _retract_minion_at(idx: int):
	if hole_states[idx] != "up": return
	hole_states[idx] = "retract"
	
	# Escaped minion breaks combo streak
	consecutive_whacks = 0
	
	if hole_tweens[idx] and is_instance_valid(hole_tweens[idx]):
		hole_tweens[idx].kill()
		hole_tweens[idx] = null
		
	var btn = minion_buttons[idx]
	var tw = create_tween()
	hole_tweens[idx] = tw
	tw.tween_property(btn, "scale", Vector2(0.1, 0.1), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		btn.visible = false
		btn.scale = Vector2.ONE
		hole_states[idx] = "idle"
		hole_tweens[idx] = null
	)

func _on_hole_clicked(idx: int):
	if not is_playing or is_paused: return
	
	if hole_states[idx] == "up":
		# Hit successful! Transition immediately to 'hit' state
		hole_states[idx] = "hit"
		
		if hole_tweens[idx] and is_instance_valid(hole_tweens[idx]):
			hole_tweens[idx].kill()
			hole_tweens[idx] = null
			
		score += 1
		consecutive_whacks += 1
		if consecutive_whacks > max_combo:
			max_combo = consecutive_whacks
			
		var hit_pts = 10
		var hit_coins = 2
		# Combo streak bonus (every 3 consecutive whacks adds a step, capped at x4)
		var mult = min(4, 1 + int(consecutive_whacks / 3))
		if mult > 1:
			var b_pts = 5 * (mult - 1)
			var b_coins = 2 * (mult - 1)
			combo_points += b_pts
			combo_coins += b_coins
			hit_pts += b_pts
			hit_coins += b_coins
			_trigger_combo_animation(consecutive_whacks, b_pts, mult)
			
		whacked_label.text = str(score)
		if points_val_label:
			points_val_label.text = str(score * 10 + combo_points)
		if coins_val_label:
			coins_val_label.text = str(score * 2 + combo_coins)
		AudioManager.play_sfx("hit")
		_spawn_hit_rewards(idx, hit_pts, hit_coins)
		
		var btn = minion_buttons[idx]
		btn.texture_normal = UIHelper.load_texture_safe("res://assets/images/candycrusadegame/BonBon-Minion-Hit-Toothbrush.png")
		
		var tw = create_tween()
		hole_tweens[idx] = tw
		# Bonk squash & wobble
		tw.tween_property(btn, "scale", Vector2(1.20, 0.80), 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2(0.95, 1.05), 0.07)
		tw.tween_interval(0.10)
		tw.tween_property(btn, "scale", Vector2(0.1, 0.1), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(func():
			btn.visible = false
			btn.scale = Vector2.ONE
			btn.modulate = Color.WHITE
			hole_states[idx] = "idle"
			hole_tweens[idx] = null
		)
	elif hole_states[idx] == "idle":
		# Missed whack (tapped empty hole)
		consecutive_whacks = 0
		misses += 1
		misses_label.text = str(misses)
		AudioManager.play_sfx("hit")

func _spawn_hit_rewards(idx: int, pts: int, coins: int):
	if not reward_layer or not is_instance_valid(reward_layer):
		return
	if idx < 0 or idx >= hole_controls.size():
		return
		
	var hc = hole_controls[idx]
	if not hc or not is_instance_valid(hc):
		return
		
	var spawn_center = hc.global_position + Vector2(hc.size.x * 0.5, hc.size.y * 0.20)
	
	# Bursting Coins & Stars Fountaining from Minion Head (no numbers, just physical points and coins)
	var coin_tex = UIHelper.load_texture_safe("res://assets/images/shop/gold_tooth_coin.png")
	if not coin_tex:
		coin_tex = UIHelper.load_texture_safe("res://assets/images/congratulations/gold_tooth_coin.png")
	if not coin_tex:
		coin_tex = UIHelper.load_texture_safe("res://assets/images/misc/gold_tooth_coin.png")
		
	var star_tex = UIHelper.load_texture_safe("res://assets/images/shop/purple_star_points.png")
	if not star_tex:
		star_tex = UIHelper.load_texture_safe("res://assets/images/congratulations/purple_star_points.png")
	if not star_tex:
		star_tex = UIHelper.load_texture_safe("res://assets/images/misc/purple_star_points.png")
		
	var particle_items: Array[Dictionary] = [
		{"tex": coin_tex, "sz": 28.0, "angle": randf_range(-0.85, -0.45)},
		{"tex": star_tex, "sz": 28.0, "angle": randf_range(-0.45, -0.10)},
		{"tex": coin_tex, "sz": 24.0, "angle": randf_range(0.10, 0.45)},
		{"tex": star_tex, "sz": 24.0, "angle": randf_range(0.45, 0.85)},
		{"tex": coin_tex, "sz": 20.0, "angle": randf_range(-0.30, 0.30)},
		{"tex": star_tex, "sz": 20.0, "angle": randf_range(-0.60, 0.60)}
	]
	
	for p_info in particle_items:
		if not p_info["tex"]:
			continue
		var p_rect = TextureRect.new()
		p_rect.texture = p_info["tex"]
		p_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		p_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var psz: float = p_info["sz"]
		p_rect.custom_minimum_size = Vector2(psz, psz)
		p_rect.size = Vector2(psz, psz)
		p_rect.pivot_offset = Vector2(psz * 0.5, psz * 0.5)
		p_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p_rect.position = spawn_center - Vector2(psz * 0.5, psz * 0.5)
		p_rect.scale = Vector2(0.2, 0.2)
		reward_layer.add_child(p_rect)
		
		var dist = randf_range(44.0, 78.0)
		var angle: float = p_info["angle"] - PI * 0.5 # Upward spread cone
		var target_offset = Vector2(cos(angle), sin(angle)) * dist
		var end_pos = spawn_center + target_offset
		var rot_target = randf_range(-35.0, 35.0)
		
		var p_tw = p_rect.create_tween()
		p_tw.tween_property(p_rect, "scale", Vector2(1.15, 1.15), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		p_tw.parallel().tween_property(p_rect, "position", end_pos, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		p_tw.parallel().tween_property(p_rect, "rotation_degrees", rot_target, 0.35)
		p_tw.tween_property(p_rect, "position:y", end_pos.y + 18.0, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		p_tw.parallel().tween_property(p_rect, "modulate:a", 0.0, 0.28)
		p_tw.parallel().tween_property(p_rect, "scale", Vector2(0.6, 0.6), 0.28)
		p_tw.finished.connect(func():
			if is_instance_valid(p_rect):
				p_rect.queue_free()
		)
		
	AudioManager.play_sfx("coin")

func _trigger_combo_animation(combo_count: int, bonus_pts: int, mult: int):
	AudioManager.play_sfx("sparkle")
	combo_label.text = "COMBO x%d! (%d pts · x%d rewards)" % [combo_count, bonus_pts, mult]
	combo_banner.modulate = Color(1, 1, 1, 1)
	combo_banner.scale = Vector2(1.2, 1.2)
	
	var tw = combo_banner.create_tween()
	tw.tween_property(combo_banner, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.9)
	tw.tween_property(combo_banner, "modulate:a", 0.0, 0.3)

func _reset_all_holes():
	if reward_layer and is_instance_valid(reward_layer):
		for ch in reward_layer.get_children():
			if is_instance_valid(ch):
				ch.queue_free()
	for i in range(9):
		if hole_tweens.size() > i and hole_tweens[i] and is_instance_valid(hole_tweens[i]):
			hole_tweens[i].kill()
			hole_tweens[i] = null
		if minion_buttons.size() > i and minion_buttons[i]:
			minion_buttons[i].visible = false
			minion_buttons[i].scale = Vector2.ONE
			minion_buttons[i].modulate = Color.WHITE
		if hole_states.size() > i:
			hole_states[i] = "idle"
	last_spawned_hole = -1

func _on_tick():
	if not is_playing or is_paused: return
	
	time_left -= 1
	time_label.text = "%ds" % time_left
	
	if time_left <= 0:
		is_playing = false
		timer_node.stop()
		spawn_timer.stop()
		_reset_all_holes()
		_on_game_over()
