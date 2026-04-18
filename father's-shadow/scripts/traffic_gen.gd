extends StaticBody3D

@export var player_path: NodePath

var player: Node3D
var traffic_forward = preload("res://scenes/TrafficCarForward.tscn")
var traffic_backward = preload("res://scenes/TrafficCarBack.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	player = get_node(player_path)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var chars_count = 0
	for node in get_tree().get_root().get_children():
		if node is CharacterBody3D:
			chars_count += 1
			
	var posx = [-4, -2, 2, 4].pick_random()
	var posz = randi_range(player.global_position.z + 30, player.global_position.z + 40)
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
