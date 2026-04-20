extends Node

const MAX_LOYALTY: int = 100
const MIN_LOYALTY: int = 0

var default_loyalty := {
	"leva": 20,
	"katerina": 35,
	"worker": 10
}

var loyalty := default_loyalty.duplicate(true)


func _ready() -> void:
	print("LoyaltyState ready: ", loyalty)


func reset_all_loyalty() -> void:
	loyalty = default_loyalty.duplicate(true)


func get_loyalty(npc_id: String) -> int:
	if not loyalty.has(npc_id):
		print("Лояльность не найдена для npc_id: ", npc_id)
		return 0

	return loyalty[npc_id]


func set_loyalty(npc_id: String, value: int) -> void:
	var clamped_value = clamp(value, MIN_LOYALTY, MAX_LOYALTY)
	loyalty[npc_id] = clamped_value


func change_loyalty(npc_id: String, amount: int) -> void:
	var current_value = get_loyalty(npc_id)
	set_loyalty(npc_id, current_value + amount)
