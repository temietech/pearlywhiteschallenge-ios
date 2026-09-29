# scripts/avatar_care_screen.gd
extends Control

signal back_pressed

var bg: TextureRect
var back_btn: TextureButton
var set_btn: TextureButton
var status_label: Label
var tooth_box: Control
var tooth_rect: TextureRect
var cavities: Array[Control] = []
var toothbrush_tool: TextureRect
var is_dragging_tool: bool = false
var cleaned_count: int = 0
var total_cavities: int = 4
var is_cleaned: bool = false

func _ready():
	anchors_preset = Control.PRESET_FULL_RECT
	anchor_right = 1.0
	anchor_bottom = 1.0
	_build_ui()
	_relayout()
	_spawn_cavity_spots()

func _notification(what: int):
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_relayout()

func _build_ui():
	# Background
	bg = TextureRect.new()
	UIHelper.setup_fullscreen_bg(bg)
	bg.texture = UIHelper.create_sky_gradient_texture()
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(bg)
	
	# Top Back Button (cyan pill button matching mockup)
	back_btn = UIHelper.create_image_button("res://assets/images/misc/blue_back_button.png", Vector2(86, 36))
	if not back_btn.texture_normal:
		back_btn = UIHelper.create_image_button("res://assets/images/shop/blue_back_button.png", Vector2(86, 36))
	back_btn.pressed.connect(func():
		var main_node = get_tree().root.get_node_or_null("Main")
		if main_node and main_node.has_method("navigate_to"):
			main_node.navigate_to("map")
		else:
			back_pressed.emit()
	)
	add_child(back_btn)
	
	# Top Right Settings Cog
	set_btn = UIHelper.create_image_button("res://assets/images/settings/settings_icon.png", Vector2(38, 38))
	if not set_btn.texture_normal:
		set_btn = UIHelper.create_image_button("res://assets/images/misc/settings_icon.png", Vector2(38, 38))
	set_btn.pressed.connect(func():
		var main_node = get_tree().root.get_node_or_null("Main")
		if main_node and main_node.has_method("navigate_to"):
			main_node.navigate_to("settings")
	)
	add_child(set_btn)
	
	# Status message at top (matches 12-avatar-care.png)
	status_label = Label.new()
	status_label.text = "Scrub the sugar spots to make your avatar happy!"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	UIHelper.apply_bubbly_label(status_label, 13, Color(0.18, 0.40, 0.68), true)
	add_child(status_label)
	
	# Tooth Avatar in Center
	tooth_box = Control.new()
	tooth_box.size = Vector2(250, 270)
	add_child(tooth_box)
	
	tooth_rect = TextureRect.new()
	tooth_rect.anchors_preset = Control.PRESET_FULL_RECT
	var dirty_tex = UIHelper.load_texture_safe("res://assets/images/cleanmolar/sad_tooth_character.png")
	if not dirty_tex:
		dirty_tex = UIHelper.load_texture_safe("res://assets/images/misc/sad_tooth_character.png")
	tooth_rect.texture = dirty_tex if dirty_tex else UIHelper.get_char_texture("chip", false)
	tooth_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tooth_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tooth_box.add_child(tooth_rect)
	
	toothbrush_tool = TextureRect.new()
	toothbrush_tool.texture = UIHelper.load_texture_safe("res://assets/images/cleanmolar/toothbrush_icon.png")
	if not toothbrush_tool.texture:
		toothbrush_tool.texture = UIHelper.load_texture_safe("res://assets/images/misc/toothbrush_icon.png")
	toothbrush_tool.custom_minimum_size = Vector2(56, 56)
	toothbrush_tool.size = Vector2(56, 56)
	toothbrush_tool.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	toothbrush_tool.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	toothbrush_tool.position = Vector2(175, 40)
	tooth_box.add_child(toothbrush_tool)

func _relayout():
	var safe_sz = UIHelper.get_viewport_safe_size(self)
	var cur_w = safe_sz.x
	var cur_h = safe_sz.y
	
	if bg:
		bg.size = safe_sz
	
	if back_btn:
		back_btn.position = Vector2(16, 16)
	if set_btn:
		set_btn.position = Vector2(cur_w - 54, 15)
	if status_label:
		var lbl_x = 110.0
		var lbl_w = max(180.0, cur_w - 170.0)
		status_label.position = Vector2(lbl_x, 14)
		status_label.size = Vector2(lbl_w, 40)
	if tooth_box:
		var box_w = 250.0
		var box_h = 270.0
		tooth_box.size = Vector2(box_w, box_h)
		tooth_box.position = Vector2((cur_w - box_w) * 0.5, 120)

func _spawn_cavity_spots():
	cleaned_count = 0
	is_cleaned = false
	for c in cavities:
		if is_instance_valid(c):
			c.queue_free()
	cavities.clear()
	
	var positions = [
		Vector2(65, 85),
		Vector2(160, 95),
		Vector2(95, 175),
		Vector2(150, 165)
	]
	
	for pos in positions:
		var spot = Panel.new()
		spot.position = pos
		spot.size = Vector2(26, 26)
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.85, 0.45, 0.15, 0.9)
		style.corner_radius_top_left = 13
		style.corner_radius_top_right = 13
		style.corner_radius_bottom_left = 13
		style.corner_radius_bottom_right = 13
		spot.add_theme_stylebox_override("panel", style)
		
		tooth_box.add_child(spot)
		cavities.append(spot)

func _gui_input(event: InputEvent):
	if is_cleaned:
		return
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		is_dragging_tool = event.pressed
		if is_dragging_tool:
			var local_pos = tooth_box.get_local_mouse_position()
			toothbrush_tool.position = local_pos - Vector2(28, 28)
			_check_scrub(local_pos)
	elif event is InputEventMouseMotion and is_dragging_tool:
		var local_pos = tooth_box.get_local_mouse_position()
		toothbrush_tool.position = local_pos - Vector2(28, 28)
		_check_scrub(local_pos)

func _check_scrub(pos: Vector2):
	for spot in cavities:
		if spot.visible:
			var rect = Rect2(spot.position, spot.size)
			if rect.grow(12.0).has_point(pos):
				spot.visible = false
				cleaned_count += 1
				AudioManager.play_sfx("pop")
				
				if cleaned_count >= total_cavities:
					_on_all_cleaned()

func _on_all_cleaned():
	is_cleaned = true
	AudioManager.play_sfx("cheer")
	status_label.text = "All clean! Your avatar is happy again."
	
	# Switch to happy clean avatar
	var p = GameState.get_active_profile()
	var char_id = p.get("avatar", "chip") if not p.is_empty() else "chip"
	tooth_rect.texture = UIHelper.get_char_texture(char_id, false)
	toothbrush_tool.visible = false
	
	# Happy cartoon bopping
	var tw = tooth_rect.create_tween().set_loops(4)
	tw.tween_property(tooth_rect, "position:y", -18.0, 0.22).set_trans(Tween.TRANS_SINE)
	tw.tween_property(tooth_rect, "position:y", 0.0, 0.22).set_trans(Tween.TRANS_SINE)
	
	p["points"] = int(round(float(p.get("points", 0)))) + 20
	GameState.save_data()
	GameState.push_toast("All Clean!", "+20 Points for keeping your avatar sparkly!", "", "green")
