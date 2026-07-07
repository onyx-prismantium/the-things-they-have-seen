class_name CaseBriefing
extends Control

## title card -> briefing text -> the four tutorial_watch lines as a short
## scripted exchange (the watch is NOT an LLM object here) -> fade out
## (BUILD_BRIEF.md §6.7).

signal finished()

@onready var _text_label: Label = %BriefingText
@onready var _continue_button: Button = %ContinueButton

var _pages: Array[String] = []
var _page_index: int = -1

func _ready() -> void:
	_continue_button.pressed.connect(_advance)
	var the_case: CaseDef = CaseLoader.current_case
	_pages.append(the_case.title)
	_pages.append(the_case.briefing)
	for line: String in the_case.tutorial_watch:
		_pages.append(line)
	_advance()

func _advance() -> void:
	_page_index += 1
	if _page_index >= _pages.size():
		visible = false
		finished.emit()
		return
	_text_label.text = _pages[_page_index]
	_continue_button.text = "Continue" if _page_index < _pages.size() - 1 else "Begin"
