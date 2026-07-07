class_name PromptBuilder
extends RefCounted

## Pure functions only — no state, no plugin contact. Unit-testable in isolation.
## Builds the per-object system prompt and GBNF grammar described in BUILD_BRIEF.md §4.

const CANDLE_EXAMPLES := """Examples (from a different object, a candle, for format only):
Memory: candle-snuffed-by-hand: A hand pinched out my flame that night.
Memory: candle-never-fell: I have never once fallen from my holder. Not that night, not ever.
Q: did a hand snuff you out?            -> yes|candle-snuffed-by-hand
Q: was your flame put out by someone?   -> yes|candle-snuffed-by-hand
Q: did you fall from your holder?       -> no|candle-never-fell   (the memory says "never" -> deny it)
Q: were you knocked to the floor?       -> no|candle-never-fell   (same memory, different words, still deny)
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
		"Follow these steps in order:",
		"1. Is it a single plain yes/no question (not who/what/when/where/why/how, not",
		"   several questions at once, not a statement or greeting)? If no -> huh|none.",
		"2. Does it use a concept you cannot sense (murder, guilt, motive, \"why\", crime,",
		"   killer, a person's identity under a glove)? If yes -> huh|none.",
		"3. Read YOUR MEMORIES above one at a time and find the ONE memory that matches —",
		"   is about the same thing the question asks, even worded differently (\"did you",
		"   touch blood\" matches a memory about blood on you; \"were you shut\" matches a",
		"   memory about being left open). Before answering, re-read that memory's exact",
		"   words: if they say something DID NOT happen, was NEVER true, or explicitly",
		"   deny/rule out the thing asked, the answer is no. Only answer yes if the words",
		"   POSITIVELY affirm the thing asked.",
		"4. Only if truly no memory above is about that topic at all -> huh|none.",
		"",
		"IMPORTANT: step 3 is the common case, and getting the yes/no answer right matters",
		"more than anything else — matching a memory does NOT automatically mean yes; check",
		"whether its words affirm or deny before choosing. Do not retreat to huh|none out of",
		"caution — if any memory speaks to the question, answer yes or no and cite it.",
		"Reserve huh|none for the cases in steps 1, 2, and 4 only. Never invent a fact that",
		"isn't listed above.",
		"",
		CANDLE_EXAMPLES,
	])

## rule names in GBNF may not contain underscores; our fact ids are already dashed.
## Polar answer comes BEFORE the fact-id (matches BUILD_BRIEF.md §4.1). An experiment
## putting fact-id first (so the polar token could condition on the model's own fact
## choice) was tried and measured WORSE (see docs/reports/) — it made the harder,
## higher-entropy decision (which of 5-7 facts, or none) come first, which seemed to
## cascade into more errors. Reverted; kept only as a documented dead end.
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
