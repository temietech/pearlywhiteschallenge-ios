# scripts/profile_screen.gd
extends Control

signal change_avatar_requested
signal switch_player_requested
signal back_pressed

var bg_rect: TextureRect
var back_btn: TextureButton
var set_btn: TextureButton
var central_card: Control
var scroll_container: ScrollContainer
var card_vbox: VBoxContainer
var name_label: Label
var edit_pencil_btn: BaseButton
var avatar_rect: TextureRect

# Level Progress Card Elements
var level_panel: PanelContainer
var level_title_label: Label
var next_level_label: Label
var level_progress_bar: ProgressBar
var level_xp_label: Label

# Stats Grid Elements
var stats_grid: GridContainer
var streak_value_label: Label
var time_value_label: Label
var coins_value_label: Label
var points_value_label: Label
var stat_card_controls: Array[Control] = []

var bottom_btn_hbox: HBoxContainer
var edit_av_btn: TextureButton
var switch_btn: TextureButton

func _ready():
	anchors_preset = Control.PRESET_FULL_RECT
	anchor_right = 1.0
	anchor_bottom = 1.0
	_build_ui()
	_refresh_profile()
	_relayout()
	GameState.stats_updated.connect(func(_p): _refresh_profile())
	GameState.profile_changed.connect(func(_p): _refresh_profile())

func _notification(what):
	if what == NOTIFICATION_RESIZED:
		_relayout()

func _build_ui():
	# Background (clean sky blue gradient with ambient rising bubbles)
	bg_rect = UIHelper.setup_clean_bubbly_bg(self)
	
	# Top Back Button
	back_btn = UIHelper.create_image_button("res://assets/images/shop/blue_back_button.png", Vector2(86, 38))
	if not back_btn.texture_normal:
		back_btn = UIHelper.create_image_button("res://assets/images/misc/blue_back_button.png", Vector2(86, 38))
	back_btn.pressed.connect(func():
		AudioManager.play_sfx("click")
		var main_node = get_tree().root.get_node_or_null("Main")
		if main_node and main_node.has_method("navigate_to"):
			main_node.navigate_to("map")
		else:
			back_pressed.emit()
	)
	add_child(back_btn)
	
	# Top Settings Button
	set_btn = UIHelper.create_image_button("res://assets/images/settings/settings_icon.png", Vector2(42, 42))
	set_btn.pressed.connect(func():
		AudioManager.play_sfx("click")
		var main_node = get_tree().root.get_node_or_null("Main")
		if main_node and main_node.has_method("navigate_to"):
			main_node.navigate_to("settings")
	)
	add_child(set_btn)
	
	# Central Frosted Card using authentic transparent_panel.png
	central_card = Control.new()
	central_card.name = "CentralCard"
	add_child(central_card)
	
	var panel_bg = NinePatchRect.new()
	panel_bg.name = "PanelBg"
	panel_bg.anchors_preset = Control.PRESET_FULL_RECT
	panel_bg.anchor_right = 1.0
	panel_bg.anchor_bottom = 1.0
	panel_bg.texture = UIHelper.load_texture_safe("res://assets/images/profile/transparent_panel.png")
	if not panel_bg.texture:
		panel_bg.texture = UIHelper.load_texture_safe("res://assets/images/parentalcontrol/transparent_panel.png")
	panel_bg.patch_margin_left = 32
	panel_bg.patch_margin_top = 40
	panel_bg.patch_margin_right = 32
	panel_bg.patch_margin_bottom = 32
	central_card.add_child(panel_bg)
	
	# ScrollContainer with clean padding and disabled scrollbars
	scroll_container = ScrollContainer.new()
	scroll_container.name = "ScrollContainer"
	scroll_container.anchors_preset = Control.PRESET_FULL_RECT
	scroll_container.anchor_right = 1.0
	scroll_container.anchor_bottom = 1.0
	scroll_container.offset_left = 16
	scroll_container.offset_right = -16
	scroll_container.offset_top = 14
	scroll_container.offset_bottom = -14
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	central_card.add_child(scroll_container)
	
	card_vbox = VBoxContainer.new()
	card_vbox.name = "CardVBox"
	card_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card_vbox.add_theme_constant_override("separation", 6)
	scroll_container.add_child(card_vbox)
	
	# 1. Player Name + Prominent Edit Button (30% bigger centered row)
	var name_center = CenterContainer.new()
	name_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_vbox.add_child(name_center)
	
	var name_row = HBoxContainer.new()
	name_row.alignment = BoxContainer.ALIGNMENT_CENTER
	name_row.add_theme_constant_override("separation", 12)
	name_center.add_child(name_row)
	
	name_label = Label.new()
	name_label.text = "Player"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(name_label, 36, Color(0.15, 0.40, 0.72), true)
	name_label.add_theme_color_override("font_outline_color", Color.WHITE)
	name_label.add_theme_constant_override("outline_size", 4)
	name_row.add_child(name_label)
	
	# Large, clear 3D Edit Pencil Button (30% bigger: 50x50)
	var ep_btn = Button.new()
	ep_btn.custom_minimum_size = Vector2(50, 50)
	ep_btn.size = Vector2(50, 50)
	ep_btn.pivot_offset = Vector2(25, 25)
	ep_btn.focus_mode = Control.FOCUS_NONE
	
	var edit_tex = UIHelper.load_texture_safe("res://assets/images/general/editbtn.png")
	if not edit_tex:
		edit_tex = UIHelper.load_texture_safe("res://assets/images/buttons/editbtn.png")
	
	if edit_tex:
		ep_btn.icon = edit_tex
		ep_btn.expand_icon = true
		ep_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var empty_sb = StyleBoxEmpty.new()
		ep_btn.add_theme_stylebox_override("normal", empty_sb)
		ep_btn.add_theme_stylebox_override("hover", empty_sb)
		ep_btn.add_theme_stylebox_override("pressed", empty_sb)
	else:
		ep_btn.text = "EDIT"
		var ep_style = UIHelper.create_bubbly_panel(25, Color(0.40, 0.82, 0.30), Color.WHITE, 2)
		ep_btn.add_theme_stylebox_override("normal", ep_style)
		ep_btn.add_theme_stylebox_override("hover", ep_style)
		ep_btn.add_theme_stylebox_override("pressed", ep_style)
		UIHelper.apply_bubbly_label(ep_btn, 11, Color.WHITE, true)
		
	ep_btn.button_down.connect(func():
		var tw = ep_btn.create_tween()
		tw.tween_property(ep_btn, "scale", Vector2(0.90, 0.90), 0.08)
	)
	ep_btn.button_up.connect(func():
		var tw = ep_btn.create_tween()
		tw.tween_property(ep_btn, "scale", Vector2.ONE, 0.08)
	)
	ep_btn.pressed.connect(func():
		AudioManager.play_sfx("click")
		var p = GameState.get_active_profile()
		var main_node = get_tree().root.get_node_or_null("Main")
		if main_node and main_node.has_method("navigate_to"):
			main_node.navigate_to("create_profile", {"edit_id": p.get("id", "")})
	)
	edit_pencil_btn = ep_btn
	name_row.add_child(edit_pencil_btn)
	
	# 2. Avatar (centered, 10% bigger: 98x98)
	var av_center = CenterContainer.new()
	av_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_vbox.add_child(av_center)
	
	avatar_rect = TextureRect.new()
	avatar_rect.name = "AvatarRect"
	avatar_rect.custom_minimum_size = Vector2(98, 98)
	avatar_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	av_center.add_child(avatar_rect)
	
	# 3. Player Level & XP Progress Card (centered, 30% shorter width)
	var level_center = CenterContainer.new()
	level_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_vbox.add_child(level_center)
	
	level_panel = PanelContainer.new()
	level_panel.name = "LevelProgressPanel"
	var lp_style = UIHelper.create_bubbly_panel(16, Color(1, 1, 1, 0.90), Color(0.85, 0.93, 1.0), 2)
	lp_style.content_margin_left = 14
	lp_style.content_margin_right = 14
	lp_style.content_margin_top = 8
	lp_style.content_margin_bottom = 8
	level_panel.add_theme_stylebox_override("panel", lp_style)
	level_center.add_child(level_panel)
	
	var lp_vbox = VBoxContainer.new()
	lp_vbox.add_theme_constant_override("separation", 4)
	level_panel.add_child(lp_vbox)
	
	var lp_hdr = HBoxContainer.new()
	lp_vbox.add_child(lp_hdr)
	
	level_title_label = Label.new()
	level_title_label.text = "Level 1 · Novice Brusher"
	level_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIHelper.apply_bubbly_label(level_title_label, 12, Color(0.12, 0.36, 0.60), true)
	lp_hdr.add_child(level_title_label)
	
	next_level_label = Label.new()
	next_level_label.text = "Lvl 2"
	UIHelper.apply_bubbly_label(next_level_label, 11, Color(0.25, 0.60, 0.90), true)
	lp_hdr.add_child(next_level_label)
	
	level_progress_bar = ProgressBar.new()
	level_progress_bar.custom_minimum_size = Vector2(0, 10)
	level_progress_bar.show_percentage = false
	level_progress_bar.min_value = 0.0
	level_progress_bar.max_value = 1.0
	level_progress_bar.value = 0.0
	
	var bg_sb = StyleBoxFlat.new()
	bg_sb.bg_color = Color(0.86, 0.92, 0.98)
	bg_sb.set_corner_radius_all(5)
	level_progress_bar.add_theme_stylebox_override("background", bg_sb)
	
	var fill_sb = StyleBoxFlat.new()
	fill_sb.bg_color = Color(0.40, 0.82, 0.30)
	fill_sb.set_corner_radius_all(5)
	level_progress_bar.add_theme_stylebox_override("fill", fill_sb)
	lp_vbox.add_child(level_progress_bar)
	
	level_xp_label = Label.new()
	level_xp_label.text = "100 points to Level 2"
	level_xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(level_xp_label, 10, Color(0.42, 0.55, 0.70), false)
	lp_vbox.add_child(level_xp_label)
	
	# 4. 2x2 Stats Grid (Lowered by 20px, 20% larger ~144x126 cards)
	var stats_margin = MarginContainer.new()
	stats_margin.add_theme_constant_override("margin_top", 20)
	stats_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_vbox.add_child(stats_margin)
	
	var stats_center = CenterContainer.new()
	stats_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_margin.add_child(stats_center)
	
	stats_grid = GridContainer.new()
	stats_grid.columns = 2
	stats_grid.add_theme_constant_override("h_separation", 12)
	stats_grid.add_theme_constant_override("v_separation", 10)
	stats_center.add_child(stats_grid)
	
	stat_card_controls.clear()
	
	# Streak Card
	streak_value_label = Label.new()
	var streak_card = _create_stat_card("res://assets/images/profile/current_streak_icon.png", streak_value_label)
	stats_grid.add_child(streak_card)
	stat_card_controls.append(streak_card)
	
	# Time Card
	time_value_label = Label.new()
	var time_card = _create_stat_card("res://assets/images/profile/total_brushing_time_icon.png", time_value_label)
	stats_grid.add_child(time_card)
	stat_card_controls.append(time_card)
	
	# Coins Card
	coins_value_label = Label.new()
	var coins_card = _create_stat_card("res://assets/images/profile/molar_coins_icon.png", coins_value_label)
	stats_grid.add_child(coins_card)
	stat_card_controls.append(coins_card)
	
	# Points Card
	points_value_label = Label.new()
	var points_card = _create_stat_card("res://assets/images/profile/points_star_button.png", points_value_label)
	stats_grid.add_child(points_card)
	stat_card_controls.append(points_card)
	
	# 5. Action Buttons — Cleanly docked below the card
	bottom_btn_hbox = HBoxContainer.new()
	bottom_btn_hbox.name = "BottomBtnHBox"
	bottom_btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_btn_hbox.add_theme_constant_override("separation", 14)
	add_child(bottom_btn_hbox)
	
	edit_av_btn = UIHelper.create_themed_button("changeavatar", Vector2(150, 48))
	if not edit_av_btn.texture_normal:
		edit_av_btn = UIHelper.create_image_button("res://assets/images/profile/edit_avatar_button_1.png", Vector2(150, 48))
	edit_av_btn.pressed.connect(func():
		AudioManager.play_sfx("click")
		change_avatar_requested.emit()
	)
	bottom_btn_hbox.add_child(edit_av_btn)
	
	switch_btn = UIHelper.create_themed_button("switchuser", Vector2(150, 48))
	if not switch_btn.texture_normal:
		switch_btn = UIHelper.create_image_button("res://assets/images/profile/switch_player_button.png", Vector2(150, 48))
	switch_btn.pressed.connect(func():
		AudioManager.play_sfx("click")
		switch_player_requested.emit()
	)
	bottom_btn_hbox.add_child(switch_btn)

func _relayout():
	var safe_sz = UIHelper.get_viewport_safe_size(self)
	var w = safe_sz.x
	var h = safe_sz.y
	var is_tablet = w >= 600
	
	if bg_rect:
		bg_rect.size = safe_sz
	
	# Top Navigation Buttons
	var top_pad = 14.0
	if back_btn:
		back_btn.position = Vector2(14, top_pad)
		back_btn.size = Vector2(86, 38) if not is_tablet else Vector2(104, 44)
		
	if set_btn:
		var btn_dim = 42.0 if not is_tablet else 48.0
		set_btn.position = Vector2(w - btn_dim - 14.0, top_pad)
		set_btn.size = Vector2(btn_dim, btn_dim)
	
	# Bottom Action Buttons
	var btn_area_h = 50.0 if not is_tablet else 56.0
	var btn_y = h - btn_area_h - 14.0
	if bottom_btn_hbox:
		var total_btn_w = min(w - 32.0, 360.0) if not is_tablet else min(w - 48.0, 440.0)
		bottom_btn_hbox.position = Vector2((w - total_btn_w) * 0.5, btn_y)
		bottom_btn_hbox.size = Vector2(total_btn_w, btn_area_h)
		var single_btn_w = (total_btn_w - 14.0) * 0.5
		var single_btn_h = 46.0 if not is_tablet else 52.0
		if edit_av_btn:
			edit_av_btn.custom_minimum_size = Vector2(single_btn_w, single_btn_h)
		if switch_btn:
			switch_btn.custom_minimum_size = Vector2(single_btn_w, single_btn_h)
		bottom_btn_hbox.z_index = 50
		
	# Central Card — organically fills and centers with ample breathing room
	if central_card:
		var card_w = clamp(w - 32.0, 340.0, 420.0) if not is_tablet else clamp(w - 80.0, 400.0, 520.0)
		var card_top = 58.0
		var card_bottom = btn_y - 12.0
		var card_h = card_bottom - card_top
		central_card.position = Vector2((w - card_w) * 0.5, card_top)
		central_card.size = Vector2(card_w, card_h)
		
		# Avatar sizing (10% bigger)
		if avatar_rect:
			var av_dim = 98.0 if not is_tablet else 120.0
			avatar_rect.custom_minimum_size = Vector2(av_dim, av_dim)
			avatar_rect.size = Vector2(av_dim, av_dim)
		
		# Level progress scale (30% shorter width)
		if level_panel:
			var inner_w = card_w - 48.0
			var scale_w = round(inner_w * 0.70)
			level_panel.custom_minimum_size = Vector2(scale_w, 0)
			level_panel.size = Vector2(scale_w, 0)
		
		# Stat cards sizing — 20% larger (~144x126)
		if stats_grid:
			var inner_w = card_w - 48.0
			var sc_w = clamp(round((inner_w - 12.0) * 0.5 * 0.96), 138.0, 168.0) if not is_tablet else clamp(round((inner_w - 16.0) * 0.5 * 0.96), 160.0, 205.0)
			var sc_h = round(sc_w * (363.0 / 413.0))
			for c in stat_card_controls:
				if is_instance_valid(c):
					c.custom_minimum_size = Vector2(sc_w, sc_h)
					c.size = Vector2(sc_w, sc_h)

func _create_stat_card(card_texture_path: String, val_lbl: Label) -> Control:
	var cont = Control.new()
	cont.custom_minimum_size = Vector2(144, 126)
	
	var tex_rect = TextureRect.new()
	tex_rect.anchors_preset = Control.PRESET_FULL_RECT
	tex_rect.anchor_right = 1.0
	tex_rect.anchor_bottom = 1.0
	tex_rect.texture = UIHelper.load_texture_safe(card_texture_path)
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cont.add_child(tex_rect)
	
	# Value label sits prominently at the bottom portion of the card (lowered by 5px, bold font)
	val_lbl.anchors_preset = Control.PRESET_BOTTOM_WIDE
	val_lbl.anchor_top = 0.60
	val_lbl.anchor_bottom = 0.92
	val_lbl.anchor_left = 0.0
	val_lbl.anchor_right = 1.0
	val_lbl.offset_top = 5.0
	val_lbl.offset_bottom = 5.0
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(val_lbl, 20, Color(0.12, 0.32, 0.60), true)
	val_lbl.add_theme_color_override("font_outline_color", Color.WHITE)
	val_lbl.add_theme_constant_override("outline_size", 4)
	cont.add_child(val_lbl)
	
	return cont

func _refresh_profile():
	var p = GameState.get_active_profile()
	if p.is_empty():
		return
	
	var raw_name = str(p.get("name", "Player")).strip_edges()
	name_label.text = raw_name.capitalize() if raw_name.length() > 0 else "Player"
	avatar_rect.texture = UIHelper.get_char_texture(p.get("avatar", "chip"), false)
	
	var pts = int(round(float(p.get("points", 0))))
	var lvl_info = GameState.level_for_points(pts, p)
	var cur_lvl = int(lvl_info.get("level", 1))
	var cur_title = str(lvl_info.get("title", "Novice Brusher"))
	
	# Calculate Next Level & Progress
	var next_lvl_obj = null
	for l in GameState.PLAYER_LEVELS:
		if int(l.get("level", 1)) == cur_lvl + 1:
			next_lvl_obj = l
			break
			
	if level_title_label:
		level_title_label.text = "Level %d · %s" % [cur_lvl, cur_title]
		
	if next_lvl_obj:
		var n_pts = int(next_lvl_obj.get("points", 100))
		var c_pts = int(lvl_info.get("points", 0))
		var n_mins = int(next_lvl_obj.get("minutes", 0))
		var c_mins = int(lvl_info.get("minutes", 0))
		
		var cur_m = GameState.get_total_brushing_minutes(p)
		
		var pts_ratio = clamp(float(pts - c_pts) / float(max(1, n_pts - c_pts)), 0.0, 1.0)
		var mins_ratio = 1.0
		if n_mins > c_mins:
			mins_ratio = clamp(float(cur_m - c_mins) / float(max(1, n_mins - c_mins)), 0.0, 1.0)
			
		var progress = min(pts_ratio, mins_ratio)
		if level_progress_bar:
			level_progress_bar.value = progress
		if next_level_label:
			next_level_label.text = "Lvl %d" % int(next_lvl_obj.get("level", cur_lvl + 1))
		if level_xp_label:
			var pts_needed = max(0, n_pts - pts)
			var mins_needed = max(0, n_mins - cur_m)
			if pts_needed > 0 and mins_needed > 0:
				level_xp_label.text = "%d points & %d mins to Level %d" % [pts_needed, mins_needed, int(next_lvl_obj.get("level", cur_lvl + 1))]
			elif mins_needed > 0:
				level_xp_label.text = "%d mins to Level %d" % [mins_needed, int(next_lvl_obj.get("level", cur_lvl + 1))]
			else:
				level_xp_label.text = "%d points to Level %d" % [pts_needed, int(next_lvl_obj.get("level", cur_lvl + 1))]
	else:
		if level_progress_bar:
			level_progress_bar.value = 1.0
		if next_level_label:
			next_level_label.text = "MAX"
		if level_xp_label:
			level_xp_label.text = "Maximum level reached!"
	
	streak_value_label.text = "%d Days" % int(round(float(p.get("streak", 0))))
	var mins = GameState.get_total_brushing_minutes(p)
	p["totalMinutes"] = mins
	p["totalBrushingSeconds"] = mins * 60
	p["brushing_time"] = mins * 60
	time_value_label.text = "%d Mins" % mins
	
	# Formatted numbers with comma separators for clean display
	coins_value_label.text = _format_number(int(round(float(p.get("coins", 0)))))
	points_value_label.text = _format_number(pts)

func _format_number(n: int) -> String:
	var s = str(abs(n))
	var out = ""
	var count = 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if n < 0 else "") + out
