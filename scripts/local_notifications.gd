# scripts/local_notifications.gd
# Autoload: "LocalNotifications"
#
# Schedules the approved iPhone reminders as LOCAL notifications (they fire even when the
# app is closed). iOS can't run our code while the app is closed, so every message is
# scheduled in advance. We cancel + rebuild the whole schedule whenever the app opens,
# goes to the background, or the player finishes something, so the texts always match
# the latest state (streak, character, Candy Crusade day, missed days).
#
# Needs the "iOS Notification Scheduler" plugin (addons/ + iOS export plugin ticked).
# Without the plugin (editor, desktop, Android) every call is a harmless no-op.

extends Node

const SETTINGS_PATH := "user://notification_settings.cfg"

# Local times (24h) for each reminder
const MORNING_HOUR := 7
const MORNING_MIN := 0
const EVENING_HOUR := 19
const EVENING_MIN := 0
const STREAK_KEEP_HOUR := 12
const STREAK_KEEP_MIN := 30
const STREAK_LOSS_HOUR := 21
const STREAK_LOSS_MIN := 0
const CRUSADE_HOUR := 16
const CRUSADE_MIN := 0
const REWARD_HOUR := 7
const REWARD_MIN := 30
const TRAP_HOUR := 9
const TRAP_MIN := 30

const REMINDER_DAYS_AHEAD := 5     # brushing reminders scheduled this many days ahead
const CRUSADE_DAYS_AHEAD := 3
const TRAP_NUDGES := 3             # "stuck in a candy trap" reminders, then we stop nagging
const ID_BLOCK := 10               # notification ids = day_offset * 10 + slot
const MAX_DAYS_TO_CANCEL := 14

enum Slot { MORNING = 0, EVENING = 1, STREAK_KEEP = 2, STREAK_LOSS = 3, CRUSADE = 4, TRAP = 5, REWARD = 6 }

var enabled: bool = true
var _plugin: Object = null
var _plugin_ready: bool = false
var _permission_granted: bool = false
var _permission_requested: bool = false
var _data_class: Object = null   # the plugin's NotificationData script


func _ready() -> void:
	_load_settings()
	_init_plugin()
	# Rebuild the schedule shortly after boot (GameState has loaded the profile by then)
	get_tree().create_timer(1.5).timeout.connect(refresh)


func _notification(what: int) -> void:
	# Going to the background is the most accurate moment to (re)build the schedule
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		refresh()
	elif what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		refresh()


# ----------------------------------------------------------------------
# Public API
# ----------------------------------------------------------------------
func is_supported() -> bool:
	return _plugin != null


func set_enabled(value: bool) -> void:
	enabled = value
	_save_settings()
	if enabled:
		request_permission()
	refresh()


## Shows the iOS "Allow notifications?" prompt (only the first time; iOS remembers the answer).
## Call this at a friendly moment: settings toggle, or after the first finished brush.
func request_permission() -> void:
	if _plugin == null or _permission_requested:
		return
	_permission_requested = true
	if _plugin.has_method("has_post_notifications_permission") and _plugin.call("has_post_notifications_permission"):
		_permission_granted = true
		refresh()
		return
	if _plugin.has_method("request_post_notifications_permission"):
		_plugin.call("request_post_notifications_permission")


## Cancels everything we scheduled and schedules it again from the current game state.
func refresh() -> void:
	if _plugin == null or not _plugin_ready:
		return
	_cancel_all()
	if not enabled:
		return
	if _plugin.has_method("has_post_notifications_permission"):
		_permission_granted = bool(_plugin.call("has_post_notifications_permission"))
	if not _permission_granted:
		return
	var p: Dictionary = GameState.get_active_profile()
	if p.is_empty():
		return
	# Nothing until the player has actually started (prologue seen)
	if not bool(p.get("prologue_seen", false)) and int(p.get("currentNode", 0)) <= 0:
		return
	_schedule_all(p)


# ----------------------------------------------------------------------
# Schedule builder
# ----------------------------------------------------------------------
func _schedule_all(p: Dictionary) -> void:
	var name_str := _character_name(p)
	var streak := int(round(float(p.get("streak", 0))))
	var today := Time.get_date_string_from_system()
	var brushed_today: bool = str(p.get("lastBrushDate", "")) == today
	var evening_done_today: bool = str(p.get("lastEveningBrushDate", "")) == today
	var cur_node := int(p.get("currentNode", 1))
	var cur_day: int = GameState.day_for_node(cur_node)
	var morning_done_today := false
	if cur_day >= 1 and cur_day <= 28:
		morning_done_today = brushed_today and GameState.is_day_morning_brush_done(cur_day, p)

	# 1) Brushing time - twice a day
	for d in range(0, REMINDER_DAYS_AHEAD + 1):
		if not (d == 0 and morning_done_today):
			_schedule(d, Slot.MORNING, MORNING_HOUR, MORNING_MIN,
				"It's brushing time!", "%s awaits!" % name_str)
		if not (d == 0 and evening_done_today):
			_schedule(d, Slot.EVENING, EVENING_HOUR, EVENING_MIN,
				"It's brushing time!", "%s awaits!" % name_str)

	# 1b) Daily stamp card reward, ready every morning at 7:30 (skip today if already claimed)
	var reward_claimed_today: bool = str(p.get("last_daily_login", "")) == today
	for d in range(0, REMINDER_DAYS_AHEAD + 1):
		if d == 0 and reward_claimed_today:
			continue
		_schedule(d, Slot.REWARD, REWARD_HOUR, REWARD_MIN,
			"Daily reward ready!", "Your daily stamp reward is ready! Tap to claim it!")

	# 2) Streak: keep it going (today only, needs a real streak and nothing brushed yet)
	if streak > 0 and not brushed_today:
		_schedule(0, Slot.STREAK_KEEP, STREAK_KEEP_HOUR, STREAK_KEEP_MIN,
			"%d-day streak!" % streak, "You're on a %d-day streak! Keep it going!" % streak)

	# 3) Streak: about to lose it (today only, evening brush still missing)
	if streak > 0 and not evening_done_today:
		_schedule(0, Slot.STREAK_LOSS, STREAK_LOSS_HOUR, STREAK_LOSS_MIN,
			"Streak in danger!", "You're about to lose your %d-day streak!" % streak)

	# 4) Candy Crusade day: Blue Candor attacks until the evening fight is done
	if cur_day >= 1 and cur_day <= 28 and GameState.CANDY_CRUSADE_DAYS.has(cur_day) \
			and not GameState.is_day_evening_completed(cur_day, p):
		for d in range(0, CRUSADE_DAYS_AHEAD):
			_schedule(d, Slot.CRUSADE, CRUSADE_HOUR, CRUSADE_MIN,
				"Blue Candor is attacking!", "Tap to protect %s!" % name_str)

	# 5) Missed a day: the character is stuck in a candy trap.
	# If they already brushed today, the first day they could miss is tomorrow, which we
	# only know on day +2. If they haven't brushed today, today is already at risk -> day +1.
	var first_trap := 2 if brushed_today else 1
	for i in range(TRAP_NUDGES):
		_schedule(first_trap + i, Slot.TRAP, TRAP_HOUR, TRAP_MIN,
			"Oh no!", "%s is stuck in a candy trap! Open the game to free them!" % name_str)


func _character_name(p: Dictionary) -> String:
	var avatar_id := str(p.get("avatar", ""))
	for c in GameState.CHARACTERS:
		if str(c.get("id", "")) == avatar_id:
			return str(c.get("name", "Your tooth pal"))
	var n := str(p.get("name", ""))
	return n if n != "" else "Your tooth pal"


# Schedules one notification at (today + day_offset) at hh:mm local time. Past times are skipped.
func _schedule(day_offset: int, slot: int, hh: int, mm: int, title: String, body: String) -> void:
	var delay := _seconds_until(day_offset, hh, mm)
	if delay < 60:
		return
	var n: Object = _make_data()
	if n == null:
		return
	var id := day_offset * ID_BLOCK + slot
	_call_set(n, "set_id", id)
	_call_set(n, "set_title", title)
	_call_set(n, "set_content", body)
	_call_set(n, "set_delay", delay)
	_call_set(n, "set_channel_id", "pearly_whites_reminders")
	if _plugin.has_method("schedule"):
		_plugin.call("schedule", n)


func _seconds_until(day_offset: int, hh: int, mm: int) -> int:
	var now_unix := int(Time.get_unix_time_from_system())
	var bias_secs := int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var local_now := Time.get_datetime_dict_from_unix_time(now_unix + bias_secs)
	var secs_into_day: int = int(local_now.hour) * 3600 + int(local_now.minute) * 60 + int(local_now.second)
	var local_midnight := now_unix - secs_into_day
	var target := local_midnight + day_offset * 86400 + hh * 3600 + mm * 60
	return target - now_unix


func _cancel_all() -> void:
	if _plugin == null or not _plugin.has_method("cancel"):
		return
	for d in range(0, MAX_DAYS_TO_CANCEL + 1):
		for s in range(0, ID_BLOCK):
			_plugin.call("cancel", d * ID_BLOCK + s)


# ----------------------------------------------------------------------
# Plugin plumbing (duck-typed so the game still runs without the plugin)
# ----------------------------------------------------------------------
func _init_plugin() -> void:
	if OS.get_name() != "iOS":
		return
	var scheduler_script := _global_class_script("NotificationScheduler")
	var data_script := _global_class_script("NotificationData")
	if scheduler_script == null or data_script == null:
		push_warning("[LocalNotifications] iOS Notification Scheduler plugin not found - reminders disabled.")
		return
	_data_class = data_script
	_plugin = scheduler_script.new()
	_plugin.name = "NotificationScheduler"
	add_child(_plugin)
	if _plugin.has_signal("initialization_completed"):
		_plugin.connect("initialization_completed", _on_plugin_initialized)
	if _plugin.has_signal("post_notifications_permission_granted"):
		_plugin.connect("post_notifications_permission_granted", _on_permission_granted)
	if _plugin.has_signal("post_notifications_permission_denied"):
		_plugin.connect("post_notifications_permission_denied", _on_permission_denied)
	if _plugin.has_method("initialize"):
		_plugin.call("initialize")
	else:
		_on_plugin_initialized()


func _on_plugin_initialized() -> void:
	_plugin_ready = true
	if _plugin.has_method("has_post_notifications_permission"):
		_permission_granted = bool(_plugin.call("has_post_notifications_permission"))
	refresh()


func _on_permission_granted(_a = null) -> void:
	_permission_granted = true
	refresh()


func _on_permission_denied(_a = null) -> void:
	_permission_granted = false


func _global_class_script(cls: String) -> Script:
	for entry in ProjectSettings.get_global_class_list():
		if str(entry.get("class", "")) == cls:
			return load(str(entry.get("path", ""))) as Script
	return null


func _make_data() -> Object:
	if _data_class == null:
		return null
	return (_data_class as Script).new()


func _call_set(obj: Object, method: String, value) -> void:
	if obj.has_method(method):
		obj.call(method, value)


# ----------------------------------------------------------------------
# Settings
# ----------------------------------------------------------------------
func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		enabled = bool(cfg.get_value("notifications", "enabled", true))


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("notifications", "enabled", enabled)
	cfg.save(SETTINGS_PATH)
