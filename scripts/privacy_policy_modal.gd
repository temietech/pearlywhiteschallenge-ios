# scripts/privacy_policy_modal.gd
extends Control

signal closed
signal agreed

var overlay: ColorRect
var center: CenterContainer
var card: Panel
var title_lbl: Label
var scroll: ScrollContainer
var text_lbl: RichTextLabel
var close_btn: TextureButton
var bottom_close_btn: BaseButton
var agree_checkbox: CheckBox
var agree_lbl: Label

func _ready():
	set_anchors_preset(Control.PRESET_FULL_RECT)
	anchor_right = 1.0
	anchor_bottom = 1.0
	z_index = 280
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	_relayout()
	
static func show_modal(parent_node: Node) -> Control:
	if not parent_node:
		return null
	var target_parent: Node = parent_node
	if parent_node.is_inside_tree():
		var main_node = parent_node.get_tree().root.get_node_or_null("Main")
		if main_node and is_instance_valid(main_node):
			target_parent = main_node
			
	var modal_script = load("res://scripts/privacy_policy_modal.gd")
	var instance = modal_script.new()
	target_parent.add_child(instance)
	return instance

func _build_ui():
	overlay = ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.04, 0.08, 0.20, 0.88)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	
	center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	
	card = Panel.new()
	var card_style = UIHelper.create_bubbly_panel(28, Color.WHITE, Color(0.32, 0.68, 0.98), 4)
	card.add_theme_stylebox_override("panel", card_style)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(card)
	
	close_btn = UIHelper.create_close_button(Vector2(32, 32))
	close_btn.pressed.connect(_on_close_pressed)
	card.add_child(close_btn)
	
	var vbox = VBoxContainer.new()
	vbox.name = "ModalVBox"
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 18
	vbox.offset_right = -18
	vbox.offset_top = 18
	vbox.offset_bottom = -18
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 10)
	card.add_child(vbox)
	
	title_lbl = Label.new()
	title_lbl.text = "PRIVACY POLICY"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(title_lbl, 20, UIHelper.DEEP_BLUE, true)
	vbox.add_child(title_lbl)
	
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var sc_st = UIHelper.create_bubbly_panel(16, Color(0.95, 0.97, 1.0), Color(0.80, 0.90, 0.98), 1)
	sc_st.content_margin_left = 14
	sc_st.content_margin_right = 14
	sc_st.content_margin_top = 12
	sc_st.content_margin_bottom = 12
	scroll.add_theme_stylebox_override("panel", sc_st)
	vbox.add_child(scroll)
	
	text_lbl = RichTextLabel.new()
	text_lbl.bbcode_enabled = true
	text_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_lbl.scroll_active = false
	text_lbl.fit_content = true
	text_lbl.text = _get_privacy_policy_text()
	scroll.add_child(text_lbl)

	# Agree Checkbox & Label
	var checkbox_hbox = HBoxContainer.new()
	checkbox_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(checkbox_hbox)

	agree_checkbox = CheckBox.new()
	agree_checkbox.button_pressed = false
	agree_checkbox.custom_minimum_size = Vector2(28, 28)
	checkbox_hbox.add_child(agree_checkbox)

	agree_lbl = Label.new()
	agree_lbl.text = "I have read and agree to this Privacy Policy"
	agree_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	agree_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(agree_lbl, 14, UIHelper.DEEP_BLUE, false)
	agree_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	checkbox_hbox.add_child(agree_lbl)

	var agree_btn := UIHelper.create_bubbly_button("I AGREE & CONTINUE", UIHelper.VIBRANT_GREEN)
	agree_btn.custom_minimum_size = Vector2(160, 44)
	agree_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	agree_btn.pressed.connect(_on_agree_pressed)
	vbox.add_child(agree_btn)
	bottom_close_btn = agree_btn

func _relayout():
	var safe_sz = UIHelper.get_viewport_safe_size(self)
	var card_w = clampf(safe_sz.x - 36.0, 310.0, 480.0)
	var card_h = clampf(safe_sz.y - 40.0, 420.0, 560.0)
	
	card.custom_minimum_size = Vector2(card_w, card_h)
	card.size = Vector2(card_w, card_h)
	close_btn.position = Vector2(card_w - 38.0, 10.0)

func _get_privacy_policy_text() -> String:
	return """[color=#153866][b]PRIVACY POLICY & DATA PROTECTION[/b][/color]

[color=#1eb038][b]1. Overview[/b][/color]
Pearly Whites Challenge deeply values player privacy and safety. This application is built from the ground up to comply fully with COPPA (Children's Online Privacy Protection Act), GDPR-K, and Apple App Store / Google Play Kids Category guidelines.

[color=#1eb038][b]2. Data Collection & Usage[/b][/color]
[color=#2b4c7e]• We only collect anonymous gameplay metrics, daily brushing completion timestamps, and quiz streaks required to track your 28-day challenge journey.
• We DO NOT collect player names, personal email addresses, phone numbers, precise location data, or unique advertising identifiers (IDFA/GAID).[/color]

[color=#1eb038][b]3. Camera Usage & On-Device Vision[/b][/color]
[color=#2b4c7e]• The camera is accessed strictly in real time on your device to detect toothbrush presence for daily habit check verification.
• Video feeds and camera frames are processed 100% locally on device.
• Camera feeds are NEVER recorded, NEVER stored, and NEVER transmitted over any network.[/color]

[color=#1eb038][b]4. Cloud Storage & Synchronization[/b][/color]
[color=#2b4c7e]• Challenge progress and streak counters are synchronized anonymously using Firebase Cloud Firestore.
• Anonymous authentication tokens are generated locally without requesting personal credentials.[/color]

[color=#1eb038][b]5. Data Deletion & Player Rights[/b][/color]
[color=#2b4c7e]• Players and parents can permanently wipe all cloud and local progress at any time via the in-game 'Reset Progress & Delete Cloud Data' button in Settings -> Tooth Fairy Parental Portal.
• Wiping progress immediately purges all server records and resets local state.[/color]

[color=#1eb038][b]6. Official Policy Reference[/b][/color]
[color=#2b4c7e]Parents and guardians can review our official online privacy policy at any time at:
[b]pearlywhitessaga.com/games/pwc/privacy-policy[/b]

For support inquiries or data privacy questions, contact us at:
[b]game@pearlywhitessaga.com[/b][/color]"""

func _on_agree_pressed():
	if not agree_checkbox.button_pressed:
		AudioManager.play_sfx("error")
		# Brief flash to draw attention to checkbox
		var tw = create_tween()
		tw.tween_callback(func(): agree_checkbox.modulate = Color(1.2, 0.8, 0.8))
		tw.tween_callback(func(): agree_checkbox.modulate = Color.WHITE).set_delay(0.3)
		return

	# Mark privacy policy as agreed
	GameState.privacy_policy_agreed = true
	GameState.save_game()

	AudioManager.play_sfx("pop")
	var tw = create_tween().set_parallel(true)
	tw.tween_property(card, "scale", Vector2(0.85, 0.85), 0.15)
	tw.tween_property(overlay, "modulate:a", 0.0, 0.15)
	tw.finished.connect(func():
		agreed.emit()
		closed.emit()
		queue_free()
	)

func _on_close_pressed():
	AudioManager.play_sfx("click")
	var tw = create_tween().set_parallel(true)
	tw.tween_property(card, "scale", Vector2(0.85, 0.85), 0.15)
	tw.tween_property(overlay, "modulate:a", 0.0, 0.15)
	tw.finished.connect(func():
		closed.emit()
		queue_free()
	)
