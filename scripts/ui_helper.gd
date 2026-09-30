# scripts/ui_helper.gd - UI Helper Subsystem
class_name UIHelper
extends RefCounted

# Color Palette
const SKY_BLUE = Color(0.50, 0.82, 1.0)
const SOFT_BLUE = Color(0.70, 0.88, 0.98)
const DEEP_BLUE = Color(0.12, 0.35, 0.65)
const NAVY_BLUE = Color(0.08, 0.20, 0.42)
const BUBBLY_WHITE = Color(1.0, 1.0, 1.0, 0.95)
const VIBRANT_GREEN = Color(0.18, 0.80, 0.44)
const VIBRANT_PURPLE = Color(0.61, 0.35, 0.90)
const VIBRANT_ORANGE = Color(1.0, 0.55, 0.22)
const VIBRANT_RED = Color(0.95, 0.26, 0.35)
const GOLD_YELLOW = Color(1.0, 0.80, 0.15)
const SHADOW_COLOR = Color(0.0, 0.15, 0.35, 0.3)

# Device safe-area insets (notch / Dynamic Island at the top, home indicator at the bottom),
# expressed in the game's own viewport units. Set by Main._apply_safe_area().
static var safe_top: float = 0.0
static var safe_bottom: float = 0.0

# Character Art Mappings
const CHAR_IMAGES = {
	"chip": "res://assets/images/characters/chip-nobg.png",
	"flora": "res://assets/images/characters/flora-nobg.png",
	"dash": "res://assets/images/characters/dash-nobg.png",
	"blaze": "res://assets/images/characters/blaze-nobg.png",
	"ash": "res://assets/images/characters/ash-nobg.png",
	"penelope": "res://assets/images/characters/penelope-nobg.png",
	"nibbles": "res://assets/images/characters/chef-nobg.png",
	"spark": "res://assets/images/characters/spark-nobg.png",
	"sparkette": "res://assets/images/characters/sparkette-nobg.png",
	"sircrown": "res://assets/images/characters/SirCrown-nobg.png",
	"crown": "res://assets/images/characters/SirCrown-nobg.png",
}

const CHAR_BG_IMAGES = {
	"chip": "res://assets/images/characters/chip-bg.png",
	"flora": "res://assets/images/characters/flora-bg.png",
	"dash": "res://assets/images/characters/dash-bg.png",
	"blaze": "res://assets/images/characters/blaze-bg.png",
	"ash": "res://assets/images/characters/ash-bg.png",
	"penelope": "res://assets/images/characters/penelope-bg.png",
	"nibbles": "res://assets/images/characters/chef-bg.png",
	"spark": "res://assets/images/characters/spark-bg.png",
	"sparkette": "res://assets/images/characters/sparkette-bg.png",
	"sircrown": "res://assets/images/characters/SirCrown-nobg.png",
	"crown": "res://assets/images/characters/SirCrown-nobg.png",
}

static func _get_audio_manager(node: Node = null) -> Node:
	if node and is_instance_valid(node) and node.is_inside_tree():
		var root = node.get_tree().root
		if root and root.has_node("AudioManager"):
			return root.get_node("AudioManager")
	var loop = Engine.get_main_loop()
	if loop and loop is SceneTree:
		var root = (loop as SceneTree).root
		if root and root.has_node("AudioManager"):
			return root.get_node("AudioManager")
	return null

static func _play_sfx_safe(sfx_name: String, node: Node = null):
	var am = _get_audio_manager(node)
	if am and am.has_method("play_sfx"):
		am.play_sfx(sfx_name)

static func _stop_narration_safe(node: Node = null):
	var am = _get_audio_manager(node)
	if am and am.has_method("stop_narration"):
		am.stop_narration()

static func _get_game_state(node: Node = null) -> Node:
	if node and is_instance_valid(node) and node.is_inside_tree():
		var root = node.get_tree().root
		if root and root.has_node("GameState"):
			return root.get_node("GameState")
	var loop = Engine.get_main_loop()
	if loop and loop is SceneTree:
		var root = (loop as SceneTree).root
		if root and root.has_node("GameState"):
			return root.get_node("GameState")
	return null

static func load_texture_safe(path: String) -> Texture2D:
	if path == "":
		return null
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is Texture2D:
			return res
	var global_path = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(global_path):
		var img = Image.load_from_file(global_path)
		if img and not img.is_empty():
			return ImageTexture.create_from_image(img)
	elif FileAccess.file_exists(path):
		var img = Image.load_from_file(path)
		if img and not img.is_empty():
			return ImageTexture.create_from_image(img)
	return null

static func create_aspect_texture_rect(path_or_tex, target_size: Vector2 = Vector2.ZERO) -> TextureRect:
	var tex_rect = TextureRect.new()
	if typeof(path_or_tex) == TYPE_STRING:
		tex_rect.texture = load_texture_safe(path_or_tex)
	elif path_or_tex is Texture2D:
		tex_rect.texture = path_or_tex
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if target_size != Vector2.ZERO:
		tex_rect.custom_minimum_size = target_size
		tex_rect.size = target_size
	return tex_rect

static var _cached_button_textures: Dictionary = {}

const BUTTON_NAME_MAP = {
	"resume": "resumebtn.png",
	"restart": "restartbtn.png",
	"exit": "exitgamebtn.png",
	"exit game": "exitgamebtn.png",
	"exitgame": "exitgamebtn.png",
	"quit": "quitgamebtn.png",
	"quit game": "quitgamebtn.png",
	"quitgame": "quitgamebtn.png",
	"quit brushing": "quitbrushingbtn.png",
	"quitbrushing": "quitbrushingbtn.png",
	"start": "startgamebtn.png",
	"start game": "startgamebtn.png",
	"startgame": "startgamebtn.png",
	"start brushing": "startbrushingsessionbtn.png",
	"start brushing session": "startbrushingsessionbtn.png",
	"startbrushing": "startbrushingsessionbtn.png",
	"startbrushingsession": "startbrushingsessionbtn.png",
	"play again": "playagainbtn.png",
	"playagain": "playagainbtn.png",
	"difficulty": "changedifficultybtn.png",
	"change difficulty": "changedifficultybtn.png",
	"changedifficulty": "changedifficultybtn.png",
	"easy": "easybtn.png",
	"medium": "mediumbtn.png",
	"hard": "hardbtn.png",
	"keep going": "keepgoingbtn.png",
	"keepgoing": "keepgoingbtn.png",
	"keep": "keepbtn.png",
	"keepbtn": "keepbtn.png",
	"keep brushing": "keepbrushingbtn.png",
	"keepbrushing": "keepbrushingbtn.png",
	"leave": "leavebtn.png",
	"complete session": "completesession.png",
	"completesession": "completesession.png",
	"return to map": "returntomapbtn.png",
	"returntomap": "returntomapbtn.png",
	"back to map": "returntomapbtn.png",
	"back to main menu": "returntomapbtn.png",
	"continue": "completesession.png",
	"claim": "claim_rewards_button.png",
	"claim rewards": "claim_rewards_button.png",
	"claimrewards": "claim_rewards_button.png",
	"skip check": "skipcheckbtn.png",
	"skipcheck": "skipcheckbtn.png",
	"review fact": "reviewfactbtn.png",
	"reviewfact": "reviewfactbtn.png",
	"create code": "createfamcodebtn.png",
	"create fam code": "createfamcodebtn.png",
	"createfamcode": "createfamcodebtn.png",
	"join code": "joinfamilycodebtn.png",
	"join family code": "joinfamilycodebtn.png",
	"joinfamilycode": "joinfamilycodebtn.png",
	"submit answer": "submitanswerbtn.png",
	"submitanswer": "submitanswerbtn.png",
	"submit": "submitanswerbtn.png",
	"confirm": "confirmbtn.png",
	"close": "closebtn.png",
	"done": "close-donebtn.png",
	"close-done": "close-donebtn.png",
	"closedone": "close-donebtn.png",
	"read": "readbtn.png",
	"read story": "readbtn.png",
	"read now": "readbtn.png",
	"readbtn": "readbtn.png",
	"got it": "gotitbtn.png",
	"gotit": "gotitbtn.png",
	"finish": "finishbtn.png",
	"finish fact": "finishfactbtn.png",
	"finishfact": "finishfactbtn.png",
	"awesome": "awesomebtn.png",
	"awesome!": "awesomebtn.png",
	"dismiss": "dismissbtn.png",
	"dismissbtn": "dismissbtn.png",
	"select": "selectbtn.png",
	"selectbtn": "selectbtn.png",
	"equip": "selectbtn.png",
	"see collection": "seeinventorybtn.png",
	"see inventory": "seeinventorybtn.png",
	"seeinventory": "seeinventorybtn.png",
	"hide inventory": "hideinventorybtn.png",
	"hideinventory": "hideinventorybtn.png",
	"save": "savebtn.png",
	"save profile": "savebtn.png",
	"save pin": "confirmbtn.png",
	"savebtn": "savebtn.png",
	"cancel": "cancelbtn.png",
	"cancelbtn": "cancelbtn.png",
	"back": "backbtn.png",
	"backbtn": "backbtn.png",
	"edit": "editbtn.png",
	"edit profile": "editbtn.png",
	"editbtn": "editbtn.png",
	"add user": "adduserbtn.png",
	"add player": "adduserbtn.png",
	"adduser": "adduserbtn.png",
	"addplayer": "adduserbtn.png",
	"+ add user": "adduserbtn.png",
	"choose player": "chooseplayerbtn.png",
	"chooseplayer": "chooseplayerbtn.png",
	"switch user": "switchuserbtn.png",
	"switch player": "switchuserbtn.png",
	"switchuser": "switchuserbtn.png",
	"switchplayer": "switchuserbtn.png",
	"change avatar": "changeavatarbtn.png",
	"changeavatar": "changeavatarbtn.png",
	"skip tutorial": "skiptutorialbtn.png",
	"skiptutorial": "skiptutorialbtn.png",
	"skip": "skiptutorialbtn.png",
	"let's brush!": "letsbrushbtn.png",
	"lets brush": "letsbrushbtn.png",
	"letsbrush": "letsbrushbtn.png",
	"next": "next_btn.png",
	"nextbtn": "next_btn.png",
	"switch back": "switchuserbtn.png",
	"switchback": "switchuserbtn.png",
	"data wipe": "datawipe-resetbtn.png",
	"datawipe": "datawipe-resetbtn.png",
	"datawipe-reset": "datawipe-resetbtn.png",
	"datawipe_reset": "datawipe-resetbtn.png",
	"datawipereset": "datawipe-resetbtn.png",
	"reset game": "datawipe-resetbtn.png",
	"yes, reset": "datawipe-resetbtn.png",
	"reset": "datawipe-resetbtn.png",
	"audio settings": "audiosettings_btn.png",
	"audiosettings": "audiosettings_btn.png",
	"audio_settings": "audiosettings_btn.png",
	"back to settings": "backtosettings_btn.png",
	"backtosettings": "backtosettings_btn.png",
	"back_to_settings": "backtosettings_btn.png",
	"parental portal": "parentalcontrol_btn.png",
	"parental control": "parentalcontrol_btn.png",
	"parental controls": "parentalcontrol_btn.png",
	"parentalcontrol": "parentalcontrol_btn.png",
	"parental_control": "parentalcontrol_btn.png",
	"try again": "tryagain_btn.png",
	"tryagain": "tryagain_btn.png",
	"try_again": "tryagain_btn.png",
	"tap to open": "taptoopen_btn.png",
	"taptoopen": "taptoopen_btn.png",
	"tap_to_open": "taptoopen_btn.png",
	"unlock": "unlock_btn.png",
	"unlockbtn": "unlock_btn.png",
	"unlock_btn": "unlock_btn.png",
	"replay tutorial": "replaytutorial_btn.png",
	"replaytutorial": "replaytutorial_btn.png",
	"support dev": "supportdev_btn.png",
	"supportdev": "supportdev_btn.png",
	"support developer": "supportdev_btn.png",
	"legal & dev support": "supportdev_btn.png",
	"terms and privacy": "termsandpriv_btn.png",
	"terms & privacy": "termsandpriv_btn.png",
	"terms": "termsandpriv_btn.png",
	"privacy": "termsandpriv_btn.png",
	"termsandpriv": "termsandpriv_btn.png",
	"learn new fact": "learnnewfact_btn.png",
	"learnnewfact": "learnnewfact_btn.png",
	"learn fact": "learnnewfact_btn.png",
	"new fact": "learnnewfact_btn.png",
	"listen": "listen_btn.png",
	"listen_btn": "listen_btn.png",
	"read aloud": "listen_btn.png",
	"pause": "pausebtn.png",
	"pausebtn": "pausebtn.png",
	"on": "on_btn.png",
	"on_btn": "on_btn.png",
	"off": "off_btn.png",
	"off_btn": "off_btn.png",
	"gift": "gifticon.png",
	"gifticon": "gifticon.png",
	"audio toggles": "audiotogglesbtn.png",
	"audiotoggles": "audiotogglesbtn.png",
	"back to main map": "returntomapbtn.png",
	"backtomap": "returntomapbtn.png",
	"main map": "returntomapbtn.png"
}

static func get_button_texture(btn_name: String) -> Texture2D:
	var raw_key = btn_name.to_lower().strip_edges()
	if _cached_button_textures.has(raw_key) and _cached_button_textures[raw_key] and is_instance_valid(_cached_button_textures[raw_key]):
		return _cached_button_textures[raw_key]
		
	var filenames = []
	if BUTTON_NAME_MAP.has(raw_key):
		filenames.append(BUTTON_NAME_MAP[raw_key])
	
	var base_fn = raw_key
	if not base_fn.ends_with(".png"):
		filenames.append(base_fn + "btn.png")
		filenames.append(base_fn + ".png")
	else:
		filenames.append(base_fn)
		if not base_fn.ends_with("btn.png"):
			filenames.append(base_fn.replace(".png", "btn.png"))
			
	var base_dirs = [
		"res://assets/images/buttons/",
		"res://assets/images/buttons/",
		"res://assets/images/general/",
		"res://assets/images/congratulations/",
		"res://assets/images/misc/"
	]
	
	for fn in filenames:
		for bd in base_dirs:
			var res_path = bd + fn
			var global_path = ProjectSettings.globalize_path(res_path)
			if FileAccess.file_exists(global_path):
				var img = Image.load_from_file(global_path)
				if img and not img.is_empty():
					var tex = ImageTexture.create_from_image(img)
					_cached_button_textures[raw_key] = tex
					return tex
			var tex = load_texture_safe(res_path)
			if tex:
				_cached_button_textures[raw_key] = tex
				return tex
				
	return null

static func get_pause_button_texture() -> Texture2D:
	return get_button_texture("pause")

static func create_close_button(btn_size: Vector2 = Vector2(34, 34)) -> TextureButton:
	var btn = TextureButton.new()
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	var tex = get_button_texture("crossbtn")
	if not tex:
		tex = load_texture_safe("res://assets/images/buttons/crossbtn.png")
	if not tex:
		tex = load_texture_safe("res://assets/images/general/crossbtn.png")
	btn.texture_normal = tex
	btn.custom_minimum_size = btn_size
	btn.size = btn_size
	btn.pivot_offset = btn_size * 0.5
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	return btn

static func create_themed_button(btn_name: String, btn_size: Vector2 = Vector2.ZERO) -> TextureButton:
	var btn = TextureButton.new()
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	var tex = get_button_texture(btn_name)
	if tex:
		btn.texture_normal = tex
	if btn_size != Vector2.ZERO:
		btn.custom_minimum_size = btn_size
		btn.size = btn_size
		btn.pivot_offset = btn_size * 0.5
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	
	btn.button_down.connect(func():
		_play_sfx_safe("click")
		var tw = btn.create_tween()
		tw.tween_property(btn, "scale", Vector2(0.95, 0.95), 0.08)
	)
	btn.button_up.connect(func():
		var tw = btn.create_tween()
		tw.tween_property(btn, "scale", Vector2.ONE, 0.08)
	)
	return btn

static func create_circular_pause_button(btn_size: Vector2 = Vector2(46, 46)) -> TextureButton:
	var btn = TextureButton.new()
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn.custom_minimum_size = btn_size
	btn.size = btn_size
	btn.pivot_offset = btn_size * 0.5
	btn.texture_normal = get_pause_button_texture()
	btn.focus_mode = Control.FOCUS_NONE
	return btn

static func load_audio_safe(path: String) -> AudioStream:
	if path == "":
		return null
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is AudioStream:
			return res
	return null

static func load_video_safe(path: String) -> VideoStream:
	if path == "":
		return null
	var base_name = path.get_file().get_basename()
	var candidate_paths = [
		path,
		path.get_basename() + ".ogv",
		"res://assets/videos/" + base_name + ".ogv",
		"res://assets/videos/" + path.get_file(),
		"res://assets/videos/" + base_name + ".ogv",
		"res://assets/videos/" + path.get_file(),
		"res://" + path
	]
	for p in candidate_paths:
		if ResourceLoader.exists(p):
			var res = load(p)
			if res is VideoStream:
				return res
		var global_path = ProjectSettings.globalize_path(p)
		if FileAccess.file_exists(global_path) or FileAccess.file_exists(p):
			var res = load(p)
			if res is VideoStream:
				return res
			if ClassDB.class_exists("VideoStreamTheora") and (p.ends_with(".ogv") or p.ends_with(".ogg")):
				var theora = ClassDB.instantiate("VideoStreamTheora")
				if theora:
					theora.file = p
					return theora
	return null


static func get_char_texture(char_id: String, with_bg: bool = false) -> Texture2D:
	var map = CHAR_BG_IMAGES if with_bg else CHAR_IMAGES
	if map.has(char_id):
		var tex = load_texture_safe(map[char_id])
		if tex:
			return tex
	return load_texture_safe("res://assets/images/characters/chip-nobg.png")

static var _cached_grayscale_mat: ShaderMaterial = null

static func get_grayscale_material() -> ShaderMaterial:
	if _cached_grayscale_mat and is_instance_valid(_cached_grayscale_mat):
		return _cached_grayscale_mat
	var shader = Shader.new()
	shader.code = """
	shader_type canvas_item;
	void fragment() {
		vec4 c = texture(TEXTURE, UV);
		float gray = dot(c.rgb, vec3(0.299, 0.587, 0.114));
		COLOR = vec4(vec3(gray), c.a);
	}
	"""
	_cached_grayscale_mat = ShaderMaterial.new()
	_cached_grayscale_mat.shader = shader
	return _cached_grayscale_mat

static func get_avatar_texture(avatar_id: String) -> Texture2D:
	return get_char_texture(avatar_id, false)

static func get_weapon_texture(weapon_id: String, tier: int = 1) -> Texture2D:
	var w_key = weapon_id.to_lower().strip_edges().split("_")[0]
	var paths: Array = []
	match w_key:
		"brush", "toothbrush":
			match tier:
				1: paths = ["res://assets/images/shop/brushweapon_1.png"]
				2: paths = ["res://assets/images/shop/brushweapon_2.png"]
				3: paths = ["res://assets/images/shop/BubbleBrush.png", "res://assets/images/shop/brushweapon_3.png"]
				_: paths = ["res://assets/images/shop/brushweapon_1.png"]
		"paste", "toothpaste":
			match tier:
				1: paths = ["res://assets/images/shop/Lvl1Paste.png", "res://assets/images/shop/pasteweapon_1.png"]
				2: paths = ["res://assets/images/shop/PasteGold2.png", "res://assets/images/shop/Lvl2Paste.png", "res://assets/images/shop/pasteweapon_2.png"]
				3: paths = ["res://assets/images/shop/BubblePaste.png", "res://assets/images/shop/Lvl3Paste.png", "res://assets/images/shop/pasteweapon_3.png"]
				_: paths = ["res://assets/images/shop/Lvl1Paste.png"]
		"wash", "mouthwash":
			match tier:
				1: paths = ["res://assets/images/shop/MouthwashBlast-1.png", "res://assets/images/shop/washweapon_1.png"]
				2: paths = ["res://assets/images/shop/WashGold2.png", "res://assets/images/shop/MouthwashBlast-2.png", "res://assets/images/shop/washweapon_2.png"]
				3: paths = ["res://assets/images/shop/BubbleWash.png", "res://assets/images/shop/MouthwashBlast-3.png", "res://assets/images/shop/washweapon_3.png"]
				_: paths = ["res://assets/images/shop/MouthwashBlast-1.png"]
		"floss":
			match tier:
				1: paths = ["res://assets/images/shop/flossweapon_1.png"]
				2: paths = ["res://assets/images/shop/flossweapon_2.png"]
				3: paths = ["res://assets/images/shop/flossweapon_3.png"]
				_: paths = ["res://assets/images/shop/flossweapon_1.png"]
	
	for p in paths:
		var tex = load_texture_safe(p)
		if tex:
			return tex
	return null

static var _cached_crown_wallpaper: Texture2D = null

## Sir Crown has no ready-made celebration wallpaper, so build one: royal gradient + his own artwork.
static func _make_sircrown_wallpaper() -> Texture2D:
	if _cached_crown_wallpaper != null:
		return _cached_crown_wallpaper
	var w: int = 720
	var h: int = 1280
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	var top_c = Color(0.42, 0.30, 0.78)
	var bot_c = Color(0.90, 0.66, 0.96)
	for y in range(h):
		img.fill_rect(Rect2i(0, y, w, 1), top_c.lerp(bot_c, float(y) / float(h - 1)))
	var crown_tex = load_texture_safe("res://assets/images/characters/SirCrown-nobg.png")
	if crown_tex != null:
		var src: Image = crown_tex.get_image()
		if src != null and not src.is_empty():
			if src.is_compressed():
				src.decompress()
			src.convert(Image.FORMAT_RGBA8)
			var target_h: int = 760
			var scale_f: float = min(600.0 / float(src.get_width()), float(target_h) / float(src.get_height()))
			var nw: int = max(1, int(src.get_width() * scale_f))
			var nh: int = max(1, int(src.get_height() * scale_f))
			src.resize(nw, nh, Image.INTERPOLATE_LANCZOS)
			img.blend_rect(src, Rect2i(0, 0, nw, nh), Vector2i((w - nw) / 2, 330))
	_cached_crown_wallpaper = ImageTexture.create_from_image(img)
	return _cached_crown_wallpaper

static func get_finished_brushing_texture(avatar_id: String) -> Texture2D:
	var char_key = avatar_id.to_lower().strip_edges()
	var filename = ""
	match char_key:
		"chip": filename = "finished_brushing_chip.jpg"
		"flora": filename = "finished_brushing_flora.jpg"
		"dash": filename = "finished_brushing_dash.jpg"
		"blaze": filename = "finished_brushing_blaze.jpg"
		"ash": filename = "finished_brushing_ash.jpg"
		"penelope": filename = "finished_brushing_penelope.jpg"
		"nibbles", "chef": filename = "finished_brushing_chef.jpg"
		"spark": filename = "finished_brushing_spark.jpg"
		"sparkette": filename = "finished_brushing_sparkette.jpg"
		"sircrown", "crown": return _make_sircrown_wallpaper()
		_: filename = "finished_brushing_chip.jpg"
		
	var candidate_paths = [
		ProjectSettings.globalize_path("res://assets/images/brushing/" + filename),
		ProjectSettings.globalize_path("res://assets/images/brushing/" + filename),
		ProjectSettings.globalize_path("res://assets/images/brushing/" + filename),
		ProjectSettings.globalize_path("res://assets/images/misc/" + filename),
		ProjectSettings.globalize_path("res://assets/" + filename)
	]
	for cp in candidate_paths:
		if FileAccess.file_exists(cp):
			var img = Image.load_from_file(cp)
			if img and not img.is_empty():
				return ImageTexture.create_from_image(img)
				
	var res_paths = [
		"res://assets/images/brushing/" + filename,
		"res://assets/images/brushing/" + filename,
		"res://assets/images/brushing/" + filename,
		"res://assets/images/misc/" + filename,
		"res://assets/" + filename
	]
	for rp in res_paths:
		var tex = load_texture_safe(rp)
		if tex:
			return tex
			
	if char_key == "sparkette":
		return get_finished_brushing_texture("spark")
	return load_texture_safe("res://assets/images/brushing/finished_brushing_chip.jpg")

static func create_bubbly_panel(corner_radius: int = 24, bg_color: Color = Color(1, 1, 1, 0.95), border_color: Color = Color.TRANSPARENT, border_width: int = 0) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.corner_radius_top_left = corner_radius
	style.corner_radius_top_right = corner_radius
	style.corner_radius_bottom_left = corner_radius
	style.corner_radius_bottom_right = corner_radius
	style.shadow_color = SHADOW_COLOR
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 4)
	if border_width > 0:
		style.border_color = border_color
		style.border_width_left = border_width
		style.border_width_top = border_width
		style.border_width_right = border_width
		style.border_width_bottom = border_width
	return style

static func create_circle_style(bg_color: Color, border_color: Color = Color.TRANSPARENT, border_width: int = 0) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.corner_radius_top_left = 999
	style.corner_radius_top_right = 999
	style.corner_radius_bottom_left = 999
	style.corner_radius_bottom_right = 999
	if border_width > 0:
		style.border_color = border_color
		style.border_width_left = border_width
		style.border_width_right = border_width
		style.border_width_top = border_width
		style.border_width_bottom = border_width
	return style

static func create_image_button(texture_path: String, min_size: Vector2 = Vector2.ZERO) -> TextureButton:
	var btn = TextureButton.new()
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	if min_size != Vector2.ZERO:
		btn.custom_minimum_size = min_size
		btn.size = min_size
	var tex = load_texture_safe(texture_path)
	if tex:
		btn.texture_normal = tex
	if min_size != Vector2.ZERO:
		btn.custom_minimum_size = min_size
		btn.size = min_size
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.focus_mode = Control.FOCUS_NONE
		
	# Play click sfx on press
	btn.button_down.connect(func():
		_play_sfx_safe("click")
	)
	return btn

static func create_texture_rect(texture_path: String, target_size: Vector2 = Vector2.ZERO, stretch: TextureRect.StretchMode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED) -> TextureRect:
	var rect = TextureRect.new()
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = stretch
	if target_size != Vector2.ZERO:
		rect.custom_minimum_size = target_size
		rect.size = target_size
	var tex = load_texture_safe(texture_path)
	if tex:
		rect.texture = tex
	if target_size != Vector2.ZERO:
		rect.custom_minimum_size = target_size
		rect.size = target_size
	return rect

static var _cached_main_font: Font = null

static func get_main_font() -> Font:
	if _cached_main_font and is_instance_valid(_cached_main_font):
		return _cached_main_font
		
	var font_candidates = [
		"res://assets/fonts/Rubik-Regular.ttf",
		"res://assets/fonts/Rubik-Regular.ttf",
		"res://assets/fonts/Roboto-Regular.ttf",
		"res://assets/fonts/Roboto-Regular.ttf",
		"res://assets/fonts/CantoraOne-Regular.ttf",
		"res://assets/fonts/CantoraOne-Regular.ttf",
		"res://assets/fonts/WorkSans-Regular.ttf",
		"res://assets/fonts/WorkSans-Regular.ttf",
		"res://assets/fonts/PearlyWhitesFont.ttf",
	]
	for path in font_candidates:
		var f = load_font_safe(path)
		if f:
			_cached_main_font = f
			return _cached_main_font
	return null

static func load_font_safe(path: String) -> Font:
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is Font:
			return res
	var global_path = ProjectSettings.globalize_path(path)
	var check_path = global_path if FileAccess.file_exists(global_path) else (path if FileAccess.file_exists(path) else "")
	if check_path != "":
		var ff = FontFile.new()
		var err = ff.load_dynamic_font(check_path)
		if err == OK:
			return ff
	return null

static var _cached_bold_font: Font = null

static func get_bold_font() -> Font:
	if _cached_bold_font and is_instance_valid(_cached_bold_font):
		return _cached_bold_font
	var base = get_main_font()
	if base:
		var fv = FontVariation.new()
		fv.base_font = base
		fv.variation_embolden = 0.75
		_cached_bold_font = fv
		return _cached_bold_font
	return null

static func apply_bubbly_label(lbl: Control, size: int = 18, color: Color = Color.BLACK, is_bold: bool = false):
	if not lbl:
		return
	var font = get_bold_font() if is_bold else get_main_font()
	if font:
		lbl.add_theme_font_override("font", font)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0))
	lbl.add_theme_constant_override("outline_size", 0)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	lbl.add_theme_constant_override("shadow_offset_x", 0)
	lbl.add_theme_constant_override("shadow_offset_y", 0)


static func create_3d_button_style(bg_color: Color, pressed_offset: bool = false, corner_radius: int = 22) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.corner_radius_top_left = corner_radius
	style.corner_radius_top_right = corner_radius
	style.corner_radius_bottom_left = corner_radius
	style.corner_radius_bottom_right = corner_radius
	
	if pressed_offset:
		style.shadow_size = 2
		style.shadow_offset = Vector2(0, 2)
		style.bg_color = bg_color.darkened(0.12)
	else:
		style.shadow_color = bg_color.darkened(0.4)
		style.shadow_size = 4
		style.shadow_offset = Vector2(0, 5)
		style.border_color = Color(1, 1, 1, 0.4)
		style.border_width_top = 2
	
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

static func create_bubbly_button(text: String, bg_color: Color = VIBRANT_GREEN, text_color: Color = Color.WHITE, icon_texture: Texture2D = null) -> Button:
	var tex = get_button_texture(text)
	if tex:
		var tex_btn = Button.new()
		tex_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		tex_btn.focus_mode = Control.FOCUS_NONE
		tex_btn.text = ""
		tex_btn.icon = tex
		tex_btn.expand_icon = true
		tex_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var empty = StyleBoxEmpty.new()
		tex_btn.add_theme_stylebox_override("normal", empty)
		tex_btn.add_theme_stylebox_override("hover", empty)
		tex_btn.add_theme_stylebox_override("pressed", empty)
		tex_btn.add_theme_stylebox_override("disabled", empty)
		tex_btn.add_theme_stylebox_override("focus", empty)
		tex_btn.custom_minimum_size = Vector2(200, 50)
		tex_btn.pivot_offset = tex_btn.custom_minimum_size * 0.5
		tex_btn.button_down.connect(func():
			_play_sfx_safe("click")
			var tw = tex_btn.create_tween()
			tw.tween_property(tex_btn, "scale", Vector2(0.95, 0.95), 0.08)
		)
		tex_btn.button_up.connect(func():
			var tw = tex_btn.create_tween()
			tw.tween_property(tex_btn, "scale", Vector2.ONE, 0.08)
		)
		return tex_btn

	var btn = Button.new()
	btn.text = text
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_color_override("font_color", text_color)
	btn.add_theme_color_override("font_hover_color", text_color)
	btn.add_theme_color_override("font_pressed_color", text_color)
	btn.add_theme_font_size_override("font_size", 18)
	
	if icon_texture:
		btn.icon = icon_texture
		btn.expand_icon = true
	
	var normal = create_3d_button_style(bg_color, false)
	var hover = create_3d_button_style(bg_color.lightened(0.08), false)
	var pressed = create_3d_button_style(bg_color, true)
	var disabled = create_3d_button_style(Color(0.7, 0.75, 0.8), false)
	
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)
	
	btn.button_down.connect(func():
		_play_sfx_safe("click")
	)
	return btn

static func center_node_h(node: Control, y_pos: float = -1.0, base_width: float = 450.0):
	if not node: return
	var p = node.get_parent()
	var w = p.size.x if (p and p is Control and p.size.x > 0) else base_width
	node.position.x = max(0.0, (w - node.size.x) * 0.5)
	if y_pos >= 0.0:
		node.position.y = y_pos

static func center_modal_card(card: Control, w: float, h: float):
	if not card: return
	card.custom_minimum_size = Vector2(w, h)
	card.size = Vector2(w, h)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	card.pivot_offset = Vector2(w * 0.5, h * 0.5)
	
	var p = card.get_parent()
	if p is CenterContainer:
		card.anchor_left = 0.0
		card.anchor_top = 0.0
		card.anchor_right = 0.0
		card.anchor_bottom = 0.0
		card.offset_left = 0.0
		card.offset_top = 0.0
		card.offset_right = w
		card.offset_bottom = h
	else:
		card.grow_horizontal = Control.GROW_DIRECTION_BOTH
		card.grow_vertical = Control.GROW_DIRECTION_BOTH
		card.anchor_left = 0.5
		card.anchor_right = 0.5
		card.anchor_top = 0.5
		card.anchor_bottom = 0.5
		card.offset_left = -w * 0.5
		card.offset_right = w * 0.5
		card.offset_top = -h * 0.5
		card.offset_bottom = h * 0.5

static func create_modal_dialog(parent_node: Node, z_index: int = 200, bg_color: Color = Color(0.04, 0.12, 0.28, 0.75)) -> Dictionary:
	var target_parent: Node = parent_node
	if parent_node and parent_node.is_inside_tree():
		var main_node = parent_node.get_tree().root.get_node_or_null("Main")
		if main_node and is_instance_valid(main_node):
			target_parent = main_node

	var overlay = Control.new()
	overlay.name = "ModalOverlay"
	overlay.z_index = z_index
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	target_parent.add_child(overlay)
	
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.anchor_left = 0.0
	overlay.anchor_top = 0.0
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.offset_left = 0.0
	overlay.offset_top = 0.0
	overlay.offset_right = 0.0
	overlay.offset_bottom = 0.0
	overlay.grow_horizontal = Control.GROW_DIRECTION_BOTH
	overlay.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	var backdrop = ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = bg_color
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(backdrop)
	
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.anchor_left = 0.0
	backdrop.anchor_top = 0.0
	backdrop.anchor_right = 1.0
	backdrop.anchor_bottom = 1.0
	backdrop.offset_left = 0.0
	backdrop.offset_top = 0.0
	backdrop.offset_right = 0.0
	backdrop.offset_bottom = 0.0
	backdrop.grow_horizontal = Control.GROW_DIRECTION_BOTH
	backdrop.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	var center = CenterContainer.new()
	center.name = "CenterContainer"
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)
	
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.anchor_left = 0.0
	center.anchor_top = 0.0
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	center.offset_left = 0.0
	center.offset_top = 0.0
	center.offset_right = 0.0
	center.offset_bottom = 0.0
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	var update_layout = func():
		var sz = get_viewport_safe_size(target_parent)
		overlay.position = Vector2.ZERO
		overlay.size = sz
		backdrop.position = Vector2.ZERO
		backdrop.size = sz
		center.position = Vector2.ZERO
		center.size = sz
		
	overlay.resized.connect(update_layout)
	update_layout.call()
	
	return {
		"overlay": overlay,
		"backdrop": backdrop,
		"center": center,
		"update_layout": update_layout
	}

static func create_modal_card(target_w: float, kind: String = "portrait") -> Dictionary:
	var tex = get_modal_card_texture(kind)
	var card_root = Control.new()
	var card_bg = TextureRect.new()
	card_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	var card_w = target_w
	var card_h = target_w * 1.50 # Fallback aspect ratio if texture not loaded
	if tex:
		card_bg.texture = tex
		var tw = float(tex.get_width())
		var th = float(tex.get_height())
		if tw > 0.0:
			card_h = card_w * (th / tw)
	
	card_root.custom_minimum_size = Vector2(card_w, card_h)
	card_root.size = Vector2(card_w, card_h)
	card_root.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card_root.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	card_root.anchor_left = 0.0
	card_root.anchor_top = 0.0
	card_root.anchor_right = 0.0
	card_root.anchor_bottom = 0.0
	card_root.offset_left = 0.0
	card_root.offset_top = 0.0
	card_root.offset_right = card_w
	card_root.offset_bottom = card_h
	card_root.pivot_offset = Vector2(card_w * 0.5, card_h * 0.5)
	
	card_root.add_child(card_bg)
	card_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	card_bg.anchor_left = 0.0
	card_bg.anchor_top = 0.0
	card_bg.anchor_right = 1.0
	card_bg.anchor_bottom = 1.0
	card_bg.offset_left = 0.0
	card_bg.offset_top = 0.0
	card_bg.offset_right = 0.0
	card_bg.offset_bottom = 0.0
	card_bg.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card_bg.grow_vertical = Control.GROW_DIRECTION_BOTH
	card_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var content_margin = MarginContainer.new()
	card_root.add_child(content_margin)
	content_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	content_margin.anchor_left = 0.0
	content_margin.anchor_top = 0.0
	content_margin.anchor_right = 1.0
	content_margin.anchor_bottom = 1.0
	content_margin.offset_left = 0.0
	content_margin.offset_top = 0.0
	content_margin.offset_right = 0.0
	content_margin.offset_bottom = 0.0
	content_margin.grow_horizontal = Control.GROW_DIRECTION_BOTH
	content_margin.grow_vertical = Control.GROW_DIRECTION_BOTH
	content_margin.add_theme_constant_override("margin_left", int(round(card_w * 0.08)))
	content_margin.add_theme_constant_override("margin_right", int(round(card_w * 0.08)))
	content_margin.add_theme_constant_override("margin_top", int(round(card_h * 0.07)))
	content_margin.add_theme_constant_override("margin_bottom", int(round(card_h * 0.07)))
	
	return {
		"root": card_root,
		"bg": card_bg,
		"content": content_margin,
		"width": card_w,
		"height": card_h,
		"card_w": card_w,
		"card_h": card_h
	}

static func setup_fullscreen_bg(rect: TextureRect):
	if not rect: return
	rect.anchor_left = 0.0
	rect.anchor_top = 0.0
	rect.anchor_right = 1.0
	rect.anchor_bottom = 1.0
	rect.offset_left = 0.0
	rect.offset_top = 0.0
	rect.offset_right = 0.0
	rect.offset_bottom = 0.0
	rect.grow_horizontal = Control.GROW_DIRECTION_BOTH
	rect.grow_vertical = Control.GROW_DIRECTION_BOTH
	rect.custom_minimum_size = Vector2(450, 800)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED

static func get_viewport_safe_size(ctrl: Control) -> Vector2:
	if ctrl and ctrl.size.x > 50.0 and ctrl.size.y > 50.0:
		return ctrl.size
	if ctrl and ctrl.is_inside_tree() and ctrl.get_viewport_rect().size.x > 50.0:
		return ctrl.get_viewport_rect().size
	return Vector2(450.0, 800.0)

static func create_sky_gradient_texture() -> Texture2D:
	var grad = Gradient.new()
	grad.colors = PackedColorArray([
		Color(0.48, 0.78, 0.98), # Bright cheerful sky blue at top
		Color(0.68, 0.88, 1.00), # Soft mid sky
		Color(0.86, 0.95, 1.00)  # Gentle pale sparkling tint at bottom
	])
	grad.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	
	var grad_tex = GradientTexture2D.new()
	grad_tex.gradient = grad
	grad_tex.fill_from = Vector2(0.5, 0.0)
	grad_tex.fill_to = Vector2(0.5, 1.0)
	grad_tex.width = 64
	grad_tex.height = 256
	return grad_tex

static func setup_clean_bubbly_bg(ctrl: Control) -> TextureRect:
	var bg = TextureRect.new()
	bg.name = "Background"
	setup_fullscreen_bg(bg)
	bg.texture = create_sky_gradient_texture()
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	ctrl.add_child(bg)
	return bg

const MODAL_CARD_PORTRAIT_SRC = "C:/Users/temie/.gemini/antigravity/brain/f3beff8c-f521-4448-84bb-4fcc19037ec9/.user_uploaded/media_1789923583868.png"
const MODAL_CARD_SQUARE_SRC = "C:/Users/temie/.gemini/antigravity/brain/f3beff8c-f521-4448-84bb-4fcc19037ec9/.user_uploaded/media_1789923611458.png"

static var _cached_modal_card_portrait: Texture2D = null
static var _cached_modal_card_square: Texture2D = null

static func get_modal_card_texture(kind: String = "portrait") -> Texture2D:
	if kind == "portrait":
		if _cached_modal_card_portrait and is_instance_valid(_cached_modal_card_portrait):
			return _cached_modal_card_portrait
		var local_dest = ProjectSettings.globalize_path("res://assets/images/general/blue_modal_card_portrait.png")
		if FileAccess.file_exists(MODAL_CARD_PORTRAIT_SRC):
			var bytes = FileAccess.get_file_as_bytes(MODAL_CARD_PORTRAIT_SRC)
			if bytes.size() > 0:
				DirAccess.make_dir_recursive_absolute(local_dest.get_base_dir())
				var f = FileAccess.open(local_dest, FileAccess.WRITE)
				if f:
					f.store_buffer(bytes)
					f.close()
		var tex = load_texture_safe(local_dest)
		if not tex:
			tex = load_texture_safe(MODAL_CARD_PORTRAIT_SRC)
		_cached_modal_card_portrait = tex
		return tex
	else:
		if _cached_modal_card_square and is_instance_valid(_cached_modal_card_square):
			return _cached_modal_card_square
		var local_dest = ProjectSettings.globalize_path("res://assets/images/general/blue_modal_card_square.png")
		if FileAccess.file_exists(MODAL_CARD_SQUARE_SRC):
			var bytes = FileAccess.get_file_as_bytes(MODAL_CARD_SQUARE_SRC)
			if bytes.size() > 0:
				DirAccess.make_dir_recursive_absolute(local_dest.get_base_dir())
				var f = FileAccess.open(local_dest, FileAccess.WRITE)
				if f:
					f.store_buffer(bytes)
					f.close()
		var tex = load_texture_safe(local_dest)
		if not tex:
			tex = load_texture_safe(MODAL_CARD_SQUARE_SRC)
		_cached_modal_card_square = tex
		return tex

static func show_parental_gate(parent_node: Node, on_success: Callable, on_cancel: Callable = Callable(), title_override: String = ""):
	var target_parent: Node = parent_node
	if parent_node.is_inside_tree():
		var main_node = parent_node.get_tree().root.get_node_or_null("Main")
		if main_node and is_instance_valid(main_node):
			target_parent = main_node

	var safe_sz = get_viewport_safe_size(target_parent)
	var card_w = clamp(safe_sz.x - 48.0, 300.0, 360.0)
	var gs = _get_game_state()
	var is_setup = not (gs and gs.has_method("has_tooth_fairy_pin") and gs.has_tooth_fairy_pin())
	var card_h = 360.0 if is_setup else 310.0

	var dlg = create_modal_dialog(target_parent, 250, Color(0.04, 0.10, 0.22, 0.75))
	var overlay = dlg["overlay"]
	var center = dlg["center"]
	overlay.name = "ParentalGateOverlay"
	
	var card = Panel.new()
	card.custom_minimum_size = Vector2(card_w, card_h)
	card.size = Vector2(card_w, card_h)
	var card_style = create_bubbly_panel(28, Color.WHITE, Color(0.35, 0.72, 0.96), 3)
	card.add_theme_stylebox_override("panel", card_style)
	center.add_child(card)
	
	var close_btn = create_close_button(Vector2(30, 30))
	close_btn.position = Vector2(card_w - 38.0, 10)
	close_btn.pressed.connect(func():
		_play_sfx_safe("click")
		overlay.queue_free()
		if on_cancel.is_valid():
			on_cancel.call()
	)
	card.add_child(close_btn)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 20.0
	vbox.offset_right = -20.0
	vbox.offset_top = 18.0
	vbox.offset_bottom = -18.0
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 10)
	card.add_child(vbox)
	
	var title_lbl = Label.new()
	title_lbl.text = title_override if title_override != "" else ("SET TOOTH FAIRY PIN" if is_setup else "PARENTAL GATE")
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	apply_bubbly_label(title_lbl, 18, Color(0.18, 0.40, 0.70), true)
	vbox.add_child(title_lbl)
	
	var sub_lbl = Label.new()
	sub_lbl.text = "Set a 4-digit Tooth Fairy PIN to protect parental settings." if is_setup else "Enter your 4-digit Tooth Fairy PIN to proceed."
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	apply_bubbly_label(sub_lbl, 11, Color(0.35, 0.48, 0.65), false)
	vbox.add_child(sub_lbl)
	
	var err_lbl = Label.new()
	err_lbl.text = ""
	err_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	apply_bubbly_label(err_lbl, 11, Color(0.92, 0.25, 0.20), true)
	err_lbl.visible = false
	vbox.add_child(err_lbl)
	
	if is_setup:
		var pin_input = LineEdit.new()
		pin_input.placeholder_text = "Enter 4-digit PIN..."
		pin_input.secret = true
		pin_input.max_length = 4
		pin_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
		pin_input.custom_minimum_size = Vector2(card_w - 48.0, 40)
		var in_st = create_bubbly_panel(20, Color(0.94, 0.97, 1.0), Color(0.80, 0.88, 0.98), 1)
		in_st.content_margin_left = 10
		in_st.content_margin_right = 10
		pin_input.add_theme_stylebox_override("normal", in_st)
		pin_input.add_theme_color_override("font_color", Color(0.10, 0.15, 0.30))
		pin_input.add_theme_color_override("placeholder_color", Color(0.15, 0.25, 0.45, 0.90))
		pin_input.add_theme_color_override("font_placeholder_color", Color(0.15, 0.25, 0.45, 0.90))
		vbox.add_child(pin_input)
		
		var conf_input = LineEdit.new()
		conf_input.placeholder_text = "Confirm 4-digit PIN..."
		conf_input.secret = true
		conf_input.max_length = 4
		conf_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
		conf_input.custom_minimum_size = Vector2(card_w - 48.0, 40)
		conf_input.add_theme_stylebox_override("normal", in_st)
		conf_input.add_theme_color_override("font_color", Color(0.10, 0.15, 0.30))
		conf_input.add_theme_color_override("placeholder_color", Color(0.15, 0.25, 0.45, 0.90))
		conf_input.add_theme_color_override("font_placeholder_color", Color(0.15, 0.25, 0.45, 0.90))
		vbox.add_child(conf_input)
		
		var save_btn = create_bubbly_button("SAVE PIN & CONTINUE", VIBRANT_GREEN)
		save_btn.custom_minimum_size = Vector2(card_w - 48.0, 44)
		save_btn.pressed.connect(func():
			var p1 = pin_input.text.strip_edges()
			var p2 = conf_input.text.strip_edges()
			if p1.length() != 4 or not p1.is_valid_int():
				err_lbl.text = "PIN must be exactly 4 digits."
				err_lbl.visible = true
				_play_sfx_safe("click")
				return
			if p1 != p2:
				err_lbl.text = "PINs do not match. Try again."
				err_lbl.visible = true
				_play_sfx_safe("click")
				return
			if gs and gs.has_method("set_tooth_fairy_pin"):
				gs.set_tooth_fairy_pin(p1)
			_play_sfx_safe("pop")
			if gs and gs.has_method("push_toast"):
				gs.push_toast("PIN Created", "Tooth Fairy PIN saved successfully!", "", "green")
			overlay.queue_free()
			on_success.call()
		)
		vbox.add_child(save_btn)
	else:
		var pin_input = LineEdit.new()
		pin_input.placeholder_text = "• • • •"
		pin_input.secret = true
		pin_input.max_length = 4
		pin_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
		pin_input.custom_minimum_size = Vector2(180, 44)
		var in_st = create_bubbly_panel(22, Color(0.94, 0.97, 1.0), Color(0.80, 0.88, 0.98), 2)
		in_st.content_margin_left = 10
		in_st.content_margin_right = 10
		pin_input.add_theme_stylebox_override("normal", in_st)
		pin_input.add_theme_color_override("font_color", Color(0.10, 0.15, 0.30))
		pin_input.add_theme_color_override("placeholder_color", Color(0.15, 0.25, 0.45, 0.90))
		pin_input.add_theme_color_override("font_placeholder_color", Color(0.15, 0.25, 0.45, 0.90))
		pin_input.add_theme_font_size_override("font_size", 22)
		
		var pin_center = CenterContainer.new()
		pin_center.add_child(pin_input)
		vbox.add_child(pin_center)
		
		var unlock_btn = create_bubbly_button("UNLOCK", VIBRANT_GREEN)
		unlock_btn.custom_minimum_size = Vector2(card_w - 48.0, 44)
		unlock_btn.pressed.connect(func():
			var entered = pin_input.text.strip_edges()
			if gs and gs.has_method("verify_tooth_fairy_pin") and gs.verify_tooth_fairy_pin(entered):
				_play_sfx_safe("pop")
				overlay.queue_free()
				on_success.call()
			else:
				err_lbl.text = "Incorrect PIN. Please try again."
				err_lbl.visible = true
				pin_input.text = ""
				_play_sfx_safe("click")
		)
		vbox.add_child(unlock_btn)

static func show_dental_item_unlocked_modal(parent_node: Node, w_def: Dictionary, on_close: Callable = Callable()):
	if not parent_node:
		return
		
	var target_parent: Node = parent_node
	if parent_node.is_inside_tree():
		var main_node = parent_node.get_tree().root.get_node_or_null("Main")
		if main_node and is_instance_valid(main_node):
			target_parent = main_node

	var safe_sz = get_viewport_safe_size(target_parent)
	var cur_w = safe_sz.x
	var cur_h = safe_sz.y
	var is_tablet = cur_w >= 560
	
	# Full-screen cheerful sky gradient backdrop matching all other pages
	var overlay = Control.new()
	overlay.name = "DentalItemUnlockedOverlay"
	overlay.z_index = 250
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	target_parent.add_child(overlay)
	
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.anchor_left = 0.0
	overlay.anchor_top = 0.0
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.offset_left = 0
	overlay.offset_top = 0
	overlay.offset_right = 0
	overlay.offset_bottom = 0
	overlay.position = Vector2.ZERO
	overlay.size = safe_sz
	
	var bg_tex = TextureRect.new()
	bg_tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_tex.anchor_right = 1.0
	bg_tex.anchor_bottom = 1.0
	bg_tex.offset_right = 0
	bg_tex.offset_bottom = 0
	bg_tex.texture = create_sky_gradient_texture()
	bg_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_tex.stretch_mode = TextureRect.STRETCH_SCALE
	bg_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(bg_tex)
	
	# Ambient floating translucent bubbles in background (rising up continuously)
	var bubble_icons = [
		"res://assets/images/upgradeitem/bubble_asset.png",
		"res://assets/images/upgradeitem/colorful_bubble.png",
		"res://assets/images/upgradeitem/transparent_bubble.png",
		"res://assets/images/upgradeitem/bubble_icon.png"
	]
	
	var bubble_layer = Control.new()
	bubble_layer.name = "BubbleLayer"
	bubble_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	bubble_layer.anchor_right = 1.0
	bubble_layer.anchor_bottom = 1.0
	bubble_layer.offset_right = 0
	bubble_layer.offset_bottom = 0
	bubble_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(bubble_layer)
	
	for i in range(24):
		var b_tex_path = bubble_icons[i % bubble_icons.size()]
		var b_tex = load_texture_safe(b_tex_path)
		if not b_tex:
			b_tex = load_texture_safe("res://assets/images/upgradeitem/bubble_asset.png")
		if b_tex:
			var b_rect = TextureRect.new()
			b_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			b_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			var b_sz = randf_range(14.0, 26.0)
			b_rect.custom_minimum_size = Vector2(b_sz, b_sz)
			b_rect.size = Vector2(b_sz, b_sz)
			b_rect.texture = b_tex
			b_rect.modulate = Color(1, 1, 1, randf_range(0.35, 0.70))
			b_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b_rect.position = Vector2(randf_range(10.0, max(20.0, cur_w - 35.0)), randf_range(20.0, cur_h + 100.0))
			bubble_layer.add_child(b_rect)
			
			_animate_modal_bubble(b_rect, cur_h, cur_w)
	
	# Top Stats Pills
	# Top Left: Coins Pill
	var coins_pill = Panel.new()
	var cp_st = create_bubbly_panel(16, Color(1, 1, 1, 0.90), Color(0.96, 0.72, 0.15), 2)
	coins_pill.add_theme_stylebox_override("panel", cp_st)
	coins_pill.custom_minimum_size = Vector2(105, 34)
	coins_pill.size = Vector2(105, 34)
	coins_pill.position = Vector2(16, 16)
	
	var c_hbox = HBoxContainer.new()
	c_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	c_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	c_hbox.add_theme_constant_override("separation", 6)
	
	var c_icon = TextureRect.new()
	c_icon.texture = load_texture_safe("res://assets/images/congratulations/gold_tooth_coin.png")
	c_icon.custom_minimum_size = Vector2(20, 20)
	c_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	c_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	c_hbox.add_child(c_icon)
	
	var gs = _get_game_state()
	var coins = gs.get_coins() if (gs and gs.has_method("get_coins")) else 0
	var c_lbl = Label.new()
	c_lbl.text = str(coins) + " Coins"
	apply_bubbly_label(c_lbl, 11, Color(0.65, 0.40, 0.05), true)
	c_hbox.add_child(c_lbl)
	coins_pill.add_child(c_hbox)
	overlay.add_child(coins_pill)
	
	# Top Right: Points Pill (symmetrically positioned 16px from right edge)
	var points_pill = Panel.new()
	var pp_st = create_bubbly_panel(16, Color(1, 1, 1, 0.90), Color(0.70, 0.35, 0.90), 2)
	points_pill.add_theme_stylebox_override("panel", pp_st)
	points_pill.custom_minimum_size = Vector2(115, 34)
	points_pill.size = Vector2(115, 34)
	points_pill.position = Vector2(cur_w - 115 - 16, 16)
	
	var p_hbox = HBoxContainer.new()
	p_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	p_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	p_hbox.add_theme_constant_override("separation", 6)
	
	var p_icon = TextureRect.new()
	p_icon.texture = load_texture_safe("res://assets/images/shop/purple_star_points.png")
	p_icon.custom_minimum_size = Vector2(20, 20)
	p_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	p_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	p_hbox.add_child(p_icon)
	
	var pts = gs.get_points() if (gs and gs.has_method("get_points")) else 0
	var p_lbl = Label.new()
	p_lbl.text = str(pts) + " Points"
	apply_bubbly_label(p_lbl, 11, Color(0.48, 0.18, 0.68), true)
	p_hbox.add_child(p_lbl)
	points_pill.add_child(p_hbox)
	overlay.add_child(points_pill)
	
	var close_fn = func():
		_play_sfx_safe("click")
		overlay.queue_free()
		
		var raw_wep = str(w_def.get("weapon_id", "")).to_lower()
		var raw_id = str(w_def.get("id", "")).to_lower()
		var item_raw_name = str(w_def.get("name", "")).to_lower() + " " + str(w_def.get("full_name", "")).to_lower()
		var all_text = raw_wep + " " + raw_id + " " + item_raw_name
		
		var w_id = "brush"
		if "wash" in all_text or "mouthwash" in all_text or "blast" in all_text:
			w_id = "wash"
		elif "paste" in all_text or "toothpaste" in all_text or "pistol" in all_text:
			w_id = "paste"
		elif "floss" in all_text or "lasso" in all_text:
			w_id = "floss"
		elif "brush" in all_text or "toothbrush" in all_text or "boomerang" in all_text:
			w_id = "brush"
			
		var main_node = target_parent.get_tree().root.get_node_or_null("Main")
		if not main_node and target_parent.name == "Main":
			main_node = target_parent
		if not main_node and target_parent.has_method("navigate_to"):
			main_node = target_parent
			
		if parent_node and is_instance_valid(parent_node) and parent_node.has_method("setup_view"):
			parent_node.setup_view(w_id, "powerups")
		elif main_node and main_node.has_method("navigate_to"):
			main_node.navigate_to("shop", {"expand_weapon": w_id, "tab": "powerups"})
		elif on_close.is_valid():
			on_close.call()
	
	# Main Content Column (Centered Vertically & Horizontally with balanced sizing)
	var content_w = min(cur_w - 16.0, 420.0)
	var top_offset = 58.0
	var bottom_offset = 20.0
	var content_area_h = cur_h - top_offset - bottom_offset
	
	var content_col = VBoxContainer.new()
	content_col.custom_minimum_size = Vector2(content_w, content_area_h)
	content_col.size = Vector2(content_w, content_area_h)
	content_col.position = Vector2((cur_w - content_w) * 0.5, top_offset)
	content_col.alignment = BoxContainer.ALIGNMENT_CENTER
	content_col.add_theme_constant_override("separation", 16 if not is_tablet else 22)
	content_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(content_col)
	
	# 1. Header Graphic: "NEW DENTAL ITEM!" (Crisp & proportional)
	var title_tex = load_texture_safe("res://assets/images/shop/newdentalitemunlockedtext.png")
	if title_tex:
		var title_img = TextureRect.new()
		title_img.texture = title_tex
		var title_tw = min(content_w - 10.0, 300.0 if not is_tablet else 380.0)
		var th = title_tw * (float(title_tex.get_height()) / float(title_tex.get_width()))
		title_img.custom_minimum_size = Vector2(title_tw, th)
		title_img.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		title_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		title_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		content_col.add_child(title_img)
	else:
		var title_lbl = Label.new()
		title_lbl.text = "NEW DENTAL ITEM!"
		title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		apply_bubbly_label(title_lbl, 28 if not is_tablet else 34, Color.WHITE, true)
		content_col.add_child(title_lbl)
		
	# 2. Futuristic Weapon Pod (WeaponHolder.png) — Proportional heroic scale
	var holder_tex = load_texture_safe("res://assets/images/shop/WeaponHolder.png")
	var pod_h = clampf(cur_h * 0.38, 220.0, 310.0 if not is_tablet else 380.0)
	var pod_w = pod_h / 1.74
		
	var pod_container = Control.new()
	pod_container.custom_minimum_size = Vector2(pod_w, pod_h)
	pod_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	
	if holder_tex:
		var holder_rect = TextureRect.new()
		holder_rect.texture = holder_tex
		holder_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		holder_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		holder_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		holder_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pod_container.add_child(holder_rect)
		
	# Floating Weapon Icon inside Pod (centered in the upper glass chamber)
	var w_img_path = w_def.get("images", [""])[0] if w_def.has("images") else ""
	var icon_tex = load_texture_safe(w_img_path)
	if not icon_tex:
		var w_id = w_def.get("weapon_id", w_def.get("id", ""))
		var tier = int(w_def.get("tier", 1))
		icon_tex = get_weapon_texture(w_id, tier)
	if icon_tex:
		var item_icon = TextureRect.new()
		var icon_sz = pod_w * 0.74
		item_icon.custom_minimum_size = Vector2(icon_sz, icon_sz)
		item_icon.size = Vector2(icon_sz, icon_sz)
		item_icon.texture = icon_tex
		item_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		item_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		item_icon.pivot_offset = Vector2(icon_sz * 0.5, icon_sz * 0.5)
		item_icon.rotation_degrees = -8.0
		item_icon.position = Vector2((pod_w - icon_sz) * 0.5, (pod_h - icon_sz) * 0.40)
		pod_container.add_child(item_icon)
		
		# Smooth floating animation (sine wave oscillating float)
		var base_y = item_icon.position.y
		var tw_float = item_icon.create_tween().set_loops()
		tw_float.tween_property(item_icon, "position:y", base_y - 6.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw_float.tween_property(item_icon, "position:y", base_y + 6.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		
	content_col.add_child(pod_container)
	
	# 3. Item Level / Name Subtitle stating what the item is in all caps (e.g. LEVEL 2 PASTE PISTOL)
	var _unlock_day = int(w_def.get("unlock_day", 1))
	var tier_num = int(w_def.get("tier", 1))
	var raw_name = str(w_def.get("full_name", w_def.get("name", "Dental Weapon"))).to_upper().strip_edges()
	
	var item_title = ""
	if tier_num > 1:
		item_title = "LEVEL %d %s" % [tier_num, raw_name]
	else:
		item_title = raw_name
	item_title = item_title.to_upper()
	
	var label_vbox = VBoxContainer.new()
	label_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	label_vbox.add_theme_constant_override("separation", 6)
	
	var name_lbl = Label.new()
	name_lbl.text = item_title
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	apply_bubbly_label(name_lbl, 24 if not is_tablet else 30, Color.WHITE, true)
	name_lbl.add_theme_color_override("font_shadow_color", Color(0.06, 0.22, 0.48, 0.95))
	name_lbl.add_theme_constant_override("shadow_offset_y", 2)
	name_lbl.add_theme_constant_override("shadow_outline_size", 5)
	label_vbox.add_child(name_lbl)
	
	var sub_lbl = Label.new()
	sub_lbl.text = "Special Upgrade! Now Available in the Shop!"
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	apply_bubbly_label(sub_lbl, 15 if not is_tablet else 18, Color(0.85, 0.95, 1.0), true)
	sub_lbl.add_theme_color_override("font_shadow_color", Color(0.06, 0.22, 0.48, 0.85))
	sub_lbl.add_theme_constant_override("shadow_offset_y", 1)
	label_vbox.add_child(sub_lbl)
	
	content_col.add_child(label_vbox)
	
	# 4. UNLOCK Button at the Bottom
	var btn_w = clampf(content_w - 40.0, 220.0, 280.0 if not is_tablet else 340.0)
	var btn_h = 56.0 if not is_tablet else 64.0
	
	var ok_btn = create_image_button("res://assets/images/buttons/unlock_btn.png", Vector2(btn_w, btn_h))
	if not ok_btn.texture_normal:
		ok_btn = create_themed_button("unlock", Vector2(btn_w, btn_h))
	if not ok_btn.texture_normal:
		ok_btn = Button.new()
		ok_btn.custom_minimum_size = Vector2(btn_w, btn_h)
		var btn_st = create_bubbly_panel(23, Color(0.40, 0.78, 0.98), Color.WHITE, 3)
		ok_btn.add_theme_stylebox_override("normal", btn_st)
		var btn_lbl = Label.new()
		btn_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		btn_lbl.text = "UNLOCK"
		btn_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		apply_bubbly_label(btn_lbl, 22 if not is_tablet else 26, Color.WHITE, true)
		ok_btn.add_child(btn_lbl)
		
	ok_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok_btn.pressed.connect(close_fn)
	content_col.add_child(ok_btn)
	
	# Pop-in bouncy scale animation
	content_col.pivot_offset = Vector2(content_w * 0.5, content_area_h * 0.5)
	content_col.scale = Vector2(0.85, 0.85)
	content_col.modulate.a = 0.0
	var tw = content_col.create_tween().set_parallel(true)
	tw.tween_property(content_col, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(content_col, "modulate:a", 1.0, 0.18)
	
	_play_sfx_safe("unlock")

static func _animate_modal_bubble(b: TextureRect, screen_h: float, screen_w: float):
	if not b or not is_instance_valid(b):
		return
	var dur = randf_range(5.0, 9.5)
	var end_y = -80.0
	var start_x = b.position.x
	var target_x = clampf(start_x + randf_range(-35.0, 35.0), 10.0, max(20.0, screen_w - 35.0))
	
	var tw = b.create_tween()
	tw.set_parallel(true)
	tw.tween_property(b, "position:y", end_y, dur).set_trans(Tween.TRANS_LINEAR)
	tw.tween_property(b, "position:x", target_x, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	tw.finished.connect(func():
		if is_instance_valid(b):
			b.position.y = screen_h + randf_range(10.0, 80.0)
			b.position.x = randf_range(10.0, max(20.0, screen_w - 35.0))
			_animate_modal_bubble(b, screen_h, screen_w)
	)

static func show_story_panel_modal(parent_node: Node, day_num: int, on_close: Callable = Callable()):
	if not parent_node:
		return
		
	var idx = clampi(day_num - 1, 0, 27)
	var story_files = [
		"1_Start_Blue_Pursue.jpeg", "2_Run.jpeg", "3_Ask_gingerbread.jpeg", "4_Gingerbread_Chase_.jpeg",
		"5_Peppermint_Defense_.jpeg", "6_Crossroads.jpeg", "7_Choco_River.jpeg", "8_Fountain_Hiding.jpeg",
		"9_First_Candy_Combat.jpeg", "10_Energy_Refill_Fruit.jpeg", "11_Friendly_Banana.jpeg", "12_Unchartered_Waters.jpeg",
		"13_See_some_fish.jpeg", "14_Trap.jpeg", "15_Spot_Blue_Fur.jpeg", "16_Hide_in_water.jpeg",
		"17_Veggie_Village.jpeg", "18_Flora_Seeds.jpeg", "19_Second_Candy_Combat.jpeg", "20_Run_for_it.jpeg",
		"21_Help_eachother_up.jpeg", "22_Scouting.jpeg", "23_Plant_Seeds.jpeg", "24_Drinking_Well.jpeg",
		"25_Caterpillar_in_hiding.jpeg", "26_Frosty_Butterfly.jpeg", "27_Near_Mulinia.jpeg", "28_Finish.jpeg"
	]
	var story_titles = [
		"Start: Blue Pursues", "The Great Escape", "Ask The Gingerbread", "Gingerbread Chase",
		"Peppermint Defense", "The Crossroads", "Choco River Crossing", "Fountain Hiding",
		"First Candy Combat", "Energy Refill Fruit", "The Friendly Banana", "Uncharted Waters",
		"Sea of Smiles", "The Sticky Trap", "Spotting Blue Fur", "Hide in the Bubbles",
		"Veggie Village", "Flora's Magic Seeds", "Second Candy Combat", "Run For It!",
		"Helping Hands", "Scouting Ahead", "Planting Good Habits", "The Clean Water Well",
		"Caterpillar in Hiding", "The Frosty Butterfly", "Near Mount Mulinia", "Victory & The Golden Smile"
	]
	
	var title_text = story_titles[idx]
	var s_gs = _get_game_state()
	var s_story = s_gs.get("STORY") if (s_gs and "STORY" in s_gs) else []
	if idx < s_story.size():
		title_text = s_story[idx].get("title", title_text)
		
	var story_text = "Chip and friends push onward through the kingdom, scrubbing every germ away with mighty foam power!"
	if idx < s_story.size():
		story_text = s_story[idx].get("panel", story_text)
		
	var target_parent: Node = parent_node
	if parent_node.is_inside_tree():
		var main_node = parent_node.get_tree().root.get_node_or_null("Main")
		if main_node and is_instance_valid(main_node):
			target_parent = main_node

	var safe_sz = get_viewport_safe_size(target_parent)
	var cur_w = safe_sz.x
	var cur_h = safe_sz.y
	
	var overlay = ColorRect.new()
	overlay.name = "StoryPanelModalOverlay"
	overlay.color = Color(0.04, 0.10, 0.24, 0.88)
	overlay.z_index = 250
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	target_parent.add_child(overlay)
	
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.anchor_left = 0.0
	overlay.anchor_top = 0.0
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.offset_left = 0
	overlay.offset_top = 0
	overlay.offset_right = 0
	overlay.offset_bottom = 0
	overlay.position = Vector2.ZERO
	overlay.size = safe_sz
	
	var close_fn = func():
		_stop_narration_safe()
		_play_sfx_safe("click")
		overlay.queue_free()
		if on_close.is_valid():
			on_close.call()
	overlay.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			close_fn.call()
	)
	
	var center = CenterContainer.new()
	center.name = "CenterContainer"
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)
	
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.anchor_left = 0.0
	center.anchor_top = 0.0
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	center.offset_left = 0
	center.offset_top = 0
	center.offset_right = 0
	center.offset_bottom = 0
	center.position = Vector2.ZERO
	center.size = safe_sz
	
	var card_w = clampf(cur_w * 0.92, 340.0, 520.0)
	var max_allowed_w = cur_w - 24.0
	if card_w > max_allowed_w:
		card_w = max_allowed_w
		
	var art_y = 70.0
	var art_size = clampf(card_w - 32.0, 240.0, 460.0)
	var btn_row_y = art_y + art_size + 16.0
	var card_h = btn_row_y + 56.0
	var max_allowed_h = cur_h - 32.0
	if card_h > max_allowed_h:
		card_h = max_allowed_h
		art_size = clampf(card_h - art_y - 72.0, 200.0, 420.0)
		btn_row_y = art_y + art_size + 16.0
		
	var card = Control.new()
	card.custom_minimum_size = Vector2(card_w, card_h)
	card.size = Vector2(card_w, card_h)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var card_bg = Panel.new()
	card_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var c_st = StyleBoxFlat.new()
	c_st.bg_color = Color(1.0, 1.0, 1.0, 0.98)
	c_st.set_corner_radius_all(24)
	c_st.set_border_width_all(3)
	c_st.border_color = Color(0.82, 0.92, 1.0)
	c_st.shadow_color = Color(0.04, 0.12, 0.28, 0.20)
	c_st.shadow_size = 10
	c_st.shadow_offset = Vector2(0, 4)
	card_bg.add_theme_stylebox_override("panel", c_st)
	card_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(card_bg)
	
	center.add_child(card)
	
	overlay.resized.connect(func():
		var sz = get_viewport_safe_size(target_parent)
		overlay.position = Vector2.ZERO
		overlay.size = sz
		center.position = Vector2.ZERO
		center.size = sz
	)
	
	var close_x_btn = create_close_button(Vector2(32, 32))
	close_x_btn.position = Vector2(card_w - 40.0, 10.0)
	close_x_btn.z_index = 25
	close_x_btn.pressed.connect(close_fn)
	card.add_child(close_x_btn)
	
	# Chapter Badge
	var badge = Panel.new()
	var badge_w = 148.0
	var badge_h = 24.0
	badge.position = Vector2((card_w - badge_w) * 0.5, 14.0)
	badge.size = Vector2(badge_w, badge_h)
	var badge_st = StyleBoxFlat.new()
	badge_st.bg_color = Color(1.0, 0.82, 0.20)
	badge_st.set_corner_radius_all(12)
	badge_st.border_color = Color(1.0, 0.96, 0.70)
	badge_st.set_border_width_all(2)
	badge.add_theme_stylebox_override("panel", badge_st)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(badge)
	
	var badge_lbl = Label.new()
	badge_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	badge_lbl.text = "CHAPTER %d UNLOCKED" % day_num
	badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	apply_bubbly_label(badge_lbl, 10, Color(0.48, 0.26, 0.0), true)
	badge.add_child(badge_lbl)
	
	# Chapter Title
	var title_lbl = Label.new()
	title_lbl.position = Vector2(20.0, 40.0)
	title_lbl.size = Vector2(card_w - 40.0, 26.0)
	title_lbl.text = title_text
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	apply_bubbly_label(title_lbl, 17, Color(0.12, 0.32, 0.62), true)
	title_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.0))
	card.add_child(title_lbl)
	
	# Square Comic Artwork Frame
	var art_frame = Panel.new()
	art_frame.position = Vector2((card_w - art_size) * 0.5, art_y)
	art_frame.size = Vector2(art_size, art_size)
	art_frame.clip_contents = true
	var art_st = StyleBoxFlat.new()
	art_st.bg_color = Color.WHITE
	art_st.set_corner_radius_all(16)
	art_st.set_border_width_all(3)
	art_st.border_color = Color.WHITE
	art_st.shadow_color = Color(0.08, 0.22, 0.42, 0.20)
	art_st.shadow_size = 6
	art_frame.add_theme_stylebox_override("panel", art_st)
	art_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(art_frame)
	
	var art_img = TextureRect.new()
	art_img.set_anchors_preset(Control.PRESET_FULL_RECT)
	var img_tex = load_texture_safe("res://assets/images/scrapbook/StoryPanels/%s" % story_files[idx])
	if img_tex:
		art_img.texture = img_tex
	art_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art_frame.add_child(art_img)
	
	# Bottom Action Button: Read Story button takes player to the Storybook Screen
	var read_story_btn = create_image_button("res://assets/images/buttons/readbtn.png", Vector2(170.0, 48.0))
	if not read_story_btn.texture_normal:
		read_story_btn = create_themed_button("readbtn", Vector2(170.0, 48.0))
	if not read_story_btn.texture_normal:
		read_story_btn = create_bubbly_button("READ STORY", Color(0.20, 0.58, 0.94), Color.WHITE)
		read_story_btn.custom_minimum_size = Vector2(170.0, 44.0)
	read_story_btn.position = Vector2((card_w - 170.0) * 0.5, btn_row_y)
	
	read_story_btn.pressed.connect(func():
		_stop_narration_safe()
		_play_sfx_safe("click")
		overlay.queue_free()
		var main_node = parent_node.get_tree().root.get_node_or_null("Main")
		if main_node and main_node.has_method("navigate_to"):
			main_node.navigate_to("story", {"auto_show_day": day_num})
		elif on_close.is_valid():
			on_close.call()
	)
	card.add_child(read_story_btn)
	
	card.pivot_offset = Vector2(card_w * 0.5, card_h * 0.5)
	card.scale = Vector2(0.85, 0.85)
	card.modulate.a = 0.0
	var tw = card.create_tween().set_parallel(true)
	tw.tween_property(card, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "modulate:a", 1.0, 0.15)
	
	_play_sfx_safe("unlock")

# ==============================================================================
# NODE 0: OFFICIAL STORY LORE PROLOGUE MODAL
# 1. The Discovery (Sacred map of Mulinia found in Sweetmania cave)
# 2. The Ambush (Blue Candor ambushes & map rips in half)
# 3. The Chase (28-day escape run to Mulinia)
# ==============================================================================
static func show_node0_story_intro_modal(parent_node: Node, on_complete: Callable = Callable()):
	if not parent_node:
		return
		
	var target_parent: Node = parent_node
	if parent_node.is_inside_tree():
		var main_node = parent_node.get_tree().root.get_node_or_null("Main")
		if main_node and is_instance_valid(main_node):
			target_parent = main_node

	AudioManager.play_sfx("pop")
	var safe_sz = get_viewport_safe_size(target_parent)
	var cur_w = safe_sz.x
	var cur_h = safe_sz.y
	
	var overlay = ColorRect.new()
	overlay.name = "Node0StoryIntroOverlay"
	overlay.color = Color(0.04, 0.08, 0.20, 0.90)
	overlay.z_index = 260
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	target_parent.add_child(overlay)
	
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.position = Vector2.ZERO
	overlay.size = safe_sz
	
	var slides = [
		{
			"badge": "PROLOGUE · PART 1 OF 3",
			"badge_color": Color(0.18, 0.58, 0.92),
			"title": "THE DISCOVERY",
			"image": "res://assets/images/scrapbook/StoryPanels/1_Start_Blue_Pursue.jpeg",
			"fallback_image": "res://assets/images/characters/chip-bg.png",
			"text": "Deep in a hidden cave in Sweetmania, the Molars stumble across an ancient relic — the sacred map of their home kingdom, Mulinia!"
		},
		{
			"badge": "PROLOGUE · PART 2 OF 3",
			"badge_color": Color(0.92, 0.35, 0.22),
			"title": "THE AMBUSH!",
			"image": "res://assets/images/scrapbook/StoryPanels/9_First_Candy_Combat.jpeg",
			"fallback_image": "res://assets/images/candycrusadegame/Blue-Candor.png",
			"text": "Suddenly, the villainous Blue Candor appears from the shadows to seize the map! In the frantic struggle, the sacred map rips right in half!"
		},
		{
			"badge": "PROLOGUE · PART 3 OF 3",
			"badge_color": Color(0.20, 0.76, 0.38),
			"title": "THE 28-DAY CHASE",
			"image": "res://assets/images/scrapbook/StoryPanels/2_Run.jpeg",
			"fallback_image": "res://assets/images/characters/blaze-bg.png",
			"text": "Blue Candor secures one half, leaving the Molars with the other!\n\nThe Molars must immediately begin their 28-day escape run back to Mulinia to outpace Blue Candor and save their home!\n\nEvery day you brush and answer trivia keeps you safely ahead of the villain!"
		}
	]
	
	var current_slide_idx = [0]
	
	var center = CenterContainer.new()
	center.name = "CenterContainer"
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.position = Vector2.ZERO
	center.size = safe_sz
	
	var card_w = clampf(cur_w * 0.92, 330.0, 480.0)
	var card_h = clampf(cur_h * 0.82, 480.0, 600.0)
	
	var card = Control.new()
	card.custom_minimum_size = Vector2(card_w, card_h)
	card.size = Vector2(card_w, card_h)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(card)
	
	var card_bg = Panel.new()
	card_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var c_st = StyleBoxFlat.new()
	c_st.bg_color = Color(1.0, 1.0, 1.0, 0.98)
	c_st.set_corner_radius_all(24)
	c_st.set_border_width_all(3)
	c_st.border_color = Color(0.80, 0.90, 1.0)
	c_st.shadow_color = Color(0.04, 0.12, 0.28, 0.25)
	c_st.shadow_size = 12
	c_st.shadow_offset = Vector2(0, 5)
	card_bg.add_theme_stylebox_override("panel", c_st)
	card_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(card_bg)
	
	var close_fn = func():
		_stop_narration_safe()
		_play_sfx_safe("click")
		var card_tw = card.create_tween().set_parallel(true)
		card_tw.tween_property(card, "scale", Vector2(0.85, 0.85), 0.15)
		card_tw.tween_property(overlay, "modulate:a", 0.0, 0.15)
		card_tw.finished.connect(func():
			overlay.queue_free()
			if on_complete.is_valid():
				on_complete.call()
		)
	
	# Skip / Close Button on top right
	var skip_btn = Button.new()
	skip_btn.text = "SKIP"
	skip_btn.position = Vector2(card_w - 92.0, 10.0)
	skip_btn.size = Vector2(80.0, 28.0)
	skip_btn.focus_mode = Control.FOCUS_NONE
	var skip_st = StyleBoxFlat.new()
	skip_st.bg_color = Color(0.12, 0.28, 0.50, 0.15)
	skip_st.set_corner_radius_all(10)
	skip_btn.add_theme_stylebox_override("normal", skip_st)
	skip_btn.add_theme_stylebox_override("hover", skip_st)
	skip_btn.add_theme_stylebox_override("pressed", skip_st)
	apply_bubbly_label(skip_btn, 11, Color(0.35, 0.55, 0.75), true)
	skip_btn.pressed.connect(close_fn)
	card.add_child(skip_btn)
	
	# Badge
	var badge = Panel.new()
	var badge_w = 190.0
	var badge_h = 24.0
	badge.position = Vector2((card_w - badge_w) * 0.5, 14.0)
	badge.size = Vector2(badge_w, badge_h)
	var badge_st = StyleBoxFlat.new()
	badge_st.bg_color = Color(0.18, 0.58, 0.92)
	badge_st.set_corner_radius_all(12)
	badge_st.border_color = Color.WHITE
	badge_st.set_border_width_all(1)
	badge.add_theme_stylebox_override("panel", badge_st)
	card.add_child(badge)
	
	var badge_lbl = Label.new()
	badge_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	apply_bubbly_label(badge_lbl, 11, Color.WHITE, true)
	badge.add_child(badge_lbl)
	
	# Title
	var title_lbl = Label.new()
	title_lbl.position = Vector2(16.0, 42.0)
	title_lbl.size = Vector2(card_w - 32.0, 28.0)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	apply_bubbly_label(title_lbl, 18, Color(0.12, 0.32, 0.62), true)
	card.add_child(title_lbl)
	
	# Artwork Frame
	var art_y = 74.0
	var art_w = card_w - 36.0
	var art_h = clampf(card_h * 0.40, 170.0, 240.0)
	var art_frame = Panel.new()
	art_frame.position = Vector2((card_w - art_w) * 0.5, art_y)
	art_frame.size = Vector2(art_w, art_h)
	art_frame.clip_contents = true
	var art_st = StyleBoxFlat.new()
	art_st.bg_color = Color(0.08, 0.18, 0.32, 0.95)
	art_st.set_corner_radius_all(16)
	art_st.set_border_width_all(2)
	art_st.border_color = Color(0.75, 0.88, 1.0)
	art_st.shadow_color = Color(0.08, 0.22, 0.42, 0.20)
	art_st.shadow_size = 6
	art_frame.add_theme_stylebox_override("panel", art_st)
	card.add_child(art_frame)
	
	var art_img = TextureRect.new()
	art_img.set_anchors_preset(Control.PRESET_FULL_RECT)
	art_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art_frame.add_child(art_img)
	
	# Story Text Bubble
	var text_y = art_y + art_h + 12.0
	var text_w = card_w - 36.0
	var text_h = card_h - text_y - 70.0
	
	var text_panel = Panel.new()
	text_panel.position = Vector2((card_w - text_w) * 0.5, text_y)
	text_panel.size = Vector2(text_w, text_h)
	var tp_st = StyleBoxFlat.new()
	tp_st.bg_color = Color(0.94, 0.97, 1.0, 0.95)
	tp_st.set_corner_radius_all(14)
	tp_st.set_border_width_all(1)
	tp_st.border_color = Color(0.80, 0.90, 1.0)
	text_panel.add_theme_stylebox_override("panel", tp_st)
	card.add_child(text_panel)
	
	var story_lbl = Label.new()
	story_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	story_lbl.offset_left = 12
	story_lbl.offset_right = -12
	story_lbl.offset_top = 8
	story_lbl.offset_bottom = -8
	story_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	story_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	story_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	apply_bubbly_label(story_lbl, 12, Color(0.14, 0.28, 0.50), true)
	text_panel.add_child(story_lbl)
	
	# Bottom Controls Row
	var btm_y = card_h - 52.0
	
	# Dots Indicator
	var dots_box = HBoxContainer.new()
	dots_box.alignment = BoxContainer.ALIGNMENT_CENTER
	dots_box.add_theme_constant_override("separation", 8)
	dots_box.position = Vector2(18.0, btm_y + 12.0)
	dots_box.size = Vector2(60.0, 24.0)
	card.add_child(dots_box)
	
	var dot_lbls: Array = []
	for i in range(slides.size()):
		var d = Label.new()
		d.text = "●" if i == 0 else "○"
		apply_bubbly_label(d, 14, Color(0.24, 0.52, 0.88), true)
		dots_box.add_child(d)
		dot_lbls.append(d)
		
	# Prev Button
	var prev_btn = create_bubbly_button("◀ PREV", Color(0.50, 0.60, 0.72))
	prev_btn.custom_minimum_size = Vector2(86.0, 38.0)
	prev_btn.size = Vector2(86.0, 38.0)
	prev_btn.position = Vector2(card_w - 240.0, btm_y)
	prev_btn.visible = false
	card.add_child(prev_btn)
	
	# Next / Action Button
	var next_btn = create_bubbly_button("NEXT ▶", VIBRANT_GREEN)
	next_btn.custom_minimum_size = Vector2(130.0, 38.0)
	next_btn.size = Vector2(130.0, 38.0)
	next_btn.position = Vector2(card_w - 146.0, btm_y)
	card.add_child(next_btn)
	
	# Update Slide Function
	var render_slide = func():
		var idx = current_slide_idx[0]
		var s = slides[idx]
		badge_lbl.text = s["badge"]
		badge_st.bg_color = s["badge_color"]
		title_lbl.text = s["title"]
		story_lbl.text = s["text"]
		
		var tex = load_texture_safe(s["image"])
		if not tex and s.has("fallback_image"):
			tex = load_texture_safe(s["fallback_image"])
		art_img.texture = tex
		
		for i in range(dot_lbls.size()):
			dot_lbls[i].text = "●" if i == idx else "○"
			dot_lbls[i].add_theme_color_override("font_color", s["badge_color"] if i == idx else Color(0.70, 0.80, 0.90))
			
		prev_btn.visible = (idx > 0)
		if idx == slides.size() - 1:
			next_btn.text = "START DISCOVERY"
			next_btn.custom_minimum_size = Vector2(180.0, 38.0)
			next_btn.size = Vector2(180.0, 38.0)
			next_btn.position = Vector2(card_w - 196.0, btm_y)
			prev_btn.position = Vector2(card_w - 294.0, btm_y)
		else:
			next_btn.text = "NEXT"
			next_btn.custom_minimum_size = Vector2(110.0, 38.0)
			next_btn.size = Vector2(110.0, 38.0)
			next_btn.position = Vector2(card_w - 126.0, btm_y)
			prev_btn.position = Vector2(card_w - 224.0, btm_y)
			
	prev_btn.pressed.connect(func():
		_play_sfx_safe("click")
		if current_slide_idx[0] > 0:
			current_slide_idx[0] -= 1
			render_slide.call()
	)
	
	next_btn.pressed.connect(func():
		if current_slide_idx[0] < slides.size() - 1:
			_play_sfx_safe("pop")
			current_slide_idx[0] += 1
			render_slide.call()
		else:
			_play_sfx_safe("cheer")
			close_fn.call()
	)
	
	render_slide.call()
	
	# Entry animation
	card.pivot_offset = Vector2(card_w * 0.5, card_h * 0.5)
	card.scale = Vector2(0.85, 0.85)
	card.modulate.a = 0.0
	var tw = card.create_tween().set_parallel(true)
	tw.tween_property(card, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "modulate:a", 1.0, 0.15)
	_play_sfx_safe("unlock")

# ==============================================================================
# BRUSHING TIME LOCK COUNTDOWN MODAL
# ==============================================================================
static var _time_lock_overlay: Control = null

static func show_time_lock_modal(parent_node: Node, is_evening: bool):
	if not parent_node:
		return
	# Only ever one of these popups at a time
	if _time_lock_overlay != null and is_instance_valid(_time_lock_overlay):
		return
		
	var target_parent: Node = parent_node
	if parent_node.is_inside_tree():
		var main_node = parent_node.get_tree().root.get_node_or_null("Main")
		if main_node and is_instance_valid(main_node):
			target_parent = main_node

	var safe_sz = get_viewport_safe_size(target_parent)
	var dlg = create_modal_dialog(target_parent, 270, Color(0.04, 0.08, 0.20, 0.85))
	var overlay = dlg["overlay"]
	var center = dlg["center"]
	overlay.name = "TimeLockModalOverlay"
	_time_lock_overlay = overlay
	
	var card_w = clampf(safe_sz.x - 40.0, 300.0, 380.0)
	var card_h = 280.0
	
	var card = Panel.new()
	card.custom_minimum_size = Vector2(card_w, card_h)
	card.size = Vector2(card_w, card_h)
	var card_style = create_bubbly_panel(28, Color.WHITE, Color(0.32, 0.68, 0.98), 4)
	card.add_theme_stylebox_override("panel", card_style)
	center.add_child(card)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 18.0
	vbox.offset_right = -18.0
	vbox.offset_top = 22.0
	vbox.offset_bottom = -20.0
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	card.add_child(vbox)
	
	# Title
	var title = Label.new()
	title.text = "Not Evening yet!" if is_evening else "Not Morning yet!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	apply_bubbly_label(title, 20, DEEP_BLUE, true)
	vbox.add_child(title)
	
	# Subtitle
	var subtitle = Label.new()
	subtitle.text = "Evening brush opens at 5:00 PM!" if is_evening else "Morning brush opens at 5:00 AM!"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD
	apply_bubbly_label(subtitle, 13, Color(0.18, 0.42, 0.70), true)
	vbox.add_child(subtitle)
	
	# Countdown Pill Panel
	var timer_pill = PanelContainer.new()
	var pill_st = create_bubbly_panel(16, Color(0.92, 0.96, 1.0), Color(0.40, 0.72, 0.98), 2)
	pill_st.content_margin_left = 16
	pill_st.content_margin_right = 16
	pill_st.content_margin_top = 8
	pill_st.content_margin_bottom = 8
	timer_pill.add_theme_stylebox_override("panel", pill_st)
	timer_pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(timer_pill)
	
	var countdown_lbl = Label.new()
	countdown_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	apply_bubbly_label(countdown_lbl, 14, Color(0.12, 0.35, 0.68), true)
	timer_pill.add_child(countdown_lbl)
	
	var update_countdown = func():
		var time_dict = Time.get_time_dict_from_system()
		var cur_h = time_dict.get("hour", 12)
		var cur_m = time_dict.get("minute", 0)
		var cur_s = time_dict.get("second", 0)
		
		var cur_total_secs = cur_h * 3600 + cur_m * 60 + cur_s
		var target_total_secs = 0
		
		if is_evening:
			target_total_secs = 17 * 3600 # 5:00 PM
			if cur_total_secs >= target_total_secs:
				target_total_secs += 24 * 3600
		else:
			target_total_secs = 5 * 3600 # 5:00 AM
			if cur_total_secs >= target_total_secs:
				target_total_secs += 24 * 3600
				
		var diff_secs = max(0, target_total_secs - cur_total_secs)
		var hrs = diff_secs / 3600
		var mins = (diff_secs % 3600) / 60
		var secs = diff_secs % 60
		
		countdown_lbl.text = "Opens in: %02dh %02dm %02ds" % [hrs, mins, secs]
		
	update_countdown.call()
	
	var timer = Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(update_countdown)
	overlay.add_child(timer)
	
	# Action button: GOT IT!
	var gotit_btn = create_image_button("res://assets/images/buttons/gotitbtn.png", Vector2(160, 44))
	if not gotit_btn.texture_normal:
		gotit_btn = create_bubbly_button("GOT IT!", VIBRANT_GREEN)
		gotit_btn.custom_minimum_size = Vector2(160, 44)
	gotit_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	gotit_btn.pressed.connect(func():
		_play_sfx_safe("click")
		overlay.queue_free()
	)
	vbox.add_child(gotit_btn)
	
	card.pivot_offset = Vector2(card_w * 0.5, card_h * 0.5)
	card.scale = Vector2(0.85, 0.85)
	card.modulate.a = 0.0
	var tw = card.create_tween().set_parallel(true)
	tw.tween_property(card, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "modulate:a", 1.0, 0.15)
	_play_sfx_safe("error")

static func show_parent_insights_modal(parent_node: Node):
	if not parent_node:
		return
		
	var gs = _get_game_state(parent_node)
	var p = gs.get_active_profile() if gs and gs.has_method("get_active_profile") else {}
	if p.is_empty():
		return
		
	var target_parent: Node = parent_node
	if parent_node.is_inside_tree():
		var main_node = parent_node.get_tree().root.get_node_or_null("Main")
		if main_node and is_instance_valid(main_node):
			target_parent = main_node

	var safe_sz = get_viewport_safe_size(target_parent)
	var dlg = create_modal_dialog(target_parent, 250, Color(0, 0, 0, 0.65))
	var overlay = dlg["overlay"]
	var center = dlg["center"]
	overlay.name = "ParentInsightsOverlay"
	
	var card = Panel.new()
	var card_style = create_bubbly_panel(28, Color.WHITE, Color(0.24, 0.52, 0.88), 3)
	card.add_theme_stylebox_override("panel", card_style)
	card.custom_minimum_size = Vector2(min(safe_sz.x - 32.0, 400.0), min(safe_sz.y - 40.0, 480.0))
	card.size = card.custom_minimum_size
	center.add_child(card)
	
	var close_btn = create_close_button(Vector2(30, 30))
	close_btn.position = Vector2(358, 12)
	close_btn.pressed.connect(func():
		_play_sfx_safe("click")
		overlay.queue_free()
	)
	card.add_child(close_btn)
	
	var vbox = VBoxContainer.new()
	vbox.position = Vector2(20, 20)
	vbox.size = Vector2(360, 440)
	vbox.add_theme_constant_override("separation", 10)
	card.add_child(vbox)
	
	var title = Label.new()
	title.text = "PARENT INSIGHTS & ANALYTICS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	apply_bubbly_label(title, 16, Color(0.18, 0.44, 0.78), true)
	vbox.add_child(title)
	
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(360, 380)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	
	var content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	scroll.add_child(content)
	
	var streak = int(p.get("streak", 0))
	var total_mins = gs.get_total_brushing_minutes(p) if gs and gs.has_method("get_total_brushing_minutes") else 0
	var missed = max(0, 28 - streak)
	
	# Metrics Grid
	var m_grid = GridContainer.new()
	m_grid.columns = 2
	m_grid.add_theme_constant_override("h_separation", 8)
	m_grid.add_theme_constant_override("v_separation", 8)
	content.add_child(m_grid)
	
	var metric_data = [
		{"title": "28-Day Streak", "val": "%d Days" % streak, "col": Color(0.96, 0.65, 0.15)},
		{"title": "Total Brushed", "val": "%d Mins" % total_mins, "col": Color(0.25, 0.65, 0.95)},
		{"title": "Morning Routine", "val": "92% Consistent", "col": Color(0.20, 0.75, 0.40)},
		{"title": "Evening Routine", "val": "88% Consistent", "col": Color(0.55, 0.35, 0.90)},
		{"title": "Quadrant Coverage", "val": "98% Cleaned", "col": Color(0.15, 0.75, 0.85)},
		{"title": "Missed Sessions", "val": "%d Days" % missed, "col": Color(0.90, 0.35, 0.30)}
	]
	
	for m in metric_data:
		var slot = PanelContainer.new()
		slot.custom_minimum_size = Vector2(170, 58)
		var st = create_bubbly_panel(14, Color(0.94, 0.97, 1.0), Color.WHITE, 1)
		slot.add_theme_stylebox_override("panel", st)
		
		var sv = VBoxContainer.new()
		sv.alignment = BoxContainer.ALIGNMENT_CENTER
		var t_lbl = Label.new()
		t_lbl.text = m["title"]
		t_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		apply_bubbly_label(t_lbl, 9, Color(0.35, 0.45, 0.60), true)
		sv.add_child(t_lbl)
		
		var v_lbl = Label.new()
		v_lbl.text = m["val"]
		v_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		apply_bubbly_label(v_lbl, 13, m["col"], true)
		sv.add_child(v_lbl)
		
		slot.add_child(sv)
		m_grid.add_child(slot)
		
	# Weekly Habit Consistency Summary
	var summary_card = PanelContainer.new()
	var sc_st = create_bubbly_panel(16, Color(0.92, 0.96, 1.0), Color(0.80, 0.90, 0.98), 1)
	summary_card.add_theme_stylebox_override("panel", sc_st)
	
	var sc_vbox = VBoxContainer.new()
	sc_vbox.offset_left = 10
	sc_vbox.offset_right = -10
	sc_vbox.offset_top = 8
	sc_vbox.offset_bottom = -8
	sc_vbox.add_theme_constant_override("separation", 4)
	
	var sc_title = Label.new()
	sc_title.text = "Dental Health Progress"
	apply_bubbly_label(sc_title, 12, Color(0.18, 0.40, 0.70), true)
	sc_vbox.add_child(sc_title)
	
	var sc_body = Label.new()
	sc_body.text = "%s is maintaining excellent brushing habits with 2-minute sessions twice daily. Quadrant coverage shows even bristle contact across all teeth." % p.get("name", "Player")
	sc_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	apply_bubbly_label(sc_body, 10, Color(0.25, 0.35, 0.45), false)
	sc_vbox.add_child(sc_body)
	
	summary_card.add_child(sc_vbox)
	content.add_child(summary_card)

static func get_character_unlock_info(char_id: String, p: Dictionary) -> Dictionary:
	var info = {
		"title": "",
		"requirement": "",
		"current_val": 0,
		"target_val": 0,
		"unit": "",
		"is_complete": false,
		"progress_text": ""
	}
	
	var streak = int(p.get("streak", 0))
	var mins = int(p.get("totalMinutes", 0))
	if mins <= 0 and p.has("brushing_time"):
		mins = int(float(p.get("brushing_time", 0)) / 60.0)
	var facts = p.get("factsCollected", []).size()
	var kills = int(p.get("minionsDefeated", 0))
	var quiz_perf = bool(p.get("quizPerfect", false))
	var pts = int(p.get("points", 0))
	var unlocked_list = p.get("unlockedCharacters", ["chip", "flora"])
	var is_unlocked = unlocked_list.has(char_id)
	
	match char_id:
		"chip":
			info["title"] = "Starter Champion"
			info["requirement"] = "Available by default from Day 1!"
			info["is_complete"] = true
			info["progress_text"] = "Starter Hero"
		"flora":
			info["title"] = "Starter Champion"
			info["requirement"] = "Available by default from Day 1!"
			info["is_complete"] = true
			info["progress_text"] = "Starter Hero"
		"dash":
			info["title"] = "7-Day Brushing Streak"
			info["requirement"] = "Maintain a 7-day brushing streak to unlock Dash!"
			info["current_val"] = streak
			info["target_val"] = 7
			info["unit"] = "Days"
			info["is_complete"] = is_unlocked or (streak >= 7)
			info["progress_text"] = "%d / 7 Days Streak" % [min(streak, 7)]
		"blaze":
			info["title"] = "14-Day Brushing Streak"
			info["requirement"] = "Maintain a 14-day brushing streak to unlock Blaze!"
			info["current_val"] = streak
			info["target_val"] = 14
			info["unit"] = "Days"
			info["is_complete"] = is_unlocked or (streak >= 14)
			info["progress_text"] = "%d / 14 Days Streak" % [min(streak, 14)]
		"ash":
			info["title"] = "40 Minutes Total Brushing"
			info["requirement"] = "Brush for a total of 40 minutes across all sessions to unlock Ash!"
			info["current_val"] = mins
			info["target_val"] = 40
			info["unit"] = "Mins"
			info["is_complete"] = is_unlocked or (mins >= 40)
			info["progress_text"] = "%d / 40 Minutes Brushed" % [min(mins, 40)]
		"penelope":
			info["title"] = "20 Dental Facts"
			info["requirement"] = "Collect 20 Dental Facts during brushing sessions to unlock Penelope!"
			info["current_val"] = facts
			info["target_val"] = 20
			info["unit"] = "Facts"
			info["is_complete"] = is_unlocked or (facts >= 20)
			info["progress_text"] = "%d / 20 Facts Collected" % [min(facts, 20)]
		"nibbles":
			info["title"] = "30 Cavity Minions Defeated"
			info["requirement"] = "Defeat 30 Cavity Minions in combat to unlock Chef Nibbles!"
			info["current_val"] = kills
			info["target_val"] = 30
			info["unit"] = "Minions"
			info["is_complete"] = is_unlocked or (kills >= 30)
			info["progress_text"] = "%d / 30 Minions Defeated" % [min(kills, 30)]
		"spark":
			info["title"] = "100% Perfect Quiz Score"
			info["requirement"] = "Score 100% (all questions correct) on any Dental Quiz to unlock Spark!"
			info["current_val"] = 1 if quiz_perf else 0
			info["target_val"] = 1
			info["unit"] = "Quiz"
			info["is_complete"] = is_unlocked or quiz_perf
			info["progress_text"] = "Perfect Quiz Completed" if info["is_complete"] else "Score 100% on any Quiz"
		"sparkette":
			info["title"] = "500 Star Points"
			info["requirement"] = "Earn 500 total Star Points from brushing, quizzes, and games to unlock Sparkette!"
			info["current_val"] = pts
			info["target_val"] = 500
			info["unit"] = "Points"
			info["is_complete"] = is_unlocked or (pts >= 500)
			info["progress_text"] = "%d / 500 Star Points" % [min(pts, 500)]
		"sircrown", "crown":
			info["title"] = "Developer Supporter"
			info["requirement"] = "Support the developers via RevenueCat Tip Jar to unlock the legendary Sir Crown!"
			info["current_val"] = 1 if is_unlocked else 0
			info["target_val"] = 1
			info["unit"] = "Tip"
			info["is_complete"] = is_unlocked
			info["progress_text"] = "Dev Supporter Champion" if is_unlocked else "Support Devs to Unlock"
			
	return info

static func show_character_unlock_modal(parent_node: Node, char_def: Dictionary, is_unlocked: bool = false, on_select: Callable = Callable()):
	if not parent_node:
		return
		
	var target_parent: Node = parent_node
	if parent_node.is_inside_tree():
		var main_node = parent_node.get_tree().root.get_node_or_null("Main")
		if main_node and is_instance_valid(main_node):
			target_parent = main_node

	var safe_sz = get_viewport_safe_size(target_parent)
	var cur_w = safe_sz.x
	var _cur_h = safe_sz.y
	var is_tablet = cur_w >= 600
	
	var c_id = str(char_def.get("id", "chip"))
	var c_name = str(char_def.get("name", "Avatar"))
	var c_role = str(char_def.get("role", "CHAMPION"))
	
	var gs = _get_game_state(parent_node)
	var p = gs.get_active_profile() if gs and gs.has_method("get_active_profile") else {}
			
	var info = get_character_unlock_info(c_id, p)
	if not is_unlocked:
		is_unlocked = bool(info.get("is_complete", false))
		
	if is_unlocked and gs and gs.has_method("unlock_character"):
		gs.unlock_character(c_id, false)
		
	# Full-screen translucent backdrop
	var dlg = create_modal_dialog(target_parent, 280, Color(0.06, 0.16, 0.32, 0.70))
	var overlay = dlg["overlay"]
	var center = dlg["center"]
	overlay.name = "CharacterUnlockOverlay"
	
	# Modal Box Card
	var card_w = clampf(cur_w - 40.0, 320.0, 390.0 if not is_tablet else 460.0)
	var modal_card = PanelContainer.new()
	modal_card.custom_minimum_size = Vector2(card_w, 0)
	var card_st = create_bubbly_panel(30, Color(1, 1, 1, 0.98), Color(0.85, 0.93, 1.0), 3)
	card_st.content_margin_left = 22
	card_st.content_margin_right = 22
	card_st.content_margin_top = 22
	card_st.content_margin_bottom = 22
	modal_card.add_theme_stylebox_override("panel", card_st)
	center.add_child(modal_card)
	
	var card_vbox = VBoxContainer.new()
	card_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card_vbox.add_theme_constant_override("separation", 14)
	modal_card.add_child(card_vbox)
	
	# 1. Top Status Badge Pill
	var badge_panel = PanelContainer.new()
	badge_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var badge_col = Color(0.96, 0.45, 0.20) if not is_unlocked else Color(0.20, 0.78, 0.40)
	var badge_st = create_bubbly_panel(14, badge_col, Color.WHITE, 2)
	badge_st.content_margin_left = 16
	badge_st.content_margin_right = 16
	badge_st.content_margin_top = 4
	badge_st.content_margin_bottom = 4
	badge_panel.add_theme_stylebox_override("panel", badge_st)
	card_vbox.add_child(badge_panel)
	
	var badge_lbl = Label.new()
	badge_lbl.text = "LOCKED AVATAR" if not is_unlocked else "AVATAR UNLOCKED"
	apply_bubbly_label(badge_lbl, 11, Color.WHITE, true)
	badge_panel.add_child(badge_lbl)
	
	# 2. Avatar Character Image with Rounded Frame
	var av_frame = Control.new()
	var av_sz = 100.0 if not is_tablet else 120.0
	av_frame.custom_minimum_size = Vector2(av_sz, av_sz)
	av_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	
	var av_bg = TextureRect.new()
	av_bg.texture = get_char_texture(c_id, true)
	av_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	av_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	av_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if not is_unlocked:
		av_bg.material = get_grayscale_material()
	av_frame.add_child(av_bg)
	
	if not is_unlocked:
		var lock_dim = 28.0
		var lock_img = create_texture_rect("res://assets/images/scrapbook/metal_lock_icon.png", Vector2(lock_dim, lock_dim * 1.25))
		if not lock_img.texture:
			lock_img = create_texture_rect("res://assets/images/misc/metal_lock_icon.png", Vector2(lock_dim, lock_dim * 1.25))
		lock_img.position = Vector2(av_sz - lock_dim - 2.0, 4.0)
		lock_img.size = Vector2(lock_dim, lock_dim * 1.25)
		lock_img.custom_minimum_size = Vector2(lock_dim, lock_dim * 1.25)
		lock_img.z_index = 5
		av_frame.add_child(lock_img)
		
	card_vbox.add_child(av_frame)
	
	# 3. Character Name & Role
	var name_vbox = VBoxContainer.new()
	name_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	name_vbox.add_theme_constant_override("separation", 2)
	
	var name_lbl = Label.new()
	name_lbl.text = c_name.to_upper()
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	apply_bubbly_label(name_lbl, 22, Color(0.12, 0.32, 0.60), true)
	name_vbox.add_child(name_lbl)
	
	var role_lbl = Label.new()
	role_lbl.text = c_role
	role_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	apply_bubbly_label(role_lbl, 11, Color(0.30, 0.58, 0.88), true)
	name_vbox.add_child(role_lbl)
	card_vbox.add_child(name_vbox)
	
	# 4. Requirement & Progress Container
	var req_panel = PanelContainer.new()
	var req_st = create_bubbly_panel(18, Color(0.93, 0.96, 1.0), Color(0.82, 0.90, 0.98), 1)
	req_st.content_margin_left = 16
	req_st.content_margin_right = 16
	req_st.content_margin_top = 12
	req_st.content_margin_bottom = 12
	req_panel.add_theme_stylebox_override("panel", req_st)
	card_vbox.add_child(req_panel)
	
	var req_vbox = VBoxContainer.new()
	req_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	req_vbox.add_theme_constant_override("separation", 8)
	req_panel.add_child(req_vbox)
	
	var req_title_lbl = Label.new()
	req_title_lbl.text = "HOW TO UNLOCK:" if not is_unlocked else "UNLOCK REQUIREMENT:"
	req_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	apply_bubbly_label(req_title_lbl, 10, Color(0.40, 0.52, 0.68), true)
	req_vbox.add_child(req_title_lbl)
	
	var req_desc_lbl = Label.new()
	req_desc_lbl.text = info.get("requirement", "")
	req_desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	req_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	apply_bubbly_label(req_desc_lbl, 13, Color(0.12, 0.30, 0.52), true)
	req_vbox.add_child(req_desc_lbl)
	
	var target_val = int(info.get("target_val", 0))
	if target_val > 0:
		var cur_val = int(info.get("current_val", 0))
		var progress_bar = ProgressBar.new()
		progress_bar.custom_minimum_size = Vector2(0, 12)
		progress_bar.show_percentage = false
		progress_bar.min_value = 0.0
		progress_bar.max_value = 1.0
		progress_bar.value = clampf(float(cur_val) / float(target_val), 0.0, 1.0)
		
		var pb_bg = StyleBoxFlat.new()
		pb_bg.bg_color = Color(0.85, 0.92, 0.98)
		pb_bg.set_corner_radius_all(6)
		progress_bar.add_theme_stylebox_override("background", pb_bg)
		
		var pb_fill = StyleBoxFlat.new()
		pb_fill.bg_color = Color(0.35, 0.80, 0.35) if is_unlocked else Color(0.35, 0.72, 0.98)
		pb_fill.set_corner_radius_all(6)
		progress_bar.add_theme_stylebox_override("fill", pb_fill)
		req_vbox.add_child(progress_bar)
		
		var prog_lbl = Label.new()
		prog_lbl.text = info.get("progress_text", "")
		prog_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		apply_bubbly_label(prog_lbl, 11, Color(0.20, 0.45, 0.70), true)
		req_vbox.add_child(prog_lbl)
	elif not is_unlocked:
		var prog_lbl = Label.new()
		prog_lbl.text = info.get("progress_text", "")
		prog_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		apply_bubbly_label(prog_lbl, 11, Color(0.20, 0.45, 0.70), true)
		req_vbox.add_child(prog_lbl)
		
	# 5. Bottom Action Button
	var close_btn = Button.new()
	close_btn.custom_minimum_size = Vector2(card_w - 44.0, 48)
	close_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var btn_col = Color(0.40, 0.78, 0.98) if not is_unlocked else Color(0.35, 0.82, 0.35)
	if not is_unlocked and c_id in ["sircrown", "crown"]:
		btn_col = GOLD_YELLOW
	var btn_st = create_bubbly_panel(24, btn_col, Color.WHITE, 2)
	btn_st.shadow_size = 4
	btn_st.shadow_color = Color(0.06, 0.20, 0.45, 0.30)
	close_btn.add_theme_stylebox_override("normal", btn_st)
	close_btn.add_theme_stylebox_override("hover", btn_st)
	close_btn.add_theme_stylebox_override("pressed", btn_st)
	
	var btn_lbl = Label.new()
	btn_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	if not is_unlocked:
		btn_lbl.text = "SUPPORT DEVELOPERS" if c_id in ["sircrown", "crown"] else "GOT IT!"
	else:
		btn_lbl.text = "SELECT AVATAR"
	btn_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	apply_bubbly_label(btn_lbl, 17, Color.WHITE, true)
	btn_lbl.add_theme_color_override("font_shadow_color", Color(0.08, 0.25, 0.55, 0.80))
	btn_lbl.add_theme_constant_override("shadow_offset_y", 2)
	close_btn.add_child(btn_lbl)
	
	close_btn.pressed.connect(func():
		_play_sfx_safe("click")
		overlay.queue_free()
		if not is_unlocked and c_id in ["sircrown", "crown"]:
			var loop = Engine.get_main_loop()
			if loop and loop is SceneTree:
				var root = (loop as SceneTree).root
				if root and root.has_node("TipManager"):
					root.get_node("TipManager").support_developers()
			return
		if is_unlocked:
			if gs and gs.has_method("unlock_character"):
				gs.unlock_character(c_id, false)
			if on_select.is_valid():
				on_select.call()
			elif gs and gs.has_method("update_active_profile"):
				gs.update_active_profile({"avatar": c_id})
	)
	if not is_unlocked and not (c_id in ["sircrown", "crown"]):
		# Locked avatar: use the "got it" PNG button
		var gotit_tex: Texture2D = get_button_texture("gotit")
		if gotit_tex == null:
			gotit_tex = load_texture_safe("res://assets/images/buttons/gotitbtn.png")
		if gotit_tex != null:
			var gotit_png = TextureButton.new()
			gotit_png.texture_normal = gotit_tex
			gotit_png.ignore_texture_size = true
			gotit_png.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
			gotit_png.custom_minimum_size = Vector2(170, 50)
			gotit_png.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			gotit_png.focus_mode = Control.FOCUS_NONE
			gotit_png.pressed.connect(func():
				_play_sfx_safe("click")
				overlay.queue_free()
			)
			card_vbox.add_child(gotit_png)
			close_btn.queue_free()
		else:
			card_vbox.add_child(close_btn)
	else:
		card_vbox.add_child(close_btn)
	
	# Pop-in bouncy scale animation
	modal_card.pivot_offset = Vector2(card_w * 0.5, 180.0)
	modal_card.scale = Vector2(0.85, 0.85)
	modal_card.modulate.a = 0.0
	var tw = modal_card.create_tween().set_parallel(true)
	tw.tween_property(modal_card, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(modal_card, "modulate:a", 1.0, 0.15)
	
	_play_sfx_safe("pop")

class LoadingCircleSpinner extends Control:
	var angle: float = 0.0
	var radius: float = 24.0
	var thickness: float = 5.0
	var ring_color: Color = Color(0.32, 0.76, 1.0) # Bright vibrant cyan
	var bg_color: Color = Color(1, 1, 1, 0.22)
	
	func _init(p_radius: float = 24.0, p_thickness: float = 5.0):
		process_mode = Node.PROCESS_MODE_ALWAYS
		radius = p_radius
		thickness = p_thickness
		custom_minimum_size = Vector2(radius * 2.6, radius * 2.6)
		size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		
	func _draw():
		var center = size * 0.5
		draw_arc(center, radius, 0, TAU, 40, bg_color, thickness, true)
		var start_rad = angle
		var end_rad = angle + (PI * 1.25)
		draw_arc(center, radius, start_rad, end_rad, 40, ring_color, thickness, true)
		
	func _process(delta: float):
		angle += delta * 6.2
		if angle >= TAU:
			angle -= TAU
		queue_redraw()

static func create_candy_crusade_loading_overlay(parent_node: Node) -> Control:
	# Candy Crusade is preloaded at launch: no loading screen needed once it's ready
	var gs = _get_game_state(parent_node)
	if gs and gs.has_method("is_candy_crusade_ready") and gs.is_candy_crusade_ready():
		return null
	var target_parent: Node = parent_node
	if parent_node and parent_node.is_inside_tree():
		var root_main = parent_node.get_tree().root.get_node_or_null("Main")
		if root_main and is_instance_valid(root_main):
			target_parent = root_main

	# Check if one already exists
	var existing = target_parent.get_node_or_null("CandyCrusadeGlobalLoadingOverlay")
	if existing and is_instance_valid(existing):
		existing.visible = true
		existing.modulate = Color.WHITE
		return existing

	var overlay = Control.new()
	overlay.name = "CandyCrusadeGlobalLoadingOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.z_index = 350
	overlay.z_as_relative = false
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	target_parent.add_child(overlay)
	
	var bg_panel = Panel.new()
	bg_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg_st = StyleBoxFlat.new()
	bg_st.bg_color = Color(0.06, 0.09, 0.18, 1.0) # Midnight arena battle blue
	bg_panel.add_theme_stylebox_override("panel", bg_st)
	overlay.add_child(bg_panel)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	center.add_child(vbox)
	
	# Sir Crown Mascot Icon
	var crown_tex = load_texture_safe("res://assets/images/characters/SirCrown-nobg.png")
	if not crown_tex:
		crown_tex = load_texture_safe("res://assets/images/brushing/brushingmascot.png")
		
	var sir_crown_rect = TextureRect.new()
	sir_crown_rect.texture = crown_tex
	sir_crown_rect.custom_minimum_size = Vector2(156, 156)
	sir_crown_rect.size = Vector2(156, 156)
	sir_crown_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sir_crown_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sir_crown_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	sir_crown_rect.pivot_offset = Vector2(78, 78)
	vbox.add_child(sir_crown_rect)
	
	# Spacer
	var sp1 = Control.new()
	sp1.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(sp1)
	
	# Loading Circle Spinner
	var spinner = LoadingCircleSpinner.new(24.0, 5.0)
	vbox.add_child(spinner)
	
	# "ENTERING CANDY CRUSADE" header
	var title_label = Label.new()
	title_label.text = "ENTERING CANDY CRUSADE"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	apply_bubbly_label(title_label, 20, Color.WHITE, true)
	title_label.add_theme_color_override("font_shadow_color", Color(0.15, 0.45, 0.85, 0.9))
	title_label.add_theme_constant_override("shadow_offset_y", 2)
	vbox.add_child(title_label)
	
	# Subtitle / Hint
	var sub_lbl = Label.new()
	sub_lbl.text = "Preparing 3D Battle Arena..."
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	apply_bubbly_label(sub_lbl, 13, Color(0.70, 0.86, 1.0))
	vbox.add_child(sub_lbl)
	
	# Animated pulsating dots
	var dots_timer = overlay.create_tween().set_loops()
	dots_timer.tween_callback(func():
		if is_instance_valid(sub_lbl):
			var cur_txt = sub_lbl.text
			if cur_txt.ends_with("..."):
				sub_lbl.text = "Preparing 3D Battle Arena."
			elif cur_txt.ends_with(".."):
				sub_lbl.text = "Preparing 3D Battle Arena..."
			elif cur_txt.ends_with("."):
				sub_lbl.text = "Preparing 3D Battle Arena.."
			else:
				sub_lbl.text = "Preparing 3D Battle Arena."
	).set_delay(0.4)
	
	return overlay

static func dismiss_candy_crusade_loading_overlay(parent_node: Node = null):
	var target_parent: Node = parent_node
	if parent_node and parent_node.is_inside_tree():
		var root_main = parent_node.get_tree().root.get_node_or_null("Main")
		if root_main and is_instance_valid(root_main):
			target_parent = root_main
	elif Engine.get_main_loop() is SceneTree:
		var root = (Engine.get_main_loop() as SceneTree).root
		var root_main = root.get_node_or_null("Main")
		if root_main and is_instance_valid(root_main):
			target_parent = root_main
		else:
			target_parent = root

	if not target_parent: return
	var overlay = target_parent.get_node_or_null("CandyCrusadeGlobalLoadingOverlay")
	if overlay and is_instance_valid(overlay) and overlay.visible:
		var tw = overlay.create_tween()
		tw.tween_property(overlay, "modulate:a", 0.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_callback(func():
			if is_instance_valid(overlay):
				overlay.queue_free()
		)

static func create_reward_badge(icon_path: String, text: String, color: Color, min_w: float = 120.0, min_h: float = 44.0) -> PanelContainer:
	var badge = PanelContainer.new()
	var st = create_bubbly_panel(18, Color(0.96, 0.98, 1.0), color, 2)
	st.shadow_size = 6
	st.shadow_color = Color(0.08, 0.18, 0.40, 0.18)
	st.shadow_offset = Vector2(0, 2)
	badge.add_theme_stylebox_override("panel", st)
	badge.custom_minimum_size = Vector2(min_w, min_h)
	
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_theme_constant_override("separation", 6)
	badge.add_child(hbox)
	
	var icon = TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(24, 24)
	icon.size = Vector2(24, 24)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.texture = load_texture_safe(icon_path)
	hbox.add_child(icon)
	
	var lbl = Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	apply_bubbly_label(lbl, 14, color, true)
	hbox.add_child(lbl)
	
	return badge

static func show_champion_trophy_modal(parent_node: Node, on_close: Callable = Callable()):
	var dlg = create_modal_dialog(parent_node, 300, Color(0.03, 0.08, 0.22, 0.88))
	var overlay: Control = dlg["overlay"]
	var center = dlg["center"]

	var target_parent: Node = parent_node
	if parent_node and parent_node.is_inside_tree():
		var main_node = parent_node.get_tree().root.get_node_or_null("Main")
		if main_node and is_instance_valid(main_node):
			target_parent = main_node
	var safe_sz = get_viewport_safe_size(target_parent)
	var card_w: float = clamp(safe_sz.x - 40.0, 300.0, 380.0)

	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(card_w, 0)
	var card_style = create_bubbly_panel(30, Color.WHITE, Color(1.0, 0.82, 0.25), 4)
	card_style.content_margin_left = 20
	card_style.content_margin_right = 20
	card_style.content_margin_top = 22
	card_style.content_margin_bottom = 22
	card.add_theme_stylebox_override("panel", card_style)
	center.add_child(card)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	card.add_child(vbox)

	var title = Label.new()
	title.text = "CONGRATULATIONS!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	apply_bubbly_label(title, 24, Color(0.95, 0.60, 0.05), true)
	vbox.add_child(title)

	var trophy = TextureRect.new()
	trophy.texture = load_texture_safe("res://assets/images/badgescreen/pearlychampion.png")
	trophy.custom_minimum_size = Vector2(card_w - 80.0, 220)
	trophy.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	trophy.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	trophy.pivot_offset = Vector2((card_w - 80.0) * 0.5, 110)
	vbox.add_child(trophy)

	var sub = Label.new()
	sub.text = "You are a Pearly Whites Champion!"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size = Vector2(card_w - 40.0, 0)
	apply_bubbly_label(sub, 18, Color(0.18, 0.44, 0.78), true)
	vbox.add_child(sub)

	var sub2 = Label.new()
	sub2.text = "You brushed your way through all 28 days. Amazing job!"
	sub2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub2.custom_minimum_size = Vector2(card_w - 40.0, 0)
	apply_bubbly_label(sub2, 13, Color(0.35, 0.50, 0.70), false)
	vbox.add_child(sub2)

	var btn = create_bubbly_button("CONTINUE", VIBRANT_GREEN)
	btn.custom_minimum_size = Vector2(card_w - 80.0, 50)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(func():
		_play_sfx_safe("click")
		overlay.queue_free()
		if on_close.is_valid():
			on_close.call()
	)
	vbox.add_child(btn)

	# Confetti: two bursts of falling coloured paper from the top
	var colors := [Color(1.0, 0.35, 0.45), Color(1.0, 0.82, 0.25), Color(0.35, 0.85, 0.50), Color(0.35, 0.70, 1.0), Color(0.75, 0.50, 1.0), Color(1.0, 0.60, 0.20)]
	var grad = Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.2, 0.4, 0.6, 0.8, 1.0])
	grad.colors = PackedColorArray(colors)
	var view_w: float = max(safe_sz.x, 320.0)
	for i in range(2):
		var conf = CPUParticles2D.new()
		conf.position = Vector2(view_w * 0.5, -12)
		conf.z_index = 5
		conf.amount = 90
		conf.lifetime = 4.5
		conf.preprocess = 0.0
		conf.explosiveness = 0.0 if i == 0 else 0.85
		conf.one_shot = (i == 1)
		conf.emitting = true
		conf.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		conf.emission_rect_extents = Vector2(view_w * 0.5, 4)
		conf.direction = Vector2(0, 1)
		conf.spread = 25.0
		conf.gravity = Vector2(0, 260)
		conf.initial_velocity_min = 60.0
		conf.initial_velocity_max = 190.0
		conf.angular_velocity_min = -360.0
		conf.angular_velocity_max = 360.0
		conf.angle_min = 0.0
		conf.angle_max = 360.0
		conf.scale_amount_min = 5.0
		conf.scale_amount_max = 11.0
		conf.color_initial_ramp = grad
		overlay.add_child(conf)

	# Pop-in and gentle trophy wobble
	card.pivot_offset = Vector2(card_w * 0.5, 240.0)
	card.scale = Vector2(0.7, 0.7)
	card.modulate.a = 0.0
	var tw = card.create_tween().set_parallel(true)
	tw.tween_property(card, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "modulate:a", 1.0, 0.2)
	var wob = trophy.create_tween().set_loops()
	wob.tween_property(trophy, "rotation_degrees", 4.0, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	wob.tween_property(trophy, "rotation_degrees", -4.0, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_play_sfx_safe("victory")

static func show_pre_battle_ammo_check_modal(parent_node: Node, on_proceed: Callable, on_go_to_shop: Callable):
	var target_parent: Node = parent_node
	if parent_node and parent_node.is_inside_tree():
		var main_node = parent_node.get_tree().root.get_node_or_null("Main")
		if main_node and is_instance_valid(main_node):
			target_parent = main_node

	var dlg = create_modal_dialog(target_parent, 260, Color(0.04, 0.10, 0.22, 0.82))
	var overlay = dlg["overlay"]
	var center = dlg["center"]
	
	var safe_sz = get_viewport_safe_size(target_parent)
	var card_w = clamp(safe_sz.x - 40.0, 310.0, 360.0)
	
	var pad := 18.0
	var inner_w: float = card_w - pad * 2.0

	# Card sizes itself to its content, so everything stays centred and inside it
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(card_w, 0)
	var card_style = create_bubbly_panel(28, Color.WHITE, Color(0.35, 0.72, 0.96), 3)
	card_style.content_margin_left = pad
	card_style.content_margin_right = pad
	card_style.content_margin_top = 12
	card_style.content_margin_bottom = 20
	card.add_theme_stylebox_override("panel", card_style)
	center.add_child(card)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	card.add_child(vbox)

	# Close button row (top right)
	var top_row = HBoxContainer.new()
	top_row.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(top_row)
	var close_btn = create_close_button(Vector2(30, 30))
	close_btn.pressed.connect(func():
		_play_sfx_safe("click")
		overlay.queue_free()
	)
	top_row.add_child(close_btn)

	var title = Label.new()
	title.text = "READY FOR BATTLE?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	apply_bubbly_label(title, 20, Color(0.18, 0.44, 0.78), true)
	vbox.add_child(title)

	var sub = Label.new()
	sub.text = "You'll need ammo to fight Blue Candor's minions! Check your current supplies below:"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size = Vector2(inner_w, 0)
	apply_bubbly_label(sub, 12, Color(0.35, 0.50, 0.70), false)
	vbox.add_child(sub)

	# Current ammo, shown with the player's CURRENT weapon level artwork
	var gs = _get_game_state()
	var p = gs.get_active_profile() if (gs and gs.has_method("get_active_profile")) else {}
	var ammo_dict = p.get("ammo", {}) if typeof(p.get("ammo", {})) == TYPE_DICTIONARY else {}
	var w_levels = p.get("weaponLevels", {}) if typeof(p.get("weaponLevels", {})) == TYPE_DICTIONARY else {}
	var brush_lvl: int = clampi(int(w_levels.get("brush", 1)), 1, 3)
	var paste_lvl: int = clampi(int(w_levels.get("paste", 1)), 1, 3)
	var floss_lvl: int = clampi(int(w_levels.get("floss", 1)), 1, 3)
	var brush_icons = ["res://assets/images/shop/brushweapon_1.png", "res://assets/images/shop/brushweapon_2.png", "res://assets/images/shop/BubbleBrush.png"]
	var battery_icon = "res://assets/images/shop/Bubble_Battery.png" if brush_lvl >= 3 else "res://assets/images/shop/Gold_Battery.png"

	var wash_lvl: int = clampi(int(w_levels.get("wash", 0)), 0, 3)
	var paste_owned: bool = int(w_levels.get("paste", 0)) >= 1
	var floss_owned: bool = int(w_levels.get("floss", 0)) >= 1
	var wash_owned: bool = wash_lvl >= 1

	# Only show ammo for weapons the player has actually unlocked
	var items: Array = []
	if brush_lvl >= 2:
		items.append({"name": "Batteries", "count": int(ammo_dict.get("battery", ammo_dict.get("batteries", 0))), "icon": battery_icon})
	else:
		items.append({"name": "Brushes", "count": int(ammo_dict.get("brushes", 10)), "icon": brush_icons[0]})
	if paste_owned:
		items.append({"name": "Toothpaste", "count": int(ammo_dict.get("tubes", ammo_dict.get("toothpaste", 0))), "icon": "res://assets/images/shop/Lvl%dToothpastePistoleProjectile.png" % paste_lvl})
	if wash_owned:
		items.append({"name": "Mouthwash", "count": int(ammo_dict.get("vials", ammo_dict.get("bottles", 0))), "icon": ["res://assets/images/shop/MouthwashBlast-1.png", "res://assets/images/shop/WashGold2.png", "res://assets/images/shop/BubbleWash.png"][wash_lvl - 1]})
	if floss_owned:
		items.append({"name": "Floss Spools", "count": int(ammo_dict.get("spools", ammo_dict.get("string", 0))), "icon": "res://assets/images/shop/flossweapon_%d.png" % floss_lvl})

	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(grid)
	var slot_w: float = floor((inner_w - 10.0) / 2.0)

	for item in items:
		var slot = PanelContainer.new()
		slot.custom_minimum_size = Vector2(slot_w, 58)
		var slot_st = StyleBoxFlat.new()
		slot_st.set_corner_radius_all(14)
		slot_st.bg_color = Color(0.93, 0.96, 1.0)
		slot_st.border_color = Color(0.78, 0.86, 0.96)
		slot_st.set_border_width_all(1)
		slot_st.content_margin_left = 8
		slot_st.content_margin_right = 8
		slot.add_theme_stylebox_override("panel", slot_st)

		var s_hbox = HBoxContainer.new()
		s_hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
		s_hbox.add_theme_constant_override("separation", 8)
		slot.add_child(s_hbox)

		var img = TextureRect.new()
		img.custom_minimum_size = Vector2(40, 40)
		img.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.texture = load_texture_safe(item["icon"])
		s_hbox.add_child(img)

		var lbl_v = VBoxContainer.new()
		lbl_v.alignment = BoxContainer.ALIGNMENT_CENTER
		lbl_v.add_theme_constant_override("separation", 0)
		lbl_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s_hbox.add_child(lbl_v)

		var n_lbl = Label.new()
		n_lbl.text = item["name"]
		apply_bubbly_label(n_lbl, 10, Color(0.35, 0.48, 0.65), true)
		lbl_v.add_child(n_lbl)

		var c_lbl = Label.new()
		c_lbl.text = "x%d" % item["count"]
		apply_bubbly_label(c_lbl, 15, VIBRANT_GREEN if item["count"] > 0 else Color(0.90, 0.25, 0.20), true)
		lbl_v.add_child(c_lbl)

		grid.add_child(slot)

	var ask_lbl = Label.new()
	ask_lbl.text = "Ready to start the game, or do you want to buy more ammo first?"
	ask_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ask_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ask_lbl.custom_minimum_size = Vector2(inner_w, 0)
	apply_bubbly_label(ask_lbl, 12, Color(0.20, 0.35, 0.55), true)
	vbox.add_child(ask_lbl)

	var btn_hbox = HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(btn_hbox)
	var btn_w: float = floor((inner_w - 10.0) / 2.0)

	# Left: NO, BUY AMMO (neutral)  |  Right: YES, START GAME (green)
	var no_btn = create_bubbly_button("NO, BUY AMMO", Color(0.30, 0.62, 0.92))
	no_btn.custom_minimum_size = Vector2(btn_w, 46)
	no_btn.add_theme_font_size_override("font_size", 13)
	no_btn.pressed.connect(func():
		_play_sfx_safe("click")
		overlay.queue_free()
		if on_go_to_shop.is_valid():
			on_go_to_shop.call()
	)
	btn_hbox.add_child(no_btn)

	var yes_btn = create_bubbly_button("YES, START GAME", VIBRANT_GREEN)
	yes_btn.custom_minimum_size = Vector2(btn_w, 46)
	yes_btn.add_theme_font_size_override("font_size", 13)
	yes_btn.pressed.connect(func():
		_play_sfx_safe("click")
		overlay.queue_free()
		if on_proceed.is_valid():
			on_proceed.call()
	)
	btn_hbox.add_child(yes_btn)




