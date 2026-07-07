class_name CaseDef
extends RefCounted

var id: String = ""
var title: String = ""
var briefing: String = ""
var police_theory: String = ""
var people: Array[Dictionary] = []
var suspects: Array[Dictionary] = []
var motives: Array[Dictionary] = []
var weapons: Array[Dictionary] = []
var solution: Dictionary = {} # culprit / motive / weapon -> id
var solution_support: Dictionary = {} # component -> Array[fact_id]
var elimination_facts: Array[String] = []
var object_ids: Array[String] = []
var objects: Dictionary = {} # object_id -> ObjectDef
var tutorial_watch: Array[String] = []
var deduction_feedback: Array[String] = []
var epilogue_win: String = ""
var epilogue_lose: String = ""

static func from_json(d: Dictionary) -> CaseDef:
	var c := CaseDef.new()
	c.id = String(d.get("id", ""))
	c.title = String(d.get("title", ""))
	c.briefing = String(d.get("briefing", ""))
	c.police_theory = String(d.get("police_theory", ""))
	for p: Variant in d.get("people", []):
		c.people.append(p as Dictionary)
	for s: Variant in d.get("suspects", []):
		c.suspects.append(s as Dictionary)
	for m: Variant in d.get("motives", []):
		c.motives.append(m as Dictionary)
	for w: Variant in d.get("weapons", []):
		c.weapons.append(w as Dictionary)
	c.solution = d.get("solution", {})
	c.solution_support = d.get("solution_support", {})
	for f: Variant in d.get("elimination_facts", []):
		c.elimination_facts.append(String(f))
	for oid: Variant in d.get("objects", []):
		c.object_ids.append(String(oid))
	for line: Variant in d.get("tutorial_watch", []):
		c.tutorial_watch.append(String(line))
	for line: Variant in d.get("deduction_feedback", []):
		c.deduction_feedback.append(String(line))
	c.epilogue_win = String(d.get("epilogue_win", ""))
	c.epilogue_lose = String(d.get("epilogue_lose", ""))
	return c

func total_facts() -> int:
	var n := 0
	for oid: String in object_ids:
		var obj: ObjectDef = objects.get(oid)
		if obj != null:
			n += obj.facts.size()
	return n

func total_sample_qa() -> int:
	var n := 0
	for oid: String in object_ids:
		var obj: ObjectDef = objects.get(oid)
		if obj != null:
			n += obj.sample_qa.size()
	return n

func find_fact_owner(fact_id: String) -> ObjectDef:
	for oid: String in object_ids:
		var obj: ObjectDef = objects.get(oid)
		if obj != null and obj.has_fact(fact_id):
			return obj
	return null
