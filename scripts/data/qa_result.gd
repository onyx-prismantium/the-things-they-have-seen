class_name QAResult
extends RefCounted

var answer: String = "huh" # "yes" | "no" | "huh"
var fact_id: String = "none"
var flavor_line: String = ""
var from_cache: bool = false
var is_repeat: bool = false
var latency_ms: int = 0
