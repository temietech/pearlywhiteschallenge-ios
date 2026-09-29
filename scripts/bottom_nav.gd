# scripts/bottom_nav.gd
extends Control

signal tab_selected(tab_name: String)

var active_tab: String = "map"
var button_nodes: Dictionary = {}

const TABS = [
	{"id": "map", "label": "Map", "src": "res://assets/images/mainmap/mapicons_map.png"},
	{"id": "story", "label": "Story", "src": "res://assets/images/mainmap/mapicons_story.png"},
	{"id": "shop", "label": "Shop", "src": "res://assets/images/mainmap/mapicons_shop.png"},
	{"id": "badges", "label": "Badges", "src": "res://assets/images/mainmap/mapicons_badges.png"},
	{"id": "facts", "label": "Diary", "src": "res://assets/images/mainmap/mapicons_diary.png"}
]

var bar_bg: TextureRect

func _ready():
	set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	anchor_top = 1.0
	anchor_bottom = 1.0
	anchor_left = 0.0
	anchor_right = 1.0
	offset_left = 0
	offset_right = 0
	offset_top = -88
	offset_bottom = 0
	custom_minimum_size = Vector2(450, 88)
	size.y = 88
	z_index = 100
	z_as_relative = false
	_build_ui()
	_relayout()

func _notification(what: int):
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_relayout()

func _relayout():
	var safe_sz = UIHelper.get_viewport_safe_size(self)
	var current_w = safe_sz.x
	size.x = current_w
	
	# Slim grounding bar plate at the bottom (reduced height from 74px down to 42px)
	var bar_h = 42.0
	if bar_bg:
		bar_bg.size = Vector2(current_w, bar_h)
		bar_bg.position = Vector2(0, size.y - bar_h)
		
	var num_tabs = TABS.size()
	var slot_width = current_w / float(num_tabs)
	# Enlarge square buttons by 30% and match image aspect ratio (340x390)
	var btn_w = clamp(slot_width * 0.96, 72.0, 82.0)
	var btn_h = round(btn_w * 1.14)
	var base_y = size.y - btn_h + 1.0
	
	for i in range(num_tabs):
		var t_id = TABS[i]["id"]
		var btn: TextureButton = button_nodes.get(t_id)
		if btn:
			btn.custom_minimum_size = Vector2(btn_w, btn_h)
			btn.size = Vector2(btn_w, btn_h)
			btn.pivot_offset = Vector2(btn_w * 0.5, btn_h * 0.5)
			var btn_y = base_y - 4.0 if t_id == active_tab else base_y
			btn.position = Vector2(i * slot_width + (slot_width - btn_w) * 0.5, btn_y)

func _build_ui():
	var safe_sz = UIHelper.get_viewport_safe_size(self)
	var current_w = safe_sz.x
	
	# Slim Persistent Bar Background Plate (reduced height, grounded at bottom)
	var bar_h = 42.0
	bar_bg = TextureRect.new()
	bar_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bar_bg.stretch_mode = TextureRect.STRETCH_SCALE
	bar_bg.position = Vector2(0, size.y - bar_h)
	bar_bg.size = Vector2(current_w, bar_h)
	bar_bg.texture = UIHelper.load_texture_safe("res://assets/images/mainmap/Persistent_bar_on_wh_item_1.png")
	add_child(bar_bg)
	
	# Tab Buttons distributed across dynamic slots (images already include label text)
	var slot_width = current_w / float(TABS.size())
	var btn_w = clamp(slot_width * 0.96, 72.0, 82.0)
	var btn_h = round(btn_w * 1.14)
	var base_y = size.y - btn_h + 1.0
	
	for i in range(TABS.size()):
		var t = TABS[i]
		var t_id = t["id"]
		var btn = TextureButton.new()
		btn.ignore_texture_size = true
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		btn.texture_normal = UIHelper.load_texture_safe(t["src"])
		btn.custom_minimum_size = Vector2(btn_w, btn_h)
		btn.size = Vector2(btn_w, btn_h)
		btn.position = Vector2(i * slot_width + (slot_width - btn_w) * 0.5, base_y)
		btn.pivot_offset = Vector2(btn_w * 0.5, btn_h * 0.5)
		
		btn.pressed.connect(func():
			AudioManager.play_sfx("click")
			set_active(t_id)
			tab_selected.emit(t_id)
		)
		
		button_nodes[t_id] = btn
		add_child(btn)
		
	set_active("map")

func set_active(tab_id: String):
	active_tab = tab_id
	var safe_sz = UIHelper.get_viewport_safe_size(self)
	var slot_w = safe_sz.x / float(TABS.size())
	var btn_w = clamp(slot_w * 0.96, 72.0, 82.0)
	var btn_h = round(btn_w * 1.14)
	var base_y = size.y - btn_h + 1.0
	
	for id in button_nodes:
		var btn: TextureButton = button_nodes[id]
		if not btn: continue
		if id == active_tab:
			var tw = btn.create_tween()
			tw.tween_property(btn, "scale", Vector2(1.10, 1.10), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(btn, "position:y", base_y - 4.0, 0.12)
			btn.modulate = Color.WHITE
		else:
			var tw = btn.create_tween()
			tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1)
			tw.parallel().tween_property(btn, "position:y", base_y, 0.1)
			btn.modulate = Color(0.92, 0.92, 0.92, 0.88)

