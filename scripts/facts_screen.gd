# scripts/facts_screen.gd
extends Control

signal back_pressed

var list_container: VBoxContainer
var count_label: Label
var bg: TextureRect
var title_img: TextureRect
var title_vbox: VBoxContainer
var notepad_rect: TextureRect
var pad_content: VBoxContainer
var detail_modal: Control
var back_btn: TextureButton
var scroll: ScrollContainer
var _target_scroll_day: int = 0

static var _cached_facts_title_tex: Texture2D = null
static var _cached_card_tex: Texture2D = null

func _get_card_texture() -> Texture2D:
	if _cached_card_tex and is_instance_valid(_cached_card_tex):
		return _cached_card_tex
	_cached_card_tex = UIHelper.load_texture_safe("res://assets/images/journal/white_rectangle_button.png")
	if not _cached_card_tex:
		_cached_card_tex = UIHelper.load_texture_safe("res://assets/images/misc/white_rectangle_button.png")
	return _cached_card_tex

func _ensure_facts_title_texture() -> Texture2D:
	if _cached_facts_title_tex and is_instance_valid(_cached_facts_title_tex):
		return _cached_facts_title_tex
		
	var path = "res://assets/images/journal/daily_dental_facts_title.png"
	# Exported builds (iPhone/iPad) only contain the imported texture, not the raw PNG,
	# so load through the resource system first (raw-file fallback below is editor-only).
	var imported_tex = UIHelper.load_texture_safe(path)
	if imported_tex:
		_cached_facts_title_tex = imported_tex
		return _cached_facts_title_tex
	var global_path = ProjectSettings.globalize_path(path)
	
	if FileAccess.file_exists(global_path):
		var img = Image.load_from_file(global_path)
		if img and not img.is_empty():
			_cached_facts_title_tex = ImageTexture.create_from_image(img)
			return _cached_facts_title_tex
			
	# Extract from screens/17-facts.png
	var screen_tex = UIHelper.load_texture_safe("res://screens/17-facts.png")
	if screen_tex:
		var full_img = screen_tex.get_image()
		if full_img and not full_img.is_empty():
			var iw = full_img.get_width()
			var ih = full_img.get_height()
			var rx = int(iw * 0.22)
			var ry = int(ih * 0.007)
			var rw = int(iw * 0.56)
			var rh = int(ih * 0.063)
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
					# Outline of title is dark blue contour (col.b > 0.38 and col.r < 0.30 and col.g < 0.50)
					var is_outline = (col.b > 0.38 and col.r < 0.30 and col.g < 0.50) or (col.r < 0.18 and col.g < 0.35 and col.b < 0.65)
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
				_cached_facts_title_tex = ImageTexture.create_from_image(cropped)
				return _cached_facts_title_tex
	return null

func _ready():
	set_anchors_preset(Control.PRESET_FULL_RECT)
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_right = 0
	offset_bottom = 0
	_build_ui()
	_relayout()
	_render_facts()
	call_deferred("_auto_scroll_to_day")

func setup_fact_view(day_num: int, is_review: bool = false):
	_target_scroll_day = day_num if day_num > 0 else get_most_recent_unlocked_fact_day()
	_render_facts()
	if not is_review and day_num >= 1 and day_num <= GameState.FACTS.size():
		var fact_text = GameState.FACTS[day_num - 1]
		call_deferred("_show_fact_modal", day_num, fact_text)
	call_deferred("_auto_scroll_to_day", _target_scroll_day)

func _notification(what):
	if what == NOTIFICATION_RESIZED:
		if is_node_ready():
			_relayout()
			_render_facts()

func _relayout():
	var safe_sz = UIHelper.get_viewport_safe_size(self)
	var cur_w = safe_sz.x
	var cur_h = safe_sz.y
	var is_tablet = cur_w >= 560
	
	if bg:
		bg.size = safe_sz
	if back_btn:
		back_btn.position = Vector2(14, 14)
	if title_img and title_img.texture:
		var tex_sz = title_img.texture.get_size()
		var tw = min(cur_w - 110.0, 340.0 if is_tablet else 270.0)
		var th = tw * (tex_sz.y / tex_sz.x)
		title_img.size = Vector2(tw, th)
		# Title drops below the notch on iPhone; the back button stays in the corner
		title_img.position = Vector2((cur_w - tw) * 0.5, max(12.0, UIHelper.safe_top + 6.0))
	elif title_vbox:
		title_vbox.size = Vector2(cur_w, 68)
		title_vbox.position = Vector2(0, max(10.0, UIHelper.safe_top + 4.0))
	if notepad_rect:
		var tex_aspect = 1.48
		if notepad_rect.texture and notepad_rect.texture.get_width() > 0:
			tex_aspect = float(notepad_rect.texture.get_height()) / float(notepad_rect.texture.get_width())
		
		var title_bottom = 76.0
		if title_img and title_img.texture:
			title_bottom = title_img.position.y + title_img.size.y + 6.0
		elif title_vbox:
			title_bottom = title_vbox.position.y + title_vbox.size.y + 6.0
		
		var max_avail_h = cur_h - title_bottom - (16.0 if is_tablet else 10.0)
		var max_avail_w = min(cur_w - 24.0, 580.0) if is_tablet else min(cur_w - 16.0, 480.0)
		
		# Strictly maintain the original aspect ratio of the notepad
		var np_w = max_avail_w
		var np_h = np_w * tex_aspect
		if np_h > max_avail_h:
			np_h = max_avail_h
			np_w = np_h / tex_aspect
			
		var np_x = (cur_w - np_w) * 0.5
		var np_y = title_bottom + (max_avail_h - np_h) * 0.35
		notepad_rect.size = Vector2(np_w, np_h)
		notepad_rect.position = Vector2(np_x, np_y)
		
		if pad_content:
			var pad_x = np_w * 0.08
			var pad_w = np_w - (pad_x * 2.0)
			var spiral_h = np_h * 0.135
			var pad_top = spiral_h + (6.0 if is_tablet else 2.0)
			var pad_bottom = np_h * 0.12
			var pad_h = np_h - pad_top - pad_bottom
			pad_content.position = Vector2(pad_x, pad_top)
			pad_content.size = Vector2(pad_w, pad_h)

func _build_ui():
	var safe_sz = UIHelper.get_viewport_safe_size(self)
	var cur_w = safe_sz.x
	var cur_h = safe_sz.y
	
	# Background
	bg = TextureRect.new()
	UIHelper.setup_fullscreen_bg(bg)
	bg.texture = UIHelper.load_texture_safe("res://assets/images/journal/diary_background.jpg")
	add_child(bg)
	
	# Header Title: Graphic Image (Clean transparent PNG) or Styled Bubbly Font fallback
	var t_tex = _ensure_facts_title_texture()
	if t_tex:
		title_img = TextureRect.new()
		title_img.texture = t_tex
		var tw = min(cur_w - 110.0, 260.0)
		var th = tw * (t_tex.get_height() / float(t_tex.get_width()))
		title_img.size = Vector2(tw, th)
		title_img.position = Vector2((cur_w - tw) * 0.5, 12.0)
		title_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		title_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		title_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(title_img)
	else:
		title_vbox = VBoxContainer.new()
		title_vbox.position = Vector2(0, 10)
		title_vbox.size = Vector2(cur_w, 68)
		title_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		title_vbox.add_theme_constant_override("separation", -4)
		title_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(title_vbox)
		
		var t1 = Label.new()
		t1.text = "DAILY DENTAL"
		t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UIHelper.apply_bubbly_label(t1, 23, Color.WHITE, true)
		t1.add_theme_color_override("font_shadow_color", Color(0.12, 0.40, 0.70))
		t1.add_theme_constant_override("shadow_offset_x", 2)
		t1.add_theme_constant_override("shadow_offset_y", 3)
		title_vbox.add_child(t1)
		
		var t2 = Label.new()
		t2.text = "FACTS JOURNAL"
		t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UIHelper.apply_bubbly_label(t2, 19, Color.WHITE, true)
		t2.add_theme_color_override("font_shadow_color", Color(0.12, 0.40, 0.70))
		t2.add_theme_constant_override("shadow_offset_x", 2)
		t2.add_theme_constant_override("shadow_offset_y", 3)
		title_vbox.add_child(t2)
	
	# Top Back Button (z_index = 50, added with high priority so it is never blocked)
	back_btn = UIHelper.create_image_button("res://assets/images/shop/blue_back_button.png", Vector2(86, 36))
	if not back_btn.texture_normal:
		back_btn = UIHelper.create_image_button("res://assets/images/journal/blue_back_button.png", Vector2(86, 36))
	if not back_btn.texture_normal:
		back_btn = UIHelper.create_image_button("res://assets/images/misc/blue_back_button.png", Vector2(86, 36))
	back_btn.position = Vector2(14, 14)
	back_btn.z_index = 50
	back_btn.focus_mode = Control.FOCUS_NONE
	back_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	back_btn.pressed.connect(func():
		AudioManager.stop_narration()
		AudioManager.play_sfx("click")
		back_pressed.emit()
	)
	add_child(back_btn)
	
	# Notepad Frame / Texture (aspect ratio strictly preserved in _relayout)
	notepad_rect = TextureRect.new()
	notepad_rect.texture = UIHelper.load_texture_safe("res://assets/images/journal/blue_notepad.png")
	notepad_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	notepad_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(notepad_rect)
	
	# Inside Notepad Content Container (layout positioned & sized in _relayout)
	pad_content = VBoxContainer.new()
	pad_content.add_theme_constant_override("separation", 6)
	notepad_rect.add_child(pad_content)
	
	# "0 / 28 COLLECTED" Pill
	var pill_box = CenterContainer.new()
	pill_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pill = PanelContainer.new()
	pill.custom_minimum_size = Vector2(190, 32)
	var p_style = UIHelper.create_bubbly_panel(16, Color.WHITE, Color(0.70, 0.85, 0.98), 2)
	pill.add_theme_stylebox_override("panel", p_style)
	count_label = Label.new()
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(count_label, 13, UIHelper.DEEP_BLUE, true)
	pill.add_child(count_label)
	pill_box.add_child(pill)
	pad_content.add_child(pill_box)
	
	# Scrollable List of Fact Cards
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	
	# Vibrant Blue Scrollbar per design specification
	var v_bar = scroll.get_v_scroll_bar()
	v_bar.custom_minimum_size.x = 7
	var grabber_sb = StyleBoxFlat.new()
	grabber_sb.bg_color = Color(0.18, 0.52, 0.88)
	grabber_sb.set_corner_radius_all(4)
	v_bar.add_theme_stylebox_override("grabber", grabber_sb)
	
	var grabber_hl = StyleBoxFlat.new()
	grabber_hl.bg_color = Color(0.10, 0.42, 0.80)
	grabber_hl.set_corner_radius_all(4)
	v_bar.add_theme_stylebox_override("grabber_highlight", grabber_hl)
	v_bar.add_theme_stylebox_override("grabber_pressed", grabber_hl)
	
	var track_sb = StyleBoxFlat.new()
	track_sb.bg_color = Color(0.80, 0.90, 0.98, 0.75)
	track_sb.set_corner_radius_all(4)
	v_bar.add_theme_stylebox_override("scroll", track_sb)
	v_bar.add_theme_stylebox_override("scroll_focus", track_sb)
	
	pad_content.add_child(scroll)
	
	list_container = VBoxContainer.new()
	list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_container.add_theme_constant_override("separation", 3)
	scroll.add_child(list_container)

func _render_facts():
	var p = GameState.get_active_profile()
	var collected = p.get("factsCollected", [])
	var unlocked_facts = p.get("unlockedFacts", [])
	var current_node = int(p.get("currentNode", 1))
	var current_day = GameState.day_for_node(current_node)
	var total_facts = 28
	
	var safe_sz = UIHelper.get_viewport_safe_size(self)
	var cur_w = safe_sz.x
	var is_tablet = cur_w >= 560
	
	var btn_tex = _get_card_texture()
	var tex_w = float(btn_tex.get_width()) if (btn_tex and btn_tex.get_width() > 0) else 330.0
	var tex_h = float(btn_tex.get_height()) if (btn_tex and btn_tex.get_height() > 0) else 96.0
	var inv_aspect = tex_h / tex_w
	
	# Determine card width to fill notepad inner width while leaving minimal margin for scrollbar
	var pad_w = pad_content.size.x if pad_content and pad_content.size.x > 50 else (cur_w * 0.8)
	var card_w = max(pad_w - 14.0, 160.0)
	# Strictly respect original aspect ratio: height = width * (tex_h / tex_w)
	var card_h = round(card_w * inv_aspect)
	
	var morning_done_for_current_day = GameState.is_day_morning_brush_done(current_day)
	# Max allowed unlocked fact index:
	# - If morning brush for current_day is completed: up to (current_day - 1)
	# - If morning brush for current_day is NOT yet completed: only up to (current_day - 2)
	var max_allowed_fact_idx = (current_day - 1) if morning_done_for_current_day else max(-1, current_day - 2)
	
	var unlocked_indices: Array[int] = []
	for i in range(total_facts):
		# A fact can only be unlocked if its day's morning brushing is actually completed
		if i <= max_allowed_fact_idx:
			unlocked_indices.append(i)
	
	count_label.text = "%d / %d COLLECTED" % [unlocked_indices.size(), total_facts]
	
	for c in list_container.get_children():
		c.queue_free()
		
	for i in range(total_facts):
		var is_unlocked = unlocked_indices.has(i)
		var fact_text = GameState.FACTS[i] if i < GameState.FACTS.size() else "Enamel is the hardest substance in the human body!"
		var card = _create_fact_card(i + 1, fact_text, is_unlocked, card_w, card_h, btn_tex, is_tablet)
		
		var row = CenterContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.custom_minimum_size = Vector2(0, card_h)
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(card)
		
		list_container.add_child(row)
		
	call_deferred("_auto_scroll_to_day")

func _create_fact_card(day_num: int, fact_text: String, is_unlocked: bool, card_w: float, card_h: float, btn_tex: Texture2D, is_tablet: bool = false) -> Control:
	var card = Control.new()
	card.custom_minimum_size = Vector2(card_w, card_h)
	card.size = Vector2(card_w, card_h)
	card.mouse_filter = Control.MOUSE_FILTER_PASS if is_unlocked else Control.MOUSE_FILTER_IGNORE
	
	# Background Texture with strict original aspect ratio preservation
	var bg_rect = TextureRect.new()
	bg_rect.texture = btn_tex
	bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not is_unlocked:
		bg_rect.modulate = Color(0.92, 0.94, 0.98, 0.88)
	card.add_child(bg_rect)
	
	if not is_unlocked:
		var center = CenterContainer.new()
		center.set_anchors_preset(Control.PRESET_FULL_RECT)
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		var vbox = VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 3)
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		var lock_w = 20.0 if is_tablet else 17.0
		var lock_img = UIHelper.create_texture_rect("res://assets/images/scrapbook/metal_lock_icon.png", Vector2(lock_w, lock_w * 1.25))
		if not lock_img.texture:
			lock_img = UIHelper.create_texture_rect("res://assets/images/misc/metal_lock_icon.png", Vector2(lock_w, lock_w * 1.25))
		lock_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(lock_img)
		
		var msg_lbl = Label.new()
		msg_lbl.text = "KEEP BRUSHING TO UNLOCK!"
		msg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		msg_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UIHelper.apply_bubbly_label(msg_lbl, 12 if is_tablet else 11, Color(0.42, 0.54, 0.68), true)
		vbox.add_child(msg_lbl)
		
		center.add_child(vbox)
		card.add_child(center)
	else:
		var margin = MarginContainer.new()
		margin.set_anchors_preset(Control.PRESET_FULL_RECT)
		margin.add_theme_constant_override("margin_left", 22 if is_tablet else 18)
		margin.add_theme_constant_override("margin_right", 22 if is_tablet else 18)
		margin.add_theme_constant_override("margin_top", 8)
		margin.add_theme_constant_override("margin_bottom", 8)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(margin)
		
		var text_vbox = VBoxContainer.new()
		text_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		text_vbox.add_theme_constant_override("separation", 2)
		text_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_child(text_vbox)
		
		var f_title = Label.new()
		f_title.text = "FACT %d" % day_num
		UIHelper.apply_bubbly_label(f_title, 14 if is_tablet else 13, Color(0.10, 0.32, 0.62), true)
		f_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text_vbox.add_child(f_title)
		
		var f_body = Label.new()
		f_body.text = fact_text
		f_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		f_body.max_lines_visible = 3
		f_body.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		UIHelper.apply_bubbly_label(f_body, 13 if is_tablet else 12, Color(0.16, 0.28, 0.48), false)
		f_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text_vbox.add_child(f_body)
		
		# Full card clickable to open detail modal with TTS
		var tap_btn = Button.new()
		tap_btn.set_anchors_preset(Control.PRESET_FULL_RECT)
		tap_btn.flat = true
		tap_btn.focus_mode = Control.FOCUS_NONE
		tap_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		tap_btn.pressed.connect(func():
			AudioManager.play_sfx("click")
			_show_fact_modal(day_num, fact_text)
		)
		card.add_child(tap_btn)
		
	return card

func _show_fact_modal(day_num: int, fact_text: String):
	if detail_modal:
		detail_modal.queue_free()
		
	var safe_sz = UIHelper.get_viewport_safe_size(self)
	var cur_w = safe_sz.x
	var cur_h = safe_sz.y
	
	detail_modal = Control.new()
	detail_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	detail_modal.z_index = 100
	add_child(detail_modal)
	
	# Dimmed backdrop
	var backdrop = ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.04, 0.10, 0.24, 0.80)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			AudioManager.stop_narration()
			AudioManager.play_sfx("click")
			detail_modal.queue_free()
	)
	detail_modal.add_child(backdrop)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_modal.add_child(center)
	
	var card_w = clamp(cur_w - 40.0, 310.0, 390.0)
	var card_h = clamp(cur_h * 0.44, 270.0, 330.0)
	var card = Panel.new()
	card.custom_minimum_size = Vector2(card_w, card_h)
	card.size = Vector2(card_w, card_h)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var card_st = StyleBoxFlat.new()
	card_st.bg_color = Color.WHITE
	card_st.set_corner_radius_all(26)
	card_st.border_width_left = 4
	card_st.border_width_right = 4
	card_st.border_width_top = 4
	card_st.border_width_bottom = 4
	card_st.border_color = Color(0.70, 0.85, 0.98)
	card_st.shadow_color = Color(0.03, 0.08, 0.20, 0.35)
	card_st.shadow_size = 18
	card_st.shadow_offset = Vector2(0, 8)
	card.add_theme_stylebox_override("panel", card_st)
	center.add_child(card)
	
	# Close button (crossbtn image)
	var close_btn = UIHelper.create_close_button(Vector2(34, 34))
	close_btn.position = Vector2(card_w - 44.0, 10.0)
	close_btn.pressed.connect(func():
		AudioManager.stop_narration()
		AudioManager.play_sfx("click")
		detail_modal.queue_free()
	)
	card.add_child(close_btn)
	
	# Header Pill: "DENTAL FACT #{day_num}"
	var pill = Panel.new()
	var pill_w = 170.0
	var pill_h = 28.0
	pill.position = Vector2((card_w - pill_w) * 0.5, 14.0)
	pill.size = Vector2(pill_w, pill_h)
	var pill_st = StyleBoxFlat.new()
	pill_st.bg_color = Color(0.88, 0.94, 1.0)
	pill_st.set_corner_radius_all(14)
	pill.add_theme_stylebox_override("panel", pill_st)
	card.add_child(pill)
	
	var pill_lbl = Label.new()
	pill_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	pill_lbl.text = "DENTAL FACT #%d" % day_num
	pill_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pill_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(pill_lbl, 12, Color(0.12, 0.38, 0.72), true)
	pill.add_child(pill_lbl)
	
	# Fact text (Significantly bigger and clearer)
	var text_lbl = Label.new()
	text_lbl.position = Vector2(20.0, 52.0)
	text_lbl.size = Vector2(card_w - 40.0, card_h - 122.0)
	text_lbl.text = fact_text
	text_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UIHelper.apply_bubbly_label(text_lbl, 18, Color(0.10, 0.22, 0.42), true)
	text_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	card.add_child(text_lbl)
	
	# Listen button with dynamic Play / Pause / Resume controls
	var btn_w = 150.0
	var btn_h = 44.0
	var listen_btn = UIHelper.create_themed_button("listen", Vector2(btn_w, btn_h))
	if not listen_btn.texture_normal:
		listen_btn = UIHelper.create_bubbly_button("Listen", Color(0.24, 0.62, 0.95), Color.WHITE)
		listen_btn.custom_minimum_size = Vector2(btn_w, btn_h)
		listen_btn.size = Vector2(btn_w, btn_h)
	listen_btn.position = Vector2((card_w - btn_w) * 0.5, card_h - btn_h - 18.0)
	
	var update_listen_btn_ui = func():
		if not is_instance_valid(listen_btn):
			return
		var is_narrating = AudioManager.is_narrating() and not AudioManager.is_narration_paused
		var is_paused = AudioManager.is_narration_paused and AudioManager.current_narration_text == fact_text
		
		if listen_btn is TextureButton:
			if is_narrating:
				var p_tex = UIHelper.get_button_texture("pause")
				if p_tex: listen_btn.texture_normal = p_tex
			elif is_paused:
				var r_tex = UIHelper.get_button_texture("resume")
				if r_tex: listen_btn.texture_normal = r_tex
			else:
				var l_tex = UIHelper.get_button_texture("listen")
				if l_tex: listen_btn.texture_normal = l_tex
		elif listen_btn is Button:
			if is_narrating:
				listen_btn.text = "Pause"
			elif is_paused:
				listen_btn.text = "Resume"
			else:
				listen_btn.text = "Listen"
			
	listen_btn.pressed.connect(func():
		AudioManager.play_sfx("click")
		AudioManager.toggle_narration(fact_text)
		update_listen_btn_ui.call()
	)
	card.add_child(listen_btn)
	
	# Auto-play voice narration if young child (ages 4-6) or auto-narration enabled
	if AudioManager.is_auto_narration_preferred():
		AudioManager.play_voice_narration(fact_text, "", false)
		update_listen_btn_ui.call()
		
	# Periodic polling to revert button label when speech finishes
	var narration_poll_timer = Timer.new()
	narration_poll_timer.wait_time = 0.4
	narration_poll_timer.autostart = true
	narration_poll_timer.timeout.connect(func():
		if is_instance_valid(listen_btn):
			update_listen_btn_ui.call()
		else:
			narration_poll_timer.stop()
			narration_poll_timer.queue_free()
	)
	detail_modal.add_child(narration_poll_timer)
	
	# Pop-in animation
	card.pivot_offset = Vector2(card_w * 0.5, 120.0)
	card.scale = Vector2(0.85, 0.85)
	card.modulate.a = 0.0
	var tw = card.create_tween().set_parallel(true)
	tw.tween_property(card, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "modulate:a", 1.0, 0.14)

func get_most_recent_unlocked_fact_day() -> int:
	var p = GameState.get_active_profile()
	if p.is_empty():
		return 1
	var current_node = int(p.get("currentNode", 1))
	var current_day = GameState.day_for_node(current_node)
	var morning_done = GameState.is_day_morning_brush_done(current_day, p)
	var max_day = current_day if morning_done else max(1, current_day - 1)
	return clampi(max_day, 1, 28)

func _auto_scroll_to_day(explicit_day: int = 0):
	var target_day = explicit_day
	if target_day <= 0:
		if _target_scroll_day > 0:
			target_day = _target_scroll_day
		else:
			target_day = get_most_recent_unlocked_fact_day()
			
	if not is_inside_tree():
		return
	await get_tree().process_frame
	await get_tree().process_frame
	scroll_to_fact_day(target_day, true)

func scroll_to_fact_day(day_num: int, animate: bool = true):
	_target_scroll_day = day_num
	if not is_node_ready() or not scroll or not is_instance_valid(scroll) or not list_container or not is_instance_valid(list_container):
		return
		
	var total_children = list_container.get_child_count()
	if total_children == 0:
		call_deferred("scroll_to_fact_day", day_num, animate)
		return
		
	var idx = clampi(day_num - 1, 0, total_children - 1)
	var child = list_container.get_child(idx) as Control
	if not child or not is_instance_valid(child):
		return
		
	var sep = 3.0
	if list_container.has_theme_constant_override("separation"):
		sep = float(list_container.get_theme_constant("separation"))
		
	var card_h = child.custom_minimum_size.y
	if card_h <= 0.0:
		card_h = child.size.y
	if card_h <= 0.0:
		card_h = 70.0
		
	var target_y = child.position.y
	if target_y <= 0.0:
		target_y = idx * (card_h + sep)
		
	var view_h = scroll.size.y
	if view_h <= 50.0:
		if pad_content and pad_content.size.y > 50.0:
			view_h = pad_content.size.y - 40.0
		else:
			var safe_sz = UIHelper.get_viewport_safe_size(self)
			view_h = safe_sz.y * 0.48
			
	# Center the card in the viewport
	var scroll_y = max(0.0, target_y - (view_h - card_h) * 0.5)
	
	var v_bar = scroll.get_v_scroll_bar()
	if v_bar:
		var max_scroll = max(0.0, v_bar.max_value - view_h)
		if max_scroll > 0.0:
			scroll_y = clampf(scroll_y, 0.0, max_scroll)
			
	var final_scroll_val = int(round(scroll_y))
	if animate:
		var tw = create_tween()
		tw.tween_property(scroll, "scroll_vertical", final_scroll_val, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		scroll.scroll_vertical = final_scroll_val
