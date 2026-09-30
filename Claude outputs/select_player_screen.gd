# scripts/select_player_screen.gd
extends Control

signal player_chosen(id: String)
signal manage_players_requested

var current_profile_id: String = ""

func _ready():
	anchors_preset = Control.PRESET_FULL_RECT
	anchor_right = 1.0
	anchor_bottom = 1.0

	_build_ui()

func _build_ui():
	# Main container
	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.anchor_right = 1.0
	main_vbox.anchor_bottom = 1.0
	main_vbox.offset_left = 0
	main_vbox.offset_top = 0
	main_vbox.offset_right = 0
	main_vbox.offset_bottom = 0
	main_vbox.separation = 16
	add_child(main_vbox)

	# Title
	var title_lbl = Label.new()
	title_lbl.text = "Who is playing?"
	title_lbl.add_theme_font_size_override("font_size", 28)
	title_lbl.add_theme_color_override("font_color", UIHelper.DEEP_BLUE)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.custom_minimum_size = Vector2(0, 60)
	main_vbox.add_child(title_lbl)

	# Players grid container (NO SCROLL - use FlowContainer for wrapping)
	var flow_container = FlowContainer.new()
	flow_container.alignment = FlowContainer.ALIGNMENT_CENTER
	flow_container.custom_minimum_size = Vector2(0, 300)
	flow_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(flow_container)

	# Build player buttons
	var profiles = GameState.profiles
	for profile in profiles:
		var player_id = profile.get("id", "")
		var player_name = profile.get("name", "Unknown")
		var avatar_id = profile.get("avatar", "chip")

		var player_btn = _create_player_button(player_id, player_name, avatar_id)
		flow_container.add_child(player_btn)

	# Manage Players button at bottom
	var bottom_hbox = HBoxContainer.new()
	bottom_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_hbox.custom_minimum_size = Vector2(0, 60)
	main_vbox.add_child(bottom_hbox)

	var manage_btn = UIHelper.create_bubbly_button("Manage Players", UIHelper.SKY_BLUE)
	manage_btn.custom_minimum_size = Vector2(200, 44)
	manage_btn.pressed.connect(func():
		AudioManager.play_sfx("click")
		manage_players_requested.emit()
	)
	bottom_hbox.add_child(manage_btn)

func _create_player_button(player_id: String, player_name: String, avatar_id: String) -> Control:
	var container = VBoxContainer.new()
	container.custom_minimum_size = Vector2(110, 140)
	container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	# Avatar frame
	var avatar_frame = PanelContainer.new()
	avatar_frame.custom_minimum_size = Vector2(100, 100)
	var frame_style = UIHelper.create_bubbly_panel(16, Color.WHITE, UIHelper.SKY_BLUE, 2)
	avatar_frame.add_theme_stylebox_override("panel", frame_style)
	container.add_child(avatar_frame)

	# Avatar texture
	var avatar_tex = TextureRect.new()
	avatar_tex.texture = UIHelper.get_char_texture(avatar_id, false)
	avatar_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	avatar_tex.custom_minimum_size = Vector2(80, 80)
	avatar_frame.add_child(avatar_tex)

	# Player name label
	var name_lbl = Label.new()
	name_lbl.text = player_name
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", UIHelper.DEEP_BLUE)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.custom_minimum_size = Vector2(110, 40)
	name_lbl.clip_text = true
	container.add_child(name_lbl)

	# Click handler
	avatar_frame.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
			AudioManager.play_sfx("click")
			player_chosen.emit(player_id)
	)

	return container
