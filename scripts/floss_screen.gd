# scripts/floss_screen.gd
extends Control

signal floss_completed
signal no_floss_proceed
signal back_pressed

enum State { PROMPT, FLOSSING, PENALTY }
var current_state: State = State.PROMPT

var bg: TextureRect
var back_btn: TextureButton

# --- Phase 1: Prompt UI ---
var prompt_container: Control
var prompt_title: Label
var prompt_card: Panel
var floss_mascot: TextureRect
var prompt_sub_label: Label
var green_floss_btn: BaseButton
var red_no_floss_btn: BaseButton

# --- Phase 2: Flossing 30s Sequence UI ---
var flossing_container: Control
var flossing_title: Label
var timer_capsule: Panel
var timer_label: Label
var progress_bar: ProgressBar
var video_card: Panel
var video_player: VideoStreamPlayer
var video_mat: ShaderMaterial
var demo_floss_icon: TextureRect
var tip_bubble: Panel
var tip_label: Label
var done_btn: BaseButton
var flossing_timer: Timer
var time_left: int = 30
const TOTAL_FLOSS_TIME: int = 30
var floss_scrub_tween: Tween

# --- Penalty Modal ---
var penalty_modal: Control

func _ready():
	set_anchors_preset(Control.PRESET_FULL_RECT)
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_right = 0
	offset_bottom = 0
	
	_build_ui()
	_relayout()
	_set_state(State.PROMPT)
	
	# Preload 3D combat assets in background during flossing screen
	GameState.preload_candy_crusade_in_background()

func _notification(what):
	# FIX: Pause floss timer when app backgrounds, resume when returns to focus
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		if current_state == State.FLOSSING and flossing_timer:
			flossing_timer.paused = true
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		if current_state == State.FLOSSING and flossing_timer:
			flossing_timer.paused = false
	elif what == NOTIFICATION_RESIZED:
		if is_node_ready():
			_relayout()

func _build_ui():
	# Background
	bg = TextureRect.new()
	UIHelper.setup_fullscreen_bg(bg)
	bg.texture = UIHelper.create_sky_gradient_texture()
	add_child(bg)
	
	_build_prompt_ui()
	_build_flossing_sequence_ui()
	
	# Top Back Button (placed on top of all containers)
	back_btn = TextureButton.new()
	back_btn.texture_normal = UIHelper.load_texture_safe("res://assets/images/shop/blue_back_button.png")
	back_btn.custom_minimum_size = Vector2(80, 36)
	back_btn.ignore_texture_size = true
	back_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	back_btn.z_index = 100
	back_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	back_btn.pressed.connect(func():
		AudioManager.play_sfx("click")
		if video_player:
			video_player.stop()
		back_pressed.emit()
	)
	add_child(back_btn)

func _build_prompt_ui():
	prompt_container = Control.new()
	prompt_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	prompt_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(prompt_container)
	
	prompt_title = Label.new()
	prompt_title.text = "READY TO FLOSS?"
	prompt_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(prompt_title, 28, Color.WHITE, true)
	prompt_title.add_theme_color_override("font_shadow_color", Color(0.12, 0.40, 0.75, 0.90))
	prompt_title.add_theme_constant_override("shadow_offset_x", 2)
	prompt_title.add_theme_constant_override("shadow_offset_y", 3)
	prompt_container.add_child(prompt_title)
	
	prompt_card = Panel.new()
	var card_st = UIHelper.create_bubbly_panel(28, Color.WHITE, Color(0.80, 0.90, 1.0, 0.95), 3)
	prompt_card.add_theme_stylebox_override("panel", card_st)
	prompt_container.add_child(prompt_card)
	
	var card_vbox = VBoxContainer.new()
	card_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	card_vbox.offset_left = 20
	card_vbox.offset_right = -20
	card_vbox.offset_top = 24
	card_vbox.offset_bottom = -24
	card_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card_vbox.add_theme_constant_override("separation", 16)
	prompt_card.add_child(card_vbox)
	
	floss_mascot = TextureRect.new()
	floss_mascot.custom_minimum_size = Vector2(140, 140)
	floss_mascot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	floss_mascot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var floss_tex = UIHelper.load_texture_safe("res://assets/images/candycrusadegame/dental_floss_icon.png")
	if not floss_tex:
		floss_tex = UIHelper.load_texture_safe("res://assets/images/candycrusadegame/flossweapon.png")
	floss_mascot.texture = floss_tex
	floss_mascot.pivot_offset = Vector2(70, 70)
	card_vbox.add_child(floss_mascot)
	
	# Gentle idle float for floss
	var ftw = floss_mascot.create_tween().set_loops()
	ftw.tween_property(floss_mascot, "position:y", -6.0, 1.2).as_relative().set_trans(Tween.TRANS_SINE)
	ftw.tween_property(floss_mascot, "position:y", 6.0, 1.2).as_relative().set_trans(Tween.TRANS_SINE)
	
	prompt_sub_label = Label.new()
	prompt_sub_label.text = "Flossing before brushing clears sneaky plaque hiding between teeth!\nDo you have your floss ready?"
	prompt_sub_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	prompt_sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_sub_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(prompt_sub_label, 14, Color(0.18, 0.38, 0.65), true)
	card_vbox.add_child(prompt_sub_label)
	
	var btn_vbox = VBoxContainer.new()
	btn_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_vbox.add_theme_constant_override("separation", 12)
	card_vbox.add_child(btn_vbox)
	
	# Green button: "FLOSSING TIME" (flossingtime_btn.png, 625x121 artwork)
	var floss_img_btn := UIHelper.create_image_button("res://assets/images/buttons/flossingtime_btn.png", Vector2(260, 50))
	if floss_img_btn.texture_normal:
		green_floss_btn = floss_img_btn
	else:
		var floss_txt_btn := UIHelper.create_bubbly_button("FLOSSING TIME!", UIHelper.VIBRANT_GREEN)
		floss_txt_btn.custom_minimum_size = Vector2(250, 52)
		green_floss_btn = floss_txt_btn
	green_floss_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	green_floss_btn.pressed.connect(_on_flossing_time_pressed)
	btn_vbox.add_child(green_floss_btn)
	
	# Red button: "I DON'T HAVE FLOSS"
	var no_floss_img := UIHelper.create_image_button("res://assets/images/buttons/idonthavefloss_btn.png", Vector2(260, 50))
	if no_floss_img.texture_normal:
		red_no_floss_btn = no_floss_img
	else:
		var no_floss_txt := UIHelper.create_bubbly_button("I DON'T HAVE FLOSS", UIHelper.VIBRANT_RED)
		no_floss_txt.custom_minimum_size = Vector2(250, 48)
		red_no_floss_btn = no_floss_txt
	red_no_floss_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	red_no_floss_btn.pressed.connect(_on_no_floss_pressed)
	btn_vbox.add_child(red_no_floss_btn)

func _build_flossing_sequence_ui():
	flossing_container = Control.new()
	flossing_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	flossing_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flossing_container.visible = false
	add_child(flossing_container)
	
	flossing_title = Label.new()
	flossing_title.text = "FLOSSING TIME!"
	flossing_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flossing_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(flossing_title, 26, Color.WHITE, true)
	flossing_title.add_theme_color_override("font_shadow_color", Color(0.10, 0.38, 0.70, 0.90))
	flossing_title.add_theme_constant_override("shadow_offset_x", 2)
	flossing_title.add_theme_constant_override("shadow_offset_y", 3)
	flossing_container.add_child(flossing_title)
	
	# Timer capsule ("0:30")
	timer_capsule = Panel.new()
	var cap_st = UIHelper.create_bubbly_panel(22, Color(1, 1, 1, 0.95), Color(0.70, 0.88, 1.0), 3)
	timer_capsule.add_theme_stylebox_override("panel", cap_st)
	flossing_container.add_child(timer_capsule)
	
	timer_label = Label.new()
	timer_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	timer_label.text = "0:30"
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(timer_label, 26, Color(0.18, 0.44, 0.80), true)
	timer_capsule.add_child(timer_label)
	
	# Video / Tutorial demonstration card
	video_card = Panel.new()
	video_card.clip_contents = true
	video_card.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	var v_st = UIHelper.create_bubbly_panel(26, Color(0.08, 0.18, 0.32, 0.95), Color.WHITE, 4)
	video_card.add_theme_stylebox_override("panel", v_st)
	flossing_container.add_child(video_card)
	
	# Video Player
	video_player = VideoStreamPlayer.new()
	video_player.set_anchors_preset(Control.PRESET_FULL_RECT)
	video_player.offset_left = 4
	video_player.offset_right = -4
	video_player.offset_top = 4
	video_player.offset_bottom = -4
	video_player.expand = true
	video_player.loop = true
	video_player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	video_player.bus = "Master"
	
	var rounded_shader = Shader.new()
	rounded_shader.code = """
shader_type canvas_item;

uniform float corner_radius : hint_range(0.0, 100.0) = 22.0;
uniform vec2 size = vec2(340.0, 260.0);

float rounded_box(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + vec2(r);
    return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
    vec4 col = texture(TEXTURE, UV);
    vec2 p = (UV - vec2(0.5)) * size;
    vec2 b = size * 0.5;
    float dist = rounded_box(p, b, corner_radius);
    if (dist > 0.0) {
        discard;
    }
    float alpha = clamp(0.5 - dist, 0.0, 1.0);
    COLOR = vec4(col.rgb, col.a * alpha);
}
"""
	video_mat = ShaderMaterial.new()
	video_mat.shader = rounded_shader
	video_player.material = video_mat
	
	var v_stream = UIHelper.load_video_safe("res://assets/videos/howtofloss.ogv")
	if not v_stream:
		v_stream = UIHelper.load_video_safe("res://assets/videos/howtofloss.mp4")
	if not v_stream:
		v_stream = UIHelper.load_video_safe("res://assets/videos/howtofloss.ogv")
	if not v_stream:
		v_stream = UIHelper.load_video_safe("res://assets/videos/howtofloss.mp4")
	if v_stream:
		video_player.stream = v_stream
	video_card.add_child(video_player)

	# White rounded border overlay to guarantee crisp wrapped frame over video edges
	var border_overlay = Panel.new()
	border_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	border_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var b_st = StyleBoxFlat.new()
	b_st.bg_color = Color(0, 0, 0, 0)
	b_st.border_color = Color.WHITE
	b_st.set_border_width_all(4)
	b_st.set_corner_radius_all(26)
	border_overlay.add_theme_stylebox_override("panel", b_st)
	video_card.add_child(border_overlay)
	
	# Inner fallback animation placeholder / tutorial graphic container
	var demo_center = CenterContainer.new()
	demo_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	demo_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	demo_center.visible = (video_player.stream == null)
	video_card.add_child(demo_center)
	
	var demo_vbox = VBoxContainer.new()
	demo_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	demo_vbox.add_theme_constant_override("separation", 10)
	demo_center.add_child(demo_vbox)
	
	demo_floss_icon = TextureRect.new()
	demo_floss_icon.custom_minimum_size = Vector2(120, 120)
	demo_floss_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	demo_floss_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var d_tex = UIHelper.load_texture_safe("res://assets/images/candycrusadegame/dental_floss_icon.png")
	if not d_tex:
		d_tex = UIHelper.load_texture_safe("res://assets/images/candycrusadegame/flossweapon.png")
	demo_floss_icon.texture = d_tex
	demo_floss_icon.pivot_offset = Vector2(60, 60)
	demo_vbox.add_child(demo_floss_icon)
	
	var demo_lbl = Label.new()
	demo_lbl.text = "TUTORIAL DEMO\nGently slide floss between each tooth\nin a smooth C-shape curve!"
	demo_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(demo_lbl, 13, Color(0.85, 0.94, 1.0), true)
	demo_vbox.add_child(demo_lbl)
	
	# Progress Bar
	progress_bar = ProgressBar.new()
	progress_bar.max_value = TOTAL_FLOSS_TIME
	progress_bar.value = 0
	progress_bar.show_percentage = false
	var p_bg = StyleBoxFlat.new()
	p_bg.bg_color = Color(0.15, 0.30, 0.52, 0.8)
	p_bg.set_corner_radius_all(8)
	progress_bar.add_theme_stylebox_override("background", p_bg)
	var p_fill = StyleBoxFlat.new()
	p_fill.bg_color = UIHelper.VIBRANT_GREEN
	p_fill.set_corner_radius_all(8)
	progress_bar.add_theme_stylebox_override("fill", p_fill)
	flossing_container.add_child(progress_bar)
	
	# Tip Bubble
	tip_bubble = Panel.new()
	var tb_st = UIHelper.create_bubbly_panel(18, Color(1, 1, 1, 0.92), Color(0.72, 0.86, 1.0), 2)
	tip_bubble.add_theme_stylebox_override("panel", tb_st)
	flossing_container.add_child(tip_bubble)
	
	tip_label = Label.new()
	tip_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	tip_label.offset_left = 12
	tip_label.offset_right = -12
	tip_label.text = "Tip: Never snap the floss into gums! Glide gently up and down."
	tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	UIHelper.apply_bubbly_label(tip_label, 11, Color(0.12, 0.35, 0.65), true)
	tip_bubble.add_child(tip_label)
	
	# "DONE FLOSSING" / Skip Button
	var done_img := UIHelper.create_image_button("res://assets/images/buttons/doneflossing_btn.png", Vector2(240, 46))
	if done_img.texture_normal:
		done_btn = done_img
	else:
		var done_txt := UIHelper.create_bubbly_button("DONE FLOSSING!", UIHelper.VIBRANT_GREEN)
		done_txt.custom_minimum_size = Vector2(230, 52)
		done_btn = done_txt
	done_btn.pressed.connect(_on_flossing_complete)
	flossing_container.add_child(done_btn)
	
	# Timer
	flossing_timer = Timer.new()
	flossing_timer.wait_time = 1.0
	flossing_timer.timeout.connect(_on_floss_tick)
	add_child(flossing_timer)

func _relayout():
	var safe_sz = UIHelper.get_viewport_safe_size(self)
	var cur_w = safe_sz.x
	var cur_h = safe_sz.y
	
	if bg:
		bg.size = safe_sz
	if back_btn:
		back_btn.position = Vector2(16, 16)
		back_btn.size = Vector2(74, 34)
		
	# Phase 1: Prompt layout
	if prompt_container:
		if prompt_title:
			# Title stays clear of the notch on iPhone; back button stays in the corner
			prompt_title.position = Vector2(20, max(max(24.0, cur_h * 0.08), UIHelper.safe_top + 6.0))
			prompt_title.size = Vector2(cur_w - 40.0, 50)
		if prompt_card:
			var card_w = clamp(cur_w - 40.0, 310.0, 420.0)
			var card_h = clamp(cur_h * 0.62, 380.0, 480.0)
			prompt_card.size = Vector2(card_w, card_h)
			prompt_card.position = Vector2((cur_w - card_w) * 0.5, (cur_h - card_h) * 0.5 + 14.0)
			
	# Phase 2: Flossing Sequence layout
	if flossing_container:
		# Everything in this phase drops just enough to clear the notch on iPhone
		var ft_base = max(18.0, cur_h * 0.06)
		var ft_shift = max(0.0, (UIHelper.safe_top + 6.0) - ft_base)
		if flossing_title:
			flossing_title.position = Vector2(20, ft_base + ft_shift)
			flossing_title.size = Vector2(cur_w - 40.0, 44)
		if timer_capsule:
			var cap_w = 120.0
			var cap_h = 44.0
			timer_capsule.size = Vector2(cap_w, cap_h)
			timer_capsule.position = Vector2((cur_w - cap_w) * 0.5, max(68.0, cur_h * 0.12) + ft_shift)
		if video_card:
			var v_w = clamp(cur_w - 40.0, 310.0, 420.0)
			var v_h = clamp(cur_h * 0.44, 260.0, 340.0)
			var v_y = max(124.0, cur_h * 0.20) + ft_shift
			video_card.size = Vector2(v_w, v_h)
			video_card.position = Vector2((cur_w - v_w) * 0.5, v_y)
			if video_mat:
				video_mat.set_shader_parameter("size", Vector2(v_w - 8.0, v_h - 8.0))
				video_mat.set_shader_parameter("corner_radius", 22.0)
			
			var below_v = v_y + v_h + 14.0
			if progress_bar:
				progress_bar.size = Vector2(v_w, 14.0)
				progress_bar.position = Vector2((cur_w - v_w) * 0.5, below_v)
			if tip_bubble:
				tip_bubble.size = Vector2(v_w, 48.0)
				tip_bubble.position = Vector2((cur_w - v_w) * 0.5, below_v + 24.0)
			if done_btn:
				var db_w = min(240.0, cur_w - 60.0)
				done_btn.custom_minimum_size = Vector2(db_w, db_w / 5.2)
				done_btn.size = Vector2(db_w, db_w / 5.2)
				done_btn.position = Vector2((cur_w - db_w) * 0.5, below_v + 84.0)

func _set_state(st: State):
	current_state = st
	if prompt_container:
		prompt_container.visible = (st == State.PROMPT)
	if flossing_container:
		flossing_container.visible = (st == State.FLOSSING)

func _exit_tree():
	if video_player:
		video_player.stop()

func _on_flossing_time_pressed():
	AudioManager.play_sfx("click")
	_set_state(State.FLOSSING)
	time_left = TOTAL_FLOSS_TIME
	progress_bar.value = 0
	timer_label.text = "0:%02d" % time_left
	flossing_timer.start()
	
	if video_player and video_player.stream:
		video_player.play()
	
	# Animate demo floss scrub
	if demo_floss_icon:
		if floss_scrub_tween:
			floss_scrub_tween.kill()
		floss_scrub_tween = demo_floss_icon.create_tween().set_loops()
		floss_scrub_tween.tween_property(demo_floss_icon, "rotation_degrees", 15.0, 0.4).set_trans(Tween.TRANS_SINE)
		floss_scrub_tween.parallel().tween_property(demo_floss_icon, "scale", Vector2(1.1, 1.1), 0.4)
		floss_scrub_tween.tween_property(demo_floss_icon, "rotation_degrees", -15.0, 0.4).set_trans(Tween.TRANS_SINE)
		floss_scrub_tween.parallel().tween_property(demo_floss_icon, "scale", Vector2(0.95, 0.95), 0.4)

func _on_floss_tick():
	time_left -= 1
	var elapsed = TOTAL_FLOSS_TIME - time_left
	progress_bar.value = elapsed
	timer_label.text = "0:%02d" % max(0, time_left)
	
	if time_left <= 0:
		flossing_timer.stop()
		_on_flossing_complete()

func _on_flossing_complete():
	var elapsed = TOTAL_FLOSS_TIME - time_left
	
	# In non-dev mode, check if clicked done in under 10 seconds
	if not GameState.dev_mode and elapsed < 10:
		if flossing_timer:
			flossing_timer.stop()
		if video_player:
			video_player.stop()
		if floss_scrub_tween:
			floss_scrub_tween.kill()
			
		AudioManager.play_sfx("error")
		
		# Deduct 100 points for dishonest early skip
		var p_prof = GameState.get_active_profile()
		var cur_p = int(p_prof.get("points", 0))
		var new_p = max(0, cur_p - 100)
		GameState.update_active_profile({"points": new_p})
		
		_show_too_fast_penalty_modal()
		return

	if flossing_timer:
		flossing_timer.stop()
	if video_player:
		video_player.stop()
	if floss_scrub_tween:
		floss_scrub_tween.kill()
		
	AudioManager.play_sfx("coin")
	
	# Award +50 points bonus for flossing
	var p = GameState.get_active_profile()
	var cur_pts = int(p.get("points", 0))
	GameState.update_active_profile({"points": cur_pts + 50})
	
	# Show bonus toast then proceed to toothbrush check
	_show_floss_bonus_toast("+50 Floss Bonus!", func():
		floss_completed.emit()
	)

func _on_no_floss_pressed():
	AudioManager.play_sfx("error")
	if video_player:
		video_player.stop()
	
	# Penalise player with -100 points (floor at 0)
	var p = GameState.get_active_profile()
	var cur_pts = int(p.get("points", 0))
	var new_pts = max(0, cur_pts - 100)
	GameState.update_active_profile({"points": new_pts})
	
	_show_penalty_modal(cur_pts - new_pts)

func _show_penalty_modal(deducted: int):
	if penalty_modal and is_instance_valid(penalty_modal):
		penalty_modal.queue_free()
		
	var safe_sz = UIHelper.get_viewport_safe_size(self)
	var dlg = UIHelper.create_modal_dialog(self, 100, Color(0.04, 0.08, 0.18, 0.85))
	penalty_modal = dlg["overlay"]
	var center = dlg["center"]
	
	var card_w = clamp(safe_sz.x - 48.0, 290.0, 360.0)
	var card_h = 240.0
	var card = Panel.new()
	card.custom_minimum_size = Vector2(card_w, card_h)
	card.size = Vector2(card_w, card_h)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var c_st = UIHelper.create_bubbly_panel(24, Color.WHITE, Color(0.92, 0.30, 0.35), 4)
	card.add_theme_stylebox_override("panel", c_st)
	center.add_child(card)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 16
	vbox.offset_right = -16
	vbox.offset_top = 18
	vbox.offset_bottom = -18
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 10)
	card.add_child(vbox)
	
	var h_lbl = Label.new()
	h_lbl.text = "-100 POINTS!"
	h_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(h_lbl, 22, Color(0.85, 0.18, 0.22), true)
	vbox.add_child(h_lbl)
	
	var msg_lbl = Label.new()
	msg_lbl.text = "Dental floss reaches where toothbrushes can't!\nAsk a grown-up to get some floss for next time."
	msg_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	msg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(msg_lbl, 12, Color(0.25, 0.35, 0.48), true)
	vbox.add_child(msg_lbl)
	
	var cont_btn = UIHelper.create_bubbly_button("TIME TO BRUSH!", UIHelper.VIBRANT_GREEN)
	cont_btn.custom_minimum_size = Vector2(200, 46)
	cont_btn.pressed.connect(func():
		AudioManager.play_sfx("click")
		penalty_modal.queue_free()
		no_floss_proceed.emit()
	)
	vbox.add_child(cont_btn)

func _show_floss_bonus_toast(text: String, on_done: Callable):
	var safe_sz = UIHelper.get_viewport_safe_size(self)
	var toast = Panel.new()
	var t_w = 260.0
	var t_h = 56.0
	toast.size = Vector2(t_w, t_h)
	toast.position = Vector2((safe_sz.x - t_w) * 0.5, safe_sz.y * 0.45)
	var t_st = UIHelper.create_bubbly_panel(28, UIHelper.VIBRANT_GREEN, Color.WHITE, 3)
	toast.add_theme_stylebox_override("panel", t_st)
	toast.z_index = 110
	add_child(toast)
	
	var lbl = Label.new()
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(lbl, 16, Color.WHITE, true)
	toast.add_child(lbl)
	
	toast.scale = Vector2(0.6, 0.6)
	toast.pivot_offset = toast.size * 0.5
	var tw = toast.create_tween()
	tw.tween_property(toast, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(1.2)
	tw.tween_property(toast, "modulate:a", 0.0, 0.3)
	tw.finished.connect(func():
		toast.queue_free()
		on_done.call()
	)

func _show_too_fast_penalty_modal():
	if penalty_modal and is_instance_valid(penalty_modal):
		penalty_modal.queue_free()
		
	var safe_sz = UIHelper.get_viewport_safe_size(self)
	var dlg = UIHelper.create_modal_dialog(self, 100, Color(0.04, 0.08, 0.18, 0.85))
	penalty_modal = dlg["overlay"]
	var center = dlg["center"]
	
	var card_w = clamp(safe_sz.x - 48.0, 300.0, 380.0)
	var card_h = 270.0
	var card = Panel.new()
	card.custom_minimum_size = Vector2(card_w, card_h)
	card.size = Vector2(card_w, card_h)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var c_st = UIHelper.create_bubbly_panel(24, Color.WHITE, Color(0.92, 0.30, 0.35), 4)
	card.add_theme_stylebox_override("panel", c_st)
	center.add_child(card)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 16
	vbox.offset_right = -16
	vbox.offset_top = 18
	vbox.offset_bottom = -18
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 10)
	card.add_child(vbox)
	
	var h_lbl = Label.new()
	h_lbl.text = "TOO FAST! -100 POINTS"
	h_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(h_lbl, 20, Color(0.85, 0.18, 0.22), true)
	vbox.add_child(h_lbl)
	
	var msg_lbl = Label.new()
	msg_lbl.text = "It's not possible to floss that fast!\nCitizens of Mulinia and Pearly White Champions are truthful!"
	msg_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	msg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(msg_lbl, 13, Color(0.25, 0.35, 0.48), true)
	vbox.add_child(msg_lbl)
	
	var cont_btn = UIHelper.create_bubbly_button("I PROMISE TO FLOSS!", UIHelper.VIBRANT_GREEN)
	cont_btn.custom_minimum_size = Vector2(220, 48)
	cont_btn.pressed.connect(func():
		AudioManager.play_sfx("click")
		penalty_modal.queue_free()
		floss_completed.emit()
	)
	vbox.add_child(cont_btn)

