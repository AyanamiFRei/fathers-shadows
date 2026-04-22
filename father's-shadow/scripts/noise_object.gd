extends StaticBody3D

@export var noise_amount: float = 15.0
@onready var noise_area: Area3D = $NoiseArea

var visible_for_player: bool = false

func _ready() -> void:
	add_to_group("noise_object")

func set_visible_for_player(value: bool) -> void:
	visible_for_player = value
	visible = value

func _on_noise_area_body_entered(body: Node3D) -> void:
	if body.has_method("add_noise"):
		body.add_noise(noise_amount)
		print(body.name, " наступил на шумный объект: ", name)
