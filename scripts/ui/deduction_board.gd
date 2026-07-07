class_name DeductionBoard
extends Control

## Three columns (Culprit / Motive / Weapon) from case.json lists, each entry
## name + blurb; select one per column, Submit -> confirm -> Mastermind-style
## feedback (BUILD_BRIEF.md §6.5). Opened any time via a persistent button.

signal closed()

@onready var _culprit_box: VBoxContainer = %CulpritBox
@onready var _motive_box: VBoxContainer = %MotiveBox
@onready var _weapon_box: VBoxContainer = %WeaponBox
@onready var _attempts_label: Label = %AttemptsLabel
@onready var _feedback_label: Label = %FeedbackLabel
@onready var _submit_button: Button = %SubmitButton
@onready var _confirm_dialog: ConfirmationDialog = %ConfirmDialog

var _selected_culprit: String = ""
var _selected_motive: String = ""
var _selected_weapon: String = ""

var _culprit_buttons: Dictionary = {} # id -> Button
var _motive_buttons: Dictionary = {}
var _weapon_buttons: Dictionary = {}

func _ready() -> void:
	visible = false
	_submit_button.pressed.connect(_on_submit_pressed)
	_confirm_dialog.confirmed.connect(_on_confirm_deduction)
	%CloseButton.pressed.connect(_on_close_pressed)
	_populate_columns()
	GameState.economy_changed.connect(_update_attempts_label)

func _populate_columns() -> void:
	var the_case: CaseDef = CaseLoader.current_case
	for entry: Dictionary in the_case.suspects:
		_add_option(_culprit_box, entry, _culprit_buttons, "_selected_culprit")
	for entry: Dictionary in the_case.motives:
		_add_option(_motive_box, entry, _motive_buttons, "_selected_motive")
	for entry: Dictionary in the_case.weapons:
		_add_option(_weapon_box, entry, _weapon_buttons, "_selected_weapon")

func _add_option(box: VBoxContainer, entry: Dictionary, registry: Dictionary, selected_field: String) -> void:
	var id := String(entry.get("id", ""))
	var label := String(entry.get("name", entry.get("label", id)))
	var blurb := String(entry.get("blurb", ""))
	var button := Button.new()
	button.toggle_mode = true
	button.text = label if blurb.is_empty() else "%s\n%s" % [label, blurb]
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.pressed.connect(_on_option_pressed.bind(id, registry, selected_field))
	box.add_child(button)
	registry[id] = button

func _on_option_pressed(id: String, registry: Dictionary, selected_field: String) -> void:
	set(selected_field, id)
	for other_id: String in registry.keys():
		var btn: Button = registry[other_id]
		btn.button_pressed = other_id == id
	_update_submit_enabled()

func _update_submit_enabled() -> void:
	_submit_button.disabled = _selected_culprit.is_empty() or _selected_motive.is_empty() or _selected_weapon.is_empty() or GameState.case_is_over

func open_board() -> void:
	_update_attempts_label()
	_feedback_label.text = ""
	visible = true

func _update_attempts_label() -> void:
	_attempts_label.text = "Attempts remaining: %d" % GameState.deduction_attempts_left
	_update_submit_enabled()

func _on_submit_pressed() -> void:
	_confirm_dialog.dialog_text = "Attempts remaining: %d. Speak it aloud?" % GameState.deduction_attempts_left
	_confirm_dialog.popup_centered()

func _on_confirm_deduction() -> void:
	var the_case: CaseDef = CaseLoader.current_case
	var correct := GameState.submit_deduction(_selected_culprit, _selected_motive, _selected_weapon)
	_feedback_label.text = the_case.deduction_feedback[correct]
	_update_attempts_label()

func _on_close_pressed() -> void:
	visible = false
	closed.emit()
