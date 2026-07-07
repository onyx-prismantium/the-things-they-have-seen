class_name ObjectDef
extends RefCounted

var id: String = ""
var display_name: String = ""
var persona: String = ""
var senses: Array[String] = []
var people_known: Array[String] = []
var voice_waveform: String = "sine"
var voice_base_hz: int = 440
var voice_lines: Dictionary = {} # answer -> Array[String]
var facts: Array[FactDef] = []
var sample_qa: Array[SampleQADef] = []

## Cached at case-load time by PromptBuilder; NluService/providers read these, never rebuild them.
var system_prompt: String = ""
var grammar: String = ""

static func from_json(d: Dictionary) -> ObjectDef:
	var o := ObjectDef.new()
	o.id = String(d.get("id", ""))
	o.display_name = String(d.get("display_name", ""))
	o.persona = String(d.get("persona", ""))
	for s: Variant in d.get("senses", []):
		o.senses.append(String(s))
	for p: Variant in d.get("people_known", []):
		o.people_known.append(String(p))
	var voice: Dictionary = d.get("voice", {})
	o.voice_waveform = String(voice.get("waveform", "sine"))
	o.voice_base_hz = int(voice.get("base_hz", 440))
	o.voice_lines = d.get("voice_lines", {})
	for f: Variant in d.get("facts", []):
		o.facts.append(FactDef.from_json(f))
	for qa: Variant in d.get("sample_qa", []):
		o.sample_qa.append(SampleQADef.from_json(qa))
	return o

func has_fact(fact_id: String) -> bool:
	for f: FactDef in facts:
		if f.id == fact_id:
			return true
	return false

func random_voice_line(answer: String) -> String:
	var lines: Array = voice_lines.get(answer, [])
	if lines.is_empty():
		return ""
	return String(lines[randi() % lines.size()])
