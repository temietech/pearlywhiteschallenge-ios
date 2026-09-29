# scripts/map_screen.gd
extends Control

signal launch_node(day: int, node_type: String)
signal launch_minigame(game_name: String)

var scroll_container: ScrollContainer
var nodes_container: Control
var map_bg_tex: TextureRect
var map_height: float = 3800.0
var grayscale_mat: ShaderMaterial

func _get_grayscale_material() -> ShaderMaterial:
	if grayscale_mat:
		return grayscale_mat
	var sh = Shader.new()
	sh.code = """
shader_type canvas_item;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float gray = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(vec3(clamp(gray * 1.15 + 0.08, 0.0, 1.0)), c.a);
}
"""
	grayscale_mat = ShaderMaterial.new()
	grayscale_mat.shader = sh
	return grayscale_mat

const BOSS_DAYS = [1, 9, 19, 28]

const PATH_COORDINATES = [
	Vector2(56.0, 96.5), # Node 0 (Intro Node)
	Vector2(62.5, 95.0), # Day 1 AM
	Vector2(27.4, 93.2), # Day 1 PM
	Vector2(31.3, 93.7), # Day 2 AM
	Vector2(73.5, 94.6), # Day 2 PM
	Vector2(81.0, 92.9), # minigame
	Vector2(39.9, 91.5), # Day 3 AM
	Vector2(43.8, 89.9), # Day 3 PM
	Vector2(76.6, 88.5), # Day 4 AM
	Vector2(44.5, 86.7), # Day 4 PM
	Vector2(51.1, 85.2), # Day 5 AM
	Vector2(78.8, 83.8), # Day 5 PM
	Vector2(75.0, 82.1), # minigame
	Vector2(28.9, 81.2), # Day 6 AM
	Vector2(64.9, 78.2), # Day 6 PM
	Vector2(43.0, 75.5), # Day 7 AM
	Vector2(59.9, 72.7), # Day 7 PM
	Vector2(22.8, 70.7), # quiz
	Vector2(71.1, 70.0), # Day 8 AM
	Vector2(50.8, 67.2), # Day 8 PM
	Vector2(76.9, 63.5), # minigame
	Vector2(51.0, 60.8), # Day 9 AM
	Vector2(45.8, 56.7), # Day 9 PM
	Vector2(77.4, 54.7), # Day 10 AM
	Vector2(54.0, 52.3), # Day 10 PM
	Vector2(46.6, 50.1), # Day 11 AM
	Vector2(61.1, 48.3), # Day 11 PM
	Vector2(52.6, 47.2), # Day 12 AM
	Vector2(29.9, 46.4), # Day 12 PM
	Vector2(21.0, 45.3), # Day 13 AM
	Vector2(31.6, 44.0), # Day 13 PM
	Vector2(52.9, 44.8), # minigame
	Vector2(80.3, 44.7), # Day 14 AM
	Vector2(80.6, 43.2), # Day 14 PM
	Vector2(70.5, 42.6), # quiz
	Vector2(46.3, 42.2), # Day 15 AM
	Vector2(42.6, 40.4), # Day 15 PM
	Vector2(66.0, 39.8), # Day 16 AM
	Vector2(75.6, 38.5), # Day 16 PM
	Vector2(54.9, 37.5), # minigame
	Vector2(45.3, 36.3), # Day 17 AM
	Vector2(67.3, 35.4), # Day 17 PM
	Vector2(77.7, 34.2), # Day 18 AM
	Vector2(72.0, 32.8), # Day 18 PM
	Vector2(30.5, 31.3), # Day 19 AM
	Vector2(36.4, 30.1), # Day 19 PM
	Vector2(58.8, 29.5), # Day 20 AM
	Vector2(69.3, 28.4), # Day 20 PM
	Vector2(56.1, 27.4), # minigame
	Vector2(42.3, 26.5), # Day 21 AM
	Vector2(52.7, 25.0), # Day 21 PM
	Vector2(61.2, 23.7), # quiz
	Vector2(47.6, 22.5), # Day 22 AM
	Vector2(28.7, 21.7), # Day 22 PM
	Vector2(25.7, 20.4), # Day 23 AM
	Vector2(41.2, 19.5), # Day 23 PM
	Vector2(64.8, 19.4), # Day 24 AM
	Vector2(43.9, 17.2), # Day 24 PM
	Vector2(62.5, 15.8), # minigame
	Vector2(44.9, 13.9), # Day 25 AM
	Vector2(67.5, 13.3), # Day 25 PM
	Vector2(75.0, 11.9), # Day 26 AM
	Vector2(55.4, 11.1), # Day 26 PM
	Vector2(44.9, 9.8), # Day 27 AM
	Vector2(62.5, 8.9), # Day 27 PM
	Vector2(69.3, 7.9), # minigame
	Vector2(48.3, 6.9), # Day 28 AM
	Vector2(37.1, 5.9), # Day 28 PM
	Vector2(46.2, 4.5), # quiz
	Vector2(52.0, 2.8)  # FINISH
]

var map_nodes_data: Array[Dictionary] = []

func _ready():
	anchors_preset = Control.PRESET_FULL_RECT
	anchor_right = 1.0
	anchor_bottom = 1.0
	
	# 1. Load local source of truth from user://challenge_data.json and populate GameState
	_load_local_challenge_state()
	
	_init_node_data()
	_build_ui()
	GameState.stats_updated.connect(_on_stats_updated)
	call_deferred("_check_main_screen_popups")
	
	# 2. Quietly upload any progress made while offline
	FirebaseManager.check_and_sync_pending_data()

func _load_local_challenge_state():
	if FileAccess.file_exists("user://challenge_data.json"):
		var file = FileAccess.open("user://challenge_data.json", FileAccess.READ)
		if file:
			var json = JSON.parse_string(file.get_as_text())
			file.close()
			if json is Dictionary and json.has("game_progress"):
				var progress = json["game_progress"]
				var file_user_id = str(json.get("user_id", ""))
				if progress is Dictionary and not progress.is_empty():
					GameState.populate_from_progress_dict(progress, file_user_id)

func _check_main_screen_popups():
	var p = GameState.get_active_profile()
	if not p.is_empty() and not p.get("tutorial_done", false):
		# Tutorial is active on cold start/first run, defer popups until tutorial completes
		var main_node = get_tree().root.get_node_or_null("Main")
		if main_node and "tutorial_overlay" in main_node and is_instance_valid(main_node.tutorial_overlay):
			var tut = main_node.tutorial_overlay
			if tut.has_signal("tutorial_finished"):
				tut.tutorial_finished.connect(func():
					_check_main_screen_popups()
				, CONNECT_ONE_SHOT)
				return

	var shown_stamp = _check_and_show_daily_stamp_calendar(func():
		_check_weapon_unlocks()
	)
	if not shown_stamp:
		_check_weapon_unlocks()

func _check_weapon_unlocks():
	var p = GameState.get_active_profile()
	if p.is_empty():
		return
		
	var max_allowed_unlock_day = GameState.get_unlocked_day(p)
	
	var seen_unlocks = p.get("seen_weapon_unlocks", ["brush", "brush_1"])
	if typeof(seen_unlocks) != TYPE_ARRAY:
		seen_unlocks = ["brush", "brush_1"]
	else:
		seen_unlocks = seen_unlocks.duplicate()
		
	var weapon_defs = [
		{"id": "brush_1", "weapon_id": "brush", "name": "TOOTHBRUSH", "full_name": "Brush Boomerang", "unlock_day": 1, "tier": 1, "images": ["res://assets/images/shop/brushweapon_1.png"]},
		{"id": "paste_1", "weapon_id": "paste", "name": "TOOTHPASTE", "full_name": "Paste Pistol", "unlock_day": 2, "tier": 1, "images": ["res://assets/images/shop/Lvl1Paste.png"]},
		{"id": "brush_2", "weapon_id": "brush", "name": "TOOTHBRUSH", "full_name": "Gold Brush", "unlock_day": 3, "tier": 2, "images": ["res://assets/images/shop/brushweapon_2.png"]},
		{"id": "floss_1", "weapon_id": "floss", "name": "FLOSS", "full_name": "Floss Lasso", "unlock_day": 5, "tier": 1, "images": ["res://assets/images/shop/flossweapon_1.png"]},
		{"id": "wash_1", "weapon_id": "wash", "name": "MOUTHWASH", "full_name": "Mouthwash Blast", "unlock_day": 7, "tier": 1, "images": ["res://assets/images/shop/MouthwashBlast-1.png"]},
		{"id": "paste_2", "weapon_id": "paste", "name": "TOOTHPASTE", "full_name": "Gold Paste Pistol", "unlock_day": 9, "tier": 2, "images": ["res://assets/images/shop/PasteGold2.png"]},
		{"id": "brush_3", "weapon_id": "brush", "name": "TOOTHBRUSH", "full_name": "Bubble Brush", "unlock_day": 11, "tier": 3, "images": ["res://assets/images/shop/BubbleBrush.png"]},
		{"id": "floss_2", "weapon_id": "floss", "name": "FLOSS", "full_name": "Gold Floss Lasso", "unlock_day": 13, "tier": 2, "images": ["res://assets/images/shop/flossweapon_2.png"]},
		{"id": "paste_3", "weapon_id": "paste", "name": "TOOTHPASTE", "full_name": "Bubble Paste", "unlock_day": 15, "tier": 3, "images": ["res://assets/images/shop/BubblePaste.png"]},
		{"id": "wash_2", "weapon_id": "wash", "name": "MOUTHWASH", "full_name": "Gold Mouthwash Blast", "unlock_day": 17, "tier": 2, "images": ["res://assets/images/shop/WashGold2.png"]},
		{"id": "floss_3", "weapon_id": "floss", "name": "FLOSS", "full_name": "Bubble Floss", "unlock_day": 19, "tier": 3, "images": ["res://assets/images/shop/flossweapon_3.png"]},
		{"id": "wash_3", "weapon_id": "wash", "name": "MOUTHWASH", "full_name": "Bubble Wash", "unlock_day": 21, "tier": 3, "images": ["res://assets/images/shop/BubbleWash.png"]}
	]
	
	# Show celebration for the earliest unviewed unlock available up to current completed day
	var weapon_to_show = {}
	for w_def in weapon_defs:
		var w_id = w_def["id"]
		var unlock_day = int(w_def.get("unlock_day", 1))
		if max_allowed_unlock_day >= unlock_day and not seen_unlocks.has(w_id):
			seen_unlocks.append(w_id)
			weapon_to_show = w_def
			break
			
	p["seen_weapon_unlocks"] = seen_unlocks
	GameState.save_game()
			
	if not weapon_to_show.is_empty():
		GameState.push_toast("Weapon Unlocked!", "%s is now ready in the shop!" % weapon_to_show.get("full_name", "New Weapon"), "", "purple", "wep_unlocked_" + str(weapon_to_show.get("id", "")))
		UIHelper.show_dental_item_unlocked_modal(self, weapon_to_show, func():
			# Re-check in case multiple weapon unlocks are queued
			_check_weapon_unlocks()
		)
	else:
		_check_story_unlocks()


func _check_story_unlocks():
	var p = GameState.get_active_profile()
	if p.is_empty():
		return
	
	var seen_story = p.get("seen_story_unlocks", [])
	if typeof(seen_story) != TYPE_ARRAY:
		seen_story = []
	else:
		seen_story = seen_story.duplicate()
		
	var modified = false
	var story_to_show = 0
	
	for d in range(1, 29):
		if GameState.is_day_story_unlocked(d, p):
			if not seen_story.has(d):
				seen_story.append(d)
				story_to_show = d
				modified = true
				break
				
	if modified:
		p["seen_story_unlocks"] = seen_story
		GameState.save_game()
		
	if story_to_show > 0:
		UIHelper.show_story_panel_modal(self, story_to_show, func():
			_check_story_unlocks()
		)

func _init_node_data():
	map_nodes_data.clear()
	map_nodes_data.append({"id": 0, "day": 0, "type": "intro"})
	var node_id = 1
	var minigame_days = [2, 5, 8, 13, 16, 20, 24, 27]
	var quiz_days = [7, 14, 21, 28]
	for day in range(1, 29):
		map_nodes_data.append({"id": node_id, "day": day, "type": "morning"})
		node_id += 1
		map_nodes_data.append({"id": node_id, "day": day, "type": "evening"})
		node_id += 1
		if minigame_days.has(day):
			map_nodes_data.append({"id": node_id, "day": day, "type": "minigame"})
			node_id += 1
		if quiz_days.has(day):
			map_nodes_data.append({"id": node_id, "day": day, "type": "quiz"})
			node_id += 1
	map_nodes_data.append({"id": node_id, "day": 28, "type": "finish"})

func _build_ui():
	scroll_container = ScrollContainer.new()
	scroll_container.anchors_preset = Control.PRESET_FULL_RECT
	scroll_container.anchor_right = 1.0
	scroll_container.anchor_bottom = 1.0
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll_container)
	
	var map_tex = UIHelper.load_texture_safe("res://assets/images/mainmap/Map.jpg")
	if not map_tex:
		map_tex = UIHelper.load_texture_safe("res://assets/images/misc/Map.jpg")
		
	var safe_sz = UIHelper.get_viewport_safe_size(self)
	var cur_w = safe_sz.x
	
	if map_tex:
		var tex_w = float(map_tex.get_width())
		var tex_h = float(map_tex.get_height())
		map_height = cur_w * (tex_h / max(1.0, tex_w))
	else:
		map_height = cur_w * 8.5
		
	var total_h = map_height
	
	nodes_container = Control.new()
	nodes_container.custom_minimum_size = Vector2(cur_w, total_h)
	nodes_container.size = Vector2(cur_w, total_h)
	scroll_container.add_child(nodes_container)
	
	map_bg_tex = TextureRect.new()
	map_bg_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map_bg_tex.stretch_mode = TextureRect.STRETCH_SCALE
	map_bg_tex.custom_minimum_size = Vector2(cur_w, map_height)
	map_bg_tex.size = Vector2(cur_w, map_height)
	map_bg_tex.position = Vector2.ZERO
	map_bg_tex.texture = map_tex
	nodes_container.add_child(map_bg_tex)
	

	_build_map_nodes()
	scroll_container.scroll_vertical = int(max(0.0, total_h - safe_sz.y))
	call_deferred("_scroll_to_current_node")

func _notification(what):
	if what == NOTIFICATION_RESIZED:
		if is_node_ready() and nodes_container:
			_update_map_layout()

func _update_map_layout():
	var safe_sz = UIHelper.get_viewport_safe_size(self)
	var cur_w = safe_sz.x
	
	if map_bg_tex and map_bg_tex.texture:
		var tex_w = float(map_bg_tex.texture.get_width())
		var tex_h = float(map_bg_tex.texture.get_height())
		map_height = cur_w * (tex_h / max(1.0, tex_w))
	else:
		map_height = cur_w * 8.5
		
	var total_h = map_height
	if nodes_container:
		nodes_container.custom_minimum_size = Vector2(cur_w, total_h)
		nodes_container.size = Vector2(cur_w, total_h)
	if map_bg_tex:
		map_bg_tex.custom_minimum_size = Vector2(cur_w, map_height)
		map_bg_tex.size = Vector2(cur_w, map_height)
		map_bg_tex.position = Vector2.ZERO
	_build_map_nodes()

func _build_map_nodes():
	var safe_sz = UIHelper.get_viewport_safe_size(self)
	var cur_w = safe_sz.x
	if nodes_container:
		nodes_container.custom_minimum_size.x = cur_w
		nodes_container.size.x = cur_w
	if map_bg_tex:
		map_bg_tex.custom_minimum_size.x = cur_w
		map_bg_tex.size.x = cur_w
		map_bg_tex.position.x = 0

	for c in nodes_container.get_children():
		if c != map_bg_tex:
			c.queue_free()
		
	var p = GameState.get_active_profile()
	var current_node = int(p.get("currentNode", 0))
	var active_avatar = p.get("avatar", "chip")
	
	var total_nodes = map_nodes_data.size()
	for i in range(total_nodes):
		var n_data = map_nodes_data[i]
		var n_id = n_data["id"]
		var n_day = n_data.get("day", 0)
		var n_type = n_data["type"]
		
		var coord = PATH_COORDINATES[i] if i < PATH_COORDINATES.size() else PATH_COORDINATES[PATH_COORDINATES.size() - 1]
		
		var node_x = (coord.x / 100.0) * cur_w
		var node_y = (coord.y / 100.0) * map_height
		
		var is_completed = (n_id < current_node)
		var is_active = (n_id == current_node)
		var is_locked = (n_id > current_node)
		var days_status = p.get("daysStatus", [])
		var is_missed = (n_day > 0 and days_status.size() >= n_day and days_status[n_day - 1] == "missed")
		
		var node_widget = _create_node_button(n_id, n_day, n_type, is_completed, is_active, is_locked, Vector2(node_x, node_y), active_avatar, is_missed)
		nodes_container.add_child(node_widget)

func _create_node_button(id: int, day: int, n_type: String, is_completed: bool, is_active: bool, is_locked: bool, pos: Vector2, avatar_id: String, is_missed: bool = false) -> Control:
	var container = Control.new()
	container.position = pos - Vector2(23, 16)
	container.custom_minimum_size = Vector2(46, 32)
	container.z_index = 2 if not is_active else 5
	if is_active:
		container.add_to_group("active_map_node")
	
	var node_stage = GameState.get_node_stage(id)
	var is_boss_day = BOSS_DAYS.has(day)
	
	var is_purple = false
	var is_yellow = false
	var is_blue = false
	
	if n_type == "intro":
		is_yellow = true # Start Node (Discovery Quiz)
	elif n_type == "morning":
		if node_stage == 0:
			is_blue = true # Morning brush
		else:
			is_yellow = true # Morning minigame is always yellow! Candy Crusade is always evening!
	elif n_type == "evening":
		if node_stage == 0:
			if is_boss_day:
				is_purple = true # Candy Crusade comes before brushing in evening
			else:
				is_yellow = true # Evening minigame
		else:
			is_blue = true # Evening brush
	elif n_type == "minigame":
		is_yellow = true # Standalone minigame
	elif n_type == "quiz" or n_type == "finish":
		is_yellow = true # Weekly Quiz / Finish
	else:
		is_blue = true
	
	var btn = TextureButton.new()
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_SCALE
	btn.custom_minimum_size = Vector2(46, 32)
	btn.size = Vector2(46, 32)
	btn.pivot_offset = Vector2(23, 16)
	
	var normal_tex: Texture2D
	var pressed_tex: Texture2D
	
	if is_completed:
		normal_tex = UIHelper.load_texture_safe("res://assets/images/mainmap/mapbuttonsup_green.png")
		pressed_tex = UIHelper.load_texture_safe("res://assets/images/mainmap/mapbuttonsdown_green.png")
	elif is_missed:
		normal_tex = UIHelper.load_texture_safe("res://assets/images/mainmap/mapbuttonsup_red.png")
		pressed_tex = UIHelper.load_texture_safe("res://assets/images/mainmap/mapbuttonsdown_red.png")
	elif is_purple:
		normal_tex = UIHelper.load_texture_safe("res://assets/images/mainmap/mapbuttonsup_purple.png")
		pressed_tex = UIHelper.load_texture_safe("res://assets/images/mainmap/mapbuttonsdown_purple.png")
	elif is_yellow:
		normal_tex = UIHelper.load_texture_safe("res://assets/images/mainmap/mapbuttonsup_yellow.png")
		pressed_tex = UIHelper.load_texture_safe("res://assets/images/mainmap/mapbuttonsdown_yellow.png")
	else:
		# Blue brushing nodes (morning brush / night brush after Candy Crusade).
		# Previously had no texture, so the node vanished from the map.
		normal_tex = UIHelper.load_texture_safe("res://assets/images/mainmap/mapbuttonsup_blue.png")
		pressed_tex = normal_tex
	if n_type == "intro":
		var start_t = UIHelper.load_texture_safe("res://assets/images/buttons/startgamebtn.png")
		if start_t:
			normal_tex = start_t
			pressed_tex = start_t
	elif n_type == "finish":
		var finish_t = UIHelper.load_texture_safe("res://assets/images/buttons/finishbtn.png")
		if finish_t:
			normal_tex = finish_t
			pressed_tex = finish_t

	btn.texture_normal = normal_tex
	btn.texture_pressed = pressed_tex
	btn.modulate = Color.WHITE
	
	if is_locked:
		btn.material = _get_grayscale_material()
	else:
		btn.material = null
		
	btn.scale = Vector2.ONE
		
	var finish_lbl: Label = null
	var day_lbl: Label = null
	
	if n_type == "intro":
		if not normal_tex or normal_tex == UIHelper.load_texture_safe("res://assets/images/mainmap/mapbuttonsup_blue.png"):
			day_lbl = Label.new()
			day_lbl.text = "START"
			day_lbl.position = Vector2(0, -4)
			day_lbl.size = Vector2(46, 32)
			day_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			day_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			day_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			day_lbl.add_theme_color_override("font_color", Color.WHITE)
			day_lbl.add_theme_font_size_override("font_size", 9 if not is_active else 10)
			day_lbl.add_theme_color_override("font_shadow_color", Color(0.1, 0.15, 0.25, 0.9))
			day_lbl.add_theme_constant_override("shadow_offset_x", 1)
			day_lbl.add_theme_constant_override("shadow_offset_y", 1)
	elif n_type == "quiz" or n_type == "minigame":
		pass
	elif n_type == "finish":
		if not UIHelper.get_button_texture("finish"):
			finish_lbl = Label.new()
			finish_lbl.text = "FINISH"
			finish_lbl.position = Vector2(0, -4)
			finish_lbl.size = Vector2(46, 32)
			finish_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			finish_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			finish_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			finish_lbl.add_theme_color_override("font_color", Color.WHITE)
			finish_lbl.add_theme_font_size_override("font_size", 9)
			finish_lbl.add_theme_color_override("font_shadow_color", Color(0.1, 0.15, 0.25, 0.9))
			finish_lbl.add_theme_constant_override("shadow_offset_x", 1)
			finish_lbl.add_theme_constant_override("shadow_offset_y", 1)
	else:
		day_lbl = Label.new()
		day_lbl.text = str(day)
		day_lbl.position = Vector2(0, -4)
		day_lbl.size = Vector2(46, 32)
		day_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		day_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		day_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		day_lbl.add_theme_color_override("font_color", Color.WHITE)
		day_lbl.add_theme_font_size_override("font_size", 14 if not is_active else 15)
		day_lbl.add_theme_color_override("font_shadow_color", Color(0.1, 0.15, 0.25, 0.9))
		day_lbl.add_theme_constant_override("shadow_offset_x", 1)
		day_lbl.add_theme_constant_override("shadow_offset_y", 1)
		
	container.add_child(btn)
	if finish_lbl:
		finish_lbl.z_index = 3
		container.add_child(finish_lbl)
	if day_lbl:
		day_lbl.z_index = 3
		container.add_child(day_lbl)
		
	if is_active:
		var mascot_root = Control.new()
		mascot_root.custom_minimum_size = Vector2(160, 140)
		mascot_root.size = Vector2(160, 140)
		mascot_root.position = Vector2((46.0 - 160.0) * 0.5, 0.0)
		mascot_root.z_index = 6
		mascot_root.mouse_filter = Control.MOUSE_FILTER_PASS
		mascot_root.gui_input.connect(func(ev):
			if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
				btn.pressed.emit()
		)
		container.add_child(mascot_root)
		
		var bubble_center = CenterContainer.new()
		bubble_center.custom_minimum_size = Vector2(160, 28)
		bubble_center.size = Vector2(160, 28)
		bubble_center.position = Vector2(0, -98)
		bubble_center.mouse_filter = Control.MOUSE_FILTER_PASS
		bubble_center.gui_input.connect(func(ev):
			if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
				btn.pressed.emit()
		)
		mascot_root.add_child(bubble_center)
		
		var bubble = PanelContainer.new()
		var b_style = UIHelper.create_bubbly_panel(12, Color.WHITE, Color(0.70, 0.88, 1.0), 2)
		b_style.content_margin_left = 10
		b_style.content_margin_right = 10
		b_style.content_margin_top = 4
		b_style.content_margin_bottom = 4
		bubble.add_theme_stylebox_override("panel", b_style)
		bubble.mouse_filter = Control.MOUSE_FILTER_PASS
		bubble.gui_input.connect(func(ev):
			if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
				btn.pressed.emit()
		)
		bubble_center.add_child(bubble)
		
		var b_lbl = Label.new()
		if is_missed:
			b_lbl.text = "Catch Up!"
		elif n_type == "intro":
			if node_stage == 0:
				b_lbl.text = "Prologue & Combat!"
			else:
				b_lbl.text = "Discovery Quiz!"
		elif n_type == "morning":
			if node_stage == 0:
				b_lbl.text = "Good morning!"
			else:
				b_lbl.text = "Morning Minigame!"
		elif n_type == "evening":
			if node_stage == 0:
				b_lbl.text = "Candy Crusade!" if is_boss_day else "Evening Minigame!"
			else:
				b_lbl.text = "Night brush time!"
		elif n_type == "minigame":
			b_lbl.text = "Bonus Minigame!"
		elif n_type == "quiz":
			b_lbl.text = "Final Quiz!" if day >= 28 else "Weekly Quiz!"
		elif n_type == "finish":
			b_lbl.text = "Finish Line!"
		else:
			b_lbl.text = "Let's Go!"
			
		b_lbl.add_theme_color_override("font_color", UIHelper.DEEP_BLUE)
		b_lbl.add_theme_font_size_override("font_size", 11)
		b_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
		b_lbl.gui_input.connect(func(ev):
			if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
				btn.pressed.emit()
		)
		bubble.add_child(b_lbl)
		
		var is_crown = (avatar_id.to_lower().strip_edges() in ["sircrown", "crown"])
		var av_w = 92.0 if is_crown else 64.0
		var av_h = 92.0 if is_crown else 64.0
		var char_rect = TextureRect.new()
		char_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		char_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		char_rect.custom_minimum_size = Vector2(av_w, av_h)
		char_rect.size = Vector2(av_w, av_h)
		char_rect.position = Vector2((160.0 - av_w) * 0.5, -av_h + 4.0 if is_crown else -60.0)
		char_rect.pivot_offset = Vector2(av_w * 0.5, av_h)
		char_rect.mouse_filter = Control.MOUSE_FILTER_PASS
		char_rect.gui_input.connect(func(ev):
			if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
				btn.pressed.emit()
		)
		char_rect.texture = UIHelper.get_char_texture(avatar_id, false)
		mascot_root.add_child(char_rect)
		
		var tw = mascot_root.create_tween().set_loops()
		tw.tween_property(mascot_root, "position:y", -16.0, 0.46).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(mascot_root, "position:y", 0.0, 0.39).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		
	if is_completed:
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(func():
			AudioManager.play_sfx("click")
			var p = GameState.get_active_profile()
			if day > 0 and GameState.is_day_story_unlocked(day, p):
				UIHelper.show_story_panel_modal(self, day)
			elif day == 0:
				UIHelper.show_node0_story_intro_modal(self)
			else:
				GameState.push_toast("Completed!", "Day %d is completed!" % day, "", "green")
		)
	else:
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(func():
			if is_locked:
				AudioManager.play_sfx("click")
				GameState.push_toast("Locked!", "Finish earlier steps first!", "", "orange")
			elif is_active:
				AudioManager.play_sfx("click")
				if n_type == "intro":
					if node_stage == 0:
						UIHelper.show_node0_story_intro_modal(self, func():
							GameState.preload_candy_crusade_in_background()
							UIHelper.create_candy_crusade_loading_overlay(self)
							launch_node.emit(0, "combat")
						)
					else:
						launch_node.emit(0, "quiz")
				elif n_type == "morning":
					if node_stage == 0:
						if not GameState.dev_mode:
							var hour = Time.get_time_dict_from_system().get("hour", 12)
							if hour < 5 or hour >= 14:
								UIHelper.show_time_lock_modal(self, false)
								return
						launch_node.emit(day, "brush")
					else:
						# Story panel MUST be shown after morning brush and before morning minigame
						var p = GameState.get_active_profile()
						var seen_story = p.get("seen_story_unlocks", [])
						if typeof(seen_story) != TYPE_ARRAY: seen_story = []
						if not seen_story.has(day) and GameState.is_day_story_unlocked(day, p):
							seen_story = seen_story.duplicate()
							seen_story.append(day)
							p["seen_story_unlocks"] = seen_story
							GameState.save_game()
							UIHelper.show_story_panel_modal(self, day, func():
								launch_node.emit(day, "minigame")
							)
						else:
							launch_node.emit(day, "minigame")
				elif n_type == "evening":
					if node_stage == 0:
						if is_boss_day:
							GameState.preload_candy_crusade_in_background()
							UIHelper.create_candy_crusade_loading_overlay(self)
							launch_node.emit(day, "combat")
						else:
							launch_node.emit(day, "minigame")
					else:
						if not GameState.dev_mode:
							var hour = Time.get_time_dict_from_system().get("hour", 12)
							if hour < 17:
								UIHelper.show_time_lock_modal(self, true)
								return
						launch_node.emit(day, "brush")
				elif n_type == "minigame":
					launch_node.emit(day, "minigame")
				elif n_type == "quiz":
					launch_node.emit(day, "quiz")
				elif n_type == "finish":
					GameState.push_toast("Champion!", "You completed the challenge!", "", "green")
		)
	
	return container

func _scroll_to_current_node():
	await get_tree().process_frame
	await get_tree().process_frame
	var p = GameState.get_active_profile()
	var current_node = int(p.get("currentNode", 0))
	var idx = clamp(current_node, 0, PATH_COORDINATES.size() - 1)
	var coord = PATH_COORDINATES[idx]
	var active_y = (coord.y / 100.0) * map_height
	var safe_sz = UIHelper.get_viewport_safe_size(self)
	var view_h = safe_sz.y
	var max_scroll = max(0.0, map_height - view_h)
	var target_scroll = int(clamp(active_y - view_h * 0.5, 0.0, max_scroll))
	scroll_container.scroll_vertical = target_scroll

func _on_stats_updated(_p):
	_build_map_nodes()

func _check_and_show_daily_stamp_calendar(on_close: Callable = Callable()) -> bool:
	var p = GameState.get_active_profile()
	if p.is_empty():
		return false
		
	var today_str = Time.get_date_string_from_system()
	var last_login = str(p.get("last_daily_login", ""))
	if last_login == today_str:
		return false # Already claimed today!
		
	p["last_daily_login"] = today_str
	var streak_days = int(p.get("login_stamp_count", 0)) + 1
	p["login_stamp_count"] = streak_days
	GameState.save_game()
	
	_show_daily_stamp_modal(streak_days, on_close)
	return true

func _show_daily_stamp_modal(current_day: int, on_close: Callable = Callable()):
	var day_index = ((current_day - 1) % 7) + 1
	var dlg = UIHelper.create_modal_dialog(self, 100, Color(0, 0, 0, 0.65))
	var overlay = dlg["overlay"]
	var center = dlg["center"]
	
	var card = Panel.new()
	var card_style = UIHelper.create_bubbly_panel(28, Color.WHITE, Color(0.24, 0.60, 0.95), 3)
	card.add_theme_stylebox_override("panel", card_style)
	card.custom_minimum_size = Vector2(360, 440)
	card.size = Vector2(360, 440)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	center.add_child(card)
	
	var close_fn = func():
		AudioManager.play_sfx("click")
		overlay.queue_free()
		if on_close.is_valid():
			on_close.call()
			
	var close_btn = UIHelper.create_close_button(Vector2(30, 30))
	close_btn.position = Vector2(360 - 38.0, 10.0)
	close_btn.pressed.connect(close_fn)
	card.add_child(close_btn)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 16.0
	vbox.offset_right = -16.0
	vbox.offset_top = 14.0
	vbox.offset_bottom = -14.0
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)
	card.add_child(vbox)
	
	var title = Label.new()
	title.text = "DAILY HABIT STAMP CARD"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(title, 18, Color(0.18, 0.44, 0.78), true)
	vbox.add_child(title)
	
	var sub = Label.new()
	sub.text = "Log in daily to earn healthy habit rewards!"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(sub, 11, Color(0.35, 0.50, 0.70), false)
	vbox.add_child(sub)
	
	# 7-Day Grid Container
	var grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(grid)
	
	var rewards_list = [
		{"day": 1, "reward": "50 Coins", "icon": "res://assets/images/congratulations/gold_tooth_coin.png", "coins": 50},
		{"day": 2, "reward": "100 Points", "icon": "res://assets/images/shop/purple_star_points.png", "points": 100},
		{"day": 3, "reward": "Shield", "icon": "res://assets/images/shop/fluorideshield.png", "shield": 1},
		{"day": 4, "reward": "100 Coins", "icon": "res://assets/images/congratulations/gold_tooth_coin.png", "coins": 100},
		{"day": 5, "reward": "Freeze", "icon": "res://assets/images/shop/streakfreeze.png", "freeze": 1},
		{"day": 6, "reward": "200 Points", "icon": "res://assets/images/shop/purple_star_points.png", "points": 200},
		{"day": 7, "reward": "Grand 500", "icon": "res://assets/images/congratulations/gold_tooth_coin.png", "coins": 500}
	]
	
	for r in rewards_list:
		var slot = PanelContainer.new()
		slot.custom_minimum_size = Vector2(72, 78)
		var is_stamped = r["day"] <= day_index
		var is_today = r["day"] == day_index
		
		var slot_style = StyleBoxFlat.new()
		slot_style.set_corner_radius_all(14)
		if is_today:
			slot_style.bg_color = Color(1.0, 0.95, 0.70)
			slot_style.border_color = Color(0.96, 0.65, 0.15)
			slot_style.set_border_width_all(3)
		elif is_stamped:
			slot_style.bg_color = Color(0.85, 0.96, 0.88)
			slot_style.border_color = UIHelper.VIBRANT_GREEN
			slot_style.set_border_width_all(2)
		else:
			slot_style.bg_color = Color(0.92, 0.95, 0.98)
			slot_style.border_color = Color(0.82, 0.88, 0.94)
			slot_style.set_border_width_all(1)
		slot.add_theme_stylebox_override("panel", slot_style)
		
		var s_vbox = VBoxContainer.new()
		s_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		s_vbox.add_theme_constant_override("separation", 2)
		
		var d_lbl = Label.new()
		d_lbl.text = "Day %d" % r["day"]
		d_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UIHelper.apply_bubbly_label(d_lbl, 10, Color(0.25, 0.45, 0.70), true)
		s_vbox.add_child(d_lbl)
		
		var r_img = TextureRect.new()
		r_img.custom_minimum_size = Vector2(30, 30)
		r_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		r_img.texture = UIHelper.load_texture_safe(r["icon"])
		s_vbox.add_child(r_img)
		
		var r_lbl = Label.new()
		r_lbl.text = "CLAIMED" if is_stamped else r["reward"]
		r_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UIHelper.apply_bubbly_label(r_lbl, 9, UIHelper.VIBRANT_GREEN if is_stamped else Color(0.35, 0.50, 0.70), true)
		s_vbox.add_child(r_lbl)
		
		slot.add_child(s_vbox)
		grid.add_child(slot)
		
	# Award Today's Reward
	var today_reward = rewards_list[day_index - 1]
	if today_reward.has("coins"):
		GameState.add_molar_coins(today_reward["coins"])
	if today_reward.has("points"):
		GameState.add_points(today_reward["points"])
		
	var claim_btn = UIHelper.create_bubbly_button("CLAIM STAMP REWARD", UIHelper.VIBRANT_GREEN)
	claim_btn.custom_minimum_size = Vector2(280, 44)
	claim_btn.pressed.connect(func():
		AudioManager.play_sfx("chime")
		GameState.push_toast("Daily Stamp Claimed!", "Habit streak advanced to Day %d!" % day_index, "", "green")
		overlay.queue_free()
		if on_close.is_valid():
			on_close.call()
	)
	vbox.add_child(claim_btn)
