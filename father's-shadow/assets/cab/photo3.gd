extends Area3D

@onready var sprite: Sprite3D = get_parent()
@onready var photo_label: Label = get_tree().current_scene.get_node("CanvasLayer4/PhotoLabel")
@onready var photo_button: Button = get_tree().current_scene.get_node("CanvasLayer4/PhotoButton")

@export var hover_color: Color = Color(1.25, 1.25, 1.25, 1.0)
@export var normal_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var label_text: String = "Найденные документы в квартире Григория ведут на Смердякова."

func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	input_event.connect(_on_input_event)

	if sprite == null:
		push_error("Sprite3D not found")
		return

	if photo_label == null:
		push_error("PhotoLabel not found at CanvasLayer2/PhotoLabel")
		return

	if photo_button == null:
		push_error("PhotoButton not found at CanvasLayer2/PhotoButton")
		return

	sprite.modulate = normal_color
	photo_label.visible = false
	photo_button.visible = false


func _on_mouse_entered() -> void:
	sprite.modulate = hover_color
	photo_label.text = label_text
	photo_label.visible = true


func _on_mouse_exited() -> void:
	sprite.modulate = normal_color
	photo_label.visible = false


func _on_input_event(camera, event, position, normal, shape_idx) -> void:
	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_LEFT \
	and event.pressed:
		photo_button.visible = true
		print("PHOTO CLICKED")
