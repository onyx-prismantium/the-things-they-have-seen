extends Node2D

## Boots the game: loads the case (already done by CaseLoader autoload),
## shows the briefing, then the room. Milestone M0 only needs this to exist
## so the project has a valid main scene; fleshed out through M1-M4.

const NOBODYWHO_PINNED_VERSION := "9.4.0" # BUILD_BRIEF.md §0.3, §2.2

@onready var _room: Node = $RoomStudy
@onready var _question_panel: QuestionPanel = $UILayer/QuestionPanel

func _ready() -> void:
	_log_nobodywho_status()
	if CaseLoader.current_case == null:
		push_error("Main: no case loaded")
		return
	print("Main: case '%s' ready" % CaseLoader.current_case.title)
	_room.object_selected.connect(_on_object_selected)
	_question_panel.answered.connect(_on_answered)
	if OS.get_environment("SELFTEST_M2") != "":
		await _run_selftest_m2()
		get_tree().quit()

func _on_object_selected(object_id: String) -> void:
	_question_panel.open_for(object_id)

func _on_answered(object_id: String, result: QAResult) -> void:
	var target: InteractiveObject = _room.get_node_or_null(object_id)
	if target != null:
		target.show_response(result)

func _process(_delta: float) -> void:
	var shot_path := OS.get_environment("SCREENSHOT_PATH")
	if shot_path != "":
		await get_tree().process_frame
		await get_tree().process_frame
		_debug_simulate_hover()
		await _debug_simulate_panel()
		await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(shot_path)
		print("Main: screenshot saved to %s" % shot_path)
		get_tree().quit()

func _debug_simulate_panel() -> void:
	var open_id := OS.get_environment("DEBUG_OPEN_PANEL")
	if open_id == "":
		return
	_question_panel.open_for(open_id)
	var question := OS.get_environment("DEBUG_ASK_QUESTION")
	if question != "":
		await _question_panel.ask_programmatically(question)

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

## Headless M2 pipeline self-test (SELFTEST_M2=1 env var). Exercises every
## golden sample_qa via the real NluService+MockProvider pipeline, then a
## dedicated economy scenario (consume/repeat-free/huh-free/unknown/exhausted).
func _run_selftest_m2() -> void:
	var the_case: CaseDef = CaseLoader.current_case
	var total := 0
	var correct := 0
	var failures: Array[String] = []
	for oid: String in the_case.object_ids:
		var obj: ObjectDef = the_case.objects[oid]
		for qa: SampleQADef in obj.sample_qa:
			GameState.reset_case()
			var result: QAResult = await NluService.ask(obj, qa.q)
			total += 1
			var ok: bool = result.answer == qa.a
			if qa.a != "huh":
				ok = ok and result.fact_id == qa.fact
			if ok:
				correct += 1
			else:
				failures.append("%s: '%s' expected %s|%s got %s|%s" % [oid, qa.q, qa.a, qa.fact, result.answer, result.fact_id])
	print("SELFTEST golden (mock): %d/%d correct" % [correct, total])
	for f: String in failures:
		print("  FAIL: ", f)

	GameState.reset_case()
	var poker: ObjectDef = the_case.objects["fireplace_poker"]
	var before_remaining := GameState.questions_remaining("fireplace_poker")
	var r1: QAResult = await NluService.ask(poker, "did you strike edmund")
	var after1 := GameState.questions_remaining("fireplace_poker")
	print("SELFTEST consume: before=%d after=%d answer=%s (expect after=before-1, answer=no)" % [before_remaining, after1, r1.answer])

	var r2: QAResult = await NluService.ask(poker, "did you strike edmund")
	var after2 := GameState.questions_remaining("fireplace_poker")
	print("SELFTEST repeat-free: after=%d (expect %d) from_cache=%s" % [after2, after1, r2.from_cache])

	var r3: QAResult = await NluService.ask(poker, "did you kill edmund")
	var after3 := GameState.questions_remaining("fireplace_poker")
	print("SELFTEST huh-free: after=%d (expect %d) answer=%s (expect huh)" % [after3, after1, r3.answer])

	var r4: QAResult = await NluService.ask(poker, "does this poker enjoy classical music")
	print("SELFTEST unknown->huh: answer=%s (expect huh)" % r4.answer)

	GameState.reset_case()
	await NluService.ask(poker, "did you strike edmund")
	await NluService.ask(poker, "did you touch his blood")
	await NluService.ask(poker, "did a gloved hand hold you that night")
	var tired: QAResult = await NluService.ask(poker, "did someone force the window latch with you")
	print("SELFTEST exhausted: remaining=%d answer=%s flavor='%s' (expect remaining=0, answer=huh, tired flavor)" % [GameState.questions_remaining("fireplace_poker"), tired.answer, tired.flavor_line])

func _log_nobodywho_status() -> void:
	if ClassDB.class_exists("NobodyWhoChat") and ClassDB.class_exists("NobodyWhoModel"):
		print("NobodyWho: plugin loaded (pinned addon release v%s)" % NOBODYWHO_PINNED_VERSION)
	else:
		print("NobodyWho: plugin NOT loaded — run tools/install_nobodywho.sh (--mock-nlu still works without it)")
