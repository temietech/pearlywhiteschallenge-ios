# scripts/achievement_overlay.gd
extends Control

signal dismissed

var dim: ColorRect
var center_container: CenterContainer
var modal_panel: PanelContainer
var heading_label: Label
var inner_panel: Panel
var rank_title_label: Label
var rank_progress: ProgressBar
var rank_pts_label: Label
var body_label: Label
var char_icon: TextureRect
var char_title_label: Label
var rew_box: HBoxContainer
var coin_pill: Panel
var coin_lbl: Label
var star_pill: Panel
var star_lbl: Label
var btn_box: HBoxContainer
var equip_btn: Button
var dismiss_btn: Button

var current_char_id: String = ""
var current_screen: String = ""
var pending_achievements: Array[Dictionary] = []
var is_showing: bool = false

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0
	visible = false
	_build_ui()
	_relayout()
	GameState.achievement_unlocked.connect(_on_achievement_unlocked)

func _notification(what: int):
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_relayout()

func _relayout():
	if modal_panel:
		var safe_sz = UIHelper.get_viewport_safe_size(self)
		var panel_w = clamp(safe_sz.x - 40.0, 310.0, 360.0)
		modal_panel.custom_minimum_size.x = panel_w
		if modal_panel.size != Vector2.ZERO:
			modal_panel.pivot_offset = modal_panel.size * 0.5

func _build_ui():
	# Dimmed backdrop
	dim = ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.04, 0.10, 0.24, 0.75)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	
	# Center container guarantees 100% horizontal and vertical centering on any viewport
	center_container = CenterContainer.new()
	center_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	center_container.anchor_right = 1.0
	center_container.anchor_bottom = 1.0
	center_container.offset_left = 0
	center_container.offset_top = 0
	center_container.offset_right = 0
	center_container.offset_bottom = 0
	center_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center_container)
	
	# Modal Panel matching screens/50-achievement-popup.png
	modal_panel = PanelContainer.new()
	modal_panel.custom_minimum_size = Vector2(340, 0)
	var m_st = StyleBoxFlat.new()
	m_st.bg_color = Color(0.32, 0.68, 0.98) # Bright cyan-blue
	m_st.set_corner_radius_all(30)
	m_st.border_width_left = 4
	m_st.border_width_right = 4
	m_st.border_width_top = 4
	m_st.border_width_bottom = 4
	m_st.border_color = Color.WHITE
	m_st.shadow_color = Color(0.06, 0.18, 0.38, 0.6)
	m_st.shadow_size = 24
	m_st.shadow_offset = Vector2(0, 10)
	m_st.content_margin_left = 20
	m_st.content_margin_right = 20
	m_st.content_margin_top = 20
	m_st.content_margin_bottom = 20
	modal_panel.add_theme_stylebox_override("panel", m_st)
	center_container.add_child(modal_panel)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 10)
	modal_panel.add_child(vbox)
	
	# Title: "LEVEL UP!" / "NEW CHAMPION!"
	heading_label = Label.new()
	heading_label.text = "LEVEL UP!"
	heading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(heading_label, 24, Color.WHITE, true)
	heading_label.add_theme_color_override("font_shadow_color", Color(0.12, 0.40, 0.72, 0.8))
	heading_label.add_theme_constant_override("shadow_offset_x", 0)
	heading_label.add_theme_constant_override("shadow_offset_y", 2)
	vbox.add_child(heading_label)
	
	# Inner White Panel (for rank level up)
	inner_panel = Panel.new()
	inner_panel.custom_minimum_size = Vector2(300, 86)
	var in_st = StyleBoxFlat.new()
	in_st.bg_color = Color.WHITE
	in_st.set_corner_radius_all(20)
	inner_panel.add_theme_stylebox_override("panel", in_st)
	vbox.add_child(inner_panel)
	
	var in_vbox = VBoxContainer.new()
	in_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	in_vbox.anchor_right = 1.0
	in_vbox.anchor_bottom = 1.0
	in_vbox.offset_left = 12
	in_vbox.offset_right = -12
	in_vbox.offset_top = 8
	in_vbox.offset_bottom = -8
	in_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	in_vbox.add_theme_constant_override("separation", 4)
	inner_panel.add_child(in_vbox)
	
	rank_title_label = Label.new()
	rank_title_label.text = "LEVEL 10 PEARLY LEGEND"
	rank_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(rank_title_label, 13, Color(0.12, 0.35, 0.65), true)
	in_vbox.add_child(rank_title_label)
	
	rank_progress = ProgressBar.new()
	rank_progress.custom_minimum_size = Vector2(260, 12)
	rank_progress.show_percentage = false
	var pb_bg = StyleBoxFlat.new()
	pb_bg.bg_color = Color(0.85, 0.92, 0.98)
	pb_bg.set_corner_radius_all(6)
	var pb_fl = StyleBoxFlat.new()
	pb_fl.bg_color = UIHelper.VIBRANT_GREEN
	pb_fl.set_corner_radius_all(6)
	rank_progress.add_theme_stylebox_override("background", pb_bg)
	rank_progress.add_theme_stylebox_override("fill", pb_fl)
	rank_progress.value = 100.0
	in_vbox.add_child(rank_progress)
	
	rank_pts_label = Label.new()
	rank_pts_label.text = "100 / 100 pts"
	rank_pts_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(rank_pts_label, 10, Color(0.35, 0.50, 0.70), true)
	in_vbox.add_child(rank_pts_label)
	
	# Character Icon (for avatar unlock achievements)
	char_icon = TextureRect.new()
	char_icon.custom_minimum_size = Vector2(90, 90)
	char_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	char_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	char_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	char_icon.visible = false
	vbox.add_child(char_icon)
	
	# Character Title (e.g. "SPARK HAS JOINED YOUR TEAM!")
	char_title_label = Label.new()
	char_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	char_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UIHelper.apply_bubbly_label(char_title_label, 15, Color.WHITE, true)
	char_title_label.visible = false
	vbox.add_child(char_title_label)
	
	# Body description
	body_label = Label.new()
	body_label.text = "You reached a new milestone! Keep brushing to maintain your sparkling smile."
	body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UIHelper.apply_bubbly_label(body_label, 12, Color.WHITE, true)
	vbox.add_child(body_label)
	
	# Reward Pills Box
	rew_box = HBoxContainer.new()
	rew_box.alignment = BoxContainer.ALIGNMENT_CENTER
	rew_box.add_theme_constant_override("separation", 14)
	vbox.add_child(rew_box)
	
	coin_pill = Panel.new()
	coin_pill.custom_minimum_size = Vector2(105, 34)
	var cp_st = UIHelper.create_bubbly_panel(17, Color.WHITE)
	coin_pill.add_theme_stylebox_override("panel", cp_st)
	var c_hbox = HBoxContainer.new()
	c_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	c_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	c_hbox.add_theme_constant_override("separation", 6)
	coin_pill.add_child(c_hbox)
	var c_icon = TextureRect.new()
	c_icon.custom_minimum_size = Vector2(22, 22)
	c_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	c_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	c_icon.texture = UIHelper.load_texture_safe("res://assets/images/congratulations/gold_tooth_coin.png")
	c_hbox.add_child(c_icon)
	coin_lbl = Label.new()
	coin_lbl.text = "+500"
	coin_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(coin_lbl, 13, Color(0.86, 0.55, 0.05), true)
	c_hbox.add_child(coin_lbl)
	rew_box.add_child(coin_pill)
	
	star_pill = Panel.new()
	star_pill.custom_minimum_size = Vector2(105, 34)
	var sp_st = UIHelper.create_bubbly_panel(17, Color.WHITE)
	star_pill.add_theme_stylebox_override("panel", sp_st)
	var s_hbox = HBoxContainer.new()
	s_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	s_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	s_hbox.add_theme_constant_override("separation", 6)
	star_pill.add_child(s_hbox)
	var s_icon = TextureRect.new()
	s_icon.custom_minimum_size = Vector2(22, 22)
	s_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	s_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	s_icon.texture = UIHelper.load_texture_safe("res://assets/images/congratulations/purple_star_points.png")
	s_hbox.add_child(s_icon)
	star_lbl = Label.new()
	star_lbl.text = "+1000"
	star_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(star_lbl, 13, Color(0.58, 0.28, 0.82), true)
	s_hbox.add_child(star_lbl)
	rew_box.add_child(star_pill)
	
	# Action Buttons
	btn_box = HBoxContainer.new()
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_box.add_theme_constant_override("separation", 10)
	vbox.add_child(btn_box)
	
	equip_btn = UIHelper.create_bubbly_button("EQUIP", Color(0.65, 0.42, 0.92))
	equip_btn.custom_minimum_size = Vector2(130, 48)
	equip_btn.pressed.connect(_on_equip_pressed)
	equip_btn.visible = false
	btn_box.add_child(equip_btn)
	
	dismiss_btn = UIHelper.create_bubbly_button("AWESOME!", UIHelper.VIBRANT_GREEN)
	dismiss_btn.custom_minimum_size = Vector2(280, 50)
	dismiss_btn.pressed.connect(_on_dismiss_pressed)
	btn_box.add_child(dismiss_btn)

func on_screen_changed(screen_name: String):
	current_screen = screen_name
	if current_screen == "map":
		# Only ever show on the map screen. Check if there are queued achievements waiting.
		if not is_showing:
			call_deferred("_check_show_next")
	else:
		# If user navigated away from the map, hide the popup immediately
		if is_showing:
			visible = false
			is_showing = false

func check_and_show_pending():
	if current_screen == "map" and not is_showing:
		_check_show_next()

func _on_achievement_unlocked(data: Dictionary):
	# Only ever display if currently on the main map page
	if current_screen == "map" and not is_showing:
		_check_show_next()

func _check_show_next():
	if is_showing:
		return
	if current_screen != "map":
		return
		
	var p = GameState.get_active_profile()
	if p.is_empty():
		return
		
	var queued = p.get("queued_achievements", [])
	if typeof(queued) != TYPE_ARRAY or queued.is_empty():
		return
		
	var data = queued.pop_front()
	var char_id = str(data.get("char_id", ""))
	if char_id != "":
		if not p.has("seen_character_unlocks") or typeof(p["seen_character_unlocks"]) != TYPE_ARRAY:
			p["seen_character_unlocks"] = ["chip", "flora"]
		if not p["seen_character_unlocks"].has(char_id):
			p["seen_character_unlocks"].append(char_id)
	GameState.save_game()
	
	_display_achievement(data)

func _display_achievement(data: Dictionary):
	is_showing = true
	
	heading_label.text = data.get("heading", "LEVEL UP!").to_upper()
	rank_title_label.text = data.get("subtitle", "PEARLY BRUSHER").to_upper()
	body_label.text = data.get("body", "Keep brushing to maintain your sparkling smile!")
	
	var coins = int(round(float(data.get("coins", 0))))
	if coins > 0:
		coin_lbl.text = "+%d" % coins
		coin_pill.visible = true
	else:
		coin_pill.visible = false
		
	var stars = int(round(float(data.get("stars", 0))))
	if stars > 0:
		star_lbl.text = "+%d" % stars
		star_pill.visible = true
	else:
		star_pill.visible = false
		
	rew_box.visible = (coin_pill.visible or star_pill.visible)
		
	current_char_id = data.get("char_id", "")
	var custom_img_path = str(data.get("image", ""))
	
	if current_char_id != "":
		char_icon.texture = UIHelper.get_char_texture(current_char_id, false)
		char_icon.visible = true
		char_title_label.text = data.get("subtitle", "").to_upper()
		char_title_label.visible = true
		inner_panel.visible = false
		equip_btn.visible = true
		dismiss_btn.custom_minimum_size = Vector2(130, 48)
	elif custom_img_path != "":
		char_icon.texture = UIHelper.load_texture_safe(custom_img_path)
		char_icon.visible = true
		char_title_label.text = data.get("subtitle", "").to_upper()
		char_title_label.visible = true
		inner_panel.visible = false
		equip_btn.visible = false
		dismiss_btn.custom_minimum_size = Vector2(280, 50)
	else:
		char_icon.visible = false
		char_title_label.visible = false
		inner_panel.visible = true
		equip_btn.visible = false
		dismiss_btn.custom_minimum_size = Vector2(280, 50)
		
	visible = true
	_relayout()
	if current_char_id != "":
		AudioManager.play_sfx("unlock")
		AudioManager.play_character_voice(current_char_id)
	else:
		AudioManager.play_sfx("unlock")
	
	modal_panel.scale = Vector2(0.7, 0.7)
	await get_tree().process_frame
	if modal_panel:
		modal_panel.pivot_offset = modal_panel.size * 0.5
		var tw = create_tween()
		tw.tween_property(modal_panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_equip_pressed():
	if current_char_id != "":
		var p = GameState.get_active_profile()
		if not p.is_empty():
			GameState.rename_profile(p["id"], p.get("name", "Player"), current_char_id, p.get("age", 8))
			GameState.save_game()
			GameState.stats_updated.emit(p)
	_on_dismiss_pressed()

func _on_dismiss_pressed():
	visible = false
	is_showing = false
	dismissed.emit()
	
	# If more achievements are queued, show the next one after a brief delay
	if current_screen == "map":
		var p = GameState.get_active_profile()
		if not p.is_empty() and p.get("queued_achievements", []).size() > 0:
			var t = get_tree().create_timer(0.35)
			t.timeout.connect(func():
				if current_screen == "map":
					_check_show_next()
			)

