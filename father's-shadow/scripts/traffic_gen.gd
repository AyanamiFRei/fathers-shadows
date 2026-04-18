extends StaticBody3D

var traffic_forward = preload("res://scenes/TrafficCarForward.tscn")
var traffic_backward = preload("res://scenes/TrafficCarBack.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var chars_count = 0
	for node in get_tree().get_root().get_children():
		if node is CharacterBody3D:
			chars_count += 1
			
	var posx = randi_range(-4, 4)
	var posz = randi_range(-85, 0)
	if chars_count <= 15:
		if posx > 0:
			var instance = traffic_forward.instantiate()
			instance.position = Vector3(posx, 1, posz)
			get_tree().get_root().add_child(instance)
			print("added")
			print(instance)
		else:
			var instance = traffic_backward.instantiate()
			instance.position = Vector3(posx, 1, posz)
			get_tree().get_root().add_child(instance)
			print("added")
			print(instance)
