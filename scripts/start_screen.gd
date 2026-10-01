# scripts/start_screen.gd
extends Control

signal start_pressed

var bg: TextureRect
var bg_fill: TextureRect
var start_btn: TextureButton

func _ready():
	set_anchors_preset(Control.PRESET_FULL_RECT)
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_right = 0
	offset_bottom = 0
	_build_ui()
	_relayout()


func _notification(what):
	if what == NOTIFICATION_RESIZED:
		if is_node_ready():
			_relayout()

func _relayout():
	var safe_sz = UIHelper.get_viewport_safe_size(self)
	var cur_w = safe_sz.x
	var cur_h = safe_sz.y
	var is_tablet = cur_w >= 600.0 or (cur_w / max(1.0, cur_h)) >= 0.68
	
	if bg:
		# Fill the whole screen (iPhone notch / iPad edges included), not just the safe size
		var full_sz = get_viewport_rect().size if is_inside_tree() else safe_sz
		bg.position = Vector2.ZERO
		bg.size = Vector2(max(safe_sz.x, full_sz.x), max(safe_sz.y, full_sz.y))
		# Phones: show the WHOLE artwork width (nothing cut off at the sides); the small leftover
		# strips at top/bottom are filled with the artwork's own sky-blue / pink edge colours.
		# Tablets: keep filling the whole screen (cover).
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED if is_tablet else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if bg_fill:
			bg_fill.position = Vector2.ZERO
			bg_fill.size = bg.size
			bg_fill.visible = not is_tablet
		_update_background(cur_w, cur_h)
		
	if start_btn:
		var btn_w: float
		var bottom_pad: float
		if is_tablet:
			btn_w = clamp(round(cur_w * 0.345), 210.0, 285.0)
			bottom_pad = 36.0 + UIHelper.safe_bottom
		else:
			btn_w = clamp(round(cur_w * 0.525), 180.0, 232.5)
			bottom_pad = 24.0 + UIHelper.safe_bottom

		var btn_h = round(btn_w * (228.0 / 493.0))
		var btn_x = (cur_w - btn_w) * 0.5
		var btn_y = cur_h - btn_h - bottom_pad

		start_btn.size = Vector2(btn_w, btn_h)
		start_btn.custom_minimum_size = Vector2(btn_w, btn_h)
		start_btn.position = Vector2(btn_x, btn_y)
		start_btn.pivot_offset = Vector2(btn_w * 0.5, btn_h * 0.5)

var _bg_kind: String = ""

func _update_background(cur_w: float = 0.0, cur_h: float = 0.0):
	if not bg: return
	if cur_w <= 0.0 or cur_h <= 0.0:
		var sz = UIHelper.get_viewport_safe_size(self)
		cur_w = sz.x
		cur_h = sz.y
	# iPhones / phones get the tall phone artwork, tablets get the tablet artwork
	var is_tablet = cur_w >= 600.0 or (cur_w / max(1.0, cur_h)) >= 0.68
	var kind = "tablet" if is_tablet else "phone"
	if kind == _bg_kind and bg.texture:
		return
	var phone_paths = ["res://assets/images/backgrounds/Start-Page.jpg"]
	var tablet_paths = ["res://assets/images/backgrounds/Start-Page-tablet.jpeg"]
	var ordered = (tablet_paths + phone_paths) if is_tablet else (phone_paths + tablet_paths)
	var clean_tex: Texture2D = null
	for path in ordered:
		clean_tex = UIHelper.load_texture_safe(path)
		if clean_tex:
			break
	if clean_tex:
		bg.texture = clean_tex
		_bg_kind = kind

func _build_ui():
	# Fullscreen Start-Page background art (adaptive phone / tablet)
	var grad = Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.45, 0.55, 1.0])
	grad.colors = PackedColorArray([
		Color8(90, 185, 233), Color8(90, 185, 233),
		Color8(229, 133, 175), Color8(229, 133, 175)
	])
	var grad_tex = GradientTexture2D.new()
	grad_tex.gradient = grad
	grad_tex.fill_from = Vector2(0.5, 0.0)
	grad_tex.fill_to = Vector2(0.5, 1.0)
	grad_tex.width = 8
	grad_tex.height = 256
	bg_fill = TextureRect.new()
	bg_fill.texture = grad_tex
	bg_fill.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_fill.stretch_mode = TextureRect.STRETCH_SCALE
	bg_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg_fill)
	
	bg = TextureRect.new()
	UIHelper.setup_fullscreen_bg(bg)
	add_child(bg)
	_update_background()
	
	var btn_w = 260.0
	var btn_h = 112.0
	start_btn = UIHelper.create_image_button("res://assets/images/brushing/start_brushing_button.png", Vector2(btn_w, btn_h))
	if not start_btn.texture_normal:
		start_btn = UIHelper.create_image_button("res://assets/images/misc/start_brushing_button.png", Vector2(btn_w, btn_h))
	start_btn.pivot_offset = Vector2(btn_w * 0.5, btn_h * 0.5)
	
	start_btn.pressed.connect(func():
		AudioManager.play_sfx("pop")
		start_pressed.emit()
	)
	
	# Gentle pulsing animation for Start button
	var tw = start_btn.create_tween().set_loops()
	tw.tween_property(start_btn, "scale", Vector2(1.04, 1.04), 0.75).set_trans(Tween.TRANS_SINE)
	tw.tween_property(start_btn, "scale", Vector2(1.0, 1.0), 0.75).set_trans(Tween.TRANS_SINE)
	
	add_child(start_btn)