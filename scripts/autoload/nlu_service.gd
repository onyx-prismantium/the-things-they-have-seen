extends Node

## Singleton: question queue -> provider -> QAResult (BUILD_BRIEF.md §3.3).
## Owns the FIFO queue (one in-flight request max), cache lookup, normalization,
## and the active NluProvider. Provider chosen by --mock-nlu cmdline flag.

signal request_started(object_id: String)
signal request_finished(object_id: String, result: QAResult)

const MODEL_RELATIVE_PATH := "models/qwen3-0.6b-q4_k_m.gguf"

var _provider: NluProvider = null
var _busy: bool = false

func _ready() -> void:
	_select_provider()

func _select_provider() -> void:
	if _use_mock():
		_provider = MockProvider.new()
		print("NluService: using MockProvider (--mock-nlu)")
	else:
		var model_path := "%s/%s" % [OS.get_user_data_dir(), MODEL_RELATIVE_PATH]
		_provider = NobodyWhoProvider.new(self, model_path)
		print("NluService: using NobodyWhoProvider, model_path=%s" % model_path)

func _use_mock() -> bool:
	return "--mock-nlu" in OS.get_cmdline_args() or "--mock-nlu" in OS.get_cmdline_user_args()

func is_mock() -> bool:
	return _provider is MockProvider

func is_ready() -> bool:
	return _provider != null and _provider.is_ready()

func warm_up() -> void:
	if _provider != null:
		_provider.warm_up()

## Public API. Returns a QAResult; never throws (degrades to huh|none on any
## internal failure, per the provider contract).
func ask(object_def: ObjectDef, raw_question: String) -> QAResult:
	var normalized := PromptBuilder.normalize(raw_question)
	var key := PromptBuilder.cache_key(object_def.id, normalized)

	var cached: QAResult = GameState.cache_get(key)
	if cached != null:
		var repeat_result := QAResult.new()
		repeat_result.answer = cached.answer
		repeat_result.fact_id = cached.fact_id
		repeat_result.from_cache = true
		repeat_result.is_repeat = true
		repeat_result.flavor_line = object_def.random_voice_line("repeat")
		GameState.add_transcript_entry(object_def.id, raw_question, repeat_result)
		request_finished.emit(object_def.id, repeat_result)
		return repeat_result

	# FIFO, max depth 1: further input is locked by the UI while busy, but guard here too.
	while _busy:
		await get_tree().process_frame

	_busy = true
	request_started.emit(object_def.id)

	var start_ms := Time.get_ticks_msec()
	var raw := "huh|none"
	if _provider != null:
		raw = await _provider.answer(object_def, normalized)
	var latency_ms := int(Time.get_ticks_msec() - start_ms)

	var parsed := PromptBuilder.parse_raw(raw)
	var validated := PromptBuilder.validate(object_def, String(parsed[0]), String(parsed[1]))

	var result := QAResult.new()
	result.answer = String(validated[0])
	result.fact_id = String(validated[1])
	result.from_cache = false
	result.is_repeat = false
	result.latency_ms = latency_ms
	result.flavor_line = object_def.random_voice_line(result.answer)

	if OS.is_debug_build() or ProjectSettings.get_setting("game/debug_nlu", false):
		print("NLU[%s] q='%s' raw='%s' -> %s|%s (%dms)" % [
			object_def.id, normalized, raw, result.answer, result.fact_id, latency_ms
		])

	GameState.cache_put(key, result)
	GameState.add_transcript_entry(object_def.id, raw_question, result)
	GameState.record_answer(object_def.id, result)

	_busy = false
	request_finished.emit(object_def.id, result)
	return result
