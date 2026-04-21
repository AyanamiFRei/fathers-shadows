extends ColorRect

func _ready() -> void:
	add_to_group("collision_flash")
	modulate.a = 0.0


func play_flash() -> void:
	# Если уже идёт предыдущий tween — прерываем его и сбрасываем
	modulate.a = 1.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4) \
		.set_ease(Tween.EASE_OUT) \
		.set_trans(Tween.TRANS_EXPO)
