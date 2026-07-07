class_name FactDef
extends RefCounted

var id: String = ""
var statement: String = ""

static func from_json(d: Dictionary) -> FactDef:
	var f := FactDef.new()
	f.id = String(d.get("id", ""))
	f.statement = String(d.get("statement", ""))
	return f
