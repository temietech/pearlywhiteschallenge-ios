# scripts/main.gd
extends Control

var content_container: Control
var top_bar: Control
var bottom_nav: Control
var achievement_overlay: Control
var toast_overlay: Control
var tutorial_overlay: Control
var notification_manager: Node

var current_screen_node: Control
var current_screen_name: String = ""

const SCRIPTS = {
	"start": "res://scripts/start_screen.gd",
	"privacy": "res://scripts/privacy_policy_screen.gd",
	"profiles": "res://scripts/profiles_screen.gd",
	"create_profile": "res://scripts/create_profile_screen.gd",
	"map": "res://scripts/map_screen.gd",
	"floss": "res://scripts/floss_screen.gd",
	"brush_check": "res://scripts/brush_check_screen.gd",
	"brushing": "res://scripts/brushing_screen.gd",
	"quiz": "res://scripts/quiz_screen.gd",
	"combat": "res://scripts/combat_screen.gd",
	"whack": "res://scripts/whack_screen.gd",
	"memory": "res://scripts/memory_screen.gd",
	"surprise": "res://scripts/surprise_screen.gd",
	"candy_trap": "res://scripts/candy_trap_screen.gd",
	"shop": "res://scripts/shop_screen.gd",
	"badges": "res://scripts/badges_screen.gd",
	"facts": "res://scripts/facts_screen.gd",
	"story": "res://scripts/story_screen.gd",
	"profile": "res://scripts/profile_screen.gd",
	"select_player": "res://scripts/select_player_screen.gd",
	"character_select": "res://scripts/character_select_screen.gd",
	"settings": "res://scripts/settings_screen.gd",
	"avatar_care": "res://scripts/avatar_care_screen.gd",
	"dev_menu": "res://scripts/dev_menu_screen.gd"
}
var _cached_scripts: Dictionary = {}

func _ready():
	anchors_preset = Control.PRESET_FULL_RECT
	anchor_right = 1.0
	anchor_bottom = 1.0
	custom_minimum_size = Vector2(450, 800)

	UIHelper.get_pause_button_texture()

	_build_framework()
	_apply_safe_area()
	get_viewport().size_changed.connect(_apply_safe_area)
	# iOS only reports the notch / home-indicator insets once its view has finished laying out,
	# which is usually AFTER _ready. Re-check a few times during start-up so the insets are never
	# stuck at zero (that left titles under the notch on iPhone).
	for delay in [0.1, 0.4, 1.0, 2.0, 4.0]:
		get_tree().create_timer(delay).timeout.connect(_apply_safe_area)
	_setup_keyboard_handling()

	# Preload Candy Crusade 3D scene asynchronously in background
	call_deferred("_preload_background_assets")

	# Cold boot: always show Start Screen
	navigate_to("start")

func _preload_background_assets():
	if GameState and GameState.has_method("preload_candy_crusade_in_background"):
		GameState.preload_candy_crusade_in_background()

func _build_framework():
	# Background Base Color
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.offset_right = 0
	bg.offset_bottom = 0
	bg.color = UIHelper.SKY_BLUE
	add_child(bg)
	
	# Content Container for Active Screen
	content_container = Control.new()
	content_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	content_container.anchor_right = 1.0
	content_container.anchor_bottom = 1.0
	content_container.offset_right = 0
	content_container.offset_bottom = 0
	add_child(content_container)
	
	# Top Bar (anchored full-width at top)
	var top_bar_script = preload("res://scripts/top_bar.gd")
	top_bar = Control.new()
	top_bar.set_script(top_bar_script)
	top_bar.anchor_left = 0.0
	top_bar.anchor_right = 1.0
	top_bar.anchor_top = 0.0
	top_bar.anchor_bottom = 0.0
	top_bar.offset_top = 0
	top_bar.offset_bottom = 80
	top_bar.z_index = 100
	top_bar.z_as_relative = false
	top_bar.avatar_pressed.connect(func(): navigate_to("profile"))
	top_bar.settings_pressed.connect(func(): navigate_to("settings"))
	top_bar.back_pressed.connect(func(): navigate_to("map"))
	add_child(top_bar)
	
	# Bottom Navigation (anchored full-width at bottom)
	var bottom_nav_script = preload("res://scripts/bottom_nav.gd")
	bottom_nav = Control.new()
	bottom_nav.set_script(bottom_nav_script)
	bottom_nav.anchor_left = 0.0
	bottom_nav.anchor_right = 1.0
	bottom_nav.anchor_top = 1.0
	bottom_nav.anchor_bottom = 1.0
	bottom_nav.offset_top = -88
	bottom_nav.offset_bottom = 0
	bottom_nav.z_index = 100
	bottom_nav.z_as_relative = false
	bottom_nav.tab_selected.connect(_on_tab_selected)
	add_child(bottom_nav)
	
	# Overlays
	var toast_script = preload("res://scripts/toast_overlay.gd")
	toast_overlay = Control.new()
	toast_overlay.set_script(toast_script)
	toast_overlay.z_index = 200
	toast_overlay.z_as_relative = false
	add_child(toast_overlay)
	
	var achieve_script = preload("res://scripts/achievement_overlay.gd")
	achievement_overlay = Control.new()
	achievement_overlay.set_script(achieve_script)
	achievement_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	achievement_overlay.anchor_right = 1.0
	achievement_overlay.anchor_bottom = 1.0
	achievement_overlay.offset_left = 0
	achievement_overlay.offset_top = 0
	achievement_overlay.offset_right = 0
	achievement_overlay.offset_bottom = 0
	achievement_overlay.z_index = 210
	achievement_overlay.z_as_relative = false
	add_child(achievement_overlay)
	
	# Push Notification & Event Reminders Manager
	var notif_script = preload("res://scripts/notification_manager.gd")
	notification_manager = Node.new()
	notification_manager.name = "NotificationManager"
	notification_manager.set_script(notif_script)
	add_child(notification_manager)

## Asks for camera access once the player has passed the privacy policy screen, so the
## iOS/Android permission prompt appears here instead of unexpectedly on the scan page.
## Safe to call repeatedly: the OS only shows the prompt the first time.
func _request_camera_permission():
	var os_name := OS.get_name()
	if os_name != "iOS" and os_name != "Android":
		return
	# 1) Native scanner plugin (also handles the permission on both platforms)
	if Engine.has_singleton("PearlyToothbrushScanner"):
		var scanner = Engine.get_singleton("PearlyToothbrushScanner")
		if scanner.has_method("hasCameraPermission") and scanner.call("hasCameraPermission"):
			return
		if scanner.has_method("requestCameraPermission"):
			scanner.call("requestCameraPermission")
			return
	# 2) Plugin missing: fall back to the engine so the prompt still appears
	if os_name == "Android":
		OS.request_permission("CAMERA")
	else:
		# On iOS, Godot asks for camera access when camera feeds start being monitored
		CameraServer.monitoring_feeds = true

func _continue_after_start():
	# Right after Privacy & Terms: a grown-up must answer the adult question and create the
	# 4-digit Tooth Fairy PIN before anything else (camera prompt, player setup).
	# Runs once - also catches players updating from an older version that had no PIN.
	if not GameState.has_tooth_fairy_pin():
		if find_child("AdultCheckOverlay", false, false) or find_child("ParentalGateOverlay", false, false):
			return  # already showing (double tap on START)
		UIHelper.show_parental_gate(self, func():
			_continue_after_pin()
		, Callable(), "SET TOOTH FAIRY PIN", false, false)
		return
	_continue_after_pin()

func _continue_after_pin():
	_request_camera_permission()
	var count = GameState.profiles.size()
	if count == 0:
		navigate_to("create_profile")
	elif count == 1:
		var p = GameState.profiles[0]
		GameState.set_active_profile(p.get("id", ""))
		navigate_to("map")
	else:
		navigate_to("select_player")

func navigate_to(screen_name: String, extra_args: Dictionary = {}):
	if not SCRIPTS.has(screen_name):
		return
		
	current_screen_name = screen_name
	
	if current_screen_node:
		current_screen_node.queue_free()
		current_screen_node = null
		
	var script: Script = null
	if _cached_scripts.has(screen_name):
		script = _cached_scripts[screen_name]
	else:
		script = load(SCRIPTS[screen_name])
		if script:
			_cached_scripts[screen_name] = script
			
	if not script:
		return
		
	var new_screen = Control.new()
	new_screen.set_script(script)
	new_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	new_screen.anchor_right = 1.0
	new_screen.anchor_bottom = 1.0
	new_screen.offset_right = 0
	new_screen.offset_bottom = 0
	
	if screen_name == "start":
		new_screen.start_pressed.connect(func():
			# First launch only: privacy policy page comes right after "Start Brushing"
			if not GameState.privacy_policy_agreed:
				navigate_to("privacy")
			else:
				_continue_after_start()
		)
	elif screen_name == "privacy":
		new_screen.agreed.connect(func(): _continue_after_start())
	elif screen_name == "profiles":
		new_screen.profile_picked.connect(func(id):
			GameState.set_active_profile(id)
			navigate_to("map")
		)
		new_screen.submit_pressed.connect(func():
			if GameState.get_active_profile().is_empty() and GameState.profiles.size() > 0:
				GameState.set_active_profile(GameState.profiles[0]["id"])
			navigate_to("map")
		)
		new_screen.create_profile_requested.connect(func():
			navigate_to("create_profile")
		)
		new_screen.edit_profile_requested.connect(func(id):
			navigate_to("create_profile", {"edit_id": id})
		)
	elif screen_name == "create_profile":
		if extra_args.has("edit_id"):
			new_screen.call_deferred("setup_edit", extra_args["edit_id"])
		
		new_screen.done_pressed.connect(func():
			navigate_to("map")
		)
		new_screen.back_pressed.connect(func():
			if GameState.profiles.size() == 0:
				navigate_to("start")
			else:
				navigate_to("select_player")
		)
	elif screen_name == "select_player":
		new_screen.player_chosen.connect(func(id):
			if id != "":
				GameState.set_active_profile(id)
			navigate_to("map")
		)
		new_screen.manage_players_requested.connect(func():
			navigate_to("profiles")
		)
	elif screen_name == "map":
		new_screen.launch_node.connect(_on_map_node_launched)
		new_screen.launch_minigame.connect(func(game): navigate_to(game))
	elif screen_name == "floss":
		new_screen.floss_completed.connect(func(): navigate_to("brush_check"))
		new_screen.no_floss_proceed.connect(func(): navigate_to("brush_check"))
		new_screen.back_pressed.connect(func(): navigate_to("map"))
	elif screen_name == "brushing":
		if new_screen.has_signal("claim_rewards_pressed"):
			new_screen.claim_rewards_pressed.connect(func(day):
				navigate_to("facts", {"auto_show_day": day, "is_review": false})
			)
		if new_screen.has_signal("review_fact_pressed"):
			new_screen.review_fact_pressed.connect(func():
				navigate_to("facts", {"is_review": true})
			)
		new_screen.brushing_completed.connect(func():
			# First finished brush = friendly moment to ask iOS for notification permission
			LocalNotifications.request_permission()
			LocalNotifications.refresh()
		)
		new_screen.quit_requested.connect(func(): navigate_to("map"))
		if new_screen.has_signal("settings_requested"):
			new_screen.settings_requested.connect(func(): navigate_to("settings"))
	elif screen_name == "story":
		if extra_args.has("auto_show_day") and new_screen.has_method("setup_story_view"):
			new_screen.call_deferred("setup_story_view", extra_args["auto_show_day"])
		new_screen.back_pressed.connect(func(): navigate_to("map"))
	elif screen_name == "quiz":
		var quiz_done = false
		new_screen.quiz_completed.connect(func():
			if quiz_done: return
			quiz_done = true
			var p = GameState.get_active_profile()
			var cur_node = int(p.get("currentNode", 0))
			var node_info = GameState.get_node_data(cur_node)
			var n_type = node_info.get("type", "")
			if cur_node == 0 or n_type == "intro":
				GameState.finish_node(false)
			elif n_type == "quiz":
				GameState.finish_node(false)
			navigate_to("map")
		)
	elif screen_name == "avatar_care":
		if new_screen.has_signal("back_pressed"):
			new_screen.back_pressed.connect(func(): navigate_to("map"))
	elif screen_name == "facts":
		if extra_args.has("auto_show_day") and new_screen.has_method("setup_fact_view"):
			new_screen.call_deferred("setup_fact_view", extra_args.get("auto_show_day", 1), extra_args.get("is_review", false))
		elif extra_args.get("is_review", false) and new_screen.has_method("setup_fact_view"):
			new_screen.call_deferred("setup_fact_view", 0, true)
		new_screen.back_pressed.connect(func():
			navigate_to("map")
		)
	elif screen_name == "shop":
		if (extra_args.has("expand_weapon") or extra_args.has("tab")) and new_screen.has_method("setup_view"):
			var w_id = str(extra_args.get("expand_weapon", ""))
			var tab_id = str(extra_args.get("tab", "powerups"))
			new_screen.setup_view(w_id, tab_id)
		if new_screen.has_signal("back_pressed"):
			new_screen.back_pressed.connect(func(): navigate_to("map"))
	elif screen_name == "badges":
		if new_screen.has_signal("back_pressed"):
			new_screen.back_pressed.connect(func(): navigate_to("map"))
	elif screen_name == "combat":
		UIHelper.create_candy_crusade_loading_overlay(self)
		var is_boss_match = extra_args.get("is_boss", false)
		new_screen.call_deferred("setup_fight", is_boss_match)
		var combat_done = false
		new_screen.combat_finished.connect(func(win):
			if combat_done: return
			combat_done = true
			UIHelper.dismiss_candy_crusade_loading_overlay(self)
			if win:
				var p = GameState.get_active_profile()
				var cur_node = int(p.get("currentNode", 0))
				var node_info = GameState.get_node_data(cur_node)
				var n_type = node_info.get("type", "")
				if cur_node == 0 or n_type == "intro":
					GameState.set_node_stage(0, 1)
					navigate_to("quiz")
					return
				elif n_type == "evening":
					if int(node_info.get("day", 0)) == 28:
						# Day 28: Candy Crusade is the last step after the night brush
						GameState.finish_node(true)
					else:
						GameState.set_node_stage(cur_node, 1)
				elif n_type == "morning":
					GameState.finish_node(false)
				elif n_type == "minigame":
					GameState.finish_node(false)
				else:
					GameState.finish_node(false)
			navigate_to("map")
		)
	elif screen_name == "whack" or screen_name == "memory" or screen_name == "surprise":
		var minigame_completed = false
		var p_start = GameState.get_active_profile()
		var launched_node = int(p_start.get("currentNode", 0))
		
		var handle_minigame_done = func(completed_successfully: bool = true):
			if minigame_completed:
				return
			minigame_completed = true
			
			var p = GameState.get_active_profile()
			var cur_node = int(p.get("currentNode", 0))
			if cur_node != launched_node:
				navigate_to("map")
				return
				
			if completed_successfully:
				var node_info = GameState.get_node_data(cur_node)
				var n_type = node_info.get("type", "")
				if n_type == "morning":
					GameState.finish_node(false)
				elif n_type == "evening":
					GameState.set_node_stage(cur_node, 1)
				elif n_type == "minigame":
					GameState.finish_node(false)
			navigate_to("map")
			
		if new_screen.has_signal("game_ended"):
			new_screen.game_ended.connect(func(): handle_minigame_done.call(false))
		if new_screen.has_signal("surprise_claimed"):
			new_screen.surprise_claimed.connect(func(): handle_minigame_done.call(true))
		if new_screen.has_signal("game_won"):
			new_screen.game_won.connect(func(): handle_minigame_done.call(true))
	elif screen_name == "profile":
		new_screen.change_avatar_requested.connect(func(): navigate_to("character_select"))
		new_screen.switch_player_requested.connect(func(): navigate_to("select_player"))
		if new_screen.has_signal("back_pressed"):
			new_screen.back_pressed.connect(func(): navigate_to("map"))
	elif screen_name == "character_select":
		new_screen.character_selected.connect(func(): navigate_to("profile"))
		if new_screen.has_signal("back_pressed"):
			new_screen.back_pressed.connect(func(): navigate_to("profile"))
	elif screen_name == "settings":
		new_screen.switch_profile_requested.connect(func(): navigate_to("select_player"))
		new_screen.reset_completed.connect(func(): navigate_to("start"))
		if new_screen.has_signal("dev_menu_requested"):
			new_screen.dev_menu_requested.connect(func(): navigate_to("dev_menu"))
		if new_screen.has_signal("back_pressed"):
			new_screen.back_pressed.connect(func(): navigate_to("map"))
	elif screen_name == "brush_check":
		new_screen.back_pressed.connect(func(): navigate_to("map"))
		new_screen.start_brushing_pressed.connect(func(): navigate_to("brushing"))
	elif screen_name == "candy_trap":
		new_screen.closed.connect(func(): navigate_to("map"))
		new_screen.completed.connect(func(): navigate_to("map"))
	elif screen_name == "dev_menu":
		new_screen.navigate_requested.connect(func(sn): navigate_to(sn))
		new_screen.back_pressed.connect(func(): navigate_to("settings"))
		
	content_container.add_child(new_screen)
	current_screen_node = new_screen
	
	_apply_content_insets()
	_update_chrome_visibility(screen_name)
	if bottom_nav and bottom_nav.has_method("set_active"):
		bottom_nav.set_active(screen_name)
		
	# The brushing song starts only once the player presses START BRUSHING (see brushing_screen.gd)
	if AudioManager and not (screen_name in ["brushing", "brush_check", "floss"]):
		AudioManager.play_screen_bgm(screen_name)
	elif AudioManager and screen_name == "brushing":
		# Silence the map music; the brushing song starts on START BRUSHING
		AudioManager.stop_bgm()

func _update_chrome_visibility(screen_name: String):
	# Global top bar is ONLY visible on map
	top_bar.visible = (screen_name == "map")
	
	# Global bottom navigation is visible on map and avatar care
	bottom_nav.visible = (screen_name == "map" or screen_name == "avatar_care")
	
	# Achievement / Level Up overlay is strictly restricted to map main page
	if achievement_overlay and achievement_overlay.has_method("on_screen_changed"):
		achievement_overlay.on_screen_changed(screen_name)
		
	# Toast notification overlay disabled per user request
	if toast_overlay and toast_overlay.has_method("dismiss"):
		toast_overlay.dismiss()
	
	if top_bar.visible and top_bar.has_method("set_screen"):
		top_bar.set_screen(screen_name)

		
	# First-run coach-mark tutorial on map for first time users (only)
	if screen_name == "map":
		var p = GameState.get_active_profile()
		if not p.is_empty() and not p.get("tutorial_done", false):
			call_deferred("_start_tutorial")
	else:
		if tutorial_overlay and is_instance_valid(tutorial_overlay):
			tutorial_overlay.queue_free()
			tutorial_overlay = null


func _start_tutorial():
	if tutorial_overlay and is_instance_valid(tutorial_overlay):
		return
	var tut_script = preload("res://scripts/tutorial_overlay.gd")
	tutorial_overlay = Control.new()
	tutorial_overlay.set_script(tut_script)
	tutorial_overlay.z_index = 200
	tutorial_overlay.tutorial_finished.connect(func():
		tutorial_overlay = null
		# Only NOW (tutorial skipped or completed) may the daily stamp card / badge popups appear
		if current_screen_node and is_instance_valid(current_screen_node) and current_screen_node.has_method("_check_main_screen_popups"):
			current_screen_node.call_deferred("_check_main_screen_popups")
	)
	add_child(tutorial_overlay)

func _on_map_node_launched(day: int, node_type: String):
	if node_type == "brush":
		navigate_to("floss")
	elif node_type == "quiz":
		navigate_to("quiz")
	elif node_type == "combat":
		UIHelper.show_pre_battle_ammo_check_modal(self, func():
			UIHelper.create_candy_crusade_loading_overlay(self)
			await get_tree().process_frame
			await get_tree().process_frame
			navigate_to("combat", {"is_boss": (day == 28 or day in [1, 9, 19, 28])})
		, func():
			navigate_to("shop", {"tab": "ammo"})
		)
	elif node_type == "minigame":
		var p = GameState.get_active_profile()
		var cur_node = int(p.get("currentNode", 0))
		var n_info = GameState.get_node_data(cur_node)
		var is_evening = (n_info.get("type", "") == "evening")
		var games = ["whack", "memory", "surprise"]
		var offset = 1 if is_evening else 0
		var pick = games[(day + offset) % games.size()]
		navigate_to(pick)
	elif node_type == "surprise":
		navigate_to("surprise")
	elif node_type == "trap":
		navigate_to("candy_trap")

func _on_tab_selected(tab_name: String):
	if tab_name != current_screen_name:
		navigate_to(tab_name)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		if is_node_ready():
			call_deferred("_apply_safe_area")

var _last_safe_insets := Vector2(-1.0, -1.0)

func _apply_safe_area():
	# Handle iPhone notch / Dynamic Island / home indicator.
	# DisplayServer.get_display_safe_area() is in real screen pixels; the game viewport is scaled
	# (canvas_items stretch), so convert to viewport units before using it.
	var top_inset := 0.0
	var bottom_inset := 0.0
	var os_name := OS.get_name()
	if os_name == "iOS" or os_name == "Android":
		var safe: Rect2i = DisplayServer.get_display_safe_area()
		var win_size: Vector2i = DisplayServer.window_get_size()
		var vp_size: Vector2 = get_viewport_rect().size
		if win_size.x > 0 and win_size.y > 0 and safe.size.x > 0 and safe.size.y > 0:
			var sy: float = vp_size.y / float(win_size.y)
			top_inset = max(0.0, float(safe.position.y) * sy)
			bottom_inset = max(0.0, float(win_size.y - (safe.position.y + safe.size.y)) * sy)
		# Fallback: tall iPhones (notch / Dynamic Island, screen ratio ~2.16) always have insets.
		# If iOS has not reported them yet, use typical values so nothing sits under the notch.
		if os_name == "iOS" and top_inset < 1.0 and win_size.x > 0:
			var ratio := float(win_size.y) / float(win_size.x)
			if ratio > 2.0:
				var pt_to_vp: float = vp_size.x / 390.0  # ~390pt wide phones
				top_inset = 50.0 * pt_to_vp
				bottom_inset = max(bottom_inset, 34.0 * pt_to_vp)
	var new_insets := Vector2(top_inset, bottom_inset)
	if new_insets.distance_to(_last_safe_insets) < 0.5:
		return  # nothing changed - avoid needless screen rebuilds
	_last_safe_insets = new_insets
	UIHelper.safe_top = top_inset
	UIHelper.safe_bottom = bottom_inset

	if top_bar:
		# Avatar / back / settings buttons stay in the top corners; the stats banner is pushed
		# down below the notch by TopBar._relayout (bar grows by the inset, nothing is shrunk)
		top_bar.offset_top = 0.0
		top_bar.offset_bottom = top_inset + 80.0
		if top_bar.has_method("_relayout"):
			top_bar.call("_relayout")
	if bottom_nav:
		# Bottom nav sits flush on the very bottom edge of the device (not lifted above the
		# home indicator) - matches the design; the buttons are tall enough to stay tappable.
		bottom_nav.offset_top = -88.0
		bottom_nav.offset_bottom = 0.0
	_apply_content_insets()
	# Every screen fills the whole display and lays itself out around the notch, so tell the
	# current one to re-layout (its size does not change, so it gets no resize event by itself)
	if current_screen_node and is_instance_valid(current_screen_node):
		if current_screen_node.has_method("on_safe_area_changed"):
			current_screen_node.call_deferred("on_safe_area_changed")
		else:
			current_screen_node.call_deferred("notification", NOTIFICATION_RESIZED)

func _apply_content_insets():
	# Every page fills the WHOLE screen (behind the notch and the home indicator).
	# Each page brings its own title down below the notch using UIHelper.safe_top,
	# while corner buttons (back / close / settings / stats) stay up in the corners.
	if not content_container:
		return
	content_container.offset_top = 0.0
	content_container.offset_bottom = 0.0


# ------------------------------------------------------------------
# Keyboard handling: dismiss on Enter or tap outside the focused box
# Popups like parental gate handle their own lift above the keyboard
# ------------------------------------------------------------------
func _setup_keyboard_handling():
	get_tree().node_added.connect(_on_kb_node_added)
	set_process_input(true)

func _on_kb_node_added(node: Node):
	if node is LineEdit:
		var le := node as LineEdit
		le.text_submitted.connect(func(_t: String):
			le.release_focus()
			DisplayServer.virtual_keyboard_hide()
		)

func _input(event: InputEvent) -> void:
	var pressed := false
	var pos := Vector2.ZERO
	if event is InputEventScreenTouch and event.pressed:
		pressed = true
		pos = event.position
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = true
		pos = event.position
	if not pressed:
		return
	var f := get_viewport().gui_get_focus_owner()
	if f == null or not (f is LineEdit or f is TextEdit):
		return
	var xf := f.get_global_transform_with_canvas()
	var rect := Rect2(xf.origin, f.size * xf.get_scale())
	if not rect.has_point(pos):
		f.release_focus()
		DisplayServer.virtual_keyboard_hide()
