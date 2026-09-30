# scripts/create_profile_screen.gd
extends Control

signal done_pressed
signal back_pressed

var title_lbl: Label
var name_input: LineEdit
var age_input: LineEdit
var category_badge: Label
var selected_avatar: String = "chip"
var avatar_cards: Dictionary = {}
var edit_id: String = ""

var bg: TextureRect

func _ready():
	set_anchors_preset(Control.PRESET_FULL_RECT)
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_right = 0
	offset_bottom = 0
	_build_ui()
	_relayout()


func _notification(what):
	if what == NOTIFICATION_RESIZED:
		if is_node_ready():
			_relayout()

func _relayout():
	var safe_sz = UIHelper.get_viewport_safe_size(self)
	var cur_w = safe_sz.x
	var cur_h = safe_sz.y
	if bg:
		bg.size = safe_sz

func setup_edit(profile_id: String):
	edit_id = profile_id
	if edit_id != "":
		if title_lbl:
			title_lbl.text = "EDIT PLAYER"
		for p in GameState.profiles:
			if p["id"] == edit_id:
				name_input.text = p.get("name", "")
				if age_input:
					age_input.text = str(p.get("age", 8))
					_on_age_changed(age_input.text)
				selected_avatar = p.get("avatar", "chip")
				_highlight_avatar()
				return
	else:
		if title_lbl:
			title_lbl.text = "NEW PLAYER"
		name_input.text = ""
		if age_input:
			age_input.text = "8"
			_on_age_changed("8")
		selected_avatar = "chip"
		_highlight_avatar()

func _build_ui():
	# Background
	bg = UIHelper.setup_clean_bubbly_bg(self)
	
	# CenterContainer
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	center.offset_right = 0
	center.offset_bottom = 0
	add_child(center)
	
	# Centered Layout
	var center_vbox = VBoxContainer.new()
	center_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center_vbox.add_theme_constant_override("separation", 20)
	center.add_child(center_vbox)
	
	# Title: "NEW PLAYER" / "EDIT PLAYER"
	title_lbl = Label.new()
	title_lbl.text = "EDIT PLAYER" if edit_id != "" else "NEW PLAYER"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(title_lbl, 32, Color.WHITE, true)
	title_lbl.add_theme_color_override("font_shadow_color", Color(0.12, 0.40, 0.70))
	title_lbl.add_theme_constant_override("shadow_offset_x", 2)
	title_lbl.add_theme_constant_override("shadow_offset_y", 3)
	center_vbox.add_child(title_lbl)
	
	# Central White Rounded Card
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(370, 420)
	var card_style = UIHelper.create_bubbly_panel(36, Color(1, 1, 1, 0.95), Color(0.85, 0.93, 1.0), 3)
	card_style.content_margin_left = 22
	card_style.content_margin_right = 22
	card_style.content_margin_top = 26
	card_style.content_margin_bottom = 26
	panel.add_theme_stylebox_override("panel", card_style)
	center_vbox.add_child(panel)
	
	var inner_vbox = VBoxContainer.new()
	inner_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	inner_vbox.add_theme_constant_override("separation", 22)
	panel.add_child(inner_vbox)
	
	# "PLAYER NAME & AGE" section
	var info_vbox = VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 6)
	
	var labels_hbox = HBoxContainer.new()
	labels_hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	
	var name_lbl = Label.new()
	name_lbl.text = "PLAYER NAME"
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIHelper.apply_bubbly_label(name_lbl, 13, Color(0.20, 0.50, 0.75), true)
	labels_hbox.add_child(name_lbl)
	
	var age_lbl = Label.new()
	age_lbl.text = "AGE"
	age_lbl.custom_minimum_size = Vector2(80, 0)
	UIHelper.apply_bubbly_label(age_lbl, 13, Color(0.20, 0.50, 0.75), true)
	labels_hbox.add_child(age_lbl)
	info_vbox.add_child(labels_hbox)
	
	var inputs_hbox = HBoxContainer.new()
	inputs_hbox.add_theme_constant_override("separation", 10)
	
	name_input = LineEdit.new()
	name_input.placeholder_text = "Enter name..."
	name_input.custom_minimum_size = Vector2(0, 52)
	name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_input.add_theme_font_size_override("font_size", 17)
	var input_style = UIHelper.create_bubbly_panel(26, Color(0.96, 0.98, 1.0), Color(0.85, 0.92, 0.98), 2)
	input_style.content_margin_left = 16
	input_style.content_margin_right = 16
	name_input.add_theme_stylebox_override("normal", input_style)
	name_input.add_theme_color_override("font_color", Color(0.15, 0.35, 0.60))
	name_input.add_theme_color_override("font_placeholder_color", Color(0.55, 0.68, 0.80))
	inputs_hbox.add_child(name_input)
	
	age_input = LineEdit.new()
	age_input.placeholder_text = "Age"
	age_input.text = "8"
	age_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	age_input.custom_minimum_size = Vector2(80, 52)
	age_input.max_length = 3
	age_input.add_theme_font_size_override("font_size", 17)
	var age_style = UIHelper.create_bubbly_panel(26, Color(0.96, 0.98, 1.0), Color(0.85, 0.92, 0.98), 2)
	age_input.add_theme_stylebox_override("normal", age_style)
	age_input.add_theme_color_override("font_color", Color(0.15, 0.35, 0.60))
	age_input.add_theme_color_override("font_placeholder_color", Color(0.55, 0.68, 0.80))
	age_input.text_changed.connect(_on_age_changed)
	inputs_hbox.add_child(age_input)
	info_vbox.add_child(inputs_hbox)
	
	# Category live indicator
	category_badge = Label.new()
	category_badge.text = "Category: Kid Brusher (Ages 7–12)"
	category_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(category_badge, 11, Color(0.35, 0.60, 0.85), false)
	info_vbox.add_child(category_badge)
	
	inner_vbox.add_child(info_vbox)
	
	# "CHOOSE AVATAR" section
	var avatar_vbox = VBoxContainer.new()
	avatar_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	avatar_vbox.add_theme_constant_override("separation", 10)
	
	var avatar_title_tex = UIHelper.load_texture_safe("res://assets/images/titles/chooseavatar_title.png")
	if not avatar_title_tex:
		avatar_title_tex = UIHelper.load_texture_safe("res://assets/images/titles/chooseavatar_title.png")
	if avatar_title_tex:
		var a_img = TextureRect.new()
		a_img.texture = avatar_title_tex
		a_img.custom_minimum_size = Vector2(220, 44)
		a_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		a_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		a_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		avatar_vbox.add_child(a_img)
	else:
		var avatar_title = Label.new()
		avatar_title.text = "CHOOSE AVATAR"
		avatar_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UIHelper.apply_bubbly_label(avatar_title, 13, Color(0.20, 0.50, 0.75), true)
		avatar_vbox.add_child(avatar_title)
	
	var avatars_hbox = HBoxContainer.new()
	avatars_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	avatars_hbox.add_theme_constant_override("separation", 28)
	avatar_vbox.add_child(avatars_hbox)
	
	var starters = [
		{"id": "chip", "name": "Chip"},
		{"id": "flora", "name": "Flora"}
	]
	
	for s in starters:
		var c_id = s["id"]
		var c_name = s["name"]
		
		var char_btn_box = VBoxContainer.new()
		char_btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
		char_btn_box.add_theme_constant_override("separation", 6)
		
		var char_btn = TextureButton.new()
		char_btn.texture_normal = UIHelper.get_char_texture(c_id, false)
		char_btn.custom_minimum_size = Vector2(96, 96)
		char_btn.ignore_texture_size = true
		char_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		char_btn.pivot_offset = Vector2(48, 48)
		
		char_btn.pressed.connect(func():
			selected_avatar = c_id
			_highlight_avatar()
			AudioManager.play_sfx("click")
		)
		char_btn_box.add_child(char_btn)
		
		var char_lbl = Label.new()
		char_lbl.text = c_name
		char_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UIHelper.apply_bubbly_label(char_lbl, 16, UIHelper.NAVY_BLUE, true)
		char_btn_box.add_child(char_lbl)
		
		avatar_cards[c_id] = {"btn": char_btn, "lbl": char_lbl, "box": char_btn_box}
		avatars_hbox.add_child(char_btn_box)
		
	inner_vbox.add_child(avatar_vbox)
	
	# Action buttons: CANCEL & SAVE
	var btn_hbox = HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_theme_constant_override("separation", 18)
	
	var cancel_btn = UIHelper.create_themed_button("cancel", Vector2(140, 56))
	if not cancel_btn.texture_normal:
		cancel_btn = UIHelper.create_image_button("res://assets/images/general/cancel_button.png", Vector2(140, 56))
	cancel_btn.pressed.connect(func(): back_pressed.emit())
	btn_hbox.add_child(cancel_btn)
	
	var save_btn = UIHelper.create_themed_button("save", Vector2(140, 56))
	if not save_btn.texture_normal:
		save_btn = UIHelper.create_image_button("res://assets/images/general/save_button.png", Vector2(140, 56))
	save_btn.pressed.connect(_on_submit)
	btn_hbox.add_child(save_btn)
	
	inner_vbox.add_child(btn_hbox)
	
	_highlight_avatar()

func _highlight_avatar():
	for c_id in avatar_cards:
		var item = avatar_cards[c_id]
		var btn: TextureButton = item["btn"]
		var lbl: Label = item["lbl"]
		if c_id == selected_avatar:
			btn.scale = Vector2(1.12, 1.12)
			btn.modulate = Color(1.0, 1.0, 1.0, 1.0)
			lbl.add_theme_color_override("font_color", UIHelper.DEEP_BLUE)
		else:
			btn.scale = Vector2(0.95, 0.95)
			btn.modulate = Color(0.8, 0.85, 0.9, 0.75)
			lbl.add_theme_color_override("font_color", Color(0.4, 0.55, 0.7))

func _on_age_changed(new_text: String):
	var a = int(new_text) if new_text.is_valid_int() else 8
	var cat = GameState.get_category_for_age(a)
	if category_badge:
		if cat == "Junior":
			category_badge.text = "Category: Junior Brusher (Ages 1–6)"
		elif cat == "Kid":
			category_badge.text = "Category: Kid Brusher (Ages 7–12)"
		else:
			category_badge.text = "Category: Adult / Teen Brusher (Ages 13+)"

func _on_submit():
	var name_text = name_input.text.strip_edges()
	if name_text == "":
		name_text = "Brusher"
	var age_val = int(age_input.text) if (age_input and age_input.text.is_valid_int()) else 8
	if age_val <= 0:
		age_val = 8
		
	if edit_id != "":
		GameState.rename_profile(edit_id, name_text, selected_avatar, age_val)
	else:
		var id = GameState.add_profile(name_text, selected_avatar, age_val)
		GameState.set_active_profile(id)
		
	AudioManager.play_sfx("cheer")
	done_pressed.emit()