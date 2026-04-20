extends Control

@onready var dialogue_panel = $DialoguePanel
@onready var name_label = $DialoguePanel/NamePlate/NameLabel
@onready var dialogue_text = $DialoguePanel/DialogueText
@onready var portrait = $DialoguePanel/Portrait

@onready var timer_bar = $DialogueTimerBar
@onready var choice_panel = $ChoicePanel
@onready var choice_1_text = $ChoicePanel/Background/"Choice1 [X]"/AnswerOption1
@onready var choice_2_text = $ChoicePanel/Background/"Choice2 [Y]"/AnswerOption2
@onready var choice_3_text = $ChoicePanel/Background/"Choice3 [B]"/AnswerOption3

@onready var dialogue_state = $"../DialogueState"

@onready var loyalty_state = $"../LoyaltyState"
@onready var loyalty_value_label = $LoyaltyValueLabel

@onready var end_anim_rect = $"../end_anim_rect"
@onready var animation_player = $"../AnimationPlayer"

@export var player: Node3D

const LINE_TIME_LIMIT: float = 6.0
const CHOICE_TIME_LIMIT: float = 8.0

var start_id: String = ""
var nodes: Dictionary = {}
var current_node_id: String = ""
var pending_node_id: String = ""
var current_npc_id: String = ""

func _ready() -> void:
	end_anim_rect.visible = false
	load_dialogue("res://dialogue/Leva.json")
	dialogue_state.reset_dialogue_timer()
	dialogue_state.start_dialogue_timer()
	start_dialogue()
	#update_loyalty_ui()
	print("loyalty_state = ", loyalty_state)


func _process(_delta: float) -> void:
	if current_node_id == "":
		return

	if dialogue_state.is_between_window_timer_running:
		if dialogue_state.is_between_window_time_over():
			dialogue_state.stop_between_window_timer()

			if pending_node_id != "":
				current_node_id = pending_node_id
				pending_node_id = ""
				show_current_node()
		return

	if dialogue_state.is_window_timer_running:
		var t = dialogue_state.get_current_window_time()
		var limit = dialogue_state.get_current_window_limit()

		if limit > 0.0:
			var progress = 1.0 - (t / limit)
			progress = clamp(progress, 0.0, 1.0)
			timer_bar.value = progress

	if dialogue_state.is_window_time_over():
		handle_window_timeout()


func _input(event: InputEvent) -> void:
	if dialogue_state.is_between_window_timer_running:
		return
	if current_node_id == "":
		return
	
	var node = nodes.get(current_node_id, {})
	if node.is_empty():
		return
	
	var node_type = str(node.get("type", ""))
	if node_type == "line":
		if event.is_action_pressed("choice_a"):
			dialogue_state.stop_window_timer()
			go_to_next_line()
	elif node_type == "choice":
		if event.is_action_pressed("choice_x"):
			dialogue_state.stop_window_timer()
			select_choice("choice_x")
		elif event.is_action_pressed("choice_y"):
			dialogue_state.stop_window_timer()
			select_choice("choice_y")
		elif event.is_action_pressed("choice_b"):
			dialogue_state.stop_window_timer()
			select_choice("choice_b")
		



func load_dialogue(path: String) -> void:
	if not FileAccess.file_exists(path):
		push_error("Файл диалога не найден: " + path)
		return

	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Не удалось открыть файл: " + path)
		return

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var result = json.parse(json_text)

	if result != OK:
		push_error("Ошибка чтения JSON: " + path)
		return
	var data = json.data
	
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Корень JSON должен быть словарём.")
		return
	
	current_npc_id = str(data.get("npc_id", ""))
	print("current_npc_id = ", current_npc_id)
	
	start_id = str(data.get("start", ""))

	var json_nodes = data.get("nodes", [])
	if typeof(json_nodes) != TYPE_ARRAY:
		push_error("Поле 'nodes' должно быть массивом.")
		return

	nodes.clear()

	for node in json_nodes:
		if typeof(node) == TYPE_DICTIONARY and node.has("id"):
			nodes[str(node["id"])] = node


func start_dialogue() -> void:
	if start_id == "":
		push_error("В JSON не задан start.")
		return

	if not nodes.has(start_id):
		push_error("Стартовый узел не найден: " + start_id)
		return

	current_node_id = start_id
	show_current_node()
	update_loyalty_ui()

func show_current_node() -> void:
	if not nodes.has(current_node_id):
		push_error("Узел не найден: " + current_node_id)
		return

	var node = nodes[current_node_id]
	var node_type = str(node.get("type", ""))

	if node_type == "line":
		show_line_node(node)
	elif node_type == "choice":
		show_choice_node(node)
	else:
		push_error("Неизвестный тип узла: " + node_type)
	update_loyalty_ui()


func show_line_node(node: Dictionary) -> void:
	dialogue_panel.show()
	choice_panel.hide()
	dialogue_state.start_window_timer(LINE_TIME_LIMIT)

	name_label.text = str(node.get("name", ""))
	dialogue_text.text = str(node.get("text", ""))

	var portrait_path = str(node.get("portrait", ""))
	if portrait_path != "":
		portrait.texture = load(portrait_path)
	else:
		portrait.texture = null
	dialogue_state.start_window_timer(LINE_TIME_LIMIT)
	
	timer_bar.show()
	timer_bar.value = 1.0


func show_choice_node(node: Dictionary) -> void:
	dialogue_panel.hide()
	choice_panel.show()

	choice_1_text.text = ""
	choice_2_text.text = ""
	choice_3_text.text = ""

	var options = node.get("options", [])
	if options.size() > 0:
		choice_1_text.text = str(options[0].get("text", ""))
	if options.size() > 1:
		choice_2_text.text = str(options[1].get("text", ""))
	if options.size() > 2:
		choice_3_text.text = str(options[2].get("text", ""))
	
	dialogue_state.start_window_timer(CHOICE_TIME_LIMIT)
	
	timer_bar.show()
	timer_bar.value = 1.0


func go_to_next_line() -> void:
	var node = nodes.get(current_node_id, {})

	if node.is_empty():
		return

	if not node.has("next"):
		end_dialogue()
		return

	var next_id = str(node["next"])

	dialogue_state.stop_window_timer()
	timer_bar.hide()

	if node.has("pause_after"):
		var pause_time = float(node["pause_after"])
		start_pause_before_next(next_id, pause_time)
	else:
		current_node_id = next_id
		show_current_node()


func select_choice(button_name: String) -> void:
	var node = nodes.get(current_node_id, {})

	if node.is_empty():
		return

	var options = node.get("options", [])

	for option in options:
		if str(option.get("button", "")) == button_name:
			dialogue_state.stop_window_timer()
			timer_bar.hide()

			var next_id = str(option.get("next", ""))
			if next_id != "":
				current_node_id = next_id
				show_current_node()
			else:
				end_dialogue()
			return

func end_dialogue() -> void:
	get_tree().get_root().find_child("Player", true, false).end_anim()
	dialogue_state.stop_dialogue_timer()
	dialogue_state.stop_window_timer()
	end_anim_rect.visible = true
	animation_player.play("fadein")
	print("Диалог завершён")
	print("Общее время диалога: ", dialogue_state.get_total_dialogue_time())
	timer_bar.hide()
	hide()

func handle_window_timeout() -> void:
	var node = nodes.get(current_node_id, {})
	if node.is_empty():
		return
	var node_type = str(node.get("type", ""))
	dialogue_state.stop_window_timer()
	timer_bar.hide()
	if node_type == "line":
		if not node.has("next"):
			end_dialogue()
			return
		var next_id = str(node["next"])
		if node.has("pause_after"):
			var pause_time = float(node["pause_after"])
			start_pause_before_next(next_id, pause_time)
		else:
			current_node_id = next_id
			show_current_node()
	elif node_type == "choice":
		select_choice("choice_x")

func start_pause_before_next(next_id: String, pause_time: float) -> void:
	if next_id == "":
		end_dialogue()
		return

	pending_node_id = next_id
	dialogue_state.start_between_window_timer(pause_time)

	dialogue_panel.hide()
	choice_panel.hide()
	timer_bar.hide()
	
func update_loyalty_ui() -> void:
	if current_npc_id == "":
		loyalty_value_label.text = "---"
		return

	var value = loyalty_state.get_loyalty(current_npc_id)
	# print("loyalty for ", current_npc_id, " = ", value)
	loyalty_value_label.text = "" + str(value)
