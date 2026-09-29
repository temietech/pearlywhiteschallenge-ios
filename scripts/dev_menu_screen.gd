# scripts/dev_menu_screen.gd
extends Control

signal navigate_requested(screen_name: String)
signal back_pressed

var title_lbl: Label
var card_panel: Panel
var card_vbox: VBoxContainer

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
	UIHelper.setup_fullscreen_bg(bg)
	bg.texture = UIHelper.create_sky_gradient_texture()
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(bg)
	
	# Title: "DEV MENU"
	title_lbl = Label.new()
	title_lbl.name = "TitleLabel"
	title_lbl.text = "DEV MENU"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(title_lbl, 28, Color(0.20, 0.45, 0.75), true)
	title_lbl.add_theme_color_override("font_shadow_color", Color(0.12, 0.35, 0.60, 0.6))
	title_lbl.add_theme_constant_override("shadow_offset_x", 0)
	title_lbl.add_theme_constant_override("shadow_offset_y", 2)
	add_child(title_lbl)
	
	# Card Panel
	card_panel = Panel.new()
	card_panel.name = "CardPanel"
	var c_style = StyleBoxFlat.new()
	c_style.bg_color = Color(1, 1, 1, 0.72)
	c_style.set_corner_radius_all(32)
	c_style.border_width_left = 3
	c_style.border_width_right = 3
	c_style.border_width_top = 3
	c_style.border_width_bottom = 3
	c_style.border_color = Color(1, 1, 1, 0.95)
	card_panel.add_theme_stylebox_override("panel", c_style)
	add_child(card_panel)
	
	var card_scroll = ScrollContainer.new()
	card_scroll.name = "CardScroll"
	card_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card_panel.add_child(card_scroll)
	
	card_vbox = VBoxContainer.new()
	card_vbox.name = "CardVBox"
	card_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card_vbox.add_theme_constant_override("separation", 8)
	card_scroll.add_child(card_vbox)
	
	# Green Pills: Minigames & Brushing
	_add_menu_btn(card_vbox, "DENTAL MATCH", Color(0.18, 0.78, 0.36), Color(0.10, 0.58, 0.24), func():
		navigate_requested.emit("memory")
	)
	_add_menu_btn(card_vbox, "POP THE BUBBLES", Color(0.18, 0.78, 0.36), Color(0.10, 0.58, 0.24), func():
		navigate_requested.emit("surprise")
	)
	_add_menu_btn(card_vbox, "BONBON BASH", Color(0.18, 0.78, 0.36), Color(0.10, 0.58, 0.24), func():
		navigate_requested.emit("whack")
	)
	_add_menu_btn(card_vbox, "CANDY CRUSADE", Color(0.18, 0.78, 0.36), Color(0.10, 0.58, 0.24), func():
		navigate_requested.emit("combat")
	)
	_add_menu_btn(card_vbox, "WEEKLY QUIZ", Color(0.18, 0.78, 0.36), Color(0.10, 0.58, 0.24), func():
		navigate_requested.emit("quiz")
	)
	_add_menu_btn(card_vbox, "BRUSHING PAGE", Color(0.18, 0.78, 0.36), Color(0.10, 0.58, 0.24), func():
		navigate_requested.emit("brushing")
	)
	
	_add_menu_btn(card_vbox, "CANDY TRAP", Color(0.18, 0.78, 0.36), Color(0.10, 0.58, 0.24), func():
		navigate_requested.emit("candy_trap")
	)
	_add_menu_btn(card_vbox, "UNLOCKED WEAPON PAGE", Color(0.18, 0.78, 0.36), Color(0.10, 0.58, 0.24), func():
		var p = GameState.get_active_profile()
		var cur_node = int(p.get("currentNode", 1)) if not p.is_empty() else 1
		var cur_day = GameState.get_unlocked_day(p)
		
		var weapon_defs = [
			{"id": "brush_1", "weapon_id": "brush", "name": "TOOTHBRUSH", "full_name": "Brush Boomerang", "unlock_day": 1, "tier": 1, "images": ["res://assets/images/shop/brushweapon_1.png"]},
			{"id": "paste_1", "weapon_id": "paste", "name": "TOOTHPASTE", "full_name": "Paste Pistol", "unlock_day": 2, "tier": 1, "images": ["res://assets/images/shop/Lvl1Paste.png"]},
			{"id": "brush_2", "weapon_id": "brush", "name": "TOOTHBRUSH", "full_name": "Gold Brush", "unlock_day": 3, "tier": 2, "images": ["res://assets/images/shop/brushweapon_2.png"]},
			{"id": "floss_1", "weapon_id": "floss", "name": "FLOSS", "full_name": "Floss Lasso", "unlock_day": 5, "tier": 1, "images": ["res://assets/images/shop/flossweapon_1.png"]},
			{"id": "wash_1", "weapon_id": "wash", "name": "MOUTHWASH", "full_name": "Mouthwash Blast", "unlock_day": 7, "tier": 1, "images": ["res://assets/images/shop/MouthwashBlast-1.png"]},
			{"id": "paste_2", "weapon_id": "paste", "name": "TOOTHPASTE", "full_name": "Gold Paste Pistol", "unlock_day": 9, "tier": 2, "images": ["res://assets/images/shop/PasteGold2.png"]},
			{"id": "brush_3", "weapon_id": "brush", "name": "TOOTHBRUSH", "full_name": "Bubble Brush", "unlock_day": 11, "tier": 3, "images": ["res://assets/images/shop/BubbleBrush.png"]},
			{"id": "floss_2", "weapon_id": "floss", "name": "FLOSS", "full_name": "Gold Floss Lasso", "unlock_day": 13, "tier": 2, "images": ["res://assets/images/shop/flossweapon_2.png"]},
			{"id": "paste_3", "weapon_id": "paste", "name": "TOOTHPASTE", "full_name": "Bubble Paste", "unlock_day": 15, "tier": 3, "images": ["res://assets/images/shop/BubblePaste.png"]},
			{"id": "wash_2", "weapon_id": "wash", "name": "MOUTHWASH", "full_name": "Gold Mouthwash Blast", "unlock_day": 17, "tier": 2, "images": ["res://assets/images/shop/WashGold2.png"]},
			{"id": "floss_3", "weapon_id": "floss", "name": "FLOSS", "full_name": "Bubble Floss", "unlock_day": 19, "tier": 3, "images": ["res://assets/images/shop/flossweapon_3.png"]},
			{"id": "wash_3", "weapon_id": "wash", "name": "MOUTHWASH", "full_name": "Bubble Wash", "unlock_day": 21, "tier": 3, "images": ["res://assets/images/shop/BubbleWash.png"]}
		]
		
		# Find most recently unlocked item (or default to the latest unlocked up to cur_day)
		var target_w = weapon_defs[0]
		for w in weapon_defs:
			if cur_day >= int(w["unlock_day"]):
				target_w = w
				
		UIHelper.show_dental_item_unlocked_modal(self, target_w)
	)
	_add_menu_btn(card_vbox, "SIMULATE MISSED DAY", Color(0.96, 0.52, 0.12), Color(0.80, 0.38, 0.08), func():
		var on_ok = func():
			var p = GameState.get_active_profile()
			if not p.is_empty():
				# Set lastBrushDate to 2 days ago so missed-day detection triggers
				var two_days_ago = Time.get_unix_time_from_system() - (2 * 86400)
				var dt = Time.get_datetime_dict_from_unix_time(int(two_days_ago))
				p["lastBrushDate"] = "%04d-%02d-%02d" % [dt.year, dt.month, dt.day]
				p["candyTrapPending"] = true
				p["streak"] = 0
				# Mark the current day as missed
				var node = int(p.get("currentNode", 1))
				var day = GameState.day_for_node(node)
				if day - 1 < p["daysStatus"].size():
					p["daysStatus"][day - 1] = "missed"
				GameState.save_game()
				GameState.stats_updated.emit(p)
				GameState.push_toast("Missed Day Simulated", "Candy Trap is now pending!", "", "orange")
				# Navigate directly to candy_trap (Godot doesn't auto-check on map load)
				navigate_requested.emit("candy_trap")
			else:
				GameState.push_toast("No Profile", "Select a player first.", "", "orange")
		UIHelper.show_parental_gate(self, on_ok, Callable(), "SIMULATE MISSED DAY")
	)
	
	# Purple Pill: Test Achievement
	_add_menu_btn(card_vbox, "TEST ACHIEVEMENT", Color(0.68, 0.42, 0.92), Color(0.50, 0.28, 0.74), func():
		GameState.push_achievement("Level Up!", "Level 10 Pearly Legend", "You reached the max rank! Keep brushing to maintain your sparkling smile.", 500, "", "", 1000)
		GameState.push_toast("Test Achievement Queued", "Popup will appear when you return to the main map!", "", "purple")
	)
	
	# White Pill: Back to Settings
	var back_btn = Button.new()
	back_btn.text = "BACK TO SETTINGS"
	back_btn.custom_minimum_size = Vector2(334, 44)
	var b_st = UIHelper.create_bubbly_panel(22, Color(0.92, 0.96, 1.0), Color(0.75, 0.85, 0.95), 2)
	back_btn.add_theme_stylebox_override("normal", b_st)
	back_btn.add_theme_stylebox_override("hover", b_st)
	back_btn.add_theme_stylebox_override("pressed", b_st)
	UIHelper.apply_bubbly_label(back_btn, 13, Color(0.18, 0.42, 0.68), true)
	back_btn.pressed.connect(func():
		AudioManager.play_sfx("click")
		back_pressed.emit()
	)
	card_vbox.add_child(back_btn)

func _relayout():
	var safe_sz = UIHelper.get_viewport_safe_size(self)
	var w = safe_sz.x
	var h = safe_sz.y
	var is_tablet = w >= 600
	
	if title_lbl:
		var title_y = 36.0 if not is_tablet else 46.0
		title_lbl.position = Vector2(0, title_y)
		title_lbl.size = Vector2(w, 40)
		title_lbl.add_theme_font_size_override("font_size", 28 if not is_tablet else 38)
		
	if card_panel:
		var card_w = min(w - 32.0, 396.0) if not is_tablet else min(w - 80.0, 480.0)
		var card_top = 88.0 if not is_tablet else 110.0
		var card_h = min(h - card_top - 20.0, 660.0)
		card_panel.position = Vector2((w - card_w) * 0.5, card_top)
		card_panel.size = Vector2(card_w, card_h)
		
		var card_scroll = card_panel.get_node_or_null("CardScroll")
		if card_scroll:
			card_scroll.position = Vector2(14, 14)
			card_scroll.size = Vector2(card_w - 28.0, card_h - 28.0)
		if card_vbox:
			for btn in card_vbox.get_children():
				if btn is Button:
					btn.custom_minimum_size = Vector2(card_w - 44.0, 42.0)

func _add_menu_btn(container: Control, text: String, fill_col: Color, border_col: Color, on_click: Callable):
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(334, 44)
	var st = UIHelper.create_bubbly_panel(22, fill_col, border_col, 2)
	btn.add_theme_stylebox_override("normal", st)
	btn.add_theme_stylebox_override("hover", st)
	btn.add_theme_stylebox_override("pressed", st)
	UIHelper.apply_bubbly_label(btn, 13, Color.WHITE, true)
	btn.pressed.connect(func():
		AudioManager.play_sfx("click")
		on_click.call()
	)
	container.add_child(btn)


