extends Node

## Singleton: voice blips + UI sounds (BUILD_BRIEF.md §6.4).
## One shared AudioStreamPlayer per concurrent voice; slight random pitch_scale
## so repeats don't feel canned.

const BLIP_DIR := "res://assets/audio/blips/"
const PITCH_JITTER := 0.03

var _voice_player: AudioStreamPlayer
var _ui_player: AudioStreamPlayer
var _stream_cache: Dictionary = {} # path -> AudioStream

func _ready() -> void:
	_voice_player = AudioStreamPlayer.new()
	_voice_player.name = "VoicePlayer"
	add_child(_voice_player)
	_ui_player = AudioStreamPlayer.new()
	_ui_player.name = "UiPlayer"
	add_child(_ui_player)

func play_answer(object_id: String, answer: String) -> void:
	var path := "%s%s_%s.wav" % [BLIP_DIR, object_id, answer]
	var stream := _load_cached(path)
	if stream == null:
		return
	_voice_player.stream = stream
	_voice_player.pitch_scale = 1.0 + randf_range(-PITCH_JITTER, PITCH_JITTER)
	_voice_player.play()

func play_ui(sound_name: String) -> void:
	var path := "res://assets/audio/ui/%s.wav" % sound_name
	var stream := _load_cached(path)
	if stream == null:
		return
	_ui_player.stream = stream
	_ui_player.pitch_scale = 1.0
	_ui_player.play()

func _load_cached(path: String) -> AudioStream:
	if _stream_cache.has(path):
		return _stream_cache[path]
	if not ResourceLoader.exists(path):
		return null
	var stream: AudioStream = ResourceLoader.load(path)
	_stream_cache[path] = stream
	return stream
