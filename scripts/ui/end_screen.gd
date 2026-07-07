class_name EndScreen
extends Control

## Win / lose epilogue (BUILD_BRIEF.md §6.5, §7 M4). Shown on GameState.case_ended.

@onready var _text_label: Label = %EpilogueText

func _ready() -> void:
	visible = false
	GameState.case_ended.connect(_on_case_ended)

func _on_case_ended(won: bool) -> void:
	var the_case: CaseDef = CaseLoader.current_case
	_text_label.text = the_case.epilogue_win if won else the_case.epilogue_lose
	visible = true
