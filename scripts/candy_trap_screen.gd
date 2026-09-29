# scripts/candy_trap_screen.gd
extends Control

signal completed
signal closed

var progress_percent: float = 0.0
var is_cleared: bool = false
var progress_bar: ProgressBar
var progress_lbl: Label
var candy_block_img: TextureRect
var back_glow: Panel
var is_dragging: bool = false
var last_touch_pos: Vector2 = Vector2.ZERO
var tooth_char: TextureRect
var claim_btn: BaseButton
var title_lbl: Label
var subtitle_lbl: Label
var char_name: String = "Spark"
var avatar_id: String = "spark"
var sfx_cooldown: float = 0.0
var particles_container: Control
var card: Panel
var title_img: TextureRect
var close_btn: TextureButton
var cube_container: Control
var touch_area: Control
var bg: TextureRect

func _ready():
	set_anchors_preset(Control.PRESET_FULL_RECT)
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_right = 0
	offset_bottom = 0
	_resolve_active_character()
	_build_ui()
	_relayout()

func _notification(what: int):
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_relayout()

func _process(delta: float):
	if sfx_cooldown > 0.0:
		sfx_cooldown -= delta

func _resolve_active_character():
	var p = GameState.get_active_profile()
	if p:
		avatar_id = p.get("avatar", "spark")
		for c in GameState.CHARACTERS:
			if c.get("id") == avatar_id:
				char_name = c.get("name", "Spark")
				break
		if char_name.is_empty():
			char_name = p.get("name", "Spark")

func _get_trapped_char_texture(id: String) -> Texture2D:
	var tex_path = "res://assets/images/candytrap/candytrap_%s.png" % id
	var tex = UIHelper.load_texture_safe(tex_path)
	if not tex:
		tex = UIHelper.load_texture_safe("res://assets/images/candytrap/sad_tooth_character.png")
	if not tex:
		tex = UIHelper.load_texture_safe("res://assets/images/characters/%s-nobg.png" % id)
	if not tex:
		tex = UIHelper.load_texture_safe("res://assets/images/characters/chip-nobg.png")
	return tex

func _build_ui():
	# Background Sky Gradient
	bg = TextureRect.new()
	UIHelper.setup_fullscreen_bg(bg)
	bg.texture = UIHelper.create_sky_gradient_texture()
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(bg)
	
	# Floating decorative background suds bubbles
	_spawn_background_bubbles()
	
	# Main Popup Card
	card = Panel.new()
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.98, 0.99, 1.0, 0.98)
	card_style.set_corner_radius_all(32)
	card_style.border_width_left = 4
	card_style.border_width_top = 4
	card_style.border_width_right = 4
	card_style.border_width_bottom = 4
	card_style.border_color = Color(1.0, 1.0, 1.0, 0.95)
	card_style.shadow_color = Color(0.08, 0.28, 0.55, 0.28)
	card_style.shadow_size = 22
	card_style.shadow_offset = Vector2(0, 8)
	card.add_theme_stylebox_override("panel", card_style)
	add_child(card)
	
	# Top Right Close X Button
	close_btn = UIHelper.create_close_button(Vector2(34, 34))
	close_btn.pressed.connect(func():
		AudioManager.play_sfx("click")
		closed.emit()
	)
	card.add_child(close_btn)
	
	# 3D Title Image: "CANDY TRAP"
	var title_tex = UIHelper.load_texture_safe("res://assets/images/titles/candytrap_title.png")
	if not title_tex:
		title_tex = UIHelper.load_texture_safe("res://assets/images/titles/candytrap_title.png")
	if title_tex:
		title_img = TextureRect.new()
		title_img.texture = title_tex
		title_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		title_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		title_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(title_img)
		
	# Sub-heading: "FREE [NAME]!"
	title_lbl = Label.new()
	title_lbl.text = "RUB AWAY THE CANDY TO FREE %s!" % char_name.to_upper()
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(title_lbl, 14 if title_img else 22, Color(0.15, 0.48, 0.90), true)
	card.add_child(title_lbl)
	
	# Center Candy Area Container (220x220)
	cube_container = Control.new()
	cube_container.size = Vector2(220, 220)
	card.add_child(cube_container)
	
	# 1. Warm Ambient Back Glow (behind character)
	back_glow = Panel.new()
	back_glow.position = Vector2(15, 15)
	back_glow.size = Vector2(190, 190)
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(1.0, 0.68, 0.16, 0.32)
	bg_style.set_corner_radius_all(36)
	bg_style.shadow_color = Color(0.95, 0.55, 0.10, 0.30)
	bg_style.shadow_size = 16
	back_glow.add_theme_stylebox_override("panel", bg_style)
	back_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cube_container.add_child(back_glow)
	
	# 2. Trapped Character (inside candy block)
	tooth_char = TextureRect.new()
	tooth_char.position = Vector2(20, 20)
	tooth_char.size = Vector2(180, 180)
	tooth_char.pivot_offset = Vector2(90, 90)
	tooth_char.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tooth_char.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tooth_char.texture = _get_trapped_char_texture(avatar_id)
	tooth_char.modulate = Color(1.0, 0.92, 0.85)
	cube_container.add_child(tooth_char)
	
	# 3. Authentic 3D Gummy Candy Block Overlay Asset (candytrap_block.png)
	candy_block_img = TextureRect.new()
	candy_block_img.position = Vector2.ZERO
	candy_block_img.size = Vector2(220, 220)
	candy_block_img.pivot_offset = Vector2(110, 110)
	candy_block_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	candy_block_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	var block_tex = UIHelper.load_texture_safe("res://assets/images/candytrap/candytrap_block.png")
	if block_tex:
		candy_block_img.texture = block_tex
		
	# Start slightly translucent (alpha = 0.72) so character inside is visible from the beginning
	candy_block_img.modulate = Color(1.0, 1.0, 1.0, 0.72)
	candy_block_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cube_container.add_child(candy_block_img)
	
	# 4. Touch & Drag Event Capture Area
	touch_area = Control.new()
	touch_area.position = Vector2.ZERO
	touch_area.size = Vector2(220, 220)
	touch_area.mouse_filter = Control.MOUSE_FILTER_STOP
	touch_area.gui_input.connect(_on_candy_gui_input)
	cube_container.add_child(touch_area)
	
	# Scrub Bubbles Particles Container
	particles_container = Control.new()
	particles_container.size = Vector2(220, 220)
	particles_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cube_container.add_child(particles_container)
	
	# Subtitle Instruction: "Use your finger to rub\nand melt the candy!"
	subtitle_lbl = Label.new()
	subtitle_lbl.text = "Use your finger to rub\nand melt the candy!"
	subtitle_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(subtitle_lbl, 15, Color(0.18, 0.50, 0.88), true)
	card.add_child(subtitle_lbl)
	
	# Progress Bar Container & Label
	progress_bar = ProgressBar.new()
	progress_bar.show_percentage = false
	var pb_bg = StyleBoxFlat.new()
	pb_bg.bg_color = Color(0.24, 0.45, 0.68)
	pb_bg.set_corner_radius_all(19)
	pb_bg.border_width_left = 2
	pb_bg.border_width_top = 2
	pb_bg.border_width_right = 2
	pb_bg.border_width_bottom = 2
	pb_bg.border_color = Color(1.0, 1.0, 1.0, 0.90)
	
	var pb_fill = StyleBoxFlat.new()
	pb_fill.bg_color = Color(0.18, 0.85, 0.96)
	pb_fill.set_corner_radius_all(19)
	progress_bar.add_theme_stylebox_override("background", pb_bg)
	progress_bar.add_theme_stylebox_override("fill", pb_fill)
	progress_bar.max_value = 100.0
	progress_bar.value = 0.0
	card.add_child(progress_bar)
	
	# Progress text inside bar: "0% Cleared" (Perfectly centered, zero clipping!)
	progress_lbl = Label.new()
	progress_lbl.anchors_preset = Control.PRESET_FULL_RECT
	progress_lbl.text = "0% Cleared"
	progress_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(progress_lbl, 14, Color.WHITE, true)
	progress_bar.add_child(progress_lbl)

func _relayout():
	var safe_sz = UIHelper.get_viewport_safe_size(self)
	var cur_w = safe_sz.x
	var cur_h = safe_sz.y
	
	if bg:
		bg.size = safe_sz
	
	if card:
		var card_w = min(cur_w - 32.0, 396.0)
		var card_h = 500.0 if not is_cleared else 530.0
		card.size = Vector2(card_w, card_h)
		card.position = Vector2((cur_w - card_w) * 0.5, max(20.0, (cur_h - card_h) * 0.5))
		
		if close_btn:
			close_btn.visible = not is_cleared
			close_btn.position = Vector2(card_w - 44.0, 12.0)
			close_btn.size = Vector2(34, 34)
			
		if not is_cleared:
			if title_img and is_instance_valid(title_img):
				var ti_w = min(card_w - 96.0, 240.0)
				title_img.position = Vector2((card_w - ti_w) * 0.5, 12)
				title_img.size = Vector2(ti_w, 42)
				if title_lbl:
					title_lbl.position = Vector2(16, 56)
					title_lbl.size = Vector2(card_w - 32, 28)
			elif title_lbl:
				title_lbl.position = Vector2(16, 36)
				title_lbl.size = Vector2(card_w - 32, 60)
			if cube_container:
				cube_container.position = Vector2((card_w - 220) * 0.5, 96)
				cube_container.size = Vector2(220, 220)
			if subtitle_lbl:
				subtitle_lbl.position = Vector2(20, 334)
				subtitle_lbl.size = Vector2(card_w - 40, 40)
			if progress_bar:
				var pb_w = card_w - 48.0
				progress_bar.position = Vector2(24, 398)
				progress_bar.size = Vector2(pb_w, 38)
				if progress_lbl:
					progress_lbl.size = Vector2(pb_w, 38)
		else:
			# Rescued state: spacious, clear layout
			if title_img and is_instance_valid(title_img):
				var ti_w = min(card_w - 96.0, 240.0)
				title_img.position = Vector2((card_w - ti_w) * 0.5, 12)
				title_img.size = Vector2(ti_w, 42)
				if title_lbl:
					title_lbl.position = Vector2(16, 56)
					title_lbl.size = Vector2(card_w - 32, 26)
			elif title_lbl:
				title_lbl.position = Vector2(16, 28)
				title_lbl.size = Vector2(card_w - 32, 48)
			if cube_container:
				cube_container.position = Vector2((card_w - 220) * 0.5, 84)
				cube_container.size = Vector2(220, 190)
			if subtitle_lbl:
				subtitle_lbl.position = Vector2(20, 288)
				subtitle_lbl.size = Vector2(card_w - 40, 34)
			if progress_bar:
				var pb_w = card_w - 48.0
				progress_bar.position = Vector2(24, 332)
				progress_bar.size = Vector2(pb_w, 38)
				if progress_lbl:
					progress_lbl.size = Vector2(pb_w, 38)
			if claim_btn and is_instance_valid(claim_btn):
				var btn_w = 230.0
				var btn_h = 52.0
				claim_btn.position = Vector2((card_w - btn_w) * 0.5, 394)
				claim_btn.custom_minimum_size = Vector2(btn_w, btn_h)

func _spawn_background_bubbles():
	var bubble_tex = UIHelper.load_texture_safe("res://assets/images/candytrap/bubble_icon.png")
	if not bubble_tex:
		bubble_tex = UIHelper.load_texture_safe("res://assets/images/surprisebox/bubble.png")
	
	var bubble_positions = [
		Vector2(40, 680), Vector2(160, 710), Vector2(320, 660),
		Vector2(390, 750), Vector2(90, 770), Vector2(360, 580)
	]
	
	for pos in bubble_positions:
		var b = TextureRect.new()
		b.position = pos
		var s = randf_range(28.0, 48.0)
		b.size = Vector2(s, s)
		b.texture = bubble_tex
		b.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		b.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		b.modulate = Color(1.0, 1.0, 1.0, randf_range(0.35, 0.65))
		add_child(b)
		
		# Gentle float upward
		var tw = b.create_tween().set_loops()
		var start_y = b.position.y
		tw.tween_property(b, "position:y", start_y - randf_range(30, 60), randf_range(3.0, 5.0)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(b, "position:y", start_y, randf_range(3.0, 5.0)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _on_candy_gui_input(event: InputEvent):
	if is_cleared:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			is_dragging = event.pressed
			if is_dragging:
				last_touch_pos = event.position
				_rub_step(event.position)
	elif event is InputEventMouseMotion and is_dragging:
		var dist = event.position.distance_to(last_touch_pos)
		if dist > 8.0:
			last_touch_pos = event.position
			_rub_step(event.position)

func _rub_step(touch_pos: Vector2):
	progress_percent = min(100.0, progress_percent + 2.5)
	progress_bar.value = progress_percent
	progress_lbl.text = "%d%% Cleared" % int(progress_percent)
	
	# Scrub sound with bubbly pitch variation
	if sfx_cooldown <= 0.0:
		AudioManager.play_sfx("pop", randf_range(1.15, 1.45))
		sfx_cooldown = 0.08
		
	# Spawn suds bubbles at touch position
	_spawn_melt_bubble(touch_pos)
	
	# Melt effect on amber candy block
	var remaining_ratio = 1.0 - (progress_percent / 100.0)
	if candy_block_img:
		candy_block_img.modulate.a = 0.72 * remaining_ratio
	if back_glow:
		var bg_st = back_glow.get_theme_stylebox("panel") as StyleBoxFlat
		if bg_st:
			bg_st.bg_color.a = 0.32 * remaining_ratio
			bg_st.shadow_color.a = 0.30 * remaining_ratio
			
	# Restore character's natural brightness as candy melts
	if tooth_char:
		tooth_char.modulate = Color(1.0, 0.92, 0.85).lerp(Color.WHITE, 1.0 - remaining_ratio)
		
	# Gelatin squish & spring wobble on the candy block as it's scrubbed
	if candy_block_img:
		var tw = candy_block_img.create_tween()
		tw.tween_property(candy_block_img, "scale", Vector2(1.04, 0.96), 0.035).set_trans(Tween.TRANS_SINE)
		tw.tween_property(candy_block_img, "scale", Vector2(0.97, 1.03), 0.035).set_trans(Tween.TRANS_SINE)
		tw.tween_property(candy_block_img, "scale", Vector2(1.0, 1.0), 0.04)
	
	if progress_percent >= 100.0 and not is_cleared:
		is_cleared = true
		_on_freed()

func _spawn_melt_bubble(local_pos: Vector2):
	var bubble_tex = UIHelper.load_texture_safe("res://assets/images/candytrap/bubble_icon.png")
	if not bubble_tex:
		bubble_tex = UIHelper.load_texture_safe("res://assets/images/misc/bubble_icon.png")
		
	var count = randi_range(1, 2)
	for i in range(count):
		var b = TextureRect.new()
		var b_size = randf_range(20.0, 38.0)
		b.size = Vector2(b_size, b_size)
		b.pivot_offset = Vector2(b_size * 0.5, b_size * 0.5)
		b.position = local_pos - Vector2(b_size * 0.5, b_size * 0.5) + Vector2(randf_range(-12, 12), randf_range(-12, 12))
		b.texture = bubble_tex
		b.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		b.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		
		# Vibrant translucent blue suds colors
		var blue_hues = [
			Color(0.32, 0.76, 1.0, randf_range(0.85, 0.98)),
			Color(0.20, 0.65, 0.98, randf_range(0.85, 0.95)),
			Color(0.42, 0.86, 1.0, randf_range(0.88, 1.0)),
			Color(0.55, 0.90, 1.0, randf_range(0.80, 0.95))
		]
		b.modulate = blue_hues[randi() % blue_hues.size()]
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.scale = Vector2(0.35, 0.35)
		particles_container.add_child(b)
		
		# Bubble motion: pop in, float upward with drift, and soft fade out
		var tw = b.create_tween()
		var target_pos = b.position + Vector2(randf_range(-24, 24), randf_range(-38, -68))
		tw.parallel().tween_property(b, "scale", Vector2(1.0, 1.0), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(b, "position", target_pos, randf_range(0.40, 0.60)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(b, "modulate:a", 0.0, randf_range(0.40, 0.60)).set_ease(Tween.EASE_IN)
		tw.tween_callback(b.queue_free)

func _on_freed():
	is_cleared = true
	if close_btn and is_instance_valid(close_btn):
		close_btn.visible = false
	AudioManager.play_sfx("cheer")
	
	GameState.add_points(50)
	GameState.add_molar_coins(25)
	
	var p = GameState.get_active_profile()
	if p:
		p["candyTrapPending"] = false
		if p.get("streak", 0) <= 0:
			p["streak"] = 1
		GameState.save_game()
		
	GameState.push_toast("%s is Free!" % char_name, "+50 Points & +25 Coins! Streak Restored!", "", "green")
	
	title_lbl.text = "%s IS FREE!" % char_name.to_upper()
	title_lbl.add_theme_color_override("font_color", Color(0.12, 0.75, 0.38))
	
	subtitle_lbl.text = "Awesome work! You melted the sticky candy!"
	subtitle_lbl.add_theme_color_override("font_color", Color(0.15, 0.65, 0.30))
	
	progress_lbl.text = "RESCUED! +50 PTS & +25 COINS"
	var fill_style = progress_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill_style:
		fill_style.bg_color = Color(0.20, 0.82, 0.36)
	
	if candy_block_img:
		candy_block_img.visible = false
	if back_glow:
		back_glow.visible = false
	tooth_char.modulate = Color.WHITE
	
	# Happy character texture
	var happy_tex = UIHelper.load_texture_safe("res://assets/images/characters/%s-nobg.png" % avatar_id)
	if not happy_tex:
		happy_tex = UIHelper.load_texture_safe("res://assets/images/characters/chip-nobg.png")
	if happy_tex:
		tooth_char.texture = happy_tex
		
	# Cheerful character bounce
	var tw = tooth_char.create_tween()
	tw.tween_property(tooth_char, "scale", Vector2(1.22, 1.22), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(tooth_char, "scale", Vector2(1.0, 1.0), 0.14)
	
	# Burst of celebration sparkles
	_spawn_celebration_burst()
	
	# Return to Map Button
	if not claim_btn:
		claim_btn = UIHelper.create_themed_button("returntomap", Vector2(230, 56))
		if not claim_btn.texture_normal:
			claim_btn = UIHelper.create_bubbly_button("RETURN TO MAP", UIHelper.VIBRANT_GREEN)
			claim_btn.custom_minimum_size = Vector2(230, 48)
		else:
			claim_btn.custom_minimum_size = Vector2(230, 56)
			claim_btn.size = Vector2(230, 56)
			
		claim_btn.pivot_offset = Vector2(115, 28)
		claim_btn.scale = Vector2(0.1, 0.1)
		claim_btn.pressed.connect(func():
			AudioManager.play_sfx("click")
			completed.emit()
		)
		card.add_child(claim_btn)
	
	_relayout()
	
	var btn_tw = claim_btn.create_tween()
	btn_tw.tween_property(claim_btn, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _spawn_celebration_burst():
	var colors = [
		Color(1.0, 0.85, 0.2), Color(0.2, 0.9, 0.4),
		Color(0.2, 0.7, 1.0), Color(1.0, 0.4, 0.7)
	]
	for i in range(20):
		var star = Label.new()
		star.text = "*"
		star.position = Vector2(110, 95)
		UIHelper.apply_bubbly_label(star, randi_range(16, 24), colors[i % colors.size()], true)
		particles_container.add_child(star)
		
		var angle = randf() * TAU
		var dist = randf_range(60.0, 130.0)
		var target = star.position + Vector2(cos(angle), sin(angle)) * dist
		
		var tw = star.create_tween()
		tw.parallel().tween_property(star, "position", target, randf_range(0.5, 0.8)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(star, "modulate:a", 0.0, randf_range(0.5, 0.8))
		tw.tween_callback(star.queue_free)
