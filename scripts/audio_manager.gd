# scripts/audio_manager.gd
extends Node

var bgm_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
var max_sfx_channels: int = 12

var master_volume: float = 0.85
var sfx_volume: float = 0.85
var bgm_volume: float = 0.40
var saved_sfx_volume: float = 0.85
var saved_bgm_volume: float = 0.40
var sound_enabled: bool = true
var music_enabled: bool = true
var is_muted: bool = false
var tts_enabled: bool = false

var narration_player: AudioStreamPlayer
var current_narration_text: String = ""
var current_narration_audio: String = ""
var is_narration_paused: bool = false
var auto_narration_enabled: bool = true

var sfx_cache: Dictionary = {}
var bgm_cache: Dictionary = {}
var voice_cache: Dictionary = {}
var current_bgm_track_path: String = ""

# Page / Screen to Background Music Mapping
# Character voices and narration are 30% louder than music / effects
const VOICE_GAIN := 1.3
# While any voice (narration, character line or text-to-speech) is speaking, music drops to this
# fraction of its normal level. Ducking starts the moment a voice is requested ("about to speak")
# and fades back up gently after the voice ends.
const VOICE_DUCK_FACTOR := 0.25
const DUCK_ATTACK_SPEED := 10.0   # fast fade down (~0.1 s)
const DUCK_RELEASE_SPEED := 2.5   # gentle fade back up (~0.4 s)
var _duck_amount: float = 0.0     # 0 = full music, 1 = fully ducked
var _duck_hold_until_ms: int = 0  # keep ducked at least until this time (covers TTS start-up lag)

const HOME_PAGE_BGM = "res://assets/audio/music/PW Intro Audio.mp3"
const MAP_AND_APP_BGM = "res://assets/audio/music/Candyland Dreams.mp3"

const SCREEN_BGM_MAP = {
	# Home / Start Page
	"start": HOME_PAGE_BGM,
	
	# Map & Other Main App Pages (seamless continuous playback)
	"profiles": MAP_AND_APP_BGM,
	"create_profile": MAP_AND_APP_BGM,
	"select_player": MAP_AND_APP_BGM,
	"character_select": MAP_AND_APP_BGM,
	"map": MAP_AND_APP_BGM,
	"shop": MAP_AND_APP_BGM,
	"badges": MAP_AND_APP_BGM,
	"profile": MAP_AND_APP_BGM,
	"avatar_care": MAP_AND_APP_BGM,
	"story": MAP_AND_APP_BGM,
	"facts": MAP_AND_APP_BGM,
	"settings": MAP_AND_APP_BGM,
	"dev_menu": MAP_AND_APP_BGM,
	
	# Distinct Minigames & Activities (each has unique music, all > 1 minute)
	"floss": "res://assets/audio/music/Brush the Pearly White way! (1).mp3",       # 01:26
	"brush_check": "res://assets/audio/music/Brush the Pearly White way! (1).mp3", # 01:26
	"brushing": "res://assets/audio/music/Brush the Pearly White way! (1).mp3",    # 01:26
	"combat": "res://assets/audio/music/into the lair - i like.MP3",               # 01:47 (Candy Crusade)
	"whack": "res://assets/audio/music/Spark.mp3",                                 # 01:17 (BonBon Bash)
	"memory": "res://assets/audio/music/Healthy Heroes CleanMatch.mp3",            # 01:20 (Memory Match)
	"candy_trap": "res://assets/audio/music/Candy Bomb Frenzy (3.20).mp3",         # 04:00 (Candy Trap)
	"surprise": "res://assets/audio/music/Candy Meadow.mp3",                       # 01:47 (Daily Surprise)
	"quiz": "res://assets/audio/music/PW Intro Audio 5.mp3"                        # 01:08 (Weekly Quiz)
}

# Authentic Sound Effects Mapping
const SFX_FILE_MAP = {
	"click": "res://assets/audio/sfx/MP3/click_001.mp3",
	"close": "res://assets/audio/sfx/MP3/close_004.mp3",
	"pop": "res://assets/audio/sfx/MP3/drop_004.mp3",
	"coin": "res://assets/audio/sfx/MP3/item-pick-up-38258.mp3",
	"chime": "res://assets/audio/sfx/MP3/confirmation_002.mp3",
	"sparkle": "res://assets/audio/sfx/CleanMatch/powerUp4.mp3",
	"victory": "res://assets/audio/sfx/LvlResults/Victory.mp3",
	"defeat": "res://assets/audio/sfx/LvlResults/You Lose.mp3",
	"hit": "res://assets/audio/sfx/MP3/hurt2.mp3",
	"error": "res://assets/audio/sfx/MP3/error1.mp3",
	"unlock": "res://assets/audio/sfx/MP3/powerUp8.mp3",
	"fanfare": "res://assets/audio/sfx/LvlResults/Level Complete.mp3",
	"choir": "res://assets/audio/sfx/MP3/ahhhh-choir.mp3",
	"drumroll": "res://assets/audio/sfx/MP3/drum-roll-please-6921.mp3",
	"eat": "res://assets/audio/sfx/MP3/eating-sound-effect-36186.mp3",
	"brush_sound": "res://assets/audio/sfx/MP3/brushing-teeth.mp3",
	"stage_clear": "res://assets/audio/sfx/LvlResults/Stage Cleared.mp3",
	"pearly_whites": "res://assets/audio/sfx/LvlResults/Pearly Whites.mp3"
}

# Character Speech Voice Lines Mapping
const CHAR_VOICE_MAP = {
	"ash": "res://assets/audio/voices/alright Ash.mp3",
	"dash": "res://assets/audio/voices/Bring it on Dash.mp3",
	"flora": "res://assets/audio/voices/Let's do this Flora.mp3",
	"blaze": "res://assets/audio/voices/Mission Accepted Blaze.mp3",
	"spark": "res://assets/audio/voices/Spark Online .mp3",
	"sparkette": "res://assets/audio/voices/Spark Online .mp3",
	"nibbles": "res://assets/audio/voices/Time to eat Nibbles.mp3",
	"chef": "res://assets/audio/voices/Time to eat Nibbles.mp3",
	"chip": "res://assets/audio/voices/Lets Go Ace.mp3",   # Chip's voice line (was using Penelope's "Pearl" line)
	"penelope": "res://assets/audio/voices/Time to shine Pearl.mp3",
	"new_character": "res://assets/audio/voices/new character unlocked.mp3"
}

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)
	
	bgm_player = AudioStreamPlayer.new()
	bgm_player.bus = "Master"
	add_child(bgm_player)
	
	narration_player = AudioStreamPlayer.new()
	narration_player.bus = "Master"
	narration_player.finished.connect(_on_narration_finished)
	add_child(narration_player)
	
	for i in range(max_sfx_channels):
		var p = AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		sfx_players.append(p)
		
	_generate_procedural_fallbacks()
	_preload_sfx()

static func load_audio_file(path: String) -> AudioStream:
	if path == "":
		return null
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is AudioStream:
			return res
	var global_path = ProjectSettings.globalize_path(path)
	var check_path = global_path if FileAccess.file_exists(global_path) else (path if FileAccess.file_exists(path) else "")
	if check_path != "":
		var lower = check_path.to_lower()
		if lower.ends_with(".mp3"):
			var file = FileAccess.open(check_path, FileAccess.READ)
			if file:
				var stream = AudioStreamMP3.new()
				stream.data = file.get_buffer(file.get_length())
				return stream
		elif lower.ends_with(".wav"):
			var file = FileAccess.open(check_path, FileAccess.READ)
			if file:
				var stream = AudioStreamWAV.new()
				stream.data = file.get_buffer(file.get_length())
				return stream
		elif lower.ends_with(".ogg"):
			var stream = AudioStreamOggVorbis.load_from_file(check_path)
			if stream:
				return stream
	return null

func _preload_sfx():
	for sfx_name in SFX_FILE_MAP.keys():
		var path = SFX_FILE_MAP[sfx_name]
		var stream = load_audio_file(path)
		if stream:
			sfx_cache[sfx_name] = stream
			
	for char_key in CHAR_VOICE_MAP.keys():
		var path = CHAR_VOICE_MAP[char_key]
		var stream = load_audio_file(path)
		if stream:
			voice_cache[char_key] = stream

func _generate_procedural_fallbacks():
	if not sfx_cache.has("click"): sfx_cache["click"] = _create_beep_sample(600.0, 0.05, 0.5)
	if not sfx_cache.has("pop"): sfx_cache["pop"] = _create_pop_sample()
	if not sfx_cache.has("coin"): sfx_cache["coin"] = _create_coin_sample()
	if not sfx_cache.has("chime"): sfx_cache["chime"] = _create_coin_sample()
	if not sfx_cache.has("sparkle"): sfx_cache["sparkle"] = _create_beep_sample(1200.0, 0.15, 0.4)
	if not sfx_cache.has("victory"): sfx_cache["victory"] = _create_victory_jingle()
	if not sfx_cache.has("hit"): sfx_cache["hit"] = _create_hit_sample()
	if not sfx_cache.has("brush_tick"): sfx_cache["brush_tick"] = _create_beep_sample(880.0, 0.08, 0.3)
	if not sfx_cache.has("unlock"): sfx_cache["unlock"] = _create_fanfare_sample()
	if not sfx_cache.has("error"): sfx_cache["error"] = _create_beep_sample(220.0, 0.18, 0.6)

func _create_beep_sample(frequency: float, duration: float, volume: float = 0.5) -> AudioStreamWAV:
	var sample = AudioStreamWAV.new()
	sample.format = AudioStreamWAV.FORMAT_16_BITS
	sample.mix_rate = 44100
	sample.stereo = false
	var num_samples = int(44100 * duration)
	var data = PackedByteArray()
	data.resize(num_samples * 2)
	for i in range(num_samples):
		var t = float(i) / 44100.0
		var envelope = 1.0 - (float(i) / float(num_samples))
		var wave = sin(2.0 * PI * frequency * t) * envelope * volume
		var sample_val = int(clamp(wave * 32767.0, -32768.0, 32767.0))
		data.encode_s16(i * 2, sample_val)
	sample.data = data
	return sample

func _create_pop_sample() -> AudioStreamWAV:
	var sample = AudioStreamWAV.new()
	sample.format = AudioStreamWAV.FORMAT_16_BITS
	sample.mix_rate = 44100
	var duration = 0.08
	var num_samples = int(44100 * duration)
	var data = PackedByteArray()
	data.resize(num_samples * 2)
	for i in range(num_samples):
		var t = float(i) / 44100.0
		var freq = lerp(300.0, 900.0, float(i) / float(num_samples))
		var envelope = 1.0 - (float(i) / float(num_samples))
		var wave = sin(2.0 * PI * freq * t) * envelope * 0.7
		var sample_val = int(clamp(wave * 32767.0, -32768.0, 32767.0))
		data.encode_s16(i * 2, sample_val)
	sample.data = data
	return sample

func _create_coin_sample() -> AudioStreamWAV:
	var sample = AudioStreamWAV.new()
	sample.format = AudioStreamWAV.FORMAT_16_BITS
	sample.mix_rate = 44100
	var duration = 0.2
	var num_samples = int(44100 * duration)
	var data = PackedByteArray()
	data.resize(num_samples * 2)
	for i in range(num_samples):
		var t = float(i) / 44100.0
		var freq = 987.77 if t < 0.1 else 1318.51
		var envelope = 1.0 - (float(i) / float(num_samples))
		var wave = sin(2.0 * PI * freq * t) * envelope * 0.6
		var sample_val = int(clamp(wave * 32767.0, -32768.0, 32767.0))
		data.encode_s16(i * 2, sample_val)
	sample.data = data
	return sample

func _create_hit_sample() -> AudioStreamWAV:
	var sample = AudioStreamWAV.new()
	sample.format = AudioStreamWAV.FORMAT_16_BITS
	sample.mix_rate = 44100
	var duration = 0.12
	var num_samples = int(44100 * duration)
	var data = PackedByteArray()
	data.resize(num_samples * 2)
	for i in range(num_samples):
		var t = float(i) / 44100.0
		var noise = (randf() * 2.0 - 1.0)
		var freq = lerp(400.0, 80.0, float(i) / float(num_samples))
		var envelope = 1.0 - (float(i) / float(num_samples))
		var wave = (sin(2.0 * PI * freq * t) * 0.6 + noise * 0.4) * envelope * 0.7
		var sample_val = int(clamp(wave * 32767.0, -32768.0, 32767.0))
		data.encode_s16(i * 2, sample_val)
	sample.data = data
	return sample

func _create_victory_jingle() -> AudioStreamWAV:
	var sample = AudioStreamWAV.new()
	sample.format = AudioStreamWAV.FORMAT_16_BITS
	sample.mix_rate = 44100
	var duration = 0.8
	var num_samples = int(44100 * duration)
	var data = PackedByteArray()
	data.resize(num_samples * 2)
	var notes = [523.25, 659.25, 783.99, 1046.50]
	for i in range(num_samples):
		var t = float(i) / 44100.0
		var note_idx = int(t / 0.2)
		if note_idx >= notes.size(): note_idx = notes.size() - 1
		var freq = notes[note_idx]
		var local_t = fmod(t, 0.2)
		var envelope = 1.0 - (local_t / 0.2) * 0.7
		var wave = sin(2.0 * PI * freq * t) * envelope * 0.6
		var sample_val = int(clamp(wave * 32767.0, -32768.0, 32767.0))
		data.encode_s16(i * 2, sample_val)
	sample.data = data
	return sample

func _create_fanfare_sample() -> AudioStreamWAV:
	return _create_victory_jingle()

func play_sfx(name: String, pitch_scale: float = 1.0):
	if is_muted or master_volume <= 0.01 or sfx_volume <= 0.01:
		return
		
	var stream: AudioStream = null
	if sfx_cache.has(name):
		stream = sfx_cache[name]
	else:
		stream = load_audio_file(SFX_FILE_MAP.get(name, ""))
		if stream:
			sfx_cache[name] = stream
		
	if stream:
		for p in sfx_players:
			if not p.playing:
				p.stream = stream
				p.pitch_scale = pitch_scale
				p.volume_db = linear_to_db(sfx_volume * master_volume)
				p.set_meta("is_voice", false)
				p.play()
				return

func play_character_voice(char_id: String):
	if is_muted or not is_sound_enabled() or master_volume <= 0.01:
		return
	var key = char_id.to_lower().strip_edges()
	var stream: AudioStream = null
	if voice_cache.has(key):
		stream = voice_cache[key]
	elif CHAR_VOICE_MAP.has(key):
		stream = load_audio_file(CHAR_VOICE_MAP[key])
		if stream:
			voice_cache[key] = stream
			
	if stream:
		for p in sfx_players:
			if not p.playing:
				p.stream = stream
				p.pitch_scale = 1.0
				p.volume_db = linear_to_db(sfx_volume * master_volume * 1.1 * VOICE_GAIN)
				p.set_meta("is_voice", true)
				begin_voice_duck(stream.get_length() if stream.has_method("get_length") else 1.5)
				p.play()
				return

func set_sfx_volume(v: float):
	sfx_volume = clamp(v, 0.0, 1.0)
	if sfx_volume <= 0.01:
		stop_narration()
		for p in sfx_players:
			if p.playing and bool(p.get_meta("is_voice", false)):
				p.stop()

func set_bgm_volume(v: float):
	bgm_volume = clamp(v, 0.0, 1.0)
	if bgm_player:
		bgm_player.volume_db = linear_to_db(bgm_volume * master_volume)

func set_master_volume(v: float):
	master_volume = clamp(v, 0.0, 1.0)
	if bgm_player:
		bgm_player.volume_db = linear_to_db(bgm_volume * master_volume)

## Sets the master mute state (keeps music / narration in sync). Used by Settings and the brushing page.
func set_muted(muted: bool) -> void:
	if is_muted != muted:
		toggle_mute()

func set_sound_enabled(enabled: bool):
	sound_enabled = enabled
	if enabled:
		# Turning sounds ON must also clear a master mute set from the brushing page
		set_muted(false)
		sfx_volume = saved_sfx_volume if saved_sfx_volume > 0.01 else 0.85
	else:
		if sfx_volume > 0.01:
			saved_sfx_volume = sfx_volume
		sfx_volume = 0.0
		stop_narration()
		for p in sfx_players:
			if p.playing and bool(p.get_meta("is_voice", false)):
				p.stop()

func set_music_enabled(enabled: bool):
	music_enabled = enabled
	if enabled:
		# Turning music ON must also clear a master mute set from the brushing page
		set_muted(false)
		bgm_volume = saved_bgm_volume if saved_bgm_volume > 0.01 else 0.40
		if bgm_player:
			bgm_player.volume_db = linear_to_db(bgm_volume * master_volume)
			if not bgm_player.playing:
				if current_bgm_track_path != "":
					play_bgm(current_bgm_track_path, true)
				else:
					play_screen_bgm("settings")
	else:
		if bgm_volume > 0.01:
			saved_bgm_volume = bgm_volume
		bgm_volume = 0.0
		if bgm_player:
			bgm_player.volume_db = linear_to_db(0.0)
			bgm_player.stop()

func is_sound_enabled() -> bool:
	return sound_enabled and sfx_volume > 0.01 and not is_muted

func is_music_enabled() -> bool:
	return music_enabled and bgm_volume > 0.01 and not is_muted

func play_screen_bgm(screen_name: String):
	var track_path = SCREEN_BGM_MAP.get(screen_name, "")
	if track_path == "":
		return
		
	# Seamless continuation if already playing the exact track (e.g. Map <-> Character Setup)
	if current_bgm_track_path == track_path and bgm_player and bgm_player.playing:
		return
		
	current_bgm_track_path = track_path
	play_bgm(track_path, true)

func play_bgm(stream_or_path: Variant, loop: bool = true):
	if not bgm_player:
		return
	var stream: AudioStream = null
	if stream_or_path is AudioStream:
		stream = stream_or_path
	elif stream_or_path is String and stream_or_path != "":
		var p_str = str(stream_or_path)
		if bgm_cache.has(p_str):
			stream = bgm_cache[p_str]
		else:
			stream = load_audio_file(p_str)
			if stream:
				bgm_cache[p_str] = stream
				
	if stream:
		if stream is AudioStreamMP3:
			stream.loop = loop
		elif stream is AudioStreamOggVorbis:
			stream.loop = loop
			
		bgm_player.stream = stream
		bgm_player.volume_db = linear_to_db(bgm_volume * master_volume)
		if not is_muted and master_volume > 0.01 and bgm_volume > 0.01:
			bgm_player.play()

func stop_bgm():
	if bgm_player:
		bgm_player.stop()
	current_bgm_track_path = ""

func toggle_mute() -> bool:
	is_muted = not is_muted
	if bgm_player:
		if is_muted:
			bgm_player.stop()
		elif not bgm_player.playing and bgm_player.stream and master_volume > 0.01 and bgm_volume > 0.01:
			bgm_player.play()
	if narration_player and is_muted:
		narration_player.stop()
	if is_muted and DisplayServer.tts_is_speaking():
		DisplayServer.tts_stop()
	return is_muted

func is_auto_narration_preferred() -> bool:
	var p: Dictionary = {}
	var gs = get_node_or_null("/root/GameState")
	if gs and gs.has_method("get_active_profile"):
		p = gs.get_active_profile()
	var age = int(p.get("age", 0))
	if age >= 4 and age <= 6:
		return true
	if bool(p.get("auto_narration", false)):
		return true
	if bool(p.get("tts_enabled", false)):
		return true
	return tts_enabled

func is_narrating() -> bool:
	if narration_player and narration_player.playing and not narration_player.stream_paused:
		return true
	if DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH) and DisplayServer.tts_is_speaking() and not is_narration_paused:
		return true
	return false

func _get_british_english_voice_id() -> String:
	"""
	Get a British English voice ID for text-to-speech.
	Searches through available voices for en-GB or British English voices.
	Falls back to first available voice if none found.
	"""
	if not DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		return ""

	var voices = DisplayServer.tts_get_voices()
	if voices.size() == 0:
		return ""

	# First pass: Look for explicit en-GB or British voices
	for voice in voices:
		if typeof(voice) == TYPE_DICTIONARY:
			var voice_id = voice.get("id", "")
			var lang = voice.get("lang", "").to_lower()
			var name = voice.get("name", "").to_lower()

			# Check for British English language code or name
			if "en_gb" in lang or "en-gb" in lang or "british" in name or "gb" in name:
				return str(voice_id)
		elif typeof(voice) == TYPE_STRING:
			var voice_str = voice.to_lower()
			if "en_gb" in voice_str or "en-gb" in voice_str or "british" in voice_str or "gb" in voice_str:
				return str(voice)

	# Second pass: Look for any en-US or generic English voices (better than random)
	for voice in voices:
		if typeof(voice) == TYPE_DICTIONARY:
			var lang = voice.get("lang", "").to_lower()
			if "en_" in lang or "en-" in lang:
				return str(voice.get("id", ""))
		elif typeof(voice) == TYPE_STRING:
			var voice_str = voice.to_lower()
			if "en_" in voice_str or "en-" in voice_str:
				return str(voice)

	# Fallback: Return first available voice
	if typeof(voices[0]) == TYPE_DICTIONARY and voices[0].has("id"):
		return str(voices[0]["id"])
	elif typeof(voices[0]) == TYPE_STRING:
		return str(voices[0])

	return ""

func play_voice_narration(text: String, audio_path: String = "", force: bool = false):
	if (not tts_enabled and not force and not is_auto_narration_preferred()) or is_muted or not is_sound_enabled():
		return
	
	stop_narration()
	current_narration_text = text
	current_narration_audio = audio_path
	is_narration_paused = false
	
	# Duck BGM before the narration starts speaking
	begin_voice_duck(0.4 + text.length() * 0.06)
	
	var played_recorded = false
	if audio_path != "" and ResourceLoader.exists(audio_path):
		var res = load(audio_path)
		if res is AudioStream:
			narration_player.stream = res
			narration_player.volume_db = linear_to_db(sfx_volume * master_volume * VOICE_GAIN)
			narration_player.play()
			played_recorded = true
			
	if not played_recorded and text != "":
		if DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
			var voice_id = _get_british_english_voice_id()
			DisplayServer.tts_speak(text, voice_id)

## Call right before any voice starts (recorded line or text-to-speech) so the music dips first.
## hold_seconds keeps the music low for at least that long, even if the OS speech engine is slow
## to report that it is speaking.
func begin_voice_duck(hold_seconds: float = 1.0) -> void:
	var until := Time.get_ticks_msec() + int(max(0.3, hold_seconds) * 1000.0)
	_duck_hold_until_ms = max(_duck_hold_until_ms, until)
	_duck_amount = max(_duck_amount, 0.6)
	_apply_bgm_volume()

## Speaks text with the device voice (TTS), dipping the music first.
func speak_tts(text: String) -> void:
	if is_muted or not is_sound_enabled() or text == "":
		return
	if not DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		return
	begin_voice_duck(0.4 + text.length() * 0.06)
	DisplayServer.tts_speak(text, _get_british_english_voice_id())

func _is_voice_active() -> bool:
	if Time.get_ticks_msec() < _duck_hold_until_ms:
		return true
	if narration_player and narration_player.playing and not narration_player.stream_paused:
		return true
	for p in sfx_players:
		if p.playing and bool(p.get_meta("is_voice", false)):
			return true
	if not is_narration_paused and DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH) and DisplayServer.tts_is_speaking():
		return true
	return false

func _apply_bgm_volume() -> void:
	if not bgm_player:
		return
	var factor: float = lerp(1.0, VOICE_DUCK_FACTOR, _duck_amount)
	bgm_player.volume_db = linear_to_db(max(0.0001, bgm_volume * master_volume * factor))

func _process(delta: float) -> void:
	if not bgm_player or not bgm_player.playing:
		_duck_amount = 0.0
		return
	var target := 1.0 if _is_voice_active() else 0.0
	if target > _duck_amount:
		_duck_amount = min(target, _duck_amount + delta * DUCK_ATTACK_SPEED)
	elif target < _duck_amount:
		_duck_amount = max(target, _duck_amount - delta * DUCK_RELEASE_SPEED)
	_apply_bgm_volume()

func pause_narration():
	if narration_player and narration_player.playing:
		narration_player.stream_paused = true
	if DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH) and DisplayServer.tts_is_speaking():
		DisplayServer.tts_pause()
	is_narration_paused = true
	# Music comes back up while paused (_process fades it)
	_duck_hold_until_ms = 0

func resume_narration():
	if is_muted:
		return
	if narration_player and narration_player.stream_paused:
		narration_player.stream_paused = false
	if is_narration_paused:
		if DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
			DisplayServer.tts_resume()
	is_narration_paused = false
	begin_voice_duck(0.5)

func stop_narration():
	if narration_player:
		narration_player.stop()
		narration_player.stream_paused = false
	if DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH) and DisplayServer.tts_is_speaking():
		DisplayServer.tts_stop()
	is_narration_paused = false
	current_narration_text = ""
	current_narration_audio = ""
	# Music fades back up smoothly in _process once nothing is speaking
	_duck_hold_until_ms = 0

func toggle_narration(text: String, audio_path: String = "") -> bool:
	if is_narrating():
		pause_narration()
		return false
	elif is_narration_paused and current_narration_text == text:
		resume_narration()
		return true
	else:
		play_voice_narration(text, audio_path, true)
		return true

func _on_narration_finished():
	stop_narration()

func speak_text(text: String, force: bool = false):
	play_voice_narration(text, "", force)
