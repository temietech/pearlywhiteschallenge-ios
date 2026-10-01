# scripts/surprise_screen.gd
extends Control

signal surprise_claimed
signal game_ended
signal game_won

var bubbles_popped: int = 0
var time_left: int = 30
var coins_earned: int = 0
var points_earned: int = 0
var gifts_earned: int = 0
var gift_contents: Array[String] = []
var gifts_opened: bool = false
var scheduled_gift_times: Array[int] = []
var gift_slots_spawned: Array[bool] = [false, false, false]
var is_playing: bool = false
var is_paused: bool = false
var speed_multiplier: float = 1.0

var active_bubbles: Array[Dictionary] = []

var timer: Timer

var bubble_count_label: Label
var time_label: Label
var coin_lbl: Label
var star_lbl: Label
var gift_lbl: Label
var play_area: Control

var difficulty_modal: Control
var pause_modal: Control
var win_modal: Control

var pause_btn: TextureButton
var title_rect: TextureRect
var title_fallback_lbl: Label
var stats_row: HBoxContainer
var tray: Control

static var _cached_bubble_title_tex: Texture2D = null
static var _bubble_tex: Texture2D = null
static var _bubble_click_mask: BitMap = null
static var _bubble_radius_ratio: float = 0.38

static func _ensure_bubble_resources():
	if _bubble_tex and _bubble_click_mask:
		return
		
	var paths = [
		"res://assets/images/createprofilescreen/transparent_bubble.png",
		"res://assets/images/candytrap/bubble_asset.png",
		"res://assets/images/misc/bubble_icon.png"
	]
	
	var img: Image = null
	for p in paths:
		var gp = ProjectSettings.globalize_path(p)
		if FileAccess.file_exists(gp):
			img = Image.load_from_file(gp)
			if img and not img.is_empty():
				_bubble_tex = ImageTexture.create_from_image(img)
				break
				
	if not _bubble_tex:
		for p in paths:
			_bubble_tex = UIHelper.load_texture_safe(p)
			if _bubble_tex:
				img = _bubble_tex.get_image()
				if img and not img.is_empty():
					break

	if img and not img.is_empty():
		# Generate precise BitMap click mask for TextureButton so only the visible bubble registers clicks
		var mask = BitMap.new()
		mask.create_from_image_alpha(img, 0.12)
		_bubble_click_mask = mask
		
		# Find visible bubble diameter (alpha >= 0.12) to calculate true collision radius
		var w = img.get_width()
		var h = img.get_height()
		var min_x = w
		var max_x = 0
		var min_y = h
		var max_y = 0
		for y in range(h):
			for x in range(w):
				if img.get_pixel(x, y).a >= 0.12:
					if x < min_x: min_x = x
					if x > max_x: max_x = x
					if y < min_y: min_y = y
					if y > max_y: max_y = y
		if max_x > min_x and max_y > min_y:
			var true_dia = min(float(max_x - min_x), float(max_y - min_y))
			_bubble_radius_ratio = clampf((true_dia * 0.5) / float(w), 0.32, 0.42)
		else:
			_bubble_radius_ratio = 0.38
	else:
		_bubble_radius_ratio = 0.38

static func _ensure_bubble_title_texture() -> Texture2D:
	if _cached_bubble_title_tex and is_instance_valid(_cached_bubble_title_tex):
		return _cached_bubble_title_tex
		
	var path = "res://assets/images/popbubblemini/bubble_pop_title.png"
	# Exported builds only contain the imported texture, so load through the resource system first
	var imported_tex = UIHelper.load_texture_safe(path)
	if imported_tex:
		_cached_bubble_title_tex = imported_tex
		return _cached_bubble_title_tex
	var global_path = ProjectSettings.globalize_path(path)
	
	if FileAccess.file_exists(global_path):
		var img = Image.load_from_file(global_path)
		if img and not img.is_empty():
			_cached_bubble_title_tex = ImageTexture.create_from_image(img)
			return _cached_bubble_title_tex
			
	# Extract from screens/41-bubble-pop-play.png (top title has pure 3D "BUBBLE POP")
	var screen_tex = UIHelper.load_texture_safe("res://screens/41-bubble-pop-play.png")
	if not screen_tex:
		screen_tex = UIHelper.load_texture_safe("res://screens/34-bubblepop-play.png")
		
	if screen_tex:
		var full_img = screen_tex.get_image()
		if full_img and not full_img.is_empty():
			var iw = full_img.get_width()
			var ih = full_img.get_height()
			var rx = int(iw * 0.22)
			var ry = int(ih * 0.038)
			var rw = int(iw * 0.56)
			var rh = int(ih * 0.056)
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
					# Background is light sky blue (lum >= 0.70). Outline is dark navy (lum <= 0.38).
					var is_outline = (lum <= 0.38) or (col.b < 0.65 and col.r < 0.25 and col.g < 0.40)
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
				_cached_bubble_title_tex = ImageTexture.create_from_image(cropped)
				return _cached_bubble_title_tex
	return null

func _ready():
	anchors_preset = Control.PRESET_FULL_RECT
	anchor_right = 1.0
	anchor_bottom = 1.0
	_build_ui()
	_relayout()
	var diff = GameState.get_difficulty()
	var spd = 0.7 if diff == "easy" else (1.1 if diff == "medium" else 1.8)
	_start_with_difficulty(spd)

func _notification(what: int):
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_relayout()

func _process(delta: float):
	if not is_playing or is_paused or not play_area:
		return
		
	var area_w = play_area.size.x
	var area_h = play_area.size.y
	if area_w <= 10 or area_h <= 10:
		return
		
	var time_ms = Time.get_ticks_msec() * 0.002
	var min_spd = 40.0 * speed_multiplier
	var max_spd = 120.0 * speed_multiplier
	var wall_margin = 2.0
	
	# 1. Update bubble positions
	for b in active_bubbles:
		if not is_instance_valid(b.get("btn", null)):
			continue
		b["pos"] += b["vel"] * delta

	# 2. Bubble vs Bubble collisions (elastic deflection & position separation based on true visible circle)
	# Run 2 passes to handle cascading multi-bubble interactions cleanly
	var count = active_bubbles.size()
	for _pass in range(2):
		for i in range(count):
			var b1 = active_bubbles[i]
			if not is_instance_valid(b1.get("btn", null)):
				continue
			var r1 = b1["size"] * _bubble_radius_ratio
			var c1 = b1["pos"] + Vector2(b1["size"] * 0.5, b1["size"] * 0.5)
			
			for j in range(i + 1, count):
				var b2 = active_bubbles[j]
				if not is_instance_valid(b2.get("btn", null)):
					continue
				var r2 = b2["size"] * _bubble_radius_ratio
				var c2 = b2["pos"] + Vector2(b2["size"] * 0.5, b2["size"] * 0.5)
				
				var delta_pos = c2 - c1
				var dist = delta_pos.length()
				var min_dist = r1 + r2
				
				if dist < min_dist:
					# Collision detected! Separate them so visible bubbles touch without overlapping
					var normal = Vector2.RIGHT
					if dist > 0.0001:
						normal = delta_pos / dist
					else:
						var ang = randf() * TAU
						normal = Vector2(cos(ang), sin(ang))
						dist = 0.0001
					
					var overlap = min_dist - dist
					var push = normal * (overlap * 0.5)
					b1["pos"] -= push
					b2["pos"] += push
					c1 -= push
					c2 += push
					
					# Elastic velocity collision response
					var vel_rel = b2["vel"] - b1["vel"]
					var vel_along_norm = vel_rel.dot(normal)
					
					# Only apply bounce impulse if bubbles are moving towards each other
					if vel_along_norm < 0.0:
						var m1 = r1 * r1
						var m2 = r2 * r2
						var restitution = 0.98
						var impulse_mag = -(1.0 + restitution) * vel_along_norm / (1.0 / m1 + 1.0 / m2)
						var impulse = normal * impulse_mag
						b1["vel"] -= impulse / m1
						b2["vel"] += impulse / m2
						
						# Maintain lively speed range
						var spd1 = b1["vel"].length()
						if spd1 < 0.001:
							b1["vel"] = -normal * min_spd
						elif spd1 < min_spd:
							b1["vel"] = b1["vel"].normalized() * min_spd
						elif spd1 > max_spd:
							b1["vel"] = b1["vel"].normalized() * max_spd
							
						var spd2 = b2["vel"].length()
						if spd2 < 0.001:
							b2["vel"] = normal * min_spd
						elif spd2 < min_spd:
							b2["vel"] = b2["vel"].normalized() * min_spd
						elif spd2 > max_spd:
							b2["vel"] = b2["vel"].normalized() * max_spd

	# 3. Wall collisions and visual position updates
	for b in active_bubbles:
		var btn = b.get("btn", null)
		if not is_instance_valid(btn):
			continue
			
		var b_size = b["size"]
		var r = b_size * _bubble_radius_ratio
		var half_sz = b_size * 0.5
		var cx = b["pos"].x + half_sz
		var cy = b["pos"].y + half_sz
		
		# Bounce off left/right walls based on actual visible bubble edge
		if cx - r <= wall_margin:
			cx = wall_margin + r
			b["pos"].x = cx - half_sz
			b["vel"].x = abs(b["vel"].x)
		elif cx + r >= area_w - wall_margin:
			cx = area_w - wall_margin - r
			b["pos"].x = cx - half_sz
			b["vel"].x = -abs(b["vel"].x)
			
		# Bounce off top/bottom walls based on actual visible bubble edge
		if cy - r <= wall_margin:
			cy = wall_margin + r
			b["pos"].y = cy - half_sz
			b["vel"].y = abs(b["vel"].y)
		elif cy + r >= area_h - wall_margin:
			cy = area_h - wall_margin - r
			b["pos"].y = cy - half_sz
			b["vel"].y = -abs(b["vel"].y)
			
		# Subtle organic wobble
		var wobble_x = sin(time_ms + b["wobble"]) * 1.5
		var wobble_y = cos(time_ms * 0.8 + b["wobble"]) * 1.5
		btn.position = b["pos"] + Vector2(wobble_x, wobble_y)

func _build_ui():
	# Clean blue background matching screens/41-bubble-pop-play.png
	var bg = TextureRect.new()
	UIHelper.setup_fullscreen_bg(bg)
	var grad = Gradient.new()
	grad.colors = PackedColorArray([Color(0.81, 0.92, 0.98, 1.0), Color(0.70, 0.88, 0.98, 1.0)])
	var grad_tex = GradientTexture2D.new()
	grad_tex.gradient = grad
	grad_tex.fill_from = Vector2(0.5, 0.0)
	grad_tex.fill_to = Vector2(0.5, 1.0)
	bg.texture = grad_tex
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	
	# Top Right Circular Pause Button
	pause_btn = UIHelper.create_circular_pause_button(Vector2(46, 46))
	pause_btn.pressed.connect(_on_pause_pressed)
	add_child(pause_btn)
	
	# Title: Graphic BUBBLE POP Image Title
	var title_tex = _ensure_bubble_title_texture()
	if title_tex:
		title_rect = TextureRect.new()
		title_rect.texture = title_tex
		title_rect.custom_minimum_size = Vector2(250, 48)
		title_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		title_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		title_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(title_rect)
	else:
		title_fallback_lbl = Label.new()
		title_fallback_lbl.text = "BUBBLE POP"
		title_fallback_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UIHelper.apply_bubbly_label(title_fallback_lbl, 24, Color.WHITE, true)
		title_fallback_lbl.add_theme_color_override("font_shadow_color", Color(0.12, 0.40, 0.70))
		title_fallback_lbl.add_theme_constant_override("shadow_offset_x", 2)
		title_fallback_lbl.add_theme_constant_override("shadow_offset_y", 2)
		add_child(title_fallback_lbl)
	
	# Stats Row: Bubble count pill, 0:30 timer capsule, Rewards pill (Coins, Stars, Gifts)
	stats_row = HBoxContainer.new()
	stats_row.alignment = BoxContainer.ALIGNMENT_CENTER
	stats_row.add_theme_constant_override("separation", 10)
	add_child(stats_row)
	
	var pop_pill = PanelContainer.new()
	pop_pill.custom_minimum_size = Vector2(76, 40)
	var pp_style = UIHelper.create_bubbly_panel(20, Color.WHITE, Color(1, 1, 1, 0.90), 2.5)
	pp_style.shadow_color = Color(0.15, 0.35, 0.60, 0.18)
	pp_style.shadow_size = 5
	pp_style.shadow_offset = Vector2(0, 2)
	pop_pill.add_theme_stylebox_override("panel", pp_style)
	var pop_hbox = HBoxContainer.new()
	pop_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	pop_hbox.add_theme_constant_override("separation", 6)
	pop_pill.add_child(pop_hbox)
	
	var b_icon = TextureRect.new()
	b_icon.texture = UIHelper.load_texture_safe("res://assets/images/candytrap/bubble_icon.png")
	if not b_icon.texture:
		b_icon.texture = UIHelper.load_texture_safe("res://assets/images/misc/bubble_icon.png")
	b_icon.custom_minimum_size = Vector2(22, 22)
	b_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	b_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pop_hbox.add_child(b_icon)
	
	bubble_count_label = Label.new()
	bubble_count_label.text = "0"
	bubble_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bubble_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(bubble_count_label, 16, Color(0.12, 0.36, 0.60), true)
	pop_hbox.add_child(bubble_count_label)
	stats_row.add_child(pop_pill)
	
	var timer_pill = PanelContainer.new()
	timer_pill.custom_minimum_size = Vector2(115, 42)
	var tp_style = UIHelper.create_bubbly_panel(21, Color.WHITE, Color(1, 1, 1, 0.90), 2.5)
	tp_style.shadow_color = Color(0.15, 0.35, 0.60, 0.18)
	tp_style.shadow_size = 5
	tp_style.shadow_offset = Vector2(0, 2)
	timer_pill.add_theme_stylebox_override("panel", tp_style)
	time_label = Label.new()
	time_label.text = "0:30"
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(time_label, 22, Color(0.12, 0.36, 0.60), true)
	timer_pill.add_child(time_label)
	stats_row.add_child(timer_pill)
	
	var rew_pill = PanelContainer.new()
	rew_pill.custom_minimum_size = Vector2(165, 40)
	var rp_style = UIHelper.create_bubbly_panel(20, Color.WHITE, Color(1, 1, 1, 0.90), 2.5)
	rp_style.shadow_color = Color(0.15, 0.35, 0.60, 0.18)
	rp_style.shadow_size = 5
	rp_style.shadow_offset = Vector2(0, 2)
	rew_pill.add_theme_stylebox_override("panel", rp_style)
	var rew_hbox = HBoxContainer.new()
	rew_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	rew_hbox.add_theme_constant_override("separation", 6)
	rew_pill.add_child(rew_hbox)
	
	var coin_ic = TextureRect.new()
	coin_ic.texture = UIHelper.load_texture_safe("res://assets/images/cardmatchmini/gold_tooth_coin.png")
	if not coin_ic.texture:
		coin_ic.texture = UIHelper.load_texture_safe("res://assets/images/shop/gold_tooth_coin.png")
	coin_ic.custom_minimum_size = Vector2(18, 18)
	coin_ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	coin_ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin_ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rew_hbox.add_child(coin_ic)
	
	coin_lbl = Label.new()
	coin_lbl.text = "0"
	coin_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UIHelper.apply_bubbly_label(coin_lbl, 13, Color(0.12, 0.36, 0.60), true)
	rew_hbox.add_child(coin_lbl)
	
	var star_ic = TextureRect.new()
	star_ic.texture = UIHelper.load_texture_safe("res://assets/images/cardmatchmini/purple_star_points.png")
	if not star_ic.texture:
		star_ic.texture = UIHelper.load_texture_safe("res://assets/images/shop/purple_star_points.png")
	star_ic.custom_minimum_size = Vector2(18, 18)
	star_ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	star_ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	star_ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rew_hbox.add_child(star_ic)
	
	star_lbl = Label.new()
	star_lbl.text = "0"
	star_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UIHelper.apply_bubbly_label(star_lbl, 13, Color(0.12, 0.36, 0.60), true)
	rew_hbox.add_child(star_lbl)
	
	var gift_ic = TextureRect.new()
	gift_ic.texture = _get_gift_icon_texture()
	gift_ic.custom_minimum_size = Vector2(18, 18)
	gift_ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	gift_ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gift_ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rew_hbox.add_child(gift_ic)
	
	gift_lbl = Label.new()
	gift_lbl.text = "0"
	gift_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UIHelper.apply_bubbly_label(gift_lbl, 13, Color(0.12, 0.36, 0.60), true)
	rew_hbox.add_child(gift_lbl)
	stats_row.add_child(rew_pill)
	
	# Main Play Window / Tray (pop_bubble_back.png 3D device frame)
	tray = Control.new()
	tray.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(tray)
	
	var tray_bg = TextureRect.new()
	tray_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	tray_bg.anchor_right = 1.0
	tray_bg.anchor_bottom = 1.0
	tray_bg.texture = UIHelper.load_texture_safe("res://assets/images/popbubblemini/pop_bubble_back.png")
	if not tray_bg.texture:
		var tray_panel = Panel.new()
		tray_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		tray_panel.add_theme_stylebox_override("panel", UIHelper.create_bubbly_panel(38, Color(0.45, 0.65, 0.85, 0.5), Color(0.9, 0.95, 1.0, 0.9), 4))
		tray.add_child(tray_panel)
	else:
		tray_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tray_bg.stretch_mode = TextureRect.STRETCH_SCALE
		tray.add_child(tray_bg)
	
	play_area = Control.new()
	play_area.clip_contents = true
	tray.add_child(play_area)
	
	timer = Timer.new()
	timer.wait_time = 1.0
	timer.timeout.connect(_on_tick)
	add_child(timer)

func _relayout():
	var safe_sz = UIHelper.get_viewport_safe_size(self)
	var cur_w = safe_sz.x
	var cur_h = safe_sz.y
	var is_tablet = cur_w >= 560
	
	if pause_btn:
		pause_btn.position = Vector2(cur_w - 56, 12)
	# Title, stats and bubble tray drop below the notch on iPhone; pause stays in the corner
	var notch_shift = max(0.0, UIHelper.safe_top - 4.0)
		
	if title_rect:
		var title_w = min(cur_w - 110.0, 280.0)
		title_rect.position = Vector2((cur_w - title_w) * 0.5, 10 + notch_shift)
		title_rect.size = Vector2(title_w, 48)
	elif title_fallback_lbl:
		var title_w = min(cur_w - 110.0, 280.0)
		title_fallback_lbl.position = Vector2((cur_w - title_w) * 0.5, 12 + notch_shift)
		title_fallback_lbl.size = Vector2(title_w, 40)
		
	if stats_row:
		var stat_w = min(cur_w - 32.0, 420.0)
		stats_row.position = Vector2((cur_w - stat_w) * 0.5, 68 + notch_shift)
		stats_row.size = Vector2(stat_w, 44)
		
	if tray:
		# Maintain native ~1:1.36 aspect ratio of pop_bubble_back so borders are never clipped
		var max_tray_w = min(cur_w - (36.0 if is_tablet else 24.0), 480.0 if is_tablet else 380.0)
		var max_tray_h = min(cur_h - 134.0 - notch_shift, 680.0 if is_tablet else 550.0)
		var tray_w = max_tray_w
		var tray_h = tray_w * 1.36
		if tray_h > max_tray_h:
			tray_h = max_tray_h
			tray_w = tray_h / 1.36
		tray.size = Vector2(tray_w, tray_h)
		tray.position = Vector2((cur_w - tray_w) * 0.5, 124.0 + notch_shift)
		
		if play_area:
			# Recessed inner screen area inside pop_bubble_back bezel (expanded outward by ~5px horizontally & vertically)
			var pad_x = max(2.0, tray_w * 0.08 - 5.0)
			var pad_top = max(2.0, tray_h * 0.06 - 5.0)
			var pad_bot = max(4.0, tray_h * 0.10 - 5.0)
			play_area.position = Vector2(pad_x, pad_top)
			play_area.size = Vector2(tray_w - pad_x * 2.0, tray_h - pad_top - pad_bot)

func _show_difficulty_modal():
	if difficulty_modal and is_instance_valid(difficulty_modal):
		difficulty_modal.queue_free()
		
	var safe_sz = UIHelper.get_viewport_safe_size(self)
	var dlg = UIHelper.create_modal_dialog(self, 100)
	difficulty_modal = dlg["overlay"]
	var center = dlg["center"]
	
	var max_card_w = min(safe_sz.x - 40.0, (safe_sz.y - 40.0) / 1.50)
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
	heading_box.add_theme_constant_override("separation", 4)
	heading_box.alignment = BoxContainer.ALIGNMENT_CENTER
	
	var title_lbl = Label.new()
	title_lbl.text = "POP THE BUBBLES"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(title_lbl, 22, Color.WHITE, true)
	title_lbl.add_theme_color_override("font_shadow_color", Color(0.12, 0.40, 0.70))
	title_lbl.add_theme_constant_override("shadow_offset_x", 2)
	title_lbl.add_theme_constant_override("shadow_offset_y", 2)
	heading_box.add_child(title_lbl)
	
	var sub_lbl = Label.new()
	sub_lbl.text = "CHOOSE A DIFFICULTY"
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(sub_lbl, 11, Color(0.92, 0.97, 1.0), true)
	heading_box.add_child(sub_lbl)
	vbox.add_child(heading_box)
	
	var easy_btn = _create_difficulty_button("EASY", "GENTLE AND SLOW", Color(0.16, 0.78, 0.42), func():
		_start_with_difficulty(0.7)
	)
	vbox.add_child(easy_btn)
	
	var med_btn = _create_difficulty_button("MEDIUM", "A FAIR CHALLENGE", Color(0.98, 0.54, 0.12), func():
		_start_with_difficulty(1.1)
	)
	vbox.add_child(med_btn)
	
	var hard_btn = _create_difficulty_button("HARD", "FAST AND FIERCE", Color(0.72, 0.42, 0.94), func():
		_start_with_difficulty(1.8)
	)
	vbox.add_child(hard_btn)
	
	var foot_lbl = Label.new()
	foot_lbl.text = "Bubbles drift slowly on Easy and zip about on Hard."
	foot_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UIHelper.apply_bubbly_label(foot_lbl, 10, Color.WHITE, true)
	vbox.add_child(foot_lbl)
	
	# Pop-in animation
	card.pivot_offset = Vector2(modal_info["width"] * 0.5, modal_info["height"] * 0.5)
	card.scale = Vector2(0.85, 0.85)
	card.modulate.a = 0.0
	var tw = card.create_tween().set_parallel(true)
	tw.tween_property(card, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "modulate:a", 1.0, 0.15)

func _create_difficulty_button(level: String, subtitle: String, bg_color: Color, on_click: Callable) -> Control:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(0, 52.0)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.focus_mode = Control.FOCUS_NONE
	
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = bg_color
	normal_style.border_color = Color.WHITE
	normal_style.border_width_left = 3
	normal_style.border_width_right = 3
	normal_style.border_width_top = 3
	normal_style.border_width_bottom = 3
	normal_style.set_corner_radius_all(30)
	normal_style.shadow_color = Color(0.08, 0.16, 0.30, 0.35)
	normal_style.shadow_size = 5
	normal_style.shadow_offset = Vector2(0, 3)
	btn.add_theme_stylebox_override("normal", normal_style)
	btn.add_theme_stylebox_override("hover", normal_style)
	btn.add_theme_stylebox_override("pressed", normal_style)
	
	var hbox = HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 14)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(hbox)
	
	var l_lbl = Label.new()
	l_lbl.text = level
	UIHelper.apply_bubbly_label(l_lbl, 19, Color.WHITE, true)
	l_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(l_lbl)
	
	var r_lbl = Label.new()
	r_lbl.text = subtitle
	UIHelper.apply_bubbly_label(r_lbl, 11, Color(1, 1, 1, 0.95), true)
	r_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(r_lbl)
	
	btn.pressed.connect(func():
		AudioManager.play_sfx("click")
		on_click.call()
	)
	return btn

func _start_with_difficulty(spd_mult: float):
	speed_multiplier = spd_mult
	if difficulty_modal:
		difficulty_modal.queue_free()
		difficulty_modal = null
	_start_game()

func _start_game():
	bubbles_popped = 0
	coins_earned = 0
	points_earned = 0
	gifts_earned = 0
	gift_contents.clear()
	gifts_opened = false
	time_left = 30
	is_playing = true
	is_paused = false
	
	# Random gift times: 1 in first 10s (29..21), 1 in second 10s (20..11), 1 in last 10s (10..2)
	scheduled_gift_times = [
		randi_range(21, 29),
		randi_range(11, 20),
		randi_range(2, 10)
	]
	gift_slots_spawned = [false, false, false]
	
	bubble_count_label.text = "0"
	time_label.text = "0:30"
	coin_lbl.text = "0"
	star_lbl.text = "0"
	gift_lbl.text = "0"
	
	for b in active_bubbles:
		if is_instance_valid(b.get("btn", null)):
			b["btn"].queue_free()
	active_bubbles.clear()
	
	# Spawn 6 initial bubbles inside window
	for i in range(6):
		_spawn_bubble()
		
	timer.start()

func _spawn_bubble(force_gift: bool = false):
	if not is_playing or not play_area: return
	
	var area_w = play_area.size.x if play_area.size.x > 50 else 350.0
	var area_h = play_area.size.y if play_area.size.y > 50 else 580.0
	
	_ensure_bubble_resources()
	var b_size = randf_range(52.0, 82.0)
	var btn = TextureButton.new()
	btn.texture_normal = _bubble_tex
	if not btn.texture_normal:
		btn.texture_normal = UIHelper.load_texture_safe("res://assets/images/createprofilescreen/transparent_bubble.png")
	if _bubble_click_mask:
		btn.texture_click_mask = _bubble_click_mask
		
	btn.custom_minimum_size = Vector2(b_size, b_size)
	btn.size = Vector2(b_size, b_size)
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn.pivot_offset = Vector2(b_size * 0.5, b_size * 0.5)
	
	# Try to find a non-overlapping spawn position inside play_area based on actual radius
	var r = b_size * _bubble_radius_ratio
	var half_sz = b_size * 0.5
	var start_pos = Vector2.ZERO
	var found_spot = false
	var wall_margin = 2.0
	for attempt in range(25):
		var test_cx = randf_range(wall_margin + r, area_w - wall_margin - r)
		var test_cy = randf_range(wall_margin + r, area_h - wall_margin - r)
		var test_c = Vector2(test_cx, test_cy)
		var collides = false
		for other in active_bubbles:
			if not is_instance_valid(other.get("btn", null)):
				continue
			var other_r = other["size"] * _bubble_radius_ratio
			var other_c = other["pos"] + Vector2(other["size"] * 0.5, other["size"] * 0.5)
			if test_c.distance_to(other_c) < (r + other_r + 3.0):
				collides = true
				break
		if not collides:
			start_pos = test_c - Vector2(half_sz, half_sz)
			found_spot = true
			break
			
	if not found_spot:
		var test_cx = randf_range(wall_margin + r, area_w - wall_margin - r)
		var test_cy = randf_range(wall_margin + r, area_h - wall_margin - r)
		start_pos = Vector2(test_cx - half_sz, test_cy - half_sz)
	btn.position = start_pos
	
	# Random direction and speed
	var base_spd = randf_range(50.0, 95.0) * speed_multiplier
	var angle = randf_range(0.0, TAU)
	var vel = Vector2(cos(angle), sin(angle)) * base_spd
	
	var b_dict = {
		"btn": btn,
		"pos": start_pos,
		"vel": vel,
		"size": b_size,
		"wobble": randf_range(0.0, 10.0),
		"is_gift": false
	}
	
	if force_gift:
		_attach_gift_to_bubble(b_dict)
	
	btn.pressed.connect(func(): _pop_bubble(b_dict))
	play_area.add_child(btn)
	active_bubbles.append(b_dict)
	
	# Bubble entrance scale pop
	btn.scale = Vector2(0.2, 0.2)
	var tw = btn.create_tween()
	tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _check_and_spawn_scheduled_gift() -> void:
	if not is_playing or is_paused: return
	
	# Check if any gift is already floating on screen
	var has_gift_bubble = false
	for b in active_bubbles:
		if b.get("is_gift", false) and is_instance_valid(b.get("btn", null)):
			has_gift_bubble = true
			break
			
	if has_gift_bubble:
		return
		
	# Check each of the 3 10-second interval slots (1-10s, 11-20s, 21-30s)
	for slot in range(3):
		if not gift_slots_spawned[slot]:
			if time_left <= scheduled_gift_times[slot]:
				gift_slots_spawned[slot] = true
				_make_bubble_gift()
				break

func _make_bubble_gift() -> void:
	# Pick an existing non-gift bubble in play_area and turn it into a gift bubble
	var candidate_bubbles: Array[Dictionary] = []
	for b in active_bubbles:
		if not b.get("is_gift", false) and is_instance_valid(b.get("btn", null)):
			candidate_bubbles.append(b)
			
	if not candidate_bubbles.is_empty():
		var chosen = candidate_bubbles[randi() % candidate_bubbles.size()]
		_attach_gift_to_bubble(chosen)
	else:
		# If no bubbles currently available, spawn a new gift bubble
		_spawn_bubble(true)

func _attach_gift_to_bubble(b_dict: Dictionary) -> void:
	var btn: TextureButton = b_dict.get("btn", null)
	if not is_instance_valid(btn): return
	if b_dict.get("is_gift", false): return
	
	b_dict["is_gift"] = true
	var b_size: float = b_dict.get("size", 64.0)
	
	var gift_icon = TextureRect.new()
	gift_icon.name = "GiftIcon"
	gift_icon.texture = _get_gift_icon_texture()
	gift_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gift_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var g_sz = b_size * 0.52
	gift_icon.custom_minimum_size = Vector2(g_sz, g_sz)
	gift_icon.size = Vector2(g_sz, g_sz)
	gift_icon.position = Vector2((b_size - g_sz) * 0.5, (b_size - g_sz) * 0.5)
	gift_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(gift_icon)
	
	# Scale pop effect on the gift appearing inside the bubble
	gift_icon.scale = Vector2.ZERO
	gift_icon.pivot_offset = Vector2(g_sz * 0.5, g_sz * 0.5)
	var tw = gift_icon.create_tween()
	tw.tween_property(gift_icon, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _pop_bubble(b_dict: Dictionary):
	if not is_playing or is_paused: return
	var btn: TextureButton = b_dict.get("btn", null)
	if not is_instance_valid(btn): return
	
	active_bubbles.erase(b_dict)
	AudioManager.play_sfx("pop")
	
	bubbles_popped += 1
	bubble_count_label.text = str(bubbles_popped)
	
	# Base rewards per pop
	var pts_add = 10
	var coins_add = 2
	points_earned += pts_add
	coins_earned += coins_add
	
	# Gift drop (only when popping a bubble with a gift inside)
	var is_surprise = b_dict.get("is_gift", false)
	if is_surprise and gift_contents.size() < 3:
		_trigger_surprise_drop(b_dict["pos"])
		
	coin_lbl.text = str(coins_earned)
	star_lbl.text = str(points_earned)
	
	# Pop Animation
	var tw = btn.create_tween()
	tw.tween_property(btn, "scale", Vector2(1.4, 1.4), 0.08)
	tw.tween_property(btn, "modulate:a", 0.0, 0.08)
	tw.tween_callback(func():
		if is_instance_valid(btn):
			btn.queue_free()
	)
	
	# Spawn replacement bubble inside window
	var t = get_tree().create_timer(0.2)
	t.timeout.connect(func():
		if is_playing and active_bubbles.size() < 7:
			_spawn_bubble()
	)

func _trigger_surprise_drop(pop_pos: Vector2):
	AudioManager.play_sfx("sparkle")
	var rewards_pool = ["Streak Freeze", "+250 Coins", "+200 Points", "Fluoride Shield"]
	var pick = rewards_pool[randi() % rewards_pool.size()]
	gift_contents.append(pick)
	gifts_earned = gift_contents.size()
	gift_lbl.text = str(gifts_earned)
	
	# Floating animated gift notification with gifticon.png and badge
	var fl_box = VBoxContainer.new()
	fl_box.alignment = BoxContainer.ALIGNMENT_CENTER
	fl_box.add_theme_constant_override("separation", 2)
	fl_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fl_box.custom_minimum_size = Vector2(100, 68)
	fl_box.size = Vector2(100, 68)
	fl_box.position = pop_pos - Vector2(50, 34)
	fl_box.pivot_offset = Vector2(50, 34)
	fl_box.z_index = 30
	
	var g_img = TextureRect.new()
	g_img.texture = _get_gift_icon_texture()
	g_img.custom_minimum_size = Vector2(38, 38)
	g_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	g_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	g_img.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	g_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fl_box.add_child(g_img)
	
	var fl_badge = PanelContainer.new()
	var fb_st = UIHelper.create_bubbly_panel(10, Color(1.0, 0.84, 0.20), Color.WHITE, 1.5)
	fb_st.shadow_size = 4
	fb_st.shadow_color = Color(0.1, 0.2, 0.4, 0.3)
	fl_badge.add_theme_stylebox_override("panel", fb_st)
	fl_badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	
	var fl_lbl = Label.new()
	fl_lbl.text = "Gift Found!"
	UIHelper.apply_bubbly_label(fl_lbl, 11, Color(0.35, 0.18, 0.02), true)
	fl_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fl_badge.add_child(fl_lbl)
	fl_box.add_child(fl_badge)
	
	play_area.add_child(fl_box)
	
	fl_box.scale = Vector2(0.3, 0.3)
	var tw = fl_box.create_tween()
	tw.set_parallel(true)
	tw.tween_property(fl_box, "scale", Vector2(1.15, 1.15), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(fl_box, "position:y", pop_pos.y - 55.0, 0.85).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(fl_box, "modulate:a", 0.0, 0.25)
	tw.tween_callback(func():
		if is_instance_valid(fl_box):
			fl_box.queue_free()
	)

func _on_pause_pressed():
	AudioManager.play_sfx("click")
	is_paused = true
	
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
	
	var btn_w = card_w - 48.0
	var resume_btn = UIHelper.create_themed_button("resume", Vector2(btn_w, 50))
	if not resume_btn.texture_normal:
		resume_btn = UIHelper.create_bubbly_button("RESUME", Color(0.16, 0.78, 0.42))
		resume_btn.custom_minimum_size = Vector2(btn_w, 48)
	resume_btn.pressed.connect(func():
		AudioManager.play_sfx("click")
		is_paused = false
		if pause_modal and is_instance_valid(pause_modal):
			pause_modal.queue_free()
			pause_modal = null
	)
	vbox.add_child(resume_btn)
	
	var restart_btn = UIHelper.create_themed_button("restart", Vector2(btn_w, 50))
	restart_btn.custom_minimum_size = Vector2(btn_w, 48)
	restart_btn.pressed.connect(func():
		AudioManager.play_sfx("click")
		is_paused = false
		if pause_modal and is_instance_valid(pause_modal):
			pause_modal.queue_free()
			pause_modal = null
		var diff = GameState.get_difficulty()
		var spd = 0.7 if diff == "easy" else (1.1 if diff == "medium" else 1.8)
		_start_with_difficulty(spd)
	)
	vbox.add_child(restart_btn)
	
	var quit_btn = UIHelper.create_themed_button("exit", Vector2(btn_w, 50))
	if not quit_btn.texture_normal:
		quit_btn = UIHelper.create_bubbly_button("EXIT GAME", Color(0.90, 0.32, 0.32))
		quit_btn.custom_minimum_size = Vector2(btn_w, 48)
	quit_btn.pressed.connect(func():
		AudioManager.play_sfx("click")
		is_playing = false
		timer.stop()
		if pause_modal and is_instance_valid(pause_modal):
			pause_modal.queue_free()
			pause_modal = null
		GameState.save_game()
		game_ended.emit()
	)
	vbox.add_child(quit_btn)
	
	# Pop-in animation
	var card_h = modal_info["height"] if modal_info.has("height") else card_w * 1.50
	card.pivot_offset = Vector2(card_w * 0.5, card_h * 0.5)
	card.scale = Vector2(0.85, 0.85)
	card.modulate.a = 0.0
	var tw = card.create_tween().set_parallel(true)
	tw.tween_property(card, "scale", Vector2.ONE, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "modulate:a", 1.0, 0.15)

func _on_tick():
	if not is_playing or is_paused: return
	
	time_left -= 1
	time_label.text = "0:%02d" % time_left
	
	_check_and_spawn_scheduled_gift()
	
	if time_left <= 0:
		is_playing = false
		timer.stop()
		_on_game_over()

func _on_game_over():
	# Base awards
	GameState.add_points(points_earned)
	GameState.add_molar_coins(coins_earned)
	
	var p = GameState.get_active_profile()
	if not p.is_empty():
		var lmg = p.get("lastMiniGame", {})
		lmg["bubble"] = Time.get_unix_time_from_system()
		p["lastMiniGame"] = lmg
		var prev_best = p.get("bestBubblePop", 0)
		if bubbles_popped > prev_best:
			p["bestBubblePop"] = bubbles_popped
	GameState.save_game()
		
	AudioManager.play_sfx("cheer")
	_show_game_over_modal()
	
static func _get_gift_icon_texture() -> Texture2D:
	var paths = [
		"res://assets/images/popbubblemini/gifticon.png",
		"res://assets/images/misc/gifticon.png",
		"res://assets/images/general/gifticon.png",
		"res://assets/images/buttons/gifticon.png",
		".godot/buttons/gifticon.png"
	]
	for p in paths:
		var tex = UIHelper.load_texture_safe(p)
		if tex:
			return tex
	return null

static func _get_reward_icon_texture(item_name: String) -> Texture2D:
	if item_name.contains("Shield"):
		return UIHelper.load_texture_safe("res://assets/images/shop/fluorideshield.png")
	elif item_name.contains("Freeze"):
		return UIHelper.load_texture_safe("res://assets/images/shop/streakfreeze.png")
	elif item_name.contains("Coin"):
		return UIHelper.load_texture_safe("res://assets/images/shop/gold_tooth_coin.png")
	elif item_name.contains("Point"):
		return UIHelper.load_texture_safe("res://assets/images/shop/purple_star_points.png")
	return _get_gift_icon_texture()

func _show_game_over_modal():
	if win_modal and is_instance_valid(win_modal):
		win_modal.queue_free()
		
	var safe_sz = UIHelper.get_viewport_safe_size(self)
	var dlg = UIHelper.create_modal_dialog(self, 200)
	win_modal = dlg["overlay"]
	var center = dlg["center"]
	
	var max_card_w = min(safe_sz.x - 36.0, (safe_sz.y - 40.0) / 1.50)
	# Window size reduced by 20%
	var card_w = clamp(max_card_w, 310.0, 370.0)
	var modal_info = UIHelper.create_modal_card(card_w, "portrait")
	var card = modal_info["root"]
	card.custom_minimum_size = Vector2(card_w, card_w * 1.50)
	card.size = Vector2(card_w, card_w * 1.50)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(card)
	
	modal_info["content"].add_theme_constant_override("margin_left", 18)
	modal_info["content"].add_theme_constant_override("margin_right", 18)
	modal_info["content"].add_theme_constant_override("margin_top", 18)
	modal_info["content"].add_theme_constant_override("margin_bottom", 18)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)
	modal_info["content"].add_child(vbox)
	
	_populate_win_modal_vbox(card, vbox, card_w)
	
	# Pop-in animation
	var card_h = modal_info["height"] if modal_info.has("height") else card_w * 1.50
	card.pivot_offset = Vector2(card_w * 0.5, card_h * 0.5)
	card.scale = Vector2(0.85, 0.85)
	card.modulate.a = 0.0
	var tw = card.create_tween().set_parallel(true)
	tw.tween_property(card, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "modulate:a", 1.0, 0.15)

func _populate_win_modal_vbox(card: Control, vbox: VBoxContainer, card_w: float):
	for c in vbox.get_children():
		c.queue_free()
		
	# Doubled Title
	var title = Label.new()
	title.text = "BUBBLES CLEARED!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(title, 22, Color.WHITE, true)
	title.add_theme_color_override("font_shadow_color", Color(0.12, 0.40, 0.70))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	vbox.add_child(title)
	
	# Personal Best calculation
	var p = GameState.get_active_profile()
	var prev_best = p.get("bestBubblePop", 0) if not p.is_empty() else 0
	var is_new_best = bubbles_popped >= prev_best and bubbles_popped > 0
	var best_score = max(prev_best, bubbles_popped)
	
	# Clean white stats card with cute bubble count + personal best + coin & star chips
	var stats_panel = PanelContainer.new()
	var sp_st = UIHelper.create_bubbly_panel(16, Color(1, 1, 1, 0.94), Color.WHITE, 2)
	sp_st.shadow_color = Color(0.12, 0.30, 0.55, 0.15)
	sp_st.shadow_size = 8
	sp_st.shadow_offset = Vector2(0, 3)
	stats_panel.add_theme_stylebox_override("panel", sp_st)
	
	var stats_box = VBoxContainer.new()
	stats_box.add_theme_constant_override("separation", 6)
	
	var score_row = HBoxContainer.new()
	score_row.alignment = BoxContainer.ALIGNMENT_CENTER
	score_row.add_theme_constant_override("separation", 6)
	
	var bub_ic = TextureRect.new()
	bub_ic.texture = _bubble_tex if _bubble_tex else UIHelper.load_texture_safe("res://assets/images/misc/bubble_icon.png")
	bub_ic.custom_minimum_size = Vector2(32, 32)
	bub_ic.size = Vector2(32, 32)
	bub_ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bub_ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	score_row.add_child(bub_ic)
	
	var score_lbl = Label.new()
	score_lbl.text = "Popped: %d Bubbles!" % bubbles_popped
	UIHelper.apply_bubbly_label(score_lbl, 15, Color(0.12, 0.38, 0.65), true)
	score_row.add_child(score_lbl)
	stats_box.add_child(score_row)
	
	var best_row = HBoxContainer.new()
	best_row.alignment = BoxContainer.ALIGNMENT_CENTER
	best_row.add_theme_constant_override("separation", 6)
	
	var best_lbl = Label.new()
	if is_new_best:
		best_lbl.text = "NEW BEST: %d Bubbles!" % best_score
		UIHelper.apply_bubbly_label(best_lbl, 16, Color(0.95, 0.45, 0.10), true)
	else:
		best_lbl.text = "Personal Best: %d Bubbles" % best_score
		UIHelper.apply_bubbly_label(best_lbl, 16, Color(0.80, 0.48, 0.10), true)
	best_row.add_child(best_lbl)
	stats_box.add_child(best_row)
	
	# Doubled 44x44 reward icons
	var rew_row = HBoxContainer.new()
	rew_row.alignment = BoxContainer.ALIGNMENT_CENTER
	rew_row.add_theme_constant_override("separation", 14)
	
	# Coins pill
	var coin_badge = UIHelper.create_reward_badge("res://assets/images/shop/gold_tooth_coin.png", "%d Coins" % coins_earned, Color(0.86, 0.55, 0.05), 116.0, 40.0)
	rew_row.add_child(coin_badge)
	
	# Points pill
	var pt_badge = UIHelper.create_reward_badge("res://assets/images/shop/purple_star_points.png", "%d Points" % points_earned, Color(0.58, 0.28, 0.82), 116.0, 40.0)
	rew_row.add_child(pt_badge)
	
	stats_box.add_child(rew_row)
	stats_panel.add_child(stats_box)
	vbox.add_child(stats_panel)
	
	if gift_contents.size() > 0:
		if not gifts_opened:
			# Unopened state: Centered gift with glowing halo and tap-to-open
			var gift_section = VBoxContainer.new()
			gift_section.name = "GiftSection"
			gift_section.alignment = BoxContainer.ALIGNMENT_CENTER
			gift_section.add_theme_constant_override("separation", 8)
			gift_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			
			var found_lbl = Label.new()
			var g_count = gift_contents.size()
			found_lbl.text = "YOU FOUND %d MYSTERY GIFT%s!" % [g_count, "S" if g_count > 1 else ""]
			found_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			UIHelper.apply_bubbly_label(found_lbl, 13, Color(0.98, 0.58, 0.12), true)
			gift_section.add_child(found_lbl)
			
			var gift_center = CenterContainer.new()
			gift_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			gift_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
			gift_section.add_child(gift_center)
			
			var gift_box_btn = Button.new()
			gift_box_btn.custom_minimum_size = Vector2(120, 118)
			gift_box_btn.flat = true
			gift_box_btn.focus_mode = Control.FOCUS_NONE
			var empty_sb = StyleBoxEmpty.new()
			gift_box_btn.add_theme_stylebox_override("normal", empty_sb)
			gift_box_btn.add_theme_stylebox_override("hover", empty_sb)
			gift_box_btn.add_theme_stylebox_override("pressed", empty_sb)
			gift_center.add_child(gift_box_btn)
			
			# Glow halo behind gift
			var glow = Panel.new()
			glow.size = Vector2(86, 86)
			glow.position = Vector2((120.0 - 86.0) * 0.5, 2.0)
			glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var glow_st = StyleBoxFlat.new()
			glow_st.bg_color = Color(1.0, 0.92, 0.55, 0.40)
			glow_st.set_corner_radius_all(43)
			glow.add_theme_stylebox_override("panel", glow_st)
			gift_box_btn.add_child(glow)
			
			var gift_img = TextureRect.new()
			gift_img.texture = _get_gift_icon_texture()
			gift_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			gift_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			gift_img.custom_minimum_size = Vector2(76, 76)
			gift_img.size = Vector2(76, 76)
			gift_img.position = Vector2((120.0 - 76.0) * 0.5, 6.0)
			gift_img.pivot_offset = Vector2(38, 38)
			gift_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
			gift_box_btn.add_child(gift_img)
			
			# "TAP TO OPEN!" image button
			var tap_badge = UIHelper.create_image_button("res://assets/images/buttons/taptoopen_btn.png", Vector2(110, 30))
			if not tap_badge.texture_normal:
				tap_badge = UIHelper.create_themed_button("taptoopen", Vector2(110, 30))
			tap_badge.position = Vector2((120.0 - 110.0) * 0.5, 84.0)
			tap_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			gift_box_btn.add_child(tap_badge)
			
			# Gentle floating pulse
			var pulse_tw = gift_img.create_tween().set_loops()
			pulse_tw.tween_property(gift_img, "scale", Vector2(1.08, 1.08), 0.5).set_trans(Tween.TRANS_SINE)
			pulse_tw.tween_property(gift_img, "scale", Vector2(1.0, 1.0), 0.5).set_trans(Tween.TRANS_SINE)
			
			var is_opening = [false]
			gift_box_btn.pressed.connect(func():
				if is_opening[0]: return
				is_opening[0] = true
				gift_box_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
				pulse_tw.kill()
				AudioManager.play_sfx("click")
				
				# Vigorously shake the gift box!
				gift_img.pivot_offset = Vector2(38, 38)
				var shake_tw = gift_img.create_tween()
				for _i in range(3):
					shake_tw.tween_property(gift_img, "rotation_degrees", -16.0, 0.06)
					shake_tw.tween_property(gift_img, "rotation_degrees", 16.0, 0.06)
				shake_tw.tween_property(gift_img, "rotation_degrees", 0.0, 0.05)
				
				shake_tw.tween_callback(func():
					AudioManager.play_sfx("unlock")
					
					var pop_tw = gift_img.create_tween().set_parallel(true)
					pop_tw.tween_property(gift_img, "scale", Vector2(1.4, 1.4), 0.12).set_trans(Tween.TRANS_BACK)
					pop_tw.tween_property(gift_img, "modulate:a", 0.0, 0.12)
					if is_instance_valid(tap_badge):
						tap_badge.visible = false
					if is_instance_valid(glow):
						glow.visible = false
					
					for g in gift_contents:
						GameState.apply_gift(g)
					
					gifts_opened = true
					
					pop_tw.chain().tween_callback(func():
						_reveal_opened_gifts_one_by_one(card, vbox, card_w)
					)
				)
			)
			vbox.add_child(gift_section)
		else:
			# If already opened (e.g. on window resize), display static list
			_render_opened_gifts_static(card, vbox, card_w)
	else:
		# No gifts found: directly show enlarged RETURN TO MAP button
		var btn_w = clamp(card_w - 36.0, 220.0, 280.0)
		var cont_btn = UIHelper.create_themed_button("back to main map", Vector2(btn_w, 56))
		if not cont_btn.texture_normal:
			cont_btn = UIHelper.create_bubbly_button("RETURN TO MAP", UIHelper.VIBRANT_GREEN)
		cont_btn.custom_minimum_size = Vector2(btn_w, 56)
		cont_btn.pressed.connect(func():
			AudioManager.play_sfx("click")
			if win_modal and is_instance_valid(win_modal):
				win_modal.queue_free()
				win_modal = null
			game_won.emit()
		)
		vbox.add_child(cont_btn)

func _reveal_opened_gifts_one_by_one(card: Control, vbox: VBoxContainer, card_w: float):
	var gift_sec = vbox.get_node_or_null("GiftSection")
	if gift_sec:
		gift_sec.queue_free()
		
	var tallies: Dictionary = {}
	var display_order: Array[String] = []
	for g in gift_contents:
		if not tallies.has(g):
			display_order.append(g)
			tallies[g] = 0
		tallies[g] += 1
		
	var opened_panel = PanelContainer.new()
	opened_panel.name = "OpenedPanel"
	var op_st = UIHelper.create_bubbly_panel(16, Color.WHITE, Color(0.98, 0.58, 0.12), 2.5)
	op_st.shadow_color = Color(0.12, 0.30, 0.55, 0.18)
	op_st.shadow_size = 10
	op_st.shadow_offset = Vector2(0, 4)
	opened_panel.add_theme_stylebox_override("panel", op_st)
	
	var op_vbox = VBoxContainer.new()
	op_vbox.add_theme_constant_override("separation", 6)
	
	var op_title = Label.new()
	op_title.text = "GIFTS OPENED!"
	op_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(op_title, 14, Color(0.95, 0.48, 0.08), true)
	op_vbox.add_child(op_title)
	
	var items_container = VBoxContainer.new()
	items_container.name = "ItemsContainer"
	items_container.add_theme_constant_override("separation", 6)
	op_vbox.add_child(items_container)
	
	opened_panel.add_child(op_vbox)
	vbox.add_child(opened_panel)
	
	# Smoothly resize modal card to fit revealed gifts + claim button cleanly inside blue background
	var target_h = clamp(card_w * 1.50 + (display_order.size() * 32.0), card_w * 1.50, 560.0)
	var resize_tw = card.create_tween().set_parallel(true)
	resize_tw.tween_property(card, "custom_minimum_size:y", target_h, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	resize_tw.tween_property(card, "size:y", target_h, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# Sequentially pop in each gift item one by one
	var row_w = card_w - 56.0
	for i in range(display_order.size()):
		var item_name = display_order[i]
		var count = tallies[item_name]
		var delay = 0.12 + (i * 0.30)
		
		var t = card.get_tree().create_timer(delay)
		t.timeout.connect(func():
			if not is_instance_valid(items_container): return
			_pop_in_gift_item(items_container, item_name, count, row_w)
		)
		
	# Reveal Claim button after all items have popped in
	var claim_delay = 0.12 + (display_order.size() * 0.30) + 0.20
	var t_claim = card.get_tree().create_timer(claim_delay)
	t_claim.timeout.connect(func():
		if not is_instance_valid(vbox): return
		AudioManager.play_sfx("sparkle")
		var btn_w = clamp(card_w - 24.0, 200.0, 260.0)
		var btn_h = 56.0
		var cont_btn = UIHelper.create_themed_button("back to main map", Vector2(btn_w, btn_h))
		if not cont_btn.texture_normal:
			cont_btn = UIHelper.create_bubbly_button("RETURN TO MAP", UIHelper.VIBRANT_GREEN)
			cont_btn.custom_minimum_size = Vector2(btn_w, 48)
		else:
			cont_btn.custom_minimum_size = Vector2(btn_w, btn_h)
			cont_btn.size = Vector2(btn_w, btn_h)
		cont_btn.pivot_offset = Vector2(btn_w * 0.5, btn_h * 0.5)
		cont_btn.scale = Vector2(0.5, 0.5)
		cont_btn.modulate.a = 0.0
		cont_btn.pressed.connect(func():
			AudioManager.play_sfx("click")
			if win_modal and is_instance_valid(win_modal):
				win_modal.queue_free()
				win_modal = null
			game_won.emit()
		)
		vbox.add_child(cont_btn)
		
		var btn_tw = cont_btn.create_tween()
		btn_tw.set_parallel(true)
		btn_tw.tween_property(cont_btn, "modulate:a", 1.0, 0.10)
		btn_tw.tween_property(cont_btn, "scale", Vector2(1.15, 1.15), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		btn_tw.chain().tween_property(cont_btn, "scale", Vector2(1.0, 1.0), 0.10)
	)

func _pop_in_gift_item(container: VBoxContainer, item_name: String, count: int, row_w: float):
	AudioManager.play_sfx("pop")
	
	var row_panel = PanelContainer.new()
	row_panel.custom_minimum_size = Vector2(row_w, 48)
	row_panel.size = Vector2(row_w, 48)
	row_panel.pivot_offset = Vector2(row_w * 0.5, 24.0)
	row_panel.scale = Vector2(0.3, 0.3)
	row_panel.modulate.a = 0.0
	
	var rp_st = UIHelper.create_bubbly_panel(14, Color(0.94, 0.98, 1.0), Color(0.72, 0.88, 1.0), 1.5)
	rp_st.shadow_color = Color(0.1, 0.25, 0.45, 0.10)
	rp_st.shadow_size = 4
	rp_st.shadow_offset = Vector2(0, 2)
	row_panel.add_theme_stylebox_override("panel", rp_st)
	
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 10)
	
	var icon = TextureRect.new()
	icon.texture = _get_reward_icon_texture(item_name)
	icon.custom_minimum_size = Vector2(28, 28)
	icon.size = Vector2(28, 28)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hbox.add_child(icon)
	
	var item_txt = item_name
	if count > 1:
		item_txt += " (x%d)" % count
	var lbl = Label.new()
	lbl.text = item_txt
	UIHelper.apply_bubbly_label(lbl, 14, Color(0.12, 0.35, 0.65), true)
	hbox.add_child(lbl)
	
	row_panel.add_child(hbox)
	container.add_child(row_panel)
	
	# Popping motion: from small scale up to big size (1.30) then bounce to normal (1.0)!
	var pop_tw = row_panel.create_tween()
	pop_tw.set_parallel(true)
	pop_tw.tween_property(row_panel, "modulate:a", 1.0, 0.08)
	pop_tw.tween_property(row_panel, "scale", Vector2(1.30, 1.30), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop_tw.chain().tween_property(row_panel, "scale", Vector2(1.0, 1.0), 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _render_opened_gifts_static(_card: Control, vbox: VBoxContainer, card_w: float):
	var tallies: Dictionary = {}
	var display_order: Array[String] = []
	for g in gift_contents:
		if not tallies.has(g):
			display_order.append(g)
			tallies[g] = 0
		tallies[g] += 1
		
	var opened_panel = PanelContainer.new()
	var op_st = UIHelper.create_bubbly_panel(16, Color.WHITE, Color(0.98, 0.58, 0.12), 2.5)
	opened_panel.add_theme_stylebox_override("panel", op_st)
	
	var op_vbox = VBoxContainer.new()
	op_vbox.add_theme_constant_override("separation", 6)
	
	var op_title = Label.new()
	op_title.text = "GIFTS OPENED!"
	op_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(op_title, 14, Color(0.95, 0.48, 0.08), true)
	op_vbox.add_child(op_title)
	
	var row_w = card_w - 56.0
	for item_name in display_order:
		var count = tallies[item_name]
		var row_panel = PanelContainer.new()
		row_panel.custom_minimum_size = Vector2(row_w, 40)
		var rp_st = UIHelper.create_bubbly_panel(12, Color(0.94, 0.98, 1.0), Color(0.72, 0.88, 1.0), 1.5)
		row_panel.add_theme_stylebox_override("panel", rp_st)
		
		var hbox = HBoxContainer.new()
		hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		hbox.add_theme_constant_override("separation", 10)
		
		var icon = TextureRect.new()
		icon.texture = _get_reward_icon_texture(item_name)
		icon.custom_minimum_size = Vector2(26, 26)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hbox.add_child(icon)
		
		var item_txt = item_name
		if count > 1:
			item_txt += " (x%d)" % count
		var lbl = Label.new()
		lbl.text = item_txt
		UIHelper.apply_bubbly_label(lbl, 14, Color(0.12, 0.35, 0.65), true)
		hbox.add_child(lbl)
		
		row_panel.add_child(hbox)
		op_vbox.add_child(row_panel)
		
	opened_panel.add_child(op_vbox)
	vbox.add_child(opened_panel)
	
	var btn_w = clamp(card_w - 36.0, 220.0, 280.0)
	var cont_btn = UIHelper.create_themed_button("back to main map", Vector2(btn_w, 56))
	if not cont_btn.texture_normal:
		cont_btn = UIHelper.create_bubbly_button("RETURN TO MAP", UIHelper.VIBRANT_GREEN)
	cont_btn.custom_minimum_size = Vector2(btn_w, 56)
	cont_btn.pressed.connect(func():
		AudioManager.play_sfx("click")
		if win_modal and is_instance_valid(win_modal):
			win_modal.queue_free()
			win_modal = null
		game_ended.emit()
	)
	vbox.add_child(cont_btn)
