# scripts/settings_screen.gd
extends Control

signal switch_profile_requested
signal reset_completed
signal back_pressed

var tts_enabled: bool = false

var title_rect: TextureRect
var title_lbl: Label
var central_card: Panel
var parental_card: Panel
var legal_card: Panel
var audio_card: Panel

var insights_grid: GridContainer
var insights_summary_lbl: Label

var pin_input_new: LineEdit
var pin_input_conf: LineEdit
var pin_err_lbl: Label

func _ready():
	anchors_preset = Control.PRESET_FULL_RECT
	anchor_right = 1.0
	anchor_bottom = 1.0
	_build_ui()
	_relayout()

func _notification(what):
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_relayout()

func _build_ui():
	# Background
	var bg = TextureRect.new()
	bg.name = "Background"
	UIHelper.setup_fullscreen_bg(bg)
	bg.texture = UIHelper.create_sky_gradient_texture()
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(bg)
	
	# Title Header (Title Image + Sub-screen Title Label)
	title_rect = TextureRect.new()
	title_rect.name = "SettingsTitle"
	var t_tex = UIHelper.load_texture_safe("res://assets/images/titles/settings_title.png")
	if not t_tex:
		t_tex = UIHelper.load_texture_safe("res://assets/images/settings/settings_title.png")
	if not t_tex:
		t_tex = UIHelper.load_texture_safe("res://assets/images/titles/settings_title.png")
	title_rect.texture = t_tex
	title_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	title_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(title_rect)
	
	title_lbl = Label.new()
	title_lbl.name = "TitleLabel"
	title_lbl.text = "SETTINGS"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(title_lbl, 30, Color.WHITE, true)
	title_lbl.add_theme_color_override("font_shadow_color", Color(0.10, 0.35, 0.65, 0.90))
	title_lbl.add_theme_constant_override("shadow_offset_x", 0)
	title_lbl.add_theme_constant_override("shadow_offset_y", 3)
	title_lbl.add_theme_color_override("font_outline_color", Color(0.12, 0.40, 0.72))
	title_lbl.add_theme_constant_override("outline_size", 6)
	title_lbl.visible = false
	title_lbl.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(title_lbl)
	
	# Secret 5-Tap Developer Gesture Setup
	var secret_taps = [0]
	var last_tap_time = [0.0]
	var handle_secret_tap = func():
		var now = Time.get_ticks_msec() / 1000.0
		if now - last_tap_time[0] > 2.0:
			secret_taps[0] = 0
		last_tap_time[0] = now
		secret_taps[0] += 1
		if secret_taps[0] >= 5:
			secret_taps[0] = 0
			GameState.dev_mode = not GameState.dev_mode
			AudioManager.play_sfx("chime")
			if GameState.dev_mode:
				GameState.push_toast("Developer Mode ON", "Free progress & 20s timers enabled!", "", "green")
			else:
				GameState.push_toast("Developer Mode OFF", "Strict 2-min timer & 5 AM/PM locks active.", "", "blue")

	title_rect.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			handle_secret_tap.call()
	)
	title_lbl.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			handle_secret_tap.call()
	)
	
	# 1. Main Settings Card
	_build_central_card()
	
	# 2. Audio Settings Card
	_build_audio_card()
	
	# 3. Tooth Fairy Parental Portal Card
	_build_parental_card()
	
	# 4. Legal & Dev Support Card
	_build_legal_card()

func _build_central_card():
	central_card = Panel.new()
	central_card.name = "CentralCard"
	var card_style = UIHelper.create_bubbly_panel(32, Color(1, 1, 1, 0.96), Color(0.85, 0.93, 1.0), 3)
	central_card.add_theme_stylebox_override("panel", card_style)
	add_child(central_card)
	
	var scroll = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = false
	central_card.add_child(scroll)
	
	# Top Right Close Button (placed on top of scroll)
	var close_btn = UIHelper.create_close_button(Vector2(32, 32))
	close_btn.name = "CloseButton"
	close_btn.z_index = 10
	close_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	close_btn.pressed.connect(_on_close)
	central_card.add_child(close_btn)
	
	var vbox = VBoxContainer.new()
	vbox.name = "ContentVBox"
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	scroll.add_child(vbox)
	
	# Section 1: Audio Settings Button
	var audio_btn = UIHelper.create_image_button("res://assets/images/buttons/audiosettings_btn.png", Vector2(300, 58))
	if not audio_btn.texture_normal:
		audio_btn = UIHelper.create_themed_button("audiosettings", Vector2(300, 58))
	if not audio_btn.texture_normal:
		audio_btn = UIHelper.create_bubbly_button("AUDIO SETTINGS", Color(0.24, 0.60, 0.95))
		audio_btn.custom_minimum_size = Vector2(300, 54)
	audio_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	audio_btn.pressed.connect(func():
		AudioManager.play_sfx("click")
		_switch_to_audio()
	)
	vbox.add_child(audio_btn)
	
	vbox.add_child(_create_h_separator())
	
	# Section 2: Parental Control (was Tooth Fairy Drop)
	var portal_box = VBoxContainer.new()
	portal_box.alignment = BoxContainer.ALIGNMENT_CENTER
	portal_box.add_theme_constant_override("separation", 4)
	portal_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var fairy_btn = UIHelper.create_image_button("res://assets/images/buttons/parentalcontrol_btn.png", Vector2(300, 58))
	if not fairy_btn.texture_normal:
		fairy_btn = UIHelper.create_themed_button("parentalcontrol", Vector2(300, 58))
	if not fairy_btn.texture_normal:
		fairy_btn = UIHelper.create_bubbly_button("PARENTAL CONTROL", Color(0.24, 0.60, 0.95))
		fairy_btn.custom_minimum_size = Vector2(300, 54)
	fairy_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	
	fairy_btn.pressed.connect(func():
		AudioManager.play_sfx("click")
		UIHelper.show_parental_gate(self, func():
			_switch_to_parental_portal()
		, Callable(), "PARENTAL ACCESS")
	)
	portal_box.add_child(fairy_btn)
	
	var fairy_sub = Label.new()
	fairy_sub.text = "Parental Control: Difficulty, Habit Insights & PIN Security"
	fairy_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fairy_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UIHelper.apply_bubbly_label(fairy_sub, 10, Color(0.35, 0.50, 0.70), false)
	portal_box.add_child(fairy_sub)
	vbox.add_child(portal_box)
	
	vbox.add_child(_create_h_separator())
	
	# Section 3: Player Management: SWITCH USER & ADD USER
	var user_btns_hbox = HBoxContainer.new()
	user_btns_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	user_btns_hbox.add_theme_constant_override("separation", 12)
	user_btns_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(user_btns_hbox)
	
	var switch_user_btn = UIHelper.create_themed_button("switchuser", Vector2(145, 52))
	if not switch_user_btn.texture_normal:
		switch_user_btn = UIHelper.create_bubbly_button("SWITCH USER", Color(0.18, 0.44, 0.82))
		switch_user_btn.custom_minimum_size = Vector2(145, 50)
	switch_user_btn.pressed.connect(func():
		var main_node = get_tree().root.get_node_or_null("Main")
		if main_node and main_node.has_method("navigate_to"):
			main_node.navigate_to("select_player")
	)
	user_btns_hbox.add_child(switch_user_btn)
	
	var add_user_btn = UIHelper.create_themed_button("adduser", Vector2(145, 52))
	if not add_user_btn.texture_normal:
		add_user_btn = UIHelper.create_bubbly_button("+ ADD USER", Color(0.20, 0.55, 0.95))
		add_user_btn.custom_minimum_size = Vector2(145, 50)
	add_user_btn.pressed.connect(func():
		var main_node = get_tree().root.get_node_or_null("Main")
		if main_node and main_node.has_method("navigate_to"):
			main_node.navigate_to("create_profile")
	)
	user_btns_hbox.add_child(add_user_btn)
	
	vbox.add_child(_create_h_separator())
	
	# Section 4: Replay Tutorial
	var replay_btn = UIHelper.create_image_button("res://assets/images/buttons/replaytutorial_btn.png", Vector2(300, 52))
	if not replay_btn.texture_normal:
		replay_btn = UIHelper.create_themed_button("replaytutorial", Vector2(300, 52))
	if not replay_btn.texture_normal:
		replay_btn = UIHelper.create_bubbly_button("REPLAY TUTORIAL", Color(0.65, 0.42, 0.92))
		replay_btn.custom_minimum_size = Vector2(300, 50)
	replay_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	replay_btn.pressed.connect(func():
		AudioManager.play_sfx("click")
		var p = GameState.get_active_profile()
		if not p.is_empty():
			p["tutorial_done"] = false
			GameState.save_game()
		GameState.push_toast("Tutorial Reset", "Map tutorial ready to replay!", "", "blue")
		var main_node = get_tree().root.get_node_or_null("Main")
		if main_node and main_node.has_method("navigate_to"):
			main_node.navigate_to("map")
	)
	vbox.add_child(replay_btn)
	
	vbox.add_child(_create_h_separator())
	
	# Section 5: Terms & Privacy
	var terms_btn = UIHelper.create_image_button("res://assets/images/buttons/termsandpriv_btn.png", Vector2(300, 52))
	if not terms_btn.texture_normal:
		terms_btn = UIHelper.create_themed_button("termsandpriv", Vector2(300, 52))
	if not terms_btn.texture_normal:
		terms_btn = UIHelper.create_bubbly_button("TERMS & PRIVACY", Color(0.25, 0.52, 0.88))
		terms_btn.custom_minimum_size = Vector2(300, 50)
	terms_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	terms_btn.pressed.connect(func():
		AudioManager.play_sfx("click")
		_switch_to_legal()
	)
	vbox.add_child(terms_btn)
	
	vbox.add_child(_create_h_separator())
	
	# Section 6: Support Developers
	var support_btn = UIHelper.create_image_button("res://assets/images/buttons/supportdev_btn.png", Vector2(300, 52))
	if not support_btn.texture_normal:
		support_btn = UIHelper.create_themed_button("supportdev", Vector2(300, 52))
	if not support_btn.texture_normal:
		support_btn = UIHelper.create_bubbly_button("SUPPORT DEVELOPERS", Color(0.92, 0.58, 0.15))
		support_btn.custom_minimum_size = Vector2(300, 50)
	support_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	support_btn.pressed.connect(func():
		AudioManager.play_sfx("click")
		var root = get_tree().root
		var tip_mgr = root.get_node_or_null("TipManager")
		if tip_mgr and tip_mgr.has_method("support_developers"):
			tip_mgr.support_developers()
		else:
			GameState.push_toast("Coming Soon", "Support Developers feature coming soon!", "", "blue")
	)
	vbox.add_child(support_btn)
	
	# Section 7: Sir Crown Avatar Selection (only visible when unlocked)
	var crown_sep = _create_h_separator()
	crown_sep.name = "CrownSep"
	vbox.add_child(crown_sep)
	
	var crown_section = VBoxContainer.new()
	crown_section.name = "CrownSection"
	crown_section.alignment = BoxContainer.ALIGNMENT_CENTER
	crown_section.add_theme_constant_override("separation", 8)
	crown_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var crown_title = Label.new()
	crown_title.text = "SPECIAL CHARACTER"
	crown_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(crown_title, 13, Color(0.86, 0.55, 0.05), true)
	crown_section.add_child(crown_title)
	
	var crown_row = HBoxContainer.new()
	crown_row.alignment = BoxContainer.ALIGNMENT_CENTER
	crown_row.add_theme_constant_override("separation", 12)
	
	var crown_avatar = TextureRect.new()
	crown_avatar.texture = UIHelper.load_texture_safe("res://assets/images/characters/SirCrown-nobg.png")
	crown_avatar.custom_minimum_size = Vector2(64, 64)
	crown_avatar.size = Vector2(64, 64)
	crown_avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crown_avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	crown_row.add_child(crown_avatar)
	
	var crown_info = VBoxContainer.new()
	crown_info.add_theme_constant_override("separation", 2)
	
	var crown_name = Label.new()
	crown_name.text = "Sir Crown"
	UIHelper.apply_bubbly_label(crown_name, 16, Color(0.12, 0.35, 0.65), true)
	crown_info.add_child(crown_name)
	
	var crown_role = Label.new()
	crown_role.text = "Royal Mascot"
	UIHelper.apply_bubbly_label(crown_role, 11, Color(0.50, 0.55, 0.65))
	crown_info.add_child(crown_role)
	crown_row.add_child(crown_info)
	
	crown_section.add_child(crown_row)
	
	var crown_toggle_btn = UIHelper.create_image_button("res://assets/images/buttons/selectbtn.png", Vector2(170, 48))
	if not crown_toggle_btn.texture_normal:
		crown_toggle_btn = UIHelper.create_bubbly_button("SELECT", Color(0.92, 0.58, 0.15))
		crown_toggle_btn.custom_minimum_size = Vector2(170, 44)
	crown_toggle_btn.name = "CrownToggleBtn"
	crown_toggle_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	crown_toggle_btn.pressed.connect(func():
		AudioManager.play_sfx("click")
		var prof = GameState.get_active_profile()
		if prof.is_empty():
			return
		if prof.get("avatar", "chip") == "sircrown":
			return # already selected
		prof["avatar"] = "sircrown"
		GameState.push_toast("Avatar Changed", "Sir Crown is now your character!", "", "gold")
		GameState.save_game()
		GameState.emit_signal("stats_updated")
		_refresh_crown_section()
	)
	crown_section.add_child(crown_toggle_btn)
	
	vbox.add_child(crown_section)
	
	# Initially hide if not unlocked
	_refresh_crown_section()

func _build_audio_card():
	audio_card = Panel.new()
	audio_card.name = "AudioCard"
	audio_card.visible = false
	var card_style = UIHelper.create_bubbly_panel(32, Color(1, 1, 1, 0.96), Color(0.40, 0.75, 0.98), 3)
	audio_card.add_theme_stylebox_override("panel", card_style)
	add_child(audio_card)
	
	var scroll = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = false
	audio_card.add_child(scroll)
	
	# Top Right Close / Back Button
	var close_btn = UIHelper.create_close_button(Vector2(32, 32))
	close_btn.name = "CloseButton"
	close_btn.z_index = 10
	close_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	close_btn.pressed.connect(_switch_to_settings)
	audio_card.add_child(close_btn)
	
	var vbox = VBoxContainer.new()
	vbox.name = "AudioVBox"
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	scroll.add_child(vbox)
	
	# Header Badge
	var header_badge = Panel.new()
	header_badge.custom_minimum_size = Vector2(240, 30)
	var hb_st = StyleBoxFlat.new()
	hb_st.bg_color = Color(0.88, 0.95, 1.0)
	hb_st.border_color = Color(0.65, 0.85, 0.98)
	hb_st.set_border_width_all(1)
	hb_st.set_corner_radius_all(12)
	header_badge.add_theme_stylebox_override("panel", hb_st)
	
	var hb_lbl = Label.new()
	hb_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	hb_lbl.text = "AUDIO & SOUND SETTINGS"
	hb_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hb_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(hb_lbl, 11, Color(0.15, 0.45, 0.78), true)
	header_badge.add_child(hb_lbl)
	vbox.add_child(header_badge)
	
	# 1. Sounds Slider Row
	var s_snd = _create_audio_slider_row(
		"Sounds",
		AudioManager.saved_sfx_volume if AudioManager.saved_sfx_volume > 0.05 else AudioManager.sfx_volume,
		AudioManager.is_sound_enabled(),
		func(val): AudioManager.set_sfx_volume(val),
		func(val): AudioManager.set_sound_enabled(val)
	)
	vbox.add_child(s_snd)
	
	# 2. Music Slider Row
	var s_mus = _create_audio_slider_row(
		"Music",
		AudioManager.saved_bgm_volume if AudioManager.saved_bgm_volume > 0.05 else AudioManager.bgm_volume,
		AudioManager.is_music_enabled(),
		func(val): AudioManager.set_bgm_volume(val),
		func(val): AudioManager.set_music_enabled(val)
	)
	vbox.add_child(s_mus)
	
	# Separator line
	vbox.add_child(_create_h_separator())

	# 3. Master Mute/Unmute Toggle Row
	var mute_toggle = _create_toggle_row("Master Mute", func(val):
		AudioManager.set_muted(val)
	, AudioManager.is_muted)
	vbox.add_child(mute_toggle)

	# Separator line
	vbox.add_child(_create_h_separator())

	# 4. Text-to-Speech Toggle Row
	var r1 = _create_toggle_row("Text-to-Speech", func(val):
		tts_enabled = val
		AudioManager.tts_enabled = val
	, AudioManager.tts_enabled)
	vbox.add_child(r1)

	# Separator line
	vbox.add_child(_create_h_separator())

	# 5. Reminder Notifications (brushing reminders, streak & Candy Crusade alerts)
	var notif_row = _create_toggle_row("Reminder Notifications", func(val):
		LocalNotifications.set_enabled(val)
	, LocalNotifications.enabled)
	vbox.add_child(notif_row)

	# Separator line
	vbox.add_child(_create_h_separator())

	# Bottom Back Button
	var back_to_set_btn = UIHelper.create_image_button("res://assets/images/buttons/backtosettings_btn.png", Vector2(280, 48))
	if not back_to_set_btn.texture_normal:
		back_to_set_btn = UIHelper.create_themed_button("backtosettings", Vector2(280, 48))
	if not back_to_set_btn.texture_normal:
		back_to_set_btn = UIHelper.create_bubbly_button("BACK TO SETTINGS", Color(0.24, 0.58, 0.92))
		back_to_set_btn.custom_minimum_size = Vector2(280, 44)
	back_to_set_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back_to_set_btn.pressed.connect(_switch_to_settings)
	vbox.add_child(back_to_set_btn)

func _build_parental_card():
	parental_card = Panel.new()
	parental_card.name = "ParentalCard"
	parental_card.visible = false
	var card_style = UIHelper.create_bubbly_panel(32, Color(1, 1, 1, 0.98), Color(0.40, 0.75, 0.98), 3)
	parental_card.add_theme_stylebox_override("panel", card_style)
	add_child(parental_card)
	
	var scroll = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.follow_focus = false
	parental_card.add_child(scroll)
	
	# Top Right Close / Back Button
	var close_btn = UIHelper.create_close_button(Vector2(32, 32))
	close_btn.name = "CloseButton"
	close_btn.z_index = 10
	close_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	close_btn.pressed.connect(_switch_to_settings)
	parental_card.add_child(close_btn)
	
	var vbox = VBoxContainer.new()
	vbox.name = "ParentalVBox"
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	scroll.add_child(vbox)
	
	# Header Note Badge
	var header_badge = Panel.new()
	header_badge.custom_minimum_size = Vector2(240, 32)
	header_badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var hb_st = StyleBoxFlat.new()
	hb_st.bg_color = Color(0.88, 0.95, 1.0)
	hb_st.border_color = Color(0.65, 0.85, 0.98)
	hb_st.set_border_width_all(1)
	hb_st.set_corner_radius_all(14)
	header_badge.add_theme_stylebox_override("panel", hb_st)
	
	var hb_lbl = Label.new()
	hb_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	hb_lbl.text = "TOOTH FAIRY PARENTAL PORTAL"
	hb_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hb_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(hb_lbl, 11, Color(0.15, 0.45, 0.78), true)
	header_badge.add_child(hb_lbl)
	vbox.add_child(header_badge)
	
	# 1. Mini-Game Difficulty Selection (Centered)
	var r_diff = _create_difficulty_row()
	vbox.add_child(r_diff)
	
	# Separator line
	vbox.add_child(_create_h_separator())
	
	# 2. Parent Insights & Analytics (Centered)
	var insights_box = VBoxContainer.new()
	insights_box.alignment = BoxContainer.ALIGNMENT_CENTER
	insights_box.add_theme_constant_override("separation", 8)
	
	var ins_title = Label.new()
	ins_title.text = "Habit Insights & Analytics"
	ins_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(ins_title, 14, Color(0.18, 0.40, 0.70), true)
	insights_box.add_child(ins_title)
	
	var ins_sub = Label.new()
	ins_sub.text = "Oral Health Quiz Knowledge & Brushing Habit Retention"
	ins_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(ins_sub, 10, Color(0.40, 0.55, 0.72), false)
	insights_box.add_child(ins_sub)
	
	var grid_holder = CenterContainer.new()
	grid_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	insights_grid = GridContainer.new()
	insights_grid.columns = 2
	insights_grid.add_theme_constant_override("h_separation", 10)
	insights_grid.add_theme_constant_override("v_separation", 10)
	grid_holder.add_child(insights_grid)
	insights_box.add_child(grid_holder)
	
	var summary_card = PanelContainer.new()
	summary_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sc_st = UIHelper.create_bubbly_panel(14, Color(0.92, 0.96, 1.0), Color(0.80, 0.90, 0.98), 1)
	summary_card.add_theme_stylebox_override("panel", sc_st)
	
	var sc_vbox = VBoxContainer.new()
	sc_vbox.offset_left = 12
	sc_vbox.offset_right = -12
	sc_vbox.offset_top = 8
	sc_vbox.offset_bottom = -8
	sc_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	sc_vbox.add_theme_constant_override("separation", 4)
	
	var sc_title = Label.new()
	sc_title.text = "Routine Summary"
	sc_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(sc_title, 11, Color(0.18, 0.40, 0.70), true)
	sc_vbox.add_child(sc_title)
	
	insights_summary_lbl = Label.new()
	insights_summary_lbl.text = "Player is maintaining steady daily brushing sessions."
	insights_summary_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	insights_summary_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UIHelper.apply_bubbly_label(insights_summary_lbl, 10, Color(0.25, 0.35, 0.45), false)
	sc_vbox.add_child(insights_summary_lbl)
	
	summary_card.add_child(sc_vbox)
	insights_box.add_child(summary_card)
	vbox.add_child(insights_box)
	
	# Separator line
	vbox.add_child(_create_h_separator())
	
	# 3. Tooth Fairy PIN Management (Centered)
	var pin_box = VBoxContainer.new()
	pin_box.alignment = BoxContainer.ALIGNMENT_CENTER
	pin_box.add_theme_constant_override("separation", 8)
	
	var pin_title = Label.new()
	pin_title.text = "Tooth Fairy PIN Security"
	pin_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(pin_title, 14, Color(0.18, 0.40, 0.70), true)
	pin_box.add_child(pin_title)
	
	var pin_sub = Label.new()
	pin_sub.text = "Set a 4-digit PIN to protect parental settings & difficulty."
	pin_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pin_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UIHelper.apply_bubbly_label(pin_sub, 10, Color(0.35, 0.48, 0.65), false)
	pin_box.add_child(pin_sub)
	
	pin_err_lbl = Label.new()
	pin_err_lbl.text = ""
	pin_err_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(pin_err_lbl, 10, Color(0.92, 0.25, 0.20), true)
	pin_err_lbl.visible = false
	pin_box.add_child(pin_err_lbl)
	
	var pin_inputs_row = HBoxContainer.new()
	pin_inputs_row.alignment = BoxContainer.ALIGNMENT_CENTER
	pin_inputs_row.add_theme_constant_override("separation", 10)
	
	var pin_st = StyleBoxFlat.new()
	pin_st.bg_color = Color.WHITE
	pin_st.border_color = Color(0.45, 0.65, 0.88)
	pin_st.set_border_width_all(2)
	pin_st.set_corner_radius_all(14)
	pin_st.content_margin_top = 8
	pin_st.content_margin_bottom = 8
	pin_st.content_margin_left = 10
	pin_st.content_margin_right = 10
	
	pin_input_new = LineEdit.new()
	pin_input_new.placeholder_text = "New 4-digit PIN..."
	pin_input_new.secret = true
	pin_input_new.max_length = 4
	pin_input_new.alignment = HORIZONTAL_ALIGNMENT_CENTER
	pin_input_new.custom_minimum_size = Vector2(145, 40)
	pin_input_new.add_theme_stylebox_override("normal", pin_st)
	pin_input_new.add_theme_stylebox_override("focus", pin_st)
	pin_input_new.add_theme_color_override("font_color", Color(0.10, 0.15, 0.30))
	pin_input_new.add_theme_color_override("placeholder_color", Color(0.15, 0.25, 0.45, 0.90))
	pin_input_new.add_theme_color_override("font_placeholder_color", Color(0.15, 0.25, 0.45, 0.90))
	pin_input_new.add_theme_font_size_override("font_size", 13)
	pin_inputs_row.add_child(pin_input_new)
	
	pin_input_conf = LineEdit.new()
	pin_input_conf.placeholder_text = "Confirm PIN..."
	pin_input_conf.secret = true
	pin_input_conf.max_length = 4
	pin_input_conf.alignment = HORIZONTAL_ALIGNMENT_CENTER
	pin_input_conf.custom_minimum_size = Vector2(145, 40)
	pin_input_conf.add_theme_stylebox_override("normal", pin_st)
	pin_input_conf.add_theme_stylebox_override("focus", pin_st)
	pin_input_conf.add_theme_color_override("font_color", Color(0.10, 0.15, 0.30))
	pin_input_conf.add_theme_color_override("placeholder_color", Color(0.15, 0.25, 0.45, 0.90))
	pin_input_conf.add_theme_color_override("font_placeholder_color", Color(0.15, 0.25, 0.45, 0.90))
	pin_input_conf.add_theme_font_size_override("font_size", 13)
	pin_inputs_row.add_child(pin_input_conf)
	pin_box.add_child(pin_inputs_row)

	# Setup keyboard handling for PIN inputs
	UIHelper.setup_line_edit_keyboard_handling(pin_input_new, self)
	UIHelper.setup_line_edit_keyboard_handling(pin_input_conf, self)
	
	var save_pin_btn = UIHelper.create_image_button("res://assets/images/buttons/savebtn.png", Vector2(160, 46))
	if not save_pin_btn.texture_normal:
		save_pin_btn = UIHelper.create_themed_button("save", Vector2(160, 46))
	if not save_pin_btn.texture_normal:
		save_pin_btn = UIHelper.create_bubbly_button("SAVE PIN", Color(0.16, 0.78, 0.42))
		save_pin_btn.custom_minimum_size = Vector2(160, 44)
	save_pin_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	save_pin_btn.pressed.connect(func():
		var p1 = pin_input_new.text.strip_edges()
		var p2 = pin_input_conf.text.strip_edges()
		if p1.length() != 4 or not p1.is_valid_int():
			pin_err_lbl.text = "PIN must be exactly 4 digits."
			pin_err_lbl.visible = true
			AudioManager.play_sfx("click")
			return
		if p1 != p2:
			pin_err_lbl.text = "PINs do not match. Try again."
			pin_err_lbl.visible = true
			AudioManager.play_sfx("click")
			return
		GameState.set_tooth_fairy_pin(p1)
		AudioManager.play_sfx("pop")
		pin_err_lbl.visible = false
		pin_input_new.text = ""
		pin_input_conf.text = ""
		GameState.push_toast("PIN Updated", "Tooth Fairy PIN saved successfully!", "", "green")
	)
	pin_box.add_child(save_pin_btn)
	vbox.add_child(pin_box)
	
	# Separator line
	vbox.add_child(_create_h_separator())
	
	# 4. Advanced Data Management & Reset (Centered)
	
	var reset_btn = UIHelper.create_image_button("res://assets/images/buttons/datawipe-resetbtn.png", Vector2(270, 48))
	if not reset_btn.texture_normal:
		reset_btn = UIHelper.create_themed_button("datawipe", Vector2(270, 48))
	if not reset_btn.texture_normal:
		reset_btn = UIHelper.create_bubbly_button("WIPE & RESET GAME DATA", Color(0.92, 0.35, 0.25))
		reset_btn.custom_minimum_size = Vector2(270, 42)
	reset_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	reset_btn.pressed.connect(func():
		AudioManager.play_sfx("click")
		_show_reset_confirmation_modal()
	)
	vbox.add_child(reset_btn)
	
	# Bottom Back Button
	var back_to_set_btn = UIHelper.create_image_button("res://assets/images/buttons/backtosettings_btn.png", Vector2(280, 48))
	if not back_to_set_btn.texture_normal:
		back_to_set_btn = UIHelper.create_themed_button("backtosettings", Vector2(280, 48))
	if not back_to_set_btn.texture_normal:
		back_to_set_btn = UIHelper.create_bubbly_button("BACK TO SETTINGS", Color(0.24, 0.58, 0.92))
		back_to_set_btn.custom_minimum_size = Vector2(280, 44)
	back_to_set_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back_to_set_btn.pressed.connect(_switch_to_settings)
	vbox.add_child(back_to_set_btn)

func _refresh_crown_section():
	var crown_sep = central_card.get_node_or_null("CentralCard/Scroll/ContentVBox/CrownSep")
	if not crown_sep:
		# Try finding by walking the vbox children
		var scroll = central_card.get_node_or_null("Scroll")
		if scroll:
			var content_vbox = scroll.get_node_or_null("ContentVBox")
			if content_vbox:
				crown_sep = content_vbox.get_node_or_null("CrownSep")
	var crown_section_node = null
	if crown_sep:
		crown_section_node = crown_sep.get_parent().get_node_or_null("CrownSection")
	
	var p = GameState.get_active_profile()
	var unlocked_chars = p.get("unlockedCharacters", [])
	var is_unlocked = "sircrown" in unlocked_chars or "crown" in unlocked_chars
	
	if crown_sep:
		crown_sep.visible = is_unlocked
	if crown_section_node:
		crown_section_node.visible = is_unlocked
		if is_unlocked:
			var toggle_btn = crown_section_node.get_node_or_null("CrownToggleBtn")
			if toggle_btn and toggle_btn is BaseButton:
				# SELECT is greyed out while Sir Crown is already the active character
				var is_selected = (p.get("avatar", "chip") == "sircrown")
				toggle_btn.disabled = is_selected
				toggle_btn.modulate = Color(1, 1, 1, 0.45) if is_selected else Color.WHITE
				toggle_btn.tooltip_text = "Selected" if is_selected else "Select Sir Crown"

func _switch_to_audio():
	AudioManager.play_sfx("click")
	central_card.visible = false
	if parental_card:
		parental_card.visible = false
	if legal_card:
		legal_card.visible = false
	if audio_card:
		audio_card.visible = true
	if title_rect:
		title_rect.visible = false
	if title_lbl:
		title_lbl.visible = true
		title_lbl.text = "AUDIO SETTINGS"
	
	if audio_card:
		audio_card.scale = Vector2(0.92, 0.92)
		audio_card.modulate.a = 0.0
		var tw = audio_card.create_tween().set_parallel(true)
		tw.tween_property(audio_card, "scale", Vector2.ONE, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(audio_card, "modulate:a", 1.0, 0.15)

func _switch_to_parental_portal():
	central_card.visible = false
	if audio_card:
		audio_card.visible = false
	if legal_card:
		legal_card.visible = false
	parental_card.visible = true
	if title_rect:
		title_rect.visible = false
	if title_lbl:
		title_lbl.visible = false
	_refresh_parental_insights()
	
	# Pop-in bouncy scale animation
	parental_card.scale = Vector2(0.92, 0.92)
	parental_card.modulate.a = 0.0
	var tw = parental_card.create_tween().set_parallel(true)
	tw.tween_property(parental_card, "scale", Vector2.ONE, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(parental_card, "modulate:a", 1.0, 0.15)

func _switch_to_settings():
	AudioManager.play_sfx("click")
	if audio_card:
		audio_card.visible = false
	if parental_card:
		parental_card.visible = false
	if legal_card:
		legal_card.visible = false
	central_card.visible = true
	if title_rect:
		title_rect.visible = true
	if title_lbl:
		title_lbl.visible = false
	
	central_card.scale = Vector2(0.92, 0.92)
	central_card.modulate.a = 0.0
	var tw = central_card.create_tween().set_parallel(true)
	tw.tween_property(central_card, "scale", Vector2.ONE, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(central_card, "modulate:a", 1.0, 0.15)
	_refresh_crown_section()

func _switch_to_legal():
	AudioManager.play_sfx("click")
	central_card.visible = false
	if audio_card:
		audio_card.visible = false
	if parental_card:
		parental_card.visible = false
	if legal_card:
		legal_card.visible = true
	if title_rect:
		title_rect.visible = false
	if title_lbl:
		title_lbl.visible = true
		title_lbl.text = "TERMS & PRIVACY"
	
	if legal_card:
		legal_card.scale = Vector2(0.92, 0.92)
		legal_card.modulate.a = 0.0
		var tw = legal_card.create_tween().set_parallel(true)
		tw.tween_property(legal_card, "scale", Vector2.ONE, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(legal_card, "modulate:a", 1.0, 0.15)

func _refresh_parental_insights():
	if not insights_grid or not is_instance_valid(insights_grid):
		return
		
	for ch in insights_grid.get_children():
		ch.queue_free()
		
	var p = GameState.get_active_profile()
	var streak = int(p.get("streak", 0))
	var total_mins = GameState.get_total_brushing_minutes(p)
	var player_name = p.get("name", "Player")
	
	# 1. True/False quiz knowledge for THIS player (weekly + final quizzes;
	#    the Day 0 Discovery Quiz is a starting-point check, so it isn't graded here)
	var tf_corr = 0
	var tf_tot = 0
	var qa = p.get("quizAnswers", {})
	if typeof(qa) == TYPE_DICTIONARY and not qa.is_empty():
		for k in qa:
			if str(k).begins_with("0_"):
				continue
			tf_tot += 1
			if qa[k] == true:
				tf_corr += 1
	elif GameState.profiles.size() <= 1:
		# Older saves: fall back to the device-wide quiz log (only safe with a single player)
		var local_data = FirebaseManager.get_challenge_data()
		var quiz_records = local_data.get("quiz_records", {})
		for day_key in quiz_records:
			if str(day_key) == "day_00":
				continue
			var day_dict = quiz_records[day_key]
			if typeof(day_dict) == TYPE_DICTIONARY:
				for q_id in day_dict:
					var entry = day_dict[q_id]
					if typeof(entry) == TYPE_DICTIONARY and str(entry.get("question_type", "")) == "true_false":
						tf_tot += 1
						if entry.get("is_correct", false) == true:
							tf_corr += 1
							
	var quiz_val_str = ""
	var quiz_pct_text = ""
	var quiz_sub_str = "True/False Recall"
	var quiz_color = Color(0.18, 0.72, 0.40)
	if tf_tot > 0:
		var pct = int(round((float(tf_corr) / float(tf_tot)) * 100.0))
		quiz_val_str = "%d%% Correct" % pct
		quiz_sub_str = "(%d/%d Questions)" % [tf_corr, tf_tot]
		quiz_pct_text = "%d%%" % pct
		if pct < 70:
			quiz_color = Color(0.95, 0.55, 0.15)
	else:
		var quizzes_done = int(p.get("quizzesCompleted", 0))
		if quizzes_done > 0:
			var perf = bool(p.get("quizPerfect", false))
			quiz_val_str = "100% Perfect" if perf else "Passed"
			quiz_sub_str = "%d Quizzes Done" % quizzes_done
		else:
			quiz_val_str = "Ready for Week 1"
			quiz_sub_str = "No quizzes yet"
			quiz_color = Color(0.35, 0.55, 0.85)

	# 2. Real Brushing Efficiency & Missed Days
	var days_status = p.get("daysStatus", [])
	var completed_days = 0
	var missed_days = 0
	for st in days_status:
		if st == "done":
			completed_days += 1
		elif st == "missed":
			missed_days += 1
			
	var current_node = int(p.get("currentNode", 0))
	var challenge_day = clampi(GameState.day_for_node(current_node), 1, 28)
	var total_attempted = completed_days + missed_days
	var consistency_pct = 100
	if total_attempted > 0:
		consistency_pct = int(round((float(completed_days) / float(total_attempted)) * 100.0))
	elif streak > 0:
		completed_days = streak

	var metric_data = [
		{
			"title": "Oral Health Quiz",
			"val": quiz_val_str,
			"sub": quiz_sub_str,
			"col": quiz_color
		},
		{
			"title": "Total Brushed",
			"val": "%d Mins" % total_mins,
			"sub": "2 min / session",
			"col": Color(0.20, 0.60, 0.95)
		},
		{
			"title": "Brushing Routine",
			"val": "%d%% On-Track" % consistency_pct,
			"sub": ("%d Missed Day" % missed_days) if missed_days == 1 else ("%d Missed Days" % missed_days),
			"col": Color(0.18, 0.72, 0.40) if missed_days == 0 else Color(0.92, 0.55, 0.18)
		},
		{
			"title": "Daily Streak",
			"val": "%d Days" % streak,
			"sub": "Unbroken Streak",
			"col": Color(0.96, 0.60, 0.15)
		}
	]
	
	for m in metric_data:
		var slot = PanelContainer.new()
		slot.custom_minimum_size = Vector2(148, 62)
		var st = UIHelper.create_bubbly_panel(14, Color(0.95, 0.98, 1.0), Color.WHITE, 1)
		slot.add_theme_stylebox_override("panel", st)
		
		var sv = VBoxContainer.new()
		sv.alignment = BoxContainer.ALIGNMENT_CENTER
		sv.add_theme_constant_override("separation", 2)
		
		var t_lbl = Label.new()
		t_lbl.text = m["title"]
		t_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UIHelper.apply_bubbly_label(t_lbl, 10, Color(0.35, 0.48, 0.65), true)
		sv.add_child(t_lbl)
		
		var v_lbl = Label.new()
		v_lbl.text = m["val"]
		v_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UIHelper.apply_bubbly_label(v_lbl, 13, m["col"], true)
		sv.add_child(v_lbl)
		
		var s_lbl = Label.new()
		s_lbl.text = m["sub"]
		s_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UIHelper.apply_bubbly_label(s_lbl, 9, Color(0.50, 0.60, 0.75), false)
		sv.add_child(s_lbl)
		
		slot.add_child(sv)
		insights_grid.add_child(slot)
		
	if insights_summary_lbl and is_instance_valid(insights_summary_lbl):
		var quiz_summary_text = ("Quiz accuracy is %s." % quiz_pct_text) if tf_tot > 0 else "Ready for weekly dental quizzes."
		insights_summary_lbl.text = "%s is on Day %d of the 28-Day Challenge with %d minutes brushed and a %d-day streak. %s" % [player_name, challenge_day, total_mins, streak, quiz_summary_text]

func _create_h_separator() -> Control:
	var sep = HSeparator.new()
	var sep_st = StyleBoxLine.new()
	sep_st.color = Color(0.85, 0.92, 0.98)
	sep_st.thickness = 2
	sep.add_theme_stylebox_override("separator", sep_st)
	sep.custom_minimum_size = Vector2(280, 10)
	return sep

func _relayout():
	var safe_sz = UIHelper.get_viewport_safe_size(self)
	var w = safe_sz.x
	var h = safe_sz.y
	var is_tablet = w >= 600
	
	var bg = get_node_or_null("Background")
	if bg:
		bg.size = safe_sz
	
	var title_w = min(w - 60.0, 270.0) if not is_tablet else 340.0
	var title_h = title_w * (300.0 / 1376.0)
	var title_y = 26.0 if not is_tablet else 36.0
	
	if title_rect:
		title_rect.position = Vector2((w - title_w) * 0.5, title_y)
		title_rect.size = Vector2(title_w, title_h)
		
	if title_lbl:
		title_lbl.position = Vector2(0, title_y + (title_h - 48.0) * 0.5)
		title_lbl.size = Vector2(w, 48)
		var f_size = 30 if not is_tablet else 40
		title_lbl.add_theme_font_size_override("font_size", f_size)
		
	var card_top = title_y + title_h + (14.0 if not is_tablet else 20.0)
	var card_w = min(w - 32.0, 416.0) if not is_tablet else min(w - 80.0, 520.0)
	var card_h = min(h - card_top - 20.0, 710.0)
	
	var scroll_pad_x = 20.0
	var scroll_pad_top = 48.0
	var scroll_pad_bottom = 20.0
	var inner_w = card_w - (scroll_pad_x * 2.0)
	var inner_h = card_h - scroll_pad_top - scroll_pad_bottom
	
	var cards_info = [
		{"panel": central_card, "vbox": "ContentVBox"},
		{"panel": audio_card, "vbox": "AudioVBox"},
		{"panel": parental_card, "vbox": "ParentalVBox"},
		{"panel": legal_card, "vbox": "LegalVBox"}
	]
	
	for c_data in cards_info:
		var c_panel = c_data["panel"] as Panel
		if not c_panel:
			continue
		c_panel.position = Vector2((w - card_w) * 0.5, card_top)
		c_panel.size = Vector2(card_w, card_h)
		c_panel.pivot_offset = Vector2(card_w * 0.5, card_h * 0.5)
		
		var close_btn = c_panel.get_node_or_null("CloseButton")
		if close_btn:
			close_btn.position = Vector2(card_w - 44.0, 10.0)
			close_btn.z_index = 10
			
		var scroll = c_panel.get_node_or_null("Scroll") as ScrollContainer
		if scroll:
			scroll.position = Vector2(scroll_pad_x, scroll_pad_top)
			scroll.size = Vector2(inner_w, inner_h)
			scroll.scroll_horizontal = 0
			var vb = scroll.get_node_or_null(c_data["vbox"])
			if vb:
				vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				vb.custom_minimum_size.x = inner_w
				vb.size.x = inner_w
				if c_data["vbox"] == "AudioVBox":
					vb.size_flags_vertical = Control.SIZE_EXPAND_FILL
					vb.custom_minimum_size.y = inner_h
					vb.add_theme_constant_override("separation", 24)

func _create_toggle_row(label_text: String, on_toggle: Callable, initial_state: bool = false) -> Control:
	var hbox = HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var lbl = Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIHelper.apply_bubbly_label(lbl, 13, Color(0.18, 0.40, 0.70), true)
	hbox.add_child(lbl)
	
	var on_tex = UIHelper.get_button_texture("on")
	var off_tex = UIHelper.get_button_texture("off")
	
	var btn = TextureButton.new()
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn.custom_minimum_size = Vector2(62, 32)
	btn.size = Vector2(62, 32)
	btn.pivot_offset = Vector2(31, 16)
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.texture_normal = on_tex if initial_state else off_tex
	
	btn.button_down.connect(func():
		var tw = btn.create_tween()
		tw.tween_property(btn, "scale", Vector2(0.92, 0.92), 0.08)
	)
	btn.button_up.connect(func():
		var tw = btn.create_tween()
		tw.tween_property(btn, "scale", Vector2.ONE, 0.08)
	)
	
	var is_on = [initial_state]
	btn.pressed.connect(func():
		AudioManager.play_sfx("click")
		is_on[0] = not is_on[0]
		btn.texture_normal = on_tex if is_on[0] else off_tex
		on_toggle.call(is_on[0])
	)
	hbox.add_child(btn)
	return hbox

func _create_audio_slider_row(label_text: String, initial_val: float, is_enabled: bool, on_val_change: Callable, on_toggle: Callable) -> Control:
	var root = VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 4)
	
	var top_row = HBoxContainer.new()
	top_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var lbl = Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIHelper.apply_bubbly_label(lbl, 13, Color(0.18, 0.40, 0.70), true)
	top_row.add_child(lbl)
	
	var on_tex = UIHelper.get_button_texture("on")
	var off_tex = UIHelper.get_button_texture("off")
	
	var toggle_btn = TextureButton.new()
	toggle_btn.ignore_texture_size = true
	toggle_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	toggle_btn.custom_minimum_size = Vector2(62, 32)
	toggle_btn.size = Vector2(62, 32)
	toggle_btn.pivot_offset = Vector2(31, 16)
	toggle_btn.focus_mode = Control.FOCUS_NONE
	toggle_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	toggle_btn.texture_normal = on_tex if is_enabled else off_tex
	
	toggle_btn.button_down.connect(func():
		var tw = toggle_btn.create_tween()
		tw.tween_property(toggle_btn, "scale", Vector2(0.92, 0.92), 0.08)
	)
	toggle_btn.button_up.connect(func():
		var tw = toggle_btn.create_tween()
		tw.tween_property(toggle_btn, "scale", Vector2.ONE, 0.08)
	)
	
	top_row.add_child(toggle_btn)
	root.add_child(top_row)
	
	var slider = _create_slider(initial_val if is_enabled else 0.0, Callable())
	slider.modulate.a = 1.0 if is_enabled else 0.45
	slider.editable = is_enabled
	root.add_child(slider)
	
	var state = {"is_on": is_enabled, "saved_val": initial_val if initial_val > 0.05 else 0.75}
	
	slider.value_changed.connect(func(v: float):
		if not state["is_on"] and v > 0.01:
			state["is_on"] = true
			toggle_btn.texture_normal = on_tex
			slider.modulate.a = 1.0
			on_toggle.call(true)
		elif state["is_on"] and v <= 0.01:
			state["is_on"] = false
			toggle_btn.texture_normal = off_tex
			on_toggle.call(false)
			
		if v > 0.01:
			state["saved_val"] = v
		on_val_change.call(v)
	)
	
	toggle_btn.pressed.connect(func():
		AudioManager.play_sfx("click")
		state["is_on"] = not state["is_on"]
		if state["is_on"]:
			toggle_btn.texture_normal = on_tex
			slider.editable = true
			slider.modulate.a = 1.0
			var restore_val = state["saved_val"] if state["saved_val"] > 0.05 else 0.75
			slider.value = restore_val
			on_toggle.call(true)
			on_val_change.call(restore_val)
		else:
			toggle_btn.texture_normal = off_tex
			slider.editable = false
			slider.modulate.a = 0.45
			on_toggle.call(false)
			on_val_change.call(0.0)
	)
	
	return root

func _create_slider(initial_val: float, on_change: Callable = Callable()) -> HSlider:
	var slider = HSlider.new()
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.02
	slider.value = initial_val
	slider.custom_minimum_size = Vector2(0, 26)
	
	var track_style = StyleBoxFlat.new()
	track_style.bg_color = Color(0.90, 0.95, 1.0)
	track_style.border_color = Color(0.80, 0.90, 0.98)
	track_style.border_width_left = 1
	track_style.border_width_top = 1
	track_style.border_width_right = 1
	track_style.border_width_bottom = 1
	track_style.corner_radius_top_left = 7
	track_style.corner_radius_top_right = 7
	track_style.corner_radius_bottom_left = 7
	track_style.corner_radius_bottom_right = 7
	track_style.content_margin_top = 5
	track_style.content_margin_bottom = 5
	slider.add_theme_stylebox_override("slider", track_style)
	
	var grabber_area = StyleBoxFlat.new()
	grabber_area.bg_color = Color(0.35, 0.72, 0.98)
	grabber_area.corner_radius_top_left = 7
	grabber_area.corner_radius_top_right = 7
	grabber_area.corner_radius_bottom_left = 7
	grabber_area.corner_radius_bottom_right = 7
	grabber_area.content_margin_top = 5
	grabber_area.content_margin_bottom = 5
	slider.add_theme_stylebox_override("grabber_area", grabber_area)
	slider.add_theme_stylebox_override("grabber_area_highlight", grabber_area)
	
	if on_change.is_valid():
		slider.value_changed.connect(on_change)
	return slider

func _create_difficulty_row() -> Control:
	var root = VBoxContainer.new()
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 6)
	
	var p = GameState.get_active_profile()
	var age = int(p.get("age", 8))
	var age_default = GameState.get_age_default_difficulty(age).capitalize()
	
	var title = Label.new()
	title.text = "Game & Brushing Difficulty"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(title, 13, Color(0.18, 0.40, 0.70), true)
	root.add_child(title)
	
	var sub_lbl = Label.new()
	sub_lbl.text = "Recommended for Age %d: %s" % [age, age_default]
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(sub_lbl, 11, Color(0.38, 0.52, 0.72), false)
	root.add_child(sub_lbl)
	
	var btn_row = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 10)
	root.add_child(btn_row)
	
	var buttons: Dictionary = {}
	var diff_configs = [
		{"id": "easy", "name": "Easy"},
		{"id": "medium", "name": "Medium"},
		{"id": "hard", "name": "Hard"}
	]
	
	var btn_w = 88.0
	var btn_h = 36.0
	
	var update_btn_styles = func():
		var active = GameState.get_difficulty()
		for cfg in diff_configs:
			var d_id = cfg["id"]
			var b = buttons.get(d_id) as Control
			if not b or not is_instance_valid(b):
				continue
			var is_selected = (d_id == active)
			if is_selected:
				b.modulate = Color.WHITE
				b.scale = Vector2(1.06, 1.06)
			else:
				b.modulate = Color(1.0, 1.0, 1.0, 0.55)
				b.scale = Vector2(0.95, 0.95)
	
	for cfg in diff_configs:
		var d_id = cfg["id"]
		var btn = UIHelper.create_themed_button(d_id, Vector2(btn_w, btn_h))
		if not btn.texture_normal:
			btn = UIHelper.create_bubbly_button(cfg["name"].to_upper(), Color(0.20, 0.60, 0.90))
			btn.custom_minimum_size = Vector2(btn_w, btn_h)
			btn.size = Vector2(btn_w, btn_h)
		else:
			btn.custom_minimum_size = Vector2(btn_w, btn_h)
			btn.size = Vector2(btn_w, btn_h)
		btn.pivot_offset = Vector2(btn_w * 0.5, btn_h * 0.5)
		
		btn.pressed.connect(func():
			AudioManager.play_sfx("click")
			GameState.set_difficulty(d_id)
			update_btn_styles.call()
			GameState.push_toast("Difficulty Changed", "Mini-games set to %s" % cfg["name"], "", "green")
		)
		btn_row.add_child(btn)
		buttons[d_id] = btn
		
	update_btn_styles.call()
	return root

func _show_reset_confirmation_modal():
	var dlg = UIHelper.create_modal_dialog(self, 300, Color(0, 0, 0, 0.6))
	var overlay = dlg["overlay"]
	var center = dlg["center"]
	
	var card = Panel.new()
	var card_style = UIHelper.create_bubbly_panel(28, Color.WHITE, Color(0.95, 0.35, 0.30), 3)
	card.add_theme_stylebox_override("panel", card_style)
	card.custom_minimum_size = Vector2(380, 300)
	card.size = Vector2(380, 300)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	center.add_child(card)
	
	var vbox = VBoxContainer.new()
	vbox.position = Vector2(24, 25)
	vbox.size = Vector2(332, 250)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	card.add_child(vbox)
	
	var title = Label.new()
	title.text = "RESET GAME DATA?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(title, 20, Color(0.85, 0.25, 0.20), true)
	vbox.add_child(title)
	
	var desc = Label.new()
	desc.text = "This will erase all player profiles, brushing progress, coins, and unlocks.\n\nThis cannot be undone!"
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UIHelper.apply_bubbly_label(desc, 13, Color(0.35, 0.40, 0.50), false)
	vbox.add_child(desc)
	
	var btn_row = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_row)
	
	var cancel_btn = UIHelper.create_themed_button("cancel", Vector2(130, 44))
	if not cancel_btn.texture_normal:
		cancel_btn = UIHelper.create_bubbly_button("CANCEL", Color(0.65, 0.72, 0.80))
		cancel_btn.custom_minimum_size = Vector2(130, 44)
	cancel_btn.pressed.connect(func():
		AudioManager.play_sfx("click")
		overlay.queue_free()
	)
	btn_row.add_child(cancel_btn)
	
	var confirm_btn = UIHelper.create_image_button("res://assets/images/buttons/datawipe-resetbtn.png", Vector2(150, 46))
	if not confirm_btn.texture_normal:
		confirm_btn = UIHelper.create_themed_button("datawipe", Vector2(150, 46))
	if not confirm_btn.texture_normal:
		confirm_btn = UIHelper.create_bubbly_button("YES, RESET", Color(0.92, 0.25, 0.22))
		confirm_btn.custom_minimum_size = Vector2(140, 44)
	confirm_btn.pressed.connect(func():
		AudioManager.play_sfx("pop")
		GameState.reset_all_data()
		overlay.queue_free()
		reset_completed.emit()
	)
	btn_row.add_child(confirm_btn)

func _build_legal_card():
	legal_card = Panel.new()
	legal_card.name = "LegalCard"
	legal_card.visible = false
	var card_style = UIHelper.create_bubbly_panel(32, Color(1, 1, 1, 0.96), Color(0.40, 0.75, 0.98), 3)
	legal_card.add_theme_stylebox_override("panel", card_style)
	add_child(legal_card)
	
	var scroll = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = false
	legal_card.add_child(scroll)
	
	# Top Right Close / Back Button
	var close_btn = UIHelper.create_close_button(Vector2(32, 32))
	close_btn.name = "CloseButton"
	close_btn.z_index = 10
	close_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	close_btn.pressed.connect(_switch_to_settings)
	legal_card.add_child(close_btn)
	
	var vbox = VBoxContainer.new()
	vbox.name = "LegalVBox"
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	scroll.add_child(vbox)
	
	# Header Badge
	var header_badge = Panel.new()
	header_badge.custom_minimum_size = Vector2(240, 30)
	var hb_st = StyleBoxFlat.new()
	hb_st.bg_color = Color(0.88, 0.95, 1.0)
	hb_st.border_color = Color(0.65, 0.85, 0.98)
	hb_st.set_border_width_all(1)
	hb_st.set_corner_radius_all(12)
	header_badge.add_theme_stylebox_override("panel", hb_st)
	
	var hb_lbl = Label.new()
	hb_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	hb_lbl.text = "TERMS & PRIVACY"
	hb_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hb_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(hb_lbl, 11, Color(0.15, 0.45, 0.78), true)
	header_badge.add_child(hb_lbl)
	vbox.add_child(header_badge)
	
	# 1. Privacy Policy Card (Comprehensive COPPA / Apple App Store & Google Play Compliant)
	var privacy_card = PanelContainer.new()
	var pc_st = UIHelper.create_bubbly_panel(16, Color(0.94, 0.98, 0.95), Color(0.70, 0.88, 0.75), 1)
	privacy_card.add_theme_stylebox_override("panel", pc_st)
	
	var pc_vbox = VBoxContainer.new()
	pc_vbox.offset_left = 12
	pc_vbox.offset_right = -12
	pc_vbox.offset_top = 10
	pc_vbox.offset_bottom = -10
	pc_vbox.add_theme_constant_override("separation", 8)
	
	var coppa_title = Label.new()
	coppa_title.text = "PRIVACY POLICY (COPPA & GDPR-K COMPLIANT)"
	UIHelper.apply_bubbly_label(coppa_title, 13, Color(0.12, 0.50, 0.30), true)
	pc_vbox.add_child(coppa_title)
	
	var coppa_body = Label.new()
	coppa_body.text = """Effective Date: September 2026

Pearly Whites Challenge ("we," "our," or "us") is dedicated to protecting the privacy of children and families. This Privacy Policy outlines our strict privacy compliance standards under the Children's Online Privacy Protection Act (COPPA), the General Data Protection Regulation for Kids (GDPR-K), Apple App Review Guidelines Section 5.1, and Google Play Families Policy.

1. ZERO PERSONAL DATA COLLECTION
We do NOT collect, harvest, request, store, or transmit any Personally Identifiable Information (PII) from child users or parents. No name, email address, physical address, geolocation data, IP address, device persistent identifier, or camera image/video is ever transmitted to external servers.

2. LOCAL DEVICE STORAGE ONLY
All application state—including player profile names, avatar choices, habit timers, daily streak logs, unlocked story chapters, and in-game virtual currencies—is saved exclusively on your local device storage ("user://"). Removing or uninstalling the app permanently erases this local state.

3. ON-DEVICE CAMERA VISION & SCANNING
Camera functionality used during brushing check routines processes live video frames strictly in real-time on your device hardware (using the device's built-in camera and on-device TensorFlow Lite, on both iPhone and Android). No photos, video feeds, or biometric data are recorded, stored, or transferred anywhere off the device.

4. THIRD-PARTY ANALYTICS, ADS & TRACKING
Pearly Whites Challenge contains ZERO third-party advertisements, ZERO data brokers, ZERO behavioral profiling SDKs, and ZERO cross-app tracking mechanisms.

5. PARENTAL GATEWAY & CONTROL
Any access to app configurations, parent settings, or external developer links is protected by an interactive Parental PIN Gate to ensure children cannot perform restricted actions independently.

6. ACCOUNT & DATA DELETION
You can permanently delete your user profile, brushing records, and all associated cloud/local data at any time directly within the application by navigating to Settings -> Tooth Fairy Parental Portal -> WIPE & RESET GAME DATA. Alternatively, you may contact our support team to request complete data erasure.

7. CONTACT & DATA INQUIRIES
For privacy questions, COPPA compliance inquiries, account deletion requests, or support assistance, please contact our team at game@pearlywhitessaga.com."""
	coppa_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UIHelper.apply_bubbly_label(coppa_body, 10, Color(0.25, 0.35, 0.45), false)
	pc_vbox.add_child(coppa_body)
	
	# Account & Data Erasure Button (Apple App Store Guideline 5.1.1(v) & Google Play Families Policy Compliant)
	var del_account_center = CenterContainer.new()
	var del_account_btn: BaseButton = UIHelper.create_image_button("res://assets/images/buttons/datawipe-resetbtn.png", Vector2(240, 86))
	if not (del_account_btn as TextureButton).texture_normal:
		var del_txt := UIHelper.create_bubbly_button("DELETE ACCOUNT & ERASE ALL DATA", Color(0.92, 0.25, 0.20))
		del_txt.custom_minimum_size = Vector2(280, 44)
		del_account_btn = del_txt
	del_account_btn.pressed.connect(func():
		AudioManager.play_sfx("click")
		UIHelper.show_parental_gate(self, func():
			_show_reset_confirmation_modal()
		, Callable(), "CONFIRM ACCOUNT DELETION")
	)
	del_account_center.add_child(del_account_btn)
	pc_vbox.add_child(del_account_center)
	
	privacy_card.add_child(pc_vbox)
	vbox.add_child(privacy_card)
	
	# 2. Terms & Conditions Card (Comprehensive Apple & Google Play Standard EULA)
	var terms_card = PanelContainer.new()
	var tc_st = UIHelper.create_bubbly_panel(16, Color(0.98, 0.96, 0.92), Color(0.92, 0.82, 0.65), 1)
	terms_card.add_theme_stylebox_override("panel", tc_st)
	
	var tc_vbox = VBoxContainer.new()
	tc_vbox.offset_left = 12
	tc_vbox.offset_right = -12
	tc_vbox.offset_top = 10
	tc_vbox.offset_bottom = -10
	tc_vbox.add_theme_constant_override("separation", 8)
	
	var terms_title = Label.new()
	terms_title.text = "TERMS & CONDITIONS OF USE (EULA)"
	UIHelper.apply_bubbly_label(terms_title, 13, Color(0.85, 0.45, 0.10), true)
	tc_vbox.add_child(terms_title)
	
	var terms_body = Label.new()
	terms_body.text = """Welcome to Pearly Whites Challenge. By installing or using this application, you agree to be bound by these Terms & Conditions.

1. INTENDED PURPOSE & EDUCATIONAL USE
Pearly Whites Challenge is an interactive habit-building and educational application designed for children and families to encourage healthy daily oral hygiene habits. The app, its interactive timers, facts, and mini-games are for motivational and habit-tracking purposes only and do not constitute professional dental or medical advice.

2. VIRTUAL ITEMS & IN-GAME CURRENCIES
All virtual items—including Molar Coins, Star Points, digital badges, character costumes, and toothbrush equipment—are non-transferable, purely cosmetic or gameplay-enhancing elements. Virtual rewards carry zero cash value and cannot be redeemed, sold, or exchanged for legal currency.

3. PARENTAL SUPERVISION RECOMMENDED
Parents and legal guardians are encouraged to supervise young children during brushing routines and device usage. 

4. INTELLECTUAL PROPERTY
All visual assets, character artwork, sound effects, music tracks, and code contained within Pearly Whites Challenge are owned by or licensed to the developer and are protected by copyright and intellectual property laws.

5. ACCOUNT DELETION & DATA WIPING
Users may permanently delete all their account data, profiles, and saved progression at any time via the "WIPE & RESET GAME DATA" feature located in the Settings screen.

6. LIMITATION OF LIABILITY
The app is provided "as is" without warranties of any kind. Under no circumstances shall the developers or distributors be liable for indirect, incidental, or consequential damages resulting from your use of or inability to use the app.

7. GOVERNING LAW & UPDATES
These terms are subject to change to maintain compliance with Apple App Store and Google Play Store distribution policies."""
	terms_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UIHelper.apply_bubbly_label(terms_body, 10, Color(0.25, 0.35, 0.45), false)
	tc_vbox.add_child(terms_body)
	terms_card.add_child(tc_vbox)
	vbox.add_child(terms_card)
	
	# Separator line
	vbox.add_child(_create_h_separator())
	
	# 4. Support Developers Tipping Card
	var tip_card = PanelContainer.new()
	var tc2_st = UIHelper.create_bubbly_panel(16, Color(0.93, 0.96, 1.0), Color(0.75, 0.88, 0.98), 1)
	tip_card.add_theme_stylebox_override("panel", tc2_st)
	
	var tip_box = VBoxContainer.new()
	tip_box.offset_left = 12
	tip_box.offset_right = -12
	tip_box.offset_top = 10
	tip_box.offset_bottom = -10
	tip_box.add_theme_constant_override("separation", 8)
	
	var tip_lbl = Label.new()
	tip_lbl.text = "Support the Developers (In-App Tip Jar)"
	tip_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(tip_lbl, 13, Color(0.18, 0.45, 0.78), true)
	tip_box.add_child(tip_lbl)
	
	var tip_sub = Label.new()
	tip_sub.text = "Tips unlock the legendary Sir Crown player and award +500 Coins and +500 Points!"
	tip_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip_sub.autowrap_mode = TextServer.AUTOWRAP_WORD
	UIHelper.apply_bubbly_label(tip_sub, 11, Color(0.40, 0.50, 0.65))
	tip_box.add_child(tip_sub)
	
	var tip_center = CenterContainer.new()
	var tip_dev_btn = UIHelper.create_themed_button("supportdev", Vector2(240, 46))
	if not tip_dev_btn.texture_normal:
		tip_dev_btn = UIHelper.create_bubbly_button("SUPPORT DEVELOPERS", UIHelper.GOLD_YELLOW)
		tip_dev_btn.custom_minimum_size = Vector2(240, 44)
	tip_dev_btn.pressed.connect(func():
		AudioManager.play_sfx("click")
		TipManager.support_developers()
	)
	tip_center.add_child(tip_dev_btn)
	tip_box.add_child(tip_center)
	tip_card.add_child(tip_box)
	vbox.add_child(tip_card)
	
	# Bottom Back Button
	var back_to_set_btn = UIHelper.create_image_button("res://assets/images/buttons/backtosettings_btn.png", Vector2(280, 48))
	if not back_to_set_btn.texture_normal:
		back_to_set_btn = UIHelper.create_themed_button("backtosettings", Vector2(280, 48))
	if not back_to_set_btn.texture_normal:
		back_to_set_btn = UIHelper.create_bubbly_button("BACK TO SETTINGS", Color(0.24, 0.58, 0.92))
		back_to_set_btn.custom_minimum_size = Vector2(280, 44)
	back_to_set_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back_to_set_btn.pressed.connect(_switch_to_settings)
	vbox.add_child(back_to_set_btn)

func _on_close():
	var main_node = get_tree().root.get_node_or_null("Main")
	if main_node and main_node.has_method("navigate_to"):
		main_node.navigate_to("map")
	else:
		back_pressed.emit()
