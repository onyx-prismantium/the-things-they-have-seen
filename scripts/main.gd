extends Node2D

## Boots the game: loads the case (already done by CaseLoader autoload),
## shows the briefing, then the room. Milestone M0 only needs this to exist
## so the project has a valid main scene; fleshed out through M1-M4.

const NOBODYWHO_PINNED_VERSION := "9.4.0" # BUILD_BRIEF.md §0.3, §2.2

func _ready() -> void:
	_log_nobodywho_status()
	if CaseLoader.current_case == null:
		push_error("Main: no case loaded")
		return
	print("Main: case '%s' ready" % CaseLoader.current_case.title)
	var room := get_node_or_null("RoomStudy")
	if room != null:
		room.object_selected.connect(_on_object_selected)

func _on_object_selected(object_id: String) -> void:
	print("Main: object selected -> %s" % object_id)

func _process(_delta: float) -> void:
	var shot_path := OS.get_environment("SCREENSHOT_PATH")
	if shot_path != "":
		await get_tree().process_frame
		await get_tree().process_frame
		_debug_simulate_hover()
		await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(shot_path)
		print("Main: screenshot saved to %s" % shot_path)
		get_tree().quit()

## Dev-only, gated behind env vars: exercises hover + economy without needing
## real mouse input, so a headless screenshot run can prove M1's accept
## criteria (hover shows name + pips; pips decrement).
func _debug_simulate_hover() -> void:
	var hover_id := OS.get_environment("DEBUG_HOVER_OBJECT")
	if hover_id == "":
		return
	var room := get_node_or_null("RoomStudy")
	if room == null:
		return
	var consume_n := int(OS.get_environment("DEBUG_CONSUME_N")) if OS.get_environment("DEBUG_CONSUME_N") != "" else 0
	for i: int in range(consume_n):
		GameState.consume_question(hover_id)
	var target := room.get_node_or_null(hover_id)
	if target != null and target.has_method("_on_mouse_entered"):
		target.call("_on_mouse_entered")

func _log_nobodywho_status() -> void:
	if ClassDB.class_exists("NobodyWhoChat") and ClassDB.class_exists("NobodyWhoModel"):
		print("NobodyWho: plugin loaded (pinned addon release v%s)" % NOBODYWHO_PINNED_VERSION)
	else:
		print("NobodyWho: plugin NOT loaded — run tools/install_nobodywho.sh (--mock-nlu still works without it)")
