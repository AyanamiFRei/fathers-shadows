extends Control

#const DIALOGUE_PATH := "res://dialogue/Telephone1.json"
#const DIALOGUE_PATH := "res://dialogue/Leva.json"
#const DIALOGUE_PATH := "res://dialogue/Police.json"
#const DIALOGUE_PATH := "res://dialogue/Katerina.json"
#const DIALOGUE_PATH := "res://dialogue/Grigory.json"

#const DIALOGUE_PATH := "res://dialogue/Telephone2.json"
#const DIALOGUE_PATH := "res://dialogue/Leva2.json"
#const DIALOGUE_PATH := "res://dialogue/Old_Lady.json"
#const DIALOGUE_PATH := "res://dialogue/Police2.json"
#const DIALOGUE_PATH := "res://dialogue/Smerdyakov.json"

const LINE_TIME_LIMIT := 6.0
const CHOICE_TIME_LIMIT := 8.0
const CHOICE_TEXT_NORMAL_COLOR := Color(1, 1, 1, 1)
const CHOICE_TEXT_HOVER_COLOR := Color(1, 0.8, 0.2, 1)
const DEFAULT_CHOICE_ON_TIMEOUT := "choice_x"

@onready var dialogue_panel: Control = $DialoguePanel
@onready var name_label: Label = $DialoguePanel/NamePlate/NameLabel
@onready var dialogue_text: RichTextLabel = $DialoguePanel/DialogueText
@onready var portrait_root: Node = $New_Portrait

@onready var timer_bar = $DialogueTimerBar
@onready var choice_panel: Control = $ChoicePanel
@onready var choice_1_text = $ChoicePanel/Background/"Choice1 [X]"/AnswerOption1
@onready var choice_2_text = $ChoicePanel/Background/"Choice2 [Y]"/AnswerOption2
@onready var choice_3_text = $ChoicePanel/Background/"Choice3 [B]"/AnswerOption3
@onready var choice_1_button: Button = $ChoicePanel/Background/"Choice1 [X]"
@onready var choice_2_button: Button = $ChoicePanel/Background/"Choice2 [Y]"
@onready var choice_3_button: Button = $ChoicePanel/Background/"Choice3 [B]"

@onready var end_anim_rect: CanvasItem = $"../end_anim_rect"
@onready var animation_player: AnimationPlayer = $"../AnimationPlayer"
@onready var dialogue_state = $"../DialogueState"
@onready var loyalty_state = $"../LoyaltyState"
@onready var loyalty_value_label: Label = $LoyaltyValueLabel
@onready var loyalty_ui = $"../LoyaltyUI"

@export var player: Node3D

var start_id := ""
var nodes: Dictionary = {}
var current_node_id := ""
var pending_node_id := ""
var current_npc_id := ""

const HIDE_PANEL_PATHS := [
	"res://dialogue/Telephone1.json",
	"res://dialogue/Police.json", 
	"res://dialogue/Telephone2.json", 
	"res://dialogue/Police2.json"
]

func _ready() -> void:
	add_to_group("dialogue_manager")
	_connect_ui_signals()
	_setup_choice_labels()

	#load_dialogue(DIALOGUE_PATH)
	var current_path = CycleManager.get_hub_dialogue_path()
	if CycleManager.current_cycle == CycleManager.Cycle.DAY:
		current_path = CycleManager.get_day_dialogue_path()
		animation_player.play("fadeout")
	
	load_dialogue(current_path)
	if current_path in HIDE_PANEL_PATHS:
		$"../LoyaltyUI/PanelContainer".hide()
	else:
		$"../LoyaltyUI/PanelContainer".show()
	dialogue_state.reset_dialogue_timer()
	dialogue_state.start_dialogue_timer()
	start_dialogue()
	animation_player.animation_finished.connect(_on_animation_finished)
	end_anim_rect.visible = true
	
	
func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == &"fadein":
		CycleManager.advance_day()


func _process(_delta: float) -> void:
	if current_node_id.is_empty():
		return

	if dialogue_state.is_between_window_timer_running:
		_process_pause_state()
		return

	_update_timer_bar()

	if dialogue_state.is_window_time_over():
		handle_window_timeout()


func _input(event: InputEvent) -> void:
	if not _can_handle_click(event):
		return

	var node := _get_current_node()
	if node.is_empty() or str(node.get("type", "")) != "line":
		return

	dialogue_state.stop_window_timer()
	go_to_next_line()


func _on_choice_1_pressed() -> void:
	_handle_mouse_choice("choice_x")


func _on_choice_2_pressed() -> void:
	_handle_mouse_choice("choice_y")


func _on_choice_3_pressed() -> void:
	_handle_mouse_choice("choice_b")


func _handle_mouse_choice(button_name: String) -> void:
	if dialogue_state.is_between_window_timer_running or current_node_id.is_empty():
		return

	var node := _get_current_node()
	if node.is_empty() or str(node.get("type", "")) != "choice":
		return

	dialogue_state.stop_window_timer()
	select_choice(button_name)


func _set_choice_text_hover(label: Control, hovered: bool) -> void:
	if label == null:
		return

	var color := CHOICE_TEXT_HOVER_COLOR if hovered else CHOICE_TEXT_NORMAL_COLOR
	if label is RichTextLabel:
		label.modulate = color
	elif label is Label:
		(label as Label).add_theme_color_override("font_color", color)


func load_dialogue(path: String) -> void:
	if not FileAccess.file_exists(path):
		push_error("Файл диалога не найден: " + path)
		return

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Не удалось открыть файл: " + path)
		return

	var json := JSON.new()
	var parse_result := json.parse(file.get_as_text())
	file.close()

	if parse_result != OK:
		push_error("Ошибка чтения JSON: " + path)
		return

	var data = json.data
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Корень JSON должен быть словарём.")
		return

	current_npc_id = str(data.get("npc_id", "")).to_lower()
	start_id = str(data.get("start", ""))
	

	if loyalty_ui != null:
		loyalty_ui.set_npc_id(current_npc_id)

	var json_nodes = data.get("nodes", [])
	if typeof(json_nodes) != TYPE_ARRAY:
		push_error("Поле 'nodes' должно быть массивом.")
		return

	nodes.clear()
	for node in json_nodes:
		if typeof(node) == TYPE_DICTIONARY and node.has("id"):
			nodes[str(node["id"])] = node


func start_dialogue() -> void:
	if start_id.is_empty():
		push_error("В JSON не задан start.")
		return

	if not nodes.has(start_id):
		push_error("Стартовый узел не найден: " + start_id)
		return

	current_node_id = start_id

	if loyalty_ui != null:
		loyalty_ui.show()

	update_loyalty_ui()
	show_current_node()

func show_current_node() -> void:
	var node := _get_current_node()
	if node.is_empty():
		push_error("Узел не найден: " + current_node_id)
		return

	match str(node.get("type", "")):
		"line":
			show_line_node(node)
		"choice":
			show_choice_node(node)
		_:
			push_error("Неизвестный тип узла: " + str(node.get("type", "")))

	update_loyalty_ui()


func show_line_node(node: Dictionary) -> void:
	set_ui_state(true, false)
	name_label.text = str(node.get("name", ""))
	dialogue_text.text = str(node.get("text", ""))
	show_portrait_node(resolve_portrait_node(node))
	_start_window(LINE_TIME_LIMIT)


func show_choice_node(node: Dictionary) -> void:
	set_ui_state(false, true)
	show_portrait_node(resolve_portrait_node(node))

	var options = node.get("options", [])
	_setup_choice_option(choice_1_button, choice_1_text, options, 0)
	_setup_choice_option(choice_2_button, choice_2_text, options, 1)
	_setup_choice_option(choice_3_button, choice_3_text, options, 2)
	_start_window(CHOICE_TIME_LIMIT)


func go_to_next_line() -> void:
	var node := _get_current_node()
	if node.is_empty():
		return

	if not node.has("next"):
		end_dialogue()
		return

	_go_to_next_node(str(node["next"]), float(node.get("pause_after", 0.0)))


func select_choice(button_name: String) -> void:
	var node := _get_current_node()
	if node.is_empty():
		return

	for option in node.get("options", []):
		if str(option.get("button", "")) != button_name:
			continue

		dialogue_state.stop_window_timer()
		timer_bar.hide()
		apply_choice_loyalty(option)
		update_loyalty_ui()

		var next_id := str(option.get("next", ""))
		if next_id.is_empty():
			end_dialogue()
		else:
			current_node_id = next_id
			show_current_node()
		return


func apply_traffic_hit_penalty() -> void:
	if current_npc_id.is_empty() or loyalty_state == null:
		return
	loyalty_state.change_loyalty(current_npc_id, -5)
	update_loyalty_ui()
	if loyalty_state.get_loyalty(current_npc_id) <= 0:
		get_tree().reload_current_scene()


func apply_choice_loyalty(option: Dictionary) -> void:
	if current_npc_id.is_empty() or loyalty_state == null:
		return

	if option.has("loyalty_change"):
		loyalty_state.change_loyalty(current_npc_id, int(option["loyalty_change"]))
	elif option.has("loyalty_set"):
		loyalty_state.set_loyalty(current_npc_id, int(option["loyalty_set"]))


func end_dialogue() -> void:
	var player_node = get_tree().get_root().find_child("Player", true, false)
	if player_node != null and player_node.has_method("end_anim"):
		player_node.end_anim()

	dialogue_state.stop_dialogue_timer()
	dialogue_state.stop_window_timer()
	timer_bar.hide()

	if loyalty_ui != null:
		loyalty_ui.hide()

	end_anim_rect.visible = true
	animation_player.play("fadein")
	hide()

func handle_window_timeout() -> void:
	var node := _get_current_node()
	if node.is_empty():
		return

	dialogue_state.stop_window_timer()
	timer_bar.hide()

	match str(node.get("type", "")):
		"line":
			if not node.has("next"):
				end_dialogue()
				return
			_go_to_next_node(str(node["next"]), float(node.get("pause_after", 0.0)))
		"choice":
			select_choice(DEFAULT_CHOICE_ON_TIMEOUT)


func start_pause_before_next(next_id: String, pause_time: float) -> void:
	if next_id.is_empty():
		end_dialogue()
		return

	pending_node_id = next_id
	dialogue_state.start_between_window_timer(pause_time)
	set_ui_state(false, false)

func update_loyalty_ui() -> void:
	if current_npc_id.is_empty():
		loyalty_value_label.text = "---"
		if loyalty_ui != null:
			loyalty_ui.set_npc_id("")
			loyalty_ui.refresh_ui()
		return

	loyalty_value_label.text = str(loyalty_state.get_loyalty(current_npc_id))

	if loyalty_ui != null:
		loyalty_ui.set_npc_id(current_npc_id)
		loyalty_ui.refresh_ui()

func hide_all_portraits() -> void:
	if portrait_root == null:
		return

	for character_node in portrait_root.get_children():
		if character_node is CanvasItem:
			character_node.hide()
		for portrait_variant in character_node.get_children():
			if portrait_variant is CanvasItem:
				portrait_variant.hide()

	if portrait_root is CanvasItem:
		portrait_root.hide()


func show_portrait_node(portrait_node_path: String) -> void:
	hide_all_portraits()
	if portrait_node_path.is_empty() or portrait_root == null:
		return

	var portrait_node := portrait_root.get_node_or_null(portrait_node_path)
	if portrait_node == null:
		push_warning("Портрет не найден: " + portrait_node_path)
		return

	if portrait_node is CanvasItem:
		portrait_node.show()

	var parent = portrait_node.get_parent()
	while parent != null:
		if parent is CanvasItem:
			parent.show()
		if parent == portrait_root:
			break
		parent = parent.get_parent()


func resolve_portrait_node(node: Dictionary) -> String:
	var portrait_node_path := str(node.get("portrait_node", ""))
	if not portrait_node_path.is_empty():
		return portrait_node_path

	match str(node.get("portrait", "")):
		"res://art/Leva.png":
			return "Leva/Leva_Base"
		"res://art/Katerina.png":
			return "Katerina/Katerina_Base"
		_:
			return ""


func set_ui_state(show_dialogue: bool, show_choice: bool) -> void:
	var ui_visible := show_dialogue or show_choice
	dialogue_panel.visible = show_dialogue
	choice_panel.visible = show_choice

	if portrait_root is CanvasItem:
		portrait_root.visible = ui_visible

	if not ui_visible:
		timer_bar.hide()
		hide_all_portraits()


func _connect_ui_signals() -> void:
	dialogue_panel.gui_input.connect(_on_dialogue_panel_gui_input)
	choice_1_button.pressed.connect(_on_choice_1_pressed)
	choice_2_button.pressed.connect(_on_choice_2_pressed)
	choice_3_button.pressed.connect(_on_choice_3_pressed)

	choice_1_button.mouse_entered.connect(func(): _set_choice_text_hover(choice_1_text, true))
	choice_1_button.mouse_exited.connect(func(): _set_choice_text_hover(choice_1_text, false))
	choice_2_button.mouse_entered.connect(func(): _set_choice_text_hover(choice_2_text, true))
	choice_2_button.mouse_exited.connect(func(): _set_choice_text_hover(choice_2_text, false))
	choice_3_button.mouse_entered.connect(func(): _set_choice_text_hover(choice_3_text, true))
	choice_3_button.mouse_exited.connect(func(): _set_choice_text_hover(choice_3_text, false))


func _setup_choice_labels() -> void:
	choice_1_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	choice_2_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	choice_3_text.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _on_dialogue_panel_gui_input(event: InputEvent) -> void:
	if dialogue_state.is_between_window_timer_running or current_node_id.is_empty():
		return
	if not (event is InputEventMouseButton):
		return
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed or event.is_echo():
		return

	var node := _get_current_node()
	if node.is_empty() or str(node.get("type", "")) != "line":
		return

	dialogue_state.stop_window_timer()
	go_to_next_line()


func _can_handle_click(event: InputEvent) -> bool:
	if dialogue_state.is_between_window_timer_running or current_node_id.is_empty():
		return false
	if not (event is InputEventMouseButton):
		return false
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed or event.is_echo():
		return false
	return dialogue_panel.visible and dialogue_panel.get_global_rect().has_point(event.position)


func _process_pause_state() -> void:
	if not dialogue_state.is_between_window_time_over():
		return

	dialogue_state.stop_between_window_timer()
	if pending_node_id.is_empty():
		return

	current_node_id = pending_node_id
	pending_node_id = ""
	show_current_node()


func _update_timer_bar() -> void:
	if not dialogue_state.is_window_timer_running:
		return

	var limit: float = dialogue_state.get_current_window_limit()
	if limit <= 0.0:
		return

	var progress: float = 1.0 - dialogue_state.get_current_window_time() / limit
	timer_bar.value = clamp(progress, 0.0, 1.0)


func _start_window(limit: float) -> void:
	timer_bar.show()
	timer_bar.value = 1.0
	dialogue_state.start_window_timer(limit)


func _setup_choice_option(button: Button, label: RichTextLabel, options: Array, index: int) -> void:
	label.text = ""
	button.hide()
	_set_choice_text_hover(label, false)

	if index >= options.size():
		return

	label.text = str(options[index].get("text", ""))
	button.show()


func _get_current_node() -> Dictionary:
	return nodes.get(current_node_id, {})


func _go_to_next_node(next_id: String, pause_time: float) -> void:
	dialogue_state.stop_window_timer()
	timer_bar.hide()

	if pause_time > 0.0:
		start_pause_before_next(next_id, pause_time)
	else:
		current_node_id = next_id
		show_current_node()
