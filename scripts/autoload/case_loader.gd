extends Node

## Loads and validates data/cases/<id>/case.json + objects/*.json into typed
## RefCounted classes (CaseDef, ObjectDef, FactDef). Fails loudly on schema
## errors: missing fact ids, duplicate ids, solution ids not in lists,
## redundancy check (BUILD_BRIEF.md §5.1, §5.6).

const DEFAULT_CASE_ID := "silent_study"
const CASE_ROOT := "res://data/cases/"

var current_case: CaseDef = null

func _ready() -> void:
	current_case = load_case(DEFAULT_CASE_ID)
	if "--check-data" in OS.get_cmdline_args() or "--check-data" in OS.get_cmdline_user_args():
		_print_check_data_and_quit()

func load_case(case_id: String) -> CaseDef:
	var case_dir := "%s%s/" % [CASE_ROOT, case_id]
	var case_json_path := case_dir + "case.json"
	var case_dict := _read_json(case_json_path)
	if case_dict.is_empty():
		push_error("CaseLoader: could not read/parse %s" % case_json_path)
		return null
	var c := CaseDef.from_json(case_dict)

	for object_id: String in c.object_ids:
		var obj_path := "%sobjects/%s.json" % [case_dir, object_id]
		var obj_dict := _read_json(obj_path)
		if obj_dict.is_empty():
			push_error("CaseLoader: could not read/parse %s" % obj_path)
			continue
		var obj := ObjectDef.from_json(obj_dict)
		c.objects[object_id] = obj

	_precompute_prompts(c)
	_validate(c)
	return c

func _precompute_prompts(c: CaseDef) -> void:
	var people_names: Dictionary = {}
	for p: Dictionary in c.people:
		people_names[String(p.get("id", ""))] = String(p.get("name", ""))
	for oid: String in c.object_ids:
		var obj: ObjectDef = c.objects.get(oid)
		if obj == null:
			continue
		obj.system_prompt = PromptBuilder.build_system_prompt(obj, people_names)
		obj.grammar = PromptBuilder.build_grammar(obj)

func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var text := f.get_as_text()
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed as Dictionary

## Fails loudly (push_error) on any schema violation; does not halt loading so
## the full list of problems surfaces in one pass.
func _validate(c: CaseDef) -> void:
	var errors: Array[String] = []
	var seen_fact_ids: Dictionary = {}

	for oid: String in c.object_ids:
		var obj: ObjectDef = c.objects.get(oid)
		if obj == null:
			errors.append("object '%s' listed in case.json but file missing/unparsable" % oid)
			continue
		for f: FactDef in obj.facts:
			if seen_fact_ids.has(f.id):
				errors.append("duplicate fact id '%s' (also on %s)" % [f.id, seen_fact_ids[f.id]])
			seen_fact_ids[f.id] = oid
		for qa: SampleQADef in obj.sample_qa:
			if qa.fact != "none" and not obj.has_fact(qa.fact):
				errors.append("object '%s' sample_qa references unknown fact '%s'" % [oid, qa.fact])

	for component: String in ["culprit", "motive", "weapon"]:
		var solved_id: String = String(c.solution.get(component, ""))
		var list_key := "suspects"
		var valid_list: Array[Dictionary] = c.suspects
		if component == "motive":
			list_key = "motives"
			valid_list = c.motives
		elif component == "weapon":
			list_key = "weapons"
			valid_list = c.weapons
		var found := false
		for entry: Dictionary in valid_list:
			if String(entry.get("id", "")) == solved_id:
				found = true
				break
		if not found:
			errors.append("solution.%s = '%s' not found in %s list" % [component, solved_id, list_key])

	for component: String in c.solution_support.keys():
		var fact_ids: Array = c.solution_support[component]
		var owning_objects: Dictionary = {}
		for fid: String in fact_ids:
			if not seen_fact_ids.has(fid):
				errors.append("solution_support.%s references unknown fact '%s'" % [component, fid])
				continue
			owning_objects[seen_fact_ids[fid]] = true
		if owning_objects.size() < 3:
			errors.append("redundancy violation: solution_support.%s spans only %d distinct object(s) (need >= 3)" % [component, owning_objects.size()])

	for fid: String in c.elimination_facts:
		if not seen_fact_ids.has(fid):
			errors.append("elimination_facts references unknown fact '%s'" % fid)

	for err: String in errors:
		push_error("CaseLoader validation: %s" % err)

	if errors.is_empty():
		print("CaseLoader: case '%s' valid — %d objects, %d facts, %d golden QAs" % [
			c.id, c.object_ids.size(), c.total_facts(), c.total_sample_qa()
		])
	else:
		push_error("CaseLoader: %d validation error(s) in case '%s'" % [errors.size(), c.id])

func _print_check_data_and_quit() -> void:
	if current_case == null:
		print("case invalid: failed to load")
		get_tree().quit(1)
		return
	print("case valid: %d objects, %d facts, %d golden QAs" % [
		current_case.object_ids.size(), current_case.total_facts(), current_case.total_sample_qa()
	])
	get_tree().quit(0)
