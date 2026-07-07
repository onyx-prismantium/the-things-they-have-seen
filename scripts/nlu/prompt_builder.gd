class_name PromptBuilder
extends RefCounted

## Pure functions only — no state, no plugin contact. Unit-testable in isolation.
## Builds the per-object system prompt and GBNF grammar described in BUILD_BRIEF.md §4.

const CANDLE_EXAMPLES := """Examples (from a different object, a candle, for format only):
Q: did a hand snuff you out?            -> yes|candle-snuffed-by-hand
Q: were you still burning at midnight?  -> no|candle-out-by-ten
Q: did the murderer touch you?          -> huh|none
Q: who lit you?                         -> huh|none
Q: were you lit, and did he see you?    -> huh|none"""

static func build_facts_block(obj: ObjectDef) -> String:
	var lines: Array[String] = []
	for f: FactDef in obj.facts:
		lines.append("- %s: %s" % [f.id, f.statement])
	return "\n".join(lines)

static func build_people_known_line(obj: ObjectDef, people_names: Dictionary) -> String:
	var names: Array[String] = []
	for pid: String in obj.people_known:
		names.append(String(people_names.get(pid, pid)))
	return ", ".join(names)

static func build_system_prompt(obj: ObjectDef, people_names: Dictionary) -> String:
	var senses_line := ", ".join(obj.senses)
	var people_line := build_people_known_line(obj, people_names)
	var facts_block := build_facts_block(obj)
	return "\n".join([
		"/no_think",
		"You are %s, an object in a Victorian study, questioned by a psychic" % obj.display_name,
		"detective. You are not a person. You cannot lie. You may only answer what your own",
		"memories support.",
		"",
		"YOUR SENSES: %s. You perceived the world only through these." % senses_line,
		"YOU RECOGNIZE only these people (long familiarity): %s. Anyone else — or" % people_line,
		"any hand hidden in a glove — is only \"an unfamiliar presence\"; you cannot identify them.",
		"",
		"YOUR MEMORIES — the complete list of everything you know:",
		facts_block,
		"",
		"TASK: The detective asks exactly one question. Output exactly one line:",
		"ANSWER|FACT-ID",
		"",
		"Rules:",
		"- yes  -> one memory confirms what the question asserts. Give that memory's fact-id.",
		"- no   -> one memory clearly establishes it did NOT happen. Give that memory's fact-id.",
		"- huh|none -> everything else: the question uses ideas beyond your senses (murder,",
		"  guilt, motive, why, crime, killer); or is not a yes/no question (who/what/when/",
		"  where/why/how); or asks several things at once; or none of your memories cover it;",
		"  or it is not a question. When uncertain, always huh|none. Never invent. Never",
		"  answer from general knowledge — only from YOUR MEMORIES above.",
		"",
		CANDLE_EXAMPLES,
	])

## rule names in GBNF may not contain underscores; our fact ids are already dashed.
static func build_grammar(obj: ObjectDef) -> String:
	var ids: Array[String] = []
	for f: FactDef in obj.facts:
		ids.append('"%s"' % f.id)
	return 'root ::= polar "|" fact | "huh|none"\npolar ::= "yes" | "no"\nfact ::= %s\n' % " | ".join(ids)

## normalize(): trim, collapse whitespace, lowercase, strip trailing ?/!/.
static func normalize(text: String) -> String:
	var s := text.strip_edges().to_lower()
	while s.length() > 0 and (s.ends_with("?") or s.ends_with("!") or s.ends_with(".")):
		s = s.substr(0, s.length() - 1).strip_edges()
	var out := ""
	var prev_space := false
	for ch: String in s:
		if ch == " " or ch == "\t" or ch == "\n":
			if not prev_space:
				out += " "
			prev_space = true
		else:
			out += ch
			prev_space = false
	return out.strip_edges()

static func cache_key(object_id: String, normalized_question: String) -> String:
	return "%s::%s" % [object_id, normalized_question]

## Parses raw provider output "answer|fact-id" into [answer, fact_id]; never throws.
static func parse_raw(raw: String) -> Array:
	var s := raw.strip_edges()
	var parts := s.split("|")
	if parts.size() != 2:
		return ["huh", "none"]
	var answer := parts[0].strip_edges().to_lower()
	var fact_id := parts[1].strip_edges().to_lower()
	if answer != "yes" and answer != "no" and answer != "huh":
		return ["huh", "none"]
	if answer == "huh":
		return ["huh", "none"]
	return [answer, fact_id]

## Post-validation (§3.3 step 4): incoherent (answer, fact) pairs degrade to huh|none.
static func validate(obj: ObjectDef, answer: String, fact_id: String) -> Array:
	if answer == "huh":
		return ["huh", "none"]
	if fact_id == "none" or fact_id == "":
		return ["huh", "none"]
	if not obj.has_fact(fact_id):
		return ["huh", "none"]
	return [answer, fact_id]
