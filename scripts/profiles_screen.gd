# scripts/profiles_screen.gd
extends Control

signal profile_picked(id: String)
signal create_profile_requested
signal edit_profile_requested(id: String)
signal submit_pressed

var grid_container: GridContainer
var center_vbox: VBoxContainer
var title_img: TextureRect
var title_lbl: Label
var sub_lbl: Label
var add_btn: TextureButton
var submit_btn: TextureButton
var btn_hbox: HBoxContainer
var bg: TextureRect

func _ready():
	set_anchors_preset(Control.PRESET_FULL_RECT)
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_right = 0
	offset_bottom = 0
	_build_ui()
	refresh_profiles()
	_relayout()


func _notification(what):
	if what == NOTIFICATION_RESIZED:
		if is_node_ready():
			_relayout()

func _get_card_size() -> Vector2:
	var safe_sz = UIHelper.get_viewport_safe_size(self)
	var cur_w = safe_sz.x
	var cur_h = safe_sz.y
	var profile_count = max(GameState.profiles.size(), 1)
	var is_tablet = (cur_w >= 600.0)
	
	var max_w = min(cur_w - 32.0, 480.0 if not is_tablet else 680.0)
	var h_sep = 20.0 if not is_tablet else 24.0
	var card_w = clampf(floor((max_w - h_sep) * 0.5), 184.0, 224.0)
	if is_tablet and profile_count >= 3:
		card_w = clampf(floor((max_w - h_sep * 2.0) / 3.0), 180.0, 230.0)
		
	var max_card_h = 280.0 if profile_count <= 4 else 240.0
	var card_h = clampf(card_w * 1.26, 232.0, max_card_h)
	return Vector2(card_w, card_h)

func _relayout():
	var safe_sz = UIHelper.get_viewport_safe_size(self)
	var cur_w = safe_sz.x
	var cur_h = safe_sz.y
	if bg:
		bg.size = safe_sz
				
	var is_tablet = (cur_w >= 600.0)
	if title_img and is_instance_valid(title_img):
		var t_w = min(cur_w - 32.0, 420.0 if is_tablet else 350.0)
		var t_h = t_w * (435.0 / 1200.0)
		title_img.custom_minimum_size = Vector2(t_w, t_h)
		title_img.size = Vector2(t_w, t_h)
	if title_lbl and is_instance_valid(title_lbl):
		title_lbl.add_theme_font_size_override("font_size", 44 if is_tablet else 40)
	if sub_lbl and is_instance_valid(sub_lbl):
		sub_lbl.add_theme_font_size_override("font_size", 18 if is_tablet else 16)
	if center_vbox and is_instance_valid(center_vbox):
		center_vbox.add_theme_constant_override("separation", 24 if is_tablet else 18)
		
	var btn_sz = Vector2(195, 68) if is_tablet else Vector2(182, 64)
	if add_btn and is_instance_valid(add_btn):
		add_btn.custom_minimum_size = btn_sz
		add_btn.size = btn_sz
	if submit_btn and is_instance_valid(submit_btn):
		submit_btn.custom_minimum_size = btn_sz
		submit_btn.size = btn_sz

func _build_ui():
	# Background
	bg = UIHelper.setup_clean_bubbly_bg(self)
	var safe_sz = UIHelper.get_viewport_safe_size(self)
	var cur_w = safe_sz.x
	var is_tablet = (cur_w >= 600.0)
	
	# CenterContainer
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	center.offset_right = 0
	center.offset_bottom = 0
	add_child(center)
	
	# Center VBox - all elements sit directly on the sky gradient
	center_vbox = VBoxContainer.new()
	center_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center_vbox.add_theme_constant_override("separation", 24 if is_tablet else 18)
	center.add_child(center_vbox)
	
	# Title: 3D "PLAYER SETUP" Image with fallback label
	var title_tex = UIHelper.load_texture_safe("res://assets/images/titles/playersetup_title.png")
	if not title_tex:
		title_tex = UIHelper.load_texture_safe("res://assets/images/titles/playersetup_title.png")
	if title_tex:
		title_img = TextureRect.new()
		title_img.texture = title_tex
		var t_w = min(cur_w - 32.0, 420.0 if is_tablet else 350.0)
		var t_h = t_w * (435.0 / 1200.0)
		title_img.custom_minimum_size = Vector2(t_w, t_h)
		title_img.size = Vector2(t_w, t_h)
		title_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		title_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		title_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center_vbox.add_child(title_img)
	else:
		title_lbl = Label.new()
		title_lbl.text = "PLAYER SETUP"
		title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UIHelper.apply_bubbly_label(title_lbl, 44 if is_tablet else 40, Color.WHITE, true)
		title_lbl.add_theme_color_override("font_shadow_color", Color(0.12, 0.40, 0.70))
		title_lbl.add_theme_constant_override("shadow_offset_x", 2)
		title_lbl.add_theme_constant_override("shadow_offset_y", 3)
		center_vbox.add_child(title_lbl)
	
	# "TAP A PLAYER TO EDIT" subtitle on blue background
	sub_lbl = Label.new()
	sub_lbl.text = "TAP A PLAYER TO EDIT"
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(sub_lbl, 18 if is_tablet else 16, Color(0.92, 0.97, 1.0), true)
	sub_lbl.add_theme_color_override("font_shadow_color", Color(0.12, 0.35, 0.65, 0.8))
	sub_lbl.add_theme_constant_override("shadow_offset_x", 1)
	sub_lbl.add_theme_constant_override("shadow_offset_y", 2)
	center_vbox.add_child(sub_lbl)
	
	# Unsquashed Profile Cards Grid (big cards filling screen nicely)
	var grid_center = CenterContainer.new()
	grid_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_vbox.add_child(grid_center)
	
	grid_container = GridContainer.new()
	grid_container.columns = 2
	grid_container.add_theme_constant_override("h_separation", 20)
	grid_container.add_theme_constant_override("v_separation", 20)
	grid_center.add_child(grid_container)
	
	# Action buttons: ADD PLAYER & SUBMIT
	btn_hbox = HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_theme_constant_override("separation", 18)
	center_vbox.add_child(btn_hbox)
	
	var btn_sz = Vector2(182, 64)
	add_btn = UIHelper.create_themed_button("adduser", btn_sz)
	if not add_btn.texture_normal:
		add_btn = UIHelper.create_image_button("res://assets/images/addprofilescreen/add_player_button_1.png", btn_sz)
	
	if GameState.profiles.size() >= 5:
		add_btn.modulate = Color(0.7, 0.7, 0.7, 0.5)
		
	add_btn.pressed.connect(func():
		if GameState.profiles.size() >= 5:
			AudioManager.play_sfx("error")
			return
		AudioManager.play_sfx("click")
		create_profile_requested.emit()
	)
	btn_hbox.add_child(add_btn)
	
	submit_btn = UIHelper.create_themed_button("confirm", btn_sz)  # was "submit" (SUBMIT ANSWER image); CONFIRM fits Player Setup
	if not submit_btn.texture_normal:
		submit_btn = UIHelper.create_image_button(
			"res://assets/images/addprofilescreen/submit_button.png",
			btn_sz
		)
	if not submit_btn.texture_normal:
		submit_btn = UIHelper.create_image_button("res://assets/images/misc/submit_button.png", btn_sz)
	submit_btn.pressed.connect(func():
		AudioManager.play_sfx("click")
		submit_pressed.emit()
	)
	btn_hbox.add_child(submit_btn)

func refresh_profiles():
	for c in grid_container.get_children():
		c.queue_free()
		
	var profiles = GameState.profiles
	var safe_sz = UIHelper.get_viewport_safe_size(self)
	var is_tablet = (safe_sz.x >= 600.0)
	grid_container.columns = 3 if (is_tablet and profiles.size() >= 3) else 2
	
	var card_sz = _get_card_size()
	for p in profiles:
		var card = _create_player_card(p, card_sz)
		grid_container.add_child(card)

func _create_player_card(p: Dictionary, card_sz: Vector2) -> Control:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = card_sz
	panel.size = card_sz
	var style = UIHelper.create_bubbly_panel(30, Color(1, 1, 1, 0.98), Color(0.80, 0.90, 0.98), 3)
	panel.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 6)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vbox)
	
	var av_dim = clampf(card_sz.y * 0.46, 76.0, 104.0)
	var avatar = TextureRect.new()
	avatar.texture = UIHelper.get_char_texture(p.get("avatar", "chip"), false)
	avatar.custom_minimum_size = Vector2(av_dim, av_dim)
	avatar.size = Vector2(av_dim, av_dim)
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(avatar)
	
	var name_lbl = Label.new()
	name_lbl.text = p.get("name", "Player").to_upper()
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIHelper.apply_bubbly_label(name_lbl, 20, UIHelper.DEEP_BLUE, true)
	name_lbl.add_theme_color_override("font_outline_color", Color(0.85, 0.93, 1.0))
	name_lbl.add_theme_constant_override("outline_size", 2)
	vbox.add_child(name_lbl)
	
	var safe_sz = UIHelper.get_viewport_safe_size(self)
	var is_tablet = (safe_sz.x >= 600.0)
	var edit_sz = Vector2(56, 56) if is_tablet else Vector2(50, 50)
	var edit_badge = UIHelper.create_themed_button("edit", edit_sz)
	edit_badge.custom_minimum_size = edit_sz
	edit_badge.size = edit_sz
	edit_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	edit_badge.z_index = 5
	vbox.add_child(edit_badge)
	
	# Transparent overlay button to trigger edit
	var btn = Button.new()
	btn.flat = true
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.offset_left = 0
	btn.offset_right = 0
	btn.offset_top = 0
	btn.offset_bottom = 0
	btn.size = card_sz
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.focus_mode = Control.FOCUS_NONE
	btn.pressed.connect(func():
		AudioManager.play_sfx("click")
		edit_profile_requested.emit(p["id"])
	)
	panel.add_child(btn)
	
	return panel
