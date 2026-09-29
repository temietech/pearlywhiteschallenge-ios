# scripts/start_screen.gd
extends Control

signal start_pressed

const NEW_PHONE_BG = "C:/Users/temie/.gemini/antigravity/brain/40c9ebe0-1383-4428-afa5-a28113911371/.user_uploaded/media_1789681557847.jpg"
const NEW_TABLET_BG = "C:/Users/temie/.gemini/antigravity/brain/40c9ebe0-1383-4428-afa5-a28113911371/.user_uploaded/media_1789681571746.jpg"

var bg: TextureRect
var start_btn: TextureButton

func _ready():
	set_anchors_preset(Control.PRESET_FULL_RECT)
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_right = 0
	offset_bottom = 0
	_sync_uploaded_assets()
	_build_ui()
	_relayout()

func _notification(what):
	if what == NOTIFICATION_RESIZED:
		if is_node_ready():
			_relayout()

func _sync_uploaded_assets():
	var phone_dest = ProjectSettings.globalize_path("res://assets/images/backgrounds/Start-Page.jpg")
	var tab_dest = ProjectSettings.globalize_path("res://assets/images/backgrounds/Start-Page-tablet.jpeg")
	
	if FileAccess.file_exists(NEW_PHONE_BG):
		var bytes = FileAccess.get_file_as_bytes(NEW_PHONE_BG)
		if bytes.size() > 0:
			var f = FileAccess.open(phone_dest, FileAccess.WRITE)
			if f:
				f.store_buffer(bytes)
				f.close()
				
	if FileAccess.file_exists(NEW_TABLET_BG):
		var bytes = FileAccess.get_file_as_bytes(NEW_TABLET_BG)
		if bytes.size() > 0:
			var f = FileAccess.open(tab_dest, FileAccess.WRITE)
			if f:
				f.store_buffer(bytes)
				f.close()

func _relayout():
	var safe_sz = UIHelper.get_viewport_safe_size(self)
	var cur_w = safe_sz.x
	var cur_h = safe_sz.y
	var is_tablet = cur_w >= 600.0 or (cur_w / max(1.0, cur_h)) >= 0.68
	
	if bg:
		bg.size = safe_sz
		_update_background(cur_w, cur_h)
		
	if start_btn:
		var btn_w: float
		var bottom_pad: float
		if is_tablet:
			btn_w = clamp(round(cur_w * 0.46), 280.0, 380.0)
			bottom_pad = 36.0
		else:
			btn_w = clamp(round(cur_w * 0.70), 240.0, 310.0)
			bottom_pad = 24.0
			
		var btn_h = round(btn_w * (228.0 / 493.0))
		var btn_x = (cur_w - btn_w) * 0.5
		var btn_y = cur_h - btn_h - bottom_pad
		
		start_btn.size = Vector2(btn_w, btn_h)
		start_btn.custom_minimum_size = Vector2(btn_w, btn_h)
		start_btn.position = Vector2(btn_x, btn_y)
		start_btn.pivot_offset = Vector2(btn_w * 0.5, btn_h * 0.5)

func _update_background(cur_w: float = 0.0, cur_h: float = 0.0):
	if not bg: return
	# Prefer clean unbaked background artwork
	var clean_tex = UIHelper.load_texture_safe("res://assets/images/backgrounds/Start-Page-tablet.jpeg")
	if not clean_tex:
		clean_tex = UIHelper.load_texture_safe(NEW_TABLET_BG)
	if not clean_tex:
		clean_tex = UIHelper.load_texture_safe(NEW_PHONE_BG)
	if not clean_tex:
		clean_tex = UIHelper.load_texture_safe("res://assets/images/backgrounds/Start-Page.jpg")
	if clean_tex:
		bg.texture = clean_tex

func _build_ui():
	# Fullscreen Start-Page background art (adaptive phone / tablet)
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
