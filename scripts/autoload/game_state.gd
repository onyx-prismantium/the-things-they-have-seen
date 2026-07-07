extends Node

## Singleton: all mutable run state (BUILD_BRIEF.md §3.2).

const MAX_QUESTIONS_PER_OBJECT := 3
const MAX_DEDUCTION_ATTEMPTS := 3

signal question_answered(object_id: String, result: QAResult)
signal fact_learned(fact_id: String)
signal economy_changed()
signal softlock_state_changed(component: String, is_softlocked: bool)
signal case_ended(won: bool)

var questions_used: Dictionary = {} # object_id -> int
var focus_bonus: Dictionary = {} # object_id -> extra questions granted by Focus
var learned_facts: Dictionary = {} # fact_id -> true
var qa_cache: Dictionary = {} # cache_key -> QAResult
var transcript: Dictionary = {} # object_id -> Array[Dictionary{question, answer, flavor_line}]
var deduction_attempts_left: int = MAX_DEDUCTION_ATTEMPTS
var focus_available: bool = true
var softlocked_components: Dictionary = {} # component -> bool
var case_is_over: bool = false

func reset_case() -> void:
	questions_used.clear()
	focus_bonus.clear()
	learned_facts.clear()
	qa_cache.clear()
	transcript.clear()
	deduction_attempts_left = MAX_DEDUCTION_ATTEMPTS
	focus_available = true
	softlocked_components.clear()
	case_is_over = false

func questions_remaining(object_id: String) -> int:
	var cap: int = MAX_QUESTIONS_PER_OBJECT + int(focus_bonus.get(object_id, 0))
	var used: int = int(questions_used.get(object_id, 0))
	return cap - used

func can_ask(object_id: String) -> bool:
	return questions_remaining(object_id) > 0

func consume_question(object_id: String) -> void:
	questions_used[object_id] = int(questions_used.get(object_id, 0)) + 1
	economy_changed.emit()

func mark_learned(fact_id: String) -> void:
	if fact_id != "none" and fact_id != "" and not learned_facts.has(fact_id):
		learned_facts[fact_id] = true
		fact_learned.emit(fact_id)

func cache_get(key: String) -> QAResult:
	return qa_cache.get(key)

func cache_put(key: String, result: QAResult) -> void:
	qa_cache[key] = result

func add_transcript_entry(object_id: String, question: String, result: QAResult) -> void:
	var entries: Array = transcript.get(object_id, [])
	entries.append({"question": question, "answer": result.answer, "flavor_line": result.flavor_line})
	transcript[object_id] = entries

func use_focus(object_id: String) -> bool:
	if not focus_available:
		return false
	focus_available = false
	focus_bonus[object_id] = int(focus_bonus.get(object_id, 0)) + 1
	economy_changed.emit()
	check_softlock()
	return true

func record_answer(object_id: String, result: QAResult) -> void:
	if result.answer == "yes" or result.answer == "no":
		if not result.from_cache:
			consume_question(object_id)
			mark_learned(result.fact_id)
	question_answered.emit(object_id, result)
	check_softlock()

## After every consumed question (BUILD_BRIEF.md §6.6): can each solution component
## still be learned given remaining questions, or has the player run dry on it?
func check_softlock() -> void:
	var the_case: CaseDef = CaseLoader.current_case
	if the_case == null:
		return
	for component: String in ["culprit", "motive", "weapon"]:
		var reachable := false
		var fact_ids: Array = the_case.solution_support.get(component, [])
		for fid: String in fact_ids:
			if learned_facts.has(fid):
				reachable = true
				break
			var owner: ObjectDef = the_case.find_fact_owner(fid)
			if owner != null and questions_remaining(owner.id) > 0:
				reachable = true
				break
		var was_softlocked: bool = bool(softlocked_components.get(component, false))
		var is_softlocked: bool = not reachable and not focus_available
		if is_softlocked != was_softlocked:
			softlocked_components[component] = is_softlocked
			softlock_state_changed.emit(component, is_softlocked)

func any_softlocked() -> bool:
	for v: Variant in softlocked_components.values():
		if bool(v):
			return true
	return false

## Mastermind-style feedback: how many of {culprit, motive, weapon} match, never which.
func submit_deduction(culprit_id: String, motive_id: String, weapon_id: String) -> int:
	var the_case: CaseDef = CaseLoader.current_case
	var correct := 0
	if String(the_case.solution.get("culprit", "")) == culprit_id:
		correct += 1
	if String(the_case.solution.get("motive", "")) == motive_id:
		correct += 1
	if String(the_case.solution.get("weapon", "")) == weapon_id:
		correct += 1
	if correct == 3:
		case_is_over = true
		case_ended.emit(true)
	else:
		deduction_attempts_left -= 1
		if deduction_attempts_left <= 0:
			case_is_over = true
			case_ended.emit(false)
	return correct
