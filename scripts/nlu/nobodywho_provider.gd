class_name NobodyWhoProvider
extends NluProvider

## ONLY file that touches the NobodyWho plugin (BUILD_BRIEF.md §3.4/§0.3).
## Fleshed out in milestone M3 once the addon is installed and its real API
## surface is verified against addons/nobodywho/ and https://docs.nobodywho.ooo/godot/.
## Until then this stub keeps the project compiling and reports "not ready" so
## NluService falls back to --mock-nlu.

var _model_node: Node = null
var _chat_nodes: Dictionary = {} # object_id -> Node (one NobodyWhoChat per object, prompt cached)
var _model_path: String = ""
var _ready: bool = false
var _host: Node = null

func _init(host: Node, model_path: String) -> void:
	_host = host
	_model_path = model_path

func is_ready() -> bool:
	return _ready

func warm_up() -> void:
	pass

func answer(_object_def: ObjectDef, _normalized_question: String) -> String:
	return "huh|none"
