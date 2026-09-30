# scripts/privacy_policy_screen.gd
# Full-page Privacy Policy / consent screen. Shown once, after the player taps
# "Start Brushing" on the home page and before they create their first player.
extends Control

signal agreed

const BODY_COLOR := Color(0.17, 0.30, 0.49)

var bg: TextureRect
var center: CenterContainer
var center_vbox: VBoxContainer
var title_lbl: Label
var sub_lbl: Label
var card: PanelContainer
var scroll: ScrollContainer
var text_lbl: RichTextLabel
var check_row: HBoxContainer
var agree_checkbox: CheckBox
var agree_lbl: Label
var agree_btn: BaseButton
var _busy := false

func _ready():
	set_anchors_preset(Control.PRESET_FULL_RECT)
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_right = 0
	offset_bottom = 0
	_build_ui()
	_relayout()

func _notification(what):
	if what == NOTIFICATION_RESIZED:
		if is_node_ready():
			_relayout()

func _build_ui():
	bg = UIHelper.setup_clean_bubbly_bg(self)

	center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	center.offset_right = 0
	center.offset_bottom = 0
	add_child(center)

	center_vbox = VBoxContainer.new()
	center_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center_vbox.add_theme_constant_override("separation", 12)
	center.add_child(center_vbox)

	# Title sits directly on the sky background, so it is white with a dark blue shadow (easy to read)
	title_lbl = Label.new()
	title_lbl.text = "PRIVACY POLICY"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(title_lbl, 38, Color.WHITE, true)
	title_lbl.add_theme_color_override("font_shadow_color", Color(0.10, 0.32, 0.62))
	title_lbl.add_theme_constant_override("shadow_offset_x", 2)
	title_lbl.add_theme_constant_override("shadow_offset_y", 3)
	title_lbl.add_theme_color_override("font_outline_color", Color(0.10, 0.32, 0.62))
	title_lbl.add_theme_constant_override("outline_size", 6)
	center_vbox.add_child(title_lbl)

	sub_lbl = Label.new()
	sub_lbl.text = "Please read this before you play"
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(sub_lbl, 16, Color(0.95, 0.98, 1.0), true)
	sub_lbl.add_theme_color_override("font_shadow_color", Color(0.10, 0.32, 0.62, 0.9))
	sub_lbl.add_theme_constant_override("shadow_offset_x", 1)
	sub_lbl.add_theme_constant_override("shadow_offset_y", 2)
	center_vbox.add_child(sub_lbl)

	card = PanelContainer.new()
	var card_style = UIHelper.create_bubbly_panel(28, Color.WHITE, Color(0.32, 0.68, 0.98), 4)
	card_style.content_margin_left = 16
	card_style.content_margin_right = 16
	card_style.content_margin_top = 14
	card_style.content_margin_bottom = 14
	card.add_theme_stylebox_override("panel", card_style)
	center_vbox.add_child(card)

	scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card.add_child(scroll)

	text_lbl = RichTextLabel.new()
	text_lbl.bbcode_enabled = true
	text_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_lbl.scroll_active = false
	text_lbl.fit_content = true
	# Default text colour: paragraphs without an explicit [color] tag used to render white-on-white
	text_lbl.add_theme_color_override("default_color", BODY_COLOR)
	text_lbl.text = _get_privacy_policy_text()
	scroll.add_child(text_lbl)

	# Tick box + agreement text (tapping the text also toggles the box)
	check_row = HBoxContainer.new()
	check_row.alignment = BoxContainer.ALIGNMENT_CENTER
	check_row.add_theme_constant_override("separation", 10)
	center_vbox.add_child(check_row)

	agree_checkbox = CheckBox.new()
	agree_checkbox.custom_minimum_size = Vector2(40, 40)
	agree_checkbox.focus_mode = Control.FOCUS_NONE
	agree_checkbox.toggled.connect(func(_on: bool): _refresh_agree_btn())
	check_row.add_child(agree_checkbox)

	agree_lbl = Label.new()
	agree_lbl.text = "I have read and agree to the Terms & Conditions and Privacy Policy"
	agree_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	agree_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	agree_lbl.mouse_filter = Control.MOUSE_FILTER_STOP
	UIHelper.apply_bubbly_label(agree_lbl, 15, Color.WHITE, true)
	agree_lbl.add_theme_color_override("font_shadow_color", Color(0.10, 0.32, 0.62, 0.9))
	agree_lbl.add_theme_constant_override("shadow_offset_x", 1)
	agree_lbl.add_theme_constant_override("shadow_offset_y", 2)
	agree_lbl.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			agree_checkbox.button_pressed = not agree_checkbox.button_pressed
	)
	check_row.add_child(agree_lbl)

	agree_btn = UIHelper.create_bubbly_button("I AGREE & CONTINUE", UIHelper.VIBRANT_GREEN)
	agree_btn.custom_minimum_size = Vector2(240, 56)
	agree_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	agree_btn.pressed.connect(_on_agree_pressed)
	center_vbox.add_child(agree_btn)
	_refresh_agree_btn()

func _relayout():
	if not center_vbox:
		return
	var safe_sz = UIHelper.get_viewport_safe_size(self)
	var is_tablet = safe_sz.x >= 600.0
	var col_w = clampf(safe_sz.x - 32.0, 290.0, 640.0 if is_tablet else 460.0)
	# Leave room for title, tick row and button; the policy card takes the rest
	var card_h = clampf(safe_sz.y - 300.0, 240.0, 620.0)

	center_vbox.custom_minimum_size = Vector2(col_w, 0)
	card.custom_minimum_size = Vector2(col_w, card_h)
	check_row.custom_minimum_size = Vector2(col_w, 0)
	agree_lbl.custom_minimum_size = Vector2(col_w - 60.0, 0)
	if title_lbl:
		title_lbl.add_theme_font_size_override("font_size", 42 if is_tablet else 36)

func _refresh_agree_btn():
	if agree_btn:
		agree_btn.modulate = Color(1, 1, 1, 1.0) if agree_checkbox.button_pressed else Color(1, 1, 1, 0.55)

func _on_agree_pressed():
	if _busy:
		return
	if not agree_checkbox.button_pressed:
		AudioManager.play_sfx("error")
		# Nudge: flash the tick row so it is obvious what is missing
		var tw = create_tween()
		tw.tween_property(check_row, "modulate", Color(1.0, 0.55, 0.55), 0.12)
		tw.tween_property(check_row, "modulate", Color.WHITE, 0.25)
		return
	_busy = true
	GameState.privacy_policy_agreed = true
	GameState.save_game()
	AudioManager.play_sfx("pop")
	agreed.emit()

func _get_privacy_policy_text() -> String:
	return """[color=#153866][b]PRIVACY POLICY & DATA PROTECTION[/b][/color]

[color=#1eb038][b]1. Overview[/b][/color]
Pearly Whites Challenge deeply values player privacy and safety. This application is built from the ground up to comply fully with COPPA (Children's Online Privacy Protection Act), GDPR-K, and Apple App Store / Google Play Kids Category guidelines.

[color=#1eb038][b]2. Data Collection & Usage[/b][/color]
• We only collect anonymous gameplay metrics, daily brushing completion timestamps, and quiz streaks required to track your 28-day challenge journey.
• We DO NOT collect player names, personal email addresses, phone numbers, precise location data, or unique advertising identifiers (IDFA/GAID).

[color=#1eb038][b]3. Camera Usage & On-Device Vision[/b][/color]
• The camera is accessed strictly in real time on your device to detect toothbrush presence for daily habit check verification.
• Video feeds and camera frames are processed 100% locally on device.
• Camera feeds are NEVER recorded, NEVER stored, and NEVER transmitted over any network.

[color=#1eb038][b]4. Cloud Storage & Synchronization[/b][/color]
• Challenge progress and streak counters are synchronized anonymously using Firebase Cloud Firestore.
• Anonymous authentication tokens are generated locally without requesting personal credentials.

[color=#1eb038][b]5. Data Deletion & Player Rights[/b][/color]
• Players and parents can permanently wipe all cloud and local progress at any time via the in-game 'Reset Progress & Delete Cloud Data' button in Settings -> Tooth Fairy Parental Portal.
• Wiping progress immediately purges all server records and resets local state.

[color=#1eb038][b]6. Official Policy Reference[/b][/color]
Parents and guardians can review our official online privacy policy at any time at:
[b]pearlywhitessaga.com/games/pwc/privacy-policy[/b]

For support inquiries or data privacy questions, contact us at:
[b]game@pearlywhitessaga.com[/b]"""
