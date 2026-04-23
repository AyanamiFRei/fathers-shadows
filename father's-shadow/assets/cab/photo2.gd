extends Area3D

@onready var sprite: Sprite3D = get_parent()
@onready var photo_label: Label = $"../../../../CanvasLayer3/PhotoLabel"

@export var hover_color: Color = Color(1.25, 1.25, 1.25, 1.0)
@export var normal_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var label_text: String = "Катерина. Давала лжесвидетельства на суде.\nНужно еще раз с ней поговорить."

func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

	if sprite == null:
		push_error("Sprite3D not found")
		return

	if photo_label == null:
		push_error("PhotoLabel not found at CanvasLayer2/PhotoLabel")
		return

	sprite.modulate = normal_color
	photo_label.visible = false


func _on_mouse_entered() -> void:
	sprite.modulate = hover_color
	photo_label.text = label_text
	photo_label.visible = true


func _on_mouse_exited() -> void:
	sprite.modulate = normal_color
	photo_label.visible = false
