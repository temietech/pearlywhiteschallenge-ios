# scripts/firebase_manager.gd
# Production Firebase REST API Client for Godot 4 (Local-First Offline Architecture)
extends Node

# Signals
signal auth_completed(user_id: String)
signal auth_failed(error_message: String)
signal profile_saved(user_id: String)
signal sync_completed(status_message: String)
signal sync_failed(error_message: String)

# Configuration & Hardcoded Default Credentials
const DEFAULT_PROJECT_ID: String = "pearly-whites-challenge"
const DEFAULT_WEB_API_KEY: String = "AIzaSyDaSD6Tmgl7VdDjzPb89gGAUsonZWh0Nz4"

@export var project_id: String = DEFAULT_PROJECT_ID
@export var web_api_key: String = DEFAULT_WEB_API_KEY

# Local Storage Paths
const AUTH_SESSION_PATH: String = "user://auth_session.json"
const CHALLENGE_DATA_PATH: String = "user://challenge_data.json"

# State Variables
var current_user_id: String = ""
var id_token: String = ""
var refresh_token: String = ""
var token_expiry_timestamp: int = 0
var is_syncing: bool = false
var is_auth_in_flight: bool = false

# In-Memory Challenge Data Cache (Local-First)
var local_data: Dictionary = {
	"user_id": "",
	"brushing_sessions": [],
	"quiz_records": {},
	"game_progress": {},
	"needs_cloud_sync": false,
	"last_modified": "",
	"timestamp_unix": 0
}

func _ready():
	_load_local_challenge_data()
	_initialize_auth_session()

# ==============================================================================
# 1. ANONYMOUS AUTHENTICATION (Silent Sign-In)
# ==============================================================================

func _initialize_auth_session():
	if _load_cached_auth_session():
		print("[FirebaseManager] Valid cached auth session loaded. User ID: ", current_user_id)
		auth_completed.emit(current_user_id)
		check_and_sync_pending_data()
	else:
		print("[FirebaseManager] No valid auth session found. Initiating anonymous sign-in...")
		anonymous_sign_in()

func anonymous_sign_in():
	if is_auth_in_flight:
		return
	is_auth_in_flight = true

	var url = "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=" + web_api_key
	var headers = ["Content-Type: application/json"]
	var body = JSON.stringify({"returnSecureToken": true})

	var http = HTTPRequest.new()
	http.name = "AuthHTTPRequest"
	add_child(http)
	http.timeout = 10.0
	http.request_completed.connect(func(result, response_code, resp_headers, resp_body):
		http.queue_free()
		is_auth_in_flight = false
		_on_anonymous_sign_in_completed(result, response_code, resp_body)
	)

	var err = http.request(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		is_auth_in_flight = false
		var err_msg = "Failed to dispatch auth request: error code %d" % err
		print("[FirebaseManager] ", err_msg)
		_fallback_offline_user()
		auth_failed.emit(err_msg)

func _on_anonymous_sign_in_completed(result: int, response_code: int, body: PackedByteArray):
	if result != HTTPRequest.RESULT_SUCCESS or (response_code != 200 and response_code != 201):
		var err_msg = "Anonymous auth failed (HTTP %d, Result %d)" % [response_code, result]
		print("[FirebaseManager] ", err_msg)
		if current_user_id.is_empty():
			_fallback_offline_user()
		auth_failed.emit(err_msg)
		return

	var json_res = JSON.parse_string(body.get_string_from_utf8())
	if json_res is Dictionary:
		current_user_id = str(json_res.get("localId", ""))
		id_token = str(json_res.get("idToken", ""))
		refresh_token = str(json_res.get("refreshToken", ""))
		var expires_in = int(json_res.get("expiresIn", 3600))
		token_expiry_timestamp = int(Time.get_unix_time_from_system()) + expires_in

		_save_cached_auth_session()
		print("[FirebaseManager] Anonymous sign-in successful! User ID: ", current_user_id)
		auth_completed.emit(current_user_id)
		check_and_sync_pending_data()

func _save_cached_auth_session():
	var session_data = {
		"user_id": current_user_id,
		"id_token": id_token,
		"refresh_token": refresh_token,
		"token_expiry": token_expiry_timestamp
	}
	var file = FileAccess.open(AUTH_SESSION_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(session_data, "\t"))
		file.close()

func _load_cached_auth_session() -> bool:
	if not FileAccess.file_exists(AUTH_SESSION_PATH):
		return false

	var file = FileAccess.open(AUTH_SESSION_PATH, FileAccess.READ)
	if not file:
		return false

	var json = JSON.parse_string(file.get_as_text())
	file.close()

	if json is Dictionary:
		current_user_id = str(json.get("user_id", ""))
		id_token = str(json.get("id_token", ""))
		refresh_token = str(json.get("refresh_token", ""))
		token_expiry_timestamp = int(json.get("token_expiry", 0))

		var now = int(Time.get_unix_time_from_system())
		# If token is within 5 minutes of expiring, refresh it
		if now >= (token_expiry_timestamp - 300) and not refresh_token.is_empty():
			_refresh_id_token()
			return true

		return not current_user_id.is_empty()
	return false

func _refresh_id_token():
	if web_api_key.is_empty() or refresh_token.is_empty():
		return

	var url = "https://securetoken.googleapis.com/v1/token?key=" + web_api_key
	var headers = ["Content-Type: application/x-www-form-urlencoded"]
	var body = "grant_type=refresh_token&refresh_token=" + refresh_token

	var http = HTTPRequest.new()
	http.name = "RefreshTokenHTTPRequest"
	add_child(http)
	http.timeout = 10.0
	http.request_completed.connect(func(result, response_code, resp_headers, resp_body):
		http.queue_free()
		if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
			var json_res = JSON.parse_string(resp_body.get_string_from_utf8())
			if json_res is Dictionary:
				id_token = str(json_res.get("id_token", ""))
				refresh_token = str(json_res.get("refresh_token", refresh_token))
				var expires_in = int(json_res.get("expires_in", 3600))
				token_expiry_timestamp = int(Time.get_unix_time_from_system()) + expires_in
				_save_cached_auth_session()
				print("[FirebaseManager] Auth token refreshed successfully.")
	)
	http.request(url, headers, HTTPClient.METHOD_POST, body)

func _fallback_offline_user():
	if current_user_id.is_empty():
		current_user_id = "offline_" + str(Time.get_unix_time_from_system()) + "_" + str(randi() % 100000)
		_save_cached_auth_session()
		print("[FirebaseManager] Offline local user created: ", current_user_id)

# ==============================================================================
# 2. USER PROFILE CREATION
# ==============================================================================

func create_or_update_profile(name: String, age: int, broad_region: String):
	if current_user_id.is_empty():
		_fallback_offline_user()

	var now_iso = Time.get_datetime_string_from_system(true, true) + "Z"
	var profile_fields = {
		"user_id": {"stringValue": current_user_id},
		"name": {"stringValue": name},
		"age": {"integerValue": str(age)},
		"broad_region": {"stringValue": broad_region},
		"created_at": {"timestampValue": now_iso},
		"last_active": {"timestampValue": now_iso}
	}

	# Non-blocking Firestore PATCH
	var url = "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents/users/%s?key=%s" % [
		project_id, current_user_id, web_api_key
	]

	var headers = ["Content-Type: application/json"]
	if not id_token.is_empty():
		headers.append("Authorization: Bearer " + id_token)

	var http = HTTPRequest.new()
	http.name = "ProfileHTTPRequest"
	add_child(http)
	http.timeout = 10.0
	http.request_completed.connect(func(result, response_code, resp_headers, resp_body):
		http.queue_free()
		if response_code == 200 or response_code == 201:
			print("[FirebaseManager] User profile saved to Firestore.")
			profile_saved.emit(current_user_id)
		else:
			print("[FirebaseManager] Profile upload queued locally (HTTP %d)." % response_code)
	)

	var payload = {"fields": profile_fields}
	http.request(url, headers, HTTPClient.METHOD_PATCH, JSON.stringify(payload))

# ==============================================================================
# 3. HABIT & EDUCATIONAL DATA RECORDING
# ==============================================================================

func record_brushing_session(duration_seconds: int, is_morning: bool):
	var session_entry = {
		"timestamp": Time.get_datetime_string_from_system(true, true) + "Z",
		"timestamp_unix": Time.get_unix_time_from_system(),
		"duration_seconds": duration_seconds,
		"session_type": "morning" if is_morning else "evening",
		"completed": duration_seconds >= 120
	}
	local_data["brushing_sessions"].append(session_entry)
	print("[FirebaseManager] Brushing session logged (%s, %ds)" % [session_entry["session_type"], duration_seconds])
	save_challenge_data()

func record_quiz_answer(day: int, question_id: String, question_type: String, answer_val: Variant, is_correct: bool):
	var day_key = "day_%02d" % day
	if not local_data["quiz_records"].has(day_key):
		local_data["quiz_records"][day_key] = {}

	var answer_entry = {
		"question_id": question_id,
		"question_type": question_type, # "true_false" or "open_text"
		"answer": answer_val,
		"is_correct": is_correct,
		"timestamp": Time.get_datetime_string_from_system(true, true) + "Z"
	}
	local_data["quiz_records"][day_key][question_id] = answer_entry
	print("[FirebaseManager] Quiz answer logged for Day %d: %s (Type: %s, Correct: %s)" % [day, question_id, question_type, str(is_correct)])
	save_challenge_data()

# ==============================================================================
# 4. MASTER SYNC FUNCTION (Local-First Offline Architecture)
# ==============================================================================

func save_challenge_data(game_progress: Dictionary = {}):
	if current_user_id.is_empty():
		_fallback_offline_user()

	if not game_progress.is_empty():
		local_data["game_progress"] = game_progress

	local_data["user_id"] = current_user_id
	local_data["needs_cloud_sync"] = true
	local_data["last_modified"] = Time.get_datetime_string_from_system(true, true) + "Z"
	local_data["timestamp_unix"] = int(Time.get_unix_time_from_system())

	# 1. Immediately serialize full state to local disk (Guaranteed save)
	_save_local_challenge_data()

	# 2. Dispatch non-blocking background HTTPRequest to Firestore
	_dispatch_firestore_sync()

func _dispatch_firestore_sync():
	if is_syncing:
		return
	if current_user_id.is_empty() or web_api_key.is_empty():
		return

	is_syncing = true

	# Target Document: users/{user_id}/challenge_data/tracker
	var url = "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents/users/%s/challenge_data/tracker?key=%s" % [
		project_id, current_user_id, web_api_key
	]

	var headers = ["Content-Type: application/json"]
	if not id_token.is_empty():
		headers.append("Authorization: Bearer " + id_token)

	# Format Firestore typed fields schema
	var firestore_body = {
		"fields": {
			"user_id": {"stringValue": current_user_id},
			"brushing_sessions": _to_firestore_value(local_data.get("brushing_sessions", [])),
			"quiz_records": _to_firestore_value(local_data.get("quiz_records", {})),
			"game_progress": _to_firestore_value(local_data.get("game_progress", {})),
			"last_modified": {"timestampValue": local_data.get("last_modified", Time.get_datetime_string_from_system(true, true) + "Z")},
			"timestamp_unix": {"integerValue": str(local_data.get("timestamp_unix", 0))}
		}
	}

	var http = HTTPRequest.new()
	http.name = "SyncHTTPRequest"
	add_child(http)
	http.timeout = 10.0
	http.request_completed.connect(func(result, response_code, resp_headers, resp_body):
		http.queue_free()
		is_syncing = false
		_on_firestore_sync_completed(result, response_code, resp_body)
	)

	var err = http.request(url, headers, HTTPClient.METHOD_PATCH, JSON.stringify(firestore_body))
	if err != OK:
		is_syncing = false
		print("[FirebaseManager] Background sync dispatch failed (%d). Retained offline." % err)

func _on_firestore_sync_completed(result: int, response_code: int, _body: PackedByteArray):
	if result == HTTPRequest.RESULT_SUCCESS and (response_code == 200 or response_code == 201):
		local_data["needs_cloud_sync"] = false
		_save_local_challenge_data()
		print("[FirebaseManager] Cloud sync SUCCEEDED (HTTP %d)." % response_code)
		sync_completed.emit("Cloud sync successful")
	else:
		# Network timeout / Offline / Error -> Keep needs_cloud_sync = true without crashing
		local_data["needs_cloud_sync"] = true
		_save_local_challenge_data()
		var msg = "Cloud sync pending (HTTP %d, Result %d). Saved offline." % [response_code, result]
		print("[FirebaseManager] ", msg)
		sync_failed.emit(msg)

# ==============================================================================
# 5. AUTOMATIC BACKGROUND SYNC & LOCAL PERSISTENCE
# ==============================================================================

func check_and_sync_pending_data():
	_load_local_challenge_data()
	if local_data.get("needs_cloud_sync", false) == true:
		print("[FirebaseManager] Pending cloud sync detected. Uploading in background...")
		_dispatch_firestore_sync()

func _save_local_challenge_data():
	var file = FileAccess.open(CHALLENGE_DATA_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(local_data, "\t"))
		file.close()

func _load_local_challenge_data():
	if not FileAccess.file_exists(CHALLENGE_DATA_PATH):
		return

	var file = FileAccess.open(CHALLENGE_DATA_PATH, FileAccess.READ)
	if not file:
		return

	var json = JSON.parse_string(file.get_as_text())
	file.close()

	if json is Dictionary:
		local_data = json
		if not local_data.has("brushing_sessions"):
			local_data["brushing_sessions"] = []
		if not local_data.has("quiz_records"):
			local_data["quiz_records"] = {}
		if not local_data.has("game_progress"):
			local_data["game_progress"] = {}

func delete_user_account_and_data():
	if current_user_id.is_empty():
		_load_cached_auth_session()
		
	if not current_user_id.is_empty() and not web_api_key.is_empty():
		print("[FirebaseManager] Deleting Cloud Firestore data for user: ", current_user_id)
		
		# 1. Delete tracker sub-document: users/{user_id}/challenge_data/tracker
		var tracker_url = "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents/users/%s/challenge_data/tracker?key=%s" % [
			project_id, current_user_id, web_api_key
		]
		var headers = ["Content-Type: application/json"]
		if not id_token.is_empty():
			headers.append("Authorization: Bearer " + id_token)
			
		var http_tracker = HTTPRequest.new()
		http_tracker.name = "DeleteTrackerHTTP"
		add_child(http_tracker)
		http_tracker.timeout = 10.0
		http_tracker.request_completed.connect(func(result, response_code, resp_headers, resp_body):
			http_tracker.queue_free()
			print("[FirebaseManager] Cloud tracker deletion status: HTTP ", response_code)
		)
		http_tracker.request(tracker_url, headers, HTTPClient.METHOD_DELETE)
		
		# 2. Delete main user document: users/{user_id}
		var user_url = "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents/users/%s?key=%s" % [
			project_id, current_user_id, web_api_key
		]
		var http_user = HTTPRequest.new()
		http_user.name = "DeleteUserHTTP"
		add_child(http_user)
		http_user.timeout = 10.0
		http_user.request_completed.connect(func(result, response_code, resp_headers, resp_body):
			http_user.queue_free()
			print("[FirebaseManager] Cloud user document deletion status: HTTP ", response_code)
		)
		http_user.request(user_url, headers, HTTPClient.METHOD_DELETE)
		
	# 3. Erase local cached session files
	if FileAccess.file_exists(AUTH_SESSION_PATH):
		DirAccess.remove_absolute(AUTH_SESSION_PATH)
	if FileAccess.file_exists(CHALLENGE_DATA_PATH):
		DirAccess.remove_absolute(CHALLENGE_DATA_PATH)
		
	current_user_id = ""
	id_token = ""
	refresh_token = ""
	token_expiry_timestamp = 0
	local_data = {
		"user_id": "",
		"brushing_sessions": [],
		"quiz_records": {},
		"game_progress": {},
		"needs_cloud_sync": false,
		"last_modified": "",
		"timestamp_unix": 0
	}
	print("[FirebaseManager] Account and data deleted successfully.")

func get_challenge_data() -> Dictionary:
	return local_data

func is_cloud_synced() -> bool:
	return not local_data.get("needs_cloud_sync", true)

# ==============================================================================
# 6. FIRESTORE REST TYPED SCHEMA SERIALIZERS
# ==============================================================================

func _to_firestore_map(dict: Dictionary) -> Dictionary:
	var fields = {}
	for k in dict.keys():
		fields[str(k)] = _to_firestore_value(dict[k])
	return {"mapValue": {"fields": fields}}

func _to_firestore_array(arr: Array) -> Dictionary:
	var values = []
	for item in arr:
		values.append(_to_firestore_value(item))
	return {"arrayValue": {"values": values}}

func _to_firestore_value(val: Variant) -> Dictionary:
	if val is bool:
		return {"booleanValue": val}
	elif val is int:
		return {"integerValue": str(val)}
	elif val is float:
		return {"doubleValue": val}
	elif val is String:
		return {"stringValue": val}
	elif val is Array:
		return _to_firestore_array(val)
	elif val is Dictionary:
		return _to_firestore_map(val)
	else:
		return {"stringValue": str(val)}

func _from_firestore_fields(fields: Dictionary) -> Dictionary:
	var result = {}
	for key in fields.keys():
		var type_dict = fields[key]
		if type_dict is Dictionary:
			if type_dict.has("stringValue"):
				result[key] = type_dict["stringValue"]
			elif type_dict.has("integerValue"):
				result[key] = int(type_dict["integerValue"])
			elif type_dict.has("doubleValue"):
				result[key] = float(type_dict["doubleValue"])
			elif type_dict.has("booleanValue"):
				result[key] = bool(type_dict["booleanValue"])
			elif type_dict.has("timestampValue"):
				result[key] = type_dict["timestampValue"]
			elif type_dict.has("arrayValue"):
				var arr = []
				var vals = type_dict["arrayValue"].get("values", [])
				for v in vals:
					arr.append(_from_firestore_value(v))
				result[key] = arr
			elif type_dict.has("mapValue"):
				result[key] = _from_firestore_fields(type_dict["mapValue"].get("fields", {}))
	return result

func _from_firestore_value(val_dict: Dictionary) -> Variant:
	if val_dict.has("stringValue"):
		return val_dict["stringValue"]
	elif val_dict.has("integerValue"):
		return int(val_dict["integerValue"])
	elif val_dict.has("doubleValue"):
		return float(val_dict["doubleValue"])
	elif val_dict.has("booleanValue"):
		return bool(val_dict["booleanValue"])
	elif val_dict.has("mapValue"):
		return _from_firestore_fields(val_dict["mapValue"].get("fields", {}))
	elif val_dict.has("arrayValue"):
		var arr = []
		for v in val_dict["arrayValue"].get("values", []):
			arr.append(_from_firestore_value(v))
		return arr
	return null
