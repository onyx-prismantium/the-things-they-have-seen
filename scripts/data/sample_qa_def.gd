class_name SampleQADef
extends RefCounted

var q: String = ""
var a: String = "" # "yes" | "no" | "huh"
var fact: String = "none"

static func from_json(d: Dictionary) -> SampleQADef:
	var s := SampleQADef.new()
	s.q = String(d.get("q", ""))
	s.a = String(d.get("a", "huh"))
	s.fact = String(d.get("fact", "none"))
	return s
