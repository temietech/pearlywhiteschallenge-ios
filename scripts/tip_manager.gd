# scripts/tip_manager.gd - RevenueCat In-App Tipping & Dev Support Autoload Singleton
extends Node

## Emitted when a developer tip transaction completes successfully
signal tip_completed(details: Dictionary)

## Emitted if tipping is cancelled or encounters an error
signal tip_failed(error_message: String)

## Emitted when tipping is initiated
signal tip_initiated()

@export var revenuecat_public_api_key: String = "appl_wYiTIHJKTweghjpzPOWeGOHPTBC"
@export var default_package_id: String = "tip_tier_499"
@export var paywall_url: String = "" # Optional RevenueCat Web Billing or Stripe payment page URL
@export var bonus_coins: int = 500
@export var bonus_points: int = 500

var is_processing: bool = false
var _http_request: HTTPRequest = null
var _thank_you_modal: Control = null
var _tip_jar_modal: Control = null

const TIP_TIERS = [
	{
		"id": "tip_tier_099",
		"name": "Small Tooth Tip",
		"price": "$0.99",
		"coins": 100,
		"points": 100,
		"badge": "🥉 SMALL TIP",
		"color": Color(0.18, 0.52, 0.88)
	},
	{
		"id": "tip_tier_299",
		"name": "Molar Supporter",
		"price": "$2.99",
		"coins": 300,
		"points": 300,
		"badge": "🥈 POPULAR",
		"color": Color(0.58, 0.28, 0.82)
	},
	{
		"id": "tip_tier_499",
		"name": "Royal Crown Supporter",
		"price": "$4.99",
		"coins": 500,
		"points": 500,
		"badge": "🥇 BEST VALUE",
		"color": Color(0.92, 0.58, 0.15)
	},
	{
		"id": "tip_tier_999",
		"name": "Legendary Supporter",
		"price": "$9.99",
		"coins": 1500,
		"points": 1500,
		"badge": "💎 LEGEND",
		"color": Color(0.85, 0.15, 0.45)
	}
]

func _ready():
	_setup_http_node()
	tip_completed.connect(_on_tip_completed)
	_setup_native_plugin_listeners()

const RC_SINGLETON := "GodotxRevenueCat"
var _rc: Object = null
var _rc_initialized: bool = false
var _pending_comment: String = ""
var _pending_package_id: String = ""
# Real App Store prices (already in the player's own currency), filled in by fetch_products
var _store_prices: Dictionary = {}

func _setup_native_plugin_listeners():
	# Real RevenueCat (GodotX plugin) - only exists in iOS/Android exports
	if not Engine.has_singleton(RC_SINGLETON):
		return
	_rc = Engine.get_singleton(RC_SINGLETON)
	if _rc.has_signal("purchase_result") and not _rc.is_connected("purchase_result", _on_rc_purchase_result):
		_rc.connect("purchase_result", _on_rc_purchase_result)
	if _rc.has_signal("products") and not _rc.is_connected("products", _on_rc_products):
		_rc.connect("products", _on_rc_products)
	if revenuecat_public_api_key.is_empty():
		return
	_rc.initialize(revenuecat_public_api_key, "", OS.is_debug_build())
	_rc_initialized = true
	_fetch_store_prices()

## Ask the App Store (through RevenueCat) for the real, localised price of each tip
func _fetch_store_prices():
	if _rc == null or not _rc_initialized or not _rc.has_method("fetch_products"):
		return
	var ids: Array = []
	for t in TIP_TIERS:
		ids.append(str(t["id"]))
	_rc.fetch_products(ids)

func _on_rc_products(data: Dictionary):
	var list = data.get("products", [])
	for i in range(list.size()):
		var prod = list[i]
		var pid := str(prod.get("id", ""))
		var price := str(prod.get("price", ""))
		if pid != "" and price != "":
			_store_prices[pid] = price
	print("[TipManager] App Store prices loaded: ", _store_prices)

## Price text for a tip button: the App Store's own price when known, otherwise the default
func get_tier_price(tier: Dictionary) -> String:
	return str(_store_prices.get(str(tier.get("id", "")), tier.get("price", "")))

func _on_rc_purchase_result(data: Dictionary):
	var err := str(data.get("error", ""))
	if bool(data.get("cancelled", false)):
		is_processing = false
		tip_failed.emit("Purchase cancelled.")
		return
	if not err.is_empty():
		is_processing = false
		tip_failed.emit(err)
		if err == "not_found":
			# Product id not found in App Store Connect / RevenueCat (or prices not live yet)
			_show_notice("Tip not available", "This tip isn't available right now. Please try again later.")
		else:
			_show_notice("Purchase failed", "The purchase didn't go through. No money was taken. Please try again.")
		return
	var pid := str(data.get("product_id", _pending_package_id))
	_finalize_successful_tip(pid, "revenuecat", _pending_comment)

func _setup_http_node():
	if not _http_request or not is_instance_valid(_http_request):
		_http_request = HTTPRequest.new()
		_http_request.name = "RevenueCatHTTP"
		_http_request.timeout = 10.0
		add_child(_http_request)

## Sets a custom paywall or checkout URL for RevenueCat Web Billing
func set_paywall_url(url: String):
	paywall_url = url

## Sets the RevenueCat public API key dynamically
func set_api_key(key: String):
	revenuecat_public_api_key = key

## Direct purchase method for testing (used by debug tester)
func purchase_tip(package_id: String):
	if is_processing:
		return
	is_processing = true
	_execute_tip_purchase(package_id, "")

## Primary public method to initiate the tip / developer support action
func support_developers(_package_id: String = ""):
	if is_processing:
		return
		
	is_processing = true
	tip_initiated.emit()
	
	# Kids App Safe: Require parental confirmation before triggering in-app purchase flow
	# (never skipped: no host = no tip jar)
	var host: Control = _ui_host()
	if host == null:
		is_processing = false
		return
	var on_gate_passed = func():
		show_tip_jar_modal()
	var on_gate_failed = func():
		is_processing = false
		tip_failed.emit("Parental gate cancelled.")
	UIHelper.show_parental_gate(
		host,
		on_gate_passed,
		on_gate_failed,
		"PARENT CONFIRMATION"
	)

## Spawns the rich Tip Jar Selection Modal with $0.99, $2.99, $4.99, $9.99 options
func show_tip_jar_modal():
	if _store_prices.size() < TIP_TIERS.size():
		_fetch_store_prices()
	if _tip_jar_modal and is_instance_valid(_tip_jar_modal):
		_tip_jar_modal.queue_free()
		_tip_jar_modal = null
		
	var tree = get_tree()
	if not tree or not tree.root:
		is_processing = false
		return
		
	var parent_target: Control = _ui_host()
	if parent_target == null:
		is_processing = false
		return
		
	var safe_sz = UIHelper.get_viewport_safe_size(parent_target)
	var dlg = UIHelper.create_modal_dialog(parent_target, 240, Color(0.04, 0.10, 0.24, 0.85))
	_tip_jar_modal = dlg["overlay"]
	var center_cont = dlg["center"]
	
	var is_tablet = safe_sz.x >= 560.0
	var card_w = clampf(safe_sz.x - 36.0, 310.0, 440.0)
	var card_h = clampf(safe_sz.y - 48.0, 480.0, 580.0)
	
	var card = Panel.new()
	card.custom_minimum_size = Vector2(card_w, card_h)
	card.size = Vector2(card_w, card_h)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	var card_style = UIHelper.create_bubbly_panel(28, Color.WHITE, Color(0.92, 0.58, 0.15), 4)
	card_style.shadow_size = 14
	card_style.shadow_color = Color(0.08, 0.20, 0.45, 0.35)
	card.add_theme_stylebox_override("panel", card_style)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	center_cont.add_child(card)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 16.0
	vbox.offset_right = -16.0
	vbox.offset_top = 16.0
	vbox.offset_bottom = -16.0
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)
	card.add_child(vbox)
	
	# Close button on top right
	var top_hbox = HBoxContainer.new()
	top_hbox.alignment = BoxContainer.ALIGNMENT_END
	var close_btn = UIHelper.create_close_button(Vector2(28, 28))
	close_btn.pressed.connect(func():
		AudioManager.play_sfx("click")
		is_processing = false
		if _tip_jar_modal and is_instance_valid(_tip_jar_modal):
			_tip_jar_modal.queue_free()
			_tip_jar_modal = null
	)
	top_hbox.add_child(close_btn)
	vbox.add_child(top_hbox)
	
	# Header title
	var title = Label.new()
	title.text = "SUPPORT DEVELOPERS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(title, 22 if not is_tablet else 26, Color(0.92, 0.58, 0.15), true)
	vbox.add_child(title)
	
	# Subtitle
	var sub_lbl = Label.new()
	sub_lbl.text = "Help Pearly Whites Challenge grow & unlock Sir Crown!"
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	UIHelper.apply_bubbly_label(sub_lbl, 11, Color(0.35, 0.48, 0.65))
	vbox.add_child(sub_lbl)
	
	# Scrollable container for the 4 Tier Cards
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(card_w - 32.0, card_h - 210.0)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	
	var tiers_vbox = VBoxContainer.new()
	tiers_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tiers_vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(tiers_vbox)
	
	# Optional Supporter Comment / Note Input Box
	var comment_box = VBoxContainer.new()
	comment_box.add_theme_constant_override("separation", 4)
	
	var comment_lbl = Label.new()
	comment_lbl.text = "Add a note or comment for the team (optional):"
	UIHelper.apply_bubbly_label(comment_lbl, 10, Color(0.25, 0.40, 0.60), true)
	comment_box.add_child(comment_lbl)
	
	var comment_input = LineEdit.new()
	comment_input.placeholder_text = "Leave a message of encouragement..."
	comment_input.custom_minimum_size = Vector2(card_w - 32.0, 38)
	var ci_style = UIHelper.create_bubbly_panel(14, Color(0.97, 0.98, 1.0), Color(0.80, 0.88, 0.98), 1.5)
	ci_style.content_margin_left = 10
	ci_style.content_margin_right = 10
	comment_input.add_theme_stylebox_override("normal", ci_style)
	comment_input.add_theme_stylebox_override("focus", ci_style)
	UIHelper.apply_bubbly_label(comment_input, 11, Color(0.15, 0.30, 0.55), false)
	comment_box.add_child(comment_input)
	
	vbox.add_child(comment_box)
	
	for tier in TIP_TIERS:
		var tier_card = _create_tier_card(tier, card_w - 48.0, comment_input)
		tiers_vbox.add_child(tier_card)
		
	# Bouncy pop-in animation
	card.pivot_offset = card.size * 0.5
	card.scale = Vector2(0.85, 0.85)
	card.modulate.a = 0.0
	var tw = card.create_tween().set_parallel(true)
	tw.tween_property(card, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "modulate:a", 1.0, 0.18)

func _create_tier_card(tier: Dictionary, target_w: float, comment_input: LineEdit = null) -> PanelContainer:
	var container = PanelContainer.new()
	container.custom_minimum_size = Vector2(target_w, 72)
	
	var card_color: Color = tier.get("color", Color(0.2, 0.5, 0.8))
	var st = UIHelper.create_bubbly_panel(16, Color(0.97, 0.98, 1.0), card_color, 2)
	st.shadow_size = 4
	st.shadow_color = Color(0.08, 0.18, 0.35, 0.12)
	container.add_theme_stylebox_override("panel", st)
	
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 10)
	hbox.offset_left = 10
	hbox.offset_right = -10
	hbox.offset_top = 8
	hbox.offset_bottom = -8
	container.add_child(hbox)
	
	# Left side: Badge & Name & Details
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 2)
	
	var badge_lbl = Label.new()
	badge_lbl.text = tier.get("badge", "") + " " + tier.get("name", "")
	UIHelper.apply_bubbly_label(badge_lbl, 13, card_color, true)
	info_vbox.add_child(badge_lbl)
	
	var coins = int(tier.get("coins", 500))
	var points = int(tier.get("points", 500))
	var desc_lbl = Label.new()
	desc_lbl.text = "Unlocks Sir Crown + %d Coins + %d Pts" % [coins, points]
	UIHelper.apply_bubbly_label(desc_lbl, 10, Color(0.35, 0.48, 0.65))
	info_vbox.add_child(desc_lbl)
	
	hbox.add_child(info_vbox)
	
	# Right side: Bubbly Price Purchase Button
	var price_btn = UIHelper.create_bubbly_button(get_tier_price(tier), card_color)
	price_btn.custom_minimum_size = Vector2(86, 42)
	price_btn.pressed.connect(func():
		AudioManager.play_sfx("click")
		var user_comment = comment_input.text.strip_edges() if comment_input else ""
		_select_and_purchase_tier(tier, user_comment)
	)
	hbox.add_child(price_btn)
	
	return container

func _select_and_purchase_tier(tier: Dictionary, user_comment: String = ""):
	if _tip_jar_modal and is_instance_valid(_tip_jar_modal):
		_tip_jar_modal.queue_free()
		_tip_jar_modal = null
		
	var package_id = str(tier.get("id", default_package_id))
	bonus_coins = int(tier.get("coins", 500))
	bonus_points = int(tier.get("points", 500))
	
	_execute_tip_purchase(package_id, user_comment)

## Executes a real RevenueCat / App Store purchase. Never grants rewards without a confirmed purchase.
func _execute_tip_purchase(package_id: String, user_comment: String = ""):
	if _rc == null or not _rc_initialized:
		is_processing = false
		tip_failed.emit("Store not available right now. Please try again later.")
		_show_notice("Store not available", "Tips can only be sent from the App Store version of the game.")
		return
	_pending_comment = user_comment
	_pending_package_id = package_id
	_rc.purchase(package_id)

## The game's main screen node (all popups go on top of it)
func _ui_host() -> Control:
	var tree = get_tree()
	if tree == null or tree.root == null:
		return null
	var main_node = tree.root.get_node_or_null("Main")
	if main_node is Control and is_instance_valid(main_node):
		return main_node
	if tree.current_scene is Control:
		return tree.current_scene
	return null

func _show_notice(title_text: String, body_text: String):
	# Small popup with an OK button so the player always knows what happened to the purchase
	var host: Control = _ui_host()
	if host == null:
		return
	var dlg = UIHelper.create_modal_dialog(host, 260, Color(0.04, 0.10, 0.24, 0.75))
	var overlay = dlg["overlay"]
	var safe_sz = UIHelper.get_viewport_safe_size(host)
	var card_w = clampf(safe_sz.x - 60.0, 260.0, 340.0)
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(card_w, 0)
	var st = UIHelper.create_bubbly_panel(24, Color.WHITE, Color(0.92, 0.58, 0.15), 3)
	st.content_margin_left = 18
	st.content_margin_right = 18
	st.content_margin_top = 16
	st.content_margin_bottom = 16
	card.add_theme_stylebox_override("panel", st)
	dlg["center"].add_child(card)
	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	card.add_child(vb)
	var t = Label.new()
	t.text = title_text
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(t, 18, Color(0.92, 0.58, 0.15), true)
	vb.add_child(t)
	var b = Label.new()
	b.text = body_text
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(card_w - 36.0, 0)
	UIHelper.apply_bubbly_label(b, 13, Color(0.20, 0.32, 0.52), false)
	vb.add_child(b)
	var ok = UIHelper.create_bubbly_button("OK", Color(0.22, 0.58, 0.92))
	ok.custom_minimum_size = Vector2(140, 44)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok.pressed.connect(func():
		AudioManager.play_sfx("click")
		if is_instance_valid(overlay):
			overlay.queue_free()
	)
	vb.add_child(ok)

func _finalize_successful_tip(package_id: String, provider: String = "test", user_comment: String = ""):
	is_processing = false
	var details = {
		"package_id": package_id,
		"provider": provider,
		"coins_awarded": bonus_coins,
		"points_awarded": bonus_points,
		"unlocked_character": "sircrown",
		"user_comment": user_comment,
		"timestamp": Time.get_unix_time_from_system()
	}
	tip_completed.emit(details)

## Internal handler when tipping is completed
func _on_tip_completed(details: Dictionary):
	# 1. Award in-game bonus coins and points
	var coins = int(details.get("coins_awarded", bonus_coins))
	var points = int(details.get("points_awarded", bonus_points))
	GameState.add_molar_coins(coins)
	GameState.add_points(points)
	
	# 2. Unlock the legendary Sir Crown special player
	GameState.unlock_character("sircrown", true)
	GameState.unlock_character("crown", false)
	
	# 3. Audio celebration
	AudioManager.play_sfx("cheer")
	
	# 4. Save and sync progress
	GameState.save_game()
	if FirebaseManager and FirebaseManager.has_method("save_challenge_data"):
		FirebaseManager.save_challenge_data(GameState.get_progress_dict())
		
	# 5. Spawn thank-you celebration animation modal
	spawn_thank_you_modal(details)

## Spawns the rich celebratory thank-you modal with Sir Crown and bonus rewards
func spawn_thank_you_modal(details: Dictionary = {}):
	if _thank_you_modal and is_instance_valid(_thank_you_modal):
		_thank_you_modal.queue_free()
		_thank_you_modal = null
		
	var tree = get_tree()
	if not tree or not tree.root:
		return
		
	var parent_target: Control = _ui_host()
	if parent_target == null:
		is_processing = false
		return
		
	var safe_sz = UIHelper.get_viewport_safe_size(parent_target)
	var dlg = UIHelper.create_modal_dialog(parent_target, 250, Color(0.04, 0.10, 0.24, 0.85))
	_thank_you_modal = dlg["overlay"]
	var center_cont = dlg["center"]
	
	var card_w = clampf(safe_sz.x - 36.0, 310.0, 420.0)
	var card_h = clampf(safe_sz.y - 60.0, 420.0, 560.0)
	
	var card = Panel.new()
	card.custom_minimum_size = Vector2(card_w, card_h)
	card.size = Vector2(card_w, card_h)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	var card_style = UIHelper.create_bubbly_panel(30, Color.WHITE, Color(0.95, 0.82, 0.25), 4)
	card_style.shadow_size = 12
	card_style.shadow_color = Color(0.08, 0.20, 0.45, 0.35)
	card.add_theme_stylebox_override("panel", card_style)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	center_cont.add_child(card)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 18.0
	vbox.offset_right = -18.0
	vbox.offset_top = 18.0
	vbox.offset_bottom = -18.0
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 10)
	card.add_child(vbox)
	
	# Header title
	var title = Label.new()
	title.text = "THANK YOU!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(title, 26, Color(0.12, 0.35, 0.65), true)
	vbox.add_child(title)
	
	# Subtitle
	var sub_lbl = Label.new()
	sub_lbl.text = "Your support keeps Pearly Whites Challenge growing and free of ads!"
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	UIHelper.apply_bubbly_label(sub_lbl, 13, Color(0.35, 0.48, 0.65))
	vbox.add_child(sub_lbl)
	
	# Display Supporter Comment if provided
	var user_comm = str(details.get("user_comment", "")).strip_edges()
	if not user_comm.is_empty():
		var comm_card = PanelContainer.new()
		var comm_st = UIHelper.create_bubbly_panel(14, Color(0.96, 0.98, 1.0), Color(0.85, 0.75, 0.95), 1.5)
		comm_card.add_theme_stylebox_override("panel", comm_st)
		
		var comm_lbl = Label.new()
		comm_lbl.text = "“%s”" % user_comm
		comm_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		comm_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		UIHelper.apply_bubbly_label(comm_lbl, 11, Color(0.40, 0.25, 0.65), false)
		comm_card.add_child(comm_lbl)
		vbox.add_child(comm_card)
	
	# Sir Crown Avatar Display with floating animation
	var crown_container = CenterContainer.new()
	crown_container.custom_minimum_size = Vector2(140, 140)
	vbox.add_child(crown_container)
	
	var crown_rect = TextureRect.new()
	crown_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crown_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var crown_tex = UIHelper.load_texture_safe("res://assets/images/characters/SirCrown-nobg.png")
	if not crown_tex:
		crown_tex = UIHelper.load_texture_safe("res://assets/images/brushing/brushingmascot.png")
	crown_rect.texture = crown_tex
	crown_rect.custom_minimum_size = Vector2(156, 156)
	crown_rect.size = Vector2(156, 156)
	crown_rect.pivot_offset = Vector2(78, 78)
	crown_container.add_child(crown_rect)
	
	# Bobbing and pulse animation for Sir Crown
	var cr_tw = crown_rect.create_tween().set_loops()
	cr_tw.tween_property(crown_rect, "position:y", -10.0, 0.9).as_relative().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	cr_tw.tween_property(crown_rect, "position:y", 10.0, 0.9).as_relative().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	# Unlocked Character Badge
	var unlocked_badge = Label.new()
	unlocked_badge.text = "NEW PLAYER UNLOCKED: SIR CROWN!"
	unlocked_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(unlocked_badge, 15, Color(0.86, 0.55, 0.05), true)
	vbox.add_child(unlocked_badge)
	
	# Reward Pills Row (Coins & Points)
	var rew_row = HBoxContainer.new()
	rew_row.alignment = BoxContainer.ALIGNMENT_CENTER
	rew_row.add_theme_constant_override("separation", 10)
	vbox.add_child(rew_row)
	
	var coins = int(details.get("coins_awarded", bonus_coins))
	var points = int(details.get("points_awarded", bonus_points))
	
	var coin_pill = _create_reward_badge("res://assets/images/congratulations/gold_tooth_coin.png", "%d Coins" % coins, Color(0.86, 0.55, 0.05))
	rew_row.add_child(coin_pill)
	
	var pt_pill = _create_reward_badge("res://assets/images/congratulations/purple_star_points.png", "%d Points" % points, Color(0.58, 0.28, 0.82))
	rew_row.add_child(pt_pill)
	
	# Awesome / Dismiss Button
	var btn_center = CenterContainer.new()
	vbox.add_child(btn_center)
	
	var ok_btn = UIHelper.create_themed_button("awesome", Vector2(240, 52))
	if not ok_btn.texture_normal:
		ok_btn = UIHelper.create_bubbly_button("USE SIR CROWN!", Color(0.92, 0.58, 0.15))
		ok_btn.custom_minimum_size = Vector2(240, 52)
	ok_btn.pressed.connect(func():
		AudioManager.play_sfx("click")
		# Equip Sir Crown as the active avatar
		var prof = GameState.get_active_profile()
		if not prof.is_empty():
			prof["avatar"] = "sircrown"
			GameState.save_game()
			GameState.emit_signal("stats_updated")
		if _thank_you_modal and is_instance_valid(_thank_you_modal):
			var close_tw = _thank_you_modal.create_tween()
			close_tw.tween_property(_thank_you_modal, "modulate:a", 0.0, 0.18)
			close_tw.finished.connect(func():
				if _thank_you_modal and is_instance_valid(_thank_you_modal):
					_thank_you_modal.queue_free()
					_thank_you_modal = null
			)
	)
	btn_center.add_child(ok_btn)
	
	# Spawn Confetti and Coin Burst Animation
	_spawn_confetti_burst(_thank_you_modal, safe_sz)
	
	# Entrance pop-in animation
	card.pivot_offset = card.size * 0.5
	card.scale = Vector2(0.80, 0.80)
	card.modulate.a = 0.0
	var enter_tw = card.create_tween().set_parallel(true)
	enter_tw.tween_property(card, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	enter_tw.tween_property(card, "modulate:a", 1.0, 0.20)

func _create_reward_badge(icon_path: String, text: String, color: Color) -> PanelContainer:
	var badge = PanelContainer.new()
	var st = UIHelper.create_bubbly_panel(18, Color(0.96, 0.98, 1.0), color, 2)
	badge.add_theme_stylebox_override("panel", st)
	badge.custom_minimum_size = Vector2(130, 42)
	
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 6)
	hbox.offset_left = 8
	hbox.offset_right = -8
	badge.add_child(hbox)
	
	var icon = TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(24, 24)
	icon.texture = UIHelper.load_texture_safe(icon_path)
	hbox.add_child(icon)
	
	var lbl = Label.new()
	lbl.text = text
	UIHelper.apply_bubbly_label(lbl, 14, color, true)
	hbox.add_child(lbl)
	
	return badge

func _spawn_confetti_burst(parent: Control, safe_sz: Vector2):
	var coin_tex = UIHelper.load_texture_safe("res://assets/images/congratulations/gold_tooth_coin.png")
	var star_tex = UIHelper.load_texture_safe("res://assets/images/congratulations/purple_star_points.png")
	var colors = [Color("#ff3366"), Color("#ffd23f"), Color("#33dd88"), Color("#33b5ff"), Color("#b044ff"), Color("#ff8833")]
	
	var burst_layer = Control.new()
	burst_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	burst_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	burst_layer.z_index = 60
	parent.add_child(burst_layer)
	
	var center = safe_sz * 0.5
	for i in range(40):
		var node: Control
		var roll = i % 4
		if roll == 0 and coin_tex:
			var tr = TextureRect.new()
			tr.texture = coin_tex
			tr.custom_minimum_size = Vector2(24, 24)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			node = tr
		elif roll == 1 and star_tex:
			var tr = TextureRect.new()
			tr.texture = star_tex
			tr.custom_minimum_size = Vector2(24, 24)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			node = tr
		else:
			var cr = ColorRect.new()
			cr.color = colors[randi() % colors.size()]
			cr.custom_minimum_size = Vector2(10, 10)
			node = cr
			
		node.position = center
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		burst_layer.add_child(node)
		
		var angle = randf_range(0, TAU)
		var dist = randf_range(120.0, max(safe_sz.x, safe_sz.y) * 0.60)
		var dest = center + Vector2(cos(angle) * dist, sin(angle) * dist + randf_range(20, 120))
		var dur = randf_range(1.2, 2.0)
		
		var tw = node.create_tween()
		tw.parallel().tween_property(node, "position", dest, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(node, "modulate:a", 0.0, dur * 0.5).set_delay(dur * 0.5)
		tw.finished.connect(func(): if is_instance_valid(node): node.queue_free())
