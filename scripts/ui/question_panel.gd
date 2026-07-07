class_name QuestionPanel
extends Control

## Object portrait/name, pips, a LineEdit (max 140 chars), Ask button, and the
## scrollable transcript of this object's previous Q&As (BUILD_BRIEF.md §6.3).

signal answered(object_id: String, result: QAResult)
signal closed()

const MAX_QUESTION_LENGTH := 140

@onready var _name_label: Label = %NameLabel
@onready var _pips_label: Label = %PipsLabel
@onready var _transcript_box: VBoxContainer = %TranscriptBox
@onready var _scroll: ScrollContainer = %TranscriptScroll
@onready var _line_edit: LineEdit = %QuestionEdit
@onready var _ask_button: Button = %AskButton
@onready var _status_label: Label = %StatusLabel

var _object_id: String = ""
var _object_def: ObjectDef = null

func _ready() -> void:
	visible = false
	_line_edit.max_length = MAX_QUESTION_LENGTH
	_ask_button.pressed.connect(_on_ask_pressed)
	_line_edit.text_submitted.connect(func(_t: String) -> void: _on_ask_pressed())
	%CloseButton.pressed.connect(_on_close_pressed)
	GameState.economy_changed.connect(_update_pips)

func open_for(object_id: String) -> void:
	_object_id = object_id
	_object_def = CaseLoader.current_case.objects.get(object_id)
	if _object_def == null:
		push_error("QuestionPanel: no ObjectDef for '%s'" % object_id)
		return
	_name_label.text = _object_def.display_name
	_update_pips()
	_rebuild_transcript()
	_status_label.text = ""
	_line_edit.text = ""
	visible = true
	_line_edit.grab_focus()

func _update_pips() -> void:
	if _object_def == null:
		return
	var remaining := GameState.questions_remaining(_object_id)
	var pips := ""
	for i: int in range(GameState.MAX_QUESTIONS_PER_OBJECT):
		pips += "●" if i < remaining else "○"
	_pips_label.text = pips

func _rebuild_transcript() -> void:
	for child: Node in _transcript_box.get_children():
		child.queue_free()
	var entries: Array = GameState.transcript.get(_object_id, [])
	for entry: Dictionary in entries:
		_append_transcript_row(String(entry.get("question", "")), String(entry.get("answer", "")), String(entry.get("flavor_line", "")))

func _append_transcript_row(question: String, answer: String, flavor_line: String) -> void:
	var row := VBoxContainer.new()
	var q_label := Label.new()
	q_label.text = "You: %s" % question
	q_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(q_label)
	var a_label := Label.new()
	a_label.text = "%s — %s" % [answer.to_upper(), flavor_line]
	a_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(a_label)
	_transcript_box.add_child(row)

func _on_ask_pressed() -> void:
	if _object_def == null:
		return
	var question := _line_edit.text.strip_edges()
	if question.is_empty():
		return
	_set_busy(true)
	var result: QAResult = await NluService.ask(_object_def, question)
	_set_busy(false)
	_line_edit.text = ""
	_append_transcript_row(question, result.answer, result.flavor_line)
	_scroll_to_bottom()
	answered.emit(_object_id, result)

func _set_busy(busy: bool) -> void:
	_line_edit.editable = not busy
	_ask_button.disabled = busy
	_status_label.text = "listening…" if busy else ""

func _scroll_to_bottom() -> void:
	await get_tree().process_frame
	_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)

func _on_close_pressed() -> void:
	visible = false
	closed.emit()

## Dev/test hook: drives the same path a real click + Enter would.
func ask_programmatically(question: String) -> void:
	_line_edit.text = question
	await _on_ask_pressed()
