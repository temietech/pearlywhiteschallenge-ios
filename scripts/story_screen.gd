# scripts/story_screen.gd
extends Control

signal back_pressed

var current_page: int = 1 # 1 to 7 (4 stories per page)
var total_pages: int = 7

var top_bg: ColorRect
var back_btn: TextureButton
var unlock_label: Label
var unlock_progress: ProgressBar
var book_container: Control
var book_bg: TextureRect
var title_img: TextureRect
var cards_parent: Control
var prev_btn: TextureButton
var next_btn: TextureButton
var page_label: Label
var detail_modal: Control

const STORY_TITLES = [
	"Start: Blue Pursues", "The Great Escape", "Ask The Gingerbread", "Gingerbread Chase",
	"Peppermint Defense", "The Crossroads", "Choco River Crossing", "Fountain Hiding",
	"First Candy Combat", "Energy Refill Fruit", "The Friendly Banana", "Uncharted Waters",
	"Sea of Smiles", "The Sticky Trap", "Spotting Blue Fur", "Hide in the Bubbles",
	"Veggie Village", "Flora's Magic Seeds", "Second Candy Combat", "Run For It!",
	"Helping Hands", "Scouting Ahead", "Planting Good Habits", "The Clean Water Well",
	"Caterpillar in Hiding", "The Frosty Butterfly", "Near Mount Mulinia", "Victory & The Golden Smile"
]

const STORY_FILES = [
	"1_Start_Blue_Pursue.jpeg", "2_Run.jpeg", "3_Ask_gingerbread.jpeg", "4_Gingerbread_Chase_.jpeg",
	"5_Peppermint_Defense_.jpeg", "6_Crossroads.jpeg", "7_Choco_River.jpeg", "8_Fountain_Hiding.jpeg",
	"9_First_Candy_Combat.jpeg", "10_Energy_Refill_Fruit.jpeg", "11_Friendly_Banana.jpeg", "12_Unchartered_Waters.jpeg",
	"13_See_some_fish.jpeg", "14_Trap.jpeg", "15_Spot_Blue_Fur.jpeg", "16_Hide_in_water.jpeg",
	"17_Veggie_Village.jpeg", "18_Flora_Seeds.jpeg", "19_Second_Candy_Combat.jpeg", "20_Run_for_it.jpeg",
	"21_Help_eachother_up.jpeg", "22_Scouting.jpeg", "23_Plant_Seeds.jpeg", "24_Drinking_Well.jpeg",
	"25_Caterpillar_in_hiding.jpeg", "26_Frosty_Butterfly.jpeg", "27_Near_Mulinia.jpeg", "28_Finish.jpeg"
]

func _ready():
	set_anchors_preset(Control.PRESET_FULL_RECT)
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_right = 0
	offset_bottom = 0
	var p = GameState.get_active_profile()
	var unlocked_count = GameState.get_unlocked_story_count(p)
	if unlocked_count > 0:
		current_page = clamp(int(ceil(float(unlocked_count) / 4.0)), 1, total_pages)
	else:
		current_page = 1
	_build_ui()
	_relayout()
	_render_page()

func _notification(what):
	if what == NOTIFICATION_RESIZED:
		if is_node_ready():
			_relayout()
			_render_page()

func _build_ui():
	var safe_sz = UIHelper.get_viewport_safe_size(self)
	var cur_w = safe_sz.x
	var cur_h = safe_sz.y
	
	# Fullscreen Light Blue Background Plate
	top_bg = ColorRect.new()
	top_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	top_bg.color = Color(0.72, 0.88, 0.98)
	add_child(top_bg)
	
	# Top Back Button (Always top layer, never blocked by containers)
	back_btn = UIHelper.create_image_button("res://assets/images/shop/blue_back_button.png", Vector2(76, 32))
	if not back_btn.texture_normal:
		back_btn = UIHelper.create_image_button("res://assets/images/general/back_button.png", Vector2(76, 32))
	back_btn.position = Vector2(16, 14)
	back_btn.size = Vector2(76, 32)
	back_btn.custom_minimum_size = Vector2(76, 32)
	back_btn.z_index = 60
	back_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	back_btn.focus_mode = Control.FOCUS_NONE
	back_btn.pressed.connect(func():
		AudioManager.stop_narration()
		AudioManager.play_sfx("click")
		back_pressed.emit()
		var main_node = get_tree().root.get_node_or_null("Main")
		if main_node and main_node.has_method("navigate_to"):
			main_node.navigate_to("map")
	)
	add_child(back_btn)
	
	# Top Center Unlocked Stats (matches 18-story.png)
	unlock_label = Label.new()
	unlock_label.text = "UNLOCKED 0/28"
	unlock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(unlock_label, 13, Color(0.08, 0.28, 0.58), true)
	unlock_label.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0.8))
	unlock_label.add_theme_constant_override("shadow_offset_x", 0)
	unlock_label.add_theme_constant_override("shadow_offset_y", 1)
	unlock_label.z_index = 50
	add_child(unlock_label)
	
	unlock_progress = ProgressBar.new()
	unlock_progress.max_value = 28
	unlock_progress.value = 0
	unlock_progress.show_percentage = false
	var pb_bg = StyleBoxFlat.new()
	pb_bg.bg_color = Color(0.85, 0.93, 0.98, 0.95)
	pb_bg.border_width_left = 2
	pb_bg.border_width_right = 2
	pb_bg.border_width_top = 2
	pb_bg.border_width_bottom = 2
	pb_bg.border_color = Color.WHITE
	pb_bg.set_corner_radius_all(6)
	pb_bg.shadow_color = Color(0.06, 0.20, 0.40, 0.25)
	pb_bg.shadow_size = 2
	pb_bg.shadow_offset = Vector2(0, 1)
	
	var pb_fill = StyleBoxFlat.new()
	pb_fill.bg_color = Color(0.18, 0.58, 0.95) # High-contrast vibrant cyan-blue fill
	pb_fill.border_width_left = 1
	pb_fill.border_width_right = 1
	pb_fill.border_width_top = 1
	pb_fill.border_width_bottom = 1
	pb_fill.border_color = Color.WHITE
	pb_fill.set_corner_radius_all(5)
	
	unlock_progress.add_theme_stylebox_override("background", pb_bg)
	unlock_progress.add_theme_stylebox_override("fill", pb_fill)
	unlock_progress.z_index = 50
	add_child(unlock_progress)
	
	# Bounded Book Container (Centered cleanly on both phone & tablet)
	book_container = Control.new()
	book_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(book_container)
	
	# Open Notebook Page Texture
	book_bg = TextureRect.new()
	book_bg.texture = UIHelper.load_texture_safe("res://assets/images/scrapbook/storybookbgpage.png")
	book_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	book_bg.stretch_mode = TextureRect.STRETCH_SCALE
	book_container.add_child(book_bg)
	
	# Scrapbook Header Title Image: "BRUSH-A-TEER SCRAPBOOK"
	title_img = TextureRect.new()
	title_img.texture = UIHelper.load_texture_safe("res://assets/images/scrapbook/brush_a_tee_scrapbook.png")
	title_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	book_container.add_child(title_img)
	
	# 2x2 Story Cards Parent (Pass-through clicks so back button & cards work)
	cards_parent = Control.new()
	cards_parent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	book_container.add_child(cards_parent)
	
	# Bottom Page Navigation: < Page 1 of 7 >
	prev_btn = UIHelper.create_image_button("res://assets/images/journal/left_arrow_button.png", Vector2(32, 32))
	if not prev_btn.texture_normal:
		prev_btn = UIHelper.create_image_button("res://assets/images/createprofilescreen/left_arrow_button.png", Vector2(32, 32))
	prev_btn.size = Vector2(32, 32)
	prev_btn.custom_minimum_size = Vector2(32, 32)
	prev_btn.pressed.connect(func():
		if current_page > 1:
			AudioManager.play_sfx("click")
			current_page -= 1
			_render_page()
	)
	book_container.add_child(prev_btn)
	
	page_label = Label.new()
	page_label.text = "Page 1 of 7"
	page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(page_label, 13, Color(0.18, 0.48, 0.82), true)
	book_container.add_child(page_label)
	
	next_btn = UIHelper.create_image_button("res://assets/images/scrapbook/right_arrow_button.png", Vector2(32, 32))
	if not next_btn.texture_normal:
		next_btn = UIHelper.create_image_button("res://assets/images/createprofilescreen/right_arrow_button.png", Vector2(32, 32))
	next_btn.size = Vector2(32, 32)
	next_btn.custom_minimum_size = Vector2(32, 32)
	next_btn.pressed.connect(func():
		if current_page < total_pages:
			AudioManager.play_sfx("click")
			current_page += 1
			_render_page()
	)
	book_container.add_child(next_btn)

func _relayout():
	var safe_sz = UIHelper.get_viewport_safe_size(self)
	var cur_w = safe_sz.x
	var cur_h = safe_sz.y
	
	if back_btn:
		back_btn.position = Vector2(16.0, 14.0)
		back_btn.custom_minimum_size = Vector2(76, 32)
		back_btn.size = Vector2(76, 32)
		
	# Top bar & progress layout
	# Top-RIGHT corner (keeps the centre clear of the iPhone notch / Dynamic Island)
	if unlock_label:
		unlock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		unlock_label.position = Vector2(cur_w - 16.0 - 150.0, 8.0)
		unlock_label.size = Vector2(150, 20)
	if unlock_progress:
		unlock_progress.position = Vector2(cur_w - 16.0 - 120.0, 30.0)
		unlock_progress.size = Vector2(120, 12)
		
	# Book Page starts flush from the left border (x = 0.0) regardless of screen width
	var book_x = 0.0
	# Book (with its scrapbook title) sits below the notch; back + UNLOCKED stay in the corners
	var book_y = max(56.0, UIHelper.safe_top)
	var book_w = cur_w
	var book_h = cur_h - book_y - 8.0
	
	if book_container:
		book_container.position = Vector2(book_x, book_y)
		book_container.size = Vector2(book_w, book_h)
	if book_bg:
		book_bg.size = Vector2(book_w, book_h)
		book_bg.position = Vector2(0, 0)
	if cards_parent:
		cards_parent.size = Vector2(book_w, book_h)
		cards_parent.position = Vector2(0, 0)
		
	# Notebook page margins & printable center
	var is_tablet = cur_w >= 560
	var left_margin = clamp(book_w * 0.09, 52.0, 72.0) if is_tablet else clamp(book_w * 0.085, 34.0, 44.0)
	var right_margin = clamp(book_w * 0.055, 30.0, 48.0) if is_tablet else clamp(book_w * 0.05, 16.0, 24.0)
	var avail_w = book_w - left_margin - right_margin
	var page_center_x = left_margin + (avail_w * 0.5)
	
	# Constrained title banner
	if title_img:
		var max_tw = 360.0 if is_tablet else 270.0
		var tw = min(book_w - (80.0 if is_tablet else 60.0), max_tw)
		var th = tw * (64.0 / 260.0)
		title_img.size = Vector2(tw, th)
		title_img.position = Vector2(page_center_x - (tw * 0.5), 14.0)
		
	# Bottom Page Nav Row: clearly on the paper page surface
	var nav_y = book_h - (82.0 if is_tablet else 74.0)
	var nav_spacing = 92.0 if is_tablet else 76.0
	var nav_btn_dim = 36.0 if is_tablet else 32.0
	if prev_btn:
		prev_btn.position = Vector2(page_center_x - nav_spacing, nav_y)
		prev_btn.custom_minimum_size = Vector2(nav_btn_dim, nav_btn_dim)
		prev_btn.size = Vector2(nav_btn_dim, nav_btn_dim)
	if page_label:
		page_label.position = Vector2(page_center_x - 55.0, nav_y + 6.0)
		page_label.size = Vector2(110, 22 if is_tablet else 20)
		page_label.add_theme_font_size_override("font_size", 15 if is_tablet else 13)
	if next_btn:
		next_btn.position = Vector2(page_center_x + nav_spacing - nav_btn_dim, nav_y)
		next_btn.custom_minimum_size = Vector2(nav_btn_dim, nav_btn_dim)
		next_btn.size = Vector2(nav_btn_dim, nav_btn_dim)

func setup_story_view(auto_show_day: int):
	current_page = clamp(int(ceil(float(auto_show_day) / 4.0)), 1, total_pages)
	_render_page()
	call_deferred("_show_story_viewer", auto_show_day, auto_show_day - 1)

func _render_page():
	var p = GameState.get_active_profile()
	var unlocked_count = GameState.get_unlocked_story_count(p)
	
	if unlock_label:
		unlock_label.text = "UNLOCKED %d/28" % unlocked_count
	if unlock_progress:
		unlock_progress.value = unlocked_count
	if page_label:
		page_label.text = "Page %d of %d" % [current_page, total_pages]
	
	if prev_btn:
		prev_btn.disabled = (current_page <= 1)
		prev_btn.modulate = Color(0.7, 0.7, 0.7, 0.4) if current_page <= 1 else Color.WHITE
	if next_btn:
		next_btn.disabled = (current_page >= total_pages)
		next_btn.modulate = Color(0.7, 0.7, 0.7, 0.4) if current_page >= total_pages else Color.WHITE
	
	if not cards_parent or not book_container:
		return
		
	for c in cards_parent.get_children():
		c.queue_free()
		
	var book_w = book_container.size.x
	var book_h = book_container.size.y
	var is_tablet = book_w >= 560
	
	# Printable area inside the notebook page
	var left_margin = clamp(book_w * 0.09, 52.0, 72.0) if is_tablet else clamp(book_w * 0.085, 34.0, 44.0)
	var right_margin = clamp(book_w * 0.055, 30.0, 48.0) if is_tablet else clamp(book_w * 0.05, 16.0, 24.0)
	var avail_w = book_w - left_margin - right_margin
	
	# Vertical layout constraints
	var max_tw = 360.0 if is_tablet else 270.0
	var title_th = min(book_w - (80.0 if is_tablet else 60.0), max_tw) * (64.0 / 260.0)
	var title_bottom = 14.0 + title_th
	var nav_y = book_h - (82.0 if is_tablet else 74.0)
	var cards_bottom_max = nav_y - (18.0 if is_tablet else 12.0)
	var avail_cards_h = cards_bottom_max - title_bottom - (24.0 if is_tablet else 16.0)
	
	# Horizontal spacing: small gap matching reference
	var col_gap = 14.0 if is_tablet else 10.0
	var row_gap = 14.0 if is_tablet else 10.0
	
	# Cards fill the available area — each card is ~47% of avail_w, height derived from rows
	var card_w = (avail_w - col_gap) * 0.5
	var card_h = (avail_cards_h - row_gap) * 0.5
	
	var grid_total_w = card_w * 2.0 + col_gap
	var col1_x = left_margin + (avail_w - grid_total_w) * 0.5
	var col2_x = col1_x + card_w + col_gap
	
	var grid_total_h = card_h * 2.0 + row_gap
	var vert_slack = cards_bottom_max - title_bottom - grid_total_h
	var row1_y = title_bottom + (vert_slack * 0.45)
	var row2_y = row1_y + card_h + row_gap
	
	var card_positions = [
		Vector2(col1_x, row1_y),
		Vector2(col2_x, row1_y),
		Vector2(col1_x, row2_y),
		Vector2(col2_x, row2_y)
	]
	
	var start_idx = (current_page - 1) * 4
	for slot in range(4):
		var i = start_idx + slot
		if i < 28:
			var day_num = i + 1
			var is_unlocked = GameState.is_day_story_unlocked(day_num, p)
			var card = _create_story_card(day_num, i, is_unlocked, card_positions[slot], card_w, card_h, is_tablet)
			cards_parent.add_child(card)

func _create_story_card(day_num: int, idx: int, is_unlocked: bool, pos: Vector2, card_w: float, card_h: float, is_tablet: bool = false) -> Control:
	var card = Panel.new()
	card.position = pos
	card.size = Vector2(card_w, card_h)
	card.clip_contents = true
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color.WHITE
	card_style.set_corner_radius_all(28 if is_tablet else 22)
	card_style.shadow_color = Color(0.1, 0.2, 0.35, 0.10)
	card_style.shadow_size = 6 if is_tablet else 5
	card_style.shadow_offset = Vector2(0, 4 if is_tablet else 3)
	card.add_theme_stylebox_override("panel", card_style)
	
	if not is_unlocked:
		# Centered Silver Lock
		var lock_dim = min(card_w * 0.30, 60.0 if is_tablet else 48.0)
		var lock_img = UIHelper.create_texture_rect("res://assets/images/scrapbook/metal_lock_icon.png", Vector2(lock_dim, lock_dim * 1.22))
		if not lock_img.texture:
			lock_img = UIHelper.create_texture_rect("res://assets/images/misc/metal_lock_icon.png", Vector2(lock_dim, lock_dim * 1.22))
		lock_img.position = Vector2((card_w - lock_dim) * 0.5, (card_h * 0.43) - (lock_dim * 0.6))
		lock_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(lock_img)
		
		var keep_lbl = Label.new()
		keep_lbl.position = Vector2(4, card_h - (34.0 if is_tablet else 28.0))
		keep_lbl.size = Vector2(card_w - 8.0, 24.0 if is_tablet else 20.0)
		keep_lbl.text = "KEEP BRUSHING!"
		keep_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		keep_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		keep_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UIHelper.apply_bubbly_label(keep_lbl, 13 if is_tablet else 10, Color(0.18, 0.48, 0.82), true)
		card.add_child(keep_lbl)
	else:
		# Unlocked Story Thumbnail
		var img_pad = 9.0 if is_tablet else 7.0
		var img_w = card_w - (img_pad * 2.0)
		var title_area_h = 56.0 if is_tablet else 46.0
		var img_h = card_h - title_area_h - (img_pad * 2.0)
		
		var img_frame = Panel.new()
		img_frame.position = Vector2(img_pad, img_pad)
		img_frame.size = Vector2(img_w, img_h)
		img_frame.clip_contents = true
		var img_st = StyleBoxFlat.new()
		img_st.bg_color = Color(0.93, 0.96, 1.0)
		img_st.set_corner_radius_all(20 if is_tablet else 16)
		img_frame.add_theme_stylebox_override("panel", img_st)
		img_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(img_frame)
		
		var img_path = "res://assets/images/scrapbook/StoryPanels/%s" % STORY_FILES[idx]
		var img = TextureRect.new()
		img.set_anchors_preset(Control.PRESET_FULL_RECT)
		var img_tex = UIHelper.load_texture_safe(img_path)
		if img_tex:
			img.texture = img_tex
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		img_frame.add_child(img)
		
		# Number badge in top-left corner (Blue circle with white number)
		var badge_dim = 32.0 if is_tablet else 24.0
		var star_badge = Panel.new()
		star_badge.position = Vector2(img_pad, img_pad)
		star_badge.size = Vector2(badge_dim, badge_dim)
		var sb_st = StyleBoxFlat.new()
		sb_st.bg_color = Color(0.18, 0.54, 0.94)
		sb_st.set_corner_radius_all(16 if is_tablet else 12)
		sb_st.border_width_left = 2
		sb_st.border_width_right = 2
		sb_st.border_width_top = 2
		sb_st.border_width_bottom = 2
		sb_st.border_color = Color.WHITE
		sb_st.shadow_color = Color(0.06, 0.20, 0.45, 0.35)
		sb_st.shadow_size = 2
		star_badge.add_theme_stylebox_override("panel", sb_st)
		star_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(star_badge)
		
		var star_num = Label.new()
		star_num.set_anchors_preset(Control.PRESET_FULL_RECT)
		star_num.text = str(day_num)
		star_num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		star_num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		UIHelper.apply_bubbly_label(star_num, 14 if is_tablet else 11, Color.WHITE, true)
		star_num.add_theme_color_override("font_outline_color", Color(0.06, 0.22, 0.48))
		star_num.add_theme_constant_override("outline_size", 2)
		star_badge.add_child(star_num)
		
		# Title label
		var title_lbl = Label.new()
		title_lbl.position = Vector2(4.0, img_pad + img_h + 2.0)
		title_lbl.size = Vector2(card_w - 8.0, title_area_h - 4.0)
		title_lbl.text = "Day %d:\n%s" % [day_num, STORY_TITLES[idx]]
		title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UIHelper.apply_bubbly_label(title_lbl, 13 if is_tablet else 10, Color(0.14, 0.38, 0.65), true)
		card.add_child(title_lbl)
		
		# Tap to open button
		var btn = Button.new()
		btn.set_anchors_preset(Control.PRESET_FULL_RECT)
		btn.flat = true
		btn.pressed.connect(func():
			AudioManager.play_sfx("click")
			_show_story_viewer(day_num, idx)
		)
		card.add_child(btn)
		
	return card

func _show_story_viewer(day_num: int, idx: int):
	if detail_modal:
		detail_modal.queue_free()
		
	var safe_sz = UIHelper.get_viewport_safe_size(self)
	var cur_w = safe_sz.x
	var cur_h = safe_sz.y
	var p = GameState.get_active_profile()
	
	var dlg = UIHelper.create_modal_dialog(self, 100, Color(0.04, 0.10, 0.24, 0.80))
	detail_modal = dlg["overlay"]
	var backdrop = dlg["backdrop"]
	var center = dlg["center"]
	
	# Dimmed backdrop (clicking backdrop dismisses modal)
	backdrop.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			AudioManager.stop_narration()
			AudioManager.play_sfx("click")
			detail_modal.queue_free()
	)
	
	# Card Sizing: generously fill the screen for rich, immersive storybook viewing
	var card_w = clampf(cur_w * 0.88, 340.0, 520.0)
	var max_allowed_w = cur_w - 24.0
	if card_w > max_allowed_w:
		card_w = max_allowed_w
		
	var card_h = clampf(cur_h * 0.84, 500.0, 720.0)
	var max_allowed_h = cur_h - 28.0
	if card_h > max_allowed_h:
		card_h = max_allowed_h
	
	var card = Control.new()
	card.custom_minimum_size = Vector2(card_w, card_h)
	card.size = Vector2(card_w, card_h)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var card_bg = Panel.new()
	card_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var c_st = StyleBoxFlat.new()
	c_st.bg_color = Color(1.0, 1.0, 1.0, 0.98)
	c_st.set_corner_radius_all(24)
	c_st.set_border_width_all(3)
	c_st.border_color = Color(0.82, 0.92, 1.0)
	c_st.shadow_color = Color(0.04, 0.12, 0.28, 0.20)
	c_st.shadow_size = 10
	c_st.shadow_offset = Vector2(0, 4)
	card_bg.add_theme_stylebox_override("panel", c_st)
	card_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(card_bg)
	center.add_child(card)
	
	# Close button (crossbtn image) neatly inset inside top-right corner
	var close_x_btn = UIHelper.create_close_button(Vector2(34, 34))
	close_x_btn.position = Vector2(card_w - 42.0, 10.0)
	close_x_btn.z_index = 25
	var close_fn = func():
		AudioManager.stop_narration()
		AudioManager.play_sfx("click")
		detail_modal.queue_free()
	close_x_btn.pressed.connect(close_fn)
	card.add_child(close_x_btn)
	
	# Chapter Badge (Yellow/Gold pill badge at top center)
	var badge = Panel.new()
	var badge_w = 140.0
	var badge_h = 26.0
	badge.position = Vector2((card_w - badge_w) * 0.5, 14.0)
	badge.size = Vector2(badge_w, badge_h)
	var badge_st = StyleBoxFlat.new()
	badge_st.bg_color = Color(1.0, 0.82, 0.20)
	badge_st.set_corner_radius_all(13)
	badge_st.border_width_left = 2
	badge_st.border_width_right = 2
	badge_st.border_width_top = 2
	badge_st.border_width_bottom = 2
	badge_st.border_color = Color(1.0, 0.96, 0.70)
	badge_st.shadow_color = Color(0.1, 0.3, 0.5, 0.15)
	badge_st.shadow_size = 2
	badge_st.shadow_offset = Vector2(0, 1)
	badge.add_theme_stylebox_override("panel", badge_st)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(badge)
	
	var badge_lbl = Label.new()
	badge_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	badge_lbl.text = "CHAPTER %d" % day_num
	badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(badge_lbl, 12, Color(0.48, 0.26, 0.0), true)
	badge.add_child(badge_lbl)
	
	# Chapter Title
	var title_text = STORY_TITLES[idx] if idx < STORY_TITLES.size() else "Story Time"
	if idx < GameState.STORY.size():
		title_text = GameState.STORY[idx].get("title", title_text)
	
	var title_lbl = Label.new()
	title_lbl.position = Vector2(20.0, 44.0)
	title_lbl.size = Vector2(card_w - 40.0, 28.0)
	title_lbl.text = title_text
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(title_lbl, 18, Color(0.12, 0.32, 0.62), true)
	title_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.0))
	card.add_child(title_lbl)
	
	# Square Comic Artwork Frame (Enlarged to fill width with neat margins)
	var art_y = 68.0
	var max_art_w = card_w - 32.0
	var max_art_h = card_h - art_y - 180.0
	var art_size = clampf(min(max_art_w, max_art_h), 220.0, 480.0)
	
	var art_frame = Panel.new()
	art_frame.position = Vector2((card_w - art_size) * 0.5, art_y)
	art_frame.size = Vector2(art_size, art_size)
	art_frame.clip_contents = true
	var art_st = StyleBoxFlat.new()
	art_st.bg_color = Color.WHITE
	art_st.set_corner_radius_all(18)
	art_st.border_width_left = 3
	art_st.border_width_right = 3
	art_st.border_width_top = 3
	art_st.border_width_bottom = 3
	art_st.border_color = Color.WHITE
	art_st.shadow_color = Color(0.08, 0.22, 0.42, 0.20)
	art_st.shadow_size = 6
	art_st.shadow_offset = Vector2(0, 2)
	art_frame.add_theme_stylebox_override("panel", art_st)
	art_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(art_frame)
	
	var art_img = TextureRect.new()
	art_img.set_anchors_preset(Control.PRESET_FULL_RECT)
	var img_tex = UIHelper.load_texture_safe("res://assets/images/scrapbook/StoryPanels/%s" % STORY_FILES[idx])
	if img_tex:
		art_img.texture = img_tex
	art_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art_frame.add_child(art_img)
	
	# Bubble sparkles in picture corners
	var bubble_icon = UIHelper.load_texture_safe("res://assets/images/scrapbook/transparent_bubble.png")
	if not bubble_icon:
		bubble_icon = UIHelper.load_texture_safe("res://assets/images/scrapbook/bubble_asset.png")
	if bubble_icon:
		var b1 = TextureRect.new()
		b1.texture = bubble_icon
		b1.position = Vector2(6, 6)
		b1.size = Vector2(22, 22)
		b1.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		b1.modulate = Color(1, 1, 1, 0.7)
		art_frame.add_child(b1)
		
		var b2 = TextureRect.new()
		b2.texture = bubble_icon
		b2.position = Vector2(art_size - 26, art_size - 26)
		b2.size = Vector2(20, 20)
		b2.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		b2.modulate = Color(1, 1, 1, 0.6)
		art_frame.add_child(b2)
		
	# Story Narration Plaque (Clean crisp white inset panel)
	var plaque_y = art_y + art_size + 8.0
	var plaque_w = card_w - 32.0
	var btn_row_y = card_h - 52.0
	var plaque_h = (btn_row_y - 8.0) - plaque_y
	
	var plaque = Panel.new()
	plaque.position = Vector2(16.0, plaque_y)
	plaque.size = Vector2(plaque_w, plaque_h)
	var pl_st = StyleBoxFlat.new()
	pl_st.bg_color = Color(1.0, 1.0, 1.0, 0.96)
	pl_st.set_corner_radius_all(18)
	pl_st.border_width_left = 3
	pl_st.border_width_right = 3
	pl_st.border_width_top = 3
	pl_st.border_width_bottom = 3
	pl_st.border_color = Color(0.85, 0.94, 1.0)
	pl_st.shadow_color = Color(0.10, 0.22, 0.40, 0.10)
	pl_st.shadow_size = 4
	pl_st.shadow_offset = Vector2(0, 2)
	plaque.add_theme_stylebox_override("panel", pl_st)
	card.add_child(plaque)
	
	var story_text = "Chip and friends push onward through the kingdom, scrubbing every germ away with mighty foam power!"
	if idx < GameState.STORY.size():
		story_text = GameState.STORY[idx].get("panel", story_text)
		
	var story_lbl = Label.new()
	story_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	story_lbl.offset_left = 14.0
	story_lbl.offset_right = -14.0
	story_lbl.offset_top = 6.0
	story_lbl.offset_bottom = -6.0
	story_lbl.text = story_text
	story_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	story_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(story_lbl, 20, Color(0.12, 0.26, 0.48), true)
	story_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.0))
	story_lbl.add_theme_constant_override("line_spacing", 4)
	plaque.add_child(story_lbl)
	
	# Bottom Action Buttons Row
	var btn_hbox = HBoxContainer.new()
	btn_hbox.position = Vector2(16.0, btn_row_y)
	btn_hbox.size = Vector2(card_w - 32.0, 44.0)
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_theme_constant_override("separation", 12)
	card.add_child(btn_hbox)
	
	# Listen / Voice Narration button with dynamic Play / Pause / Resume states
	var speak_btn = UIHelper.create_themed_button("listen", Vector2(160.0, 44.0))
	if not speak_btn.texture_normal:
		speak_btn = UIHelper.create_bubbly_button("Listen", Color(0.20, 0.58, 0.94), Color.WHITE)
		speak_btn.custom_minimum_size = Vector2(160.0, 44.0)
		speak_btn.size = Vector2(160.0, 44.0)
	
	var update_speak_btn_ui = func():
		if not is_instance_valid(speak_btn):
			return
		var is_narrating = AudioManager.is_narrating() and not AudioManager.is_narration_paused
		var is_paused = AudioManager.is_narration_paused and AudioManager.current_narration_text == story_text
		
		if speak_btn is TextureButton:
			if is_narrating:
				var p_tex = UIHelper.get_button_texture("pause")
				if p_tex: speak_btn.texture_normal = p_tex
			elif is_paused:
				var r_tex = UIHelper.get_button_texture("resume")
				if r_tex: speak_btn.texture_normal = r_tex
			else:
				var l_tex = UIHelper.get_button_texture("listen")
				if l_tex: speak_btn.texture_normal = l_tex
		elif speak_btn is Button:
			if is_narrating:
				speak_btn.text = "Pause"
			elif is_paused:
				speak_btn.text = "Resume"
			else:
				speak_btn.text = "Listen"
	
	speak_btn.pressed.connect(func():
		AudioManager.play_sfx("click")
		AudioManager.toggle_narration(story_text)
		update_speak_btn_ui.call()
	)
	btn_hbox.add_child(speak_btn)
	
	# Auto-play voice narration if young child (ages 4-6) or auto-narration enabled
	if AudioManager.is_auto_narration_preferred():
		AudioManager.play_voice_narration(story_text, "", false)
		update_speak_btn_ui.call()
	
	# Periodic polling to revert button label when speech naturally concludes
	var narration_poll_timer = Timer.new()
	narration_poll_timer.wait_time = 0.4
	narration_poll_timer.autostart = true
	narration_poll_timer.timeout.connect(func():
		if is_instance_valid(speak_btn):
			update_speak_btn_ui.call()
		else:
			narration_poll_timer.stop()
			narration_poll_timer.queue_free()
	)
	detail_modal.add_child(narration_poll_timer)
	
	# Bouncy Pop-in Animation
	card.pivot_offset = Vector2(card_w * 0.5, card_h * 0.5)
	card.scale = Vector2(0.85, 0.85)
	card.modulate.a = 0.0
	var tw = card.create_tween().set_parallel(true)
	tw.tween_property(card, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "modulate:a", 1.0, 0.15)

