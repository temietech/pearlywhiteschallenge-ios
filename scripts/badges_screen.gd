# scripts/badges_screen.gd
extends Control

signal back_pressed

var badges_data = [
	# Shelf 1 (Top)
	{
		"id": "streak",
		"name": "ON A ROLL",
		"desc": "Brush daily morning & night to keep your streak glowing!",
		"unit": "Days",
		"tiers": [
			{"level": 1, "threshold": 3, "label": "3-Day Streak", "src": "res://assets/images/badgescreen/onaroll_bronze.png"},
			{"level": 2, "threshold": 7, "label": "7-Day Streak", "src": "res://assets/images/badgescreen/onaroll_silver.png"},
			{"level": 3, "threshold": 14, "label": "14-Day Streak", "src": "res://assets/images/badgescreen/onaroll_gold.png"}
		]
	},
	{
		"id": "fact",
		"name": "FACT FINDER",
		"desc": "Discover awesome dental facts each day after brushing!",
		"unit": "Facts",
		"tiers": [
			{"level": 1, "threshold": 5, "label": "5 Dental Facts", "src": "res://assets/images/badgescreen/factfinder_bronze.png"},
			{"level": 2, "threshold": 10, "label": "10 Dental Facts", "src": "res://assets/images/badgescreen/factfinder_silver.png"},
			{"level": 3, "threshold": 20, "label": "20 Dental Facts", "src": "res://assets/images/badgescreen/factfinder_gold.png"}
		]
	},
	{
		"id": "minion",
		"name": "MINION MASHER",
		"desc": "Defeat pesky Cavity Minions in battle to protect the kingdom!",
		"unit": "Minions",
		"tiers": [
			{"level": 1, "threshold": 25, "label": "25 Minions Defeated", "src": "res://assets/images/badgescreen/minionmasher_bronze.png"},
			{"level": 2, "threshold": 75, "label": "75 Minions Defeated", "src": "res://assets/images/badgescreen/minionmasher_silver.png"},
			{"level": 3, "threshold": 200, "label": "200 Minions Defeated", "src": "res://assets/images/badgescreen/minionmasher_gold.png"}
		]
	},
	# Shelf 2 (Middle)
	{
		"id": "quiz",
		"name": "QUIZ WHIZ",
		"desc": "Test your dental smarts and ace weekly quizzes!",
		"unit": "Quizzes",
		"tiers": [
			{"level": 1, "threshold": 1, "label": "1 Quiz Completed", "src": "res://assets/images/badgescreen/quizwhiz-bronze.png"},
			{"level": 2, "threshold": 2, "label": "2 Quizzes Completed", "src": "res://assets/images/badgescreen/quizwhiz-silver.png"},
			{"level": 3, "threshold": 3, "label": "3 Quizzes Completed", "src": "res://assets/images/badgescreen/quizwhiz.png"}
		]
	},
	{
		"id": "boss",
		"name": "SWEET DEFEAT",
		"desc": "Defeat villain Blue Candor to defend the kingdom of teeth!",
		"unit": "Bosses",
		"tiers": [
			{"level": 1, "threshold": 1, "label": "Defeat Blue Candor", "src": "res://assets/images/badgescreen/sweetdefeat_bronze.png"},
			{"level": 2, "threshold": 2, "label": "Defeat 2 Times", "src": "res://assets/images/badgescreen/sweetdefeat_silver.png"},
			{"level": 3, "threshold": 3, "label": "Defeat 3 Times", "src": "res://assets/images/badgescreen/sweetdefeat_gold.png"}
		]
	},
	{
		"id": "coin",
		"name": "COIN COLLECTOR",
		"desc": "Earn and save shiny Molar Coins to spend in the shop!",
		"unit": "Coins",
		"tiers": [
			{"level": 1, "threshold": 250, "label": "Save 250 Coins", "src": "res://assets/images/badgescreen/coincollector_bronze.png"},
			{"level": 2, "threshold": 750, "label": "Save 750 Coins", "src": "res://assets/images/badgescreen/coincollector_silver.png"},
			{"level": 3, "threshold": 2000, "label": "Save 2000 Coins", "src": "res://assets/images/badgescreen/coincollector_gold.png"}
		]
	},
	# Shelf 3 (Bottom)
	{
		"id": "point",
		"name": "POINT MASTER",
		"desc": "Reach high challenge Star Points for brushing excellence!",
		"unit": "Points",
		"tiers": [
			{"level": 1, "threshold": 500, "label": "Earn 500 Points", "src": "res://assets/images/badgescreen/Pointsmaster_bronze.png"},
			{"level": 2, "threshold": 2000, "label": "Earn 2000 Points", "src": "res://assets/images/badgescreen/pointmaster_silver.png"},
			{"level": 3, "threshold": 5000, "label": "Earn 5000 Points", "src": "res://assets/images/badgescreen/Pointsmaster_gold.png"}
		]
	},
	{
		"id": "sparkle",
		"name": "FIRST SPARKLE",
		"desc": "Complete your very first 2-minute brushing session!",
		"unit": "Brush",
		"tiers": [
			{"level": 1, "threshold": 1, "label": "First Brush", "src": "res://assets/images/badgescreen/firstsparkle.png"}
		]
	},
	{
		"id": "champion",
		"name": "PEARLY CHAMPION",
		"desc": "Complete all 28 challenge days and earn the grand trophy!",
		"unit": "Days",
		"tiers": [
			{"level": 1, "threshold": 28, "label": "28 Days Completed", "src": "res://assets/images/badgescreen/pearlychampion.png"}
		]
	}
]

var detail_modal: Control
var back_btn: TextureButton = null
static var _cached_grayscale_mat: ShaderMaterial = null
static var _cached_title_tex: Texture2D = null

func _get_grayscale_material() -> ShaderMaterial:
	if _cached_grayscale_mat:
		return _cached_grayscale_mat
		
	var shader = Shader.new()
	shader.code = """
shader_type canvas_item;

uniform float brightness : hint_range(0.0, 2.0) = 0.52;
uniform float contrast : hint_range(0.0, 2.0) = 1.10;

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	float gray = dot(col.rgb, vec3(0.299, 0.587, 0.114));
	float final_gray = clamp((gray - 0.5) * contrast + 0.5, 0.0, 1.0) * brightness;
	COLOR = vec4(vec3(final_gray), col.a);
}
"""
	_cached_grayscale_mat = ShaderMaterial.new()
	_cached_grayscale_mat.shader = shader
	return _cached_grayscale_mat

static func _ensure_trophy_title_texture() -> Texture2D:
	if _cached_title_tex:
		return _cached_title_tex
		
	var path = "res://assets/images/badgescreen/trophy_collection_title.png"
	# Exported builds (iPhone/iPad) only contain the imported texture, not the raw PNG file,
	# so load it through the resource system first. Raw-file cleanup below is editor-only.
	var imported_tex = UIHelper.load_texture_safe(path)
	if imported_tex:
		_cached_title_tex = imported_tex
		return _cached_title_tex
	var global_path = ProjectSettings.globalize_path(path)
	
	# If image exists on disk, load and clean any black background artifacts
	if FileAccess.file_exists(global_path):
		var img = Image.load_from_file(global_path)
		if img and not img.is_empty():
			img.convert(Image.FORMAT_RGBA8)
			var w = img.get_width()
			var h = img.get_height()
			var has_black = false
			
			# Clean pure black or near-black background pixels that leaked from RGB8 crop
			for y in range(h):
				for x in range(w):
					var c = img.get_pixel(x, y)
					# Background black is pure black (r<0.05, g<0.05, b<0.05)
					if c.a > 0.1 and c.r < 0.06 and c.g < 0.06 and c.b < 0.06:
						img.set_pixel(x, y, Color(0, 0, 0, 0))
						has_black = true
			if has_black:
				img.save_png(global_path)
			_cached_title_tex = ImageTexture.create_from_image(img)
			return _cached_title_tex
			
	# If not yet generated, extract from screens/16-badges.png with proper RGBA8 format
	var screen_tex = UIHelper.load_texture_safe("res://screens/16-badges.png")
	if screen_tex:
		var full_img = screen_tex.get_image()
		if full_img and not full_img.is_empty():
			var iw = full_img.get_width()
			var ih = full_img.get_height()
			var rx = int(iw * 0.23)
			var ry = int(ih * 0.012)
			var rw = int(iw * 0.54)
			var rh = int(ih * 0.088)
			var cropped = full_img.get_region(Rect2i(rx, ry, rw, rh))
			if cropped and not cropped.is_empty():
				cropped.convert(Image.FORMAT_RGBA8)
				var w = cropped.get_width()
				var h = cropped.get_height()
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
					var lum = col.r * 0.299 + col.g * 0.587 + col.b * 0.114
					var is_outline = (lum <= 0.36) or (col.r < 0.20 and col.g * 0.35 and col.b < 0.60)
					if is_outline:
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
				cropped.save_png(global_path)
				_cached_title_tex = ImageTexture.create_from_image(cropped)
				return _cached_title_tex
	return null

static func _get_see_inventory_texture() -> Texture2D:
	var path = "res://assets/images/badgescreen/seeinventorybtn.png"
	var tex = UIHelper.load_texture_safe(path)
	if tex:
		return tex
	var godot_btn_path = "res://assets/images/buttons/seeinventorybtn.png"
	tex = UIHelper.load_texture_safe(godot_btn_path)
	if tex:
		var g_path = ProjectSettings.globalize_path(path)
		var img = tex.get_image()
		if img and not img.is_empty():
			img.save_png(g_path)
		return tex
	return null

func _create_nine_patch(tex_path: String, margin_left: int = 28, margin_top: int = -1, margin_right: int = -1, margin_bottom: int = -1) -> NinePatchRect:
	var np = NinePatchRect.new()
	np.texture = UIHelper.load_texture_safe(tex_path)
	np.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var mt = margin_left if margin_top < 0 else margin_top
	var mr = margin_left if margin_right < 0 else margin_right
	var mb = mt if margin_bottom < 0 else margin_bottom
	np.patch_margin_left = margin_left
	np.patch_margin_top = mt
	np.patch_margin_right = mr
	np.patch_margin_bottom = mb
	return np

func _ready():
	anchors_preset = Control.PRESET_FULL_RECT
	anchor_right = 1.0
	anchor_bottom = 1.0
	_build_ui()
	_last_built_size = size

func _notification(what):
	if what == NOTIFICATION_RESIZED and is_node_ready():
		call_deferred("_rebuild_ui")

var _last_built_size: Vector2 = Vector2.ZERO

func _rebuild_ui():
	# Only rebuild when the size REALLY changed: rebuilding frees the back button, and a rebuild
	# landing between finger-down and finger-up made the back button feel dead on phones.
	if _last_built_size != Vector2.ZERO and size.distance_to(_last_built_size) < 2.0:
		return
	_last_built_size = size
	for c in get_children():
		# Protect back button and detail modal from being freed during rebuilds
		if c != detail_modal and c != back_btn:
			c.queue_free()
	_build_ui()

static func _resolve_badge_src(src: String) -> String:
	if ResourceLoader.exists(src) or FileAccess.file_exists(ProjectSettings.globalize_path(src)):
		return src
	# Minion masher bronze and gold fallback to silver until user adds them
	if "minionmasher" in src:
		var silver_path = "res://assets/images/badgescreen/minionmasher_silver.png"
		if ResourceLoader.exists(silver_path) or FileAccess.file_exists(ProjectSettings.globalize_path(silver_path)):
			return silver_path
	# Case sensitivity variation fallbacks for Pointsmaster / pointmaster
	if "point" in src.to_lower() and "master" in src.to_lower():
		var variations = [
			src.replace("Pointsmaster", "pointmaster"),
			src.replace("pointmaster", "Pointsmaster")
		]
		for v in variations:
			if ResourceLoader.exists(v) or FileAccess.file_exists(ProjectSettings.globalize_path(v)):
				return v
	return src

func _get_badge_status(b: Dictionary, p: Dictionary) -> Dictionary:
	var cur_val = 0
	if b["id"] == "streak":
		cur_val = int(p.get("streak", 0))
	elif b["id"] == "fact":
		cur_val = p.get("factsCollected", []).size()
	elif b["id"] == "minion":
		cur_val = int(p.get("minionsDefeated", 0))
	elif b["id"] == "quiz":
		cur_val = int(p.get("quizzesCompleted", 0))
	elif b["id"] == "boss":
		cur_val = int(p.get("bossesDefeated", 0))
	elif b["id"] == "coin":
		cur_val = int(p.get("coins", 0))
	elif b["id"] == "point":
		cur_val = int(p.get("points", 0))
	elif b["id"] == "sparkle":
		var days_stat = p.get("daysStatus", [])
		var has_done = false
		for d in days_stat:
			if d == "done" or d == "surprise-done":
				has_done = true
				break
		cur_val = 1 if (has_done or int(p.get("totalMinutes", 0)) >= 2) else 0
	elif b["id"] == "champion":
		var days_stat = p.get("daysStatus", [])
		var completed_days = 0
		for d in days_stat:
			if d == "done" or d == "surprise-done":
				completed_days += 1

		# Include the current day in progress if player is actively working on it
		# This gives a more accurate representation of progress (e.g., on day 28 morning,
		# show "28 Days" not "27 Days" since they're actively working on day 28)
		var cur_node = int(p.get("currentNode", 1))
		var cur_day = GameState.day_for_node(cur_node)
		if cur_day > 0 and cur_day <= 28 and cur_day > completed_days:
			var cur_node_data = GameState.get_node_data(cur_node)
			var node_type = str(cur_node_data.get("type", ""))
			# Count the current day if they've started it (at least morning brush done)
			# or if the finish node is the current node (day 28 complete)
			if node_type in ["evening", "minigame", "quiz", "finish"] or GameState.is_day_morning_completed(cur_day, p):
				completed_days = cur_day

		cur_val = completed_days

	var tiers: Array = b["tiers"]
	var highest_tier_idx = -1
	for i in range(tiers.size() - 1, -1, -1):
		if cur_val >= tiers[i]["threshold"]:
			highest_tier_idx = i
			break
			
	var is_unlocked = (highest_tier_idx >= 0)
	var display_tier_idx = highest_tier_idx if is_unlocked else 0
	var display_src = _resolve_badge_src(tiers[display_tier_idx]["src"])
	
	return {
		"cur_val": cur_val,
		"is_unlocked": is_unlocked,
		"highest_tier_idx": highest_tier_idx,
		"display_tier_idx": display_tier_idx,
		"display_src": display_src,
		"tiers": tiers
	}

func _build_ui():
	var safe_sz = UIHelper.get_viewport_safe_size(self)
	var cur_w = safe_sz.x
	var cur_h = safe_sz.y
	
	# Background
	var bg = TextureRect.new()
	UIHelper.setup_fullscreen_bg(bg)
	bg.texture = UIHelper.load_texture_safe("res://assets/images/badgescreen/badges_background.jpg")
	add_child(bg)
	
	# Top Back Button - Only create once and preserve across rebuilds
	if not back_btn or not is_instance_valid(back_btn):
		back_btn = UIHelper.create_image_button("res://assets/images/badgescreen/blue_back_button.png", Vector2(86, 36))
		if not back_btn.texture_normal:
			back_btn = UIHelper.create_image_button("res://assets/images/shop/blue_back_button.png", Vector2(86, 36))
		if not back_btn.texture_normal:
			back_btn = UIHelper.create_image_button("res://assets/images/shop/backbtnshop.png", Vector2(86, 36))
		back_btn.custom_minimum_size = Vector2(96, 44)
		back_btn.size = Vector2(96, 44)
		# FIX: Raise z_index to 60 and add mouse_filter to make back button tappable above content
		back_btn.z_index = 60
		back_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		var back_fired := [false]
		var go_back := func():
			if back_fired[0]:
				return
			back_fired[0] = true
			# Re-arm shortly so the button can never stay dead if navigation was blocked
			get_tree().create_timer(0.6).timeout.connect(func(): back_fired[0] = false)
			# main.gd connects back_pressed -> navigate_to("map")
			back_pressed.emit()
		# Fire on finger-DOWN so the button can never be lost to a layout rebuild mid-tap
		back_btn.button_down.connect(go_back)
		back_btn.pressed.connect(go_back)
		add_child(back_btn)
	# Update position on each rebuild
	# Keep the button below the notch / status bar so iPhone and iPad taps reach it
	back_btn.position = Vector2(10, 10 + UIHelper.safe_top)
	
	# Header Title: Graphic Image (Clean transparent PNG) or Styled Bubbly Font
	var title_tex = _ensure_trophy_title_texture()
	if title_tex:
		var title_rect = TextureRect.new()
		title_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		title_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		title_rect.texture = title_tex
		var tw = clamp(cur_w * 0.65, 230.0, 310.0)
		var aspect = float(title_tex.get_height()) / float(max(1, title_tex.get_width()))
		var th = tw * aspect
		title_rect.custom_minimum_size = Vector2(tw, th)
		title_rect.size = Vector2(tw, th)
		title_rect.position = Vector2((cur_w - tw) * 0.5, 8.0)
		title_rect.z_index = 15
		add_child(title_rect)
	else:
		var title_vbox = VBoxContainer.new()
		title_vbox.position = Vector2(0, 8)
		title_vbox.size = Vector2(cur_w, 65)
		title_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		title_vbox.add_theme_constant_override("separation", -6)
		add_child(title_vbox)
		
		var font = UIHelper.get_main_font()
		var t1 = Label.new()
		t1.text = "TROPHY"
		t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if font:
			t1.add_theme_font_override("font", font)
		UIHelper.apply_bubbly_label(t1, 30, Color(0.25, 0.65, 0.95), true)
		t1.add_theme_color_override("font_outline_color", Color.WHITE)
		t1.add_theme_constant_override("outline_size", 8)
		t1.add_theme_color_override("font_shadow_color", Color(0.08, 0.28, 0.55))
		t1.add_theme_constant_override("shadow_offset_x", 2)
		t1.add_theme_constant_override("shadow_offset_y", 3)
		title_vbox.add_child(t1)
		
		var t2 = Label.new()
		t2.text = "COLLECTION"
		t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if font:
			t2.add_theme_font_override("font", font)
		UIHelper.apply_bubbly_label(t2, 26, Color(0.25, 0.65, 0.95), true)
		t2.add_theme_color_override("font_outline_color", Color.WHITE)
		t2.add_theme_constant_override("outline_size", 8)
		t2.add_theme_color_override("font_shadow_color", Color(0.08, 0.28, 0.55))
		t2.add_theme_constant_override("shadow_offset_x", 2)
		t2.add_theme_constant_override("shadow_offset_y", 3)
		title_vbox.add_child(t2)
	
	# Profile stats for unlocks
	var p = GameState.get_active_profile()
	
	# 3 Shelves setup (Beams + 3 Badges each)
	# Lowered comfortably so the top row clears the trophy title
	var shelf_ys = [cur_h * 0.40, cur_h * 0.67, cur_h * 0.94]
	var badge_w = clamp(cur_w * 0.30, 120.0, 140.0)
	var badge_h = round(badge_w * 1.28)
	var col_gap = clamp(cur_w * 0.04, 10.0, 18.0)
	var total_badges_w = (badge_w * 3.0) + (col_gap * 2.0)
	var badges_start_x = (cur_w - total_badges_w) * 0.5
	
	var shelf_w = clamp(total_badges_w + 50.0, 350.0, cur_w - 20.0)
	var shelf_x = (cur_w - shelf_w) * 0.5
	
	for row_idx in range(3):
		var beam_y = shelf_ys[row_idx]
		
		# Wooden shelf plank (centered between side columns)
		var shelf_beam = Panel.new()
		shelf_beam.position = Vector2(shelf_x, beam_y)
		shelf_beam.size = Vector2(shelf_w, 13)
		var sb_style = StyleBoxFlat.new()
		sb_style.bg_color = Color(0.92, 0.70, 0.36)
		sb_style.corner_radius_top_left = 6
		sb_style.corner_radius_top_right = 6
		sb_style.corner_radius_bottom_left = 6
		sb_style.corner_radius_bottom_right = 6
		sb_style.shadow_color = Color(0, 0, 0, 0.28)
		sb_style.shadow_size = 5
		sb_style.shadow_offset = Vector2(0, 4)
		shelf_beam.add_theme_stylebox_override("panel", sb_style)
		add_child(shelf_beam)
		
		# 3 badges standing on this shelf
		for col_idx in range(3):
			var badge_idx = row_idx * 3 + col_idx
			if badge_idx < badges_data.size():
				var b = badges_data[badge_idx]
				var status = _get_badge_status(b, p)
				var is_unlocked = status["is_unlocked"]
				var display_src = status["display_src"]
				
				var x_pos = badges_start_x + col_idx * (badge_w + col_gap)
				var badge_y = beam_y - badge_h - 4.0
				
				var badge_btn = UIHelper.create_image_button(display_src, Vector2(badge_w, badge_h))
				badge_btn.position = Vector2(x_pos, badge_y)
				badge_btn.pivot_offset = Vector2(badge_w * 0.5, badge_h * 0.5)
				
				if not is_unlocked:
					badge_btn.material = _get_grayscale_material()
					
					var lock_img = TextureRect.new()
					lock_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
					lock_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
					lock_img.texture = UIHelper.load_texture_safe("res://assets/images/scrapbook/metal_lock_icon.png")
					if not lock_img.texture:
						lock_img.texture = UIHelper.load_texture_safe("res://assets/images/misc/metal_lock_icon.png")
					var lock_sz = Vector2(32, 40)
					lock_img.custom_minimum_size = lock_sz
					lock_img.size = lock_sz
					lock_img.position = Vector2(x_pos + (badge_w - lock_sz.x) * 0.5, badge_y + (badge_h - lock_sz.y) * 0.5)
					lock_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
					lock_img.z_index = 8
					add_child(lock_img)
				
				badge_btn.pressed.connect(func():
					AudioManager.play_sfx("click")
					_show_badge_detail(b, status)
				)
				add_child(badge_btn)

func _show_badge_detail(b: Dictionary, status: Dictionary):
	if detail_modal:
		detail_modal.queue_free()
		
	var safe_sz = UIHelper.get_viewport_safe_size(self)
	var cur_w = safe_sz.x
	var cur_h = safe_sz.y
	
	detail_modal = Control.new()
	detail_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	detail_modal.z_index = 100
	add_child(detail_modal)
	
	# Dimmed backdrop (click outside to close)
	var backdrop = ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.04, 0.10, 0.24, 0.80)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			AudioManager.play_sfx("click")
			detail_modal.queue_free()
	)
	detail_modal.add_child(backdrop)
	
	# Center container
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_modal.add_child(center)
	
	var is_unlocked = status["is_unlocked"]
	var cur_val = status["cur_val"]
	var tiers: Array = status["tiers"]
	var highest_idx = status["highest_tier_idx"]
	var initial_tier_idx = highest_idx if highest_idx >= 0 else 0
	
	# Load background window texture
	var bg_tex = UIHelper.load_texture_safe("res://assets/images/badgescreen/game_blue_windo_b.png")
	if not bg_tex:
		bg_tex = UIHelper.load_texture_safe("res://assets/images/shop/game_blue_windo_b.png")
	
	var aspect := 1.35
	if bg_tex != null and bg_tex.get_width() > 0:
		aspect = float(bg_tex.get_height()) / float(bg_tex.get_width())
	
	var max_w = cur_w * 0.82
	var max_h = cur_h * 0.82
	var card_w = max_w
	var card_h = round(card_w * aspect)
	if card_h > max_h:
		card_h = max_h
		card_w = round(card_h / aspect)
	
	var card = Control.new()
	var can_show_inventory = (is_unlocked and tiers.size() > 1)
	card.custom_minimum_size = Vector2(card_w, card_h)
	card.size = Vector2(card_w, card_h)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var bg_win = TextureRect.new()
	bg_win.texture = bg_tex
	bg_win.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_win.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bg_win.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_win.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(bg_win)
	center.add_child(card)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	var pad_x = round(card_w * 0.06)
	var pad_top = round(card_h * 0.052)
	var pad_bot = round(card_h * 0.048)
	vbox.offset_left = pad_x
	vbox.offset_right = -pad_x
	vbox.offset_top = pad_top
	vbox.offset_bottom = -pad_bot
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", int(clamp(card_h * 0.018, 8, 14)))
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(vbox)
	
	# Close X Button
	var close_btn_sz = clamp(round(card_w * 0.085), 32.0, 38.0)
	var close_x_btn = UIHelper.create_close_button(Vector2(close_btn_sz, close_btn_sz))
	close_x_btn.position = Vector2(card_w - close_btn_sz - 10.0, 10.0)
	close_x_btn.z_index = 25
	close_x_btn.pressed.connect(func():
		AudioManager.play_sfx("click")
		detail_modal.queue_free()
	)
	card.add_child(close_x_btn)
	
	# 1. Main Badge Image Container AT THE TOP (Badge graphic already contains the title name)
	var panel_w = round(card_w * 0.88)
	var top_area_h = clamp(round(card_h * 0.32), 140.0, 190.0)
	
	var img_center = CenterContainer.new()
	img_center.custom_minimum_size = Vector2(panel_w, top_area_h)
	img_center.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(img_center)
	
	var img_dim = top_area_h - 4.0
	var img_box = Control.new()
	var img_sz = Vector2(img_dim, img_dim)
	img_box.custom_minimum_size = img_sz
	img_box.size = img_sz
	img_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	img_center.add_child(img_box)
	
	var main_img = TextureRect.new()
	main_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	main_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	main_img.size = img_sz
	main_img.position = Vector2.ZERO
	main_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	img_box.add_child(main_img)
	
	var lock_ov = TextureRect.new()
	lock_ov.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	lock_ov.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var lock_sz = Vector2(round(img_dim * 0.35), round(img_dim * 0.44))
	lock_ov.custom_minimum_size = lock_sz
	lock_ov.size = lock_sz
	lock_ov.position = (img_sz - lock_sz) * 0.5
	lock_ov.texture = UIHelper.load_texture_safe("res://assets/images/scrapbook/metal_lock_icon.png")
	if not lock_ov.texture:
		lock_ov.texture = UIHelper.load_texture_safe("res://assets/images/misc/metal_lock_icon.png")
	lock_ov.mouse_filter = Control.MOUSE_FILTER_IGNORE
	img_box.add_child(lock_ov)
	
	# 3. Description & Progress Inset Panel IN THE MIDDLE
	var info_h = clamp(round(card_h * 0.24), 110.0, 150.0)
	var info_panel = Panel.new()
	info_panel.custom_minimum_size = Vector2(panel_w, info_h)
	info_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var ip_st = StyleBoxFlat.new()
	ip_st.bg_color = Color.WHITE
	ip_st.set_corner_radius_all(16)
	ip_st.border_width_left = 3
	ip_st.border_width_right = 3
	ip_st.border_width_top = 3
	ip_st.border_width_bottom = 3
	ip_st.border_color = Color(0.85, 0.94, 1.0)
	ip_st.shadow_color = Color(0.1, 0.2, 0.35, 0.12)
	ip_st.shadow_size = 4
	info_panel.add_theme_stylebox_override("panel", ip_st)
	vbox.add_child(info_panel)
	
	var ip_vbox = VBoxContainer.new()
	ip_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	ip_vbox.offset_left = 14.0
	ip_vbox.offset_right = -14.0
	ip_vbox.offset_top = 8.0
	ip_vbox.offset_bottom = -8.0
	ip_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	ip_vbox.add_theme_constant_override("separation", int(clamp(card_h * 0.010, 3, 6)))
	info_panel.add_child(ip_vbox)
	
	var desc_lbl = Label.new()
	desc_lbl.text = b["desc"]
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	UIHelper.apply_bubbly_label(desc_lbl, clamp(int(card_w * 0.036), 12, 15), Color(0.14, 0.30, 0.55), true)
	desc_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	ip_vbox.add_child(desc_lbl)
	
	var tier_status_lbl = Label.new()
	tier_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ip_vbox.add_child(tier_status_lbl)
	
	var pbar = ProgressBar.new()
	pbar.custom_minimum_size = Vector2(panel_w - 28.0, clamp(round(card_h * 0.024), 12.0, 16.0))
	pbar.min_value = 0.0
	pbar.show_percentage = false
	var pb_bg = StyleBoxFlat.new()
	pb_bg.bg_color = Color(0.88, 0.94, 0.98)
	pb_bg.set_corner_radius_all(6)
	var pb_fl = StyleBoxFlat.new()
	pb_fl.set_corner_radius_all(6)
	pbar.add_theme_stylebox_override("background", pb_bg)
	pbar.add_theme_stylebox_override("fill", pb_fl)
	ip_vbox.add_child(pbar)
	
	var count_lbl = Label.new()
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(count_lbl, clamp(int(card_w * 0.033), 11, 14), Color(0.35, 0.50, 0.70), true)
	ip_vbox.add_child(count_lbl)
	
	# 4. Inventory Drawer Container AT THE BOTTOM (Enlarged Badges & Interactivity)
	var inv_drawer_h = clamp(round(card_h * 0.25), 115.0, 155.0)
	var inv_drawer = Panel.new()
	inv_drawer.custom_minimum_size = Vector2(panel_w, inv_drawer_h)
	inv_drawer.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	inv_drawer.visible = false
	var id_st = StyleBoxFlat.new()
	id_st.bg_color = Color(1, 1, 1, 0.96)
	id_st.set_corner_radius_all(16)
	id_st.border_width_left = 3
	id_st.border_width_right = 3
	id_st.border_width_top = 3
	id_st.border_width_bottom = 3
	id_st.border_color = Color(0.85, 0.94, 1.0)
	id_st.shadow_size = 4
	id_st.shadow_color = Color(0.1, 0.2, 0.35, 0.12)
	inv_drawer.add_theme_stylebox_override("panel", id_st)
	vbox.add_child(inv_drawer)
	
	var inv_hbox = HBoxContainer.new()
	inv_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	inv_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	inv_hbox.add_theme_constant_override("separation", int(clamp(card_w * 0.038, 14, 24)))
	inv_drawer.add_child(inv_hbox)
	
	var tier_buttons: Array = []
	var tier_wrappers: Array = []
	var tier_borders: Array = []
	var tier_names = ["BRONZE", "SILVER", "GOLD"]
	
	# Significantly larger badge size (e.g. 75px to 100px)
	var t_sz = clamp(round(inv_drawer_h * 0.68), 75.0, 100.0)
	
	for t_i in range(tiers.size()):
		var t = tiers[t_i]
		var t_owned = (cur_val >= t["threshold"])
		
		var t_btn = TextureButton.new()
		t_btn.custom_minimum_size = Vector2(t_sz, t_sz + 24.0)
		t_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		inv_hbox.add_child(t_btn)
		tier_buttons.append(t_btn)
		
		var t_box = VBoxContainer.new()
		t_box.set_anchors_preset(Control.PRESET_FULL_RECT)
		t_box.alignment = BoxContainer.ALIGNMENT_CENTER
		t_box.add_theme_constant_override("separation", 3)
		t_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		t_btn.add_child(t_box)
		
		var t_img_wrap = Control.new()
		t_img_wrap.custom_minimum_size = Vector2(t_sz, t_sz)
		t_img_wrap.pivot_offset = Vector2(t_sz * 0.5, t_sz * 0.5)
		t_img_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		t_box.add_child(t_img_wrap)
		tier_wrappers.append(t_img_wrap)
		
		# Glowing selection border
		var sel_border = Panel.new()
		sel_border.set_anchors_preset(Control.PRESET_FULL_RECT)
		sel_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var border_st = StyleBoxFlat.new()
		border_st.bg_color = Color(1, 1, 1, 0)
		border_st.set_corner_radius_all(14)
		border_st.border_width_left = 3
		border_st.border_width_right = 3
		border_st.border_width_top = 3
		border_st.border_width_bottom = 3
		border_st.border_color = Color(1.0, 0.78, 0.18) # Shiny Gold Selection Border
		border_st.shadow_color = Color(1.0, 0.82, 0.20, 0.50)
		border_st.shadow_size = 6
		sel_border.add_theme_stylebox_override("panel", border_st)
		sel_border.visible = false
		t_img_wrap.add_child(sel_border)
		tier_borders.append(sel_border)
		
		var t_img = TextureRect.new()
		t_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t_img.set_anchors_preset(Control.PRESET_FULL_RECT)
		t_img.texture = UIHelper.load_texture_safe(_resolve_badge_src(t["src"]))
		t_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		if not t_owned:
			t_img.material = _get_grayscale_material()
			t_img.modulate = Color(0.9, 0.9, 0.95, 0.55)
		else:
			t_img.modulate = Color.WHITE
			
		t_img_wrap.add_child(t_img)
		
		var t_name_lbl = Label.new()
		t_name_lbl.text = tier_names[t_i] if t_i < tier_names.size() else "TIER %d" % (t_i + 1)
		t_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UIHelper.apply_bubbly_label(t_name_lbl, clamp(int(card_w * 0.034), 12, 15), Color(0.12, 0.32, 0.62), true)
		t_box.add_child(t_name_lbl)
	
	# Reactive View update function when a tier is selected
	var update_tier_view = func(t_i: int):
		if t_i < 0 or t_i >= tiers.size():
			return
			
		var sel_tier = tiers[t_i]
		var sel_src = _resolve_badge_src(sel_tier["src"])
		var t_owned = (cur_val >= sel_tier["threshold"])
		var t_label = sel_tier["label"]
		var t_name = tier_names[t_i] if t_i < tier_names.size() else "TIER %d" % (t_i + 1)
		
		# Update main image
		main_img.texture = UIHelper.load_texture_safe(sel_src)
		if t_owned:
			main_img.material = null
			main_img.modulate = Color.WHITE
			lock_ov.visible = false
		else:
			main_img.material = _get_grayscale_material()
			main_img.modulate = Color(0.90, 0.92, 0.98, 0.90)
			lock_ov.visible = true
			
		# Update goal description & progress text
		var target_val = sel_tier["threshold"]
		if t_owned:
			tier_status_lbl.text = "%s TIER UNLOCKED! (%s)" % [t_name, t_label]
			UIHelper.apply_bubbly_label(tier_status_lbl, clamp(int(card_w * 0.033), 11, 14), UIHelper.VIBRANT_GREEN, true)
			pb_fl.bg_color = UIHelper.VIBRANT_GREEN
		else:
			var to_go = max(0, target_val - cur_val)
			var unit_name = b["unit"]
			if to_go == 1:
				var u_lower = unit_name.to_lower()
				if u_lower == "facts": unit_name = "Fact"
				elif u_lower == "days": unit_name = "Day"
				elif u_lower == "quizzes": unit_name = "Quiz"
				elif u_lower == "bosses": unit_name = "Boss"
				elif u_lower == "minions": unit_name = "Minion"
				elif u_lower == "coins": unit_name = "Coin"
				elif u_lower == "points": unit_name = "Point"
				elif unit_name.ends_with("s"): unit_name = unit_name.left(unit_name.length() - 1)
			tier_status_lbl.text = "Goal for %s: %s (%d %s to go!)" % [t_name, t_label, to_go, unit_name]
			UIHelper.apply_bubbly_label(tier_status_lbl, clamp(int(card_w * 0.033), 11, 14), Color(0.92, 0.40, 0.10), true)
			pb_fl.bg_color = UIHelper.GOLD_YELLOW

		pbar.max_value = float(target_val)
		pbar.value = float(clamp(cur_val, 0, target_val))
		count_lbl.text = "Progress: %d / %d %s" % [cur_val, target_val, b["unit"]]

		# Update selection highlights
		for idx in range(tiers.size()):
			if idx < tier_wrappers.size() and idx < tier_borders.size():
				var wrp = tier_wrappers[idx]
				var brd = tier_borders[idx]
				if idx == t_i:
					wrp.scale = Vector2(1.10, 1.10)
					brd.visible = true
				else:
					wrp.scale = Vector2(1.0, 1.0)
					brd.visible = false
	
	# Connect click events to tier buttons
	for t_i in range(tier_buttons.size()):
		var btn = tier_buttons[t_i] as TextureButton
		var idx_capture = t_i
		btn.pressed.connect(func():
			AudioManager.play_sfx("click")
			update_tier_view.call(idx_capture)
		)

	# Initial call with default active tier
	update_tier_view.call(initial_tier_idx)

	# 5. Action Button & Inventory Drawer Toggle (at the very bottom)
	if can_show_inventory:
		var see_inv_path = "res://assets/images/badgescreen/seeinventorybtn.png"
		if not FileAccess.file_exists(ProjectSettings.globalize_path(see_inv_path)):
			see_inv_path = "res://assets/images/general/seeinventorybtn.png"
			
		var hide_inv_path = "res://assets/images/buttons/hideinventorybtn.png"
		if not FileAccess.file_exists(ProjectSettings.globalize_path(hide_inv_path)):
			hide_inv_path = "res://assets/images/buttons/hideinventorybtn.png"
			
		var see_tex = UIHelper.load_texture_safe(see_inv_path)
		var hide_tex = UIHelper.load_texture_safe(hide_inv_path)
		
		var btn_w = clamp(round(card_w * 0.56), 180.0, 260.0)
		var btn_h = clamp(round(card_h * 0.095), 44.0, 62.0)
		var inv_btn = TextureButton.new()
		inv_btn.texture_normal = see_tex
		inv_btn.ignore_texture_size = true
		inv_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		inv_btn.custom_minimum_size = Vector2(btn_w, btn_h)
		inv_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		vbox.add_child(inv_btn)
		
		inv_btn.pressed.connect(func():
			AudioManager.play_sfx("click")
			inv_drawer.visible = not inv_drawer.visible
			# Keep top hero artwork visible so layout stays seamless and persistent
			img_center.visible = true
			inv_btn.texture_normal = hide_tex if inv_drawer.visible else see_tex
		)
	else:
		var close_btn = UIHelper.create_bubbly_button("CLOSE", Color(0.22, 0.58, 0.92))
		var btn_w = clamp(round(card_w * 0.44), 140.0, 220.0)
		var btn_h = clamp(round(card_h * 0.08), 38.0, 56.0)
		close_btn.custom_minimum_size = Vector2(btn_w, btn_h)
		close_btn.add_theme_font_size_override("font_size", clamp(int(card_w * 0.04), 12, 16))
		close_btn.pressed.connect(func():
			AudioManager.play_sfx("click")
			detail_modal.queue_free()
		)
		vbox.add_child(close_btn)
	
	# Bouncy Pop-in Animation
	card.pivot_offset = card.size * 0.5
	card.scale = Vector2(0.85, 0.85)
	card.modulate.a = 0.0
	var tw = card.create_tween().set_parallel(true)
	tw.tween_property(card, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "modulate:a", 1.0, 0.15)
