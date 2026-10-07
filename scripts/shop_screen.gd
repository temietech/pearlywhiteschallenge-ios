# scripts/shop_screen.gd
extends Control

signal back_pressed

var current_tab: String = "powerups" # "powerups", "ammo", "boosters"
var active_weapon_id: String = ""

var content_container: Control
var subtitle_panel: Panel
var subtitle_label: Label
var points_label: Label
var coins_label: Label

var tab_btn_powerups: TextureButton
var tab_btn_ammo: TextureButton
var tab_btn_boosters: TextureButton

var bg: TextureRect
var header_bar: Control
var pts_pill: Panel
var coins_pill: Panel
var title_img: TextureRect
var tab_container: Control
var tab_bg: Panel
var tab_hbox: HBoxContainer
var back_btn: TextureButton
var bottom_bar: Panel
var modal_layer: Control

const WEAPON_DEFS = [
	{
		"id": "brush",
		"name": "TOOTHBRUSH",
		"full_name": "Brush Boomerang",
		"display_title": "Brush\nBoomerang",
		"title_img": "res://assets/images/shop/brushboomerang_title.png",
		"level_titles": ["Brush Boomerang", "Gold Brush", "Bubble Brush"],
		"level_display_titles": ["Brush\nBoomerang", "Gold\nBrush", "Bubble\nBrush"],
		"level_title_imgs": [
			"res://assets/images/shop/brushboomerang_title.png",
			"res://assets/images/shop/brushboomerang_title.png",
			"res://assets/images/shop/bubblebrush_title.png"
		],
		"unlock_day": 1,
		"images": [
			"res://assets/images/shop/brushweapon_1.png",
			"res://assets/images/shop/brushweapon_2.png",
			"res://assets/images/shop/BubbleBrush.png"
		],
		"costs": [0, 350, 650],
		"day_reqs": [1, 3, 11]
	},
	{
		"id": "paste",
		"name": "TOOTHPASTE",
		"full_name": "Paste Pistol",
		"display_title": "Paste\nPistol",
		"title_img": "res://assets/images/shop/pastepistol_title.png",
		"level_titles": ["Paste Pistol", "Gold Paste Pistol", "Bubble Paste"],
		"level_display_titles": ["Paste\nPistol", "Gold\nPaste", "Bubble\nPaste"],
		"level_title_imgs": [
			"res://assets/images/shop/pastepistol_title.png",
			"res://assets/images/shop/pastepistol_title.png",
			"res://assets/images/shop/bubblepaste_title.png"
		],
		"unlock_day": 2,
		"images": [
			"res://assets/images/shop/Lvl1Paste.png",
			"res://assets/images/shop/PasteGold2.png",
			"res://assets/images/shop/BubblePaste.png"
		],
		"costs": [250, 550, 800],
		"day_reqs": [2, 9, 15]
	},
	{
		"id": "wash",
		"name": "MOUTHWASH",
		"full_name": "Mouthwash Blast",
		"display_title": "Mouthwash\nBlast",
		"title_img": "res://assets/images/shop/mouthwashblast_title.png",
		"level_titles": ["Mouthwash Blast", "Gold Mouthwash Blast", "Bubble Wash"],
		"level_display_titles": ["Mouthwash\nBlast", "Gold\nWash", "Bubble\nWash"],
		"level_title_imgs": [
			"res://assets/images/shop/mouthwashblast_title.png",
			"res://assets/images/shop/mouthwashblast_title.png",
			"res://assets/images/shop/bubblewash_title.png"
		],
		"unlock_day": 7,
		"images": [
			"res://assets/images/shop/MouthwashBlast-1.png",
			"res://assets/images/shop/WashGold2.png",
			"res://assets/images/shop/BubbleWash.png"
		],
		"costs": [450, 850, 1100],
		"day_reqs": [7, 17, 21]
	},
	{
		"id": "floss",
		"name": "FLOSS",
		"full_name": "Floss Lasso",
		"display_title": "Floss\nLasso",
		"title_img": "res://assets/images/shop/flosslasso_title.png",
		"level_titles": ["Floss Lasso", "Gold Floss Lasso", "Bubble Floss"],
		"level_display_titles": ["Floss\nLasso", "Gold\nFloss", "Bubble\nFloss"],
		"level_title_imgs": [
			"res://assets/images/shop/flosslasso_title.png",
			"res://assets/images/shop/flosslasso_title.png",
			"res://assets/images/shop/bubblefloss_title.png"
		],
		"unlock_day": 5,
		"images": [
			"res://assets/images/shop/flossweapon_1.png",
			"res://assets/images/shop/flossweapon_2.png",
			"res://assets/images/shop/flossweapon_3.png"
		],
		"costs": [400, 700, 950],
		"day_reqs": [5, 13, 19]
	}
]

static func get_weapon_title_img(w_def: Dictionary, lvl: int) -> String:
	var lvl_clamped = clampi(lvl, 1, 3)
	if w_def.has("level_title_imgs") and (w_def["level_title_imgs"] as Array).size() >= lvl_clamped:
		var img_path = str(w_def["level_title_imgs"][lvl_clamped - 1])
		if ResourceLoader.exists(img_path) or FileAccess.file_exists(ProjectSettings.globalize_path(img_path)):
			return img_path
	if lvl_clamped == 3:
		var w_id = str(w_def.get("id", ""))
		match w_id:
			"brush": return "res://assets/images/shop/bubblebrush_title.png"
			"paste": return "res://assets/images/shop/bubblepaste_title.png"
			"wash": return "res://assets/images/shop/bubblewash_title.png"
			"floss": return "res://assets/images/shop/bubblefloss_title.png"
	return str(w_def.get("title_img", ""))

static func get_weapon_display_title(w_def: Dictionary, lvl: int) -> String:
	var lvl_clamped = clampi(lvl, 1, 3)
	if w_def.has("level_display_titles") and (w_def["level_display_titles"] as Array).size() >= lvl_clamped:
		return str(w_def["level_display_titles"][lvl_clamped - 1])
	if lvl_clamped == 3:
		var w_id = str(w_def.get("id", ""))
		match w_id:
			"brush": return "Bubble\nBrush"
			"paste": return "Bubble\nPaste"
			"wash": return "Bubble\nWash"
			"floss": return "Bubble\nFloss"
	elif lvl_clamped == 2:
		var w_id = str(w_def.get("id", ""))
		match w_id:
			"brush": return "Gold\nBrush"
			"paste": return "Gold\nPaste"
			"wash": return "Gold\nWash"
			"floss": return "Gold\nFloss"
	return str(w_def.get("display_title", w_def.get("full_name", w_def.get("name", ""))))

static func get_weapon_full_name(w_def: Dictionary, lvl: int) -> String:
	var lvl_clamped = clampi(lvl, 1, 3)
	if w_def.has("level_titles") and (w_def["level_titles"] as Array).size() >= lvl_clamped:
		return str(w_def["level_titles"][lvl_clamped - 1])
	if lvl_clamped == 3:
		var w_id = str(w_def.get("id", ""))
		match w_id:
			"brush": return "Bubble Brush"
			"paste": return "Bubble Paste"
			"wash": return "Bubble Wash"
			"floss": return "Bubble Floss"
	elif lvl_clamped == 2:
		var w_id = str(w_def.get("id", ""))
		match w_id:
			"brush": return "Gold Brush"
			"paste": return "Gold Paste Pistol"
			"wash": return "Gold Mouthwash Blast"
			"floss": return "Gold Floss Lasso"
	return str(w_def.get("full_name", w_def.get("name", "")))

const AMMO_DEFS_BY_WEAPON = {
	"brush": {
		1: {
			"id": "brush_lvl1",
			"name": "BRUSH BOOMERANG PACKS (x4)",
			"subtitle": "Refill bristles for Brush Boomerang",
			"icon": "res://assets/images/shop/ToothbrushPack.png",
			"ammo_key": "brushes",
			"pack": 4,
			"cost": 50,
			"desc": "Brush Boomerang Packs",
			"weapon_name": "Brush Boomerang (LVL 1)"
		},
		2: {
			"id": "brush_lvl2",
			"name": "GOLD BRUSH BATTERIES (x1)",
			"subtitle": "Rechargeable power cells for Gold Brush",
			"icon": "res://assets/images/shop/Gold_Battery.png",
			"ammo_key": "battery",
			"pack": 1,
			"cost": 60,
			"desc": "Gold Brush Batteries",
			"weapon_name": "Gold Brush (LVL 2)"
		},
		3: {
			"id": "brush_lvl3",
			"name": "BUBBLE BRUSH BATTERIES (x1)",
			"subtitle": "Powerful fluoride-infused batteries for Bubble Brush",
			"icon": "res://assets/images/shop/Bubble_Battery.png",
			"ammo_key": "battery",
			"pack": 1,
			"cost": 80,
			"desc": "Bubble Brush Batteries",
			"weapon_name": "Bubble Brush (LVL 3)"
		}
	},
	"paste": {
		1: {
			"id": "paste_lvl1",
			"name": "PASTE PISTOL REFILLS (x3)",
			"subtitle": "Mint projectile charges for Paste Pistol",
			"icon": "res://assets/images/shop/Lvl1ToothpastePistoleProjectile.png",
			"ammo_key": "tubes",
			"pack": 3,
			"cost": 40,
			"desc": "Paste Pistol Refills",
			"weapon_name": "Paste Pistol (LVL 1)"
		},
		2: {
			"id": "paste_lvl2",
			"name": "GOLD PASTE REFILLS (x3)",
			"subtitle": "Heavy-duty gel charges for Gold Paste Pistol",
			"icon": "res://assets/images/shop/Lvl2ToothpastePistoleProjectile.png",
			"ammo_key": "tubes",
			"pack": 3,
			"cost": 60,
			"desc": "Gold Paste Refills",
			"weapon_name": "Gold Paste Pistol (LVL 2)"
		},
		3: {
			"id": "paste_lvl3",
			"name": "BUBBLE PASTE REFILLS (x3)",
			"subtitle": "Powerful fluoride-infused paste for Bubble Paste Pistol",
			"icon": "res://assets/images/shop/Lvl3ToothpastePistoleProjectile.png",
			"ammo_key": "tubes",
			"pack": 3,
			"cost": 80,
			"desc": "Bubble Paste Refills",
			"weapon_name": "Bubble Paste Pistol (LVL 3)"
		}
	},
	"wash": {
		1: {
			"id": "wash_lvl1",
			"name": "MOUTHWASH BLAST BOTTLES (x1)",
			"subtitle": "Antiseptic splash bottles for Mouthwash Blast",
			"icon": "res://assets/images/shop/MouthwashBlast-1.png",
			"ammo_key": "vials",
			"pack": 1,
			"cost": 75,
			"desc": "Mouthwash Blast Bottles",
			"weapon_name": "Mouthwash Blast (LVL 1)"
		},
		2: {
			"id": "wash_lvl2",
			"name": "GOLD MOUTHWASH BOTTLES (x2)",
			"subtitle": "Concentrated golden rinse for Gold Mouthwash Blast",
			"icon": "res://assets/images/shop/WashGold2.png",
			"ammo_key": "vials",
			"pack": 2,
			"cost": 110,
			"desc": "Gold Mouthwash Bottles",
			"weapon_name": "Gold Mouthwash Blast (LVL 2)"
		},
		3: {
			"id": "wash_lvl3",
			"name": "BUBBLE MOUTHWASH BOTTLES (x2)",
			"subtitle": "Powerful fluoride-infused rinse for Bubble Mouthwash Blast",
			"icon": "res://assets/images/shop/BubbleWash.png",
			"ammo_key": "vials",
			"pack": 2,
			"cost": 150,
			"desc": "Bubble Mouthwash Bottles",
			"weapon_name": "Bubble Mouthwash Blast (LVL 3)"
		}
	},
	"floss": {
		1: {
			"id": "floss_lvl1",
			"name": "FLOSS LASSO STRINGS (x2)",
			"subtitle": "Snaring string spools for Floss Lasso",
			"icon": "res://assets/images/shop/level1flosstring.png",
			"ammo_key": "spools",
			"pack": 2,
			"cost": 20,
			"desc": "Floss Lasso Strings",
			"weapon_name": "Floss Lasso (LVL 1)"
		},
		2: {
			"id": "floss_lvl2",
			"name": "GOLD LASSO STRINGS (x2)",
			"subtitle": "Reinforced gold strings for Gold Floss Lasso",
			"icon": "res://assets/images/shop/level2flosstring.png",
			"ammo_key": "spools",
			"pack": 2,
			"cost": 35,
			"desc": "Gold Lasso Strings",
			"weapon_name": "Gold Floss Lasso (LVL 2)"
		},
		3: {
			"id": "floss_lvl3",
			"name": "BUBBLE LASSO STRINGS (x2)",
			"subtitle": "Powerful fluoride-infused strings for Bubble Floss Lasso",
			"icon": "res://assets/images/shop/level3flosstring.png",
			"ammo_key": "spools",
			"pack": 2,
			"cost": 50,
			"desc": "Bubble Lasso Strings",
			"weapon_name": "Bubble Floss Lasso (LVL 3)"
		}
	}
}

static func normalize_weapon_id(raw_id: String) -> String:
	var s = raw_id.to_lower().strip_edges()
	if "wash" in s or "mouthwash" in s or "blast" in s:
		return "wash"
	elif "paste" in s or "toothpaste" in s or "pistol" in s:
		return "paste"
	elif "floss" in s or "lasso" in s:
		return "floss"
	elif "brush" in s or "toothbrush" in s or "boomerang" in s:
		return "brush"
	return "brush"

func setup_view(expand_weapon_id: String = "", tab_name: String = "powerups"):
	current_tab = tab_name
	if expand_weapon_id != "":
		active_weapon_id = normalize_weapon_id(expand_weapon_id)
	else:
		if tab_name == "powerups":
			active_weapon_id = ""
	if is_node_ready():
		_update_tab_buttons()
		_relayout()
		_refresh_data()

var _booster_live_timer: float = 0.0

func _process(delta: float):
	if current_tab == "boosters" and is_visible_in_tree() and modal_layer and modal_layer.get_child_count() == 0:
		_booster_live_timer += delta
		if _booster_live_timer >= 1.0:
			_booster_live_timer = 0.0
			_refresh_data()

func _ready():
	anchors_preset = Control.PRESET_FULL_RECT
	anchor_right = 1.0
	anchor_bottom = 1.0
	_build_ui()
	_relayout()
	_refresh_data()
	call_deferred("_check_new_weapon_unlocks")

func _check_new_weapon_unlocks():
	if active_weapon_id != "":
		return
	var p = GameState.get_active_profile()
	if p.is_empty():
		return
	var cur_node = int(p.get("currentNode", 1))
	var cur_day = max(GameState.get_unlocked_day(p), GameState.day_for_node(cur_node))
	var seen_unlocks = p.get("seen_weapon_unlocks", ["brush"])
	if typeof(seen_unlocks) != TYPE_ARRAY:
		seen_unlocks = ["brush"]
	else:
		seen_unlocks = seen_unlocks.duplicate()
		
	# Auto-mark any unlocks from days prior to cur_day as seen so we don't display stale old popups from past days
	for w_def in WEAPON_DEFS:
		var w_id = w_def["id"]
		var unlock_day = int(w_def.get("unlock_day", 1))
		if cur_day > unlock_day and not seen_unlocks.has(w_id):
			seen_unlocks.append(w_id)
			
	var weapon_to_show = {}
	for w_def in WEAPON_DEFS:
		var w_id = w_def["id"]
		var unlock_day = int(w_def.get("unlock_day", 1))
		if cur_day == unlock_day and not seen_unlocks.has(w_id):
			seen_unlocks.append(w_id)
			weapon_to_show = w_def
			break
			
	p["seen_weapon_unlocks"] = seen_unlocks
	GameState.save_game()
	
	if not weapon_to_show.is_empty():
		UIHelper.show_dental_item_unlocked_modal(self, weapon_to_show)

## Called by main.gd when the iPhone notch / home-indicator insets become known or change
func on_safe_area_changed():
	if is_node_ready():
		_relayout()
		if content_container:
			_refresh_data()

func _notification(what):
	if what == NOTIFICATION_RESIZED:
		if is_node_ready():
			_relayout()
			if content_container:
				_refresh_data()

# ==============================================================================
# SIZING RULE HELPERS (Rule 5)
# Every TextureRect and TextureButton strictly enforces aspect ratio preservation
# and explicit minimum sizing to prevent any stretching or distortion.
# ==============================================================================
func _create_aspect_rect(tex_path: String, min_sz: Vector2) -> TextureRect:
	var tex_rect = TextureRect.new()
	tex_rect.texture = UIHelper.load_texture_safe(tex_path)
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.custom_minimum_size = min_sz
	tex_rect.size = min_sz
	tex_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	return tex_rect

func _create_aspect_button(tex_path: String, min_sz: Vector2) -> TextureButton:
	var tb = TextureButton.new()
	tb.texture_normal = UIHelper.load_texture_safe(tex_path)
	tb.ignore_texture_size = true
	tb.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	tb.custom_minimum_size = min_sz
	tb.size = min_sz
	tb.focus_mode = Control.FOCUS_NONE
	tb.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	return tb

func _create_nine_patch(tex_path: String, margin_left: int = 24, margin_top: int = -1, margin_right: int = -1, margin_bottom: int = -1) -> NinePatchRect:
	var np = NinePatchRect.new()
	np.texture = UIHelper.load_texture_safe(tex_path)
	np.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var mt = margin_left if margin_top < 0 else margin_top
	var mr = margin_left if margin_right < 0 else margin_right
	var mb = mt if margin_bottom < 0 else margin_bottom
	np.patch_margin_left = margin_left
	np.patch_margin_top = mt
	np.patch_margin_right = mr
	np.patch_margin_bottom = mb
	return np

static var _cached_grayscale_mat: ShaderMaterial = null

func _get_grayscale_material() -> ShaderMaterial:
	if _cached_grayscale_mat and is_instance_valid(_cached_grayscale_mat):
		return _cached_grayscale_mat
		
	var shader = Shader.new()
	shader.code = """
shader_type canvas_item;

void fragment() {
	vec4 col = texture(TEXTURE, UV) * COLOR;
	float gray = dot(col.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(vec3(gray), col.a);
}
"""
	_cached_grayscale_mat = ShaderMaterial.new()
	_cached_grayscale_mat.shader = shader
	return _cached_grayscale_mat

# ==============================================================================
# RESPONSIVE LAYOUT
# ==============================================================================
func _relayout():
	var safe_sz = UIHelper.get_viewport_safe_size(self)
	var cur_w = safe_sz.x
	var cur_h = safe_sz.y
	size = safe_sz
	# The shop is laid out full-screen (main.gd does not inset it). Points & coins pills stay up in
	# the top corners beside the notch - like the map's avatar & settings buttons - while the
	# title and everything below it drop beneath the notch / Dynamic Island.
	var t: float = UIHelper.safe_top
	var b: float = UIHelper.safe_bottom
	
	if bg:
		bg.size = safe_sz
	if header_bar:
		header_bar.size = Vector2(cur_w, 76 + t)
	if pts_pill:
		pts_pill.position = Vector2(8, 10)
		pts_pill.size = Vector2(112, 44)
	if coins_pill:
		coins_pill.position = Vector2(cur_w - 120, 10)
		coins_pill.size = Vector2(112, 44)
	if title_img:
		# On notched phones the title sits just under the notch; otherwise it shares the pill row
		var title_y = (t + 2.0) if t > 1.0 else 4.0
		title_img.position = Vector2((cur_w - 216.0) * 0.5, title_y)
		title_img.size = Vector2(216, 60)
	if tab_container:
		var tab_w = min(cur_w - 32.0, 310.0)
		var tab_h = 40.0
		tab_container.position = Vector2((cur_w - tab_w) * 0.5, 72 + t)
		tab_container.size = Vector2(tab_w, tab_h)
		if tab_bg:
			tab_bg.size = Vector2(tab_w, tab_h)
		if tab_hbox:
			var slot_w = (tab_w - 6.0 - 4.0) / 3.0
			var slot_h = tab_h - 4.0
			tab_hbox.size = Vector2(tab_w - 6.0, slot_h)
			for btn in [tab_btn_powerups, tab_btn_ammo, tab_btn_boosters]:
				if btn and is_instance_valid(btn):
					var ssz = Vector2(slot_w, slot_h)
					btn.custom_minimum_size = ssz
					btn.size = ssz
	if subtitle_panel:
		var sub_w = min(cur_w - 20.0, 354.0)
		var sub_h = 32.0
		subtitle_panel.position = Vector2((cur_w - sub_w) * 0.5, 132 + t)
		subtitle_panel.size = Vector2(sub_w, sub_h)
		if subtitle_label and is_instance_valid(subtitle_label):
			subtitle_label.position = Vector2.ZERO
			subtitle_label.size = Vector2(sub_w, sub_h)
			subtitle_label.custom_minimum_size = Vector2(sub_w, sub_h)
			subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			subtitle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if content_container:
		var top_y = t + (126 if (current_tab == "powerups" and active_weapon_id != "") else (176 if (subtitle_panel and subtitle_panel.visible) else 134))
		content_container.position = Vector2(0, top_y)
		content_container.size = Vector2(cur_w, cur_h - top_y - 62 - b)
		
	if bottom_bar:
		# Bar reaches the very bottom edge; the back button stays above the home indicator
		bottom_bar.size = Vector2(cur_w, 56 + b)
		bottom_bar.position = Vector2(0, cur_h - 56 - b)
		
	if back_btn:
		back_btn.position = Vector2((cur_w - 116.0) * 0.5, cur_h - 49.0 - b)

# ==============================================================================
# UI INITIALIZATION
# ==============================================================================
func _build_ui():
	var safe_sz = UIHelper.get_viewport_safe_size(self)
	var cur_w = safe_sz.x
	var cur_h = safe_sz.y
	size = safe_sz
	
	# Sky gradient background
	bg = TextureRect.new()
	UIHelper.setup_fullscreen_bg(bg)
	bg.texture = UIHelper.create_sky_gradient_texture()
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(bg)
	
	# Header bar (Points Pill, PW Shop Title, Coins Pill)
	header_bar = Control.new()
	header_bar.position = Vector2(0, 0)
	header_bar.size = Vector2(cur_w, 76)
	add_child(header_bar)
	
	# Points Pill (Left)
	pts_pill = Panel.new()
	pts_pill.position = Vector2(8, 10)
	pts_pill.size = Vector2(112, 44)
	var pp_style = UIHelper.create_bubbly_panel(22, Color(0.18, 0.42, 0.70, 0.90), Color.WHITE, 2)
	pts_pill.add_theme_stylebox_override("panel", pp_style)
	header_bar.add_child(pts_pill)
	
	var star_ic = _create_aspect_rect("res://assets/images/cardmatchmini/purple_star_points.png", Vector2(34, 34))
	if not star_ic.texture:
		star_ic = _create_aspect_rect("res://assets/images/congratulations/purple_star_points.png", Vector2(34, 34))
	star_ic.position = Vector2(3, 5)
	pts_pill.add_child(star_ic)
	
	var pts_vbox = VBoxContainer.new()
	pts_vbox.position = Vector2(38, 2)
	pts_vbox.size = Vector2(70, 40)
	pts_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	pts_vbox.add_theme_constant_override("separation", -2)
	pts_pill.add_child(pts_vbox)
	
	var pts_tag = Label.new()
	pts_tag.text = "POINTS"
	pts_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(pts_tag, 9, Color(0.85, 0.92, 1.0), true)
	pts_vbox.add_child(pts_tag)
	
	points_label = Label.new()
	points_label.text = "0"
	points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(points_label, 15, Color.WHITE, true)
	pts_vbox.add_child(points_label)
	
	# Center Shop Title Image
	title_img = _create_aspect_rect("res://assets/images/shop/pwshoptitle.png", Vector2(216, 60))
	if not title_img.texture:
		title_img = _create_aspect_rect("res://assets/images/shop/pearly_whites_store.png", Vector2(216, 60))
	title_img.position = Vector2((cur_w - 216.0) * 0.5, 4)
	header_bar.add_child(title_img)
	
	# Coins Pill (Right)
	coins_pill = Panel.new()
	coins_pill.position = Vector2(cur_w - 120, 10)
	coins_pill.size = Vector2(112, 44)
	var cp_style = UIHelper.create_bubbly_panel(22, Color(0.18, 0.42, 0.70, 0.90), Color.WHITE, 2)
	coins_pill.add_theme_stylebox_override("panel", cp_style)
	header_bar.add_child(coins_pill)
	
	var coin_ic = _create_aspect_rect("res://assets/images/shop/gold_tooth_coin.png", Vector2(34, 34))
	coin_ic.position = Vector2(3, 5)
	coins_pill.add_child(coin_ic)
	
	var coins_vbox = VBoxContainer.new()
	coins_vbox.position = Vector2(38, 2)
	coins_vbox.size = Vector2(70, 40)
	coins_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	coins_vbox.add_theme_constant_override("separation", -2)
	coins_pill.add_child(coins_vbox)
	
	var coins_tag = Label.new()
	coins_tag.text = "COINS"
	coins_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(coins_tag, 9, Color(0.85, 0.92, 1.0), true)
	coins_vbox.add_child(coins_tag)
	
	coins_label = Label.new()
	coins_label.text = "0"
	coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(coins_label, 15, Color.WHITE, true)
	coins_vbox.add_child(coins_label)
	
	# ==========================================================================
	# 1. TAB BAR SETUP (POWER-UPS | AMMO | BOOSTERS)
	# Container: HBoxContainer inside a soft blue backing pill container
	# Nodes: Image assets buttons (powerupsbtn.png, ammobtn.png, boostersbtn.png)
	# Each button has its own dedicated backing panel and sits inside.
	# ==========================================================================
	# 3-Segment Image Tab Buttons: POWER-UPS | AMMO | BOOSTERS
	var tab_w = min(cur_w - 32.0, 310.0)
	var tab_h = 40.0
	tab_container = Control.new()
	tab_container.position = Vector2((cur_w - tab_w) * 0.5, 72)
	tab_container.size = Vector2(tab_w, tab_h)
	add_child(tab_container)
	
	tab_bg = Panel.new()
	tab_bg.size = Vector2(tab_w, tab_h)
	tab_bg.position = Vector2.ZERO
	tab_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tbg_style = UIHelper.create_bubbly_panel(20, Color(0.14, 0.38, 0.68, 0.50), Color(0.65, 0.85, 1.0, 0.35), 1.5)
	tab_bg.add_theme_stylebox_override("panel", tbg_style)
	tab_container.add_child(tab_bg)
	
	tab_hbox = HBoxContainer.new()
	tab_hbox.position = Vector2(3, 2)
	tab_hbox.size = Vector2(tab_w - 6.0, tab_h - 4.0)
	tab_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	tab_hbox.add_theme_constant_override("separation", 2)
	tab_container.add_child(tab_hbox)
	
	var slot_w = (tab_w - 6.0 - 4.0) / 3.0
	var slot_sz = Vector2(slot_w, tab_h - 4.0)
	
	tab_btn_powerups = _create_image_tab_button("res://assets/images/shop/powerupsbtn.png", "powerups", slot_sz)
	tab_hbox.add_child(tab_btn_powerups)
	
	tab_btn_ammo = _create_image_tab_button("res://assets/images/shop/ammobtn.png", "ammo", slot_sz)
	tab_hbox.add_child(tab_btn_ammo)
	
	tab_btn_boosters = _create_image_tab_button("res://assets/images/shop/boostersbtn.png", "boosters", slot_sz)
	tab_hbox.add_child(tab_btn_boosters)
	
	# Subtitle Banner with backing panel for high contrast readability
	var sub_w = min(cur_w - 20.0, 354.0)
	var sub_h = 32.0
	subtitle_panel = Panel.new()
	subtitle_panel.position = Vector2((cur_w - sub_w) * 0.5, 132)
	subtitle_panel.size = Vector2(sub_w, sub_h)
	subtitle_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sub_style = UIHelper.create_bubbly_panel(16, Color(0.06, 0.20, 0.44, 0.95), Color(1.0, 1.0, 1.0, 0.9), 1.5)
	subtitle_panel.add_theme_stylebox_override("panel", sub_style)
	add_child(subtitle_panel)
	
	subtitle_label = Label.new()
	subtitle_label.position = Vector2.ZERO
	subtitle_label.size = Vector2(sub_w, sub_h)
	subtitle_label.custom_minimum_size = Vector2(sub_w, sub_h)
	subtitle_label.text = ""
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(subtitle_label, 13, Color.WHITE, true)
	subtitle_label.add_theme_color_override("font_color", Color.WHITE)
	subtitle_label.add_theme_color_override("font_outline_color", Color(0.02, 0.10, 0.26, 0.95))
	subtitle_label.add_theme_constant_override("outline_size", 3)
	subtitle_panel.add_child(subtitle_label)
	
	# Main Content Area
	content_container = Control.new()
	content_container.position = Vector2(0, 176)
	content_container.size = Vector2(cur_w, cur_h - 232)
	add_child(content_container)
	
	# Bottom Sky Blue Bar
	bottom_bar = Panel.new()
	var bar_style = StyleBoxFlat.new()
	bar_style.bg_color = Color(0.51, 0.79, 0.98, 1.0)
	bar_style.border_width_top = 2
	bar_style.border_color = Color(0.38, 0.68, 0.91, 0.85)
	bar_style.set_corner_radius_all(0)
	bottom_bar.add_theme_stylebox_override("panel", bar_style)
	bottom_bar.size = Vector2(cur_w, 56)
	bottom_bar.position = Vector2(0, cur_h - 56)
	bottom_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom_bar)
	
	# Back Button
	back_btn = _create_aspect_button("res://assets/images/shop/backbtnshop.png", Vector2(116, 42))
	if not back_btn.texture_normal:
		back_btn = _create_aspect_button("res://assets/images/shop/blue_back_button.png", Vector2(116, 42))
	back_btn.position = Vector2((cur_w - 116.0) * 0.5, cur_h - 49.0)
	back_btn.pressed.connect(func():
		AudioManager.play_sfx("click")
		if current_tab == "powerups" and active_weapon_id != "":
			active_weapon_id = ""
			_refresh_data()
			return
		var main_node = get_tree().root.get_node_or_null("Main")
		if main_node and main_node.has_method("navigate_to"):
			main_node.navigate_to("map")
		else:
			back_pressed.emit()
	)
	add_child(back_btn)
	
	# Modal Layer
	modal_layer = Control.new()
	modal_layer.name = "ModalLayer"
	modal_layer.anchors_preset = Control.PRESET_FULL_RECT
	modal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal_layer.z_index = 50
	add_child(modal_layer)

# ==============================================================================
# TAB BAR BUTTON CREATION & STATE MANAGEMENT (Direct Image Buttons, No Individual Wraps)
# ==============================================================================
func _create_image_tab_button(img_path: String, tab_id: String, btn_sz: Vector2) -> TextureButton:
	var btn = TextureButton.new()
	btn.name = "TabBtn_" + tab_id
	btn.texture_normal = UIHelper.load_texture_safe(img_path)
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn.custom_minimum_size = btn_sz
	btn.size = btn_sz
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.size_flags_vertical = Control.SIZE_FILL
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	
	btn.pressed.connect(func():
		AudioManager.play_sfx("click")
		_switch_tab(tab_id)
	)
	return btn

func _switch_tab(new_tab: String):
	if current_tab != new_tab:
		current_tab = new_tab
		if new_tab == "powerups":
			active_weapon_id = ""
		_relayout()
		_refresh_data()

func _update_tab_buttons():
	var tabs = [
		{"btn": tab_btn_powerups, "id": "powerups"},
		{"btn": tab_btn_ammo, "id": "ammo"},
		{"btn": tab_btn_boosters, "id": "boosters"}
	]
	for t in tabs:
		var btn = t["btn"] as TextureButton
		if not btn or not is_instance_valid(btn):
			continue
		var is_active = (t["id"] == current_tab)
		if is_active:
			btn.modulate = Color(1.0, 1.0, 1.0, 1.0)
		else:
			btn.modulate = Color(0.70, 0.85, 1.0, 0.50)

# ==============================================================================
# DATA REFRESH & STATE MACHINE DISPATCHER
# ==============================================================================
func _get_owned_tiers(p: Dictionary, w_id: String) -> Array:
	var tiers_dict = p.get("weaponTiers", {})
	if typeof(tiers_dict) != TYPE_DICTIONARY:
		return [1] if w_id == "brush" else []
	var list = tiers_dict.get(w_id, [])
	if typeof(list) != TYPE_ARRAY:
		return [1] if w_id == "brush" else []
	var clean: Array = []
	for t in list:
		var ti = int(t)
		if not clean.has(ti):
			clean.append(ti)
	if w_id == "brush" and not clean.has(1):
		clean.append(1)
	clean.sort()
	return clean

func _is_tier_owned(p: Dictionary, w_id: String, level: int) -> bool:
	var list = _get_owned_tiers(p, w_id)
	return list.has(level)

func _get_active_weapon_level(p: Dictionary, w_id: String) -> int:
	var owned = _get_owned_tiers(p, w_id)
	if owned.is_empty():
		return 0
	var loadout_lvl = int(p.get("loadout", {}).get(w_id, 0))
	if loadout_lvl > 0 and owned.has(loadout_lvl):
		return loadout_lvl
	var wep_lvl = int(p.get("weaponLevels", {}).get(w_id, 0))
	if wep_lvl > 0 and owned.has(wep_lvl):
		return wep_lvl
	return int(owned[-1])

func _refresh_data():
	var p = GameState.get_active_profile()
	points_label.text = str(int(round(float(p.get("points", 0)))))
	coins_label.text = str(int(round(float(p.get("coins", 0)))))
	
	var cur_node = int(p.get("currentNode", 1))
	var cur_day = max(GameState.get_unlocked_day(p), GameState.day_for_node(cur_node))
	
	_update_tab_buttons()
	
	for c in content_container.get_children():
		c.queue_free()
		
	if subtitle_panel and subtitle_label:
		subtitle_label.position = Vector2.ZERO
		subtitle_label.size = subtitle_panel.size
		subtitle_label.custom_minimum_size = subtitle_panel.size
		subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		subtitle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	if current_tab == "powerups":
		if active_weapon_id == "":
			if subtitle_panel: subtitle_panel.visible = true
			subtitle_label.text = "Tap a tool to see its upgrade levels"
			subtitle_label.add_theme_font_size_override("font_size", 12)
			_relayout()
			_build_powerups_grid_view(p, cur_day)
		else:
			if subtitle_panel: subtitle_panel.visible = false
			_relayout()
			_build_powerups_expanded_view(p, cur_day)
	elif current_tab == "ammo":
		if subtitle_panel: subtitle_panel.visible = true
		subtitle_label.text = "NO AMMO, NO FIRING — STOCK UP BEFORE BATTLE"
		subtitle_label.add_theme_font_size_override("font_size", 11)
		_build_ammo_view(p)
	elif current_tab == "boosters":
		if subtitle_panel: subtitle_panel.visible = true
		subtitle_label.text = "SPECIAL ITEMS TO BOOST YOUR ADVENTURE"
		subtitle_label.add_theme_font_size_override("font_size", 12)
		_build_boosters_view(p)

# ==============================================================================
# TAB 1: POWER-UPS TAB - 2x2 TOOLBOX INVENTORY GRID (Closed State)
# - Background: itembackpanel.png with strict 1:1 square aspect ratio
# - Scale: 3-segment visual scale + label that accurately reflects owned levels out of 3
#   and fits neatly inside the itembackpanel.png square!
# ==============================================================================
func _build_powerups_grid_view(p: Dictionary, cur_day: int):
	var avail_h = content_container.size.y
	var avail_w = size.x
	
	var col_gap = 12.0
	var row_gap = 14.0
	var card_w = clampf((avail_w - 24.0 - col_gap) * 0.5, 174.0, 185.0)
	var card_h = clampf(card_w * 1.34, 234.0, 248.0)
	var total_w = card_w * 2.0 + col_gap
	var start_x = (avail_w - total_w) * 0.5
	
	var total_h = card_h * 2.0 + row_gap
	var start_y = max(10.0, (avail_h - total_h) * 0.35)
	
	for idx in range(WEAPON_DEFS.size()):
		var w = WEAPON_DEFS[idx]
		var col = idx % 2
		var row = idx / 2
		var pos_x = start_x + col * (card_w + col_gap)
		var pos_y = start_y + row * (card_h + row_gap)
		
		var owned_tiers = _get_owned_tiers(p, w["id"])
		var is_discovered = (cur_day >= w["unlock_day"] or owned_tiers.size() > 0)
		
		var card = _create_powerup_square_card(w, owned_tiers, is_discovered, card_w, card_h)
		card.position = Vector2(pos_x, pos_y)
		content_container.add_child(card)

func _create_powerup_square_card(w_def: Dictionary, owned_tiers: Array, is_discovered: bool, card_w: float, card_h: float) -> Button:
	var card = Button.new()
	card.custom_minimum_size = Vector2(card_w, card_h)
	card.size = Vector2(card_w, card_h)
	card.flat = true
	card.focus_mode = Control.FOCUS_NONE
	var empty_style = StyleBoxEmpty.new()
	card.add_theme_stylebox_override("normal", empty_style)
	card.add_theme_stylebox_override("hover", empty_style)
	card.add_theme_stylebox_override("pressed", empty_style)
	card.add_theme_stylebox_override("focus", empty_style)
	
	# Background: itembackpanel.png scaled to card dimensions
	var bg_img = TextureRect.new()
	bg_img.texture = UIHelper.load_texture_safe("res://assets/images/shop/itembackpanel.png")
	bg_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_img.stretch_mode = TextureRect.STRETCH_SCALE
	bg_img.custom_minimum_size = Vector2(card_w, card_h)
	bg_img.size = Vector2(card_w, card_h)
	bg_img.position = Vector2.ZERO
	bg_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_img.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	card.add_child(bg_img)
	
	var vbox_y = 25.0 # Brought down nicely inside the card
	var vbox = VBoxContainer.new()
	vbox.position = Vector2(8, vbox_y)
	vbox.size = Vector2(card_w - 16.0, card_h - (vbox_y + 10.0))
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 3)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(vbox)
	
	# Determine highest unlocked level for this weapon
	var active_lvl = 1
	if not owned_tiers.is_empty():
		for t in owned_tiers:
			if int(t) > active_lvl:
				active_lvl = int(t)
				
	# Top: Weapon Name (use 3D title graphic matching current tier if discovered/owned, else label)
	var title_img_path = get_weapon_title_img(w_def, active_lvl)
	var title_w = card_w - 14.0
	var title_h = 44.0 # Title size enlarged to fit comfortably and boldly
	var title_sz = Vector2(title_w, title_h)
	var title_rect = _create_aspect_rect(title_img_path, title_sz)
	if (is_discovered or not owned_tiers.is_empty()) and title_rect.texture:
		title_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(title_rect)
	else:
		var name_lbl = Label.new()
		name_lbl.custom_minimum_size = Vector2(card_w - 16.0, title_h)
		name_lbl.size = Vector2(card_w - 16.0, title_h)
		if not is_discovered and owned_tiers.is_empty():
			name_lbl.text = ""
		else:
			name_lbl.text = get_weapon_display_title(w_def, active_lvl)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UIHelper.apply_bubbly_label(name_lbl, 14, Color.BLACK, true)
		name_lbl.add_theme_color_override("font_color", Color.BLACK)
		name_lbl.add_theme_constant_override("outline_size", 0)
		name_lbl.add_theme_constant_override("line_spacing", -2)
		vbox.add_child(name_lbl)
	
	# Center: Large Weapon Graphic or "?" (Scaled up to 120x120 for all cards)
	var center_box = CenterContainer.new()
	var weapon_icon_sz = Vector2(120, 120)
	center_box.custom_minimum_size = Vector2(card_w - 16.0, 114)
	center_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(center_box)
	
	var has_unlocked = (owned_tiers.size() > 0)
	if has_unlocked:
		var recent_lvl = 1
		for t in owned_tiers:
			if int(t) > recent_lvl:
				recent_lvl = int(t)
		var img_path = w_def["images"][clamp(recent_lvl - 1, 0, 2)]
		var img = _create_aspect_rect(img_path, weapon_icon_sz)
		img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center_box.add_child(img)
	elif is_discovered:
		var img_path = w_def["images"][0]
		var img = _create_aspect_rect(img_path, weapon_icon_sz)
		img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center_box.add_child(img)
	else:
		var q_img = _create_aspect_rect("res://assets/images/shop/QuestionMark.png", Vector2(76, 76))
		q_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg_img.material = _get_grayscale_material()
		center_box.add_child(q_img)
		
	# Bottom: Continuous Scale Meter (Enlarged to wide pill with 13pt bold text)
	var scale_center = CenterContainer.new()
	scale_center.custom_minimum_size = Vector2(card_w - 16.0, 32)
	scale_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scale_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var scale_w = clamp(round(card_w - 30.0), 140.0, 154.0)
	var scale_widget = _create_ownership_scale(owned_tiers.size(), is_discovered, w_def["unlock_day"], scale_w)
	scale_center.add_child(scale_widget)
	vbox.add_child(scale_center)
	
	# Bottom spacer to ensure scale sits well above the bottom border
	var bottom_spacer = Control.new()
	bottom_spacer.custom_minimum_size = Vector2(card_w - 16.0, 8)
	bottom_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(bottom_spacer)
	
	# Tapping emits pressed() and reveals Expanded Weapon view
	card.pressed.connect(func():
		if not is_discovered and owned_tiers.is_empty():
			AudioManager.play_sfx("hit")
			GameState.push_toast("Locked!", "Unlocks on Day %d!" % w_def["unlock_day"], "", "blue")
			return
		AudioManager.play_sfx("click")
		active_weapon_id = w_def["id"]
		_refresh_data()
	)
	return card

# ==============================================================================
# OWNERSHIP CONTINUOUS SCALE METER WIDGET
# The scale itself is the progress bar, with the text (e.g. "1/3 owned") centered directly inside it.
# No outer horizontal window holding a separate mini scale.
# ==============================================================================
func _create_ownership_scale(owned_count: int, is_discovered: bool, day_req: int, base_scale_w: float) -> Control:
	var scale_h = 26.0
	var scale_w = clampf(base_scale_w * 0.95, 136.0, 152.0)
	
	if owned_count >= 1:
		var bar_path = "res://assets/images/shop/1of3owned_bar.png"
		if owned_count == 2:
			bar_path = "res://assets/images/shop/2of3owned_bar.png"
		elif owned_count >= 3:
			bar_path = "res://assets/images/shop/3of3owned_bar.png"
			
		var bar_rect = _create_aspect_rect(bar_path, Vector2(scale_w, scale_h))
		if bar_rect.texture:
			bar_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			return bar_rect

	var scale_bar = Control.new()
	scale_bar.custom_minimum_size = Vector2(scale_w, scale_h)
	scale_bar.size = Vector2(scale_w, scale_h)
	scale_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var track = Panel.new()
	track.position = Vector2.ZERO
	track.size = Vector2(scale_w, scale_h)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tr_st = StyleBoxFlat.new()
	tr_st.bg_color = Color(0.06, 0.16, 0.32, 0.92) # Dark navy blue trough
	tr_st.border_color = Color(0.42, 0.72, 0.95, 0.85) # Crisp blue border
	tr_st.set_border_width_all(1)
	tr_st.set_corner_radius_all(int(scale_h * 0.5)) # Rounded pill ends
	track.add_theme_stylebox_override("panel", tr_st)
	scale_bar.add_child(track)
	
	if not is_discovered:
		# Locked scale: Centered metallic lock icon + "Day %d" directly inside the scale
		var lock_box = HBoxContainer.new()
		lock_box.position = Vector2.ZERO
		lock_box.size = Vector2(scale_w, scale_h)
		lock_box.custom_minimum_size = Vector2(scale_w, scale_h)
		lock_box.alignment = BoxContainer.ALIGNMENT_CENTER
		lock_box.add_theme_constant_override("separation", 6)
		lock_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		scale_bar.add_child(lock_box)
		
		var lock_ic = _create_aspect_rect("res://assets/images/parentalcontrol/metal_lock_icon.png", Vector2(16, 16))
		if not lock_ic.texture:
			lock_ic = _create_aspect_rect("res://assets/images/scrapbook/metal_lock_icon.png", Vector2(16, 16))
		if lock_ic.texture:
			lock_box.add_child(lock_ic)
			
		var day_lbl = Label.new()
		day_lbl.text = "Day %d" % day_req
		day_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		day_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		day_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UIHelper.apply_bubbly_label(day_lbl, 12, Color(0.85, 0.94, 1.0), true)
		lock_box.add_child(day_lbl)
	else:
		var lbl = Label.new()
		lbl.position = Vector2.ZERO
		lbl.size = Vector2(scale_w, scale_h)
		lbl.custom_minimum_size = Vector2(scale_w, scale_h)
		lbl.text = "0/3 OWNED"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UIHelper.apply_bubbly_label(lbl, 12, Color.WHITE, true)
		scale_bar.add_child(lbl)
		
	return scale_bar

# # ==============================================================================
# TAB 1: EXPANDED WEAPON VIEW ("Power-ups" Tab) (Rule 2)
# Displays upgrade path for the selected tool and allows switching to other tools.
# - Main Background: NinePatchRect with ItemWindow.png (stretches vertically)
# - Level Rows (LVL 1, LVL 2, LVL 3): VBoxContainer of TextureRect using blue_panels_long.png
#   - Row 1 (Owned): brushweapon_1.png + grey pill "OWNED"
#   - Row 2 (Next Upgrade): brushweapon_2.png (greyscale) + clean yellow purchasebtn.png (no price overlay)
#   - Row 3 (Locked): Grey/translucent modulate, Godot Label "?" and "DAY 11"
# - Bottom Weapon Switcher: HBoxContainer with 3 square cards on itembackpanel.png
#   displaying pasteweapon_1.png, MouthwashBlast-1.png, flossweapon_1.png or "?" for locked
# ==============================================================================
func _build_powerups_expanded_view(p: Dictionary, cur_day: int):
	var avail_h = content_container.size.y
	var avail_w = size.x
	
	var active_w = null
	var target_id = normalize_weapon_id(active_weapon_id)
	for w in WEAPON_DEFS:
		if w["id"] == target_id:
			active_w = w
			active_weapon_id = w["id"]
			break
	if active_w == null:
		active_w = WEAPON_DEFS[0]
		active_weapon_id = active_w["id"]
		
	var owned_tiers = _get_owned_tiers(p, active_w["id"])
	
	# Make expanded view big, prominent, and centered on page height
	var row_w = min(avail_w - 16.0, 430.0)
	var row_x = (avail_w - row_w) * 0.5
	
	# Calculate heights dynamically so the 3 level bars and bottom switcher fill comfortably and centered
	var header_h = 42.0
	var bot_card_sz = clampf(floor((row_w - 32.0) / 3.0), 80.0, 116.0)
	var bot_title_h = 32.0
	var bot_total_h = bot_card_sz + bot_title_h + 4.0
	
	var fixed_h = header_h + 8.0 + bot_total_h + 12.0 + 16.0
	var remaining_for_rows = avail_h - fixed_h
	var row_h = clampf(floor((remaining_for_rows - 16.0) / 3.0), 74.0, 92.0)
	var rows_h = row_h * 3.0 + 16.0
	var total_used_h = header_h + 8.0 + rows_h + 12.0 + bot_total_h
	var start_y = max(4.0, (avail_h - total_used_h) * 0.5)
	
	# Header title: 3D weapon title graphic matching latest tier
	var header_box = Control.new()
	header_box.position = Vector2(row_x, start_y)
	header_box.size = Vector2(row_w, header_h)
	content_container.add_child(header_box)
	
	var latest_tier = 1
	if not owned_tiers.is_empty():
		for t in owned_tiers:
			if int(t) > latest_tier:
				latest_tier = int(t)
				
	var title_img_path = get_weapon_title_img(active_w, latest_tier)
	var title_sz = Vector2(min(row_w - 60.0, 260.0), 40.0)
	var title_img_rect = _create_aspect_rect(title_img_path, title_sz)
	if title_img_rect.texture:
		title_img_rect.position = Vector2((row_w - title_sz.x) * 0.5, 2)
		title_img_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		header_box.add_child(title_img_rect)
	else:
		var header_title = Label.new()
		header_title.position = Vector2(0, 4)
		header_title.size = Vector2(row_w - 40.0, 32)
		header_title.text = "%s (%d/3 OWNED)" % [get_weapon_full_name(active_w, latest_tier), owned_tiers.size()]
		header_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		UIHelper.apply_bubbly_label(header_title, 16, Color.WHITE, true)
		header_box.add_child(header_title)
	
	# Close 'X' Button on top-right to return to 2x2 Toolbox Inventory
	var close_btn = UIHelper.create_close_button(Vector2(32, 32))
	close_btn.name = "CloseWeaponBtn"
	close_btn.position = Vector2(row_w - 32.0, 4.0)
	close_btn.pressed.connect(func():
		AudioManager.play_sfx("click")
		active_weapon_id = ""
		_refresh_data()
	)
	header_box.add_child(close_btn)
	
	# Level Rows (LVL 1, LVL 2, LVL 3): VBoxContainer filling the central area
	var rows_vbox = VBoxContainer.new()
	rows_vbox.position = Vector2(row_x, start_y + header_h + 8.0)
	rows_vbox.size = Vector2(row_w, rows_h)
	rows_vbox.add_theme_constant_override("separation", 8)
	content_container.add_child(rows_vbox)
	
	for lvl in range(1, 4):
		var row = _create_weapon_level_row(active_w, lvl, cur_day, p, row_w, row_h)
		rows_vbox.add_child(row)
		
	# Bottom Weapon Switcher: HBoxContainer with 3 square cards on itembackpanel.png
	var bot_hbox = HBoxContainer.new()
	bot_hbox.position = Vector2(row_x, start_y + header_h + 8.0 + rows_h + 12.0)
	bot_hbox.size = Vector2(row_w, bot_total_h)
	bot_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	bot_hbox.add_theme_constant_override("separation", 16)
	content_container.add_child(bot_hbox)
	
	for w in WEAPON_DEFS:
		if w["id"] == active_weapon_id:
			continue
		var mini_item = _create_bottom_weapon_switcher_item(w, p, cur_day, bot_card_sz, bot_title_h)
		bot_hbox.add_child(mini_item)

func _create_weapon_level_row(w_def: Dictionary, lvl: int, cur_day: int, p: Dictionary, row_w: float, row_h: float) -> Control:
	var row = Control.new()
	row.custom_minimum_size = Vector2(row_w, row_h)
	row.size = Vector2(row_w, row_h)
	
	var is_owned = _is_tier_owned(p, w_def["id"], lvl)
	var day_req = w_def["day_reqs"][lvl - 1]
	var cost = w_def["costs"][lvl - 1]
	var is_discovered = (cur_day >= day_req or is_owned)
	
	# Row background: blue_panels_long.png filling the full wide row
	var row_bg = TextureRect.new()
	row_bg.texture = UIHelper.load_texture_safe("res://assets/images/shop/blue_panels_long.png")
	row_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	row_bg.stretch_mode = TextureRect.STRETCH_SCALE
	row_bg.position = Vector2.ZERO
	row_bg.size = Vector2(row_w, row_h)
	row_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row_bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if not is_owned:
		row_bg.material = _get_grayscale_material()
		if not is_discovered:
			row_bg.modulate = Color(0.70, 0.80, 0.92, 0.85)
	row.add_child(row_bg)
	
	# Left: LVL 1 / LVL 2 / LVL 3 Graphic
	var lvl_tex_path = "res://assets/images/shop/LVL%d_Txt.png" % lvl
	var lvl_sz = Vector2(clampf(row_w * 0.26, 86.0, 114.0), round(row_h * 0.72))
	var lvl_img = _create_aspect_rect(lvl_tex_path, lvl_sz)
	if lvl_img.texture:
		lvl_img.position = Vector2(12, (row_h - lvl_sz.y) * 0.5)
		if not is_discovered:
			lvl_img.modulate = Color(0.80, 0.88, 0.95, 0.75)
		row.add_child(lvl_img)
	else:
		var lvl_lbl = Label.new()
		lvl_lbl.position = Vector2(12, (row_h - 36.0) * 0.5)
		lvl_lbl.size = Vector2(lvl_sz.x, 36)
		lvl_lbl.text = "LVL %d" % lvl
		lvl_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		UIHelper.apply_bubbly_label(lvl_lbl, 20, Color.WHITE, true)
		row.add_child(lvl_lbl)
		
	# Center: Large Weapon Graphic (brushweapon_1.png, brushweapon_2.png, BubbleBrush.png) or "?"
	if is_owned or is_discovered:
		var img_path = w_def["images"][lvl - 1]
		var icon_sz = Vector2(round(row_h * 0.78), round(row_h * 0.78))
		var img_rect = _create_aspect_rect(img_path, icon_sz)
		img_rect.position = Vector2((row_w - icon_sz.x) * 0.5, (row_h - icon_sz.y) * 0.5)
		if not is_owned:
			img_rect.material = _get_grayscale_material()
		row.add_child(img_rect)
	else:
		# Row 3 (Locked): QuestionMark image
		var q_sz = Vector2(round(row_h * 0.55), round(row_h * 0.55))
		var q_img = _create_aspect_rect("res://assets/images/shop/QuestionMark.png", q_sz)
		q_img.position = Vector2((row_w - q_sz.x) * 0.5, (row_h - q_sz.y) * 0.5)
		q_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(q_img)
		
	# Right Action:
	var btn_w = clampf(row_w * 0.32, 114.0, 142.0)
	var btn_h = clampf(row_h * 0.58, 46.0, 54.0)
	if is_owned:
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		row.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				AudioManager.play_sfx("click")
				_show_owned_weapon_breakdown_popup(w_def, lvl)
		)
		
		# Row 1 (Owned): Authentic 3D ownedbtn.png asset (extra large)
		var btn_sz = Vector2(btn_w, btn_h)
		var owned_btn = _create_aspect_button("res://assets/images/shop/ownedbtn.png", btn_sz)
		if not owned_btn.texture_normal:
			owned_btn = _create_aspect_button("res://assets/images/general/ownedbtn.png", btn_sz)
		if not owned_btn.texture_normal:
			owned_btn = _create_aspect_button("res://assets/images/buttons/ownedbtn.png", btn_sz)
		owned_btn.position = Vector2(row_w - btn_sz.x - 12.0, (row_h - btn_sz.y) * 0.5)
		owned_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		owned_btn.pressed.connect(func():
			AudioManager.play_sfx("click")
			_show_owned_weapon_breakdown_popup(w_def, lvl)
		)
		row.add_child(owned_btn)
	elif is_discovered:
		# Row 2 (Next Upgrade): Clean yellow PURCHASE button
		var btn_sz = Vector2(btn_w, btn_h)
		var buy_btn = _create_aspect_button("res://assets/images/shop/purchasebtn.png", btn_sz)
		buy_btn.position = Vector2(row_w - btn_sz.x - 12.0, (row_h - btn_sz.y) * 0.5)
		buy_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		buy_btn.pressed.connect(func():
			AudioManager.play_sfx("click")
			_purchase_weapon(w_def, lvl, cost)
		)
		row.add_child(buy_btn)
		
		# Tapping the row opens preview/breakdown modal
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		row.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				AudioManager.play_sfx("click")
				_show_weapon_purchase_popup(w_def, lvl, cost)
		)
	else:
		# Row 3 (Locked): "DAY %d" badge
		var day_lbl = Label.new()
		var d_w = btn_w
		day_lbl.position = Vector2(row_w - d_w - 12.0, (row_h - 28.0) * 0.5)
		day_lbl.size = Vector2(d_w, 28)
		day_lbl.text = "DAY %d" % day_req
		day_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		day_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		UIHelper.apply_bubbly_label(day_lbl, 14, Color(0.80, 0.88, 0.95, 0.90), true)
		row.add_child(day_lbl)
		
	return row

func _create_bottom_weapon_switcher_item(w_def: Dictionary, p: Dictionary, cur_day: int, card_sz: float, title_h: float = 36.0) -> Control:
	var item_container = VBoxContainer.new()
	item_container.custom_minimum_size = Vector2(card_sz, card_sz + title_h + 4.0)
	item_container.size = Vector2(card_sz, card_sz + title_h + 4.0)
	item_container.alignment = BoxContainer.ALIGNMENT_CENTER
	item_container.add_theme_constant_override("separation", 2)
	
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(card_sz, card_sz)
	btn.size = Vector2(card_sz, card_sz)
	btn.focus_mode = Control.FOCUS_NONE
	btn.flat = true
	var empty_st = StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", empty_st)
	btn.add_theme_stylebox_override("hover", empty_st)
	btn.add_theme_stylebox_override("pressed", empty_st)
	btn.add_theme_stylebox_override("focus", empty_st)
	
	var owned_tiers = _get_owned_tiers(p, w_def["id"])
	var is_owned = (owned_tiers.size() > 0)
	var is_discovered = (cur_day >= w_def["unlock_day"] or is_owned)
	
	# Square base background: TextureRect with itembackpanel.png
	var panel_bg = TextureRect.new()
	panel_bg.texture = UIHelper.load_texture_safe("res://assets/images/shop/itembackpanel.png")
	panel_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	panel_bg.stretch_mode = TextureRect.STRETCH_SCALE
	panel_bg.position = Vector2.ZERO
	panel_bg.size = Vector2(card_sz, card_sz)
	panel_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not is_owned:
		panel_bg.material = _get_grayscale_material()
	btn.add_child(panel_bg)
	
	var center_box = CenterContainer.new()
	center_box.position = Vector2.ZERO
	center_box.size = Vector2(card_sz, card_sz)
	center_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(center_box)
	
	if is_owned:
		# Shows most recently unlocked tier's icon
		var latest_tier = owned_tiers[-1]
		var icon_path = w_def["images"][clamp(latest_tier - 1, 0, 2)]
		var icon = _create_aspect_rect(icon_path, Vector2(round(card_sz * 0.74), round(card_sz * 0.74)))
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center_box.add_child(icon)
		
		btn.pressed.connect(func():
			AudioManager.play_sfx("click")
			active_weapon_id = w_def["id"]
			_refresh_data()
		)
	elif is_discovered:
		# Discovered on schedule, but not yet bought -> Fully greyscale!
		var icon_path = w_def["images"][0]
		var icon = _create_aspect_rect(icon_path, Vector2(round(card_sz * 0.74), round(card_sz * 0.74)))
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.material = _get_grayscale_material()
		center_box.add_child(icon)
		
		btn.pressed.connect(func():
			AudioManager.play_sfx("click")
			active_weapon_id = w_def["id"]
			_refresh_data()
		)
	else:
		# Locked (future day) -> Question mark
		var q_img = _create_aspect_rect("res://assets/images/shop/QuestionMark.png", Vector2(round(card_sz * 0.52), round(card_sz * 0.52)))
		q_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center_box.add_child(q_img)
		
		btn.pressed.connect(func():
			AudioManager.play_sfx("hit")
			GameState.push_toast("Locked!", "Unlocks on Day %d!" % w_def["unlock_day"], "", "blue")
		)
		
	item_container.add_child(btn)
	
	# 3D Title Image UNDER the square, perfectly centered to each square
	var title_box = CenterContainer.new()
	title_box.custom_minimum_size = Vector2(card_sz, title_h)
	title_box.size = Vector2(card_sz, title_h)
	title_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	if is_discovered or is_owned:
		var active_lvl = 1
		if is_owned and not owned_tiers.is_empty():
			active_lvl = int(owned_tiers[-1])
		var title_path = get_weapon_title_img(w_def, active_lvl)
		var title_sz = Vector2(card_sz - 4.0, title_h)
		var title_rect = _create_aspect_rect(title_path, title_sz)
		if title_rect.texture:
			title_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			title_box.add_child(title_rect)
		else:
			var sub_lbl = Label.new()
			sub_lbl.custom_minimum_size = Vector2(card_sz, title_h)
			sub_lbl.size = Vector2(card_sz, title_h)
			sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			sub_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			sub_lbl.text = get_weapon_full_name(w_def, active_lvl)
			UIHelper.apply_bubbly_label(sub_lbl, 11, Color.WHITE, true)
			sub_lbl.add_theme_color_override("font_outline_color", Color(0.06, 0.18, 0.38))
			sub_lbl.add_theme_constant_override("outline_size", 2)
			title_box.add_child(sub_lbl)
	item_container.add_child(title_box)
	
	return item_container

# ==============================================================================
# TAB 2: AMMO SUPPLY PAGE ("Ammo" Tab) (Rule 3)
# - Widened and enlarged to match the expanded powerups width
# - Background: blue_panels_long.png filling each large row
# - Store Items:
#   - Row 1: Manual Brush Packs (ToothbrushPack.png)
#   - Row 2: Alkaline Batteries (Bubble_Battery.png)
#   - Row 3: Minty Projectile Refill (BubblePaste.png)
#   - Row 4: Elixir Bottles (BubbleWash.png)
#   - Row 5: Floss String Spool (level1flosstring.png)
# - Buy Buttons: purchasebtn.png (yellow button) on the right
# ==============================================================================
func _build_ammo_view(p: Dictionary):
	var avail_h = content_container.size.y
	var avail_w = size.x
	var card_w = min(avail_w - 16.0, 430.0)
	var card_x = (avail_w - card_w) * 0.5
	
	# Only show ammo items for unlocked weapons matching the exact level the user is on
	var ammo_items: Array = []
	for w in WEAPON_DEFS:
		var w_id = w["id"]
		var active_lvl = _get_active_weapon_level(p, w_id)
		if active_lvl > 0 and AMMO_DEFS_BY_WEAPON.has(w_id):
			var w_ammos = AMMO_DEFS_BY_WEAPON[w_id]
			if w_ammos.has(active_lvl):
				ammo_items.append(w_ammos[active_lvl])
	
	var row_w = card_w - 4.0
	var row_h = clampf(round(row_w * 0.25), 94.0, 112.0)
	var sep = 10.0
	var total_rows_h = ammo_items.size() * row_h + max(0, ammo_items.size() - 1) * sep
	var start_y = max(16.0, (avail_h - total_rows_h) * 0.35)
	
	# List Container: ScrollContainer holding VBoxContainer directly on content area
	var scroll = ScrollContainer.new()
	scroll.position = Vector2(card_x, start_y)
	scroll.size = Vector2(card_w, avail_h - start_y - 12.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	content_container.add_child(scroll)
	
	var rows_vbox = VBoxContainer.new()
	rows_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows_vbox.add_theme_constant_override("separation", sep)
	scroll.add_child(rows_vbox)
	
	if ammo_items.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "No weapons unlocked yet!\nUnlock weapons in Power-ups to access ammo refills."
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_lbl.custom_minimum_size = Vector2(row_w, 120)
		UIHelper.apply_bubbly_label(empty_lbl, 14, Color.WHITE, true)
		rows_vbox.add_child(empty_lbl)
	else:
		for item in ammo_items:
			var row_node = _create_ammo_row(item, p, row_w, row_h)
			rows_vbox.add_child(row_node)

func _create_ammo_icon(item: Dictionary, box_sz: Vector2) -> Control:
	var is_paste = (item.get("ammo_key") == "tubes" or item.get("id", "").begins_with("paste_") or item.get("icon", "").find("Projectile") != -1)
	if not is_paste:
		return _create_aspect_rect(item["icon"], box_sz)
		
	var c = Control.new()
	c.custom_minimum_size = box_sz
	c.size = box_sz
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var w = box_sz.x
	var h = box_sz.y
	# Diameter of each projectile: around 54% of box size
	var d = round(min(w, h) * 0.54)
	var p_sz = Vector2(d, d)
	
	# Horizontal spread for the bottom two projectiles
	var left_x = round((w - d * 1.62) * 0.5)
	var right_x = w - d - left_x
	var bottom_y = h - d - 2.0
	var top_x = round((w - d) * 0.5)
	var top_y = 2.0
	
	# Bottom-left projectile
	var p_bl = _create_aspect_rect(item["icon"], p_sz)
	p_bl.position = Vector2(left_x, bottom_y)
	p_bl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(p_bl)
	
	# Bottom-right projectile
	var p_br = _create_aspect_rect(item["icon"], p_sz)
	p_br.position = Vector2(right_x, bottom_y)
	p_br.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(p_br)
	
	# Top projectile (peak of triangle, sitting cleanly in front)
	var p_top = _create_aspect_rect(item["icon"], p_sz)
	p_top.position = Vector2(top_x, top_y)
	p_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(p_top)
	
	return c

func _create_ammo_row(item: Dictionary, p: Dictionary, row_w: float, row_h: float) -> Control:
	var row_container = Control.new()
	row_container.custom_minimum_size = Vector2(row_w, row_h)
	row_container.size = Vector2(row_w, row_h)
	row_container.mouse_filter = Control.MOUSE_FILTER_STOP
	row_container.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			AudioManager.play_sfx("click")
			_show_ammo_purchase_popup(item)
	)
	
	# Background: blue_panels_long.png stretching across the full wide row
	var bg = TextureRect.new()
	bg.texture = UIHelper.load_texture_safe("res://assets/images/shop/blue_panels_long.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.position = Vector2.ZERO
	bg.size = Vector2(row_w, row_h)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	row_container.add_child(bg)
	
	# HBoxContainer inside - using generous 18px horizontal inset padding
	var hbox = HBoxContainer.new()
	var pad_x = 18.0
	var pad_y = 6.0
	hbox.position = Vector2(pad_x, pad_y)
	hbox.size = Vector2(row_w - pad_x * 2.0, row_h - pad_y * 2.0)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 12)
	row_container.add_child(hbox)
	
	# Item Icon (Single icon for standard ammo, or 3-projectile triangle for toothpaste ammo)
	var icon_h = clampf(row_h - 16.0, 56.0, 72.0)
	var icon = _create_ammo_icon(item, Vector2(icon_h, icon_h))
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(icon)
	
	# Name, subtitle & owned details VBox (No price on the row)
	var text_vbox = VBoxContainer.new()
	text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	text_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(text_vbox)
	
	var name_lbl = Label.new()
	name_lbl.text = item["name"]
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UIHelper.apply_bubbly_label(name_lbl, 13, Color.BLACK, true)
	name_lbl.add_theme_color_override("font_color", Color.BLACK)
	name_lbl.add_theme_constant_override("outline_size", 0)
	text_vbox.add_child(name_lbl)
	
	var sub_text = item.get("subtitle", "")
	if sub_text != "":
		var desc_lbl = Label.new()
		desc_lbl.text = sub_text
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UIHelper.apply_bubbly_label(desc_lbl, 11, Color(0.12, 0.12, 0.12), false)
		desc_lbl.add_theme_color_override("font_color", Color(0.12, 0.12, 0.12))
		desc_lbl.add_theme_constant_override("outline_size", 0)
		text_vbox.add_child(desc_lbl)
	
	var cur_qty = int(p.get("ammo", {}).get(item["ammo_key"], 0))
	if item["ammo_key"] == "brushes" and cur_qty <= 0:
		cur_qty = 40
	var sub_lbl = Label.new()
	sub_lbl.text = "Owned: %d in Arsenal" % cur_qty
	UIHelper.apply_bubbly_label(sub_lbl, 11, Color(0.15, 0.15, 0.15), true)
	sub_lbl.add_theme_color_override("font_color", Color(0.15, 0.15, 0.15))
	sub_lbl.add_theme_constant_override("outline_size", 0)
	text_vbox.add_child(sub_lbl)
	
	# Buy Button: purchasebtn.png
	var btn_w = clampf(row_w * 0.28, 110.0, 130.0)
	var btn_h = round(btn_w * 34.0 / 100.0)
	var buy_btn = _create_aspect_button("res://assets/images/shop/purchasebtn.png", Vector2(btn_w, btn_h))
	buy_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	# Clicking purchase opens confirmation modal popup showing the price
	buy_btn.pressed.connect(func():
		AudioManager.play_sfx("click")
		_show_ammo_purchase_popup(item)
	)
	hbox.add_child(buy_btn)
	
	return row_container

# ==============================================================================
# AMMO PURCHASE CONFIRMATION POPUP MODAL
# ==============================================================================
func _show_ammo_purchase_popup(item: Dictionary):
	_cleanup_modals()
		
	var safe_sz = UIHelper.get_viewport_safe_size(self)
	var dlg = UIHelper.create_modal_dialog(modal_layer, 200, Color(0, 0, 0, 0.65))
	var backdrop = dlg["overlay"]
	var center = dlg["center"]
	
	var win_w = min(safe_sz.x - 32.0, 330.0)
	var win_h = 455.0
	var win = _create_nine_patch("res://assets/images/shop/game_blue_window_tall.png", 32)
	win.custom_minimum_size = Vector2(win_w, win_h)
	win.size = Vector2(win_w, win_h)
	win.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	win.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	center.add_child(win)
	
	var close_btn = UIHelper.create_close_button(Vector2(32, 32))
	close_btn.position = Vector2(win_w - 24.0, -10.0)
	close_btn.pressed.connect(func():
		AudioManager.play_sfx("click")
		backdrop.queue_free()
	)
	win.add_child(close_btn)
	
	var vbox = VBoxContainer.new()
	vbox.position = Vector2(16, 16)
	vbox.size = Vector2(win_w - 32.0, win_h - 32.0)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)
	win.add_child(vbox)
	
	var title_lbl = Label.new()
	title_lbl.text = "PURCHASE AMMO"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(title_lbl, 14, Color.WHITE, true)
	vbox.add_child(title_lbl)
	
	var name_lbl = Label.new()
	name_lbl.text = item["name"]
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UIHelper.apply_bubbly_label(name_lbl, 13, Color(0.85, 0.93, 1.0), true)
	vbox.add_child(name_lbl)
	
	var sub_text = item.get("subtitle", "")
	if sub_text != "":
		var sub_lbl = Label.new()
		sub_lbl.text = sub_text
		sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UIHelper.apply_bubbly_label(sub_lbl, 12, Color.WHITE, true)
		sub_lbl.add_theme_color_override("font_color", Color.WHITE)
		sub_lbl.add_theme_color_override("font_outline_color", Color(0.04, 0.14, 0.32, 0.95))
		sub_lbl.add_theme_constant_override("outline_size", 2)
		vbox.add_child(sub_lbl)
		
	var p_cur = GameState.get_active_profile()
	var cur_arsenal = int(p_cur.get("ammo", {}).get(item["ammo_key"], 0))
	if item["ammo_key"] == "brushes" and cur_arsenal <= 0:
		cur_arsenal = 40
	var owned_status_lbl = Label.new()
	owned_status_lbl.text = "Owned: %d in Arsenal" % cur_arsenal
	owned_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(owned_status_lbl, 12, Color(1.0, 0.88, 0.30), true)
	owned_status_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.30))
	owned_status_lbl.add_theme_color_override("font_outline_color", Color(0.04, 0.14, 0.32, 0.95))
	owned_status_lbl.add_theme_constant_override("outline_size", 2)
	vbox.add_child(owned_status_lbl)
	
	var img_box = CenterContainer.new()
	img_box.custom_minimum_size = Vector2(win_w - 32.0, 58)
	vbox.add_child(img_box)
	
	var img = _create_ammo_icon(item, Vector2(60, 60))
	img_box.add_child(img)

	# Quantity Counter State
	var pack_qty = [1]
	var base_cost = int(item.get("cost", 40))
	var pcs_per_pack = int(item.get("pack", 1))

	# Quantity Selector Row (- number +)
	var qty_hbox = HBoxContainer.new()
	qty_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	qty_hbox.add_theme_constant_override("separation", 10)
	
	var minus_btn = UIHelper.create_bubbly_button("-", Color(0.85, 0.35, 0.35), Color.WHITE)
	minus_btn.custom_minimum_size = Vector2(42, 34)
	qty_hbox.add_child(minus_btn)
	
	var qty_lbl = Label.new()
	qty_lbl.text = "1 Pack"
	qty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qty_lbl.custom_minimum_size = Vector2(80, 34)
	qty_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(qty_lbl, 15, Color.WHITE, true)
	qty_hbox.add_child(qty_lbl)
	
	var plus_btn = UIHelper.create_bubbly_button("+", UIHelper.VIBRANT_GREEN, Color.WHITE)
	plus_btn.custom_minimum_size = Vector2(42, 34)
	qty_hbox.add_child(plus_btn)
	
	vbox.add_child(qty_hbox)
	
	# Total Individual Pieces Summary Label under quantity control
	var summary_lbl = Label.new()
	summary_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UIHelper.apply_bubbly_label(summary_lbl, 12, Color(1.0, 0.92, 0.35), true)
	vbox.add_child(summary_lbl)
	
	# Price Pill
	var p_pill = Panel.new()
	p_pill.custom_minimum_size = Vector2(160, 32)
	p_pill.size = Vector2(160, 32)
	var pp_st = UIHelper.create_bubbly_panel(16, Color(0.52, 0.28, 0.85), Color.WHITE, 1.5)
	p_pill.add_theme_stylebox_override("panel", pp_st)
	
	var point_ic = _create_aspect_rect("res://assets/images/shop/purple_star_points.png", Vector2(22, 22))
	point_ic.position = Vector2(12, 5)
	p_pill.add_child(point_ic)
	
	var plbl = Label.new()
	plbl.position = Vector2(38, 0)
	plbl.size = Vector2(110, 32)
	plbl.text = "%d POINTS" % base_cost
	plbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(plbl, 13, Color.WHITE, true)
	p_pill.add_child(plbl)
	
	var pill_center = CenterContainer.new()
	pill_center.add_child(p_pill)
	vbox.add_child(pill_center)
	
	# Function to refresh quantity, total individual pieces, and total price
	var update_ui = func():
		var q = pack_qty[0]
		qty_lbl.text = "%d %s" % [q, "Pack" if q == 1 else "Packs"]
		var total_pcs = q * pcs_per_pack
		summary_lbl.text = "Total: %d Pieces (%d Packs)" % [total_pcs, q]
		plbl.text = "%d POINTS" % (q * base_cost)
		
	minus_btn.pressed.connect(func():
		AudioManager.play_sfx("click")
		if pack_qty[0] > 1:
			pack_qty[0] -= 1
			update_ui.call()
	)
	
	plus_btn.pressed.connect(func():
		AudioManager.play_sfx("click")
		if pack_qty[0] < 99:
			pack_qty[0] += 1
			update_ui.call()
	)

	update_ui.call()
	
	# Status line shown INSIDE the popup (global toasts are disabled, so feedback must live here)
	var status_lbl = Label.new()
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_lbl.custom_minimum_size = Vector2(win_w - 48.0, 18)
	status_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIHelper.apply_bubbly_label(status_lbl, 12, Color(1.0, 0.88, 0.30), true)
	status_lbl.add_theme_color_override("font_outline_color", Color(0.04, 0.14, 0.32, 0.95))
	status_lbl.add_theme_constant_override("outline_size", 2)
	var pts_now = int(round(float(p_cur.get("points", 0))))
	status_lbl.text = "You have %d points" % pts_now
	vbox.add_child(status_lbl)

	# Yellow PURCHASE button
	var buy_btn = _create_aspect_button("res://assets/images/shop/purchasebtn.png", Vector2(130, 38))
	buy_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	
	buy_btn.pressed.connect(func():
		var p = GameState.get_active_profile()
		var points = int(round(float(p.get("points", 0))))
		var q = pack_qty[0]
		var total_cost = q * base_cost
		var total_pcs = q * pcs_per_pack
		var cur_qty = int(p.get("ammo", {}).get(item["ammo_key"], 0))
		if item["ammo_key"] == "brushes" and cur_qty <= 0:
			cur_qty = 40
		if points >= total_cost:
			if not p.has("ammo") or typeof(p["ammo"]) != TYPE_DICTIONARY:
				p["ammo"] = {"brushes": 40, "battery": 0, "tubes": 0, "spools": 0, "vials": 0}
			p["points"] = points - total_cost
			p["ammo"][item["ammo_key"]] = cur_qty + total_pcs
			GameState.save_game()
			GameState.stats_updated.emit(p)
			AudioManager.play_sfx("pop")
			status_lbl.add_theme_color_override("font_color", Color(0.45, 1.0, 0.55))
			status_lbl.text = "Purchased! +%d %s" % [total_pcs, item["desc"]]
			buy_btn.disabled = true
			_refresh_data()
			# Let the player SEE the confirmation before the popup closes
			get_tree().create_timer(0.8).timeout.connect(func():
				if is_instance_valid(backdrop):
					backdrop.queue_free()
			)
		else:
			AudioManager.play_sfx("hit")
			status_lbl.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45))
			status_lbl.text = "Not enough points! You need %d more." % (total_cost - points)
			var shake = status_lbl.create_tween()
			shake.tween_property(status_lbl, "position:x", status_lbl.position.x + 6.0, 0.05)
			shake.tween_property(status_lbl, "position:x", status_lbl.position.x - 6.0, 0.05)
			shake.tween_property(status_lbl, "position:x", status_lbl.position.x, 0.05)
	)
	
	var bc = CenterContainer.new()
	bc.add_child(buy_btn)
	vbox.add_child(bc)

# ==============================================================================
# TAB 3: BOOSTERS PAGE ("Boosters" Tab) (Rule 4)
# - Grid Container: GridContainer set to columns = 2 centered on screen
# - Item Panels (4 blocks): Background game_blue_windo_a.png for large square bases
# - Inner layout: VBoxContainer stacking title, icon, price pill, purchase button
# - Assets:
#   - Fluoride Shield: fluorideshield.png
#   - Coin Multiplier: coinmultiplier.png
#   - Streak Freeze: streakfreeze.png
#   - Points Bundle: pointsbundle.png
# - Price Pills: blue_panels_a.png behind a Label (e.g. "50 COINS")
# - Purchase buttons: purchasebtn.png with "PURCHASE"
# ==============================================================================
func _get_freeze_cooldown(p: Dictionary) -> Dictionary:
	var last_freeze = float(p.get("lastFreezePurchase", 0))
	if last_freeze > 100000000000.0:
		last_freeze = last_freeze / 1000.0
	var cur = Time.get_unix_time_from_system()
	var cd_dur = 86400.0 # 24 hours (1 day cooldown)
	if last_freeze > 0:
		var elapsed = cur - last_freeze
		if elapsed < cd_dur and elapsed >= 0:
			var rem = cd_dur - elapsed
			var d = int(rem / 86400.0)
			var h = int(fmod(rem, 86400.0) / 3600.0)
			var m = int(fmod(rem, 3600.0) / 60.0)
			var s = int(fmod(rem, 60.0))
			var txt = ""
			if d >= 1:
				txt = "%dd %dh" % [d, h]
			elif h >= 1:
				txt = "%dh %dm" % [h, m]
			elif m >= 1:
				txt = "%dm" % [m]
			else:
				txt = "%ds" % [max(1, s)]
			return {"active": true, "remaining_seconds": rem, "text": txt}
	return {"active": false, "remaining_seconds": 0.0, "text": ""}

func _get_multiplier_status(p: Dictionary) -> Dictionary:
	var until = float(p.get("multiplierActiveUntil", 0))
	if until > 100000000000.0:
		until = until / 1000.0
	var cur = Time.get_unix_time_from_system()
	if until > cur:
		var rem = until - cur
		var d = int(rem / 86400.0)
		var h = int(fmod(rem, 86400.0) / 3600.0)
		var m = int(fmod(rem, 3600.0) / 60.0)
		var s = int(fmod(rem, 60.0))
		var txt = ""
		if d >= 1:
			txt = "%dd %dh" % [d, h]
		elif h >= 1:
			txt = "%dh %dm" % [h, m]
		elif m >= 1:
			txt = "%dm" % [m]
		else:
			txt = "%ds" % [max(1, s)]
		return {"active": true, "remaining_seconds": rem, "text": txt}
	return {"active": false, "remaining_seconds": 0.0, "text": ""}

# ==============================================================================
# TAB 3: BOOSTERS PAGE ("Boosters" Tab) (Rule 4)
# ==============================================================================
func _build_boosters_view(p: Dictionary):
	var avail_h = content_container.size.y
	var total_w = min(size.x - 24.0, 396.0)
	var start_x = (size.x - total_w) * 0.5
	
	var col_gap = 14.0
	var block_w = (total_w - col_gap) * 0.5
	var card_body_h = clampf((avail_h - 40.0) * 0.46, 210.0, 236.0)
	var card_total_h = card_body_h
	var row_gap = 14.0
	var total_h = card_total_h * 2.0 + row_gap
	var start_y = max(12.0, (avail_h - total_h) * 0.45)
	
	# Grid Container: 2 columns centered on screen
	var grid = GridContainer.new()
	grid.columns = 2
	grid.position = Vector2(start_x, start_y)
	grid.size = Vector2(total_w, total_h)
	grid.add_theme_constant_override("h_separation", int(col_gap))
	grid.add_theme_constant_override("v_separation", int(row_gap))
	content_container.add_child(grid)
	
	var booster_items = [
		{
			"id": "shield",
			"name": "FLUORIDE SHIELD!",
			"title_img": "res://assets/images/shop/fluorideshield_title.png",
			"img": "res://assets/images/shop/fluorideshield.png",
			"cost": 50,
			"cost_str": "50 COINS"
		},
		{
			"id": "multiplier",
			"name": "COIN MULTIPLIER!",
			"title_img": "res://assets/images/shop/coinmultiplier_title.png",
			"img": "res://assets/images/shop/coinmultiplier.png",
			"cost": 100,
			"cost_str": "100 COINS"
		},
		{
			"id": "freeze",
			"name": "STREAK FREEZE!",
			"title_img": "res://assets/images/shop/streakfreeze_title.png",
			"img": "res://assets/images/shop/streakfreeze.png",
			"cost": 150,
			"cost_str": "150 COINS"
		},
		{
			"id": "bundle",
			"name": "POINTS BUNDLE!",
			"title_img": "res://assets/images/shop/pointsbundle_title.png",
			"img": "res://assets/images/shop/pointsbundle.png",
			"cost": 250,
			"cost_str": "250 COINS"
		}
	]
	
	var freeze_st = _get_freeze_cooldown(p)
	var mult_st = _get_multiplier_status(p)
	
	for item in booster_items:
		var is_freeze = (item["id"] == "freeze")
		var is_multiplier = (item["id"] == "multiplier")
		var freeze_locked = is_freeze and freeze_st["active"]
		var mult_active = is_multiplier and mult_st["active"]
		
		var panel = Control.new()
		panel.custom_minimum_size = Vector2(block_w, card_total_h)
		panel.size = Vector2(block_w, card_total_h)
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				AudioManager.play_sfx("click")
				_show_booster_purchase_popup(item)
		)
		
		# 1. Background: itembackpanel.png
		var bg_img = TextureRect.new()
		bg_img.texture = UIHelper.load_texture_safe("res://assets/images/shop/itembackpanel.png")
		bg_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg_img.stretch_mode = TextureRect.STRETCH_SCALE
		bg_img.custom_minimum_size = Vector2(block_w, card_body_h)
		bg_img.size = Vector2(block_w, card_body_h)
		bg_img.position = Vector2.ZERO
		bg_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg_img.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		panel.add_child(bg_img)
		
		# 2. 3D Title Image (top centered, scaled to fit comfortably inside card and lowered down)
		var title_w = block_w - 32.0
		var title_h = 24.0
		var title_sz = Vector2(title_w, title_h)
		var title_rect = _create_aspect_rect(item.get("title_img", ""), title_sz)
		if title_rect.texture:
			title_rect.position = Vector2((block_w - title_w) * 0.5, 23.0)
			title_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			panel.add_child(title_rect)
		else:
			var title_lbl = Label.new()
			title_lbl.position = Vector2(8, 23)
			title_lbl.size = Vector2(block_w - 16.0, 24)
			title_lbl.text = item["name"]
			title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			UIHelper.apply_bubbly_label(title_lbl, 12, Color.BLACK, true)
			title_lbl.add_theme_color_override("font_color", Color.BLACK)
			title_lbl.add_theme_constant_override("outline_size", 0)
			title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			panel.add_child(title_lbl)
		
		# 3. Item Graphic (prominent, centered between title and purchase button)
		var scale_factor = 1.0
		if item["id"] == "shield" or item["id"] == "multiplier":
			scale_factor = 1.20
		elif item["id"] == "bundle":
			scale_factor = 1.40
			
		var base_sz_val = clampf(block_w * 0.50, 78.0, 92.0)
		var icon_sz_val = base_sz_val * scale_factor
		var icon_sz = Vector2(icon_sz_val, icon_sz_val)
		var icon = _create_aspect_rect(item["img"], icon_sz)
		
		var btn_w = min(118.0, block_w - 24.0)
		var btn_h = round(btn_w / 3.4)
		var buy_btn_y = card_body_h - btn_h - 22.0
		
		var available_space_y = buy_btn_y - 48.0
		var icon_y = 44.0 + (available_space_y - icon_sz.y) * 0.5
		icon.position = Vector2((block_w - icon_sz.x) * 0.5, icon_y)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(icon)
		
		# 4. Purchase / Action Button
		if freeze_locked:
			var wait_btn = Button.new()
			wait_btn.custom_minimum_size = Vector2(btn_w, btn_h)
			wait_btn.size = Vector2(btn_w, btn_h)
			wait_btn.position = Vector2((block_w - btn_w) * 0.5, buy_btn_y)
			var btn_st = UIHelper.create_bubbly_panel(int(btn_h * 0.5), Color(0.40, 0.48, 0.58, 0.95), Color.WHITE, 1.5)
			wait_btn.add_theme_stylebox_override("normal", btn_st)
			wait_btn.add_theme_stylebox_override("hover", btn_st)
			wait_btn.add_theme_stylebox_override("pressed", btn_st)
			wait_btn.text = "WAIT %s" % freeze_st["text"]
			wait_btn.focus_mode = Control.FOCUS_NONE
			UIHelper.apply_bubbly_label(wait_btn, 10, Color.WHITE, true)
			wait_btn.pressed.connect(func():
				AudioManager.play_sfx("click")
				_show_booster_purchase_popup(item)
			)
			panel.add_child(wait_btn)
		elif mult_active:
			var act_btn = Button.new()
			act_btn.custom_minimum_size = Vector2(btn_w, btn_h)
			act_btn.size = Vector2(btn_w, btn_h)
			act_btn.position = Vector2((block_w - btn_w) * 0.5, buy_btn_y)
			var btn_st = UIHelper.create_bubbly_panel(int(btn_h * 0.5), Color(0.92, 0.60, 0.08, 0.95), Color.WHITE, 1.5)
			act_btn.add_theme_stylebox_override("normal", btn_st)
			act_btn.add_theme_stylebox_override("hover", btn_st)
			act_btn.add_theme_stylebox_override("pressed", btn_st)
			act_btn.text = "ACTIVE (%s)" % mult_st["text"]
			act_btn.focus_mode = Control.FOCUS_NONE
			UIHelper.apply_bubbly_label(act_btn, 9, Color(0.20, 0.10, 0.0), true)
			act_btn.pressed.connect(func():
				AudioManager.play_sfx("click")
				_show_booster_purchase_popup(item)
			)
			panel.add_child(act_btn)
		else:
			var buy_btn = TextureButton.new()
			buy_btn.texture_normal = UIHelper.load_texture_safe("res://assets/images/shop/purchasebtn.png")
			buy_btn.ignore_texture_size = true
			buy_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
			buy_btn.custom_minimum_size = Vector2(btn_w, btn_h)
			buy_btn.size = Vector2(btn_w, btn_h)
			buy_btn.position = Vector2((block_w - btn_w) * 0.5, buy_btn_y)
			buy_btn.pivot_offset = Vector2(btn_w * 0.5, btn_h * 0.5)
			buy_btn.focus_mode = Control.FOCUS_NONE
			buy_btn.mouse_filter = Control.MOUSE_FILTER_STOP
			buy_btn.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			
			buy_btn.button_down.connect(func():
				var tw = buy_btn.create_tween()
				tw.tween_property(buy_btn, "scale", Vector2(0.95, 0.95), 0.08)
			)
			buy_btn.button_up.connect(func():
				var tw = buy_btn.create_tween()
				tw.tween_property(buy_btn, "scale", Vector2.ONE, 0.08)
			)
			buy_btn.pressed.connect(func():
				AudioManager.play_sfx("click")
				_show_booster_purchase_popup(item)
			)
			panel.add_child(buy_btn)
		
		grid.add_child(panel)

# ==============================================================================
# BOOSTER PURCHASE CONFIRMATION POPUP MODAL
# ==============================================================================
func _show_booster_purchase_popup(item: Dictionary):
	_cleanup_modals()
		
	var p = GameState.get_active_profile()
	var safe_sz = UIHelper.get_viewport_safe_size(self)
	
	var is_freeze = (item["id"] == "freeze")
	var is_multiplier = (item["id"] == "multiplier")
	var freeze_st = _get_freeze_cooldown(p)
	var mult_st = _get_multiplier_status(p)
	var freeze_locked = is_freeze and freeze_st["active"]
	var mult_active = is_multiplier and mult_st["active"]
	
	var dlg = UIHelper.create_modal_dialog(modal_layer, 200, Color(0, 0, 0, 0.65))
	var backdrop = dlg["overlay"]
	var center = dlg["center"]
	
	var win_w = min(safe_sz.x - 32.0, 330.0)
	var win_h = 415.0
	var win = _create_nine_patch("res://assets/images/shop/game_blue_window_tall.png", 32)
	win.custom_minimum_size = Vector2(win_w, win_h)
	win.size = Vector2(win_w, win_h)
	win.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	win.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	center.add_child(win)
	
	var close_btn = UIHelper.create_close_button(Vector2(32, 32))
	close_btn.position = Vector2(win_w - 24.0, -10.0)
	close_btn.pressed.connect(func():
		AudioManager.play_sfx("click")
		backdrop.queue_free()
	)
	win.add_child(close_btn)
	
	var vbox = VBoxContainer.new()
	vbox.position = Vector2(20, 16)
	vbox.size = Vector2(win_w - 40.0, win_h - 32.0)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 6)
	win.add_child(vbox)
	
	var title_img_path = item.get("title_img", "")
	var title_img_rect = _create_aspect_rect(title_img_path, Vector2(min(win_w - 110.0, 190.0), 26.0))
	if title_img_rect.texture:
		vbox.add_child(title_img_rect)
	else:
		var title_lbl = Label.new()
		title_lbl.text = "BOOSTER PURCHASE"
		title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UIHelper.apply_bubbly_label(title_lbl, 14, Color.WHITE, true)
		vbox.add_child(title_lbl)
		
		var name_lbl = Label.new()
		name_lbl.text = item["name"]
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UIHelper.apply_bubbly_label(name_lbl, 14, Color(0.85, 0.93, 1.0), true)
		vbox.add_child(name_lbl)
		
	# Subtitle status badge if locked / active
	if freeze_locked:
		var stat_lbl = Label.new()
		stat_lbl.text = "LOCKED · 24-HOUR COOLDOWN"
		stat_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UIHelper.apply_bubbly_label(stat_lbl, 12, Color(1.0, 0.85, 0.40), true)
		vbox.add_child(stat_lbl)
	elif mult_active:
		var stat_lbl = Label.new()
		stat_lbl.text = "ACTIVE · 24-HOUR BOOST"
		stat_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UIHelper.apply_bubbly_label(stat_lbl, 12, Color(1.0, 0.90, 0.40), true)
		vbox.add_child(stat_lbl)
	
	var p_scale = 1.0
	if item["id"] == "shield" or item["id"] == "multiplier":
		p_scale = 1.20
	elif item["id"] == "bundle":
		p_scale = 1.40
	var pop_icon_sz = round(68.0 * p_scale)
	
	var img_box = CenterContainer.new()
	img_box.custom_minimum_size = Vector2(win_w - 40.0, max(75.0, pop_icon_sz + 6.0))
	vbox.add_child(img_box)
	
	var img = _create_aspect_rect(item["img"], Vector2(pop_icon_sz, pop_icon_sz))
	img_box.add_child(img)
	
	# In Inventory count badge (for inventory items like Fluoride Shield & Streak Freeze)
	if item["id"] == "shield" or item["id"] == "freeze":
		var inv = p.get("inventory", {})
		var owned_qty = 0
		if typeof(inv) == TYPE_DICTIONARY:
			owned_qty = int(inv.get(item["id"], 0))
		var inv_lbl = Label.new()
		inv_lbl.text = "In Inventory: %d" % owned_qty
		inv_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UIHelper.apply_bubbly_label(inv_lbl, 13, Color(1.0, 0.88, 0.35), true)
		vbox.add_child(inv_lbl)
	
	# Description explaining the purchase benefit or cooldown lock
	var desc_lbl = Label.new()
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.custom_minimum_size = Vector2(win_w - 48.0, 48)
	
	if freeze_locked:
		desc_lbl.text = "Streak Freeze can be purchased once every 24 hours.\nAvailable to purchase again in %s." % freeze_st["text"]
	elif mult_active:
		desc_lbl.text = "Coin Multiplier is active for the next %s!\nAll coins earned are doubled. You can purchase again once expired." % mult_st["text"]
	else:
		match item["id"]:
			"multiplier":
				desc_lbl.text = "For 24 hours, all coins earned will be doubled across minigames and challenges!"
			"bundle":
				desc_lbl.text = "Pay %d Coins to instantly receive a bundle of 500 bonus Points to level up faster!" % item["cost"]
			"shield":
				desc_lbl.text = "Protects your tooth enamel in battle and prevents losing your progress on missed days!"
			"freeze":
				desc_lbl.text = "Freezes your daily brushing streak if you miss a day so your hard-earned streak stays safe! (Once every 24 hours)"
			_:
				desc_lbl.text = "Boost your Pearly Whites journey with this special item!"
			
	UIHelper.apply_bubbly_label(desc_lbl, 11, Color(0.90, 0.96, 1.0), false)
	vbox.add_child(desc_lbl)
	
	# Price Pill / Cooldown Pill
	var p_pill = Panel.new()
	p_pill.custom_minimum_size = Vector2(170, 32)
	p_pill.size = Vector2(170, 32)
	var pp_color = Color(0.25, 0.35, 0.48, 0.95) if (freeze_locked or mult_active) else Color(0.20, 0.58, 0.90)
	var pp_st = UIHelper.create_bubbly_panel(16, pp_color, Color.WHITE, 1.5)
	p_pill.add_theme_stylebox_override("panel", pp_st)
	
	var coin_ic = _create_aspect_rect("res://assets/images/shop/gold_tooth_coin.png", Vector2(22, 22))
	coin_ic.position = Vector2(14, 5)
	p_pill.add_child(coin_ic)
	
	var plbl = Label.new()
	plbl.position = Vector2(40, 0)
	plbl.size = Vector2(120, 32)
	if freeze_locked:
		plbl.text = "WAIT %s" % freeze_st["text"]
	elif mult_active:
		plbl.text = "ACTIVE: %s" % mult_st["text"]
	else:
		plbl.text = "%d COINS" % item["cost"]
	plbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(plbl, 12, Color.WHITE, true)
	p_pill.add_child(plbl)
	
	var pill_center = CenterContainer.new()
	pill_center.add_child(p_pill)
	vbox.add_child(pill_center)
	
	# Purchase / Action Button
	if freeze_locked:
		var locked_btn = Button.new()
		locked_btn.custom_minimum_size = Vector2(150, 38)
		locked_btn.size = Vector2(150, 38)
		var btn_st = UIHelper.create_bubbly_panel(19, Color(0.40, 0.48, 0.58, 0.95), Color.WHITE, 2.0)
		locked_btn.add_theme_stylebox_override("normal", btn_st)
		locked_btn.add_theme_stylebox_override("hover", btn_st)
		locked_btn.add_theme_stylebox_override("pressed", btn_st)
		locked_btn.text = "LOCKED (%s)" % freeze_st["text"]
		locked_btn.focus_mode = Control.FOCUS_NONE
		UIHelper.apply_bubbly_label(locked_btn, 11, Color(1.0, 0.90, 0.60), true)
		locked_btn.pressed.connect(func():
			AudioManager.play_sfx("hit")
			GameState.push_toast("Streak Freeze Locked!", "Available to buy again in %s!" % freeze_st["text"], "", "blue")
		)
		var bc = CenterContainer.new()
		bc.add_child(locked_btn)
		vbox.add_child(bc)
	elif mult_active:
		var active_btn = Button.new()
		active_btn.custom_minimum_size = Vector2(150, 38)
		active_btn.size = Vector2(150, 38)
		var btn_st = UIHelper.create_bubbly_panel(19, Color(0.92, 0.60, 0.08, 0.95), Color.WHITE, 2.0)
		active_btn.add_theme_stylebox_override("normal", btn_st)
		active_btn.add_theme_stylebox_override("hover", btn_st)
		active_btn.add_theme_stylebox_override("pressed", btn_st)
		active_btn.text = "ACTIVE (%s)" % mult_st["text"]
		active_btn.focus_mode = Control.FOCUS_NONE
		UIHelper.apply_bubbly_label(active_btn, 11, Color(0.20, 0.10, 0.0), true)
		active_btn.pressed.connect(func():
			AudioManager.play_sfx("coin")
			GameState.push_toast("Multiplier Active!", "Doubling all coins for %s more!" % mult_st["text"], "", "green")
		)
		var bc = CenterContainer.new()
		bc.add_child(active_btn)
		vbox.add_child(bc)
	else:
		var buy_btn = _create_aspect_button("res://assets/images/shop/purchasebtn.png", Vector2(130, 38))
		buy_btn.pressed.connect(func():
			var p_now = GameState.get_active_profile()
			var cns = int(round(float(p_now.get("coins", 0))))
			if cns >= item["cost"]:
				p_now["coins"] = cns - item["cost"]
				if not p_now.has("inventory") or typeof(p_now["inventory"]) != TYPE_DICTIONARY:
					p_now["inventory"] = {"shield": 0, "freeze": 0}
				if item["id"] == "shield":
					p_now["inventory"]["shield"] = int(p_now["inventory"].get("shield", 0)) + 1
					AudioManager.play_sfx("coin")
					GameState.push_toast("Shield Acquired!", "Fluoride Shield added to inventory!", "", "green")
				elif item["id"] == "freeze":
					p_now["inventory"]["freeze"] = int(p_now["inventory"].get("freeze", 0)) + 1
					p_now["lastFreezePurchase"] = Time.get_unix_time_from_system()
					AudioManager.play_sfx("coin")
					GameState.push_toast("Streak Freeze!", "Streak Freeze added! (24-hour cooldown active)", "", "green")
				elif item["id"] == "multiplier":
					p_now["multiplierActiveUntil"] = Time.get_unix_time_from_system() + 86400
					AudioManager.play_sfx("coin")
					GameState.push_toast("2x Coins Active!", "All coins doubled for the next 24 hours!", "", "green")
					_spawn_rain_celebration("res://assets/images/shop/gold_tooth_coin.png", 35)
				elif item["id"] == "bundle":
					p_now["points"] = int(round(float(p_now.get("points", 0)))) + 500
					AudioManager.play_sfx("coin")
					GameState.push_toast("Points Added!", "500 Points added to your total!", "", "green")
					_spawn_rain_celebration("res://assets/images/shop/purple_star_points.png", 35)
				GameState.save_game()
				GameState.stats_updated.emit(p_now)
				backdrop.queue_free()
				_refresh_data()
			else:
				AudioManager.play_sfx("hit")
				GameState.push_toast("Need More Coins!", "Complete games & brushing to earn coins!", "", "orange")
		)
		var bc = CenterContainer.new()
		bc.add_child(buy_btn)
		vbox.add_child(bc)

# ==============================================================================
# RAIN CELEBRATION EFFECT (Coins / Points rain down across the screen)
# ==============================================================================
func _spawn_rain_celebration(icon_path: String, count: int = 20):
	var rain_layer = Control.new()
	rain_layer.anchors_preset = Control.PRESET_FULL_RECT
	rain_layer.size = size
	rain_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rain_layer.z_index = 80
	rain_layer.clip_contents = true
	add_child(rain_layer)
	
	var tex = UIHelper.load_texture_safe(icon_path)
	if not tex:
		tex = UIHelper.load_texture_safe("res://assets/images/shop/gold_tooth_coin.png")
		
	var completed_tweens := 0
	var total_items := count
	
	for i in range(count):
		var tex_rect = TextureRect.new()
		tex_rect.texture = tex
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var icon_sz = randf_range(18.0, 30.0)
		tex_rect.custom_minimum_size = Vector2(icon_sz, icon_sz)
		tex_rect.size = Vector2(icon_sz, icon_sz)
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tex_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		
		# Distribute across width
		var start_x = randf_range(16.0, max(size.x - 50.0, 100.0))
		var start_y = randf_range(-180.0, -30.0)
		tex_rect.position = Vector2(start_x, start_y)
		tex_rect.rotation = randf_range(-0.6, 0.6)
		rain_layer.add_child(tex_rect)
		
		# Fall animation with gravity feel
		var fall_dur = randf_range(1.1, 1.7)
		var delay = randf_range(0.0, 0.45)
		var target_y = size.y + 60.0
		var drift_x = start_x + randf_range(-35.0, 35.0)
		
		var tw = tex_rect.create_tween()
		if delay > 0.0:
			tw.tween_interval(delay)
		tw.parallel().tween_property(tex_rect, "position:y", target_y, fall_dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(tex_rect, "position:x", drift_x, fall_dur).set_trans(Tween.TRANS_SINE)
		tw.parallel().tween_property(tex_rect, "rotation", tex_rect.rotation + randf_range(-2.5, 2.5), fall_dur)
		
		tw.finished.connect(func():
			completed_tweens += 1
			tex_rect.queue_free()
			if completed_tweens >= total_items:
				rain_layer.queue_free()
		)

# ==============================================================================
# WEAPON PURCHASE CONFIRMATION POPUP MODAL
# ==============================================================================
func _cleanup_modals():
	if modal_layer and is_instance_valid(modal_layer):
		for c in modal_layer.get_children():
			if is_instance_valid(c):
				c.queue_free()
	var main_node = get_tree().root.get_node_or_null("Main") if is_inside_tree() else null
	if main_node and is_instance_valid(main_node):
		for c in main_node.get_children():
			if is_instance_valid(c) and (c.name == "ModalOverlay" or c.name.begins_with("Modal")):
				c.queue_free()

func _purchase_weapon(w_def: Dictionary, lvl: int, cost: int, popup_to_close: Control = null) -> bool:
	var p = GameState.get_active_profile()
	var coins = int(round(float(p.get("coins", 0))))
	if coins < cost:
		AudioManager.play_sfx("hit")
		GameState.push_toast("Need More Coins!", "You need %d coins (have %d)!" % [cost, coins], "", "orange")
		return false
		
	p["coins"] = coins - cost
	var tiers = _get_owned_tiers(p, w_def["id"])
	if not tiers.has(lvl):
		tiers.append(lvl)
		tiers.sort()
	if not p.has("weaponTiers") or typeof(p["weaponTiers"]) != TYPE_DICTIONARY:
		p["weaponTiers"] = {"brush": [1], "paste": [], "wash": [], "floss": []}
	p["weaponTiers"][w_def["id"]] = tiers
	if not p.has("weaponLevels") or typeof(p["weaponLevels"]) != TYPE_DICTIONARY:
		p["weaponLevels"] = {"brush": 1, "paste": 0, "wash": 0, "floss": 0}
	p["weaponLevels"][w_def["id"]] = max(int(p["weaponLevels"].get(w_def["id"], 0)), lvl)
	if not p.has("loadout") or typeof(p["loadout"]) != TYPE_DICTIONARY:
		p["loadout"] = {"brush": 1, "paste": 0, "wash": 0, "floss": 0}
	p["loadout"][w_def["id"]] = lvl
	
	GameState.save_game()
	GameState.stats_updated.emit(p)
	AudioManager.play_sfx("unlock")
	GameState.push_toast("Glass Broken!", "%s (LVL %d) Unlocked!" % [get_weapon_full_name(w_def, lvl), lvl], "", "green")
	
	if popup_to_close and is_instance_valid(popup_to_close):
		popup_to_close.queue_free()
		
	_cleanup_modals()
	_refresh_data()
	
	if lvl == 3:
		_spawn_bubble_product_celebration()
		
	return true

func _show_weapon_purchase_popup(w_def: Dictionary, lvl: int, cost: int):
	_cleanup_modals()
		
	var safe_sz = UIHelper.get_viewport_safe_size(self)
	var dlg = UIHelper.create_modal_dialog(modal_layer, 200, Color(0, 0, 0, 0.65))
	var backdrop = dlg["overlay"]
	var center = dlg["center"]
	
	var win_w = min(safe_sz.x - 32.0, 330.0)
	var win_h = 360.0
	var win = _create_nine_patch("res://assets/images/shop/game_blue_window_tall.png", 32)
	win.custom_minimum_size = Vector2(win_w, win_h)
	win.size = Vector2(win_w, win_h)
	win.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	win.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	center.add_child(win)
	
	var close_btn = UIHelper.create_close_button(Vector2(32, 32))
	close_btn.position = Vector2(win_w - 24.0, -10.0)
	close_btn.pressed.connect(func():
		AudioManager.play_sfx("click")
		_cleanup_modals()
	)
	win.add_child(close_btn)
	
	var vbox = VBoxContainer.new()
	vbox.position = Vector2(20, 20)
	vbox.size = Vector2(win_w - 40.0, win_h - 40.0)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 10)
	win.add_child(vbox)
	
	var title_img_path = get_weapon_title_img(w_def, lvl)
	var title_img_rect = _create_aspect_rect(title_img_path, Vector2(win_w - 60.0, 36.0))
	if title_img_rect.texture:
		vbox.add_child(title_img_rect)
		
		var lvl_lbl = Label.new()
		lvl_lbl.text = "LEVEL %d UPGRADE" % lvl
		lvl_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UIHelper.apply_bubbly_label(lvl_lbl, 13, Color(0.85, 0.93, 1.0), true)
		vbox.add_child(lvl_lbl)
	else:
		var title_lbl = Label.new()
		title_lbl.text = "UNLOCK LEVEL %d" % lvl
		title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UIHelper.apply_bubbly_label(title_lbl, 16, Color.WHITE, true)
		vbox.add_child(title_lbl)
		
		var name_lbl = Label.new()
		name_lbl.text = "%s" % get_weapon_full_name(w_def, lvl)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UIHelper.apply_bubbly_label(name_lbl, 12, Color(0.85, 0.93, 1.0), true)
		vbox.add_child(name_lbl)
	
	var img_box = CenterContainer.new()
	img_box.custom_minimum_size = Vector2(win_w - 40.0, 90)
	vbox.add_child(img_box)
	
	var img = _create_aspect_rect(w_def["images"][lvl - 1], Vector2(80, 80))
	img_box.add_child(img)
	
	# Price Pill
	var p_pill = Panel.new()
	p_pill.custom_minimum_size = Vector2(150, 32)
	p_pill.size = Vector2(150, 32)
	var pp_st = UIHelper.create_bubbly_panel(16, Color(0.20, 0.58, 0.90), Color.WHITE, 1.5)
	p_pill.add_theme_stylebox_override("panel", pp_st)
	
	var coin_ic = _create_aspect_rect("res://assets/images/shop/gold_tooth_coin.png", Vector2(22, 22))
	coin_ic.position = Vector2(14, 5)
	p_pill.add_child(coin_ic)
	
	var plbl = Label.new()
	plbl.position = Vector2(40, 0)
	plbl.size = Vector2(100, 32)
	plbl.text = "%d COINS" % cost
	plbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(plbl, 13, Color.WHITE, true)
	p_pill.add_child(plbl)
	
	var pill_center = CenterContainer.new()
	pill_center.add_child(p_pill)
	vbox.add_child(pill_center)
	
	# Yellow PURCHASE button (image already contains "PURCHASE" graphic)
	var buy_btn = _create_aspect_button("res://assets/images/shop/purchasebtn.png", Vector2(130, 38))
	buy_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	buy_btn.pressed.connect(func():
		_purchase_weapon(w_def, lvl, cost, backdrop)
	)
	
	var btn_center = CenterContainer.new()
	btn_center.add_child(buy_btn)
	vbox.add_child(btn_center)

func _spawn_bubble_product_celebration():
	var safe_sz = UIHelper.get_viewport_safe_size(self)
	
	var celebration_layer = Control.new()
	celebration_layer.name = "BubbleProductCelebrationLayer"
	celebration_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	celebration_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	celebration_layer.z_index = 250
	celebration_layer.clip_contents = true
	add_child(celebration_layer)
	
	# Load bubble and tooth textures
	var bubble_textures: Array[Texture2D] = []
	var tooth_textures: Array[Texture2D] = []
	
	var bubble_paths = [
		"res://assets/images/shop/colorful_bubble.png",
		"res://assets/images/shop/colorful_bubble_1.png",
		"res://assets/images/shop/colorful_bubble_2.png",
		"res://assets/images/shop/bubble_icon.png",
		"res://assets/images/createprofilescreen/transparent_bubble.png",
		"res://assets/images/createprofilescreen/colorful_bubble.png"
	]
	for bp in bubble_paths:
		var tex = UIHelper.load_texture_safe(bp)
		if tex and not bubble_textures.has(tex):
			bubble_textures.append(tex)
			
	var tooth_paths = [
		"res://assets/images/congratulations/plain_tooth_icon.png",
		"res://assets/images/shop/golden_tooth_coin.png",
		"res://assets/images/congratulations/gold_tooth_coin.png"
	]
	for tp in tooth_paths:
		var tex = UIHelper.load_texture_safe(tp)
		if tex and not tooth_textures.has(tex):
			tooth_textures.append(tex)
			
	var confetti_colors = [
		Color("#33ccff"), Color("#66e0ff"), Color("#ff77aa"), Color("#ffd23f"), 
		Color("#a855f7"), Color("#38bdf8"), Color("#ffffff"), Color("#67e8f9")
	]
	
	var center = Vector2(safe_sz.x * 0.5, safe_sz.y * 0.45)
	
	# 1. Immediate Explosive Radial Burst of Bubbles and Teeth (60 items)
	for i in range(60):
		var is_bubble = (i % 2 == 0)
		var node: Control
		
		if is_bubble and not bubble_textures.is_empty():
			var tr = TextureRect.new()
			tr.texture = bubble_textures[randi() % bubble_textures.size()]
			var sz = randf_range(12.0, 22.0)
			tr.custom_minimum_size = Vector2(sz, sz)
			tr.size = Vector2(sz, sz)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			node = tr
		elif not is_bubble and not tooth_textures.is_empty():
			var tr = TextureRect.new()
			tr.texture = tooth_textures[randi() % tooth_textures.size()]
			var sz = randf_range(12.0, 20.0)
			tr.custom_minimum_size = Vector2(sz, sz)
			tr.size = Vector2(sz, sz)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			node = tr
		else:
			var cr = ColorRect.new()
			cr.color = confetti_colors[randi() % confetti_colors.size()]
			var sz = randf_range(6.0, 10.0)
			cr.custom_minimum_size = Vector2(sz, sz)
			cr.size = Vector2(sz, sz)
			node = cr
			
		node.position = center
		node.pivot_offset = node.size * 0.5
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		celebration_layer.add_child(node)
		
		var angle = randf_range(0, TAU)
		var speed = randf_range(120.0, max(safe_sz.x, safe_sz.y) * 0.60)
		var target_pos = center + Vector2(cos(angle) * speed, sin(angle) * speed - randf_range(15, 70))
		var dur = randf_range(1.4, 2.4)
		
		var tw = node.create_tween()
		tw.set_parallel(true)
		tw.tween_property(node, "position", target_pos, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(node, "rotation_degrees", randf_range(-360, 360), dur)
		tw.tween_property(node, "scale", Vector2(randf_range(0.7, 1.0), randf_range(0.7, 1.0)), dur * 0.4)
		tw.tween_property(node, "modulate:a", 0.0, dur * 0.45).set_delay(dur * 0.55)
		tw.finished.connect(func(): if is_instance_valid(node): node.queue_free())
		
	# 2. Rising Fluttering Bubbles & Cascading Teeth Shower (35 items across full page)
	for j in range(35):
		var is_bubble = (j % 2 == 0)
		var node: Control
		
		if is_bubble and not bubble_textures.is_empty():
			var tr = TextureRect.new()
			tr.texture = bubble_textures[randi() % bubble_textures.size()]
			var sz = randf_range(14.0, 24.0)
			tr.custom_minimum_size = Vector2(sz, sz)
			tr.size = Vector2(sz, sz)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			node = tr
		elif not is_bubble and not tooth_textures.is_empty():
			var tr = TextureRect.new()
			tr.texture = tooth_textures[randi() % tooth_textures.size()]
			var sz = randf_range(12.0, 20.0)
			tr.custom_minimum_size = Vector2(sz, sz)
			tr.size = Vector2(sz, sz)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			node = tr
		else:
			var cr = ColorRect.new()
			cr.color = confetti_colors[randi() % confetti_colors.size()]
			var sz = randf_range(6.0, 10.0)
			cr.custom_minimum_size = Vector2(sz, sz)
			cr.size = Vector2(sz, sz)
			node = cr
			
		var start_x = randf_range(20.0, safe_sz.x - 20.0)
		var start_y = safe_sz.y + randf_range(10.0, 50.0) if is_bubble else randf_range(-50.0, -10.0)
		var end_y = randf_range(-60.0, -20.0) if is_bubble else safe_sz.y + randf_range(20.0, 60.0)
		
		node.position = Vector2(start_x, start_y)
		node.pivot_offset = node.size * 0.5
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		celebration_layer.add_child(node)
		
		var delay = randf_range(0.05, 0.7)
		var dur = randf_range(2.2, 3.8)
		var tw = node.create_tween()
		tw.tween_interval(delay)
		tw.parallel().tween_property(node, "position:y", end_y, dur).set_trans(Tween.TRANS_LINEAR)
		tw.parallel().tween_property(node, "position:x", start_x + randf_range(-60.0, 60.0), dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.parallel().tween_property(node, "rotation_degrees", randf_range(-270, 270), dur)
		tw.parallel().tween_property(node, "modulate:a", 0.0, dur * 0.35).set_delay(dur * 0.65)
		tw.finished.connect(func(): if is_instance_valid(node): node.queue_free())
		
	# Clean up layer after celebration completes
	get_tree().create_timer(4.5).timeout.connect(func():
		if is_instance_valid(celebration_layer):
			celebration_layer.queue_free()
	)

# ==============================================================================
# OWNED WEAPON BREAKDOWN POPUP MODAL
# Displays in-depth weapon stats, damage breakdown, mechanics, and why it's amazing
# Special celebratory showcase for Level 3 Bubble products
# ==============================================================================
const WEAPON_BREAKDOWN_DATA = {
	"brush": {
		1: {
			"name": "Toothbrush",
			"badge": "LVL 1 · STANDARD WEAPON",
			"badge_color": Color(0.18, 0.55, 0.90),
			"damage_text": "1 DMG / Sweep",
			"type_text": "Primary Sweeper",
			"what_it_does": "Your trusty first weapon! Sweeps away sugar minions in close and mid-range combat with steady bristle power.",
			"how_amazing": "Reliable, nimble, and fast! Sweeps incoming minions back and provides steady frontline defense against sugar bugs."
		},
		2: {
			"name": "Gold Toothbrush",
			"badge": "LVL 2 · GILDED UPGRADE",
			"badge_color": Color(0.95, 0.75, 0.15),
			"damage_text": "2 DMG (+100% Boost!)",
			"type_text": "Reinforced Golden Sweeper",
			"what_it_does": "Crafted from reinforced golden enamel fibers, slicing through tough sugar armor with twice the strength of standard bristles.",
			"how_amazing": "Double the damage output! Sweeps through enemy ranks with lightning speed and gleaming golden prestige."
		},
		3: {
			"name": "Bubble Brush",
			"badge": "LEGENDARY BUBBLE PRODUCT · LVL 3",
			"badge_color": Color(0.18, 0.78, 0.95),
			"damage_text": "4 DMG + Splash Foam AOE",
			"type_text": "Ultimate Foaming Powerhouse",
			"what_it_does": "Unleashes continuous high-pressure micro-bubbles that explode on contact, cleansing whole clusters of minions simultaneously!",
			"how_amazing": "THE ULTIMATE BUBBLE BRUSH! Drenches the entire battlefield in glorious effervescent foam, vaporizing sugar armor and turning terrifying candy bosses into sparkling clean memories with effortless ease!"
		}
	},
	"paste": {
		1: {
			"name": "Paste Pistol",
			"badge": "LVL 1 · STANDARD WEAPON",
			"badge_color": Color(0.18, 0.55, 0.90),
			"damage_text": "1 DMG / Shot",
			"type_text": "Long-Range Projectile",
			"what_it_does": "Fires straight-flying blobs of active fluoride paste to snipe distant candy enemies before they reach your front line.",
			"how_amazing": "Pinpoint accuracy! Eliminates sneaky snipers and long-range candy minions from total safety."
		},
		2: {
			"name": "Gold Paste Pistol",
			"badge": "LVL 2 · GILDED UPGRADE",
			"badge_color": Color(0.95, 0.75, 0.15),
			"damage_text": "3 DMG / Shot (Triple Power!)",
			"type_text": "Heavy Kinetic Blaster",
			"what_it_does": "Launches high-velocity golden paste slugs with extreme kinetic force, punching through multiple layers of candy defense.",
			"how_amazing": "Massive single-target punch! Knocks enemy bosses back on their heels with heavy golden impact power."
		},
		3: {
			"name": "Bubble Paste",
			"badge": "LEGENDARY BUBBLE PRODUCT · LVL 3",
			"badge_color": Color(0.18, 0.78, 0.95),
			"damage_text": "5 DMG + Chaining Energy Arcs",
			"type_text": "Electrifying Bubble Blaster",
			"what_it_does": "Shoots glowing iridescent bubble-infused paste that explodes into energetic lightning arcs, hitting the target and automatically shocking 2 nearby minions!",
			"how_amazing": "THE UNSTOPPABLE BUBBLE PASTE! One shot clears whole battle formations as magical electric bubbles chain across the horizon, vaporizing candy hordes in seconds!"
		}
	},
	"wash": {
		1: {
			"name": "Mouthwash Blast",
			"badge": "LVL 1 · STANDARD WEAPON",
			"badge_color": Color(0.18, 0.55, 0.90),
			"damage_text": "3 DMG / Splash",
			"type_text": "Lobbed Splash Bomb",
			"what_it_does": "Lobs a pressurized bottle of refreshing mint antiseptic that shatters on impact, dealing area-of-effect damage to all clustered enemies.",
			"how_amazing": "Superb crowd control! Perfect for wiping out tightly grouped candy minions when they try to overwhelm your defenses."
		},
		2: {
			"name": "Gold Mouthwash Blast",
			"badge": "LVL 2 · GILDED UPGRADE",
			"badge_color": Color(0.95, 0.75, 0.15),
			"damage_text": "6 DMG + Wider Area Blast",
			"type_text": "Concussive Shockwave Bomb",
			"what_it_does": "Detonates with a thunderous golden shockwave, dealing heavy double-strength splash damage over an expanded blast radius.",
			"how_amazing": "Crushing explosive force! Clears congested lanes in a single glorious golden detonation, dissolving sugary armor instantly."
		},
		3: {
			"name": "Bubble Wash",
			"badge": "LEGENDARY BUBBLE PRODUCT · LVL 3",
			"badge_color": Color(0.18, 0.78, 0.95),
			"damage_text": "10 DMG + Tidal Wave Deluge",
			"type_text": "Colossal Bubbly Tsunami",
			"what_it_does": "Unleashes an immense tidal vortex of hyper-concentrated bubbly mouthwash that floods the battlefield, dealing colossal damage to everything in its path!",
			"how_amazing": "THE SUPREME BUBBLE TSUNAMI! The most devastating area-of-effect superweapon in all of Mulinia, wiping out whole armies of candy monsters in a roaring tidal wave of pure sparkle!"
		}
	},
	"floss": {
		1: {
			"name": "Floss Lasso",
			"badge": "LVL 1 · STANDARD WEAPON",
			"badge_color": Color(0.18, 0.55, 0.90),
			"damage_text": "1 DMG + 1.5s Snare",
			"type_text": "Precision Tether",
			"what_it_does": "Throws high-tensile dental floss to ensnare and immobilize dangerous candy enemies, freezing them right in their tracks.",
			"how_amazing": "Tactical mastery! Stops fast-running candy rushers instantly so you can line up easy follow-up attacks."
		},
		2: {
			"name": "Gold Floss Lasso",
			"badge": "LVL 2 · GILDED UPGRADE",
			"badge_color": Color(0.95, 0.75, 0.15),
			"damage_text": "3 DMG + 2.5s Heavy Snare",
			"type_text": "Reinforced Gold Constrictor",
			"what_it_does": "Spins reinforced golden wire that binds targets in a tight constricting hold, inflicting continuous damage while locking them down for 2.5 seconds.",
			"how_amazing": "Total battlefield lockdown! Completely halts elite sugar soldiers and leaves bosses helpless against your assault."
		},
		3: {
			"name": "Bubble Floss",
			"badge": "LEGENDARY BUBBLE PRODUCT · LVL 3",
			"badge_color": Color(0.18, 0.78, 0.95),
			"damage_text": "9999 DMG (Instant Vaporization!)",
			"type_text": "Reality-Shattering Bubble Snare",
			"what_it_does": "Tethers any minion into an impenetrable iridescent bubble sphere for 2 seconds before violently popping and instantly disintegrating them into sparkling star cubes!",
			"how_amazing": "THE LEGENDARY BUBBLE FLOSS! Nothing can survive its magical iridescent bubble trap. Wraps, lifts, and instantly vaporizes foes in a shower of sparkling glitter!"
		}
	}
}

func _show_owned_weapon_breakdown_popup(w_def: Dictionary, lvl: int):
	_cleanup_modals()
		
	var safe_sz = UIHelper.get_viewport_safe_size(self)
	var dlg = UIHelper.create_modal_dialog(modal_layer, 200, Color(0, 0, 0, 0.70))
	var backdrop = dlg["overlay"]
	var center = dlg["center"]
	
	var is_lvl3 = (lvl == 3)
	var w_id = str(w_def.get("id", ""))
	var w_data = WEAPON_BREAKDOWN_DATA.get(w_id, {}).get(lvl, {})
	
	var win_w = min(safe_sz.x - 28.0, 360.0)
	var win_h = min(safe_sz.y - 36.0, 560.0)
	var win = _create_nine_patch("res://assets/images/shop/game_blue_window_tall.png", 32)
	win.custom_minimum_size = Vector2(win_w, win_h)
	win.size = Vector2(win_w, win_h)
	win.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	win.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	center.add_child(win)
	
	var close_btn = UIHelper.create_close_button(Vector2(32, 32))
	close_btn.position = Vector2(win_w - 24.0, -10.0)
	close_btn.pressed.connect(func():
		AudioManager.play_sfx("click")
		backdrop.queue_free()
	)
	win.add_child(close_btn)
	
	var vbox = VBoxContainer.new()
	vbox.position = Vector2(16, 14)
	vbox.size = Vector2(win_w - 32.0, win_h - 28.0)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 6)
	win.add_child(vbox)
	
	# Top Badge
	var badge_panel = Panel.new()
	var b_w = min(win_w - 40.0, 250.0)
	badge_panel.custom_minimum_size = Vector2(b_w, 24)
	badge_panel.size = Vector2(b_w, 24)
	var badge_color = w_data.get("badge_color", Color(0.20, 0.60, 0.95))
	var bp_st = UIHelper.create_bubbly_panel(12, badge_color, Color.WHITE, 1.5)
	badge_panel.add_theme_stylebox_override("panel", bp_st)
	
	var badge_lbl = Label.new()
	badge_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	badge_lbl.text = w_data.get("badge", "OWNED WEAPON")
	badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(badge_lbl, 10, Color.WHITE, true)
	badge_panel.add_child(badge_lbl)
	
	var bc_badge = CenterContainer.new()
	bc_badge.add_child(badge_panel)
	vbox.add_child(bc_badge)
	
	# 3D Title Image or Label
	var title_img_path = get_weapon_title_img(w_def, lvl)
	var title_img_rect = _create_aspect_rect(title_img_path, Vector2(min(win_w - 60.0, 210.0), 30.0))
	if title_img_rect.texture:
		vbox.add_child(title_img_rect)
	else:
		var name_lbl = Label.new()
		name_lbl.text = get_weapon_full_name(w_def, lvl)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UIHelper.apply_bubbly_label(name_lbl, 15, Color.WHITE, true)
		vbox.add_child(name_lbl)
		
	# Artwork Icon in Center with gentle float animation
	var img_box = CenterContainer.new()
	img_box.custom_minimum_size = Vector2(win_w - 40.0, 68)
	vbox.add_child(img_box)
	
	var img_sz = Vector2(72, 72) if is_lvl3 else Vector2(64, 64)
	var img = _create_aspect_rect(w_def["images"][lvl - 1], img_sz)
	img.pivot_offset = img_sz * 0.5
	img_box.add_child(img)
	
	var float_tw = img.create_tween().set_loops()
	float_tw.tween_property(img, "position:y", -4.0, 0.9).as_relative().set_trans(Tween.TRANS_SINE)
	float_tw.tween_property(img, "position:y", 4.0, 0.9).as_relative().set_trans(Tween.TRANS_SINE)
	
	# Damage & Type Stats Pill
	var stats_pill = Panel.new()
	var sp_w = win_w - 36.0
	stats_pill.custom_minimum_size = Vector2(sp_w, 30)
	stats_pill.size = Vector2(sp_w, 30)
	var sp_color = Color(0.08, 0.22, 0.42, 0.95) if is_lvl3 else Color(0.12, 0.32, 0.55, 0.95)
	var sp_st = UIHelper.create_bubbly_panel(16, sp_color, Color(0.70, 0.88, 1.0), 1.5)
	stats_pill.add_theme_stylebox_override("panel", sp_st)
	
	var stats_hbox = HBoxContainer.new()
	stats_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	stats_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	stats_hbox.add_theme_constant_override("separation", 10)
	stats_pill.add_child(stats_hbox)
	
	var dmg_lbl = Label.new()
	dmg_lbl.text = "%s" % w_data.get("damage_text", "Damage")
	UIHelper.apply_bubbly_label(dmg_lbl, 10, Color(1.0, 0.88, 0.30), true)
	stats_hbox.add_child(dmg_lbl)
	
	var type_lbl = Label.new()
	type_lbl.text = "%s" % w_data.get("type_text", "Weapon")
	UIHelper.apply_bubbly_label(type_lbl, 10, Color(0.85, 0.95, 1.0), true)
	stats_hbox.add_child(type_lbl)
	
	var bc_stats = CenterContainer.new()
	bc_stats.add_child(stats_pill)
	vbox.add_child(bc_stats)
	
	# Description Box (What It Does & How Amazing It Is) with internal scroll if needed
	var desc_panel = Panel.new()
	var dp_w = win_w - 36.0
	var dp_h = clampf(win_h - 290.0, 110.0, 175.0)
	desc_panel.custom_minimum_size = Vector2(dp_w, dp_h)
	desc_panel.size = Vector2(dp_w, dp_h)
	var dp_color = Color(0.04, 0.12, 0.25, 0.90)
	var dp_st = UIHelper.create_bubbly_panel(14, dp_color, Color(0.50, 0.75, 1.0, 0.6), 1.0)
	desc_panel.add_theme_stylebox_override("panel", dp_st)
	
	var desc_scroll = ScrollContainer.new()
	desc_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	desc_scroll.offset_left = 8
	desc_scroll.offset_right = -8
	desc_scroll.offset_top = 6
	desc_scroll.offset_bottom = -6
	desc_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	desc_panel.add_child(desc_scroll)
	
	var desc_vbox = VBoxContainer.new()
	desc_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	desc_vbox.add_theme_constant_override("separation", 4)
	desc_scroll.add_child(desc_vbox)
	
	var what_lbl = Label.new()
	what_lbl.text = "%s" % w_data.get("what_it_does", "")
	what_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	what_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(what_lbl, 10, Color(0.88, 0.94, 1.0), false)
	desc_vbox.add_child(what_lbl)
	
	var amazing_lbl = Label.new()
	amazing_lbl.text = "%s" % w_data.get("how_amazing", "")
	amazing_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	amazing_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var amz_col = Color(1.0, 0.90, 0.40) if is_lvl3 else Color(0.75, 0.90, 1.0)
	UIHelper.apply_bubbly_label(amazing_lbl, 10, amz_col, true)
	desc_vbox.add_child(amazing_lbl)
	
	var bc_desc = CenterContainer.new()
	bc_desc.add_child(desc_panel)
	vbox.add_child(bc_desc)
	
	# Action Button: "GOT IT!"
	var got_it_btn = Button.new()
	var btn_w = 140.0
	var btn_h = 36.0
	got_it_btn.custom_minimum_size = Vector2(btn_w, btn_h)
	got_it_btn.size = Vector2(btn_w, btn_h)
	var btn_color = UIHelper.VIBRANT_GREEN if not is_lvl3 else Color(0.15, 0.72, 0.95)
	var gb_st = UIHelper.create_bubbly_panel(18, btn_color, Color.WHITE, 2.0)
	got_it_btn.add_theme_stylebox_override("normal", gb_st)
	got_it_btn.add_theme_stylebox_override("hover", gb_st)
	got_it_btn.add_theme_stylebox_override("pressed", gb_st)
	got_it_btn.text = "AWESOME!" if is_lvl3 else "GOT IT!"
	got_it_btn.focus_mode = Control.FOCUS_NONE
	UIHelper.apply_bubbly_label(got_it_btn, 11, Color.WHITE, true)
	got_it_btn.pressed.connect(func():
		AudioManager.play_sfx("click")
		backdrop.queue_free()
	)
	
	var bc_btn = CenterContainer.new()
	bc_btn.add_child(got_it_btn)
	vbox.add_child(bc_btn)


