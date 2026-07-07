extends SceneTree

## Headless paraphrase consistency harness (BUILD_BRIEF.md §8.2).
## Run: godot --headless --path . -s res://tests/run_harness.gd -- --runs 3
## Writes user://harness/report.csv (object, question, expected, got, fact,
## run, latency_ms) and prints a summary: accuracy per class, flip rate
## across runs, latency p50/p95.
##
## NOTE: autoload singletons are NOT resolvable as bare global identifiers
## from a -s entry script (only from scripts compiled via the normal main-
## scene boot path) — always go through get_node("/root/Name") here, never
## "CaseLoader"/"NluService"/"GameState" directly. Confirmed empirically
## during M0 (a bare reference is a parse-time "Identifier not found" error).

func _initialize() -> void:
	# root isn't resolvable via absolute get_node() paths until the tree has
	# processed at least one frame after autoloads are added.
	await process_frame

	var args := OS.get_cmdline_user_args()
	var runs := 3
	for i: int in range(args.size()):
		if args[i] == "--runs" and i + 1 < args.size():
			runs = int(args[i + 1])

	var case_loader: Node = get_root().get_node("/root/CaseLoader")
	var nlu_service: Node = get_root().get_node("/root/NluService")
	var game_state: Node = get_root().get_node("/root/GameState")

	if bool(nlu_service.call("is_mock")):
		print("HARNESS: refusing to run against MockProvider — the harness measures the")
		print("HARNESS: live model. Launch without --mock-nlu.")
		quit(1)
		return

	print("HARNESS: waiting for NobodyWho worker (runs=%d)..." % runs)
	var waited_ms := 0
	while not bool(nlu_service.call("is_ready")) and waited_ms < 120000:
		await create_timer(0.5).timeout
		waited_ms += 500
	if not bool(nlu_service.call("is_ready")):
		print("HARNESS: provider not ready after 120s, aborting")
		quit(1)
		return

	var the_case: CaseDef = case_loader.get("current_case")
	var paraphrases_text := FileAccess.get_file_as_string("res://tests/paraphrases.json")
	var parsed: Variant = JSON.parse_string(paraphrases_text)
	var paraphrases: Dictionary = parsed as Dictionary

	var rows: Array[String] = ["object,question,expected,got,fact,run,latency_ms"]
	var yn_total := 0
	var yn_correct := 0
	var huh_total := 0
	var huh_correct := 0
	var flip_count := 0
	var flip_total := 0
	var latencies: Array[int] = []
	var per_object_total: Dictionary = {}
	var per_object_correct: Dictionary = {}

	var fact_entries: Array = paraphrases.get("fact_paraphrases", [])
	for entry_v: Variant in fact_entries:
		var entry: Dictionary = entry_v as Dictionary
		var oid: String = String(entry.get("object_id", ""))
		var fact_id: String = String(entry.get("fact_id", ""))
		var expected: String = String(entry.get("expected", ""))
		var obj: ObjectDef = the_case.objects[oid]
		var question_list: Array = entry.get("paraphrases", [])
		for question_v: Variant in question_list:
			var question: String = String(question_v)
			var answers_seen: Dictionary = {}
			for run_i: int in range(runs):
				game_state.call("reset_case")
				var result: QAResult = await nlu_service.call("ask", obj, question)
				rows.append("%s,\"%s\",%s,%s,%s,%d,%d" % [oid, question.replace("\"", "'"), expected, result.answer, result.fact_id, run_i, result.latency_ms])
				latencies.append(result.latency_ms)
				answers_seen[result.answer] = true
				per_object_total[oid] = int(per_object_total.get(oid, 0)) + 1
				var ok: bool = result.answer == expected and result.fact_id == fact_id
				if ok:
					per_object_correct[oid] = int(per_object_correct.get(oid, 0)) + 1
				yn_total += 1
				if ok:
					yn_correct += 1
			flip_total += 1
			if answers_seen.size() > 1:
				flip_count += 1

	var huh_probes: Dictionary = paraphrases.get("huh_probes", {})
	for oid: String in huh_probes.keys():
		var obj: ObjectDef = the_case.objects[oid]
		var questions: Array = huh_probes[oid]
		for question_v: Variant in questions:
			var question: String = String(question_v)
			for run_i: int in range(runs):
				game_state.call("reset_case")
				var result: QAResult = await nlu_service.call("ask", obj, question)
				rows.append("%s,\"%s\",huh,%s,%s,%d,%d" % [oid, question.replace("\"", "'"), result.answer, result.fact_id, run_i, result.latency_ms])
				latencies.append(result.latency_ms)
				per_object_total[oid] = int(per_object_total.get(oid, 0)) + 1
				huh_total += 1
				if result.answer == "huh":
					huh_correct += 1
					per_object_correct[oid] = int(per_object_correct.get(oid, 0)) + 1

	DirAccess.make_dir_recursive_absolute("user://harness")
	var f := FileAccess.open("user://harness/report.csv", FileAccess.WRITE)
	f.store_string("\n".join(rows))
	f.close()

	latencies.sort()
	var p50: int = latencies[latencies.size() / 2] if latencies.size() > 0 else 0
	var p95: int = latencies[int(latencies.size() * 0.95)] if latencies.size() > 0 else 0

	print("HARNESS yes/no: %d/%d (%.1f%%) [target >=95%%]" % [yn_correct, yn_total, 100.0 * yn_correct / maxi(1, yn_total)])
	print("HARNESS huh: %d/%d (%.1f%%) [target >=90%%]" % [huh_correct, huh_total, 100.0 * huh_correct / maxi(1, huh_total)])
	print("HARNESS flip rate: %d/%d (%.1f%%) [target <=2%%]" % [flip_count, flip_total, 100.0 * flip_count / maxi(1, flip_total)])
	print("HARNESS latency p50=%dms p95=%dms [target <=2000ms]" % [p50, p95])
	print("HARNESS per-object accuracy:")
	for oid: String in per_object_total.keys():
		var total: int = int(per_object_total[oid])
		var correct: int = int(per_object_correct.get(oid, 0))
		print("  %s: %d/%d (%.1f%%)" % [oid, correct, total, 100.0 * correct / maxi(1, total)])
	print("HARNESS report written to %s" % ProjectSettings.globalize_path("user://harness/report.csv"))
	quit(0)
