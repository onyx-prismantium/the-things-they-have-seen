extends Node2D

## The study (BUILD_BRIEF.md §6.1): a single 2D scene, static background,
## instantiated InteractiveObject children. No walking avatar — the cursor is
## Laura. Re-broadcasts each object's `clicked` signal upward so Main can open
## the Question Panel for it (wired in M2).

signal object_selected(object_id: String)

func _ready() -> void:
	for child: Node in get_children():
		if child is InteractiveObject:
			(child as InteractiveObject).clicked.connect(_on_object_clicked)

func _on_object_clicked(object_id: String) -> void:
	object_selected.emit(object_id)

func all_object_ids() -> Array[String]:
	var ids: Array[String] = []
	for child: Node in get_children():
		if child is InteractiveObject:
			ids.append((child as InteractiveObject).object_id)
	return ids
