# scripts/toast_overlay.gd
extends Control

var toast_panel: PanelContainer
var icon_label: Label
var title_label: Label
var body_label: Label

var hide_timer: Timer
var next_timer: Timer
var is_showing_toast: bool = false

func _ready():
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchors_preset = Control.PRESET_FULL_RECT
	anchor_right = 1.0
	anchor_bottom = 1.0

func _build_ui():
	pass

func _on_toast_pushed(_toast: Dictionary):
	pass

func start_draining_queue():
	# Top notifications disabled per user request
	var p = GameState.get_active_profile()
	if not p.is_empty() and p.has("queued_notifications"):
		p["queued_notifications"] = []
	dismiss()

func _drain_next():
	pass

func _show_toast_dict(_toast: Dictionary):
	pass

func dismiss():
	is_showing_toast = false
	if toast_panel:
		toast_panel.visible = false

func _hide_toast():
	is_showing_toast = false
	if toast_panel:
		toast_panel.visible = false


