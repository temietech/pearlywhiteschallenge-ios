# scripts/parental_gate_modal.gd
# Apple Kids Category parental gate (Guidelines 1.3 / 5.1.4).
# Usage:
#   ParentalGateModal.show_gate(self, func(): TipManager.purchase_tip("tip_small"))
class_name ParentalGateModal
extends Control

signal verified(success: bool)

const SCENE_PATH := "res://scenes/ui/ParentalGateModal.tscn"   # ADAPT if your folder differs
const CONFIRM_BTN_TEX := "res://assets/images/buttons/confirmbtn.png"
const GROUP := "parental_gate_modal"
const MAX_ATTEMPTS := 3
const CARD_H := 340.0

# Set to false if you only want math challenges (harder for young kids to pass).
const USE_WORD_CHALLENGES := true

const REVERSE_WORDS := ["NINE", "SEVEN", "SMILE", "TOOTH", "BRUSH", "PEARL"]
const PHRASES := ["Pearly Whites", "Brush Daily", "Happy Teeth", "Shiny Smile", "Floss Often"]

enum Challenge { MULTIPLY, ADD, REVERSE, SECOND_WORD }

var overlay: ColorRect
var center: CenterContainer
var card: Panel
var vbox: VBoxContainer
var title_lbl: Label
var question_lbl: Label
var answer_input: LineEdit
var err_lbl: Label
var submit_btn: BaseButton
var cancel_btn: BaseButton
var close_btn: BaseButton

var on_success_callback: Callable
var on_cancel_callback: Callable
var title_text := "GROWN-UPS ONLY"
# Hard mode: multi-step maths only (no word puzzles) so young children can't guess their way through.
var hard_mode := false

var _expected := ""
var _last_type := -1
var _attempts_left := MAX_ATTEMPTS
var _closing := false
var _rng := RandomNumberGenerator.new()

# ------------------------------------------------------------------
# Public API
# ------------------------------------------------------------------
static func show_gate(parent_node: Node, on_success: Callable, on_cancel: Callable = Callable(), title_override: String = "GROWN-UPS ONLY", hard: bool = false) -> ParentalGateModal:
	if parent_node == null or not parent_node.is_inside_tree():
		if on_cancel.is_valid():
			on_cancel.call_deferred()
		return null

	var tree := parent_node.get_tree()

	# Prevent stacking (e.g. double-tap on the tip button).
	var existing := tree.get_first_node_in_group(GROUP)
	if existing and is_instance_valid(existing):
		return existing as ParentalGateModal

	var instance: ParentalGateModal
	if ResourceLoader.exists(SCENE_PATH):
		instance = load(SCENE_PATH).instantiate() as ParentalGateModal
	if instance == null:
		instance = ParentalGateModal.new()

	instance.on_success_callback = on_success
	instance.on_cancel_callback = on_cancel
	instance.title_text = title_override if title_override != "" else "GROWN-UPS ONLY"
	instance.hard_mode = hard

	_find_host(parent_node).add_child(instance)
	return instance

static func _find_host(node: Node) -> Node:
	var tree := node.get_tree()
	var main_node := tree.root.get_node_or_null("Main")
	if main_node and is_instance_valid(main_node):
		return main_node
	return tree.current_scene if tree.current_scene else tree.root

# ------------------------------------------------------------------
# Lifecycle
# ------------------------------------------------------------------
func _ready() -> void:
	add_to_group(GROUP)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = 300
	mouse_filter = Control.MOUSE_FILTER_STOP
	_rng.randomize()

	_build_ui()
	_relayout()
	get_viewport().size_changed.connect(_relayout)

	_new_challenge()
	_play_open_anim()
	answer_input.grab_focus.call_deferred()

func _process(_delta: float) -> void:
	# Lift the card above the iOS/Android on-screen keyboard.
	if center == null or _closing:
		return
	var kb_px := float(DisplayServer.virtual_keyboard_get_height())
	var target := 0.0
	if kb_px > 0.0:
		var s := get_viewport().get_final_transform().get_scale().y
		if s > 0.0:
			target = -(kb_px / s) * 0.9
	center.offset_bottom = lerpf(center.offset_bottom, target, 0.25)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_cancel_pressed()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:   # Android back button
		_on_cancel_pressed()

# ------------------------------------------------------------------
# UI
# ------------------------------------------------------------------
func _build_ui() -> void:
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
	card.add_theme_stylebox_override("panel", UIHelper.create_bubbly_panel(28, Color.WHITE, Color(0.35, 0.72, 0.96), 4))
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(card)

	close_btn = UIHelper.create_close_button(Vector2(32, 32))
	close_btn.pressed.connect(_on_cancel_pressed)
	card.add_child(close_btn)

	vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 18
	vbox.offset_right = -18
	vbox.offset_top = 22
	vbox.offset_bottom = -18
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 10)
	card.add_child(vbox)

	title_lbl = Label.new()
	title_lbl.text = title_text
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIHelper.apply_bubbly_label(title_lbl, 18, UIHelper.DEEP_BLUE, true)
	vbox.add_child(title_lbl)

	question_lbl = Label.new()
	question_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	question_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UIHelper.apply_bubbly_label(question_lbl, 14, Color(0.18, 0.42, 0.70), true)
	vbox.add_child(question_lbl)

	answer_input = LineEdit.new()
	answer_input.placeholder_text = "Your answer..."
	answer_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	answer_input.custom_minimum_size = Vector2(0, 44)
	var in_st := UIHelper.create_bubbly_panel(20, Color(0.94, 0.97, 1.0), Color(0.80, 0.88, 0.98), 2)
	in_st.content_margin_left = 10
	in_st.content_margin_right = 10
	answer_input.add_theme_stylebox_override("normal", in_st)
	answer_input.add_theme_color_override("font_color", Color(0.10, 0.15, 0.30))
	answer_input.add_theme_color_override("font_placeholder_color", Color(0.20, 0.40, 0.65, 0.70))
	answer_input.text_submitted.connect(func(_t: String): _on_submit_pressed())
	vbox.add_child(answer_input)

	err_lbl = Label.new()
	err_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	err_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UIHelper.apply_bubbly_label(err_lbl, 11, Color(0.92, 0.25, 0.20), true)
	err_lbl.visible = false
	vbox.add_child(err_lbl)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	vbox.add_child(row)

	var cancel_tex := UIHelper.create_themed_button("cancel", Vector2(120, 44))
	if cancel_tex.texture_normal:
		cancel_btn = cancel_tex
	else:
		var b := UIHelper.create_bubbly_button("CANCEL", UIHelper.VIBRANT_RED)
		b.custom_minimum_size = Vector2(120, 44)
		cancel_btn = b
	cancel_btn.pressed.connect(_on_cancel_pressed)
	row.add_child(cancel_btn)

	var confirm_tex := UIHelper.create_image_button(CONFIRM_BTN_TEX, Vector2(140, 44))
	if confirm_tex.texture_normal:
		submit_btn = confirm_tex
	else:
		var b2 := UIHelper.create_bubbly_button("CONFIRM", UIHelper.VIBRANT_GREEN)
		b2.custom_minimum_size = Vector2(140, 44)
		submit_btn = b2
	submit_btn.pressed.connect(_on_submit_pressed)
	row.add_child(submit_btn)

func _relayout() -> void:
	if card == null:
		return
	var safe_sz := UIHelper.get_viewport_safe_size(self)
	var card_w := clampf(safe_sz.x - 40.0, 300.0, 380.0)
	card.custom_minimum_size = Vector2(card_w, CARD_H)
	card.size = Vector2(card_w, CARD_H)
	card.pivot_offset = card.size * 0.5
	close_btn.position = Vector2(card_w - 40.0, 10.0)

func _play_open_anim() -> void:
	overlay.modulate.a = 0.0
	card.scale = Vector2(0.85, 0.85)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(overlay, "modulate:a", 1.0, 0.18)
	tw.tween_property(card, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# ------------------------------------------------------------------
# Challenges
# ------------------------------------------------------------------
func _new_hard_challenge() -> void:
	# Multi-step arithmetic that a young child can't solve by guessing or simple times tables.
	var t: int = _rng.randi_range(0, 2)
	while t == _last_type:
		t = _rng.randi_range(0, 2)
	_last_type = t
	match t:
		0:
			var a := _rng.randi_range(14, 29)
			var b := _rng.randi_range(11, 19)
			var c := _rng.randi_range(6, 9)
			question_lbl.text = "What is (%d + %d) x %d?" % [a, b, c]
			_expected = str((a + b) * c)
		1:
			var a := _rng.randi_range(13, 19)
			var b := _rng.randi_range(6, 9)
			var c := _rng.randi_range(15, 49)
			question_lbl.text = "What is %d x %d + %d?" % [a, b, c]
			_expected = str(a * b + c)
		_:
			var a := _rng.randi_range(12, 19)
			var b := _rng.randi_range(7, 9)
			var c := _rng.randi_range(11, 39)
			question_lbl.text = "What is %d x %d - %d?" % [a, b, c]
			_expected = str(a * b - c)
	answer_input.text = ""

func _new_challenge() -> void:
	if hard_mode:
		_new_hard_challenge()
		return
	var types := [Challenge.MULTIPLY, Challenge.ADD]
	if USE_WORD_CHALLENGES:
		types.append_array([Challenge.REVERSE, Challenge.SECOND_WORD])
	var t: int = types[_rng.randi_range(0, types.size() - 1)]
	if types.size() > 1:
		while t == _last_type:
			t = types[_rng.randi_range(0, types.size() - 1)]
	_last_type = t

	match t:
		Challenge.MULTIPLY:
			var a := _rng.randi_range(6, 9)
			var b := _rng.randi_range(6, 9)
			question_lbl.text = "What is %d x %d?" % [a, b]
			_expected = str(a * b)
		Challenge.ADD:
			var a := _rng.randi_range(12, 29)
			var b := _rng.randi_range(12, 29)
			question_lbl.text = "What is %d + %d?" % [a, b]
			_expected = str(a + b)
		Challenge.REVERSE:
			var w: String = REVERSE_WORDS[_rng.randi_range(0, REVERSE_WORDS.size() - 1)]
			question_lbl.text = "Type the word %s backwards" % w
			_expected = w.reverse().to_lower()
		_:
			var p: String = PHRASES[_rng.randi_range(0, PHRASES.size() - 1)]
			question_lbl.text = "Type the second word of: %s" % p
			_expected = p.split(" ")[1].to_lower()
	answer_input.text = ""

func _on_submit_pressed() -> void:
	if _closing:
		return
	var answer := answer_input.text.strip_edges().to_lower()
	if answer == _expected:
		AudioManager.play_sfx("pop")
		verified.emit(true)
		_close(on_success_callback)
		return
	AudioManager.play_sfx("error")
	_attempts_left -= 1
	if _attempts_left <= 0:
		_on_cancel_pressed()
		return
	err_lbl.text = "Not quite. Try this one (%d tries left)." % _attempts_left
	err_lbl.visible = true
	_new_challenge()

func _on_cancel_pressed() -> void:
	if _closing:
		return
	AudioManager.play_sfx("click")
	verified.emit(false)
	_close(on_cancel_callback)

func _close(cb: Callable) -> void:
	_closing = true
	var tw := create_tween().set_parallel(true)
	tw.tween_property(overlay, "modulate:a", 0.0, 0.15)
	tw.tween_property(card, "scale", Vector2(0.85, 0.85), 0.15)
	tw.finished.connect(func():
		queue_free()
		if cb.is_valid():
			cb.call()
	)
