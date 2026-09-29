# scripts/notification_manager.gd
extends Node

# Notification Manager for Native & In-Game Push Notifications & Automated Reminders
# Triggers:
# 1. Daily Streak Loss Warning at 7:00 PM (19:00) if morning/evening brushing incomplete
# 2. Blue Candor Boss Attack alerts when boss events trigger (Days 1, 9, 19, 28 & combat)
# 3. Shop Weapon/Upgrade affordability notifications when player reaches required points/coins
# 4. Daily / weekly storybook chapter panel unlock alerts

var check_timer: Timer
var sent_notifications: Dictionary = {}
var last_checked_story_count: int = -1
var last_notified_weapon_ids: Array[String] = []

const BOSS_DAYS = [1, 9, 19, 28]

func _ready():
	# Top notifications disabled per user request
	pass

func _on_check_timer():
	_evaluate_all_triggers()

func _on_stats_updated(profile: Dictionary):
	_check_streak_milestones(profile)
	_check_shop_affordability(profile)
	_check_storybook_unlocks(profile)

func _on_profile_changed(profile: Dictionary):
	last_checked_story_count = -1
	last_notified_weapon_ids.clear()
	_evaluate_all_triggers()

func _evaluate_all_triggers():
	var p = GameState.get_active_profile()
	if p.is_empty():
		return
		
	_check_streak_milestones(p)
	_check_streak_loss_warning(p)
	_check_boss_attack_alert(p)
	_check_shop_affordability(p)
	_check_storybook_unlocks(p)

func run_failsafe_reconciliation():
	var p = GameState.get_active_profile()
	if p.is_empty():
		return
	_check_streak_milestones(p)
	GameState.check_character_unlocks(p, true)
	_check_boss_attack_alert(p)
	_check_shop_affordability(p)

# ----------------------------------------------------------------------
# Trigger 0: Streak Milestones (3, 7, 14, 21, 28 Days)
# ----------------------------------------------------------------------
func _check_streak_milestones(p: Dictionary):
	var streak = int(p.get("streak", 0))
	if streak <= 0:
		return
		
	var prof_id = str(p.get("id", "def"))
	if not p.has("notified_streak_milestones") or typeof(p["notified_streak_milestones"]) != TYPE_ARRAY:
		p["notified_streak_milestones"] = []
	var notified = p["notified_streak_milestones"]
	
	var milestones = [
		{"days": 3, "title": "3-Day Streak!", "body": "Great start! 3 days in a row! Keep brushing!", "icon": "", "tone": "orange"},
		{"days": 7, "title": "7-Day Streak Achieved!", "body": "Incredible! You've brushed 7 days in a row! 1 Week Strong!", "icon": "", "tone": "orange"},
		{"days": 14, "title": "14-Day Streak Champion!", "body": "Two full weeks of brushing mastery! You're unstoppable!", "icon": "", "tone": "purple"},
		{"days": 21, "title": "21-Day Streak Legend!", "body": "3 weeks strong! A lifelong healthy habit in the making!", "icon": "", "tone": "yellow"},
		{"days": 28, "title": "28-Day Challenge Mastered!", "body": "Congratulations! You conquered the 28-Day Pearly Whites Challenge!", "icon": "", "tone": "green"}
	]
	
	var newly_notified = false
	for m in milestones:
		var d = int(m["days"])
		if streak >= d and not notified.has(d):
			notified.append(d)
			newly_notified = true
			var notif_key = "streak_milestone_%d_%s" % [d, prof_id]
			dispatch_notification(m["title"], m["body"], m["icon"], m["tone"], notif_key)
			
	if newly_notified:
		GameState.save_game()



# ----------------------------------------------------------------------
# Trigger 1: Daily Streak Loss Warnings (1 Hour, 30 Mins, and 10 Mins before Midnight)
# ----------------------------------------------------------------------
func _check_streak_loss_warning(p: Dictionary):
	var time_dict = Time.get_time_dict_from_system()
	var date_dict = Time.get_date_dict_from_system()
	var date_key = "%04d-%02d-%02d" % [date_dict.year, date_dict.month, date_dict.day]
	
	# If evening brushing has already been completed today, DO NOT send any streak warning!
	var cur_node = int(p.get("currentNode", 1))
	var day = GameState.day_for_node(cur_node)
	if GameState.is_day_evening_completed(day, p) or str(p.get("lastEveningBrushDate", "")) == date_key:
		return
		
	var streak = int(p.get("streak", 0))
	if streak <= 0:
		return # No active streak to lose
		
	# Calculate minutes remaining until midnight (when streak expires)
	var mins_to_midnight = (23 - time_dict.hour) * 60 + (60 - time_dict.minute)
	
	# Only evaluate when within the 1-hour window before midnight (<= 60 minutes)
	if mins_to_midnight > 60 or mins_to_midnight < 0:
		return
		
	var prof_id = p.get("id", "def")
	
	# 10 Minutes Away Warning (23:50 - 23:59)
	if mins_to_midnight <= 10:
		var key_10m = "streak_loss_10m_" + prof_id + "_" + date_key
		if not sent_notifications.has(key_10m):
			sent_notifications[key_10m] = true
			dispatch_notification(
				"Streak Alert: 10 Mins Left!",
				"Urgent! Only 10 minutes left before midnight! Complete your evening brush to save your %d-day streak!" % streak,
				"",
				"orange"
			)
		return
		
	# 30 Minutes Away Warning (23:30 - 23:49)
	if mins_to_midnight <= 30:
		var key_30m = "streak_loss_30m_" + prof_id + "_" + date_key
		if not sent_notifications.has(key_30m):
			sent_notifications[key_30m] = true
			dispatch_notification(
				"Streak Warning: 30 Mins Left!",
				"Only 30 minutes left before midnight! Protect your %d-day streak with your evening brush!" % streak,
				"",
				"orange"
			)
		return
		
	# 1 Hour Away Warning (23:00 - 23:29)
	if mins_to_midnight <= 60:
		var key_60m = "streak_loss_60m_" + prof_id + "_" + date_key
		if not sent_notifications.has(key_60m):
			sent_notifications[key_60m] = true
			dispatch_notification(
				"Streak Warning: 1 Hour Left!",
				"You have 1 hour left before midnight to complete your evening brush and keep your %d-day streak alive!" % streak,
				"",
				"orange"
			)
		return

# ----------------------------------------------------------------------
# Trigger 2: Blue Candor Boss Attack Alert (Days 1, 9, 19, 28)
# ----------------------------------------------------------------------
func _check_boss_attack_alert(p: Dictionary):
	var cur_node = int(p.get("currentNode", 1))
	var day = GameState.day_for_node(cur_node)
	
	if day in BOSS_DAYS:
		var boss_key = "boss_attack_day_%d_%s" % [day, p.get("id", "def")]
		if not sent_notifications.has(boss_key):
			# Check if player is on this boss node stage
			var stages = p.get("nodeStage", {})
			var stage = int(stages.get(str(cur_node), 0))
			if stage < 1: # Boss not yet defeated
				sent_notifications[boss_key] = true
				dispatch_notification(
					"Blue Candor Attack!",
					"Blue Candor is attacking on Day %d! Defend Pearly Land with your weapons!" % day,
					"",
					"purple"
				)

func trigger_boss_encounter_alert(boss_name: String = "Blue Candor"):
	dispatch_notification(
		"Boss Attack Warning!",
		"%s and candy minions are storming the castle! Battle ready!" % boss_name,
		"",
		"purple"
	)

const SHOP_WEAPONS = [
	{"id": "brush", "name": "Brush Boomerang", "unlock_day": 1, "costs": [0, 350, 650], "day_reqs": [1, 3, 11]},
	{"id": "paste", "name": "Paste Pistol", "unlock_day": 2, "costs": [250, 550, 800], "day_reqs": [2, 9, 15]},
	{"id": "floss", "name": "Floss Lasso", "unlock_day": 5, "costs": [400, 700, 950], "day_reqs": [5, 13, 19]},
	{"id": "wash", "name": "Mouthwash Blast", "unlock_day": 7, "costs": [450, 850, 1100], "day_reqs": [7, 17, 21]}
]

# ----------------------------------------------------------------------
# Trigger 3: Shop Weapon / Upgrade Affordability Notification
# ----------------------------------------------------------------------
func _check_shop_affordability(p: Dictionary):
	var pts = int(round(float(p.get("points", 0))))
	var cur_node = int(p.get("currentNode", 1))
	var cur_day = GameState.get_unlocked_day(p)
	var prof_id = p.get("id", "def")
	var wep_levels = p.get("weaponLevels", {})
	
	for w_def in SHOP_WEAPONS:
		var w_id = str(w_def.get("id", ""))
		var w_name = str(w_def.get("name", "New Weapon"))
		var unlock_day = int(w_def.get("unlock_day", 1))
		var day_reqs: Array = w_def.get("day_reqs", [1, 1, 1])
		var costs: Array = w_def.get("costs", [0, 0, 0])
		
		# If the base weapon isn't unlocked on the player's current day yet, skip!
		if cur_day < unlock_day:
			continue
			
		var cur_lvl = int(wep_levels.get(w_id, 0))
		# If weapon is not maxed out (max level is 3)
		if cur_lvl < 3:
			var target_tier_idx = cur_lvl # 0 for tier 1 (unlock), 1 for tier 2, 2 for tier 3
			var target_day_req = int(day_reqs[target_tier_idx])
			var cost = int(costs[target_tier_idx])
			
			# Check if target tier is unlocked by day AND player has enough points
			if cur_day >= target_day_req and pts >= cost and cost > 0:
				var notif_key = "afford_wep_%s_lvl_%d_%s" % [w_id, cur_lvl + 1, prof_id]
				if not sent_notifications.has(notif_key):
					sent_notifications[notif_key] = true
					var action_text = "unlock the %s" % w_name if cur_lvl == 0 else "upgrade %s to Level %d" % [w_name, cur_lvl + 1]
					dispatch_notification(
						"Weapon Ready in Shop!",
						"You have %d Points! You can now %s!" % [pts, action_text],
						"",
						"green"
					)
					break

# ----------------------------------------------------------------------
# Trigger 4: Storybook Chapter Panel Unlock Alerts (Handled directly on Map Screen)
# ----------------------------------------------------------------------
func _check_storybook_unlocks(_p: Dictionary):
	# Story unlocks pop up exclusively on the Map Screen as rich interactive comic panels
	pass

# ----------------------------------------------------------------------
# Core Dispatcher: In-Game Toast + Window / OS Attention
# ----------------------------------------------------------------------
func dispatch_notification(_title: String, _body: String, _icon: String = "", _tone: String = "green", _id: String = ""):
	# Top notifications disabled per user request
	pass


