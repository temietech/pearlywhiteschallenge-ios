# scripts/select_player_screen.gd
extends Control

signal player_chosen(profile_id: String)
signal manage_players_requested

var current_index: int = 0
var profiles_list: Array[Dictionary] = []

var bg: TextureRect
var title_img: TextureRect
var cards_flow: FlowContainer
var card_nodes: Array[Control] = []
var choose_btn: Control
var manage_btn: Button

func _ready():
	set_anchors_preset(Control.PRESET_FULL_RECT)
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_right = 0
	offset_bottom = 0
	_build_ui()
	_load_profiles()
	_relayout()

func _notification(what):
	if what == NOTIFICATION_RESIZED:
		if is_node_ready():
			_relayout()

static func _get_choose_btn_texture() -> Texture2D:
	var tex = UIHelper.get_button_texture("chooseplayer")
	if tex: return tex
	var path1 = "res://assets/images/whoisplayingpick/chooseplayerbtn.png"
	tex = UIHelper.load_texture_safe(path1)
	if tex: return tex
	return null

func _build_ui():
	# Clean bubbly sky background with gently rising bubbles
	bg = UIHelper.setup_clean_bubbly_bg(self)

	# Title: "Who is playing?" image asset
	var title_tex = UIHelper.load_texture_safe("res://assets/images/whoisplayingpick/title-whoisplaying.png")
	if not title_tex:
		title_tex = UIHelper.load_texture_safe("res://assets/images/misc/title-whoisplaying.png")
	title_img = TextureRect.new()
	title_img.texture = title_tex
	title_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(title_img)

	# Cards FlowContainer (no scroll bar, wraps naturally)
	cards_flow = FlowContainer.new()
	cards_flow.alignment = FlowContainer.ALIGNMENT_CENTER
	cards_flow.add_theme_constant_override("h_separation", 18)
	cards_flow.add_theme_constant_override("v_separation", 18)
	add_child(cards_flow)

	# 3D Pill "Choose Player" Button (using chooseplayerbtn.png)
	var btn_tex = _get_choose_btn_texture()
	if btn_tex:
		var tb = TextureButton.new()
		tb.ignore_texture_size = true
		tb.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		tb.texture_normal = btn_tex
		choose_btn = tb
		choose_btn.button_down.connect(func():
			AudioManager.play_sfx("click")
			var tw = choose_btn.create_tween()
			tw.tween_property(choose_btn, "scale", Vector2(0.96, 0.96), 0.08)
		)
		choose_btn.button_up.connect(func():
			var tw = choose_btn.create_tween()
			tw.tween_property(choose_btn, "scale", Vector2.ONE, 0.08)
		)
		tb.pressed.connect(_on_choose_pressed)
	else:
		var btn = Button.new()
		var btn_st = StyleBoxFlat.new()
		btn_st.bg_color = Color(0.24, 0.62, 0.88)
		btn_st.set_corner_radius_all(33)
		btn_st.border_width_left = 3
		btn_st.border_width_right = 3
		btn_st.border_width_top = 3
		btn_st.border_width_bottom = 3
		btn_st.border_color = Color.WHITE
		btn_st.shadow_color = Color(0.1, 0.35, 0.65, 0.3)
		btn_st.shadow_size = 8
		btn_st.shadow_offset = Vector2(0, 4)
		btn.add_theme_stylebox_override("normal", btn_st)
		btn.add_theme_stylebox_override("hover", btn_st)
		btn.add_theme_stylebox_override("pressed", btn_st)
		btn.text = "Choose Player"
		UIHelper.apply_bubbly_label(btn, 22, Color.WHITE, true)
		btn.pressed.connect(_on_choose_pressed)
		choose_btn = btn
	add_child(choose_btn)

	# "Manage Players" link button below Choose Player
	manage_btn = Button.new()
	manage_btn.flat = true
	manage_btn.text = "Manage Players"
	UIHelper.apply_bubbly_label(manage_btn, 16, Color(0.20, 0.50, 0.80), true)
	manage_btn.pressed.connect(func():
		AudioManager.play_sfx("click")
		manage_players_requested.emit()
	)
	add_child(manage_btn)

func _relayout():
	var safe_sz = UIHelper.get_viewport_safe_size(self)
	var cur_w = safe_sz.x
	var cur_h = safe_sz.y

	if bg:
		bg.size = safe_sz

	# Compute dimensions of each section
	var tw = min(cur_w - 32.0, 340.0)
	var th = tw * (64.0 / 340.0)
	var flow_w = cur_w - 20.0
	var btn_w = min(cur_w - 48.0, 320.0)
	var btn_h = 68.0
	var mg_w = 200.0
	var mg_h = 36.0

	# Responsive card sizing
	var base_card_w = 144.0
	var base_card_h = 190.0
	var card_gap = 18.0
	var min_card_w = 110.0
	var actual_card_w = base_card_w
	var num_cards = profiles_list.size()
	if num_cards > 0:
		var total_needed = num_cards * base_card_w + (num_cards - 1) * card_gap
		if total_needed > flow_w:
			actual_card_w = max(min_card_w, (flow_w - (num_cards - 1) * card_gap) / num_cards)
	var actual_card_h = actual_card_w * (base_card_h / base_card_w)

	for cn in card_nodes:
		cn.custom_minimum_size = Vector2(actual_card_w, actual_card_h)
		cn.size = Vector2(actual_card_w, actual_card_h)
		cn.pivot_offset = Vector2(actual_card_w * 0.5, actual_card_h * 0.5)

	# Calculate how many cards fit per row
	var cards_per_row = 1
	if num_cards > 0:
		cards_per_row = int((flow_w + card_gap) / (actual_card_w + card_gap))
		cards_per_row = max(1, cards_per_row)

	# Calculate number of rows needed
	var num_rows = 1
	if num_cards > 0:
		num_rows = ceili(float(num_cards) / float(cards_per_row))

	# Calculate actual flow container height based on rows
	var flow_h = num_rows * actual_card_h + (num_rows - 1) * card_gap + 25.0

	var gap_title_to_cards = 48.0
	var gap_cards_to_choose = 48.0
	var gap_choose_to_manage = 22.0

	# Total stack height
	var total_h = th + gap_title_to_cards + flow_h + gap_cards_to_choose + btn_h + gap_choose_to_manage + mg_h
	# Vertically centered starting Y
	var start_y = max(24.0, (cur_h - total_h) * 0.5)

	if title_img:
		title_img.size = Vector2(tw, th)
		title_img.position = Vector2((cur_w - tw) * 0.5, start_y)

	var card_row_y = start_y + th + gap_title_to_cards
	if cards_flow:
		cards_flow.size = Vector2(flow_w, flow_h)
		cards_flow.position = Vector2(10.0, card_row_y)

	var btn_y = card_row_y + flow_h + gap_cards_to_choose
	if choose_btn:
		choose_btn.size = Vector2(btn_w, btn_h)
		choose_btn.pivot_offset = Vector2(btn_w * 0.5, btn_h * 0.5)
		choose_btn.position = Vector2((cur_w - btn_w) * 0.5, btn_y)

	if manage_btn:
		manage_btn.size = Vector2(mg_w, mg_h)
		manage_btn.position = Vector2((cur_w - mg_w) * 0.5, btn_y + btn_h + gap_choose_to_manage)

	# Re-apply highlights so scale/pivot are correct after resize
	_update_card_highlights()

func _load_profiles():
	profiles_list = GameState.get_profiles()
	if profiles_list.is_empty():
		var def_p = GameState.get_active_profile()
		if not def_p.is_empty():
			profiles_list.append(def_p)

	current_index = 0
	for i in range(profiles_list.size()):
		if profiles_list[i].get("id", "") == GameState.active_id:
			current_index = i
			break

	_render_player_cards()

func _render_player_cards():
	for c in cards_flow.get_children():
		c.queue_free()
	card_nodes.clear()

	if profiles_list.is_empty():
		profiles_list.append({"id": "default", "name": "Player", "avatar": "chip"})

	for i in range(profiles_list.size()):
		var p = profiles_list[i]
		var card = _create_player_card(p, i)
		cards_flow.add_child(card)
		card_nodes.append(card)

	_update_card_highlights()

func _create_player_card(p: Dictionary, idx: int) -> Control:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(144, 190)
	card.size = Vector2(144, 190)
	card.pivot_offset = Vector2(72, 95)
	card.mouse_filter = Control.MOUSE_FILTER_PASS

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 10)
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	card.add_child(vbox)

	# Top spacer
	var sp1 = Control.new()
	sp1.custom_minimum_size = Vector2(0, 4)
	vbox.add_child(sp1)

	# Avatar
	var av_id = p.get("avatar_id", p.get("avatar", "chip"))
	var av_tex = UIHelper.get_avatar_texture(av_id)
	var av_rect = TextureRect.new()
	av_rect.custom_minimum_size = Vector2(104, 104)
	av_rect.size = Vector2(104, 104)
	av_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	av_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	av_rect.texture = av_tex
	av_rect.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(av_rect)

	# Name Label
	var n_lbl = Label.new()
	n_lbl.text = p.get("name", "Player")
	n_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	n_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	UIHelper.apply_bubbly_label(n_lbl, 16, Color(0.12, 0.38, 0.65), true)
	vbox.add_child(n_lbl)

	# Full card click button overlay
	var click_btn = Button.new()
	click_btn.flat = true
	click_btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	click_btn.anchor_right = 1.0
	click_btn.anchor_bottom = 1.0
	click_btn.offset_right = 0
	click_btn.offset_bottom = 0
	click_btn.focus_mode = Control.FOCUS_NONE
	click_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	click_btn.pressed.connect(func():
		_select_player_index(idx)
	)
	card.add_child(click_btn)

	return card

func _select_player_index(idx: int):
	AudioManager.play_sfx("click")
	current_index = idx
	_update_card_highlights()

	if idx < card_nodes.size():
		var chosen_card = card_nodes[idx]
		var tw = chosen_card.create_tween()
		tw.tween_property(chosen_card, "scale", Vector2(1.08, 1.08), 0.1).set_trans(Tween.TRANS_BACK)
		tw.tween_property(chosen_card, "scale", Vector2(1.04, 1.04), 0.1).set_trans(Tween.TRANS_SINE)

func _update_card_highlights():
	for i in range(card_nodes.size()):
		var card = card_nodes[i]
		var is_selected = (i == current_index)

		var style = StyleBoxFlat.new()
		style.bg_color = Color.WHITE
		style.set_corner_radius_all(28)

		if is_selected:
			style.border_width_left = 4
			style.border_width_right = 4
			style.border_width_top = 4
			style.border_width_bottom = 4
			style.border_color = Color(0.25, 0.65, 0.98) # Glowing cyan-blue active border
			style.shadow_color = Color(0.20, 0.50, 0.90, 0.35)
			style.shadow_size = 14
			style.shadow_offset = Vector2(0, 6)
			card.scale = Vector2(1.04, 1.04)
			card.modulate = Color.WHITE
		else:
			style.border_width_left = 2
			style.border_width_right = 2
			style.border_width_top = 2
			style.border_width_bottom = 2
			style.border_color = Color(0.85, 0.92, 0.98)
			style.shadow_color = Color(0.2, 0.4, 0.7, 0.12)
			style.shadow_size = 6
			style.shadow_offset = Vector2(0, 3)
			card.scale = Vector2.ONE
			card.modulate = Color(0.95, 0.96, 0.98, 0.88)

		card.add_theme_stylebox_override("panel", style)

func _on_choose_pressed():
	AudioManager.play_sfx("cheer")
	if not profiles_list.is_empty():
		var p = profiles_list[current_index]
		GameState.set_active_profile(p.get("id", ""))
		player_chosen.emit(p.get("id", ""))
	else:
		player_chosen.emit("")