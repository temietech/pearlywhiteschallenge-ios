# scripts/brush_check_screen.gd
extends Control

signal back_pressed
signal start_brushing_pressed

# UI References
var bg: TextureRect
var title: Label
var cam_card: Panel
var inner_box: Panel
var msg: Label
var pbar: ProgressBar
var sub_lbl: Label
var btn_box: HBoxContainer
var back_btn: BaseButton
var retry_btn: BaseButton
var parental_override_btn: BaseButton

# Camera & Reticle Overlays
var camera_feed: TextureRect
var rear_cam_badge: Panel
var tflite_badge: Panel
var scanline_laser: ColorRect
var scanline_pos: float = 0.0
var scanline_dir: float = 1.0
var reticle_box: Panel
var confidence_lbl: Label

# Native Android Plugin State
var android_scanner: Object = null
const PLUGIN_NAME: String = "PearlyToothbrushScanner"

# Fallback Camera Server State (for Desktop / Editor test)
var active_camera_feed: CameraFeed = null
var camera_feed_texture: CameraTexture = null
# Live preview sent by the native iOS plugin
var native_preview_texture: ImageTexture = null
var native_preview_live: bool = false
var inference_timer: Timer = null

# Detection Progression State
var is_scanning: bool = false
var is_verified: bool = false
var current_confidence: float = 0.0
var scan_duration: float = 0.0
const SCAN_TIMEOUT_SECONDS: float = 6.0
var failed_scan_attempts: int = 0
const MAX_ATTEMPTS_BEFORE_OVERRIDE: int = 3
var live_hold_time: float = 0.0
const REQUIRED_HOLD_TIME: float = 0.8

func _ready():
	set_anchors_preset(Control.PRESET_FULL_RECT)
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_right = 0
	offset_bottom = 0
	failed_scan_attempts = GameState.brush_check_failed_attempts
	_build_ui()
	_relayout()
	_init_android_plugin()
	_start_scanner_session()

func _exit_tree():
	_stop_scanner_session()

func _notification(what):
	if what == NOTIFICATION_RESIZED:
		if is_node_ready():
			_relayout()

func _process(delta: float):
	if is_scanning and not is_verified:
		# 1. Animate viewfinder laser line
		var max_h = (inner_box.size.y - 8.0) if inner_box else 240.0
		scanline_pos += delta * 150.0 * scanline_dir
		if scanline_pos >= max_h:
			scanline_pos = max_h
			scanline_dir = -1.0
		elif scanline_pos <= 6.0:
			scanline_pos = 6.0
			scanline_dir = 1.0
		if scanline_laser and is_instance_valid(scanline_laser):
			scanline_laser.position.y = scanline_pos

		# 2. Update Progress Bar & require steady physical hold
		if current_confidence >= 60.0:
			live_hold_time += delta
			var hold_pct = clamp(live_hold_time / REQUIRED_HOLD_TIME, 0.0, 1.0)
			if pbar:
				pbar.value = max(current_confidence, hold_pct * 100.0)
			if msg and not is_verified:
				msg.text = "Toothbrush detected! Hold steady (%.0f%%)..." % [hold_pct * 100.0]
				msg.add_theme_color_override("font_color", Color(0.35, 0.90, 1.0))
			if live_hold_time >= REQUIRED_HOLD_TIME and not is_verified:
				_on_toothbrush_verified()
		else:
			live_hold_time = max(0.0, live_hold_time - delta * 1.5)
			if pbar:
				pbar.value = clamp(current_confidence, 0.0, 100.0)

		# 3. Track scan duration timeout
		scan_duration += delta
		if scan_duration >= SCAN_TIMEOUT_SECONDS and current_confidence < 60.0:
			_on_scan_timeout()

func _init_android_plugin():
	if Engine.has_singleton(PLUGIN_NAME):
		android_scanner = Engine.get_singleton(PLUGIN_NAME)
		print("[PearlyScanner] Initialized Android Native Plugin: ", PLUGIN_NAME)
		
		# Connect native Android signals
		if not android_scanner.is_connected("toothbrush_verified", Callable(self, "_on_native_toothbrush_verified")):
			android_scanner.connect("toothbrush_verified", Callable(self, "_on_native_toothbrush_verified"))
		if not android_scanner.is_connected("toothbrush_detected", Callable(self, "_on_native_toothbrush_detected")):
			android_scanner.connect("toothbrush_detected", Callable(self, "_on_native_toothbrush_detected"))
		if not android_scanner.is_connected("scanner_error", Callable(self, "_on_native_scanner_error")):
			android_scanner.connect("scanner_error", Callable(self, "_on_native_scanner_error"))
		if not android_scanner.is_connected("permission_result", Callable(self, "_on_native_permission_result")):
			android_scanner.connect("permission_result", Callable(self, "_on_native_permission_result"))
		# iOS plugin only: live camera image for the viewfinder
		if android_scanner.has_signal("preview_frame") and not android_scanner.is_connected("preview_frame", Callable(self, "_on_native_preview_frame")):
			android_scanner.connect("preview_frame", Callable(self, "_on_native_preview_frame"))
	else:
		print("[PearlyScanner] Android native plugin not detected. Enabling desktop editor fallback.")

func _start_scanner_session():
	is_scanning = true
	is_verified = false
	current_confidence = 0.0
	scan_duration = 0.0
	live_hold_time = 0.0
	scanline_pos = 10.0
	scanline_dir = 1.0
	native_preview_live = false

	if retry_btn:
		retry_btn.visible = false

	if sub_lbl:
		sub_lbl.text = "HOLD YOUR TOOTHBRUSH UP TO THE CAMERA..."
		sub_lbl.add_theme_color_override("font_color", Color.WHITE)
	if msg:
		msg.text = "Toothbrush detector scanning..."
		msg.add_theme_color_override("font_color", Color.WHITE)

	# 1. Start Native Android Plugin if available
	if android_scanner:
		if android_scanner.has_method("startScanner"):
			android_scanner.call("startScanner")
	else:
		# 2. Desktop / Editor Fallback Camera View
		_start_desktop_camera_fallback()

func _start_desktop_camera_fallback():
	# Also makes iOS show the camera permission prompt if the native plugin is missing
	CameraServer.monitoring_feeds = true
	if OS.get_name() == "Android":
		OS.request_permission("CAMERA")
	var feeds = CameraServer.feeds()
	var rear_feed: CameraFeed = null
	for f in feeds:
		if is_instance_valid(f) and f.get_position() == CameraFeed.FEED_BACK:
			rear_feed = f
			break
	if not rear_feed and feeds.size() > 0:
		rear_feed = feeds[0]

	if rear_feed:
		active_camera_feed = rear_feed
		active_camera_feed.feed_is_active = true
		camera_feed_texture = CameraTexture.new()
		camera_feed_texture.camera_feed_id = active_camera_feed.get_id()
		if active_camera_feed.get_datatype() == CameraFeed.FEED_YCBCR_SEP:
			# iOS delivers camera frames as separate Y and CbCr planes. Reading them as RGBA
			# gives a red/pink picture, so convert YCbCr -> RGB in a shader instead.
			camera_feed_texture.which_feed = CameraServer.FEED_Y_IMAGE
			var cbcr_tex := CameraTexture.new()
			cbcr_tex.camera_feed_id = active_camera_feed.get_id()
			cbcr_tex.which_feed = CameraServer.FEED_CBCR_IMAGE
			var sh := Shader.new()
			sh.code = """shader_type canvas_item;
uniform sampler2D cbcr_tex : filter_linear;
uniform vec2 box_size = vec2(1.0, 1.0);
uniform float rotate_quarter = 1.0; // 1.0 = rotate the landscape sensor image 90 degrees clockwise (portrait phone)
void fragment() {
	vec2 ts = vec2(textureSize(TEXTURE, 0));
	if (ts.x < 2.0 || ts.y < 2.0) { ts = vec2(4.0, 3.0); }
	vec2 img = rotate_quarter > 0.5 ? vec2(ts.y, ts.x) : ts;
	float a_img = img.x / img.y;
	float a_box = box_size.x / max(box_size.y, 1.0);
	vec2 uv = UV - vec2(0.5);
	// "cover" the box: crop the longer side instead of stretching
	if (a_box > a_img) { uv.y *= a_img / a_box; } else { uv.x *= a_box / a_img; }
	uv += vec2(0.5);
	vec2 src = rotate_quarter > 0.5 ? vec2(uv.y, 1.0 - uv.x) : uv;
	float y = texture(TEXTURE, src).r;
	vec2 c = texture(cbcr_tex, src).rg - vec2(0.5);
	vec3 rgb = vec3(y + 1.402 * c.y, y - 0.344136 * c.x - 0.714136 * c.y, y + 1.772 * c.x);
	COLOR = vec4(rgb, 1.0);
}
"""
			var mat := ShaderMaterial.new()
			mat.shader = sh
			mat.set_shader_parameter("cbcr_tex", cbcr_tex)
			if camera_feed:
				# The shader does its own rotation + cover-crop, so the rect must simply fill the box
				camera_feed.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				camera_feed.stretch_mode = TextureRect.STRETCH_SCALE
				camera_feed.material = mat
				mat.set_shader_parameter("box_size", camera_feed.size)
		else:
			camera_feed_texture.which_feed = CameraServer.FEED_RGBA_IMAGE
			if camera_feed:
				camera_feed.material = null
		if camera_feed:
			camera_feed.texture = camera_feed_texture
			camera_feed.modulate = Color.WHITE

func _stop_scanner_session():
	if android_scanner and android_scanner.has_method("stopScanner"):
		android_scanner.call("stopScanner")
	if inference_timer and is_instance_valid(inference_timer):
		inference_timer.stop()
	if active_camera_feed and is_instance_valid(active_camera_feed):
		active_camera_feed.feed_is_active = false
		active_camera_feed = null

# --- NATIVE ANDROID PLUGIN SIGNAL HANDLERS ---

func _on_native_toothbrush_verified(confidence: float):
	current_confidence = confidence
	_on_toothbrush_verified()

func _on_native_toothbrush_detected(confidence: float, label: String):
	current_confidence = confidence
	if confidence_lbl:
		if confidence > 0.0:
			confidence_lbl.text = "%s Detected (%.1f%%)" % [label.capitalize(), confidence]
		else:
			confidence_lbl.text = "Searching for Toothbrush..."

func _on_native_preview_frame(rgba: PackedByteArray, width: int, height: int):
	if not is_scanning or is_verified or not camera_feed:
		return
	if rgba.size() != width * height * 4:
		return
	var img := Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, rgba)
	if native_preview_texture and native_preview_texture.get_size() == Vector2(width, height):
		native_preview_texture.update(img)
	else:
		native_preview_texture = ImageTexture.create_from_image(img)
	if camera_feed.texture != native_preview_texture:
		camera_feed.texture = native_preview_texture
		camera_feed.modulate = Color.WHITE
	if not native_preview_live:
		# Camera is really running now (after any permission prompt): start the timeout from here.
		native_preview_live = true
		scan_duration = 0.0

func _on_native_scanner_error(err_msg: String):
	print("[PearlyScanner] Scanner Error: ", err_msg)
	if msg:
		msg.text = "Camera Notice: %s\nYou can retry or tap Start Brushing Session." % err_msg
		msg.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
	if retry_btn:
		retry_btn.visible = true
	if parental_override_btn:
		parental_override_btn.visible = true

func _on_native_permission_result(granted: bool):
	if not granted:
		if msg:
			msg.text = "Camera access is needed to scan your toothbrush.\nYou can enable camera access or tap Start Brushing Session."
			msg.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
		if retry_btn:
			retry_btn.visible = true
			if retry_btn is Button:
				retry_btn.text = "ENABLE CAMERA"
		if parental_override_btn:
			parental_override_btn.visible = true
	else:
		if msg:
			msg.text = "Camera permission granted! Starting scanner..."
			msg.add_theme_color_override("font_color", UIHelper.VIBRANT_GREEN)
		if retry_btn:
			retry_btn.visible = false
			if retry_btn is Button:
				retry_btn.text = "TRY AGAIN"

# --- COMMON VERIFICATION FLOW ---

func _on_toothbrush_verified(instant: bool = false):
	if is_verified:
		return
	is_verified = true
	is_scanning = false
	failed_scan_attempts = 0
	GameState.brush_check_failed_attempts = 0
	_stop_scanner_session()
	AudioManager.play_sfx("chime")

	if scanline_laser and is_instance_valid(scanline_laser):
		scanline_laser.color = Color(0.2, 1.0, 0.4, 0.9)
	if reticle_box and is_instance_valid(reticle_box):
		var r_st = reticle_box.get_theme_stylebox("panel") as StyleBoxFlat
		if r_st:
			r_st.border_color = UIHelper.VIBRANT_GREEN
			r_st.bg_color = Color(0.12, 0.85, 0.35, 0.22)
	if confidence_lbl and is_instance_valid(confidence_lbl):
		confidence_lbl.text = "Toothbrush Locked: %.1f%%" % current_confidence
		confidence_lbl.add_theme_color_override("font_color", UIHelper.VIBRANT_GREEN)

	if sub_lbl:
		sub_lbl.text = "TOOTHBRUSH VERIFIED! READY!"
		sub_lbl.add_theme_color_override("font_color", UIHelper.VIBRANT_GREEN)
	if msg:
		msg.text = "TOOTHBRUSH DETECTED!\nStarting 2-minute brushing timer..."
		msg.add_theme_color_override("font_color", UIHelper.VIBRANT_GREEN)

	if instant:
		# Parent unlocked with the PIN: go straight to brushing
		start_brushing_pressed.emit.call_deferred()
		return
	var timer = get_tree().create_timer(1.2)
	timer.timeout.connect(func():
		if is_inside_tree():
			start_brushing_pressed.emit()
	)

func _on_scan_timeout():
	is_scanning = false
	_stop_scanner_session()

	failed_scan_attempts += 1
	GameState.brush_check_failed_attempts = failed_scan_attempts

	if msg:
		msg.text = "Toothbrush not detected.\nPosition your toothbrush clearly or retry scan."
		msg.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))

	if retry_btn:
		retry_btn.visible = true

	if failed_scan_attempts >= MAX_ATTEMPTS_BEFORE_OVERRIDE:
		if sub_lbl:
			sub_lbl.text = "3 FAILURES REACHED: PARENT PIN REQUIRED"
			sub_lbl.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35))
		UIHelper.show_parental_gate(self, func():
			failed_scan_attempts = 0
			GameState.brush_check_failed_attempts = 0
			_on_toothbrush_verified(true)
		)
	else:
		if sub_lbl:
			sub_lbl.text = "SCAN TIMED OUT (%d/%d TRIES). TRY AGAIN!" % [failed_scan_attempts, MAX_ATTEMPTS_BEFORE_OVERRIDE]
			sub_lbl.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))

	if parental_override_btn:
		parental_override_btn.visible = false

func _on_retry_pressed():
	AudioManager.play_sfx("click")
	if retry_btn:
		retry_btn.visible = false
	_start_scanner_session()

func _on_error_override_pressed():
	AudioManager.play_sfx("click")
	UIHelper.show_parental_gate(self, func():
		failed_scan_attempts = 0
		GameState.brush_check_failed_attempts = 0
		_on_toothbrush_verified(true)
	)

func _relayout():
	var safe_sz = UIHelper.get_viewport_safe_size(self)
	var cur_w = safe_sz.x
	var cur_h = safe_sz.y
	
	if bg:
		bg.size = safe_sz
		
	var card_w = clamp(cur_w - 40.0, 320.0, 420.0)
	var card_h = clamp(cur_h * 0.46, 320.0, 430.0)
	
	if title:
		var title_w = min(cur_w - 32.0, 410.0)
		title.size = Vector2(title_w, 70)
		# Title stays clear of the notch on iPhone
		title.position = Vector2((cur_w - title_w) * 0.5, max(max(52.0, cur_h * 0.08), UIHelper.safe_top + 6.0))
		
	if cam_card:
		var card_y = max(title.position.y + title.size.y + 10.0, cur_h * 0.18)
		cam_card.size = Vector2(card_w, card_h)
		cam_card.position = Vector2((cur_w - card_w) * 0.5, card_y)
		
		if inner_box:
			inner_box.size = Vector2(card_w - 32.0, card_h - 32.0)
			inner_box.position = Vector2(16, 16)
			if camera_feed:
				camera_feed.size = inner_box.size
				camera_feed.position = Vector2.ZERO
				if camera_feed.material is ShaderMaterial:
					(camera_feed.material as ShaderMaterial).set_shader_parameter("box_size", inner_box.size)
			if scanline_laser:
				scanline_laser.size = Vector2(inner_box.size.x, 3)
			if reticle_box:
				var ret_w = clampf(inner_box.size.x * 0.72, 180.0, 260.0)
				var ret_h = clampf(inner_box.size.y * 0.60, 120.0, 200.0)
				reticle_box.size = Vector2(ret_w, ret_h)
				reticle_box.position = Vector2((inner_box.size.x - ret_w) * 0.5, (inner_box.size.y - ret_h) * 0.44)
			if msg:
				msg.size = Vector2(inner_box.size.x - 24.0, 80)
				msg.position = Vector2(12, inner_box.size.y - 90)
				
		var below_y = card_y + card_h + 16.0
		if pbar:
			pbar.size = Vector2(card_w, 14)
			pbar.position = Vector2((cur_w - card_w) * 0.5, below_y)
		if sub_lbl:
			sub_lbl.size = Vector2(card_w, 24)
			sub_lbl.position = Vector2((cur_w - card_w) * 0.5, below_y + 20.0)
		if btn_box:
			var box_w = clamp(cur_w - 24.0, 320.0, 420.0)
			btn_box.size = Vector2(box_w, 48)
			btn_box.position = Vector2((cur_w - box_w) * 0.5, below_y + 52.0)

func _build_ui():
	# Background
	bg = TextureRect.new()
	UIHelper.setup_fullscreen_bg(bg)
	bg.texture = UIHelper.create_sky_gradient_texture()
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(bg)
	
	# Title
	title = Label.new()
	title.text = "SHOW ME YOUR\nTOOTHBRUSH!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(title, 26, Color.WHITE, true)
	title.add_theme_color_override("font_shadow_color", Color(0.12, 0.45, 0.85, 0.9))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 3)
	add_child(title)
	
	# Viewfinder Frame Card
	cam_card = Panel.new()
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.06, 0.16, 0.28, 0.98)
	card_style.set_corner_radius_all(28)
	card_style.border_width_left = 4
	card_style.border_width_right = 4
	card_style.border_width_top = 4
	card_style.border_width_bottom = 4
	card_style.border_color = Color.WHITE
	cam_card.add_theme_stylebox_override("panel", card_style)
	add_child(cam_card)
	
	# Inner Container
	inner_box = Panel.new()
	var inner_style = StyleBoxFlat.new()
	inner_style.bg_color = Color(0.04, 0.10, 0.20, 0.75)
	inner_style.set_corner_radius_all(20)
	inner_style.border_width_left = 2
	inner_style.border_width_right = 2
	inner_style.border_width_top = 2
	inner_style.border_width_bottom = 2
	inner_style.border_color = Color(0.35, 0.65, 0.95, 0.4)
	inner_box.add_theme_stylebox_override("panel", inner_style)
	cam_card.add_child(inner_box)
	
	# Rear Camera Texture Display
	camera_feed = TextureRect.new()
	camera_feed.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	camera_feed.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	camera_feed.modulate = Color(1, 1, 1, 0.35)
	var default_tex = UIHelper.load_texture_safe("res://assets/images/brushing/toothbrush_icon.png")
	if default_tex:
		camera_feed.texture = default_tex
	inner_box.add_child(camera_feed)
	
	# Rear Camera HUD Badge (top left)
	rear_cam_badge = Panel.new()
	var rcb_st = UIHelper.create_bubbly_panel(10, Color(0.02, 0.08, 0.18, 0.85), Color(0.20, 0.85, 0.45), 1)
	rear_cam_badge.add_theme_stylebox_override("panel", rcb_st)
	rear_cam_badge.position = Vector2(10, 10)
	rear_cam_badge.size = Vector2(148, 22)
	rear_cam_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rcb_lbl = Label.new()
	rcb_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	rcb_lbl.text = "CAMERA ACTIVE"
	rcb_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rcb_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(rcb_lbl, 9, Color(0.30, 0.95, 0.55), true)
	rear_cam_badge.add_child(rcb_lbl)
	inner_box.add_child(rear_cam_badge)
	
	# Toothbrush Detector Badge (top right)
	tflite_badge = Panel.new()
	var tfb_st = UIHelper.create_bubbly_panel(10, Color(0.02, 0.08, 0.18, 0.85), Color(0.35, 0.75, 1.0), 1)
	tflite_badge.add_theme_stylebox_override("panel", tfb_st)
	tflite_badge.position = Vector2(166, 10)
	tflite_badge.size = Vector2(154, 22)
	tflite_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tfb_lbl = Label.new()
	tfb_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	tfb_lbl.text = "TOOTHBRUSH DETECTOR"
	tfb_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tfb_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(tfb_lbl, 9, Color(0.60, 0.88, 1.0), true)
	tflite_badge.add_child(tfb_lbl)
	inner_box.add_child(tflite_badge)
	
	# Detection Reticle Box
	reticle_box = Panel.new()
	var ret_st = StyleBoxFlat.new()
	ret_st.bg_color = Color(0.18, 0.65, 0.95, 0.10)
	ret_st.set_corner_radius_all(14)
	ret_st.border_width_left = 2
	ret_st.border_width_right = 2
	ret_st.border_width_top = 2
	ret_st.border_width_bottom = 2
	ret_st.border_color = Color(0.35, 0.80, 1.0, 0.85)
	reticle_box.add_theme_stylebox_override("panel", ret_st)
	reticle_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner_box.add_child(reticle_box)
	
	confidence_lbl = Label.new()
	confidence_lbl.set_anchors_preset(Control.PRESET_TOP_WIDE)
	confidence_lbl.position = Vector2(6, 6)
	confidence_lbl.size = Vector2(180, 18)
	confidence_lbl.text = "Searching..."
	UIHelper.apply_bubbly_label(confidence_lbl, 10, Color(0.90, 0.95, 1.0), true)
	reticle_box.add_child(confidence_lbl)
	
	# Laser Line
	scanline_laser = ColorRect.new()
	scanline_laser.color = Color(0.35, 0.85, 1.0, 0.80)
	scanline_laser.size = Vector2(280, 3)
	scanline_laser.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner_box.add_child(scanline_laser)
	
	# Status message
	msg = Label.new()
	msg.text = "Position your toothbrush inside the box...\nNative AI Vision Scanning..."
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UIHelper.apply_bubbly_label(msg, 13, Color.WHITE, true)
	msg.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	inner_box.add_child(msg)
	
	# Progress bar
	pbar = ProgressBar.new()
	pbar.show_percentage = false
	var pb_bg = StyleBoxFlat.new()
	pb_bg.bg_color = Color(0.20, 0.48, 0.80, 0.4)
	pb_bg.set_corner_radius_all(7)
	var pb_fill = StyleBoxFlat.new()
	pb_fill.bg_color = UIHelper.GOLD_YELLOW
	pb_fill.set_corner_radius_all(7)
	pbar.add_theme_stylebox_override("background", pb_bg)
	pbar.add_theme_stylebox_override("fill", pb_fill)
	pbar.value = 0
	add_child(pbar)
	
	# Subtitle
	sub_lbl = Label.new()
	sub_lbl.text = "POINT REAR CAMERA AT YOUR TOOTHBRUSH..."
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(sub_lbl, 12, Color.WHITE, true)
	add_child(sub_lbl)
	
	# Bottom Buttons Container
	btn_box = HBoxContainer.new()
	btn_box.add_theme_constant_override("separation", 12)
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(btn_box)
	
	# BACK Button
	var themed_back = UIHelper.create_themed_button("back", Vector2(80, 44))
	if themed_back and themed_back.texture_normal:
		back_btn = themed_back
	else:
		var txt_btn = Button.new()
		txt_btn.text = "BACK"
		txt_btn.custom_minimum_size = Vector2(80, 44)
		var bb_style = UIHelper.create_bubbly_panel(22, Color(1, 1, 1, 0.95), Color(0.68, 0.88, 1.0), 3)
		txt_btn.add_theme_stylebox_override("normal", bb_style)
		txt_btn.add_theme_stylebox_override("hover", bb_style)
		txt_btn.add_theme_stylebox_override("pressed", bb_style)
		UIHelper.apply_bubbly_label(txt_btn, 13, Color(0.12, 0.38, 0.68), true)
		back_btn = txt_btn
	back_btn.pressed.connect(func():
		AudioManager.play_sfx("click")
		back_pressed.emit()
	)
	btn_box.add_child(back_btn)

	# TRY AGAIN Button (hidden initially)
	var themed_retry = UIHelper.create_image_button("res://assets/images/buttons/tryagain_btn.png", Vector2(130, 44))
	if not themed_retry.texture_normal:
		themed_retry = UIHelper.create_themed_button("tryagain", Vector2(130, 44))
	if themed_retry and themed_retry.texture_normal:
		retry_btn = themed_retry
	else:
		retry_btn = Button.new()
		retry_btn.text = "TRY AGAIN"
		retry_btn.custom_minimum_size = Vector2(106, 44)
		var rb_style = UIHelper.create_bubbly_panel(22, UIHelper.GOLD_YELLOW, Color.WHITE, 3)
		retry_btn.add_theme_stylebox_override("normal", rb_style)
		retry_btn.add_theme_stylebox_override("hover", rb_style)
		retry_btn.add_theme_stylebox_override("pressed", rb_style)
		UIHelper.apply_bubbly_label(retry_btn, 12, Color(0.12, 0.28, 0.58), true)
	retry_btn.visible = false
	retry_btn.pressed.connect(_on_retry_pressed)
	btn_box.add_child(retry_btn)

	# START BRUSHING SESSION Button (shown after scan attempts / errors)
	parental_override_btn = Button.new()
	parental_override_btn.text = "START BRUSHING SESSION"
	parental_override_btn.custom_minimum_size = Vector2(170, 44)
	var pb_style = UIHelper.create_bubbly_panel(22, Color(0.18, 0.72, 0.38), Color.WHITE, 3)
	parental_override_btn.add_theme_stylebox_override("normal", pb_style)
	parental_override_btn.add_theme_stylebox_override("hover", pb_style)
	parental_override_btn.add_theme_stylebox_override("pressed", pb_style)
	UIHelper.apply_bubbly_label(parental_override_btn, 11, Color.WHITE, true)
	parental_override_btn.visible = false
	parental_override_btn.pressed.connect(_on_error_override_pressed)
	btn_box.add_child(parental_override_btn)
