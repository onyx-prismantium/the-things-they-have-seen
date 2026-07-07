class_name NluProvider
extends RefCounted

## Returns raw model output in the pipe format: "yes|fact-id" | "no|fact-id" | "huh|none"
## Must never throw; on internal failure return "huh|none".
func answer(_object_def: ObjectDef, _normalized_question: String) -> String:
	assert(false, "abstract")
	return "huh|none"

func warm_up() -> void:
	pass # load model / no-op

func is_ready() -> bool:
	return true
