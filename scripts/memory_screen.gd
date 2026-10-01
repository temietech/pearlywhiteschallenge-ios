# scripts/memory_screen.gd
extends Control

signal game_ended
signal game_won

var cards: Array[Dictionary] = []
var first_card_idx: int = -1
var second_card_idx: int = -1
var matches_found: int = 0
var is_locked: bool = false
var is_memorise_phase: bool = false
var is_paused: bool = false

var timer: Timer
var time_elapsed: int = 0
var memorise_countdown: int = 3
var selected_difficulty: String = "medium"

# Combo & Reward Tracking
var consecutive_matches: int = 0
var max_combo: int = 0
var coins_earned: int = 0
var points_earned: int = 0

var count_label: Label
var time_label: Label
var coins_label: Label
var points_label: Label
var memorise_pill: PanelContainer
var memorise_label: Label
var combo_banner: PanelContainer
var combo_label: Label
var grid: GridContainer
var card_buttons: Array[TextureButton] = []
var current_card_dim: float = 74.0

var difficulty_modal: Control
var pause_modal: Control
var win_modal: Control
var pause_btn: TextureButton
var title_vbox: VBoxContainer
var stats_row: HBoxContainer
var tray: Control
var tray_margin: MarginContainer

static var _cached_dental_title_tex: Texture2D = null
static var _cached_card_front_tex: Texture2D = null

static func _ensure_dental_match_title_texture() -> Texture2D:
	if _cached_dental_title_tex and is_instance_valid(_cached_dental_title_tex):
		var sz = _cached_dental_title_tex.get_size()
		if sz.y > 0 and (sz.x / sz.y) < 3.2:
			return _cached_dental_title_tex
		_cached_dental_title_tex = null
		
	var candidate_paths = [
		ProjectSettings.globalize_path("res://../mockups/assets/title/DentalMatch-Title.png"),
		"C:/Users/temie/Documents/Personal Life/Pearly White/Challenge/App/mockups/assets/title/DentalMatch-Title.png",
		ProjectSettings.globalize_path("res://assets/images/cardmatchmini/DentalMatch-Title.png"),
		ProjectSettings.globalize_path("res://assets/images/cardmatchmini/dental_match_title.png")
	]
	
	for cp in candidate_paths:
		if FileAccess.file_exists(cp):
			var img = Image.load_from_file(cp)
			if img and not img.is_empty():
				var iw = img.get_width()
				var ih = img.get_height()
				# If it's the old single-line strip (ih < 120 and iw > 400), don't prioritize it if mockups exists
				if cp.ends_with("dental_match_title.png") and ih > 0 and (float(iw) / float(ih)) > 3.0:
					var mock_path = ProjectSettings.globalize_path("res://../mockups/assets/title/DentalMatch-Title.png")
					if FileAccess.file_exists(mock_path):
						var mock_img = Image.load_from_file(mock_path)
						if mock_img and not mock_img.is_empty():
							img = mock_img
							cp = mock_path
				_cached_dental_title_tex = ImageTexture.create_from_image(img)
				var dest1 = ProjectSettings.globalize_path("res://assets/images/cardmatchmini/DentalMatch-Title.png")
				var dest2 = ProjectSettings.globalize_path("res://assets/images/cardmatchmini/dental_match_title.png")
				DirAccess.make_dir_recursive_absolute(dest1.get_base_dir())
				if cp != dest1:
					img.save_png(dest1)
				if cp != dest2:
					img.save_png(dest2)
				return _cached_dental_title_tex
				
	var res_paths = [
		"res://assets/images/cardmatchmini/DentalMatch-Title.png",
		"res://assets/images/cardmatchmini/dental_match_title.png"
	]
	for rp in res_paths:
		var tex = UIHelper.load_texture_safe(rp)
		if tex:
			_cached_dental_title_tex = tex
			return _cached_dental_title_tex
			
	return null

static func _get_card_front_texture() -> Texture2D:
	if _cached_card_front_tex and is_instance_valid(_cached_card_front_tex):
		return _cached_card_front_tex
		
	var path = "res://assets/images/cardmatchmini/beforetapcardface.png"
	var base_tex = UIHelper.load_texture_safe(path)
	if not base_tex:
		return null
		
	var img = base_tex.get_image()
	if not img or img.is_empty():
		_cached_card_front_tex = base_tex
		return _cached_card_front_tex
		
	var used = img.get_used_rect()
	if used.size.x > 0 and used.size.y > 0 and (used.size.x < img.get_width() or used.size.y < img.get_height()):
		var cropped = img.get_region(used)
		_cached_card_front_tex = ImageTexture.create_from_image(cropped)
		return _cached_card_front_tex
		
	_cached_card_front_tex = base_tex
	return _cached_card_front_tex

func _ready():
	anchors_preset = Control.PRESET_FULL_RECT
	anchor_right = 1.0
	anchor_bottom = 1.0
	_build_ui()
	_relayout()
	var diff = GameState.get_difficulty()
	var cd = 5 if diff == "easy" else (3 if diff == "medium" else 0)
	_start_with_difficulty(diff, cd)

func _notification(what: int):
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_relayout()

func _build_card_pairs() -> Array[Dictionary]:
	var p = GameState.get_active_profile()
	var pairs: Array[Dictionary] = []
	
	# 1. Toothbrush Weapon (Straight yellow for Level 1, Gold for Level 2, Bubble Brush for Level 3)
	var brush_lvl = _get_weapon_level(p, "brush")
	var brush_tex = "res://assets/images/shop/brushweapon_1.png"
	if brush_lvl == 2:
		brush_tex = "res://assets/images/shop/brushweapon_2.png"
	elif brush_lvl >= 3:
		brush_tex = "res://assets/images/shop/BubbleBrush.png"
	pairs.append({
		"id": "brush",
		"tex": brush_tex,
		"fallback": "res://assets/images/shop/brushweapon_1.png"
	})
	
	# 2. Red Paste Weapon
	pairs.append({
		"id": "paste",
		"tex": "res://assets/images/candycrusadegame/pasteweapon.png",
		"fallback": "res://assets/images/shop/pasteweapon_1.png"
	})
	
	# 3. Blue Wash / Mouthwash Weapon (Connected from candycrusadegame)
	pairs.append({
		"id": "wash",
		"tex": "res://assets/images/candycrusadegame/washweapon.png",
		"fallback": "res://assets/images/shop/MouthwashBlast-1.png"
	})
	
	# 4. Green Floss Weapon (Connected from candycrusadegame)
	pairs.append({
		"id": "floss",
		"tex": "res://assets/images/candycrusadegame/flossweapon.png",
		"fallback": "res://assets/images/shop/flossweapon_1.png"
	})
	
	# 5. Chip Tooth Mascot (res://assets/images/characters/chip-nobg.png)
	var av_id = p.get("avatar", "chip")
	var av_tex = UIHelper.get_char_texture(av_id, false)
	if not av_tex:
		av_tex = UIHelper.load_texture_safe("res://assets/images/characters/chip-nobg.png")
	pairs.append({
		"id": "avatar",
		"tex": av_tex,
		"is_texture_obj": true
	})
	
	# 6. Sir Crown Mascot (res://assets/images/characters/SirCrown-nobg.png)
	pairs.append({
		"id": "crown",
		"tex": "res://assets/images/characters/SirCrown-nobg.png",
		"fallback": "res://assets/images/characters/chip-nobg.png"
	})
	
	# 7. Purple Star Points Icon (res://assets/images/cardmatchmini/purple_star_points.png)
	pairs.append({
		"id": "star",
		"tex": "res://assets/images/cardmatchmini/purple_star_points.png",
		"fallback": "res://assets/images/shop/purple_star_points.png"
	})
	
	# 8. Gold Tooth Coin Icon (res://assets/images/cardmatchmini/gold_tooth_coin.png)
	pairs.append({
		"id": "coin",
		"tex": "res://assets/images/cardmatchmini/gold_tooth_coin.png",
		"fallback": "res://assets/images/shop/gold_tooth_coin.png"
	})
	
	return pairs

func _get_weapon_level(p: Dictionary, weapon_type: String) -> int:
	var lvl = 1
	var tiers = p.get("weaponTiers", {}).get(weapon_type, [])
	if tiers is Array and tiers.size() > 0:
		for t in tiers:
			if int(t) > lvl:
				lvl = int(t)
	var direct_lvl = p.get("weaponLevels", {}).get(weapon_type, 1)
	if direct_lvl > lvl:
		lvl = direct_lvl
	return clampi(lvl, 1, 3)

func _build_ui():
	# Background
	var bg = UIHelper.setup_clean_bubbly_bg(self)
	
	# Top Right Circular Pause Button
	pause_btn = UIHelper.create_circular_pause_button(Vector2(46, 46))
	pause_btn.pressed.connect(_on_pause_pressed)
	add_child(pause_btn)
	
	# Memorise Banner (Floating at top, not inside title_vbox)
	memorise_pill = PanelContainer.new()
	memorise_pill.custom_minimum_size = Vector2(160, 30)
	var mp_style = UIHelper.create_bubbly_panel(15, Color(0.18, 0.43, 0.82), Color.WHITE, 2.5)
	memorise_pill.add_theme_stylebox_override("panel", mp_style)
	memorise_pill.z_index = 30
	
	memorise_label = Label.new()
	memorise_label.text = "MEMORISE! 3"
	memorise_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	memorise_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(memorise_label, 13, Color.WHITE, true)
	memorise_pill.add_child(memorise_label)
	memorise_pill.visible = false
	add_child(memorise_pill)
	
	# Title container
	title_vbox = VBoxContainer.new()
	title_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	title_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title_vbox)
	
	var title_tex = _ensure_dental_match_title_texture()
	if title_tex:
		var title_img = TextureRect.new()
		title_img.name = "TitleImg"
		title_img.texture = title_tex
		title_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		title_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		title_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title_vbox.add_child(title_img)
	else:
		var font = UIHelper.get_main_font()
		var title = Label.new()
		title.name = "TitleLbl"
		title.text = "DENTAL MATCH"
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if font:
			title.add_theme_font_override("font", font)
		UIHelper.apply_bubbly_label(title, 25, Color.WHITE, true)
		title.add_theme_color_override("font_outline_color", Color(0.12, 0.38, 0.72))
		title.add_theme_constant_override("outline_size", 8)
		title_vbox.add_child(title)
	
	# Status Row (0/8 pill, 0:00 timer capsule, coins & points pill)
	stats_row = HBoxContainer.new()
	stats_row.alignment = BoxContainer.ALIGNMENT_CENTER
	stats_row.add_theme_constant_override("separation", 14)
	add_child(stats_row)
	
	var count_pill = PanelContainer.new()
	count_pill.custom_minimum_size = Vector2(74, 38)
	var cp_style = UIHelper.create_bubbly_panel(19, Color.WHITE, Color(1, 1, 1, 0.90), 2.5)
	cp_style.shadow_color = Color(0.15, 0.35, 0.60, 0.18)
	cp_style.shadow_size = 5
	cp_style.shadow_offset = Vector2(0, 2)
	count_pill.add_theme_stylebox_override("panel", cp_style)
	count_label = Label.new()
	count_label.text = "0/8"
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(count_label, 16, Color(0.12, 0.36, 0.60), true)
	count_pill.add_child(count_label)
	stats_row.add_child(count_pill)
	
	var timer_pill = PanelContainer.new()
	timer_pill.custom_minimum_size = Vector2(120, 42)
	var tp_style = UIHelper.create_bubbly_panel(21, Color.WHITE, Color(1, 1, 1, 0.90), 2.5)
	tp_style.shadow_color = Color(0.15, 0.35, 0.60, 0.18)
	tp_style.shadow_size = 5
	tp_style.shadow_offset = Vector2(0, 2)
	timer_pill.add_theme_stylebox_override("panel", tp_style)
	time_label = Label.new()
	time_label.text = "0:00"
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(time_label, 22, Color(0.12, 0.36, 0.60), true)
	timer_pill.add_child(time_label)
	stats_row.add_child(timer_pill)
	
	var rew_pill = PanelContainer.new()
	rew_pill.custom_minimum_size = Vector2(138, 38)
	var rp_style = UIHelper.create_bubbly_panel(19, Color.WHITE, Color(1, 1, 1, 0.90), 2.5)
	rp_style.shadow_color = Color(0.15, 0.35, 0.60, 0.18)
	rp_style.shadow_size = 5
	rp_style.shadow_offset = Vector2(0, 2)
	rew_pill.add_theme_stylebox_override("panel", rp_style)
	var rew_hbox = HBoxContainer.new()
	rew_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	rew_hbox.add_theme_constant_override("separation", 7)
	
	var coin_ic = TextureRect.new()
	coin_ic.texture = UIHelper.load_texture_safe("res://assets/images/cardmatchmini/gold_tooth_coin.png")
	if not coin_ic.texture:
		coin_ic.texture = UIHelper.load_texture_safe("res://assets/images/shop/gold_tooth_coin.png")
	coin_ic.custom_minimum_size = Vector2(20, 20)
	coin_ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	coin_ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin_ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rew_hbox.add_child(coin_ic)
	
	coins_label = Label.new()
	coins_label.text = "0"
	coins_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UIHelper.apply_bubbly_label(coins_label, 15, Color(0.12, 0.36, 0.60), true)
	rew_hbox.add_child(coins_label)
	
	var star_ic = TextureRect.new()
	star_ic.texture = UIHelper.load_texture_safe("res://assets/images/cardmatchmini/purple_star_points.png")
	if not star_ic.texture:
		star_ic.texture = UIHelper.load_texture_safe("res://assets/images/shop/purple_star_points.png")
	star_ic.custom_minimum_size = Vector2(20, 20)
	star_ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	star_ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	star_ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rew_hbox.add_child(star_ic)
	
	points_label = Label.new()
	points_label.text = "0"
	points_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UIHelper.apply_bubbly_label(points_label, 15, Color(0.12, 0.36, 0.60), true)
	rew_hbox.add_child(points_label)
	rew_pill.add_child(rew_hbox)
	stats_row.add_child(rew_pill)
	
	# Frosted 3D Card Tray using authentic cardmatchback.png
	tray = TextureRect.new()
	tray.texture = UIHelper.load_texture_safe("res://assets/images/cardmatchmini/cardmatchback.png")
	tray.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tray.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tray.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(tray)
	
	# 4x4 Grid of 16 Cards inside the tray's recessed area
	tray_margin = MarginContainer.new()
	tray_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	tray.add_child(tray_margin)
	
	grid = GridContainer.new()
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tray_margin.add_child(grid)
	
	# Combo Banner (Floating animated pill)
	combo_banner = PanelContainer.new()
	combo_banner.size = Vector2(230, 36)
	var cb_st = UIHelper.create_bubbly_panel(18, Color(1, 0.92, 0.3), Color(1, 0.6, 0.1), 2)
	combo_banner.add_theme_stylebox_override("panel", cb_st)
	combo_banner.modulate = Color(1, 1, 1, 0)
	combo_banner.pivot_offset = Vector2(115, 18)
	
	combo_label = Label.new()
	combo_label.text = "COMBO x2!"
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combo_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(combo_label, 13, Color(0.85, 0.25, 0.0), true)
	combo_banner.add_child(combo_label)
	add_child(combo_banner)
	
	# Timer
	timer = Timer.new()
	timer.wait_time = 1.0
	timer.timeout.connect(_on_timer_tick)
	add_child(timer)

func _relayout():
	var safe_sz = UIHelper.get_viewport_safe_size(self)
	var cur_w = safe_sz.x
	var cur_h = safe_sz.y
	var is_tablet = cur_w >= 560
	
	# 1. Title dimensions (DentalMatch-Title.png aspect ratio is ~2.30 : 1)
	var title_w = clamp(cur_w * (0.50 if is_tablet else 0.58), 220.0, 310.0)
	var title_h = title_w / 2.30
	
	# 2. Stats Row dimensions
	var stat_w = min(cur_w - 32.0, 420.0)
	var stat_h = 44.0
	
	# 3. Tray dimensions (square)
	var max_tray_w = min(cur_w - (40.0 if is_tablet else 28.0), 520.0 if is_tablet else 410.0)
	var max_tray_h = cur_h * (0.50 if is_tablet else 0.52)
	var tray_size = min(max_tray_w, max_tray_h)
	tray_size = clamp(tray_size, 280.0, 520.0)
	
	# 4. Vertical Distribution & Centering with ample padding between segments
	var total_group_h = title_h + stat_h + tray_size + 24.0 + 28.0
	# Content group starts below the notch on iPhone; the pause button stays in the corner
	var notch_t: float = UIHelper.safe_top
	var free_h = max(0.0, cur_h - total_group_h - notch_t)
	
	# Balance vertical position across the screen:
	# Keep a comfortable top margin for header buttons (back, pause, memorise pill)
	var top_pad = clamp(free_h * 0.35, 45.0, 95.0)
	var gap_title_stats = clamp(free_h * 0.10, 20.0, 30.0)
	var gap_stats_tray = clamp(free_h * 0.12, 24.0, 36.0)
	
	var title_y = top_pad + notch_t
	var stats_y = title_y + title_h + gap_title_stats
	var tray_y = stats_y + stat_h + gap_stats_tray
	
	# Header buttons vertically centered in the space above the title
	var top_btn_y = clamp((top_pad - 46.0) * 0.5, 14.0, 24.0)
	if pause_btn:
		pause_btn.position = Vector2(cur_w - 58, top_btn_y)
	if memorise_pill:
		memorise_pill.position = Vector2((cur_w - 160.0) * 0.5, max(8.0, top_btn_y - 4.0) + notch_t)
		
	if title_vbox:
		title_vbox.position = Vector2((cur_w - title_w) * 0.5, title_y)
		title_vbox.size = Vector2(title_w, title_h)
		title_vbox.custom_minimum_size = Vector2(title_w, title_h)
		var title_img = title_vbox.get_node_or_null("TitleImg")
		if title_img:
			title_img.custom_minimum_size = Vector2(title_w, title_h)
			title_img.size = Vector2(title_w, title_h)
			
	if stats_row:
		stats_row.position = Vector2((cur_w - stat_w) * 0.5, stats_y)
		stats_row.size = Vector2(stat_w, stat_h)
		
	if tray:
		tray.size = Vector2(tray_size, tray_size)
		tray.position = Vector2((cur_w - tray_size) * 0.5, tray_y)
		
		if tray_margin:
			var pad_x = tray_size * 0.105
			var pad_top = tray_size * 0.105
			var pad_bottom = tray_size * 0.115
			tray_margin.add_theme_constant_override("margin_left", int(pad_x))
			tray_margin.add_theme_constant_override("margin_right", int(pad_x))
			tray_margin.add_theme_constant_override("margin_top", int(pad_top))
			tray_margin.add_theme_constant_override("margin_bottom", int(pad_bottom))
			
			var avail_grid_w = tray_size - (pad_x * 2.0)
			var card_sep = 8.0 if is_tablet else 6.0
			grid.add_theme_constant_override("h_separation", int(card_sep))
			grid.add_theme_constant_override("v_separation", int(card_sep))
			current_card_dim = floor((avail_grid_w - card_sep * 3.0) / 4.0)
			for btn in card_buttons:
				if is_instance_valid(btn):
					btn.custom_minimum_size = Vector2(current_card_dim, current_card_dim)
					btn.size = Vector2(current_card_dim, current_card_dim)
					btn.pivot_offset = Vector2(current_card_dim * 0.5, current_card_dim * 0.5)
					btn.clip_contents = true
	if combo_banner:
		var banner_y = min(cur_h - 70.0, tray_y + tray_size + 24.0)
		combo_banner.position = Vector2((cur_w - 230.0) * 0.5, banner_y)

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
	
	var title_tex = _ensure_dental_match_title_texture()
	if title_tex:
		var title_img = TextureRect.new()
		title_img.texture = title_tex
		title_img.custom_minimum_size = Vector2(card_w - 60.0, 46)
		title_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		title_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		title_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		heading_box.add_child(title_img)
	else:
		var title_lbl = Label.new()
		title_lbl.text = "DENTAL MATCH"
		title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UIHelper.apply_bubbly_label(title_lbl, 25, Color.WHITE, true)
		title_lbl.add_theme_color_override("font_shadow_color", Color(0.12, 0.40, 0.70))
		title_lbl.add_theme_constant_override("shadow_offset_x", 2)
		title_lbl.add_theme_constant_override("shadow_offset_y", 2)
		heading_box.add_child(title_lbl)
	
	var sub_lbl = Label.new()
	sub_lbl.text = "CHOOSE A DIFFICULTY"
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(sub_lbl, 12, Color(0.92, 0.97, 1.0), true)
	heading_box.add_child(sub_lbl)
	vbox.add_child(heading_box)
	
	# 1. Easy Button
	var easy_btn = _create_difficulty_button("EASY", "GENTLE AND SLOW", Color(0.16, 0.78, 0.42), func():
		_start_with_difficulty("easy", 5)
	)
	vbox.add_child(easy_btn)
	
	# 2. Medium Button
	var med_btn = _create_difficulty_button("MEDIUM", "A FAIR CHALLENGE", Color(0.98, 0.54, 0.12), func():
		_start_with_difficulty("medium", 3)
	)
	vbox.add_child(med_btn)
	
	# 3. Hard Button
	var hard_btn = _create_difficulty_button("HARD", "FAST AND FIERCE", Color(0.72, 0.42, 0.94), func():
		_start_with_difficulty("hard", 0)
	)
	vbox.add_child(hard_btn)
	
	var foot_lbl = Label.new()
	foot_lbl.text = "Easy shows every card for 5s, Medium for 3s,\nHard shows nothing."
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

func _start_with_difficulty(diff: String, countdown_secs: int):
	selected_difficulty = diff
	memorise_countdown = countdown_secs
	if difficulty_modal:
		difficulty_modal.queue_free()
		difficulty_modal = null
	start_game()

func start_game():
	cards.clear()
	card_buttons.clear()
	for c in grid.get_children():
		c.queue_free()
		
	matches_found = 0
	consecutive_matches = 0
	max_combo = 0
	coins_earned = 0
	points_earned = 0
	time_elapsed = 0
	first_card_idx = -1
	second_card_idx = -1
	is_locked = false
	
	count_label.text = "0/8"
	time_label.text = "0:00"
	coins_label.text = "0"
	points_label.text = "0"
	
	var pair_templates = _build_card_pairs()
	for item in pair_templates:
		cards.append({
			"id": item["id"],
			"tex": item.get("tex", null),
			"fallback": item.get("fallback", ""),
			"is_texture_obj": item.get("is_texture_obj", false),
			"matched": false
		})
		cards.append({
			"id": item["id"],
			"tex": item.get("tex", null),
			"fallback": item.get("fallback", ""),
			"is_texture_obj": item.get("is_texture_obj", false),
			"matched": false
		})
	cards.shuffle()
	
	var card_dim = current_card_dim if current_card_dim > 0 else 74.0
	var front_tex = _get_card_front_texture()
	for i in range(16):
		var btn = TextureButton.new()
		btn.ignore_texture_size = true
		btn.stretch_mode = TextureButton.STRETCH_SCALE
		btn.texture_normal = front_tex
		btn.focus_mode = Control.FOCUS_NONE
		btn.clip_contents = true
		btn.custom_minimum_size = Vector2(card_dim, card_dim)
		btn.size = Vector2(card_dim, card_dim)
		btn.pivot_offset = Vector2(card_dim * 0.5, card_dim * 0.5)
		var idx = i
		btn.pressed.connect(func(): _on_card_clicked(idx))
		card_buttons.append(btn)
		grid.add_child(btn)
		
	_relayout()
	
	if memorise_countdown > 0:
		is_memorise_phase = true
		memorise_label.text = "MEMORISE! %d" % memorise_countdown
		memorise_pill.visible = true
		_relayout()
		for i in range(16):
			_show_card_face(i)
	else:
		is_memorise_phase = false
		memorise_pill.visible = false
		_relayout()
		for i in range(16):
			_hide_card_face(i)
			
	timer.start()

func _on_timer_tick():
	if is_paused:
		return
		
	if is_memorise_phase:
		memorise_countdown -= 1
		if memorise_countdown > 0:
			memorise_label.text = "MEMORISE! %d" % memorise_countdown
		else:
			is_memorise_phase = false
			memorise_pill.visible = false
			_relayout()
			time_elapsed = 0
			for i in range(16):
				_hide_card_face(i)
	else:
		time_elapsed += 1
		var mins = time_elapsed / 60
		var secs = time_elapsed % 60
		time_label.text = "%d:%02d" % [mins, secs]

func _show_card_face(idx: int):
	if idx < 0 or idx >= card_buttons.size() or idx >= cards.size():
		return
	var btn = card_buttons[idx]
	var c = cards[idx]
	
	for ch in btn.get_children():
		ch.queue_free()
		
	btn.texture_normal = null
	
	var card_dim = current_card_dim
	if card_dim <= 0:
		card_dim = btn.size.x if btn.size.x > 0 else 74.0
		
	# White rounded card tile matching screens/40-dental-match-play.png
	var tile = Panel.new()
	tile.name = "CardTile"
	tile.set_anchors_preset(Control.PRESET_FULL_RECT)
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.clip_contents = true
	
	var tile_st = StyleBoxFlat.new()
	tile_st.bg_color = Color(0.85, 0.93, 1.0) # Soft concave blue interior
	tile_st.border_color = Color.WHITE
	var b_w = maxi(3, int(card_dim * 0.055))
	tile_st.border_width_left = b_w
	tile_st.border_width_right = b_w
	tile_st.border_width_top = b_w
	tile_st.border_width_bottom = b_w
	tile_st.set_corner_radius_all(maxi(12, int(card_dim * 0.22)))
	tile_st.shadow_size = 0
	tile.add_theme_stylebox_override("panel", tile_st)
	btn.add_child(tile)
	
	# Icon inside tile - strictly contained and centered
	var icon = TextureRect.new()
	icon.name = "CardIcon"
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	var pad = round(card_dim * 0.17)
	icon.offset_left = pad
	icon.offset_top = pad
	icon.offset_right = -pad
	icon.offset_bottom = -pad
	
	if c.get("is_texture_obj", false) and c["tex"] is Texture2D:
		icon.texture = c["tex"]
	elif typeof(c["tex"]) == TYPE_STRING:
		icon.texture = UIHelper.load_texture_safe(c["tex"])
		if not icon.texture and c.get("fallback", "") != "":
			icon.texture = UIHelper.load_texture_safe(c["fallback"])
			
	tile.add_child(icon)

func _hide_card_face(idx: int):
	if idx < 0 or idx >= card_buttons.size():
		return
	var btn = card_buttons[idx]
	for ch in btn.get_children():
		ch.queue_free()
	btn.texture_normal = _get_card_front_texture()

func _flip_card(idx: int, reveal: bool, callback: Callable = Callable()):
	if idx < 0 or idx >= card_buttons.size():
		return
	var btn = card_buttons[idx]
	btn.pivot_offset = btn.size * 0.5
	var tw = btn.create_tween()
	tw.tween_property(btn, "scale:x", 0.05, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		if reveal:
			_show_card_face(idx)
		else:
			_hide_card_face(idx)
	)
	tw.tween_property(btn, "scale:x", 1.0, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if callback.is_valid():
		tw.tween_callback(callback)

func _on_card_clicked(idx: int):
	if is_memorise_phase or is_locked or cards[idx]["matched"] or idx == first_card_idx or is_paused:
		return
		
	AudioManager.play_sfx("click")
	
	if first_card_idx == -1:
		first_card_idx = idx
		_flip_card(idx, true)
	else:
		second_card_idx = idx
		is_locked = true
		_flip_card(idx, true, func():
			_check_match()
		)

func _check_match():
	if first_card_idx < 0 or second_card_idx < 0:
		is_locked = false
		return
		
	if cards[first_card_idx]["id"] == cards[second_card_idx]["id"]:
		# MATCH!
		AudioManager.play_sfx("sparkle")
		cards[first_card_idx]["matched"] = true
		cards[second_card_idx]["matched"] = true
		matches_found += 1
		consecutive_matches += 1
		if consecutive_matches > max_combo:
			max_combo = consecutive_matches
			
		# Base Rewards
		var match_pts = 10
		var match_coins = 2
		
		# Combo Rewards
		var combo_pts = 0
		var combo_coins = 0
		if consecutive_matches >= 2:
			combo_pts = (consecutive_matches - 1) * 15
			combo_coins = (consecutive_matches - 1) * 2
			_trigger_combo_animation(consecutive_matches, combo_pts)
			
		points_earned += match_pts + combo_pts
		coins_earned += match_coins + combo_coins
		
		count_label.text = "%d/8" % matches_found
		coins_label.text = str(coins_earned)
		points_label.text = str(points_earned)
		
		# Disable clicks on matched cards
		card_buttons[first_card_idx].mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_buttons[second_card_idx].mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		# Card success pop animation
		_animate_matched_pair(first_card_idx, second_card_idx)
		
		first_card_idx = -1
		second_card_idx = -1
		is_locked = false
		
		if matches_found >= 8:
			timer.stop()
			var win_timer = get_tree().create_timer(0.6)
			win_timer.timeout.connect(_on_game_won)
	else:
		# MISMATCH! Combo resets
		consecutive_matches = 0
		AudioManager.play_sfx("hit")
		var t = get_tree().create_timer(0.7)
		t.timeout.connect(func():
			var c1 = first_card_idx
			var c2 = second_card_idx
			first_card_idx = -1
			second_card_idx = -1
			if c1 >= 0 and c1 < card_buttons.size():
				_flip_card(c1, false)
			if c2 >= 0 and c2 < card_buttons.size():
				_flip_card(c2, false, func():
					is_locked = false
				)
			else:
				is_locked = false
		)

func _animate_matched_pair(idx1: int, idx2: int):
	var b1 = card_buttons[idx1]
	var b2 = card_buttons[idx2]
	var tw1 = b1.create_tween()
	tw1.tween_property(b1, "scale", Vector2(1.15, 1.15), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw1.tween_property(b1, "scale", Vector2(1.0, 1.0), 0.16).set_ease(Tween.EASE_IN)
	var tw2 = b2.create_tween()
	tw2.tween_property(b2, "scale", Vector2(1.15, 1.15), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw2.tween_property(b2, "scale", Vector2(1.0, 1.0), 0.16).set_ease(Tween.EASE_IN)

func _trigger_combo_animation(combo_count: int, bonus_pts: int):
	AudioManager.play_sfx("sparkle")
	combo_label.text = "COMBO x%d! (+%d pts)" % [combo_count, bonus_pts]
	combo_banner.modulate = Color(1, 1, 1, 1)
	combo_banner.scale = Vector2(1.3, 1.3)
	
	var tw = combo_banner.create_tween()
	tw.tween_property(combo_banner, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.9)
	tw.tween_property(combo_banner, "modulate:a", 0.0, 0.3)

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
		var cd = 5 if diff == "easy" else (3 if diff == "medium" else 0)
		_start_with_difficulty(diff, cd)
	)
	vbox.add_child(restart_btn)
	
	var quit_btn = UIHelper.create_themed_button("exit", Vector2(btn_w, 50))
	if not quit_btn.texture_normal:
		quit_btn = UIHelper.create_bubbly_button("EXIT GAME", Color(0.90, 0.32, 0.32))
		quit_btn.custom_minimum_size = Vector2(btn_w, 48)
	quit_btn.pressed.connect(func():
		AudioManager.play_sfx("click")
		if pause_modal and is_instance_valid(pause_modal):
			pause_modal.queue_free()
			pause_modal = null
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

func _on_game_won():
	AudioManager.play_sfx("cheer")
	
	# Calculate stars & rewards based on time matching canonical React logic (screens.tsx:7670)
	var earned_stars = 1
	var completion_points = 20
	if time_elapsed <= 60:
		earned_stars = 3
		completion_points = 100
	elif time_elapsed <= 90:
		earned_stars = 2
		completion_points = 50
		
	var final_points = points_earned + completion_points
	var final_coins = coins_earned + 16
	
	GameState.add_points(final_points)
	GameState.add_molar_coins(final_coins)
	
	# Update best time
	var p = GameState.get_active_profile()
	var prev_best = p.get("memoryBest", 999)
	if time_elapsed < prev_best or prev_best <= 0:
		p["memoryBest"] = time_elapsed
	GameState.save_game()
	
	if win_modal and is_instance_valid(win_modal):
		win_modal.queue_free()
		
	var safe_sz = UIHelper.get_viewport_safe_size(self)
	var dlg = UIHelper.create_modal_dialog(self, 200)
	win_modal = dlg["overlay"]
	var center = dlg["center"]
	
	var is_tablet = safe_sz.x >= 560.0
	# Window size reduced by 20%
	var card_w = clamp((safe_sz.x - 32.0) * 0.90, 300.0, 380.0)
	var card_h = clamp(safe_sz.y * 0.62, 400.0, 520.0)
	
	var card = Panel.new()
	card.custom_minimum_size = Vector2(card_w, card_h)
	card.size = Vector2(card_w, card_h)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.38, 0.72, 0.98)
	card_style.border_color = Color.WHITE
	card_style.border_width_left = 4
	card_style.border_width_right = 4
	card_style.border_width_top = 4
	card_style.border_width_bottom = 4
	card_style.set_corner_radius_all(24)
	card_style.shadow_color = Color(0.05, 0.15, 0.35, 0.40)
	card_style.shadow_size = 20
	card_style.shadow_offset = Vector2(0, 8)
	card.add_theme_stylebox_override("panel", card_style)
	center.add_child(card)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 14.0
	vbox.offset_right = -14.0
	vbox.offset_top = 14.0
	vbox.offset_bottom = -14.0
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)
	card.add_child(vbox)
	
	# Doubled Title
	var title = Label.new()
	title.text = "PERFECT MATCH!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(title, 22, Color.WHITE, true)
	title.add_theme_color_override("font_shadow_color", Color(0.10, 0.36, 0.66))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	vbox.add_child(title)
	
	# Star Rating: 3D Golden Star textures
	var star_tex = UIHelper.load_texture_safe("res://assets/images/candycrusadegame/star.png")
	if not star_tex:
		star_tex = UIHelper.load_texture_safe("res://assets/images/mainmap/gold_star_counter.png")
	if not star_tex:
		star_tex = UIHelper.load_texture_safe("res://assets/images/cardmatchmini/purple_star_points.png")
		
	var star_hbox = HBoxContainer.new()
	star_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	star_hbox.add_theme_constant_override("separation", 10)
	
	for s in range(3):
		var star_sz = Vector2(52, 52) if s == 1 else Vector2(42, 42)
		var star_ctrl = CenterContainer.new()
		star_ctrl.custom_minimum_size = star_sz
		
		var star_rect = TextureRect.new()
		star_rect.texture = star_tex
		star_rect.custom_minimum_size = star_sz
		star_rect.size = star_sz
		star_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		star_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		star_rect.pivot_offset = star_sz * 0.5
		
		if s < earned_stars:
			star_rect.modulate = Color.WHITE
		else:
			star_rect.modulate = Color(0.32, 0.45, 0.62, 0.35)
			
		star_ctrl.add_child(star_rect)
		star_hbox.add_child(star_ctrl)
	vbox.add_child(star_hbox)
	
	# Star Criteria Clarity
	var star_info_lbl = Label.new()
	if earned_stars == 3:
		star_info_lbl.text = "Under 60s (+100 Pts!)"
		UIHelper.apply_bubbly_label(star_info_lbl, 13, Color(1, 0.96, 0.35), true)
	elif earned_stars == 2:
		star_info_lbl.text = "Under 90s (+50 Pts) • Finish in ≤60s for 3 Stars!"
		UIHelper.apply_bubbly_label(star_info_lbl, 12, Color(1, 0.90, 0.45), true)
	else:
		star_info_lbl.text = "Over 90s (+20 Pts) • Finish in ≤60s for 3 Stars!"
		UIHelper.apply_bubbly_label(star_info_lbl, 12, Color(1, 0.85, 0.45), true)
	star_info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(star_info_lbl)
	
	# Stats card inside
	var stats_panel = PanelContainer.new()
	var sp_st = UIHelper.create_bubbly_panel(16, Color(1, 1, 1, 0.94), Color.WHITE, 2.5)
	stats_panel.add_theme_stylebox_override("panel", sp_st)
	
	var stats_box = VBoxContainer.new()
	stats_box.add_theme_constant_override("separation", 6)
	
	var mins = int(time_elapsed) / 60
	var secs = int(time_elapsed) % 60
	var time_str = "%d:%02d" % [mins, secs]
	
	var t_row = Label.new()
	t_row.text = "Time: %s" % time_str
	t_row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(t_row, 17, Color(0.12, 0.36, 0.68), true)
	stats_box.add_child(t_row)
	
	var best_secs = int(p.get("memoryBest", time_elapsed))
	if best_secs <= 0:
		best_secs = int(time_elapsed)
	var b_mins = best_secs / 60
	var b_secs = best_secs % 60
	var best_str = "%d:%02d" % [b_mins, b_secs]
	
	var c_row = Label.new()
	c_row.text = "Best Time: %s" % best_str
	c_row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(c_row, 17, Color(0.95, 0.45, 0.10), true)
	stats_box.add_child(c_row)
	
	# Rewards row with doubled coin & star points graphic icons (44x44)
	var rew_hbox = HBoxContainer.new()
	rew_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	rew_hbox.add_theme_constant_override("separation", 12)
	
	# Coins pill
	var coin_badge = UIHelper.create_reward_badge("res://assets/images/cardmatchmini/gold_tooth_coin.png", "%d Coins" % final_coins, Color(0.86, 0.55, 0.05), 116.0, 40.0)
	rew_hbox.add_child(coin_badge)
	
	# Points pill
	var pt_badge = UIHelper.create_reward_badge("res://assets/images/cardmatchmini/purple_star_points.png", "%d Points" % final_points, Color(0.58, 0.28, 0.82), 116.0, 40.0)
	rew_hbox.add_child(pt_badge)
	
	stats_box.add_child(rew_hbox)
	stats_panel.add_child(stats_box)
	vbox.add_child(stats_panel)
	
	# Doubled Return to map button
	var btn_w = clamp(card_w - 24.0, 200.0, 260.0)
	var btn_h = 56.0
	var cont_btn = UIHelper.create_themed_button("returntomap", Vector2(btn_w, btn_h))
	if not cont_btn.texture_normal:
		cont_btn = UIHelper.create_bubbly_button("RETURN TO MAP", UIHelper.VIBRANT_GREEN)
		cont_btn.custom_minimum_size = Vector2(btn_w, 48)
	else:
		cont_btn.custom_minimum_size = Vector2(btn_w, btn_h)
		cont_btn.size = Vector2(btn_w, btn_h)
	cont_btn.pressed.connect(func():
		AudioManager.play_sfx("click")
		win_modal.queue_free()
		win_modal = null
		game_won.emit()
	)
	vbox.add_child(cont_btn)
	
	# Pop-in animation
	card.pivot_offset = Vector2(card_w * 0.5, card_h * 0.5)
	card.scale = Vector2(0.85, 0.85)
	card.modulate.a = 0.0
	var tw = card.create_tween().set_parallel(true)
	tw.tween_property(card, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "modulate:a", 1.0, 0.15)
