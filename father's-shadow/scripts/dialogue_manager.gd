extends Control

@onready var dialogue_panel = $DialoguePanel
@onready var name_label = $DialoguePanel/NamePlate/NameLabel
@onready var dialogue_text = $DialoguePanel/DialogueText
@onready var portrait_root = $New_Portrait

@onready var timer_bar = $DialogueTimerBar
@onready var choice_panel = $ChoicePanel
@onready var choice_1_text = $ChoicePanel/Background/"Choice1 [X]"/AnswerOption1
@onready var choice_2_text = $ChoicePanel/Background/"Choice2 [Y]"/AnswerOption2
@onready var choice_3_text = $ChoicePanel/Background/"Choice3 [B]"/AnswerOption3
@onready var choice_1_button = $ChoicePanel/Background/"Choice1 [X]"
@onready var choice_2_button = $ChoicePanel/Background/"Choice2 [Y]"
@onready var choice_3_button = $ChoicePanel/Background/"Choice3 [B]"

@onready var end_anim_rect = $"../end_anim_rect"
@onready var animation_player = $"../AnimationPlayer"

@export var player: Node3D

@onready var dialogue_state = $"../DialogueState"

@onready var loyalty_state = $"../LoyaltyState"
@onready var loyalty_value_label = $LoyaltyValueLabel

const LINE_TIME_LIMIT: float = 6.0
const CHOICE_TIME_LIMIT: float = 8.0
const CHOICE_TEXT_NORMAL_COLOR := Color(1, 1, 1, 1)
const CHOICE_TEXT_HOVER_COLOR := Color(1, 0.8, 0.2, 1)

var start_id: String = ""
var nodes: Dictionary = {}
var current_node_id: String = ""
var pending_node_id: String = ""
var current_npc_id: String = ""

func _ready() -> void:
	#load_dialogue("res://dialogue/Leva.json")
	load_dialogue("res://dialogue/Katerina.json")
	dialogue_state.reset_dialogue_timer()
	dialogue_state.start_dialogue_timer()
	start_dialogue()
	#update_loyalty_ui()
	print("loyalty_state = ", loyalty_state)
	end_anim_rect.visible = true
	animation_player.play("fadeout")

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

	choice_1_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	choice_2_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	choice_3_text.mouse_filter = Control.MOUSE_FILTER_IGNORE


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
	if not (event is InputEventMouseButton):
		return
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed or event.is_echo():
		return

	var node = nodes.get(current_node_id, {})
	if node.is_empty():
		return

	if str(node.get("type", "")) == "line" and dialogue_panel.visible:
		if dialogue_panel.get_global_rect().has_point(event.position):
			dialogue_state.stop_window_timer()
			go_to_next_line()


func _on_dialogue_panel_gui_input(event: InputEvent) -> void:
	if dialogue_state.is_between_window_timer_running:
		return
	if current_node_id == "":
		return
	if not (event is InputEventMouseButton):
		return
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return

	var node = nodes.get(current_node_id, {})
	if node.is_empty():
		return

	var node_type = str(node.get("type", ""))
	if node_type == "line":
		dialogue_state.stop_window_timer()
		go_to_next_line()


func _on_choice_1_pressed() -> void:
	_handle_mouse_choice("choice_x")


func _on_choice_2_pressed() -> void:
	_handle_mouse_choice("choice_y")


func _on_choice_3_pressed() -> void:
	_handle_mouse_choice("choice_b")


func _handle_mouse_choice(button_name: String) -> void:
	if dialogue_state.is_between_window_timer_running:
		return
	if current_node_id == "":
		return

	var node = nodes.get(current_node_id, {})
	if node.is_empty():
		return
	if str(node.get("type", "")) != "choice":
		return

	dialogue_state.stop_window_timer()
	select_choice(button_name)

func _set_choice_text_hover(label: Control, hovered: bool) -> void:
	if label == null:
		return
	var color = CHOICE_TEXT_HOVER_COLOR if hovered else CHOICE_TEXT_NORMAL_COLOR
	if label is RichTextLabel:
		label.modulate = color
	elif label is Label:
		(label as Label).add_theme_color_override("font_color", color)

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
	set_ui_state(true, false)

	name_label.text = str(node.get("name", ""))
	dialogue_text.text = str(node.get("text", ""))

	show_portrait_node(resolve_portrait_node(node))

	timer_bar.show()
	timer_bar.value = 1.0
	dialogue_state.start_window_timer(LINE_TIME_LIMIT)

func show_choice_node(node: Dictionary) -> void:
	set_ui_state(false, true)

	show_portrait_node(resolve_portrait_node(node))

	var options = node.get("options", [])

	choice_1_text.text = ""
	choice_2_text.text = ""
	choice_3_text.text = ""

	choice_1_button.hide()
	choice_2_button.hide()
	choice_3_button.hide()
	
	_set_choice_text_hover(choice_1_text, false)
	_set_choice_text_hover(choice_2_text, false)
	_set_choice_text_hover(choice_3_text, false)

	if options.size() > 0:
		choice_1_text.text = str(options[0].get("text", ""))
		choice_1_button.show()
	if options.size() > 1:
		choice_2_text.text = str(options[1].get("text", ""))
		choice_2_button.show()
	if options.size() > 2:
		choice_3_text.text = str(options[2].get("text", ""))
		choice_3_button.show()

	timer_bar.show()
	timer_bar.value = 1.0
	dialogue_state.start_window_timer(CHOICE_TIME_LIMIT)


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

			apply_choice_loyalty(option)
			update_loyalty_ui()

			var next_id = str(option.get("next", ""))
			if next_id != "":
				current_node_id = next_id
				show_current_node()
			else:
				end_dialogue()
			return

func apply_choice_loyalty(option: Dictionary) -> void:
	if current_npc_id == "":
		return
	if loyalty_state == null:
		return

	if option.has("loyalty_change"):
		loyalty_state.change_loyalty(current_npc_id, int(option["loyalty_change"]))
	elif option.has("loyalty_set"):
		loyalty_state.set_loyalty(current_npc_id, int(option["loyalty_set"]))

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

	set_ui_state(false, false)
	
func update_loyalty_ui() -> void:
	if current_npc_id == "":
		loyalty_value_label.text = "---"
		return

	var value = loyalty_state.get_loyalty(current_npc_id)
	print("loyalty for ", current_npc_id, " = ", value)
	loyalty_value_label.text = "" + str(value)

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
	if portrait_node_path == "" or portrait_root == null:
		return
	var portrait_node = portrait_root.get_node_or_null(portrait_node_path)
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
	var portrait_node_path = str(node.get("portrait_node", ""))
	if portrait_node_path != "":
		return portrait_node_path
	var legacy_portrait = str(node.get("portrait", ""))
	match legacy_portrait:
		"res://art/Leva.png":
			return "Leva/Leva_Base"
		"res://art/Katerina.png":
			return "Katerina/Katerina_Base"
	return ""
	
func legacy_portrait_to_node_path(legacy_path: String) -> String:
	match legacy_path:
		"res://art/Katerina.png":
			return "Katerina/Katerina_Base"
		"res://art/Leva.png":
			return "Leva/Leva_Base"
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

	if not ui_visible:
		timer_bar.hide()
		hide_all_portraits()
