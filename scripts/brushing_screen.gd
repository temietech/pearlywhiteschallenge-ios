# scripts/brushing_screen.gd
extends Control

signal brushing_completed
signal claim_rewards_pressed(completed_day: int)
signal review_fact_pressed
signal quit_requested
signal settings_requested

var is_brushing_active: bool = false
var is_paused: bool = false
var total_seconds: int = 120
var time_left: int = 120
var current_quadrant_index: int = -1

var timer: Timer
var time_label: Label
var mouth_card: Panel
var base_mouth: TextureRect
var quadrant_rects: Array[TextureRect] = []
var germs: Array[Control] = []
var flash_overlay: ColorRect
var brush_icon: Control
var brush_tween: Tween
var _quad_transition_tween: Tween = null

var bg: TextureRect
var top_bar_rect: TextureRect
var coin_lbl: Label
var pt_lbl: Label
var day_lbl: Label
var live_coins: int = 0
var live_points: int = 0
var reward_flyers_layer: Control
var timer_capsule: Panel

var mascot_shadow: Control
var chip_shadow: Control
var mascot_rect: TextureRect
var char_rect: TextureRect
var speech_bubble: TextureRect
var bubble_label: Label

# Controls containers
var pre_brush_controls: Control
var back_btn: TextureButton
var start_btn: TextureButton
var start_btn_tween: Tween

var active_brush_controls: Control
var pb_root: Control
var progress_bar: ProgressBar
var progress_badge: TextureRect
var pause_btn: TextureButton
var pause_dim_overlay: ColorRect

var pause_modal: Control
var confirmation_modal: Control
var cheer_modal: Control

# Custom draggable coordinates & tuning
var custom_char_pos: Vector2 = Vector2.ZERO
var custom_mascot_pos: Vector2 = Vector2.ZERO
var custom_bubble_pos: Vector2 = Vector2.ZERO
var dragged_target: Control = null
var drag_target_id: String = ""
var drag_offset: Vector2 = Vector2.ZERO

# Custom path drawing
var custom_brush_path: Array = []
var is_drawing_path: bool = false
var draw_path_active: bool = false
var path_canvas: Control = null

# Tuning HUD elements
var tuning_bar: HBoxContainer = null
var coords_hud_btn: Button = null
var draw_path_btn: Button = null
var coords_popup_modal: Control = null

static var _cached_bacteria_tex: Texture2D = null

var current_music_track: String = "sparkle_beat"
var music_selector_hbox: HBoxContainer

const BRUSHING_TRACKS = [
	{"id": "sparkle_beat", "name": "Sparkle Beat"},
	{"id": "minty_pop", "name": "Minty Pop"},
	{"id": "hero_groove", "name": "Hero Groove"}
]

const QUADRANTS = [
	{
		"name": "top left",
		"tex": "res://assets/images/brushing/mouth_q_tl.png",
		"from": 120,
		"to": 90,
		"dialogue": "Start on the top left teeth!",
		"voice_prompt": "Switch to your top left teeth!",
		"brush_pos": Vector2(72, 68),
		"bristles_up": false
	},
	{
		"name": "top right",
		"tex": "res://assets/images/brushing/mouth_q_tr.png",
		"from": 90,
		"to": 60,
		"dialogue": "Top right! Keep those bristles moving!",
		"voice_prompt": "Switch to your top right teeth!",
		"brush_pos": Vector2(142, 68),
		"bristles_up": false
	},
	{
		"name": "bottom right",
		"tex": "res://assets/images/brushing/mouth_q_br.png",
		"from": 60,
		"to": 30,
		"dialogue": "Bottom right! Scrub the biting surfaces!",
		"voice_prompt": "Bottom right teeth now!",
		"brush_pos": Vector2(142, 148),
		"bristles_up": true
	},
	{
		"name": "bottom left",
		"tex": "res://assets/images/brushing/mouth_q_bl.png",
		"from": 30,
		"to": 0,
		"dialogue": "Bottom left! Finish strong!",
		"voice_prompt": "Bottom left teeth now! Almost done!",
		"brush_pos": Vector2(72, 148),
		"bristles_up": true
	}
]

# Germ positions mapped to quadrant 0..3 (TL, TR, BR, BL) on 240x240 mouth card (aligned strictly on tooth enamel)
const GERM_DATA = [
	# Quadrant 0: Top-Left (Molar, Premolar, Canine/Incisor)
	{"pos": Vector2(56, 86), "quadrant": 0, "size": 26},
	{"pos": Vector2(75, 56), "quadrant": 0, "size": 25},
	{"pos": Vector2(108, 44), "quadrant": 0, "size": 24},
	# Quadrant 1: Top-Right (Canine/Incisor, Premolar, Molar)
	{"pos": Vector2(132, 44), "quadrant": 1, "size": 24},
	{"pos": Vector2(165, 56), "quadrant": 1, "size": 25},
	{"pos": Vector2(184, 86), "quadrant": 1, "size": 26},
	# Quadrant 2: Bottom-Right (Molar, Premolar, Canine/Incisor)
	{"pos": Vector2(184, 156), "quadrant": 2, "size": 26},
	{"pos": Vector2(165, 178), "quadrant": 2, "size": 25},
	{"pos": Vector2(132, 194), "quadrant": 2, "size": 24},
	# Quadrant 3: Bottom-Left (Molar, Premolar, Canine/Incisor)
	{"pos": Vector2(56, 156), "quadrant": 3, "size": 26},
	{"pos": Vector2(75, 178), "quadrant": 3, "size": 25},
	{"pos": Vector2(108, 194), "quadrant": 3, "size": 24}
]

var QUADRANT_TEETH_PATHS = [
	# Q0: Top-Left (TL) (109 points)
	[Vector2(75, 93), Vector2(69, 95), Vector2(63, 97), Vector2(56, 96), Vector2(54, 88), Vector2(58, 82), Vector2(64, 81), Vector2(68, 86), Vector2(65, 91), Vector2(59, 92), Vector2(54, 87), Vector2(52, 81), Vector2(52, 75), Vector2(59, 72), Vector2(65, 70), Vector2(71, 73), Vector2(71, 79), Vector2(65, 79), Vector2(62, 74), Vector2(61, 67), Vector2(65, 61), Vector2(71, 60), Vector2(77, 59), Vector2(80, 64), Vector2(74, 66), Vector2(67, 65), Vector2(69, 59), Vector2(75, 57), Vector2(81, 56), Vector2(87, 56), Vector2(91, 61), Vector2(84, 61), Vector2(80, 56), Vector2(81, 50), Vector2(87, 48), Vector2(94, 47), Vector2(98, 52), Vector2(95, 57), Vector2(92, 51), Vector2(96, 46), Vector2(102, 46), Vector2(108, 45), Vector2(113, 48), Vector2(112, 54), Vector2(106, 55), Vector2(100, 54), Vector2(97, 49), Vector2(100, 44), Vector2(106, 43), Vector2(112, 43), Vector2(118, 43), Vector2(122, 48), Vector2(117, 53), Vector2(111, 53), Vector2(105, 50), Vector2(102, 45), Vector2(103, 38), Vector2(109, 37), Vector2(114, 43), Vector2(111, 48), Vector2(106, 51), Vector2(100, 52), Vector2(94, 53), Vector2(87, 50), Vector2(92, 55), Vector2(85, 57), Vector2(80, 54), Vector2(80, 47), Vector2(86, 46), Vector2(93, 47), Vector2(96, 52), Vector2(90, 54), Vector2(83, 56), Vector2(76, 57), Vector2(71, 54), Vector2(76, 51), Vector2(81, 55), Vector2(81, 61), Vector2(76, 65), Vector2(69, 67), Vector2(68, 61), Vector2(73, 58), Vector2(79, 59), Vector2(80, 65), Vector2(77, 70), Vector2(72, 75), Vector2(66, 75), Vector2(61, 70), Vector2(64, 65), Vector2(70, 64), Vector2(75, 69), Vector2(75, 76), Vector2(73, 82), Vector2(67, 86), Vector2(61, 87), Vector2(54, 85), Vector2(60, 80), Vector2(66, 78), Vector2(72, 78), Vector2(73, 84), Vector2(68, 89), Vector2(63, 92), Vector2(56, 93), Vector2(62, 89), Vector2(67, 92), Vector2(66, 98), Vector2(60, 98), Vector2(54, 95), Vector2(54, 89)],
	# Q1: Top-Right (TR) (91 points)
	[Vector2(130, 54), Vector2(127, 49), Vector2(126, 43), Vector2(131, 39), Vector2(135, 45), Vector2(136, 51), Vector2(131, 54), Vector2(129, 48), Vector2(133, 43), Vector2(139, 42), Vector2(144, 45), Vector2(145, 51), Vector2(139, 53), Vector2(139, 47), Vector2(145, 46), Vector2(151, 46), Vector2(159, 48), Vector2(160, 54), Vector2(154, 55), Vector2(147, 55), Vector2(151, 50), Vector2(158, 51), Vector2(163, 54), Vector2(165, 60), Vector2(159, 61), Vector2(162, 56), Vector2(168, 56), Vector2(172, 61), Vector2(172, 67), Vector2(166, 69), Vector2(164, 63), Vector2(170, 61), Vector2(176, 63), Vector2(175, 69), Vector2(171, 75), Vector2(165, 77), Vector2(160, 74), Vector2(166, 72), Vector2(172, 72), Vector2(178, 78), Vector2(181, 83), Vector2(182, 89), Vector2(178, 94), Vector2(174, 89), Vector2(177, 84), Vector2(184, 86), Vector2(187, 91), Vector2(185, 97), Vector2(179, 101), Vector2(173, 104), Vector2(169, 98), Vector2(168, 92), Vector2(169, 86), Vector2(175, 82), Vector2(178, 87), Vector2(173, 92), Vector2(167, 92), Vector2(162, 88), Vector2(161, 82), Vector2(161, 76), Vector2(165, 70), Vector2(171, 68), Vector2(166, 72), Vector2(157, 72), Vector2(154, 66), Vector2(157, 61), Vector2(163, 62), Vector2(162, 68), Vector2(156, 68), Vector2(149, 68), Vector2(144, 65), Vector2(141, 60), Vector2(143, 54), Vector2(150, 54), Vector2(156, 57), Vector2(150, 60), Vector2(143, 59), Vector2(137, 56), Vector2(134, 51), Vector2(140, 50), Vector2(141, 56), Vector2(135, 58), Vector2(129, 58), Vector2(124, 55), Vector2(121, 50), Vector2(123, 44), Vector2(127, 38), Vector2(132, 33), Vector2(138, 30), Vector2(142, 35), Vector2(140, 42)],
	# Q2: Bottom-Right (BR) (99 points)
	[Vector2(177, 152), Vector2(182, 155), Vector2(183, 161), Vector2(179, 167), Vector2(173, 168), Vector2(168, 165), Vector2(172, 159), Vector2(178, 157), Vector2(184, 159), Vector2(184, 166), Vector2(178, 169), Vector2(173, 172), Vector2(166, 172), Vector2(164, 166), Vector2(171, 164), Vector2(177, 164), Vector2(180, 169), Vector2(176, 174), Vector2(171, 178), Vector2(165, 181), Vector2(162, 176), Vector2(168, 173), Vector2(172, 178), Vector2(166, 181), Vector2(161, 184), Vector2(155, 185), Vector2(158, 180), Vector2(161, 185), Vector2(158, 190), Vector2(152, 190), Vector2(152, 184), Vector2(155, 179), Vector2(161, 180), Vector2(162, 186), Vector2(156, 191), Vector2(150, 195), Vector2(144, 196), Vector2(138, 196), Vector2(139, 189), Vector2(145, 188), Vector2(148, 194), Vector2(142, 195), Vector2(135, 193), Vector2(129, 191), Vector2(134, 187), Vector2(135, 194), Vector2(130, 198), Vector2(124, 200), Vector2(123, 194), Vector2(128, 189), Vector2(132, 195), Vector2(132, 188), Vector2(140, 184), Vector2(146, 185), Vector2(147, 191), Vector2(146, 185), Vector2(151, 182), Vector2(156, 185), Vector2(155, 178), Vector2(158, 173), Vector2(163, 169), Vector2(170, 169), Vector2(172, 175), Vector2(166, 178), Vector2(161, 175), Vector2(161, 169), Vector2(164, 164), Vector2(170, 158), Vector2(176, 157), Vector2(180, 163), Vector2(174, 161), Vector2(171, 156), Vector2(175, 161), Vector2(172, 167), Vector2(166, 171), Vector2(171, 176), Vector2(171, 183), Vector2(165, 186), Vector2(162, 180), Vector2(165, 175), Vector2(171, 178), Vector2(166, 183), Vector2(161, 188), Vector2(155, 190), Vector2(154, 184), Vector2(155, 190), Vector2(150, 195), Vector2(145, 198), Vector2(141, 193), Vector2(144, 187), Vector2(146, 194), Vector2(139, 195), Vector2(132, 195), Vector2(126, 191), Vector2(131, 195), Vector2(129, 201), Vector2(123, 200), Vector2(123, 194), Vector2(126, 188)],
	# Q3: Bottom-Left (BL) (104 points)
	[Vector2(113, 193), Vector2(108, 197), Vector2(106, 190), Vector2(112, 186), Vector2(117, 189), Vector2(115, 197), Vector2(110, 202), Vector2(104, 204), Vector2(101, 199), Vector2(101, 193), Vector2(106, 189), Vector2(111, 193), Vector2(106, 196), Vector2(100, 197), Vector2(93, 197), Vector2(92, 190), Vector2(97, 186), Vector2(94, 191), Vector2(90, 186), Vector2(84, 190), Vector2(78, 190), Vector2(79, 184), Vector2(82, 179), Vector2(88, 177), Vector2(92, 182), Vector2(85, 183), Vector2(79, 182), Vector2(75, 177), Vector2(75, 171), Vector2(78, 166), Vector2(81, 171), Vector2(78, 176), Vector2(71, 178), Vector2(67, 173), Vector2(68, 167), Vector2(71, 161), Vector2(77, 164), Vector2(77, 170), Vector2(72, 173), Vector2(66, 172), Vector2(64, 166), Vector2(66, 159), Vector2(72, 158), Vector2(75, 164), Vector2(69, 166), Vector2(63, 163), Vector2(57, 159), Vector2(63, 156), Vector2(68, 159), Vector2(63, 164), Vector2(57, 159), Vector2(61, 154), Vector2(67, 154), Vector2(70, 160), Vector2(70, 167), Vector2(68, 173), Vector2(62, 173), Vector2(59, 167), Vector2(57, 159), Vector2(63, 154), Vector2(69, 156), Vector2(72, 161), Vector2(74, 168), Vector2(74, 174), Vector2(73, 180), Vector2(68, 177), Vector2(68, 171), Vector2(73, 167), Vector2(79, 167), Vector2(84, 172), Vector2(83, 178), Vector2(77, 179), Vector2(71, 180), Vector2(67, 175), Vector2(73, 173), Vector2(78, 176), Vector2(81, 181), Vector2(80, 187), Vector2(75, 190), Vector2(72, 185), Vector2(73, 179), Vector2(79, 178), Vector2(85, 181), Vector2(91, 186), Vector2(87, 191), Vector2(81, 191), Vector2(86, 186), Vector2(93, 186), Vector2(99, 188), Vector2(101, 195), Vector2(96, 198), Vector2(90, 196), Vector2(93, 190), Vector2(99, 188), Vector2(105, 188), Vector2(111, 189), Vector2(114, 195), Vector2(110, 200), Vector2(103, 201), Vector2(98, 198), Vector2(100, 191), Vector2(106, 190), Vector2(112, 189), Vector2(117, 194)]
]

var brush_anim_time: float = 0.0

class FloorShadow extends Control:
	var shadow_color: Color
	
	func _init(p_size: Vector2, p_color: Color = Color(0.18, 0.10, 0.28, 0.38)):
		size = p_size
		shadow_color = p_color
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		
	func _draw():
		var center = size * 0.5
		var rx = size.x * 0.5
		var ry = size.y * 0.5
		var pts = PackedVector2Array()
		for a in range(24):
			var th = a * (TAU / 24.0)
			pts.append(center + Vector2(cos(th) * rx, sin(th) * ry))
		draw_colored_polygon(pts, shadow_color)
		var inner_pts = PackedVector2Array()
		for a in range(24):
			var th = a * (TAU / 24.0)
			inner_pts.append(center + Vector2(cos(th) * rx * 0.70, sin(th) * ry * 0.70))
		draw_colored_polygon(inner_pts, Color(shadow_color.r, shadow_color.g, shadow_color.b, shadow_color.a * 0.6))

static func _ensure_bacteria_texture() -> Texture2D:
	if _cached_bacteria_tex and is_instance_valid(_cached_bacteria_tex):
		return _cached_bacteria_tex
		
	# Check user-provided file in .godot/ or project folders
	var candidate_paths = [
		ProjectSettings.globalize_path("res://assets/images/brushing/bacteria.png"),
		ProjectSettings.globalize_path("res://assets/images/brushing/bacteria.png"),
		ProjectSettings.globalize_path("res://assets/images/brushing/bacteria.png"),
		ProjectSettings.globalize_path("res://assets/images/misc/bacteria.png")
	]
	
	for cp in candidate_paths:
		if FileAccess.file_exists(cp):
			var img = Image.load_from_file(cp)
			if img and not img.is_empty():
				_cached_bacteria_tex = ImageTexture.create_from_image(img)
				var dest_path = ProjectSettings.globalize_path("res://assets/images/brushing/bacteria.png")
				if cp != dest_path:
					DirAccess.make_dir_recursive_absolute(dest_path.get_base_dir())
					img.save_png(dest_path)
				return _cached_bacteria_tex
				
	var res_paths = [
		"res://assets/images/brushing/bacteria.png",
		"res://assets/images/brushing/bacteria.png",
		"res://assets/images/brushing/bacteria.png",
		"res://assets/images/misc/bacteria.png"
	]
	for rp in res_paths:
		var tex = UIHelper.load_texture_safe(rp)
		if tex:
			_cached_bacteria_tex = tex
			return _cached_bacteria_tex
			
	return null

static func _draw_circle_on_img(img: Image, pos: Vector2, radius: float, color: Color):
	var min_x = int(clamp(pos.x - radius, 0, img.get_width() - 1))
	var max_x = int(clamp(pos.x + radius, 0, img.get_width() - 1))
	var min_y = int(clamp(pos.y - radius, 0, img.get_height() - 1))
	var max_y = int(clamp(pos.y + radius, 0, img.get_height() - 1))
	var r2 = radius * radius
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			if (Vector2(x, y) - pos).length_squared() <= r2:
				img.set_pixel(x, y, color)

class WeaponToothbrush extends Control:
	var bristles_up: bool = true
	var brush_img: TextureRect
	var sparkle_time: float = 0.0
	
	func _init():
		custom_minimum_size = Vector2(40, 88)
		size = Vector2(40, 88)
		pivot_offset = Vector2(20, 16)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		brush_img = TextureRect.new()
		brush_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		brush_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		brush_img.custom_minimum_size = Vector2(40, 88)
		brush_img.size = Vector2(40, 88)
		brush_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(brush_img)
		
		_update_brush_texture()
		
	func _process(delta: float):
		if visible:
			sparkle_time += delta
			queue_redraw()
			
	func _update_brush_texture():
		var p = GameState.get_active_profile()
		var lvl = clamp(int(p.get("weaponLevels", {}).get("brush", 1)), 1, 3)
		brush_img.texture = UIHelper.load_texture_safe("res://assets/images/shop/brushweapon_%d.png" % lvl)
		
	func set_bristles_direction(_facing_up: bool):
		bristles_up = true
		brush_img.flip_h = false
		brush_img.flip_v = false
		pivot_offset = Vector2(20, 16)
		queue_redraw()
		
	func _draw():
		var pulse = sin(sparkle_time * 6.0) * 0.8
		var head_y = 16.0
		_draw_star(Vector2(6, head_y - 8), 3.2 + pulse)
		_draw_star(Vector2(34, head_y - 4), 3.8 - pulse)
		_draw_star(Vector2(18, head_y + (6.0 if bristles_up else -6.0)), 2.8 + pulse * 0.4)
		
	func _draw_star(pos: Vector2, r: float):
		r = max(1.2, r)
		var pts = PackedVector2Array([
			pos + Vector2(0, -r),
			pos + Vector2(r * 0.28, -r * 0.28),
			pos + Vector2(r, 0),
			pos + Vector2(r * 0.28, r * 0.28),
			pos + Vector2(0, r),
			pos + Vector2(-r * 0.28, r * 0.28),
			pos + Vector2(-r, 0),
			pos + Vector2(-r * 0.28, -r * 0.28)
		])
		draw_colored_polygon(pts, Color(1.0, 0.92, 0.38, 0.9))
		draw_circle(pos, r * 0.3, Color.WHITE)

class BrushPathCanvas extends Control:
	var host: Control = null
	
	func _draw():
		if not host: return
		var pts = host.custom_brush_path
		if pts.size() < 2: return
		var scale_f = (host.mouth_card.size.x / 240.0) if (host.mouth_card and is_instance_valid(host.mouth_card)) else 1.0
		var screen_pts: PackedVector2Array = []
		for p in pts:
			screen_pts.append((p as Vector2) * scale_f)
		# Draw glowing path polyline
		draw_polyline(screen_pts, Color(0.18, 0.85, 1.0, 0.92), 4.0, true)
		# Start and end dots
		if screen_pts.size() > 0:
			draw_circle(screen_pts[0], 5.0, Color(0.25, 1.0, 0.45, 0.95))
			draw_circle(screen_pts[-1], 5.0, Color(1.0, 0.85, 0.20, 0.95))

class PlaqueGerm extends Control:
	var quadrant: int = 0
	var germ_size: float = 28.0
	var tex_rect: TextureRect
	
	func _init(p_quadrant: int, p_size: float, p_texture: Texture2D = null):
		quadrant = p_quadrant
		germ_size = p_size
		custom_minimum_size = Vector2(p_size, p_size)
		size = Vector2(p_size, p_size)
		pivot_offset = Vector2(p_size * 0.5, p_size * 0.5)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		tex_rect = TextureRect.new()
		tex_rect.name = "BacteriaImg"
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.position = Vector2.ZERO
		tex_rect.size = Vector2(p_size, p_size)
		tex_rect.custom_minimum_size = Vector2(p_size, p_size)
		tex_rect.pivot_offset = Vector2(p_size * 0.5, p_size * 0.5)
		if p_texture:
			tex_rect.texture = p_texture
		else:
			tex_rect.texture = UIHelper.load_texture_safe("res://assets/images/brushing/bacteria.png")
			if not tex_rect.texture:
				tex_rect.texture = UIHelper.load_texture_safe("res://assets/images/misc/bacteria.png")
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(tex_rect)
		
	func _ready():
		_start_idle_wobble()
		
	func _start_idle_wobble():
		tex_rect.scale = Vector2.ONE
		var tw = tex_rect.create_tween().set_loops()
		var delay = randf_range(0.0, 0.4)
		var tilt_ang = randf_range(16.0, 20.0)
		var dur = randf_range(0.42, 0.52)
		
		tw.tween_interval(delay)
		# Step 1: Smooth tilt left
		tw.tween_property(tex_rect, "rotation_degrees", -tilt_ang, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		# Step 2: Smooth tilt right
		tw.tween_property(tex_rect, "rotation_degrees", tilt_ang, dur * 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		# Step 3: Return to center
		tw.tween_property(tex_rect, "rotation_degrees", 0.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _ready():
	anchors_preset = Control.PRESET_FULL_RECT
	anchor_right = 1.0
	anchor_bottom = 1.0
	_build_ui()
	_relayout()
	_set_pre_brush_state()

func _notification(what):
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_relayout()

func _process(delta: float):
	_fit_bubble_text()
	if not is_brushing_active or is_paused or time_left <= 0:
		return
		
	brush_anim_time += delta
	_update_toothbrush_motion(delta)
	_update_bacteria_fading()

func _sample_path_array(pts: Array, t: float, scale_f: float) -> Vector2:
	var n = pts.size()
	if n == 0:
		return Vector2.ZERO
	if n == 1:
		return (pts[0] as Vector2) * scale_f
	var total_segs = float(n - 1)
	var pos_f = clamp(t * total_segs, 0.0, total_segs)
	var idx = int(floor(pos_f))
	var frac = pos_f - float(idx)
	if idx >= n - 1:
		return (pts[n - 1] as Vector2) * scale_f
	var pA = (pts[idx] as Vector2) * scale_f
	var pB = (pts[idx + 1] as Vector2) * scale_f
	return pA.lerp(pB, frac)

func _update_toothbrush_motion(_delta: float):
	if not brush_icon or not is_instance_valid(brush_icon):
		return
		
	var scale_f = (mouth_card.size.x / 240.0) if (mouth_card and is_instance_valid(mouth_card)) else 1.0
	var guide_pos: Vector2
	# Slow, gentle sweep along the teeth path (changed from 1.6 to 0.55)
	var sweep = (sin(brush_anim_time * 0.55) + 1.0) * 0.5
	
	if custom_brush_path.size() >= 2:
		guide_pos = _sample_path_array(custom_brush_path, sweep, scale_f)
	else:
		if current_quadrant_index < 0 or current_quadrant_index >= QUADRANT_TEETH_PATHS.size():
			return
		var pts = QUADRANT_TEETH_PATHS[current_quadrant_index]
		guide_pos = _sample_path_array(pts, sweep, scale_f)
	
	# Slower, gentle circular scrub motion over the teeth (3.2s per loop instead of 1.4s)
	var circle_speed = TAU / 3.2
	var circle_angle = brush_anim_time * circle_speed
	var rx = 10.0 * scale_f
	var ry = 7.0 * scale_f
	var circle_offset = Vector2(cos(circle_angle) * rx, sin(circle_angle) * ry)
	var target_head_pos = guide_pos + circle_offset
	
	# Position brush such that pivot (head at 20, 16) is centered on the teeth
	brush_icon.position = target_head_pos - brush_icon.pivot_offset
	
	# Head on left, handle extending to the right
	# Tilt slightly upward (-86°) for upper teeth, slightly downward (-94°) for lower teeth
	var is_top_teeth = (current_quadrant_index == 0 or current_quadrant_index == 1)
	if custom_brush_path.size() >= 2:
		is_top_teeth = guide_pos.y < (120.0 * scale_f)
	var base_rot = -86.0 if is_top_teeth else -94.0
	var rot_wobble = sin(circle_angle) * 3.5
	brush_icon.rotation_degrees = base_rot + rot_wobble
	brush_icon.visible = true

func _update_bacteria_fading():
	var quad_dur: float = 5.0 if GameState.dev_mode else 30.0
	var frac = 1.0 - (timer.time_left if timer and is_instance_valid(timer) else 1.0)
	var exact_elapsed = float(total_seconds - time_left) + clamp(frac, 0.0, 1.0)
	var elapsed_in_quad = clamp(exact_elapsed - float(current_quadrant_index) * quad_dur, 0.0, quad_dur)
	var fade = clamp(1.0 - (elapsed_in_quad / quad_dur), 0.0, 1.0)
	
	for g in germs:
		if not is_instance_valid(g):
			continue
		if g.quadrant < current_quadrant_index:
			g.visible = false
			g.modulate.a = 0.0
		elif g.quadrant > current_quadrant_index:
			g.visible = true
			g.modulate.a = 1.0
			g.scale = Vector2.ONE
		else:
			g.visible = (fade > 0.01)
			g.modulate.a = fade
			g.scale = Vector2.ONE

func _input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Don't start drag if a modal dialog is open
				if (coords_popup_modal and is_instance_valid(coords_popup_modal)) or \
				   (pause_modal and is_instance_valid(pause_modal)) or \
				   (confirmation_modal and is_instance_valid(confirmation_modal)) or \
				   (cheer_modal and is_instance_valid(cheer_modal)):
					return
					
				# Don't drag if clicking on pause button, tuning buttons or action buttons
				var m_pos = get_global_mouse_position()
				if pause_btn and is_instance_valid(pause_btn) and pause_btn.visible and pause_btn.get_global_rect().has_point(m_pos):
					return
				if tuning_bar and is_instance_valid(tuning_bar) and tuning_bar.visible and tuning_bar.get_global_rect().has_point(m_pos):
					return
				if pre_brush_controls and is_instance_valid(pre_brush_controls) and pre_brush_controls.visible:
					if (start_btn and is_instance_valid(start_btn) and start_btn.get_global_rect().has_point(m_pos)) or \
					   (back_btn and is_instance_valid(back_btn) and back_btn.get_global_rect().has_point(m_pos)):
						return
						
				# Hit-test draggable items in Z-order: speech_bubble, char_rect, mascot_rect
				if speech_bubble and is_instance_valid(speech_bubble) and speech_bubble.visible and speech_bubble.get_global_rect().has_point(m_pos):
					dragged_target = speech_bubble
					drag_target_id = "bubble"
					drag_offset = speech_bubble.global_position - m_pos
					get_viewport().set_input_as_handled()
				elif char_rect and is_instance_valid(char_rect) and char_rect.visible and char_rect.get_global_rect().has_point(m_pos):
					dragged_target = char_rect
					drag_target_id = "char"
					drag_offset = char_rect.global_position - m_pos
					get_viewport().set_input_as_handled()
				elif mascot_rect and is_instance_valid(mascot_rect) and mascot_rect.visible and mascot_rect.get_global_rect().has_point(m_pos):
					dragged_target = mascot_rect
					drag_target_id = "mascot"
					drag_offset = mascot_rect.global_position - m_pos
					get_viewport().set_input_as_handled()
			else:
				if dragged_target:
					dragged_target = null
					drag_target_id = ""
	elif event is InputEventMouseMotion and dragged_target and is_instance_valid(dragged_target):
		var new_global = get_global_mouse_position() + drag_offset
		dragged_target.global_position = new_global
		var local_pos = dragged_target.position
		match drag_target_id:
			"mascot":
				custom_mascot_pos = local_pos
			"char":
				custom_char_pos = local_pos
			"bubble":
				custom_bubble_pos = local_pos

func _setup_draggable(target: Control, id_name: String):
	target.mouse_filter = Control.MOUSE_FILTER_PASS

func _setup_path_drawing_input(canvas: Control):
	canvas.gui_input.connect(func(event: InputEvent):
		if not draw_path_active:
			return
		var scale_f = (mouth_card.size.x / 240.0) if (mouth_card and is_instance_valid(mouth_card)) else 1.0
		if scale_f <= 0.001: scale_f = 1.0
		
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT:
				if event.pressed:
					is_drawing_path = true
					custom_brush_path.clear()
					var p = event.position / scale_f
					custom_brush_path.append(p)
					canvas.queue_redraw()
				else:
					is_drawing_path = false
					canvas.queue_redraw()
		elif event is InputEventMouseMotion:
			if is_drawing_path:
				var p = event.position / scale_f
				if custom_brush_path.is_empty() or (custom_brush_path[-1] as Vector2).distance_to(p) > 6.0:
					custom_brush_path.append(p)
					canvas.queue_redraw()
	)

func _toggle_draw_path_mode():
	AudioManager.play_sfx("click")
	draw_path_active = not draw_path_active
	if draw_path_active:
		if draw_path_btn:
			draw_path_btn.text = "DONE DRAWING"
			var st = draw_path_btn.get_theme_stylebox("normal") as StyleBoxFlat
			if st:
				st.bg_color = UIHelper.VIBRANT_GREEN
		if path_canvas and is_instance_valid(path_canvas):
			path_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
		bubble_label.text = "Draw a path\non the mouth\nfor the brush!"
		_pop_speech_bubble()
	else:
		if draw_path_btn:
			draw_path_btn.text = "DRAW PATH"
			var st = draw_path_btn.get_theme_stylebox("normal") as StyleBoxFlat
			if st:
				st.bg_color = Color(0.18, 0.52, 0.88)
		if path_canvas and is_instance_valid(path_canvas):
			path_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
			path_canvas.queue_redraw()
		if custom_brush_path.size() >= 2:
			bubble_label.text = "Path saved!\n%d points\nready!" % custom_brush_path.size()
		else:
			bubble_label.text = "Ready to\nbrush!"
		_pop_speech_bubble()

func _format_tuning_coords() -> String:
	var m_pos = mascot_rect.position if (mascot_rect and is_instance_valid(mascot_rect)) else custom_mascot_pos
	var c_pos = char_rect.position if (char_rect and is_instance_valid(char_rect)) else custom_char_pos
	var b_pos = speech_bubble.position if (speech_bubble and is_instance_valid(speech_bubble)) else custom_bubble_pos
	
	var text = "=== PEARLY WHITES TUNING COORDINATES ===\n"
	text += "Sir Crown (Mascot): Vector2(%d, %d)\n" % [int(round(m_pos.x)), int(round(m_pos.y))]
	text += "Chip (Character):   Vector2(%d, %d)\n" % [int(round(c_pos.x)), int(round(c_pos.y))]
	text += "Speech Bubble:      Vector2(%d, %d)\n\n" % [int(round(b_pos.x)), int(round(b_pos.y))]
	
	if custom_brush_path.size() > 0:
		text += "Toothbrush Path (%d points):\n[" % custom_brush_path.size()
		var p_strs: Array[String] = []
		for p in custom_brush_path:
			p_strs.append("Vector2(%d, %d)" % [int(round((p as Vector2).x)), int(round((p as Vector2).y))])
		text += ", ".join(p_strs) + "]\n\n"
		
	var q_names = ["TL", "TR", "BR", "BL"]
	for i in range(4):
		var pts = QUADRANT_TEETH_PATHS[i]
		text += "Toothbrush Path (%s) (%d points):\n[" % [q_names[i], pts.size()]
		var p_strs: Array[String] = []
		for p in pts:
			p_strs.append("Vector2(%d, %d)" % [int(round((p as Vector2).x)), int(round((p as Vector2).y))])
		text += ", ".join(p_strs) + "]\n\n"
	return text

func _parse_vector2_array(str_data: String) -> Array:
	var arr: Array = []
	var reg = RegEx.new()
	reg.compile("Vector2\\s*\\(\\s*(-?\\d+(?:\\.\\d+)?)\\s*,\\s*(-?\\d+(?:\\.\\d+)?)\\s*\\)")
	var matches = reg.search_all(str_data)
	for m in matches:
		arr.append(Vector2(float(m.get_string(1)), float(m.get_string(2))))
	return arr

func _apply_coords_from_text(raw: String):
	var regex_vec = RegEx.new()
	regex_vec.compile("(?i)(?:mascot|crown)[^\\n]*Vector2\\s*\\(\\s*(-?\\d+(?:\\.\\d+)?)\\s*,\\s*(-?\\d+(?:\\.\\d+)?)\\s*\\)")
	var m_res = regex_vec.search(raw)
	if m_res:
		custom_mascot_pos = Vector2(float(m_res.get_string(1)), float(m_res.get_string(2)))
		if mascot_rect and is_instance_valid(mascot_rect):
			mascot_rect.position = custom_mascot_pos
			
	regex_vec.compile("(?i)(?:chip|character)[^\\n]*Vector2\\s*\\(\\s*(-?\\d+(?:\\.\\d+)?)\\s*,\\s*(-?\\d+(?:\\.\\d+)?)\\s*\\)")
	var c_res = regex_vec.search(raw)
	if c_res:
		custom_char_pos = Vector2(float(c_res.get_string(1)), float(c_res.get_string(2)))
		if char_rect and is_instance_valid(char_rect):
			char_rect.position = custom_char_pos
			
	regex_vec.compile("(?i)(?:bubble|speech)[^\\n]*Vector2\\s*\\(\\s*(-?\\d+(?:\\.\\d+)?)\\s*,\\s*(-?\\d+(?:\\.\\d+)?)\\s*\\)")
	var b_res = regex_vec.search(raw)
	if b_res:
		custom_bubble_pos = Vector2(float(b_res.get_string(1)), float(b_res.get_string(2)))
		if speech_bubble and is_instance_valid(speech_bubble):
			speech_bubble.position = custom_bubble_pos

	var lines = raw.split("\n")
	var current_target = ""
	var buf = ""
	for line in lines:
		var l_lower = line.to_lower()
		if "toothbrush path" in l_lower:
			if current_target != "" and buf != "":
				var pts = _parse_vector2_array(buf)
				_apply_parsed_path(current_target, pts)
			if "tl" in l_lower: current_target = "tl"
			elif "tr" in l_lower: current_target = "tr"
			elif "br" in l_lower: current_target = "br"
			elif "bl" in l_lower: current_target = "bl"
			else: current_target = "custom"
			buf = line
		elif current_target != "":
			buf += "\n" + line
	if current_target != "" and buf != "":
		var pts = _parse_vector2_array(buf)
		_apply_parsed_path(current_target, pts)

func _apply_parsed_path(target: String, pts: Array):
	if pts.size() == 0:
		return
	match target:
		"tl":
			QUADRANT_TEETH_PATHS[0] = pts
		"tr":
			QUADRANT_TEETH_PATHS[1] = pts
		"br":
			QUADRANT_TEETH_PATHS[2] = pts
		"bl":
			QUADRANT_TEETH_PATHS[3] = pts
		"custom":
			custom_brush_path = pts
			if path_canvas and is_instance_valid(path_canvas):
				path_canvas.queue_redraw()

func _show_coords_popup():
	if coords_popup_modal and is_instance_valid(coords_popup_modal):
		coords_popup_modal.queue_free()
		
	var safe_sz = UIHelper.get_viewport_safe_size(self)
	var dlg = UIHelper.create_modal_dialog(self, 150, Color(0.02, 0.06, 0.16, 0.82))
	coords_popup_modal = dlg["overlay"]
	var center_cont = dlg["center"]
	
	var card_w = clamp(safe_sz.x - 32.0, 300.0, 380.0)
	var card_h = 440.0
	
	var card = Panel.new()
	card.custom_minimum_size = Vector2(card_w, card_h)
	card.size = Vector2(card_w, card_h)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var card_style = UIHelper.create_bubbly_panel(24, Color.WHITE, UIHelper.SOFT_BLUE, 3)
	card.add_theme_stylebox_override("panel", card_style)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	center_cont.add_child(card)
	
	var vbox = VBoxContainer.new()
	vbox.anchors_preset = Control.PRESET_FULL_RECT
	vbox.offset_left = 16.0
	vbox.offset_right = -16.0
	vbox.offset_top = 16.0
	vbox.offset_bottom = -16.0
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)
	card.add_child(vbox)
	
	var title = Label.new()
	title.text = "TUNING COORDINATES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(title, 18, UIHelper.DEEP_BLUE, true)
	vbox.add_child(title)
	
	var info_lbl = Label.new()
	info_lbl.text = "Drag characters on screen or paste/edit coordinates below:"
	info_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(info_lbl, 11, Color(0.30, 0.42, 0.55))
	vbox.add_child(info_lbl)
	
	var text_box = TextEdit.new()
	text_box.text = _format_tuning_coords()
	text_box.editable = true
	text_box.selecting_enabled = true
	text_box.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	text_box.custom_minimum_size = Vector2(card_w - 32.0, 160)
	var tb_st = StyleBoxFlat.new()
	tb_st.bg_color = Color(0.93, 0.96, 1.0)
	tb_st.border_color = Color(0.72, 0.85, 0.98)
	tb_st.set_border_width_all(2)
	tb_st.set_corner_radius_all(12)
	text_box.add_theme_stylebox_override("normal", tb_st)
	text_box.add_theme_color_override("font_color", Color(0.12, 0.22, 0.38))
	text_box.add_theme_font_size_override("font_size", 12)
	vbox.add_child(text_box)
	
	var btn_row_top = HBoxContainer.new()
	btn_row_top.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row_top.add_theme_constant_override("separation", 8)
	vbox.add_child(btn_row_top)
	
	var copy_btn = UIHelper.create_bubbly_button("COPY", UIHelper.VIBRANT_GREEN)
	copy_btn.custom_minimum_size = Vector2((card_w - 40.0) * 0.5, 38)
	copy_btn.pressed.connect(func():
		DisplayServer.clipboard_set(text_box.text)
		AudioManager.play_sfx("click")
		copy_btn.text = "COPIED!"
		var tw = create_tween()
		tw.tween_interval(1.5)
		tw.tween_callback(func():
			if is_instance_valid(copy_btn):
				copy_btn.text = "COPY"
		)
	)
	btn_row_top.add_child(copy_btn)
	
	var apply_btn = UIHelper.create_bubbly_button("APPLY TO SCREEN", Color(0.18, 0.52, 0.88))
	apply_btn.custom_minimum_size = Vector2((card_w - 40.0) * 0.5, 38)
	apply_btn.pressed.connect(func():
		AudioManager.play_sfx("click")
		_apply_coords_from_text(text_box.text)
		apply_btn.text = "APPLIED!"
		var tw = create_tween()
		tw.tween_interval(1.5)
		tw.tween_callback(func():
			if is_instance_valid(apply_btn):
				apply_btn.text = "APPLY TO SCREEN"
		)
	)
	btn_row_top.add_child(apply_btn)
	
	var btn_row = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 8)
	vbox.add_child(btn_row)
	
	var reset_btn = UIHelper.create_bubbly_button("RESET DEFAULTS", Color(0.85, 0.40, 0.40))
	reset_btn.custom_minimum_size = Vector2((card_w - 40.0) * 0.5, 38)
	reset_btn.pressed.connect(func():
		AudioManager.play_sfx("click")
		custom_mascot_pos = Vector2.ZERO
		custom_char_pos = Vector2.ZERO
		custom_bubble_pos = Vector2.ZERO
		custom_brush_path.clear()
		if path_canvas and is_instance_valid(path_canvas):
			path_canvas.queue_redraw()
		_relayout()
		text_box.text = _format_tuning_coords()
	)
	btn_row.add_child(reset_btn)
	
	var close_btn = UIHelper.create_bubbly_button("CLOSE", UIHelper.SOFT_BLUE)
	close_btn.custom_minimum_size = Vector2((card_w - 40.0) * 0.5, 38)
	close_btn.pressed.connect(func():
		AudioManager.play_sfx("click")
		coords_popup_modal.queue_free()
		coords_popup_modal = null
	)
	btn_row.add_child(close_btn)

func _build_ui():
	# 1. Bathroom Background (Raised slightly to lift the floor tiles)
	bg = TextureRect.new()
	bg.name = "BathroomBackground"
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.texture = UIHelper.load_texture_safe("res://assets/images/brushing/brushing_bathroom_bg.jpg")
	bg.flip_h = true
	add_child(bg)
	
	# 2. Top Status Bar
	top_bar_rect = TextureRect.new()
	top_bar_rect.name = "TopStatusBar"
	top_bar_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	top_bar_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	top_bar_rect.texture = UIHelper.load_texture_safe("res://assets/images/brushing/brushingpagestatusbar.png")
	add_child(top_bar_rect)
	
	var p = GameState.get_active_profile()
	var coins = p.get("coins", 0)
	var points = p.get("points", 0)
	live_coins = int(round(float(coins)))
	live_points = int(round(float(points)))
	var cur_node = int(p.get("currentNode", 1))
	var day = GameState.day_for_node(cur_node)
	
	coin_lbl = Label.new()
	coin_lbl.text = str(live_coins)
	coin_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coin_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(coin_lbl, 15, Color.WHITE, true)
	top_bar_rect.add_child(coin_lbl)
	
	pt_lbl = Label.new()
	pt_lbl.text = str(live_points)
	pt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pt_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(pt_lbl, 15, Color.WHITE, true)
	top_bar_rect.add_child(pt_lbl)
	
	day_lbl = Label.new()
	day_lbl.text = "DAY %d" % day
	day_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	day_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(day_lbl, 14, Color.WHITE, true)
	top_bar_rect.add_child(day_lbl)
	
	reward_flyers_layer = Control.new()
	reward_flyers_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	reward_flyers_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reward_flyers_layer.z_index = 110
	add_child(reward_flyers_layer)
	
	# 3. Capsule Timer ("2:00")
	timer_capsule = Panel.new()
	timer_capsule.name = "TimerCapsule"
	var capsule_style = UIHelper.create_bubbly_panel(28, Color(1, 1, 1, 0.94), Color(0.70, 0.88, 1.0, 0.9), 3)
	timer_capsule.add_theme_stylebox_override("panel", capsule_style)
	add_child(timer_capsule)
	
	time_label = Label.new()
	time_label.anchors_preset = Control.PRESET_FULL_RECT
	time_label.text = "2:00"
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	time_label.add_theme_color_override("font_color", Color(0.18, 0.44, 0.80))
	time_label.add_theme_color_override("font_outline_color", Color.WHITE)
	time_label.add_theme_constant_override("outline_size", 8)
	time_label.add_theme_color_override("font_shadow_color", Color(0.10, 0.28, 0.55, 0.40))
	time_label.add_theme_constant_override("shadow_offset_x", 2)
	time_label.add_theme_constant_override("shadow_offset_y", 3)
	time_label.add_theme_font_size_override("font_size", 34)
	timer_capsule.add_child(time_label)
	
	# 4. Center Mouth Card
	mouth_card = Panel.new()
	mouth_card.name = "MouthCard"
	var mouth_card_style = UIHelper.create_bubbly_panel(28, Color.WHITE, Color(0.88, 0.93, 0.98, 0.95), 3)
	mouth_card.add_theme_stylebox_override("panel", mouth_card_style)
	add_child(mouth_card)
	
	base_mouth = TextureRect.new()
	base_mouth.anchors_preset = Control.PRESET_FULL_RECT
	base_mouth.offset_left = 10
	base_mouth.offset_right = -10
	base_mouth.offset_top = 10
	base_mouth.offset_bottom = -10
	base_mouth.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	base_mouth.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	base_mouth.texture = UIHelper.load_texture_safe("res://assets/images/brushing/brushingpagemouth.png")
	mouth_card.add_child(base_mouth)
	
	# 4 Layered Quadrant Overlays
	quadrant_rects.clear()
	for i in range(QUADRANTS.size()):
		var q_rect = TextureRect.new()
		q_rect.anchors_preset = Control.PRESET_FULL_RECT
		q_rect.offset_left = 10
		q_rect.offset_right = -10
		q_rect.offset_top = 10
		q_rect.offset_bottom = -10
		q_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		q_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		q_rect.texture = UIHelper.load_texture_safe(QUADRANTS[i]["tex"])
		q_rect.modulate.a = 0.0
		q_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mouth_card.add_child(q_rect)
		quadrant_rects.append(q_rect)
		
	# Plaque Germs on Teeth
	_spawn_plaque_germs()
		
	# White flash overlay on mouth card
	flash_overlay = ColorRect.new()
	flash_overlay.anchors_preset = Control.PRESET_FULL_RECT
	flash_overlay.color = Color(1, 1, 1, 0.0)
	flash_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mouth_card.add_child(flash_overlay)
	
	# Unlocked Toothbrush Weapon
	brush_icon = WeaponToothbrush.new()
	brush_icon.visible = false
	brush_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mouth_card.add_child(brush_icon)
	
	# Path Canvas (for custom path drawing)
	path_canvas = BrushPathCanvas.new()
	path_canvas.host = self
	path_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	path_canvas.anchor_right = 1.0
	path_canvas.anchor_bottom = 1.0
	path_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	path_canvas.z_index = 80
	mouth_card.add_child(path_canvas)
	_setup_path_drawing_input(path_canvas)
	
	# 5. User Avatar & Speech Bubble (Sir Crown Removed)
	mascot_rect = TextureRect.new()
	mascot_rect.name = "SirCrown"
	mascot_rect.visible = false
	add_child(mascot_rect)
	
	char_rect = TextureRect.new()
	char_rect.name = "Avatar"
	char_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	char_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var av_id = str(p.get("avatar", "chip")).to_lower().strip_edges()
	char_rect.texture = UIHelper.get_char_texture(av_id, false)
	# Blaze, Sparkette, Penelope, Spark already face/point right naturally toward the speech bubble
	if av_id in ["chip", "dash", "chef", "sircrown", "crown"]:
		char_rect.flip_h = true
	else:
		char_rect.flip_h = false
	add_child(char_rect)
	_setup_draggable(char_rect, "char")

	
	# Speech Bubble (Larger with Tail towards Avatar)
	speech_bubble = TextureRect.new()
	speech_bubble.name = "SpeechBubble"
	speech_bubble.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	speech_bubble.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var bubble_tex = UIHelper.load_texture_safe("res://assets/images/brushing/speech_bubble.png")
	if not bubble_tex:
		bubble_tex = UIHelper.load_texture_safe("res://assets/images/brushing/speech_bubble_right_tail.png")
	speech_bubble.texture = bubble_tex
	speech_bubble.flip_h = false
	speech_bubble.size = Vector2(161, 67)
	add_child(speech_bubble)
	_setup_draggable(speech_bubble, "bubble")

	bubble_label = Label.new()
	bubble_label.position = Vector2(13, 7)
	bubble_label.size = Vector2(136, 53)
	bubble_label.text = "Ready to scrub\nthat plaque away?\nHit START!"
	bubble_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bubble_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bubble_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bubble_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIHelper.apply_bubbly_label(bubble_label, 12, Color(0.10, 0.30, 0.55), true)
	speech_bubble.add_child(bubble_label)

	
	# 6. Pause Dim Overlay
	pause_dim_overlay = ColorRect.new()
	pause_dim_overlay.anchors_preset = Control.PRESET_FULL_RECT
	pause_dim_overlay.color = Color(0, 0, 0, 0.40)
	pause_dim_overlay.visible = false
	pause_dim_overlay.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(pause_dim_overlay)
	
	# 7. Pre-brush Controls (Floor Area)
	pre_brush_controls = Control.new()
	pre_brush_controls.anchors_preset = Control.PRESET_FULL_RECT
	pre_brush_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pre_brush_controls)
	
	back_btn = UIHelper.create_image_button("res://assets/images/shop/blue_back_button.png", Vector2(108, 46))
	back_btn.pressed.connect(func(): quit_requested.emit())
	pre_brush_controls.add_child(back_btn)
	
	start_btn = UIHelper.create_image_button("res://assets/images/brushing/start_brushing_button.png", Vector2(230, 76))
	start_btn.pressed.connect(_on_start_pressed)
	pre_brush_controls.add_child(start_btn)
	
	# 8. Active-brush Controls (Floor Area)
	active_brush_controls = Control.new()
	active_brush_controls.anchors_preset = Control.PRESET_FULL_RECT
	active_brush_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	active_brush_controls.visible = false
	add_child(active_brush_controls)
	
	pb_root = Control.new()
	active_brush_controls.add_child(pb_root)
	
	progress_bar = ProgressBar.new()
	progress_bar.max_value = 120
	progress_bar.value = 0
	progress_bar.show_percentage = false
	var pb_bg = StyleBoxFlat.new()
	pb_bg.bg_color = Color(0.68, 0.88, 0.98, 0.95)
	pb_bg.border_color = Color.WHITE
	pb_bg.set_border_width_all(2)
	pb_bg.set_corner_radius_all(9)
	progress_bar.add_theme_stylebox_override("background", pb_bg)
	var pb_fill = StyleBoxFlat.new()
	pb_fill.bg_color = Color(1.0, 0.62, 0.15)
	pb_fill.set_corner_radius_all(9)
	progress_bar.add_theme_stylebox_override("fill", pb_fill)
	pb_root.add_child(progress_bar)
	
	progress_badge = TextureRect.new()
	progress_badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	progress_badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	progress_badge.texture = UIHelper.load_texture_safe("res://assets/images/brushing/brushingpageprogressbarbadge.png")
	active_brush_controls.add_child(progress_badge)
	
	# Top Right Circular Blue Pause Button (opens pause menu)
	pause_btn = UIHelper.create_circular_pause_button(Vector2(46, 46))
	pause_btn.z_index = 100
	pause_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_btn.pressed.connect(_on_pause_pressed)
	active_brush_controls.add_child(pause_btn)
	
	# Timer
	timer = Timer.new()
	timer.wait_time = 1.0
	timer.timeout.connect(_on_tick)
	add_child(timer)

func _relayout():
	var safe_sz = UIHelper.get_viewport_safe_size(self)
	var cur_w = safe_sz.x
	var cur_h = safe_sz.y
	var cx = cur_w * 0.5
	var is_tablet = cur_w >= 600.0
	
	# 1. Bathroom Background (anchored cleanly across full viewport)
	if bg:
		var bg_y_offset = -round(cur_h * 0.04)
		# The page fills the whole screen (behind the notch and home indicator)
		bg.position = Vector2(0, bg_y_offset)
		bg.size = Vector2(cur_w, cur_h * 1.06)
		
	# 2. Top Status Bar (Centered across top width)
	var bar_w = min(cur_w - 24.0, 400.0) if not is_tablet else 440.0
	var bar_h = 56.0 if not is_tablet else 64.0
	if top_bar_rect:
		if top_bar_rect.texture:
			var tw = float(top_bar_rect.texture.get_width())
			var th = float(top_bar_rect.texture.get_height())
			if tw > 0.0:
				bar_h = bar_w * (th / tw)
		# Stats bar spans the top centre, so it drops below the notch on iPhone
		top_bar_rect.position = Vector2((cur_w - bar_w) * 0.5, max(8.0 if not is_tablet else 12.0, UIHelper.safe_top + 2.0))
		top_bar_rect.size = Vector2(bar_w, bar_h)
		
		# Percentage-based alignments matching React / Godot mockup
		if coin_lbl:
			var c_w = 64.0
			var c_h = 24.0
			coin_lbl.size = Vector2(c_w, c_h)
			coin_lbl.position = Vector2(bar_w * 0.22 - c_w * 0.5, bar_h * 0.50 - c_h * 0.5)
			coin_lbl.pivot_offset = Vector2(c_w * 0.5, c_h * 0.5)
		if pt_lbl:
			var p_w = 64.0
			var p_h = 24.0
			pt_lbl.size = Vector2(p_w, p_h)
			pt_lbl.position = Vector2(bar_w * 0.54 - p_w * 0.5, bar_h * 0.50 - p_h * 0.5)
			pt_lbl.pivot_offset = Vector2(p_w * 0.5, p_h * 0.5)
		if day_lbl:
			var d_w = 84.0
			var d_h = 24.0
			day_lbl.size = Vector2(d_w, d_h)
			day_lbl.position = Vector2(bar_w * 0.86 - d_w * 0.5, bar_h * 0.50 - d_h * 0.5)
			day_lbl.pivot_offset = Vector2(d_w * 0.5, d_h * 0.5)
		
	# 3. Timer Capsule ("2:00")
	var cap_w = 170.0 if not is_tablet else 200.0
	var cap_h = 52.0 if not is_tablet else 60.0
	var cap_y = (top_bar_rect.position.y + bar_h + 8.0) if top_bar_rect else 72.0
	if timer_capsule:
		timer_capsule.position = Vector2((cur_w - cap_w) * 0.5, cap_y)
		timer_capsule.size = Vector2(cap_w, cap_h)
		if time_label:
			time_label.position = Vector2.ZERO
			time_label.size = Vector2(cap_w, cap_h)
			time_label.add_theme_font_size_override("font_size", 34 if not is_tablet else 40)
		
	# 4. Mouth Card (Enlarged sizing for clear tooth view & accurate bacteria placement)
	if mouth_card:
		var mouth_sz = clampf(cur_w * 0.73, 310.0, 335.0) if not is_tablet else 380.0
		var mouth_y = cap_y + cap_h + 4.0
		mouth_card.position = Vector2((cur_w - mouth_sz) * 0.5, mouth_y)
		mouth_card.size = Vector2(mouth_sz, mouth_sz)
		
		var inner_mouth_sz = mouth_card.size - Vector2(20, 20)
		if base_mouth:
			base_mouth.position = Vector2(10, 10)
			base_mouth.size = inner_mouth_sz
		for q in quadrant_rects:
			q.position = Vector2(10, 10)
			q.size = inner_mouth_sz
		if flash_overlay:
			flash_overlay.position = Vector2.ZERO
			flash_overlay.size = mouth_card.size
			
		if path_canvas and is_instance_valid(path_canvas):
			path_canvas.position = Vector2.ZERO
			path_canvas.size = mouth_card.size
			path_canvas.queue_redraw()
			
		var scale_f = mouth_sz / 240.0
		for i in range(germs.size()):
			if is_instance_valid(germs[i]) and i < GERM_DATA.size():
				var d = GERM_DATA[i]
				var sz = d.get("size", 28.0) * scale_f
				var center_pos = d["pos"] * scale_f
				germs[i].custom_minimum_size = Vector2(sz, sz)
				germs[i].size = Vector2(sz, sz)
				germs[i].pivot_offset = Vector2(sz * 0.5, sz * 0.5)
				germs[i].position = center_pos - Vector2(sz * 0.5, sz * 0.5)
				if germs[i].has_node("BacteriaImg"):
					var b_img = germs[i].get_node("BacteriaImg")
					b_img.size = Vector2(sz, sz)
					b_img.custom_minimum_size = Vector2(sz, sz)
					b_img.pivot_offset = Vector2(sz * 0.5, sz * 0.5)
		
	# Sir Crown / mouth-card geometry (shared by the button row and the avatar+bubble block)
	# SirCrown-nobg.png is a 424x424 square; its visible art spans x 48..362 (after flip_h) and y 31..416.
	const CROWN_VIS_LEFT := 0.113
	const CROWN_VIS_RIGHT := 0.854
	const CROWN_VIS_TOP := 0.073
	const CROWN_VIS_BOTTOM := 0.981
	var is_sircrown = (GameState.get_avatar().to_lower().strip_edges() in ["sircrown", "crown"])
	var mc_bottom: float = (mouth_card.position.y + mouth_card.size.y) if mouth_card else cur_h - 396.0
	var crown_box: float = 0.0
	var crown_x: float = 0.0
	var crown_vis_right: float = 0.0
	if is_sircrown:
		# Much bigger Sir Crown: as tall as fits between the mouth card and the bottom of the screen
		var want_box: float = 300.0 if not is_tablet else 380.0
		var fit_box: float = (cur_h - 6.0 - (mc_bottom + 6.0)) / (CROWN_VIS_BOTTOM - CROWN_VIS_TOP)
		crown_box = maxf(150.0, minf(want_box, fit_box))
		crown_x = 8.0 - CROWN_VIS_LEFT * crown_box
		crown_vis_right = crown_x + CROWN_VIS_RIGHT * crown_box
	
	# 5. Bottom Pre-brush Controls (Grouped closely side-by-side, lifted up by 20px)
	var btn_y = cur_h - 98.0 if not is_tablet else cur_h - 110.0
	if pre_brush_controls:
		pre_brush_controls.z_index = 40
	
	var back_w = 108.0 if not is_tablet else 125.0
	var back_h = 46.0 if not is_tablet else 54.0
	var start_w = 230.0 if not is_tablet else 270.0
	var start_h = 76.0 if not is_tablet else 90.0
	var btn_gap = 12.0
	var total_btns_w = back_w + btn_gap + start_w
	var start_x = (cur_w - total_btns_w) * 0.5
	if is_sircrown:
		# Keep the buttons clear of the bigger Sir Crown
		start_x = minf(maxf(start_x, crown_vis_right + 8.0), cur_w - total_btns_w - 4.0)
	
	if back_btn:
		back_btn.position = Vector2(start_x, btn_y + (start_h - back_h) * 0.5)
		back_btn.size = Vector2(back_w, back_h)
		back_btn.custom_minimum_size = Vector2(back_w, back_h)
	if start_btn:
		start_btn.position = Vector2(start_x + back_w + btn_gap, btn_y)
		start_btn.size = Vector2(start_w, start_h)
		start_btn.custom_minimum_size = Vector2(start_w, start_h)
		start_btn.pivot_offset = Vector2(start_w * 0.5, start_h * 0.5)
		
	# 6. User Avatar & Speech Bubble
	var floor_y = cur_h - 76.0 if not is_tablet else cur_h - 90.0
	
	if mascot_rect:
		mascot_rect.visible = false
		
	var avatar_h: float
	var avatar_w: float
	var avatar_x: float
	var avatar_y: float
	if is_sircrown:
		# Sir Crown: big square sprite standing on the bottom of the screen
		avatar_w = crown_box
		avatar_h = crown_box
		avatar_x = crown_x
		avatar_y = cur_h - 6.0 - CROWN_VIS_BOTTOM * crown_box
	else:
		avatar_h = 165.0 if not is_tablet else 210.0
		avatar_w = avatar_h * (120.0 / 134.0)
		avatar_x = 4.0 if not is_tablet else cx - avatar_w - 70.0
		avatar_y = floor_y - avatar_h
	
	if char_rect:
		char_rect.visible = true
		char_rect.size = Vector2(avatar_w, avatar_h)
		if custom_char_pos != Vector2.ZERO:
			char_rect.position = custom_char_pos
		else:
			char_rect.position = Vector2(avatar_x, avatar_y)
		char_rect.scale = Vector2.ONE
		char_rect.pivot_offset = Vector2(avatar_w * 0.5, avatar_h)
		char_rect.z_index = 80
		
	# Speech bubble: fills all the free room between the mouth card and the button row,
	# keeps the artwork's own aspect ratio (tail bottom-left points at the avatar)
	if speech_bubble:
		var tex_aspect := 1.40
		if speech_bubble.texture and speech_bubble.texture.get_height() > 0:
			tex_aspect = float(speech_bubble.texture.get_width()) / float(speech_bubble.texture.get_height())
		var bubble_left: float = (crown_vis_right - 55.0) if is_sircrown else (avatar_x + avatar_w * 0.70)
		var bubble_top: float = mc_bottom + 2.0
		var bubble_bottom: float = btn_y - 2.0
		var bubble_h: float = maxf(110.0, bubble_bottom - bubble_top)
		var bubble_w: float = bubble_h * tex_aspect
		var bubble_max_w: float = cur_w - bubble_left - 6.0
		if bubble_w > bubble_max_w:
			bubble_w = bubble_max_w
			bubble_h = bubble_w / tex_aspect
		speech_bubble.size = Vector2(bubble_w, bubble_h)
		speech_bubble.flip_h = false
		if custom_bubble_pos != Vector2.ZERO:
			speech_bubble.position = custom_bubble_pos
		else:
			var bubble_x = clampf(bubble_left, 4.0, cur_w - bubble_w - 4.0)
			speech_bubble.position = Vector2(bubble_x, bubble_bottom - bubble_h)
		speech_bubble.z_index = 85
		if bubble_label:
			# Text area = the rounded body of the bubble artwork (excludes border and tail)
			bubble_label.position = Vector2(bubble_w * 0.07, bubble_h * 0.06)
			bubble_label.size = Vector2(bubble_w * 0.86, bubble_h * 0.64)
			bubble_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			UIHelper.apply_bubbly_label(bubble_label, 22 if not is_tablet else 26, Color(0.10, 0.30, 0.55), true)
			_bubble_fit_key = ""

		
	# 7. Active-brush Controls (Progress Bar at floor bottom)
	var pb_w = min(cur_w - 36.0, 390.0)
	var pb_x = (cur_w - pb_w) * 0.5
	var pb_y = cur_h - 48.0 if not is_tablet else cur_h - 58.0
	
	if pb_root:
		pb_root.position = Vector2(pb_x, pb_y)
		pb_root.size = Vector2(pb_w, 28)
		pb_root.z_index = 40
	if progress_bar:
		progress_bar.position = Vector2(38, 5)
		progress_bar.size = Vector2(pb_w - 44.0, 18)
	if progress_badge:
		progress_badge.position = Vector2(pb_x - 12.0, pb_y - 10.0)
		progress_badge.size = Vector2(46, 48)
		progress_badge.z_index = 45
		
	if active_brush_controls:
		active_brush_controls.position = Vector2.ZERO
		active_brush_controls.size = safe_sz

	# Top Right Circular Pause Button
	if pause_btn:
		pause_btn.position = Vector2(cur_w - 56.0, 12.0)
		pause_btn.size = Vector2(46, 46)
		pause_btn.z_index = 100
		
	# Active pause & modals repositioning
	if pause_modal and is_instance_valid(pause_modal):
		pause_modal.size = safe_sz
		for ch in pause_modal.get_children():
			if ch is Control:
				ch.size = safe_sz
	if confirmation_modal and is_instance_valid(confirmation_modal):
		confirmation_modal.size = safe_sz
		for ch in confirmation_modal.get_children():
			if ch is Control:
				ch.size = safe_sz
	if cheer_modal and is_instance_valid(cheer_modal):
		_relayout_cheer_modal(cur_w, cur_h)
	if coords_popup_modal and is_instance_valid(coords_popup_modal):
		coords_popup_modal.size = safe_sz
		for ch in coords_popup_modal.get_children():
			if ch is Control:
				ch.size = safe_sz

func _spawn_plaque_germs():
	for g in germs:
		if is_instance_valid(g):
			g.queue_free()
	germs.clear()
	
	var b_tex = _ensure_bacteria_texture()
	for d in GERM_DATA:
		var sz = d.get("size", 28.0)
		var germ = PlaqueGerm.new(d["quadrant"], sz, b_tex)
		germ.position = d["pos"] - Vector2(sz * 0.5, sz * 0.5)
		mouth_card.add_child(germ)
		germs.append(germ)

func _pop_germs_in_quadrant(q_idx: int):
	for g in germs:
		if is_instance_valid(g) and g.quadrant == q_idx and g.visible:
			var tw = create_tween()
			tw.tween_property(g, "scale", Vector2(1.35, 1.35), 0.12).set_trans(Tween.TRANS_BACK)
			tw.parallel().tween_property(g, "modulate:a", 0.0, 0.16)
			tw.finished.connect(func(): g.visible = false)

func _reset_plaque_germs():
	for g in germs:
		if is_instance_valid(g):
			g.visible = true
			g.scale = Vector2.ONE
			g.modulate.a = 1.0

func _start_mascot_idle_bob():
	# Characters are stationary per user requirement
	if mascot_rect:
		mascot_rect.scale = Vector2.ONE
	if char_rect:
		char_rect.scale = Vector2.ONE

func _set_pre_brush_state():
	is_brushing_active = false
	is_paused = false
	pause_dim_overlay.visible = false
	pre_brush_controls.visible = true
	active_brush_controls.visible = false
	
	if bg: bg.visible = true
	if top_bar_rect: top_bar_rect.visible = true
	if timer_capsule: timer_capsule.visible = true
	if mouth_card: mouth_card.visible = true
	if mascot_rect: mascot_rect.visible = false
	if char_rect: char_rect.visible = true
	if speech_bubble: speech_bubble.visible = true
	if tuning_bar: tuning_bar.visible = true
	
	if pause_modal and is_instance_valid(pause_modal):
		pause_modal.queue_free()
		pause_modal = null
	if confirmation_modal and is_instance_valid(confirmation_modal):
		confirmation_modal.queue_free()
		confirmation_modal = null
	if coords_popup_modal and is_instance_valid(coords_popup_modal):
		coords_popup_modal.queue_free()
		coords_popup_modal = null
	
	if base_mouth:
		base_mouth.visible = true
		base_mouth.modulate.a = 1.0
		
	current_quadrant_index = -1
	for q_rect in quadrant_rects:
		q_rect.visible = false
		q_rect.modulate.a = 0.0
		
	brush_icon.visible = false
	if brush_tween:
		brush_tween.kill()
		
	_reset_plaque_germs()
		
	bubble_label.text = "Ready to scrub\nthat plaque away?\nHit START!"
	total_seconds = 20 if GameState.dev_mode else 120
	time_left = total_seconds
	time_label.text = "2:00"
	progress_bar.max_value = total_seconds
	progress_bar.value = 0
	
	_start_start_btn_pulse()

func _start_start_btn_pulse():
	if start_btn_tween:
		start_btn_tween.kill()
	start_btn.pivot_offset = start_btn.size * 0.5
	start_btn_tween = create_tween().set_loops()
	start_btn_tween.tween_property(start_btn, "scale", Vector2(1.03, 1.03), 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	start_btn_tween.tween_property(start_btn, "scale", Vector2(1.0, 1.0), 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _on_start_pressed():
	if start_btn_tween:
		start_btn_tween.kill()
	start_btn.scale = Vector2.ONE
	
	AudioManager.play_sfx("pop")
	# The brushing song starts only now that the player pressed START
	AudioManager.play_screen_bgm("brushing")
	is_brushing_active = true
	is_paused = false
	brush_anim_time = 0.0
	pause_dim_overlay.visible = false
	pre_brush_controls.visible = false
	active_brush_controls.visible = true
	
	# Preload 3D combat assets in background during brushing timer
	GameState.preload_candy_crusade_in_background()
	
	total_seconds = 20 if GameState.dev_mode else 120
	time_left = total_seconds
	progress_bar.max_value = total_seconds
	progress_bar.value = 0
	_set_quadrant(0)
	timer.start()

func _on_tick():
	if is_paused:
		return
		
	time_left -= 1
	progress_bar.value = total_seconds - time_left
	
	var mins = time_left / 60
	var secs = time_left % 60
	time_label.text = "%d:%02d" % [mins, secs]
	
	# Alternating reward bursts: points and coins operate at separate times (never simultaneously)
	# Points: 1:45 (105s), 1:15 (75s), 0:45 (45s), 0:15 (15s)
	# Coins:  1:55 (115s), 1:30 (90s), 1:00 (60s), 0:30 (30s), 0:01 (1s)
	var points_times = [17, 12, 7, 2] if GameState.dev_mode else [105, 75, 45, 15]
	var coins_times = [19, 15, 10, 5, 1] if GameState.dev_mode else [115, 90, 60, 30, 1]
	if points_times.has(time_left):
		_trigger_reward_burst("star", 5)
	elif coins_times.has(time_left):
		_trigger_reward_burst("coin", 5)
	
	# Check active quadrant:
	var quad_dur = total_seconds / 4.0
	var elapsed = total_seconds - time_left
	var target_q = int(clamp(floor(elapsed / quad_dur), 0, 3))
		
	if target_q != current_quadrant_index and time_left > 0:
		_set_quadrant(target_q)
		
	if time_left <= 0:
		timer.stop()
		_on_brushing_complete()

func _set_quadrant(q_idx: int):
	var old_q = current_quadrant_index
	current_quadrant_index = q_idx
	var q_info = QUADRANTS[q_idx]
	
	if _quad_transition_tween and _quad_transition_tween.is_valid():
		_quad_transition_tween.kill()
	_quad_transition_tween = create_tween().set_parallel(true)
	
	# Seamless, zero-gap crossfade between mouth quadrants (no white flashes)
	var new_rect = quadrant_rects[q_idx] if q_idx < quadrant_rects.size() else null
	if new_rect:
		new_rect.visible = true
		_quad_transition_tween.tween_property(new_rect, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		
	if old_q >= 0 and old_q < quadrant_rects.size() and old_q != q_idx:
		var old_rect = quadrant_rects[old_q]
		var fade_tw = _quad_transition_tween.tween_property(old_rect, "modulate:a", 0.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		fade_tw.finished.connect(func():
			if is_instance_valid(old_rect) and current_quadrant_index != old_q:
				old_rect.visible = false
		)
	elif base_mouth and base_mouth.visible:
		var bm_tw = _quad_transition_tween.tween_property(base_mouth, "modulate:a", 0.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		bm_tw.finished.connect(func():
			if is_instance_valid(base_mouth):
				base_mouth.visible = false
		)
		
	for i in range(quadrant_rects.size()):
		if i != q_idx and i != old_q:
			quadrant_rects[i].visible = false
			quadrant_rects[i].modulate.a = 0.0
	
	# Audio chime & Spoken Voice Guide
	AudioManager.play_sfx("coin")

	var voice_prompt_text = q_info.get("voice_prompt", q_info["dialogue"])
	if DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		DisplayServer.tts_stop()
		# speak_tts dips the brushing song first so the spoken tip is easy to hear
		AudioManager.speak_tts(voice_prompt_text)
	else:
		# Fallback spoken notification
		AudioManager.play_sfx("brush_tick")
	
	# Update brush bristles direction (Q0 and Q1 are top teeth -> facing_up = true)
	var facing_up = (q_idx == 0 or q_idx == 1)
	if brush_icon.has_method("set_bristles_direction"):
		brush_icon.set_bristles_direction(facing_up)
	if brush_icon.has_method("_update_brush_texture"):
		brush_icon._update_brush_texture()
	brush_icon.visible = true
	
	# Speech bubble update & pop
	bubble_label.text = q_info["dialogue"]
	_pop_speech_bubble()

func _start_brush_anim(_base_pos: Vector2, facing_up: bool):
	if brush_icon.has_method("set_bristles_direction"):
		brush_icon.set_bristles_direction(facing_up)
	if brush_icon.has_method("_update_brush_texture"):
		brush_icon._update_brush_texture()
	brush_icon.visible = true

func _trigger_reward_burst(kind: String, count: int = 5):
	if not mouth_card or not is_instance_valid(mouth_card):
		return
	if not reward_flyers_layer or not is_instance_valid(reward_flyers_layer):
		return
		
	var start_pos = mouth_card.global_position + mouth_card.size * 0.5
	var target_label = coin_lbl if kind == "coin" else pt_lbl
	if not target_label or not is_instance_valid(target_label):
		return
		
	var target_pos = target_label.global_position + target_label.size * 0.5
	var tex = UIHelper.load_texture_safe(
		"res://assets/images/congratulations/gold_tooth_coin.png" if kind == "coin"
		else "res://assets/images/congratulations/purple_star_points.png"
	)
	if not tex:
		tex = UIHelper.load_texture_safe("res://assets/images/brushing/purple_star_points.png")
		
	for i in range(count):
		get_tree().create_timer(i * 0.10).timeout.connect(func():
			if not is_instance_valid(reward_flyers_layer) or not is_instance_valid(target_label):
				return
			var flyer = TextureRect.new()
			flyer.texture = tex
			flyer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			flyer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			flyer.size = Vector2(28, 28)
			flyer.pivot_offset = Vector2(14, 14)
			flyer.mouse_filter = Control.MOUSE_FILTER_IGNORE
			reward_flyers_layer.add_child(flyer)
			
			var sx = start_pos.x + randf_range(-20, 20)
			var sy = start_pos.y + randf_range(-15, 15)
			var tx = target_pos.x + randf_range(-8, 8)
			var ty = target_pos.y + randf_range(-6, 6)
			flyer.global_position = Vector2(sx, sy)
			
			var tw = flyer.create_tween()
			tw.tween_property(flyer, "global_position", Vector2(tx, ty), 1.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.parallel().tween_property(flyer, "scale", Vector2(0.5, 0.5), 1.15)
			tw.finished.connect(func():
				flyer.queue_free()
				AudioManager.play_sfx("coin")
				_pulse_target_counter(target_label)
				if kind == "coin":
					live_coins += 1
					if coin_lbl:
						coin_lbl.text = str(live_coins)
					var p = GameState.get_active_profile()
					GameState.update_active_profile({"coins": int(p.get("coins", 0)) + 1})
				else:
					live_points += 2
					if pt_lbl:
						pt_lbl.text = str(live_points)
					var p = GameState.get_active_profile()
					GameState.update_active_profile({"points": int(p.get("points", 0)) + 2})
			)
		)

func _pulse_target_counter(lbl: Label):
	if not lbl or not is_instance_valid(lbl):
		return
	var tw = lbl.create_tween()
	tw.tween_property(lbl, "scale", Vector2(1.35, 1.35), 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_SINE)

var _bubble_fit_key := ""

# Shrinks the speech-bubble text until it fits inside the bubble.
func _fit_bubble_text() -> void:
	if not bubble_label or not is_instance_valid(bubble_label) or not bubble_label.is_visible_in_tree():
		return
	var key := "%s|%s" % [bubble_label.text, bubble_label.size]
	if key == _bubble_fit_key:
		return
	_bubble_fit_key = key
	var font := bubble_label.get_theme_font("font")
	if not font:
		return
	var box := bubble_label.size - Vector2(16, 10)
	var max_fs: int = clampi(int(box.y / 2.6), 12, 44)
	var fs := max_fs
	while fs > 10:
		var sz := font.get_multiline_string_size(bubble_label.text, HORIZONTAL_ALIGNMENT_CENTER, box.x, fs)
		if sz.y <= box.y and sz.x <= box.x:
			break
		fs -= 1
	bubble_label.add_theme_font_size_override("font_size", fs)

func _pop_speech_bubble():
	speech_bubble.pivot_offset = speech_bubble.size * 0.5
	var tw = create_tween()
	tw.tween_property(speech_bubble, "scale", Vector2(1.08, 1.08), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(speech_bubble, "scale", Vector2(1.0, 1.0), 0.10).set_trans(Tween.TRANS_SINE)

func _on_dev_skip_pressed():
	AudioManager.play_sfx("click")
	if timer:
		timer.stop()
	GameState.push_toast("Dev Mode", "Brushing skipped via Dev Mode.", "", "green")
	_on_brushing_complete()

func _on_error_override_pressed():
	AudioManager.play_sfx("click")
	is_paused = true
	if timer:
		timer.stop()
	if brush_tween:
		brush_tween.pause()
	if brush_icon and is_instance_valid(brush_icon):
		brush_icon.visible = false
	
	UIHelper.show_parental_gate(self, func():
		GameState.push_toast("Parent Override", "Brushing session marked complete by parent.", "", "green")
		_on_brushing_complete()
	, func():
		is_paused = false
		if is_brushing_active:
			if timer:
				timer.start()
			if brush_tween:
				brush_tween.play()
			if brush_icon and is_instance_valid(brush_icon):
				brush_icon.visible = true
	, "PARENT OVERRIDE")

func _on_pause_pressed():
	AudioManager.play_sfx("click")
	is_paused = true
	if timer:
		timer.stop()
	if brush_tween:
		brush_tween.pause()
	brush_icon.visible = false
	bubble_label.text = "Paused!\nTake a\nbreather!"
	_pop_speech_bubble()
	_show_pause_menu()

func _restart_brushing():
	AudioManager.play_sfx("click")
	if pause_modal and is_instance_valid(pause_modal):
		pause_modal.queue_free()
		pause_modal = null
	if timer:
		timer.stop()
	if brush_tween:
		brush_tween.kill()
		
	is_brushing_active = true
	is_paused = false
	brush_anim_time = 0.0
	pause_dim_overlay.visible = false
	pre_brush_controls.visible = false
	active_brush_controls.visible = true
	
	total_seconds = 20 if GameState.dev_mode else 120
	time_left = total_seconds
	progress_bar.max_value = total_seconds
	progress_bar.value = 0
	_reset_plaque_germs()
	_set_quadrant(0)
	timer.start()

func _show_pause_menu():
	if pause_modal and is_instance_valid(pause_modal):
		pause_modal.queue_free()
		
	var safe_sz = UIHelper.get_viewport_safe_size(self)
	var dlg = UIHelper.create_modal_dialog(self, 100, Color(0.04, 0.12, 0.28, 0.75))
	pause_modal = dlg["overlay"]
	var center_cont = dlg["center"]
	
	var max_card_w = min(safe_sz.x - 40.0, (safe_sz.y - 40.0) / 1.50)
	var card_w = clamp(max_card_w, 260.0, 320.0)
	var modal_info = UIHelper.create_modal_card(card_w, "portrait")
	var card = modal_info["root"]
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	center_cont.add_child(card)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	modal_info["content"].add_child(vbox)
	
	# Title
	var title = Label.new()
	title.text = "BRUSHING PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(title, 22, Color.WHITE, true)
	title.add_theme_color_override("font_shadow_color", Color(0.12, 0.40, 0.70))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	vbox.add_child(title)
	
	var sub_lbl = Label.new()
	sub_lbl.text = "Take a quick breather!"
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(sub_lbl, 13, Color(0.88, 0.95, 1.0))
	vbox.add_child(sub_lbl)
	
	var btn_w = card_w - 44.0
	
	# 1. Resume Button
	var resume_btn = UIHelper.create_themed_button("resume", Vector2(btn_w, 50))
	if not resume_btn.texture_normal:
		resume_btn = UIHelper.create_bubbly_button("RESUME", UIHelper.VIBRANT_GREEN)
		resume_btn.custom_minimum_size = Vector2(btn_w, 48)
	resume_btn.pressed.connect(func():
		AudioManager.play_sfx("click")
		is_paused = false
		if timer:
			timer.start()
		if brush_tween:
			brush_tween.play()
		brush_icon.visible = true
		if pause_modal and is_instance_valid(pause_modal):
			pause_modal.queue_free()
			pause_modal = null
		if current_quadrant_index >= 0 and current_quadrant_index < QUADRANTS.size():
			bubble_label.text = QUADRANTS[current_quadrant_index]["dialogue"]
			_pop_speech_bubble()
	)
	vbox.add_child(resume_btn)
	
	# 2. Restart Button
	var restart_btn = UIHelper.create_themed_button("restart", Vector2(btn_w, 50))
	if not restart_btn.texture_normal:
		restart_btn = UIHelper.create_bubbly_button("RESTART", UIHelper.VIBRANT_ORANGE)
		restart_btn.custom_minimum_size = Vector2(btn_w, 48)
	restart_btn.pressed.connect(func():
		_restart_brushing()
	)
	vbox.add_child(restart_btn)
	
	# 3. Audio Settings Button
	var settings_btn = UIHelper.create_themed_button("audiosettings", Vector2(btn_w, 50))
	if not settings_btn.texture_normal:
		settings_btn = UIHelper.create_bubbly_button("AUDIO SETTINGS", Color(0.18, 0.44, 0.82))
		settings_btn.custom_minimum_size = Vector2(btn_w, 48)
	settings_btn.pressed.connect(func():
		AudioManager.play_sfx("click")
		_show_audio_settings_submodal()
	)
	vbox.add_child(settings_btn)
	
	# 4. Exit Game Button
	var exit_btn = UIHelper.create_themed_button("exitgame", Vector2(btn_w, 50))
	if not exit_btn.texture_normal:
		exit_btn = UIHelper.create_themed_button("quit brushing", Vector2(btn_w, 50))
	if not exit_btn.texture_normal:
		exit_btn = UIHelper.create_bubbly_button("EXIT GAME", UIHelper.VIBRANT_RED)
		exit_btn.custom_minimum_size = Vector2(btn_w, 48)
	exit_btn.pressed.connect(func():
		AudioManager.play_sfx("click")
		if pause_modal and is_instance_valid(pause_modal):
			pause_modal.queue_free()
			pause_modal = null
		_show_early_quit_modal()
	)
	vbox.add_child(exit_btn)
	
	# Pop-in animation
	var card_h = modal_info["height"] if modal_info.has("height") else card_w * 1.50
	card.pivot_offset = Vector2(card_w * 0.5, card_h * 0.5)
	card.scale = Vector2(0.85, 0.85)
	card.modulate.a = 0.0
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(card, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "modulate:a", 1.0, 0.18)

func _show_audio_settings_submodal():
	var parent_for_sub = pause_modal if (pause_modal and is_instance_valid(pause_modal)) else self
	var dlg = UIHelper.create_modal_dialog(parent_for_sub, 105, Color(0.02, 0.06, 0.16, 0.80))
	var sub_modal = dlg["overlay"]
	var center_cont = dlg["center"]
	
	var card = Panel.new()
	card.custom_minimum_size = Vector2(300, 240)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var card_style = UIHelper.create_bubbly_panel(26, Color.WHITE, UIHelper.SOFT_BLUE, 3)
	card.add_theme_stylebox_override("panel", card_style)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	center_cont.add_child(card)
	
	var vbox = VBoxContainer.new()
	vbox.anchors_preset = Control.PRESET_FULL_RECT
	vbox.offset_left = 20.0
	vbox.offset_right = -20.0
	vbox.offset_top = 18.0
	vbox.offset_bottom = -18.0
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	card.add_child(vbox)
	
	var title = Label.new()
	title.text = "Audio Settings"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(title, 20, UIHelper.DEEP_BLUE, true)
	vbox.add_child(title)
	
	var sound_row = HBoxContainer.new()
	sound_row.alignment = BoxContainer.ALIGNMENT_CENTER
	sound_row.add_theme_constant_override("separation", 16)
	
	var sound_lbl = Label.new()
	sound_lbl.text = "Sound:"
	UIHelper.apply_bubbly_label(sound_lbl, 16, UIHelper.DEEP_BLUE, true)
	sound_row.add_child(sound_lbl)
	
	var on_tex = UIHelper.get_button_texture("on")
	var off_tex = UIHelper.get_button_texture("off")
	
	var mute_btn = TextureButton.new()
	mute_btn.ignore_texture_size = true
	mute_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	mute_btn.custom_minimum_size = Vector2(64, 32)
	mute_btn.size = Vector2(64, 32)
	mute_btn.pivot_offset = Vector2(32, 16)
	mute_btn.focus_mode = Control.FOCUS_NONE
	mute_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	mute_btn.texture_normal = off_tex if AudioManager.is_muted else on_tex
	
	mute_btn.pressed.connect(func():
		AudioManager.play_sfx("click")
		var is_mut = AudioManager.toggle_mute()
		mute_btn.texture_normal = off_tex if is_mut else on_tex
	)
	sound_row.add_child(mute_btn)
	vbox.add_child(sound_row)
	
	var close_btn = UIHelper.create_themed_button("back", Vector2(250, 44))
	if not close_btn.texture_normal:
		close_btn = UIHelper.create_bubbly_button("BACK", UIHelper.SOFT_BLUE)
		close_btn.custom_minimum_size = Vector2(250, 42)
	close_btn.pressed.connect(func():
		AudioManager.play_sfx("click")
		sub_modal.queue_free()
	)
	vbox.add_child(close_btn)

func _show_early_quit_modal():
	is_paused = true
	if timer:
		timer.stop()
	if brush_tween:
		brush_tween.pause()
	brush_icon.visible = false
		
	if confirmation_modal and is_instance_valid(confirmation_modal):
		confirmation_modal.queue_free()
		
	var safe_sz = UIHelper.get_viewport_safe_size(self)
	var dlg = UIHelper.create_modal_dialog(self, 110, Color(0, 0, 0, 0.65))
	confirmation_modal = dlg["overlay"]
	var center_cont = dlg["center"]
	
	var card_w = clampf(safe_sz.x - 48.0, 300.0, 400.0)
	
	var card = Panel.new()
	# A Panel does not grow with its children, so give the white card a real height
	card.custom_minimum_size = Vector2(card_w, 260)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	card.add_theme_stylebox_override("panel", UIHelper.create_bubbly_panel(28, Color.WHITE, UIHelper.SOFT_BLUE, 3))
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	center_cont.add_child(card)
	
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	card.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 18)
	margin.add_child(vbox)
	
	var q_lbl = Label.new()
	q_lbl.text = "End early?"
	q_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIHelper.apply_bubbly_label(q_lbl, 26, UIHelper.DEEP_BLUE, true)
	vbox.add_child(q_lbl)
	
	var sub_lbl = Label.new()
	sub_lbl.text = "Are you sure? If you quit early, you won't earn today's rewards!"
	sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIHelper.apply_bubbly_label(sub_lbl, 15, Color(0.35, 0.45, 0.58))
	vbox.add_child(sub_lbl)
	
	var btn_row = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_row.add_theme_constant_override("separation", 16)
	vbox.add_child(btn_row)
	
	var btn_min_w = (card_w - 48.0 - 16.0) * 0.5
	
	var stay_btn = UIHelper.create_themed_button("keep going", Vector2(btn_min_w, 52))
	if not stay_btn.texture_normal:
		stay_btn = UIHelper.create_bubbly_button("KEEP GOING", UIHelper.VIBRANT_GREEN)
		stay_btn.custom_minimum_size = Vector2(btn_min_w, 52)
	stay_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stay_btn.pressed.connect(func():
		AudioManager.play_sfx("click")
		confirmation_modal.queue_free()
		is_paused = false
		if timer:
			timer.start()
		if brush_tween:
			brush_tween.play()
		brush_icon.visible = true
		if current_quadrant_index >= 0 and current_quadrant_index < QUADRANTS.size():
			bubble_label.text = QUADRANTS[current_quadrant_index]["dialogue"]
			_pop_speech_bubble()
	)
	btn_row.add_child(stay_btn)
	
	var quit_btn = UIHelper.create_themed_button("leave", Vector2(btn_min_w, 52))
	if not quit_btn.texture_normal:
		quit_btn = UIHelper.create_themed_button("quit brushing", Vector2(btn_min_w, 52))
	if not quit_btn.texture_normal:
		quit_btn = UIHelper.create_bubbly_button("LEAVE", UIHelper.VIBRANT_RED)
		quit_btn.custom_minimum_size = Vector2(btn_min_w, 52)
	quit_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quit_btn.pressed.connect(func():
		AudioManager.play_sfx("click")
		confirmation_modal.queue_free()
		GameState.complete_brushing(false)
		quit_requested.emit()
	)
	btn_row.add_child(quit_btn)

# Canonical Brushing Congratulations from src/lib/extras.tsx BrushCongrats
func _on_brushing_complete():
	AudioManager.play_sfx("cheer")
	
	var p = GameState.get_active_profile()
	var cur_node = int(p.get("currentNode", 0))
	var node_info = GameState.get_node_data(cur_node)
	var is_evening = (node_info.get("type", "") == "evening")
	var completed_day = node_info.get("day", 1)
	
	GameState.complete_brushing(true, is_evening)
	if is_evening and int(completed_day) == 28:
		# Day 28: Candy Crusade comes AFTER the night brush, so the node stays open
		GameState.set_node_stage(cur_node, 1)
	elif is_evening:
		GameState.finish_node(true)
	else:
		GameState.set_node_stage(cur_node, 1)

	# 1. Log brushing session habit metric (duration & morning/evening) to FirebaseManager
	FirebaseManager.record_brushing_session(120, not is_evening)
	
	# 2. Save challenge data locally and trigger background cloud sync
	FirebaseManager.save_challenge_data(GameState.get_progress_dict())
	
	if pause_modal and is_instance_valid(pause_modal):
		pause_modal.queue_free()
		pause_modal = null
	if confirmation_modal and is_instance_valid(confirmation_modal):
		confirmation_modal.queue_free()
		confirmation_modal = null
	if coords_popup_modal and is_instance_valid(coords_popup_modal):
		coords_popup_modal.queue_free()
		coords_popup_modal = null
		
	_show_brush_congrats_modal(p, is_evening, completed_day)

func _show_brush_congrats_modal(p: Dictionary, is_evening: bool, completed_day: int):
	if cheer_modal and is_instance_valid(cheer_modal):
		cheer_modal.queue_free()
		
	var safe_sz = UIHelper.get_viewport_safe_size(self)
	
	# Hide background brushing elements completely so the celebration wallpaper takes over the whole screen
	if bg: bg.visible = false
	if top_bar_rect: top_bar_rect.visible = false
	if timer_capsule: timer_capsule.visible = false
	if mouth_card: mouth_card.visible = false
	if mascot_rect: mascot_rect.visible = false
	if char_rect: char_rect.visible = false
	if speech_bubble: speech_bubble.visible = false
	if tuning_bar: tuning_bar.visible = false
	if pre_brush_controls: pre_brush_controls.visible = false
	if active_brush_controls: active_brush_controls.visible = false
	if pause_btn: pause_btn.visible = false
	
	cheer_modal = Control.new()
	cheer_modal.name = "CheerModal"
	cheer_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	cheer_modal.z_index = 150
	add_child(cheer_modal)
	
	# Solid base backdrop matching wallpaper red palette
	var base_bg = ColorRect.new()
	base_bg.name = "CheerBaseColor"
	base_bg.color = Color("#e24b4b")
	base_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	base_bg.anchor_left = 0.0
	base_bg.anchor_top = 0.0
	base_bg.anchor_right = 1.0
	base_bg.anchor_bottom = 1.0
	base_bg.offset_left = 0
	base_bg.offset_top = 0
	base_bg.offset_right = 0
	base_bg.offset_bottom = 0
	base_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cheer_modal.add_child(base_bg)
	
	# 1. Fullscreen Character Celebration Wallpaper Background (Edge-to-Edge Cover)
	var av_id = p.get("avatar", "chip")
	var bg_img = TextureRect.new()
	bg_img.name = "CelebrationWallpaper"
	var wallpaper_tex = UIHelper.get_finished_brushing_texture(av_id)
	bg_img.texture = wallpaper_tex
	bg_img.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_img.anchor_left = 0.0
	bg_img.anchor_top = 0.0
	bg_img.anchor_right = 1.0
	bg_img.anchor_bottom = 1.0
	bg_img.offset_left = 0
	bg_img.offset_top = 0
	bg_img.offset_right = 0
	bg_img.offset_bottom = 0
	bg_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cheer_modal.add_child(bg_img)
	
	# Fullscreen Confetti, Coins & Point Stars Explosion
	_spawn_celebration_burst(cheer_modal)
	
	# 2. Main Page UI Layer (z_index = 100 so it sits cleanly above wallpaper & burst effects)
	var ui_layer = Control.new()
	ui_layer.name = "CheerUILayer"
	ui_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_layer.anchor_left = 0.0
	ui_layer.anchor_top = 0.0
	ui_layer.anchor_right = 1.0
	ui_layer.anchor_bottom = 1.0
	ui_layer.offset_left = 0
	ui_layer.offset_top = 0
	ui_layer.offset_right = 0
	ui_layer.offset_bottom = 0
	ui_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.z_index = 100
	cheer_modal.add_child(ui_layer)
	
	# --- TOP: Celebration Header ---
	var top_vbox = VBoxContainer.new()
	top_vbox.name = "TopHeaderVBox"
	top_vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	top_vbox.add_theme_constant_override("separation", 8)
	top_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(top_vbox)
	
	var name_str = p.get("name", "CHAMPION").to_upper()
	var well_done = Label.new()
	well_done.name = "WellDoneLabel"
	well_done.text = "WELL DONE %s!" % name_str
	well_done.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	well_done.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	well_done.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIHelper.apply_bubbly_label(well_done, 36, Color.WHITE, true)
	well_done.add_theme_color_override("font_color", Color.WHITE)
	well_done.add_theme_color_override("font_outline_color", Color(0.10, 0.22, 0.52))
	well_done.add_theme_constant_override("outline_size", 10)
	well_done.add_theme_color_override("font_shadow_color", Color(0.04, 0.12, 0.30, 0.70))
	well_done.add_theme_constant_override("shadow_offset_x", 0)
	well_done.add_theme_constant_override("shadow_offset_y", 3)
	top_vbox.add_child(well_done)
	
	var sub_lbl = Label.new()
	sub_lbl.name = "SubTitleLabel"
	sub_lbl.text = "YOU BRUSHED FOR A FULL 2 MINUTES!"
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIHelper.apply_bubbly_label(sub_lbl, 18, Color.WHITE, true)
	sub_lbl.add_theme_color_override("font_color", Color.WHITE)
	sub_lbl.add_theme_color_override("font_outline_color", Color(0.10, 0.22, 0.52))
	sub_lbl.add_theme_constant_override("outline_size", 8)
	sub_lbl.add_theme_color_override("font_shadow_color", Color(0.04, 0.12, 0.30, 0.60))
	sub_lbl.add_theme_constant_override("shadow_offset_x", 0)
	sub_lbl.add_theme_constant_override("shadow_offset_y", 2)
	top_vbox.add_child(sub_lbl)
	
	# --- BOTTOM: Rewards & Action Button Container ---
	var bot_vbox = VBoxContainer.new()
	bot_vbox.name = "BottomControlsVBox"
	bot_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	bot_vbox.add_theme_constant_override("separation", 14)
	bot_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(bot_vbox)
	
	# Reward Pills Row
	var rew_row = HBoxContainer.new()
	rew_row.name = "RewardRow"
	rew_row.alignment = BoxContainer.ALIGNMENT_CENTER
	rew_row.add_theme_constant_override("separation", 12)
	rew_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bot_vbox.add_child(rew_row)
	
	var mult_active = p.get("multiplierActiveUntil", 0) > Time.get_unix_time_from_system()
	var coins_text = "100 Coins" if mult_active else "50 Coins"
	var coin_pill = _create_reward_pill("res://assets/images/congratulations/gold_tooth_coin.png", coins_text, Color(0.86, 0.55, 0.05))
	rew_row.add_child(coin_pill)
	
	var pt_pill = _create_reward_pill("res://assets/images/congratulations/purple_star_points.png", "100 Points", Color(0.58, 0.28, 0.82))
	rew_row.add_child(pt_pill)
	
	var fact_pill: Control = null
	if not is_evening:
		fact_pill = _create_reward_pill("res://assets/images/journal/magnifying_glass.png", "1 Fact", Color(0.18, 0.48, 0.80))
		rew_row.add_child(fact_pill)
		
	# Action Button
	var btn_center = CenterContainer.new()
	btn_center.name = "ActionBtnCenter"
	bot_vbox.add_child(btn_center)
	
	if is_evening:
		var review_btn = UIHelper.create_themed_button("reviewfact", Vector2(290, 62))
		if not review_btn.texture_normal:
			review_btn = UIHelper.create_bubbly_button("REVIEW FACT", UIHelper.VIBRANT_GREEN)
			review_btn.custom_minimum_size = Vector2(290, 62)
		review_btn.pivot_offset = Vector2(145, 31)
		var r_tw = review_btn.create_tween().set_loops()
		r_tw.tween_property(review_btn, "scale", Vector2(1.03, 1.03), 0.6).set_trans(Tween.TRANS_SINE)
		r_tw.tween_property(review_btn, "scale", Vector2(1.0, 1.0), 0.6).set_trans(Tween.TRANS_SINE)
		
		review_btn.pressed.connect(func():
			AudioManager.play_sfx("coin")
			cheer_modal.queue_free()
			review_fact_pressed.emit()
			brushing_completed.emit()
		)
		btn_center.add_child(review_btn)
	else:
		var fact_btn = UIHelper.create_themed_button("learnnewfact", Vector2(290, 62))
		if not fact_btn.texture_normal:
			fact_btn = UIHelper.create_bubbly_button("LEARN NEW FACT", UIHelper.VIBRANT_GREEN)
			fact_btn.custom_minimum_size = Vector2(290, 62)
		fact_btn.pivot_offset = Vector2(145, 31)
		
		var cl_tw = fact_btn.create_tween().set_loops()
		cl_tw.tween_property(fact_btn, "scale", Vector2(1.03, 1.03), 0.6).set_trans(Tween.TRANS_SINE)
		cl_tw.tween_property(fact_btn, "scale", Vector2(1.0, 1.0), 0.6).set_trans(Tween.TRANS_SINE)
		
		fact_btn.pressed.connect(func():
			AudioManager.play_sfx("coin")
			cheer_modal.queue_free()
			claim_rewards_pressed.emit(completed_day)
			brushing_completed.emit()
		)
		btn_center.add_child(fact_btn)
		
	# Initial positioning
	_relayout_cheer_modal(safe_sz.x, safe_sz.y)
		
	# Smooth page entrance animation
	cheer_modal.modulate.a = 0.0
	var page_tw = cheer_modal.create_tween()
	page_tw.tween_property(cheer_modal, "modulate:a", 1.0, 0.22)

func _relayout_cheer_modal(cur_w: float, cur_h: float):
	if not cheer_modal or not is_instance_valid(cheer_modal):
		return
	var safe_sz = Vector2(cur_w, cur_h)
	cheer_modal.position = Vector2.ZERO
	cheer_modal.size = safe_sz
	
	var base_bg = cheer_modal.get_node_or_null("CheerBaseColor") as Control
	if base_bg:
		base_bg.position = Vector2.ZERO
		base_bg.size = safe_sz
		
	var wallpaper = cheer_modal.get_node_or_null("CelebrationWallpaper") as TextureRect
	if wallpaper and wallpaper.texture:
		var tw = float(wallpaper.texture.get_width())
		var th = float(wallpaper.texture.get_height())
		if tw <= 0.0: tw = 768.0
		if th <= 0.0: th = 1344.0
		
		# Cover the entire screen dimensions with a 5% safety margin
		var scale_factor = maxf(cur_w / tw, cur_h / th) * 1.05
		var bg_w = tw * scale_factor
		var bg_h = th * scale_factor
		var bg_x = (cur_w - bg_w) * 0.5
		
		# Place character at the vertical middle height (cur_h * 0.58).
		# In finished_brushing artworks the character sits around y = th * 0.62.
		var bg_y = (cur_h * 0.58) - (th * 0.62 * scale_factor)
		
		# Clamping to ensure zero empty borders
		if bg_y > 0.0:
			bg_y = 0.0
		if bg_y + bg_h < cur_h:
			bg_y = cur_h - bg_h
			
		wallpaper.position = Vector2(bg_x, bg_y)
		wallpaper.size = Vector2(bg_w, bg_h)
		wallpaper.stretch_mode = TextureRect.STRETCH_SCALE
		
	var ui_layer = cheer_modal.get_node_or_null("CheerUILayer") as Control
	if ui_layer:
		ui_layer.position = Vector2.ZERO
		ui_layer.size = safe_sz
		
		var content_w = clampf(cur_w - 20.0, 300.0, 560.0)
		var is_tablet = cur_w >= 600.0
		
		var top_vbox = ui_layer.get_node_or_null("TopHeaderVBox") as Control
		if top_vbox:
			var top_y = max(14.0, cur_h * 0.03)
			top_vbox.position = Vector2((cur_w - content_w) * 0.5, top_y)
			top_vbox.size = Vector2(content_w, 180)
			top_vbox.custom_minimum_size = Vector2(content_w, 0)
			
			var well_done = top_vbox.get_node_or_null("WellDoneLabel") as Label
			if well_done:
				well_done.custom_minimum_size = Vector2(content_w, 0)
				var font_sz = clamp(int(cur_w * 0.088), 32, 44) if not is_tablet else 46
				well_done.add_theme_font_size_override("font_size", font_sz)
				well_done.add_theme_constant_override("outline_size", 10)
				
			var sub_lbl = top_vbox.get_node_or_null("SubTitleLabel") as Label
			if sub_lbl:
				sub_lbl.custom_minimum_size = Vector2(content_w, 0)
				var sub_font_sz = clamp(int(cur_w * 0.046), 16, 21) if not is_tablet else 22
				sub_lbl.add_theme_font_size_override("font_size", sub_font_sz)
				sub_lbl.add_theme_constant_override("outline_size", 8)
				
		var bot_vbox = ui_layer.get_node_or_null("BottomControlsVBox") as Control
		if bot_vbox:
			var bot_h = 160.0
			var bot_y = cur_h - bot_h - max(20.0, cur_h * 0.035)
			bot_vbox.position = Vector2((cur_w - content_w) * 0.5, bot_y)
			bot_vbox.size = Vector2(content_w, bot_h)
			bot_vbox.custom_minimum_size = Vector2(content_w, bot_h)

func _spawn_celebration_burst(parent: Control):
	var coin_tex = UIHelper.load_texture_safe("res://assets/images/congratulations/gold_tooth_coin.png")
	var star_tex = UIHelper.load_texture_safe("res://assets/images/congratulations/purple_star_points.png")
	var tooth_tex = UIHelper.load_texture_safe("res://assets/images/congratulations/plain_tooth_icon.png")
	var confetti_colors = [
		Color("#ff3366"), Color("#ffd23f"), Color("#33dd88"), Color("#33b5ff"), 
		Color("#b044ff"), Color("#ff8833"), Color("#ffffff"), Color("#ff77aa")
	]
	
	var burst_layer = Control.new()
	burst_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	burst_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	burst_layer.z_index = 80
	parent.add_child(burst_layer)
	
	var safe_sz = UIHelper.get_viewport_safe_size(self)
	var center = Vector2(safe_sz.x * 0.5, safe_sz.y * 0.45)
	
	# 1. Immediate Radial Burst of 75 items (Coins, Point Stars, Confetti)
	for i in range(75):
		var angle = randf_range(0, TAU)
		var speed = randf_range(160.0, max(safe_sz.x, safe_sz.y) * 0.75)
		var target_pos = center + Vector2(cos(angle) * speed, sin(angle) * speed + randf_range(20, 120))
		var roll = i % 5
		
		var node: Control
		if roll == 0 and coin_tex:
			var tr = TextureRect.new()
			tr.texture = coin_tex
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			var sz = randf_range(28, 38)
			tr.custom_minimum_size = Vector2(sz, sz)
			tr.size = Vector2(sz, sz)
			node = tr
		elif roll == 1 and star_tex:
			var tr = TextureRect.new()
			tr.texture = star_tex
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			var sz = randf_range(28, 38)
			tr.custom_minimum_size = Vector2(sz, sz)
			tr.size = Vector2(sz, sz)
			node = tr
		elif roll == 2 and tooth_tex:
			var tr = TextureRect.new()
			tr.texture = tooth_tex
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			var sz = randf_range(24, 32)
			tr.custom_minimum_size = Vector2(sz, sz)
			tr.size = Vector2(sz, sz)
			node = tr
		else:
			var cr = ColorRect.new()
			cr.color = confetti_colors[randi() % confetti_colors.size()]
			var cw = randf_range(10, 18)
			var ch = randf_range(6, 12)
			cr.custom_minimum_size = Vector2(cw, ch)
			cr.size = Vector2(cw, ch)
			node = cr
			
		node.position = center
		node.pivot_offset = node.size * 0.5
		node.rotation_degrees = randf_range(0, 360)
		node.scale = Vector2.ZERO
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		burst_layer.add_child(node)
		
		var delay = randf_range(0.0, 0.15)
		var dur = randf_range(1.2, 2.2)
		var tw = node.create_tween()
		tw.tween_interval(delay)
		tw.parallel().tween_property(node, "scale", Vector2.ONE * randf_range(0.9, 1.3), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(node, "position", target_pos, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(node, "rotation_degrees", node.rotation_degrees + randf_range(-540, 540), dur)
		tw.parallel().tween_property(node, "modulate:a", 0.0, dur * 0.45).set_delay(dur * 0.55)
		tw.finished.connect(func(): if is_instance_valid(node): node.queue_free())

	# 2. Raining Confetti & Coin Stream from top (40 cascading fluttering pieces)
	for j in range(40):
		var start_x = randf_range(10.0, safe_sz.x - 10.0)
		var start_y = randf_range(-50.0, -10.0)
		var end_y = safe_sz.y + randf_range(20.0, 60.0)
		var roll = j % 3
		
		var node: Control
		if roll == 0 and coin_tex and randf() > 0.4:
			var tr = TextureRect.new()
			tr.texture = coin_tex
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.custom_minimum_size = Vector2(24, 24)
			tr.size = Vector2(24, 24)
			node = tr
		elif roll == 1 and star_tex and randf() > 0.4:
			var tr = TextureRect.new()
			tr.texture = star_tex
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.custom_minimum_size = Vector2(24, 24)
			tr.size = Vector2(24, 24)
			node = tr
		else:
			var cr = ColorRect.new()
			cr.color = confetti_colors[randi() % confetti_colors.size()]
			var cw = randf_range(10, 16)
			var ch = randf_range(6, 10)
			cr.custom_minimum_size = Vector2(cw, ch)
			cr.size = Vector2(cw, ch)
			node = cr
			
		node.position = Vector2(start_x, start_y)
		node.pivot_offset = node.size * 0.5
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		burst_layer.add_child(node)
		
		var delay = randf_range(0.05, 0.6)
		var dur = randf_range(2.0, 3.5)
		var tw = node.create_tween()
		tw.tween_interval(delay)
		tw.parallel().tween_property(node, "position:y", end_y, dur).set_trans(Tween.TRANS_LINEAR)
		tw.parallel().tween_property(node, "position:x", start_x + randf_range(-45.0, 45.0), dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.parallel().tween_property(node, "rotation_degrees", randf_range(-360, 360), dur)
		tw.finished.connect(func(): if is_instance_valid(node): node.queue_free())

func _create_reward_pill(icon_path: String, text: String, text_color: Color = Color(0.12, 0.32, 0.58)) -> Control:
	var pill_w = 108.0 if text == "1 Fact" else 126.0
	return UIHelper.create_reward_badge(icon_path, text, text_color, pill_w, 42.0)

