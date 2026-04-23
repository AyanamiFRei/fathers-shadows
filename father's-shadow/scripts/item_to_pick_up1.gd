extends StaticBody3D

var visible_for_player: bool = false

func _ready() -> void:
	add_to_group("interactable_object")

func set_visible_for_player(value: bool) -> void:
	visible_for_player = value
	visible = value

func can_interact() -> bool:
	return visible_for_player

func interact():
	$PickupSound.play()
	await $PickupSound.finished
	queue_free()
