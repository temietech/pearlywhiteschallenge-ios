# scripts/tutorial_overlay.gd
extends Control

signal tutorial_finished

const STEPS = [
	{
		"target": "",
		"title": "Welcome to the Pearly Whites Challenge!",
		"body": "A 28-day brushing adventure. Brush twice a day, beat Blue Candor and collect coins, points and badges. Let me show you around!"
	},
	{
		"target": "profile",
		"title": "This is you",
		"body": "Your character and name live here. Tap it any time to see your level, your progress and your collection."
	},
	{
		"target": "stats",
		"title": "Coins, Points & Streak",
		"body": "Coins buy new brushing gear, points buy power-ups, and the flame is your daily streak. Keep it alive by brushing every day!"
	},
	{
		"target": "settings",
		"title": "Settings",
		"body": "Sound, text-to-speech, adding family players and the Tooth Fairy bonus all live behind this gear."
	},
	{
		"target": "map-node",
		"title": "Your adventure map",
		"body": "Each day has a morning brush, a story panel, a mini-game and an evening brush. Tap the glowing spot to play the next one."
	},
	{
		"target": "nav-story",
		"title": "Storybook",
		"body": "A brand new comic panel unlocks every day you brush. Read the whole tale of the Pearly Whites."
	},
	{
		"target": "nav-shop",
		"title": "Shop & Arcade",
		"body": "Spend coins on stronger toothbrushes and paste, spend points on power-ups, and play the arcade mini-games."
	},
	{
		"target": "nav-badges",
		"title": "Badges",
		"body": "Every milestone earns a badge in bronze, silver or gold. Fill the shelves!"
	},
	{
		"target": "nav-facts",
		"title": "Smile Diary",
		"body": "One new dental fact appears each day you brush. Save your favourites to the diary."
	},
	{
		"target": "",
		"title": "You're all set!",
		"body": "Start with today's brush on the map. You can replay this tour any time from Settings."
	}
]

var current_step: int = 0
const ARROW_SIZE := 46.0
const ARROW_GAP := 6.0
var _arrow_points_up := true

var dim_bg: ColorRect
var spotlight_ring: Panel
var pointing_hand: TextureRect
var card_container: CenterContainer
var card_panel: PanelContainer
var step_lbl: Label
var skip_btn: TextureButton
var title_lbl: Label
var body_lbl: Label
var back_btn: TextureButton
var next_btn: TextureButton

var pulse_tween: Tween
var bob_tween: Tween
var _ui_built: bool = false

func _ready():
	set_anchors_preset(Control.PRESET_FULL_RECT)
	anchor_left = 0.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 1.0
	offset_left = 0
	offset_right = 0
	offset_top = 0
	offset_bottom = 0
	z_index = 200
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	_update_step()

func _exit_tree():
	if pulse_tween and pulse_tween.is_valid():
		pulse_tween.kill()
	if bob_tween and bob_tween.is_valid():
		bob_tween.kill()

func _notification(what: int):
	if what == NOTIFICATION_RESIZED:
		if is_node_ready() and _ui_built:
			_update_step()

func _build_ui():
	var safe_sz = UIHelper.get_viewport_safe_size(self)
	var cur_w = safe_sz.x
	var cur_h = safe_sz.y
	
	# 1. Fullscreen Dim Layer
	dim_bg = ColorRect.new()
	dim_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim_bg.anchor_right = 1.0
	dim_bg.anchor_bottom = 1.0
	dim_bg.color = Color(0.04, 0.12, 0.25, 0.72)
	dim_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim_bg)
	
	# 2. Glowing Spotlight Ring (Highlights target)
	spotlight_ring = Panel.new()
	var ring_style = StyleBoxFlat.new()
	ring_style.bg_color = Color(1, 1, 1, 0.08)
	ring_style.set_corner_radius_all(24)
	ring_style.border_color = Color(1.0, 1.0, 1.0, 0.95)
	ring_style.border_width_left = 3
	ring_style.border_width_top = 3
	ring_style.border_width_right = 3
	ring_style.border_width_bottom = 3
	ring_style.shadow_color = Color(1.0, 1.0, 1.0, 0.5)
	ring_style.shadow_size = 14
	spotlight_ring.add_theme_stylebox_override("panel", ring_style)
	spotlight_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spotlight_ring.visible = false
	add_child(spotlight_ring)
	
	# 3. Pointing Arrow Indicator (Animated Bobbing, real image, no emojis)
	pointing_hand = TextureRect.new()
	# Square blue arrow button (artwork points LEFT; rotated in _update_step)
	var arr_tex = UIHelper.load_texture_safe("res://assets/images/shop/blue_arrow_button.png")
	if not arr_tex:
		arr_tex = UIHelper.load_texture_safe("res://assets/images/mainmap/right_arrow_button.png")
	pointing_hand.texture = arr_tex
	pointing_hand.custom_minimum_size = Vector2(ARROW_SIZE, ARROW_SIZE)
	pointing_hand.size = Vector2(ARROW_SIZE, ARROW_SIZE)
	pointing_hand.pivot_offset = Vector2(ARROW_SIZE, ARROW_SIZE) * 0.5
	pointing_hand.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pointing_hand.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pointing_hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pointing_hand.visible = false
	add_child(pointing_hand)
	
	# 4. Coach Card Container
	card_container = CenterContainer.new()
	card_container.anchor_left = 0.0
	card_container.anchor_right = 1.0
	card_container.anchor_top = 0.0
	card_container.anchor_bottom = 0.0
	card_container.offset_left = 0
	card_container.offset_right = 0
	card_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(card_container)
	
	card_panel = PanelContainer.new()
	var card_w = clamp(cur_w - 32.0, 320.0, 400.0)
	card_panel.custom_minimum_size = Vector2(card_w, 250.0)
	var card_st = UIHelper.create_bubbly_panel(30, Color(0.35, 0.70, 0.98), Color.WHITE, 4)
	card_st.content_margin_left = 20
	card_st.content_margin_right = 20
	card_st.content_margin_top = 16
	card_st.content_margin_bottom = 16
	card_panel.add_theme_stylebox_override("panel", card_st)
	card_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	card_container.add_child(card_panel)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_panel.add_child(vbox)
	
	# Top Row: Step indicator pill & SKIP button
	var top_row = HBoxContainer.new()
	top_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(top_row)
	
	var pill = PanelContainer.new()
	var p_st = UIHelper.create_bubbly_panel(12, Color.WHITE)
	p_st.content_margin_left = 12
	p_st.content_margin_right = 12
	p_st.content_margin_top = 3
	p_st.content_margin_bottom = 3
	pill.add_theme_stylebox_override("panel", p_st)
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(pill)
	
	step_lbl = Label.new()
	step_lbl.text = "1 / 10"
	step_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIHelper.apply_bubbly_label(step_lbl, 11, Color(0.18, 0.48, 0.82), true)
	pill.add_child(step_lbl)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(spacer)
	
	skip_btn = UIHelper.create_themed_button("skiptutorial", Vector2(104, 32))
	skip_btn.pressed.connect(_on_skip_pressed)
	top_row.add_child(skip_btn)
	
	# Title
	title_lbl = Label.new()
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIHelper.apply_bubbly_label(title_lbl, 20, Color.WHITE, true)
	title_lbl.add_theme_color_override("font_shadow_color", Color(0.12, 0.40, 0.70))
	title_lbl.add_theme_constant_override("shadow_offset_x", 1)
	title_lbl.add_theme_constant_override("shadow_offset_y", 2)
	vbox.add_child(title_lbl)
	
	# Body
	body_lbl = Label.new()
	body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	body_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIHelper.apply_bubbly_label(body_lbl, 13, Color.WHITE)
	body_lbl.custom_minimum_size = Vector2(280, 52)
	vbox.add_child(body_lbl)
	
	# Bottom Row: BACK & NEXT
	var btn_row = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 14)
	btn_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(btn_row)
	
	back_btn = UIHelper.create_themed_button("back", Vector2(96, 44))
	back_btn.pressed.connect(_on_back_pressed)
	btn_row.add_child(back_btn)
	
	next_btn = UIHelper.create_themed_button("next", Vector2(116, 44))
	next_btn.pressed.connect(_on_next_pressed)
	btn_row.add_child(next_btn)
	
	_ui_built = true

func _start_bobbing():
	if not is_instance_valid(pointing_hand):
		return
	if bob_tween and bob_tween.is_valid():
		bob_tween.kill()
	var base_y = pointing_hand.position.y
	var bob := -6.0 if _arrow_points_up else 6.0  # nudge towards the target
	bob_tween = create_tween().set_loops()
	bob_tween.tween_property(pointing_hand, "position:y", base_y + bob, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob_tween.tween_property(pointing_hand, "position:y", base_y, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _get_target_rect(target: String) -> Rect2:
	var safe_sz = UIHelper.get_viewport_safe_size(self)
	var cur_w = safe_sz.x
	var cur_h = safe_sz.y
	var main_node = get_tree().root.get_node_or_null("Main")
	
	if target == "profile":
		if main_node and is_instance_valid(main_node.top_bar) and is_instance_valid(main_node.top_bar.avatar_btn) and main_node.top_bar.avatar_btn.is_inside_tree():
			var gr = main_node.top_bar.avatar_btn.get_global_rect()
			if gr.size.x > 10 and gr.size.y > 10:
				return gr
		return Rect2(8, 6, 74, 70)
		
	elif target == "stats":
		if main_node and is_instance_valid(main_node.top_bar) and is_instance_valid(main_node.top_bar.stats_banner) and main_node.top_bar.stats_banner.is_inside_tree():
			var gr = main_node.top_bar.stats_banner.get_global_rect()
			if gr.size.x > 10 and gr.size.y > 10:
				return gr
		var bw = clamp(cur_w * 0.58, 288.0, 360.0)
		var bh = bw / 4.89
		var mid_x = ((8.0 + 72.0 + 8.0) + (cur_w - 52.0 - 8.0)) * 0.5
		return Rect2(mid_x - bw * 0.5, 6, bw, bh)
		
	elif target == "settings":
		if main_node and is_instance_valid(main_node.top_bar) and is_instance_valid(main_node.top_bar.settings_btn) and main_node.top_bar.settings_btn.is_inside_tree():
			var gr = main_node.top_bar.settings_btn.get_global_rect()
			if gr.size.x > 10 and gr.size.y > 10:
				return gr
		return Rect2(cur_w - 52, 14, 44, 44)
		
	elif target == "map-node":
		var active_node = get_tree().get_first_node_in_group("active_map_node")
		if active_node and active_node is Control and active_node.is_inside_tree():
			var gr = active_node.get_global_rect()
			if gr.size.x > 5 and gr.size.y > 5:
				var x = gr.position.x - 14
				var y = gr.position.y - 74
				var w = gr.size.x + 28
				var h = gr.size.y + 82
				return Rect2(x, y, w, h)
		return Rect2((cur_w - 80) * 0.5, cur_h * 0.46, 80, 80)
		
	elif target.begins_with("nav-"):
		var tab_id = target.substr(4)
		if main_node and is_instance_valid(main_node.bottom_nav) and main_node.bottom_nav.button_nodes.has(tab_id):
			var btn = main_node.bottom_nav.button_nodes[tab_id]
			if btn and is_instance_valid(btn) and btn.is_inside_tree():
				var gr = btn.get_global_rect()
				if gr.size.x > 10 and gr.size.y > 10:
					return gr
		var slot_w = cur_w / 5.0
		var idx = ["map", "story", "shop", "badges", "facts"].find(tab_id)
		if idx == -1: idx = 0
		var btn_w = clamp(slot_w * 0.96, 72.0, 82.0)
		var btn_h = round(btn_w * 1.14)
		return Rect2(idx * slot_w + (slot_w - btn_w) * 0.5, cur_h - btn_h - 2, btn_w, btn_h)
		
	return Rect2()

func _update_step():
	if not _ui_built or not is_inside_tree():
		return
	if not is_instance_valid(step_lbl) or not is_instance_valid(title_lbl) or not is_instance_valid(body_lbl) or not is_instance_valid(card_container) or not is_instance_valid(next_btn) or not is_instance_valid(back_btn):
		return
		
	var safe_sz = UIHelper.get_viewport_safe_size(self)
	var cur_w = safe_sz.x
	var cur_h = safe_sz.y
	
	if current_step < 0 or current_step >= STEPS.size():
		current_step = 0
		
	var data = STEPS[current_step]
	step_lbl.text = str(current_step + 1) + " / " + str(STEPS.size())
	title_lbl.text = data["title"]
	body_lbl.text = data["body"]
	
	back_btn.visible = (current_step > 0)
	if current_step == STEPS.size() - 1:
		next_btn.texture_normal = UIHelper.get_button_texture("letsbrush")
		next_btn.custom_minimum_size = Vector2(160, 46)
		next_btn.size = Vector2(160, 46)
		next_btn.pivot_offset = Vector2(80, 23)
	else:
		next_btn.texture_normal = UIHelper.get_button_texture("next")
		next_btn.custom_minimum_size = Vector2(116, 44)
		next_btn.size = Vector2(116, 44)
		next_btn.pivot_offset = Vector2(58, 22)
		
	var target = data["target"]
	var target_rect = _get_target_rect(target) if target != "" else Rect2()
	var has_target = (target != "" and target_rect.size.x > 0 and target_rect.size.y > 0)
		
	if has_target:
		if is_instance_valid(spotlight_ring):
			spotlight_ring.visible = true
			spotlight_ring.position = target_rect.position - Vector2(5, 5)
			spotlight_ring.size = target_rect.size + Vector2(10, 10)
			
			var ring_style = spotlight_ring.get_theme_stylebox("panel") as StyleBoxFlat
			if ring_style:
				if target == "stats":
					ring_style.set_corner_radius_all(18)
				elif target == "settings" or target == "profile":
					ring_style.set_corner_radius_all(22)
				elif target.begins_with("nav-"):
					ring_style.set_corner_radius_all(16)
				else:
					ring_style.set_corner_radius_all(24)
			
			# Pulse spotlight ring
			if pulse_tween and pulse_tween.is_valid():
				pulse_tween.kill()
			pulse_tween = create_tween().set_loops()
			pulse_tween.tween_property(spotlight_ring, "modulate:a", 0.55, 0.55).set_trans(Tween.TRANS_SINE)
			pulse_tween.tween_property(spotlight_ring, "modulate:a", 1.0, 0.55).set_trans(Tween.TRANS_SINE)
		
		if is_instance_valid(pointing_hand):
			pointing_hand.visible = true
			pointing_hand.size = Vector2(ARROW_SIZE, ARROW_SIZE)
			pointing_hand.pivot_offset = Vector2(ARROW_SIZE, ARROW_SIZE) * 0.5
			var is_blue_square: bool = pointing_hand.texture != null and pointing_hand.texture.get_width() > 200
			# rotation that turns the artwork's direction into UP / DOWN
			var rot_up: float = 90.0 if is_blue_square else -90.0
			var hand_x = clamp(target_rect.position.x + target_rect.size.x * 0.5 - ARROW_SIZE * 0.5, 8.0, cur_w - ARROW_SIZE - 8.0)
			var card_h := 240.0

			var point_up: bool = not (target.begins_with("nav-") or target_rect.position.y > (cur_h - 130.0)) and (target_rect.position.y + target_rect.size.y * 0.5) < (cur_h * 0.46)
			_arrow_points_up = point_up
			if point_up:
				# Target near the top: arrow just below it pointing UP, card just below the arrow
				pointing_hand.rotation_degrees = rot_up
				var arrow_y: float = target_rect.end.y + ARROW_GAP
				pointing_hand.position = Vector2(hand_x, arrow_y)
				var card_top: float = clamp(arrow_y + ARROW_SIZE + ARROW_GAP, 60.0, cur_h - card_h - 10.0)
				card_container.offset_top = card_top
				card_container.offset_bottom = card_top + card_h
			else:
				# Target lower down / bottom nav: arrow just above it pointing DOWN, card above the arrow
				pointing_hand.rotation_degrees = rot_up + 180.0
				var arrow_y2: float = target_rect.position.y - ARROW_GAP - ARROW_SIZE
				pointing_hand.position = Vector2(hand_x, arrow_y2)
				var card_top2: float = clamp(arrow_y2 - ARROW_GAP - card_h, 40.0, cur_h - card_h - 10.0)
				card_container.offset_top = card_top2
				card_container.offset_bottom = card_top2 + card_h
				
			_start_bobbing()
	else:
		if is_instance_valid(spotlight_ring):
			spotlight_ring.visible = false
		if is_instance_valid(pointing_hand):
			pointing_hand.visible = false
		if pulse_tween and pulse_tween.is_valid():
			pulse_tween.kill()
		if bob_tween and bob_tween.is_valid():
			bob_tween.kill()
		# Centered card
		var target_y = (cur_h - 240.0) * 0.5
		card_container.offset_top = target_y
		card_container.offset_bottom = target_y + 240

func _on_next_pressed():
	if current_step < STEPS.size() - 1:
		AudioManager.play_sfx("pop")
		current_step += 1
		_update_step()
	else:
		_finish_tutorial()

func _on_back_pressed():
	if current_step > 0:
		AudioManager.play_sfx("click")
		current_step -= 1
		_update_step()

func _on_skip_pressed():
	AudioManager.play_sfx("click")
	_finish_tutorial()

func _finish_tutorial():
	AudioManager.play_sfx("cheer")
	var p = GameState.get_active_profile()
	if not p.is_empty():
		p["tutorial_done"] = true
		GameState.save_game()
	tutorial_finished.emit()
	queue_free()
