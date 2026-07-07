class_name ResponseBubble
extends Control

## Pops above the clicked object: big answer word (distinct color per §6.3)
## + flavor voice line. Auto-dismisses after a few seconds. Never lets the
## flavor line obscure the answer — the answer word is the mechanic.

const COLOR_YES := Color(0.35, 0.75, 0.4)   # warm green
const COLOR_NO := Color(0.75, 0.2, 0.2)     # deep red
const COLOR_HUH := Color(0.8, 0.65, 0.15)   # mustard
const LIFETIME_SECONDS := 3.0

@onready var _answer_label: Label = %AnswerLabel
@onready var _flavor_label: Label = %FlavorLabel
@onready var _panel: PanelContainer = %Panel

func setup(result: QAResult) -> void:
	var word := "HUH?!"
	var color := COLOR_HUH
	if result.answer == "yes":
		word = "YES"
		color = COLOR_YES
	elif result.answer == "no":
		word = "NO"
		color = COLOR_NO
	_answer_label.text = word
	_answer_label.add_theme_color_override("font_color", color)
	_flavor_label.text = result.flavor_line

func _ready() -> void:
	var timer := get_tree().create_timer(LIFETIME_SECONDS)
	timer.timeout.connect(queue_free)
