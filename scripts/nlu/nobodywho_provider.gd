class_name NobodyWhoProvider
extends NluProvider

## ONLY file that touches the NobodyWho plugin (BUILD_BRIEF.md §3.4/§0.3).
## Verified against the installed v9.4.0 addon (ClassDB introspection, not
## just the docs): NobodyWhoModel{model_path, use_gpu_if_available},
## NobodyWhoChat{model_node, system_prompt, allow_thinking, context_length;
## start_worker(), ask(), reset_context(), set_sampler_preset_constrain_with_grammar();
## signals response_updated, response_finished, worker_started, worker_failed, ready}.
##
## One shared NobodyWhoModel + one NobodyWhoChat, created in code and owned by
## the host (NluService). Grammar/system_prompt are precomputed per object at
## case load (CaseLoader -> PromptBuilder) and cached on ObjectDef; this class
## just applies them per request. system_prompt is re-set on every request
## rather than relying on reset_context() preserving it (§3.4 guidance) —
## cheap, and avoids depending on undocumented behavior.

const TIMEOUT_SECONDS := 8.0

var _model_path: String = ""
var _host: Node = null
var _model_node: Node = null
var _chat_node: Node = null
var _ready: bool = false
var _model_file_missing: bool = false
var _worker_started: bool = false

func _init(host: Node, model_path: String) -> void:
	_host = host
	_model_path = model_path
	_model_file_missing = not FileAccess.file_exists(model_path)

func model_file_missing() -> bool:
	return _model_file_missing

func model_path() -> String:
	return _model_path

func is_ready() -> bool:
	return _ready

func warm_up() -> void:
	if _model_file_missing:
		push_error("NobodyWhoProvider: model file not found at %s" % _model_path)
		return
	if _model_node != null:
		return # already warmed up
	if not ClassDB.class_exists("NobodyWhoModel") or not ClassDB.class_exists("NobodyWhoChat"):
		push_error("NobodyWhoProvider: NobodyWho addon not loaded — run tools/install_nobodywho.sh")
		return

	_model_node = ClassDB.instantiate("NobodyWhoModel")
	_model_node.model_path = _model_path
	_model_node.use_gpu_if_available = true
	_host.add_child(_model_node)

	_chat_node = ClassDB.instantiate("NobodyWhoChat")
	_chat_node.model_node = _model_node
	_chat_node.allow_thinking = false # belt-and-suspenders alongside the /no_think prompt line
	_chat_node.worker_failed.connect(_on_worker_failed)
	_host.add_child(_chat_node)
	_chat_node.start_worker()

	await _chat_node.worker_started
	_worker_started = true
	_ready = true
	print("NobodyWhoProvider: worker started, model=%s" % _model_path.get_file())

func _on_worker_failed(error: String) -> void:
	push_error("NobodyWhoProvider: worker failed: %s" % error)
	_ready = false

## Never throws; degrades to "huh|none" on any internal failure (missing
## model, worker not ready, or an 8s timeout — logged as TIMEOUT).
func answer(object_def: ObjectDef, normalized_question: String) -> String:
	if _model_file_missing or _chat_node == null or not _ready:
		return "huh|none"

	_chat_node.system_prompt = object_def.system_prompt
	_chat_node.set_sampler_preset_constrain_with_grammar(object_def.grammar)
	_chat_node.reset_context()

	# A Dictionary, not plain locals: GDScript lambdas capture value-type
	# locals by snapshot, not reference, so a bool/String written inside the
	# signal callback would never be visible to this polling loop otherwise.
	var state := {"done": false, "raw_text": ""}
	var on_finished := func(text: String) -> void:
		state.raw_text = text
		state.done = true
	_chat_node.response_finished.connect(on_finished, CONNECT_ONE_SHOT)

	_chat_node.ask(normalized_question)

	var deadline_ms: int = Time.get_ticks_msec() + int(TIMEOUT_SECONDS * 1000)
	while not bool(state.done):
		if Time.get_ticks_msec() >= deadline_ms:
			if _chat_node.response_finished.is_connected(on_finished):
				_chat_node.response_finished.disconnect(on_finished)
			_chat_node.stop_generation()
			push_error("NobodyWhoProvider: TIMEOUT after %.1fs on '%s'" % [TIMEOUT_SECONDS, normalized_question])
			return "huh|none"
		await _host.get_tree().process_frame

	return String(state.raw_text)
