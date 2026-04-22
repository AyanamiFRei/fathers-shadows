extends Node

signal loyalty_changed(npc_id: String, old_value: int, new_value: int, direction: int)
signal loyalty_indicator_started(npc_id: String, direction: int)
signal loyalty_indicator_ended(npc_id: String)

const MAX_LOYALTY := 100
const MIN_LOYALTY := 0
const INDICATOR_DURATION := 5.0

const DIRECTION_NONE := 0
const DIRECTION_UP := 1
const DIRECTION_DOWN := -1

var default_loyalty := {
	"katerina": 40,
	"leva": 50,
	"grigory": 30,
	"old": 30,
	"smerdyakov": 45
}

var loyalty: Dictionary = {}
var active_indicators: Dictionary = {}


func _init() -> void:
	_initialize_loyalty()


func _ready() -> void:
	_initialize_loyalty()
	set_process(true)


func _process(delta: float) -> void:
	var expired_npcs: Array[String] = []

	for npc_id in active_indicators.keys():
		active_indicators[npc_id]["time_left"] -= delta
		if active_indicators[npc_id]["time_left"] <= 0.0:
			expired_npcs.append(npc_id)

	for npc_id in expired_npcs:
		active_indicators.erase(npc_id)
		loyalty_indicator_ended.emit(npc_id)


func reset_all_loyalty() -> void:
	loyalty = default_loyalty.duplicate(true)
	active_indicators.clear()


func get_loyalty(npc_id: String) -> int:
	_initialize_loyalty()
	return loyalty.get(npc_id.to_lower(), 0)


func set_loyalty(npc_id: String, value: int) -> void:
	_initialize_loyalty()

	var key := npc_id.to_lower()
	var old_value := get_loyalty(key)
	var new_value := clampi(value, MIN_LOYALTY, MAX_LOYALTY)
	var direction := DIRECTION_NONE

	if new_value > old_value:
		direction = DIRECTION_UP
	elif new_value < old_value:
		direction = DIRECTION_DOWN

	loyalty[key] = new_value

	if direction != DIRECTION_NONE:
		var icon_index := get_loyalty_icon_index_from_value(new_value)
		_start_indicator(key, direction, icon_index)

	loyalty_changed.emit(key, old_value, new_value, direction)


func change_loyalty(npc_id: String, amount: int) -> void:
	set_loyalty(npc_id, get_loyalty(npc_id) + amount)


func get_loyalty_icon_index(npc_id: String) -> int:
	return get_loyalty_icon_index_from_value(get_loyalty(npc_id))

func get_loyalty_icon_index_from_value(value: int) -> int:
	if value <= 30:
		return 1
	if value <= 60:
		return 2
	return 3


func get_loyalty_icon_path(npc_id: String) -> String:
	return "res://assets_interface/loyalty/loyalty_%d.png" % get_loyalty_icon_index(npc_id)


func has_active_indicator(npc_id: String) -> bool:
	return active_indicators.has(npc_id.to_lower())


func get_indicator_direction(npc_id: String) -> int:
	return active_indicators.get(npc_id.to_lower(), {}).get("direction", DIRECTION_NONE)


func get_indicator_icon_path(npc_id: String) -> String:
	var direction := get_indicator_direction(npc_id)
	if direction == DIRECTION_NONE:
		return ""

	var icon_index := get_indicator_icon_index(npc_id)
	var dir_name := "up" if direction == DIRECTION_UP else "down"

	return "res://assets_interface/loyalty/arrow_%d_%s.png" % [icon_index, dir_name]

func get_indicator_time_left(npc_id: String) -> float:
	return active_indicators.get(npc_id.to_lower(), {}).get("time_left", 0.0)


func _initialize_loyalty() -> void:
	if loyalty.is_empty():
		loyalty = default_loyalty.duplicate(true)


func _start_indicator(npc_id: String, direction: int, icon_index: int) -> void:
	active_indicators[npc_id] = {
		"direction": direction,
		"time_left": INDICATOR_DURATION,
		"icon_index": icon_index,
	}
	loyalty_indicator_started.emit(npc_id, direction)
	
func get_indicator_icon_index(npc_id: String) -> int:
	return active_indicators.get(npc_id.to_lower(), {}).get("icon_index", get_loyalty_icon_index(npc_id))

func get_loyalty_level(npc_id: String) -> int:
	var value = get_loyalty(npc_id)
	return clampi(int(floor(value / 25.0)) + 1, 1, 5)
