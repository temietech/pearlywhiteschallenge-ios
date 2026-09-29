# scripts/character_select_screen.gd
extends Control

signal character_selected
signal back_pressed

static var _cached_choose_avatar_title_tex: Texture2D = null

static func _ensure_choose_avatar_title_texture() -> Texture2D:
	if _cached_choose_avatar_title_tex and is_instance_valid(_cached_choose_avatar_title_tex):
		return _cached_choose_avatar_title_tex
		
	var direct_tex = UIHelper.load_texture_safe("res://assets/images/titles/chooseavatar_title.png")
	if not direct_tex:
		direct_tex = UIHelper.load_texture_safe("res://assets/images/titles/chooseavatar_title.png")
	if direct_tex:
		_cached_choose_avatar_title_tex = direct_tex
		return _cached_choose_avatar_title_tex
		
	var path = "res://assets/images/general/choose_avatar_title.png"
	var global_path = ProjectSettings.globalize_path(path)
	
	if FileAccess.file_exists(global_path):
		var img = Image.load_from_file(global_path)
		if img and not img.is_empty():
			_cached_choose_avatar_title_tex = ImageTexture.create_from_image(img)
			return _cached_choose_avatar_title_tex
			
	var screen_tex = UIHelper.load_texture_safe("res://screens/22-character-select.png")
	if screen_tex:
		var full_img = screen_tex.get_image()
		if full_img and not full_img.is_empty():
			var iw = full_img.get_width()
			var ih = full_img.get_height()
			
			var rx = int(iw * 0.18)
			var ry = int(ih * 0.052)
			var rw = int(iw * 0.64)
			var rh = int(ih * 0.060)
			
			var cropped = full_img.get_region(Rect2i(rx, ry, rw, rh))
			if cropped and not cropped.is_empty():
				cropped.convert(Image.FORMAT_RGBA8)
				var w = cropped.get_width()
				var h = cropped.get_height()
				
				# Remove the outer sky blue background cleanly
				var visited = PackedByteArray()
				visited.resize(w * h)
				visited.fill(0)
				
				var queue: Array[Vector2i] = []
				for x in range(w):
					queue.append(Vector2i(x, 0))
					queue.append(Vector2i(x, h - 1))
					visited[x] = 1
					visited[(h - 1) * w + x] = 1
				for y in range(h):
					if visited[y * w] == 0:
						queue.append(Vector2i(0, y))
						visited[y * w] = 1
					if visited[y * w + (w - 1)] == 0:
						queue.append(Vector2i(w - 1, y))
						visited[y * w + (w - 1)] = 1
						
				var head = 0
				while head < queue.size():
					var p = queue[head]
					head += 1
					var col = cropped.get_pixel(p.x, p.y)
					# Outline has dark blue, text has white/cyan.
					# Sky blue background in 22-character-select is:
					# r between 0.38 and 0.80, g between 0.62 and 0.94, b > 0.80
					var is_sky_bg = (col.b > 0.80 and col.g > 0.60 and col.r > 0.35 and col.r < 0.82)
					if not is_sky_bg:
						continue
					cropped.set_pixel(p.x, p.y, Color(0, 0, 0, 0))
					var n_offsets = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
					for off in n_offsets:
						var nx = p.x + off.x
						var ny = p.y + off.y
						if nx >= 0 and nx < w and ny >= 0 and ny < h:
							var idx = ny * w + nx
							if visited[idx] == 0:
								visited[idx] = 1
								queue.append(Vector2i(nx, ny))
								
				var used = cropped.get_used_rect()
				if used.size.x > 10 and used.size.y > 10:
					cropped = cropped.get_region(used)
					
				cropped.save_png(global_path)
				_cached_choose_avatar_title_tex = ImageTexture.create_from_image(cropped)
				return _cached_choose_avatar_title_tex
	return null

var bg_rect: TextureRect
var back_btn: TextureButton
var title_rect: TextureRect
var title_lbl: Label
var grid_container: GridContainer
var action_btn: TextureButton
var bubble_decorations: Array[TextureRect] = []

var selected_char_id: String = "chip"
var card_widgets: Dictionary = {}

const CHARACTERS = [
	{"id": "chip", "name": "Chip", "role": "STUDENT"},
	{"id": "flora", "name": "Flora", "role": "BOTANIST"},
	{"id": "dash", "name": "Dash", "role": "ATHLETE"},
	{"id": "blaze", "name": "Blaze", "role": "SECRET AGENT"},
	{"id": "ash", "name": "Ash", "role": "ARTIST & MUSICIAN"},
	{"id": "penelope", "name": "Penelope", "role": "FASHION DESIGNER"},
	{"id": "nibbles", "name": "Chef Nibbles", "role": "CHEF"},
	{"id": "spark", "name": "Spark", "role": "SCIENTIST"},
	{"id": "sparkette", "name": "Sparkette", "role": "ENGINEER"}
]

func _ready():
	anchors_preset = Control.PRESET_FULL_RECT
	anchor_right = 1.0
	anchor_bottom = 1.0
	
	var p = GameState.get_active_profile()
	if not p.is_empty():
		selected_char_id = p.get("avatar", "chip")
		
	_build_ui()
	_render_grid()
	_relayout()
	
	if GameState.has_signal("stats_updated"):
		GameState.stats_updated.connect(func(_p): _render_grid())
	if GameState.has_signal("profile_changed"):
		GameState.profile_changed.connect(func(_p): _render_grid())

func _notification(what):
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_relayout()

func _build_ui():
	# Background (clean sky gradient with ambient rising bubbles)
	bg_rect = TextureRect.new()
	UIHelper.setup_fullscreen_bg(bg_rect)
	bg_rect.texture = UIHelper.create_sky_gradient_texture()
	bg_rect.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(bg_rect)
	
	# Translucent decorative floating bubbles matching mockup
	var bubble_tex = UIHelper.load_texture_safe("res://assets/images/misc/transparent_bubble.png")
	if not bubble_tex:
		bubble_tex = UIHelper.load_texture_safe("res://assets/images/misc/colorful_bubble.png")
	if bubble_tex:
		var bubble_data = [
			{"pos": Vector2(0.82, 0.06), "size": 90.0, "alpha": 0.45},
			{"pos": Vector2(0.46, 0.12), "size": 65.0, "alpha": 0.35},
			{"pos": Vector2(0.18, 0.38), "size": 80.0, "alpha": 0.30},
			{"pos": Vector2(0.28, 0.70), "size": 60.0, "alpha": 0.28},
			{"pos": Vector2(0.75, 0.73), "size": 48.0, "alpha": 0.32},
			{"pos": Vector2(0.32, 0.92), "size": 26.0, "alpha": 0.25}
		]
		for b in bubble_data:
			var b_rect = TextureRect.new()
			b_rect.texture = bubble_tex
			b_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			b_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			b_rect.modulate = Color(1, 1, 1, b["alpha"])
			b_rect.set_meta("rel_pos", b["pos"])
			b_rect.set_meta("base_size", b["size"])
			add_child(b_rect)
			bubble_decorations.append(b_rect)
	
	# Back Button (Top Left)
	back_btn = UIHelper.create_image_button("res://assets/images/shop/blue_back_button.png", Vector2(100, 42))
	if not back_btn.texture_normal:
		back_btn = UIHelper.create_image_button("res://assets/images/misc/blue_back_button.png", Vector2(100, 42))
	back_btn.pressed.connect(func():
		AudioManager.play_sfx("click")
		var main_node = get_tree().root.get_node_or_null("Main")
		if main_node and main_node.has_method("navigate_to"):
			main_node.navigate_to("profile")
		else:
			back_pressed.emit()
	)
	add_child(back_btn)
	
	# 3D Title Image: "Choose Avatar" (matching screens/22-character-select.png)
	title_rect = TextureRect.new()
	title_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	title_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t_tex = _ensure_choose_avatar_title_texture()
	if t_tex:
		title_rect.texture = t_tex
		title_rect.visible = true
	add_child(title_rect)
	
	# Title Fallback Label
	title_lbl = Label.new()
	title_lbl.text = "CHOOSE AVATAR"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(title_lbl, 32, Color.WHITE, true)
	title_lbl.add_theme_color_override("font_shadow_color", Color(0.12, 0.38, 0.68, 0.8))
	title_lbl.add_theme_constant_override("shadow_offset_x", 0)
	title_lbl.add_theme_constant_override("shadow_offset_y", 3)
	title_lbl.add_theme_color_override("font_outline_color", Color(0.15, 0.45, 0.75))
	title_lbl.add_theme_constant_override("outline_size", 3)
	title_lbl.visible = (t_tex == null)
	add_child(title_lbl)
	
	# 3x3 Grid
	grid_container = GridContainer.new()
	grid_container.columns = 3
	add_child(grid_container)
	
	# Bottom Large Blue Glossy "KEEP" / Green "SELECT" Button
	action_btn = UIHelper.create_themed_button("keep", Vector2(210, 76))
	if not action_btn.texture_normal:
		action_btn = UIHelper.create_image_button("res://assets/images/general/keep_button.png", Vector2(210, 76))
	action_btn.pressed.connect(_on_keep_pressed)
	add_child(action_btn)

func _relayout():
	var safe_sz = UIHelper.get_viewport_safe_size(self)
	var w = safe_sz.x
	var h = safe_sz.y
	var is_tablet = w >= 600
	
	if bg_rect:
		bg_rect.size = safe_sz
	
	# Position back button
	if back_btn:
		back_btn.position = Vector2(16, 20)
		back_btn.size = Vector2(96, 40) if not is_tablet else Vector2(115, 48)
		
	# Position Title
	var title_y = 52.0 if not is_tablet else 65.0
	var title_h = 46.0 if not is_tablet else 60.0
	var title_w = min(w * 0.72, 300.0) if not is_tablet else 400.0
	if title_rect and title_rect.visible:
		title_rect.position = Vector2((w - title_w) * 0.5, title_y)
		title_rect.size = Vector2(title_w, title_h)
	if title_lbl and title_lbl.visible:
		title_lbl.position = Vector2(0, title_y)
		title_lbl.size = Vector2(w, title_h)
		var f_size = 30 if not is_tablet else 40
		title_lbl.add_theme_font_size_override("font_size", f_size)
		
	# Floating background bubbles
	for b_rect in bubble_decorations:
		var rel_pos = b_rect.get_meta("rel_pos", Vector2.ZERO)
		var b_size = b_rect.get_meta("base_size", 60.0)
		if is_tablet:
			b_size *= 1.3
		b_rect.size = Vector2(b_size, b_size)
		b_rect.position = Vector2(w * rel_pos.x - b_size * 0.5, h * rel_pos.y - b_size * 0.5)
		
	# Grid Layout
	if grid_container:
		var card_dim = 114.0 if not is_tablet else 140.0
		var h_sep = 14.0 if not is_tablet else 24.0
		var v_sep = 12.0 if not is_tablet else 20.0
		
		# Ensure grid fits screen width
		var max_grid_w = w - 32.0
		if (card_dim * 3.0 + h_sep * 2.0) > max_grid_w:
			card_dim = floor((max_grid_w - h_sep * 2.0) / 3.0)
			
		grid_container.add_theme_constant_override("h_separation", int(h_sep))
		grid_container.add_theme_constant_override("v_separation", int(v_sep))
		
		var grid_total_w = card_dim * 3.0 + h_sep * 2.0
		# Each item has card_dim height + role label height (~20px) + separation
		var grid_total_h = (card_dim + 24.0) * 3.0 + v_sep * 2.0
		
		var grid_x = (w - grid_total_w) * 0.5
		var grid_y = 118.0 if not is_tablet else 150.0
		grid_container.position = Vector2(grid_x, grid_y)
		grid_container.size = Vector2(grid_total_w, grid_total_h)
		
		# Update sizes of cards
		for c_id in card_widgets:
			var card_root = card_widgets[c_id]
			if is_instance_valid(card_root):
				card_root.custom_minimum_size = Vector2(card_dim, card_dim + 24.0)
				var card_panel = card_root.get_node_or_null("CardPanel")
				if card_panel:
					card_panel.custom_minimum_size = Vector2(card_dim, card_dim)
					card_panel.size = Vector2(card_dim, card_dim)
					var lock_img = card_panel.get_node_or_null("LockIcon")
					if lock_img:
						var lock_dim = clampf(card_dim * 0.22, 20.0, 30.0)
						lock_img.custom_minimum_size = Vector2(lock_dim, lock_dim * 1.25)
						lock_img.size = Vector2(lock_dim, lock_dim * 1.25)
						lock_img.position = Vector2(card_dim - lock_dim - 6.0, 6.0)
				
	# Action Button (KEEP / SELECT)
	if action_btn:
		var btn_w = min(220.0, w - 36.0) if not is_tablet else min(280.0, w - 60.0)
		var btn_h = btn_w * (76.0 / 210.0)
		action_btn.custom_minimum_size = Vector2(btn_w, btn_h)
		action_btn.size = Vector2(btn_w, btn_h)
		var btn_x = (w - btn_w) * 0.5
		var btn_y = h - btn_h - (36.0 if not is_tablet else 54.0)
		
		# Ensure action button does not overlap grid on smaller screens
		if grid_container and (grid_container.position.y + grid_container.size.y + 16.0) > btn_y:
			btn_y = grid_container.position.y + grid_container.size.y + 16.0
			
		action_btn.position = Vector2(btn_x, btn_y)

func _render_grid():
	var p = GameState.get_active_profile()
	if not p.is_empty():
		GameState.check_character_unlocks(p, false)
	var current_avatar = p.get("avatar", "chip") if not p.is_empty() else "chip"
	if selected_char_id == "":
		selected_char_id = current_avatar
	var unlocked = p.get("unlockedCharacters", ["chip", "flora"]) if not p.is_empty() else ["chip", "flora"]
	
	_update_action_button(current_avatar)
	
	for c in grid_container.get_children():
		grid_container.remove_child(c)
		c.queue_free()
	card_widgets.clear()
	
	var safe_sz = UIHelper.get_viewport_safe_size(self)
	var is_tablet = safe_sz.x >= 600
	var card_dim = 114.0 if not is_tablet else 140.0
	var h_sep = 14.0 if not is_tablet else 24.0
	var max_grid_w = safe_sz.x - 32.0
	if (card_dim * 3.0 + h_sep * 2.0) > max_grid_w:
		card_dim = floor((max_grid_w - h_sep * 2.0) / 3.0)
	
	for char_def in CHARACTERS:
		var c_id = char_def["id"]
		var is_unlocked = unlocked.has(c_id)
		var is_selected = (selected_char_id == c_id)
		
		var card = _create_char_card(char_def, is_unlocked, is_selected, card_dim)
		card_widgets[c_id] = card
		grid_container.add_child(card)
		
	_relayout()

func _update_action_button(current_avatar: String):
	if not action_btn:
		return
	var tex: Texture2D
	if selected_char_id == current_avatar:
		tex = UIHelper.get_button_texture("keep")
		if not tex:
			tex = UIHelper.load_texture_safe("res://assets/images/general/keep_button.png")
	else:
		tex = UIHelper.get_button_texture("select")
		if not tex:
			tex = UIHelper.load_texture_safe("res://assets/images/general/select_button.png")
	if tex:
		action_btn.texture_normal = tex

func _select_character(new_id: String):
	if selected_char_id == new_id:
		return
	var old_id = selected_char_id
	selected_char_id = new_id
	
	# Update old selected card visually in place
	if card_widgets.has(old_id):
		var old_card = card_widgets[old_id]
		if is_instance_valid(old_card):
			var tw = old_card.create_tween()
			tw.tween_property(old_card, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
					
	# Update new selected card visually in place
	if card_widgets.has(new_id):
		var new_card = card_widgets[new_id]
		if is_instance_valid(new_card):
			var tw = new_card.create_tween()
			tw.tween_property(new_card, "scale", Vector2(1.06, 1.06), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
					
	var p = GameState.get_active_profile()
	var current_avatar = p.get("avatar", "chip") if not p.is_empty() else "chip"
	_update_action_button(current_avatar)

func _create_char_card(char_def: Dictionary, is_unlocked: bool, is_selected: bool, card_dim: float) -> Control:
	var c_id = char_def["id"]
	var root_vbox = VBoxContainer.new()
	root_vbox.name = "RootVBox_" + c_id
	root_vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	root_vbox.add_theme_constant_override("separation", 5)
	root_vbox.custom_minimum_size = Vector2(card_dim, card_dim + 24.0)
	root_vbox.pivot_offset = Vector2(card_dim * 0.5, (card_dim + 24.0) * 0.5)
	root_vbox.scale = Vector2(1.06, 1.06) if is_selected else Vector2.ONE
	
	# Card Panel / Frame
	var card_panel = Control.new()
	card_panel.name = "CardPanel"
	card_panel.custom_minimum_size = Vector2(card_dim, card_dim)
	card_panel.size = Vector2(card_dim, card_dim)
	card_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Character Card Texture (using the high-quality rendered card art from sorted_assets/characters/[id]-bg.png)
	var card_img = TextureRect.new()
	card_img.name = "CardImg"
	card_img.set_anchors_preset(Control.PRESET_FULL_RECT)
	card_img.anchor_right = 1.0
	card_img.anchor_bottom = 1.0
	card_img.texture = UIHelper.get_char_texture(c_id, true)
	card_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	card_img.modulate = Color.WHITE
	
	if not is_unlocked:
		card_img.material = UIHelper.get_grayscale_material()
	else:
		card_img.material = null
		
	card_panel.add_child(card_img)
	
	if not is_unlocked:
		var lock_dim = clampf(card_dim * 0.22, 20.0, 30.0)
		var lock_img = UIHelper.create_texture_rect("res://assets/images/scrapbook/metal_lock_icon.png", Vector2(lock_dim, lock_dim * 1.25))
		if not lock_img.texture:
			lock_img = UIHelper.create_texture_rect("res://assets/images/misc/metal_lock_icon.png", Vector2(lock_dim, lock_dim * 1.25))
		lock_img.name = "LockIcon"
		lock_img.position = Vector2(card_dim - lock_dim - 6.0, 6.0)
		lock_img.size = Vector2(lock_dim, lock_dim * 1.25)
		lock_img.custom_minimum_size = Vector2(lock_dim, lock_dim * 1.25)
		lock_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lock_img.z_index = 5
		card_panel.add_child(lock_img)
	
	# Interactive click button
	var click_btn = Button.new()
	click_btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	click_btn.flat = true
	click_btn.pressed.connect(func():
		if is_unlocked:
			AudioManager.play_character_voice(c_id)
			_select_character(c_id)
		else:
			UIHelper.show_character_unlock_modal(self, char_def, false, func():
				_select_character(c_id)
				_render_grid()
			)
	)
	card_panel.add_child(click_btn)
	root_vbox.add_child(card_panel)
	
	# Role label underneath card in uppercase blue
	var role_lbl = Label.new()
	role_lbl.text = char_def["role"]
	role_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var lbl_col = Color(0.18, 0.42, 0.68) if is_unlocked else Color(0.50, 0.58, 0.68)
	UIHelper.apply_bubbly_label(role_lbl, 10, lbl_col, true)
	role_lbl.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0.6))
	role_lbl.add_theme_constant_override("shadow_offset_x", 0)
	role_lbl.add_theme_constant_override("shadow_offset_y", 1)
	root_vbox.add_child(role_lbl)
	
	return root_vbox

func _on_keep_pressed():
	var p = GameState.get_active_profile()
	if not p.is_empty():
		GameState.rename_profile(p["id"], p.get("name", "Player"), selected_char_id, p.get("age", 8))
		GameState.save_game()
		AudioManager.play_sfx("cheer")
		
	var main_node = get_tree().root.get_node_or_null("Main")
	if main_node and main_node.has_method("navigate_to"):
		main_node.navigate_to("profile")
	else:
		character_selected.emit()


