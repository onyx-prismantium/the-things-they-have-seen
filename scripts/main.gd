extends Node2D

## Boots the game: loads the case (already done by CaseLoader autoload),
## shows the briefing, then the room. Milestone M0 only needs this to exist
## so the project has a valid main scene; fleshed out through M1-M4.

const NOBODYWHO_PINNED_VERSION := "9.4.0" # BUILD_BRIEF.md §0.3, §2.2

@onready var _room: Node = $RoomStudy
@onready var _question_panel: QuestionPanel = $UILayer/QuestionPanel
@onready var _ui_layer: CanvasLayer = $UILayer
@onready var _deduction_board: DeductionBoard = $UILayer/DeductionBoard
@onready var _present_deduction_button: Button = $UILayer/PresentDeductionButton
@onready var _case_briefing: CaseBriefing = $UILayer/CaseBriefing
@onready var _end_screen: EndScreen = $UILayer/EndScreen

var _boot_screen: Control = null

func _ready() -> void:
	_log_nobodywho_status()
	if CaseLoader.current_case == null:
		push_error("Main: no case loaded")
		return
	print("Main: case '%s' ready" % CaseLoader.current_case.title)
	_room.object_selected.connect(_on_object_selected)
	_question_panel.answered.connect(_on_answered)
	_present_deduction_button.pressed.connect(_on_present_deduction_pressed)
	_case_briefing.finished.connect(_on_briefing_finished)

	if not NluService.is_mock() and NluService.model_missing():
		_show_model_missing_screen()
	elif not NluService.is_mock():
		print("NluService: warming up NobodyWho worker (model=%s)..." % NluService.expected_model_path().get_file())

	if OS.get_environment("SELFTEST_M2") != "":
		await _run_selftest_m2()
		get_tree().quit()

	if OS.get_environment("SELFTEST_M3_SINGLE") != "":
		await _run_selftest_m3_single()
		get_tree().quit()

	if OS.get_environment("SELFTEST_M3_GOLDEN") != "":
		await _run_selftest_m3_golden()
		get_tree().quit()

	if OS.get_environment("SELFTEST_M4") != "":
		await _run_selftest_m4()
		get_tree().quit()

## BUILD_BRIEF.md §2.3: "Add a boot check with a clear 'place model file here'
## error screen listing the expected path + filename." Built procedurally —
## this is a one-off system message, not case content, so it doesn't warrant
## its own authored scene.
func _show_model_missing_screen() -> void:
	_boot_screen = PanelContainer.new()
	_boot_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui_layer.add_child(_boot_screen)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 120)
	margin.add_theme_constant_override("margin_top", 120)
	margin.add_theme_constant_override("margin_right", 120)
	margin.add_theme_constant_override("margin_bottom", 120)
	_boot_screen.add_child(margin)

	var vbox := VBoxContainer.new()
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "No local model found"
	title.add_theme_font_size_override("font_size", 32)
	vbox.add_child(title)

	var body := Label.new()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.text = "The Things They Have Seen needs a local GGUF model to talk to objects.\n\nExpected file:\n%s\n\nSee docs/MODEL_SETUP.md for download instructions, or launch with --mock-nlu to play against the scripted mock provider instead." % NluService.expected_model_path()
	vbox.add_child(body)

func _on_object_selected(object_id: String) -> void:
	if _boot_screen != null or GameState.case_is_over:
		return
	_question_panel.open_for(object_id)

func _on_answered(object_id: String, result: QAResult) -> void:
	var target: InteractiveObject = _room.get_node_or_null(object_id)
	if target != null:
		target.show_response(result)

func _on_present_deduction_pressed() -> void:
	if GameState.case_is_over:
		return
	_deduction_board.open_board()

func _on_briefing_finished() -> void:
	pass # room is already visible underneath; briefing was just an overlay

func _process(_delta: float) -> void:
	var shot_path := OS.get_environment("SCREENSHOT_PATH")
	if shot_path != "":
		await get_tree().process_frame
		await get_tree().process_frame
		_debug_simulate_hover()
		_debug_simulate_win()
		await _debug_simulate_panel()
		await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(shot_path)
		print("Main: screenshot saved to %s" % shot_path)
		get_tree().quit()

func _debug_simulate_win() -> void:
	if OS.get_environment("DEBUG_SIMULATE_WIN") == "":
		return
	var the_case: CaseDef = CaseLoader.current_case
	var solution: Dictionary = the_case.solution
	GameState.reset_case()
	GameState.submit_deduction(String(solution.culprit), String(solution.motive), String(solution.weapon))

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

## Quick live-model smoke test (SELFTEST_M3_SINGLE=1): waits for the worker,
## asks one known question, prints the raw+parsed result and latency.
func _run_selftest_m3_single() -> void:
	print("SELFTEST_M3_SINGLE: waiting for NobodyWho worker...")
	var waited_ms := 0
	while not NluService.is_ready() and waited_ms < 120000:
		await get_tree().create_timer(0.5).timeout
		waited_ms += 500
	print("SELFTEST_M3_SINGLE: worker ready=%s after %dms" % [NluService.is_ready(), waited_ms])
	if not NluService.is_ready():
		return
	var poker: ObjectDef = CaseLoader.current_case.objects["fireplace_poker"]
	var result: QAResult = await NluService.ask(poker, "did you strike edmund")
	print("SELFTEST_M3_SINGLE result: answer=%s fact=%s latency=%dms" % [result.answer, result.fact_id, result.latency_ms])

## M3 gate (§7): all 61 golden sample_qa answered by the live model. Targets:
## >=95% yes/no accuracy, >=90% huh accuracy, median latency <=2s.
func _run_selftest_m3_golden() -> void:
	print("SELFTEST_M3_GOLDEN: waiting for NobodyWho worker...")
	var waited_ms := 0
	while not NluService.is_ready() and waited_ms < 120000:
		await get_tree().create_timer(0.5).timeout
		waited_ms += 500
	print("SELFTEST_M3_GOLDEN: worker ready=%s after %dms" % [NluService.is_ready(), waited_ms])
	if not NluService.is_ready():
		return

	var the_case: CaseDef = CaseLoader.current_case
	var yn_total := 0
	var yn_correct := 0
	var huh_total := 0
	var huh_correct := 0
	var latencies: Array[int] = []
	var failures: Array[String] = []

	for oid: String in the_case.object_ids:
		var obj: ObjectDef = the_case.objects[oid]
		for qa: SampleQADef in obj.sample_qa:
			GameState.reset_case()
			var result: QAResult = await NluService.ask(obj, qa.q)
			latencies.append(result.latency_ms)
			if qa.a == "huh":
				huh_total += 1
				if result.answer == "huh":
					huh_correct += 1
				else:
					failures.append("%s: '%s' expected huh got %s|%s" % [oid, qa.q, result.answer, result.fact_id])
			else:
				yn_total += 1
				if result.answer == qa.a and result.fact_id == qa.fact:
					yn_correct += 1
				else:
					failures.append("%s: '%s' expected %s|%s got %s|%s" % [oid, qa.q, qa.a, qa.fact, result.answer, result.fact_id])

	latencies.sort()
	var p50: int = latencies[latencies.size() / 2] if latencies.size() > 0 else 0
	var p95: int = latencies[int(latencies.size() * 0.95)] if latencies.size() > 0 else 0

	print("SELFTEST_M3_GOLDEN: yes/no %d/%d (%.1f%%), huh %d/%d (%.1f%%), latency p50=%dms p95=%dms" % [
		yn_correct, yn_total, 100.0 * yn_correct / maxi(1, yn_total),
		huh_correct, huh_total, 100.0 * huh_correct / maxi(1, huh_total),
		p50, p95,
	])
	for f: String in failures:
		print("  FAIL: ", f)

## M4 gate (§7): full playthrough to win and to lose on mock; softlock demo.
func _run_selftest_m4() -> void:
	var the_case: CaseDef = CaseLoader.current_case
	var solution: Dictionary = the_case.solution

	# --- WIN: walk the intended solve path (§5.5), then submit the true solution.
	GameState.reset_case()
	var solve_path: Array = [
		["bay_window", "was your latch broken from inside the room"],
		["bay_window", "did you see silas crane that night"],
		["bay_window", "did edmund wave a torn page at silas"],
		["iron_cashbox", "were you opened with your own key"],
		["persian_rug", "did a stranger walk on you that night"],
		["fireplace_poker", "did you strike edmund"],
		["marble_mantelpiece", "did edmund's head strike you"],
		["marble_mantelpiece", "was he pushed"],
		["persian_rug", "did edmund fall near the fireplace"],
		["brandy_glasses", "did silas crane drink here that night"],
		["persian_rug", "did silas stand over edmund's body"],
		["leather_ledger", "did silas crane write in you"],
		["leather_ledger", "were your figures altered"],
		["fire_grate", "was it a page from a ledger"],
	]
	for step: Array in solve_path:
		var obj: ObjectDef = the_case.objects[String(step[0])]
		await NluService.ask(obj, String(step[1]))
	var win_correct := GameState.submit_deduction(String(solution.culprit), String(solution.motive), String(solution.weapon))
	print("SELFTEST_M4 win: correct=%d/3 case_is_over=%s (expect 3/3, true)" % [win_correct, GameState.case_is_over])

	# --- LOSE: three wrong deductions in a row.
	GameState.reset_case()
	var wrong_culprit := ""
	for s: Dictionary in the_case.suspects:
		if String(s.get("id", "")) != String(solution.culprit):
			wrong_culprit = String(s.get("id", ""))
			break
	var last_correct := -1
	for attempt: int in range(3):
		last_correct = GameState.submit_deduction(wrong_culprit, "simple-robbery", "walking-cane")
	print("SELFTEST_M4 lose: attempts_left=%d case_is_over=%s last_correct=%d (expect 0, true, 0)" % [GameState.deduction_attempts_left, GameState.case_is_over, last_correct])

	# --- SOFTLOCK: exhaust every object supporting "weapon" (mantel, rug, grate)
	# without learning any of its solution_support facts, with Focus already spent.
	GameState.reset_case()
	GameState.focus_available = false
	for oid: String in ["marble_mantelpiece", "persian_rug", "fire_grate"]:
		for i: int in range(GameState.MAX_QUESTIONS_PER_OBJECT):
			GameState.consume_question(oid)
	GameState.check_softlock()
	var weapon_softlocked: bool = bool(GameState.softlocked_components.get("weapon", false))
	print("SELFTEST_M4 softlock: weapon=%s (expect true); culprit=%s motive=%s (expect false, still reachable elsewhere)" % [
		weapon_softlocked,
		GameState.softlocked_components.get("culprit", false),
		GameState.softlocked_components.get("motive", false),
	])

func _log_nobodywho_status() -> void:
	if ClassDB.class_exists("NobodyWhoChat") and ClassDB.class_exists("NobodyWhoModel"):
		print("NobodyWho: plugin loaded (pinned addon release v%s)" % NOBODYWHO_PINNED_VERSION)
	else:
		print("NobodyWho: plugin NOT loaded — run tools/install_nobodywho.sh (--mock-nlu still works without it)")
