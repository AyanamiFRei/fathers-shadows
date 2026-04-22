extends Node3D

@onready var lamp_light: OmniLight3D = $LampLight

func toggle_light():
	lamp_light.visible = !lamp_light.visible
	
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
