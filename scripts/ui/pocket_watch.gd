class_name PocketWatch
extends Control

## Persistent corner UI element (BUILD_BRIEF.md §6.6/§6.7). Hover: rules
## reminder tooltip. Click: Focus flow (spend the one-per-case refund on a
## chosen object) and/or the softlock hint. The watch itself is fully
## scripted, never an LLM object.

@onready var _button: Button = %WatchButton
@onready var _popup: PopupPanel = %WatchPopup
@onready var _popup_label: Label = %PopupLabel
@onready var _object_list: OptionButton = %ObjectList
@onready var _use_focus_button: Button = %UseFocusButton

func _ready() -> void:
	tooltip_text = "Ask yes/no questions. Huh?! and exact repeats are free. Each object tires after 3 true answers. One Focus refund per case."
	_button.pressed.connect(_on_watch_pressed)
	_button.pressed.connect(func() -> void: AudioDirector.play_ui("click"))
	_use_focus_button.pressed.connect(_on_use_focus_pressed)
	GameState.softlock_state_changed.connect(_on_softlock_changed)
	_populate_object_list()

func _populate_object_list() -> void:
	_object_list.clear()
	var the_case: CaseDef = CaseLoader.current_case
	for oid: String in the_case.object_ids:
		var obj: ObjectDef = the_case.objects[oid]
		_object_list.add_item(obj.display_name)
		_object_list.set_item_metadata(_object_list.item_count - 1, oid)

func _on_watch_pressed() -> void:
	var lines: Array[String] = []
	if GameState.any_softlocked():
		for component: String in GameState.softlocked_components.keys():
			if bool(GameState.softlocked_components[component]):
				lines.append("Something in this room still holds what you need about the %s. Wind me if you must — or listen again to what you were already told." % component)
	else:
		lines.append("(Your pocket watch ticks quietly. Nothing is out of reach yet.)")
	_popup_label.text = "\n\n".join(lines)
	_use_focus_button.visible = GameState.focus_available
	_object_list.visible = GameState.focus_available
	_popup.popup_centered()

func _on_use_focus_pressed() -> void:
	var idx := _object_list.selected
	if idx < 0:
		return
	var oid := String(_object_list.get_item_metadata(idx))
	if GameState.use_focus(oid):
		_popup_label.text = "The watch grows warm, then still. One of them may speak once more."
		_use_focus_button.visible = false
		_object_list.visible = false

func _on_softlock_changed(_component: String, is_softlocked: bool) -> void:
	if is_softlocked:
		_flash_warning()

func _flash_warning() -> void:
	if _button == null:
		return
	var tween := create_tween()
	tween.tween_property(_button, "modulate", Color(1.0, 0.6, 0.2), 0.3)
	tween.tween_property(_button, "modulate", Color(1, 1, 1), 0.3)
