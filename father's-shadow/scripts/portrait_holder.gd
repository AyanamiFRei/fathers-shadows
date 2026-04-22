extends Node2D
class_name PortraitHolder

@export var default_npc_id: String = ""

var current_portrait: Node2D = null
var current_npc_id: String = ""

var portrait_scenes: Dictionary = {
	"katerina": preload("res://art/katerina.tscn"),
	"leva": preload("res://art/leva.tscn")
}

func _ready() -> void:
	if default_npc_id != "":
		show_portrait(default_npc_id)


func show_portrait(npc_id: String) -> void:
	if npc_id == "":
		clear_portrait()
		return

	if current_npc_id == npc_id and is_instance_valid(current_portrait):
		return

	clear_portrait()

	if not portrait_scenes.has(npc_id):
		push_warning("PortraitHolder: no portrait scene for npc_id: " + npc_id)
		return

	var portrait_scene: PackedScene = portrait_scenes[npc_id]
	var instance := portrait_scene.instantiate()

	if not (instance is Node2D):
		push_error("PortraitHolder: portrait root must be Node2D for npc_id: " + npc_id)
		instance.queue_free()
		return

	current_portrait = instance
	current_npc_id = npc_id
	add_child(current_portrait)


func clear_portrait() -> void:
	if is_instance_valid(current_portrait):
		current_portrait.queue_free()

	current_portrait = null
	current_npc_id = ""
