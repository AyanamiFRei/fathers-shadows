extends Control

@export var npc_id := ""

@onready var loyalty_state = $"../LoyaltyState"
@onready var loyalty_icon: TextureRect = $PanelContainer/LoyaltyIcon
@onready var change_arrow: TextureRect = $PanelContainer/ChangeArrow

var is_initialized := false


func _ready() -> void:
	change_arrow.visible = false

	if loyalty_state != null:
		loyalty_state.loyalty_changed.connect(_on_loyalty_changed)
		loyalty_state.loyalty_indicator_ended.connect(_on_loyalty_indicator_ended)

	is_initialized = true
	refresh_ui()


func set_npc_id(new_npc_id: String) -> void:
	npc_id = new_npc_id.to_lower()

	if is_initialized:
		refresh_ui()


func refresh_ui() -> void:
	if not is_initialized:
		return

	if npc_id.is_empty():
		loyalty_icon.texture = null
		loyalty_icon.visible = false
		change_arrow.visible = false
		return

	var icon_path: String = loyalty_state.get_loyalty_icon_path(npc_id)
	if ResourceLoader.exists(icon_path):
		loyalty_icon.texture = load(icon_path)
		loyalty_icon.visible = true
	else:
		push_warning("Не найден смайлик: " + icon_path)
		loyalty_icon.texture = null
		loyalty_icon.visible = false
	print("npc_id = ", npc_id)
	print("icon_path = ", icon_path)
	print("exists = ", ResourceLoader.exists(icon_path))
	print("icon visible = ", loyalty_icon.visible)
	_update_arrow()


func _update_arrow() -> void:
	if npc_id.is_empty() or not loyalty_state.has_active_indicator(npc_id):
		change_arrow.visible = false
		return

	var arrow_path: String = loyalty_state.get_indicator_icon_path(npc_id)
	if ResourceLoader.exists(arrow_path):
		change_arrow.texture = load(arrow_path)
		change_arrow.visible = true
	else:
		push_warning("Не найдена стрелка: " + arrow_path)
		change_arrow.visible = false


func _on_loyalty_changed(changed_npc_id: String, _old_value: int, _new_value: int, _direction: int) -> void:
	if changed_npc_id.to_lower() == npc_id:
		refresh_ui()


func _on_loyalty_indicator_ended(changed_npc_id: String) -> void:
	if changed_npc_id.to_lower() == npc_id:
		_update_arrow()
