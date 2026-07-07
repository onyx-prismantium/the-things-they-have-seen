class_name InteractiveObject
extends Area2D

## An interrogable object in the study (BUILD_BRIEF.md §6.1). Binds to its
## JSON definition (via CaseLoader) at ready by object_id. Placeholder art:
## a flat-color box sized/colored per export vars, built procedurally so the
## scene tree stays trivial to author for all 8 instances.

signal clicked(object_id: String)

@export var object_id: String = ""
@export var box_size: Vector2 = Vector2(160, 120)
@export var box_color: Color = Color(0.5, 0.45, 0.35)

var object_def: ObjectDef = null

var _polygon: Polygon2D
var _hover_panel: Control
var _name_label: Label
var _pips_label: Label
var _hovering: bool = false

func _ready() -> void:
	input_pickable = true
	object_def = CaseLoader.current_case.objects.get(object_id) if CaseLoader.current_case != null else null
	if object_def == null:
		push_error("InteractiveObject: no ObjectDef for id '%s'" % object_id)

	_build_shape()
	_build_hover_ui()
	_update_pips()

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	input_event.connect(_on_input_event)
	GameState.economy_changed.connect(_update_pips)
	NluService.request_started.connect(_on_request_started)
	NluService.request_finished.connect(_on_request_finished)

func _build_shape() -> void:
	_polygon = Polygon2D.new()
	var hw := box_size.x * 0.5
	var hh := box_size.y * 0.5
	_polygon.polygon = PackedVector2Array([
		Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh)
	])
	_polygon.color = box_color
	add_child(_polygon)

	var shape := RectangleShape2D.new()
	shape.size = box_size
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)

func _build_hover_ui() -> void:
	_hover_panel = PanelContainer.new()
	_hover_panel.position = Vector2(-box_size.x * 0.5, -box_size.y * 0.5 - 64)
	_hover_panel.custom_minimum_size = Vector2(box_size.x, 56)
	_hover_panel.visible = false
	_hover_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hover_panel)

	var vbox := VBoxContainer.new()
	_hover_panel.add_child(vbox)

	_name_label = Label.new()
	_name_label.text = object_def.display_name if object_def != null else object_id
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_name_label)

	_pips_label = Label.new()
	_pips_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_pips_label)

func _update_pips() -> void:
	if _pips_label == null:
		return
	var remaining := GameState.questions_remaining(object_id)
	var pips := ""
	for i: int in range(GameState.MAX_QUESTIONS_PER_OBJECT):
		pips += "●" if i < remaining else "○" # ● filled / ○ empty
	_pips_label.text = pips

func _on_mouse_entered() -> void:
	_hovering = true
	_polygon.color = box_color.lightened(0.35)
	_hover_panel.visible = true

func _on_mouse_exited() -> void:
	_hovering = false
	_polygon.color = box_color
	_hover_panel.visible = false

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			clicked.emit(object_id)

const ResponseBubbleScene := preload("res://scenes/ui/response_bubble.tscn")

## Pops a big answer word + flavor line above this object (BUILD_BRIEF.md §6.3),
## then plays the matching voice blip.
func show_response(result: QAResult) -> void:
	var bubble: ResponseBubble = ResponseBubbleScene.instantiate()
	bubble.position = Vector2(-140, -box_size.y * 0.5 - 180)
	add_child(bubble)
	bubble.setup(result)
	AudioDirector.play_answer(object_id, result.answer)

var _shimmer_tween: Tween = null

## "the clicked object gently pulses ... input locked" (BUILD_BRIEF.md §4.4).
func _on_request_started(requested_object_id: String) -> void:
	if requested_object_id != object_id:
		return
	if _shimmer_tween != null and _shimmer_tween.is_valid():
		_shimmer_tween.kill()
	_shimmer_tween = create_tween().set_loops()
	_shimmer_tween.tween_property(_polygon, "modulate", Color(1.25, 1.25, 1.25), 0.35)
	_shimmer_tween.tween_property(_polygon, "modulate", Color(1, 1, 1), 0.35)

func _on_request_finished(finished_object_id: String, _result: QAResult) -> void:
	if finished_object_id != object_id:
		return
	if _shimmer_tween != null and _shimmer_tween.is_valid():
		_shimmer_tween.kill()
	_polygon.modulate = Color(1, 1, 1)

