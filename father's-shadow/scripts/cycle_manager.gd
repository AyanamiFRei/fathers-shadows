## cycle_manager.gd
## Глобальный синглтон (Autoload). Управляет сменой циклов игры:
##   Хаб → Дневная смена (цепочка диалогов) → Ночная смена → …
##
## Подключение:
##   Project → Project Settings → Autoload → добавить этот файл с именем "CycleManager".
##
## Минимальные изменения в dialogue_manager.gd (см. комментарии ниже):
##   1. Убрать «const DIALOGUE_PATH := …»
##   2. В _ready() заменить load_dialogue(DIALOGUE_PATH) на
##        load_dialogue(CycleManager.get_day_dialogue_path())
##   3. В _ready() добавить:
##        animation_player.animation_finished.connect(_on_animation_finished)
##   4. Добавить функцию:
##        func _on_animation_finished(anim_name: StringName) -> void:
##            if anim_name == &"fadein":
##                CycleManager.advance_day()

extends Node


# ─────────────────────────────────────────────────────────────
#  Перечисления и константы
# ─────────────────────────────────────────────────────────────

enum Cycle { HUB, DAY, NIGHT }

const SCENE_HUB  := "res://assets/cab/cab.tscn"
const SCENE_DAY  := "res://scenes/dayshift.tscn"

## Ночные сцены перебираются по очереди с каждым новым циклом.
const NIGHT_SCENES: Array = [
	"res://scenes/nightshift1.tscn",
	"res://scenes/nightshift2.tscn",
]

## Диалоги дневной смены — строго по порядку.
## Замените и дополните пути под актуальную структуру проекта.
const DAY_DIALOGUES: Array = [
	"res://dialogue/Leva.json",
	"res://dialogue/Katerina.json",
	"res://dialogue/Police.json",
	"res://dialogue/Grigory.json",
	"res://dialogue/Telephone1.json",
]


# ─────────────────────────────────────────────────────────────
#  Состояние
# ─────────────────────────────────────────────────────────────

var current_cycle: Cycle = Cycle.HUB

## Индекс текущего диалога внутри дневной смены.
var day_dialogue_index: int = 0

## Счётчик пройденных ночей (определяет, какая ночная сцена загрузится).
var night_count: int = 0


# ─────────────────────────────────────────────────────────────
#  Публичный API
# ─────────────────────────────────────────────────────────────

## Возвращает путь к JSON-диалогу для текущего шага дневной смены.
## Вызывается из dialogue_manager._ready() вместо хардкода DIALOGUE_PATH.
func get_day_dialogue_path() -> String:
	if day_dialogue_index >= 0 and day_dialogue_index < DAY_DIALOGUES.size():
		return DAY_DIALOGUES[day_dialogue_index]

	push_error("CycleManager: индекс диалога %d вне диапазона [0, %d)."
			% [day_dialogue_index, DAY_DIALOGUES.size()])
	return DAY_DIALOGUES[0]


## Запустить дневную смену с первого диалога.
## Вызывается из хаба, когда игрок готов выйти на маршрут.
func start_day() -> void:
	current_cycle = Cycle.DAY
	day_dialogue_index = 0
	get_tree().change_scene_to_file(SCENE_DAY)


## Продвинуть дневной цикл после завершения диалога (вызов по окончании анимации fadein).
## Если диалоги не кончились — перезагружает ту же сцену с новым диалогом.
## Если все диалоги пройдены — переходит в ночную смену.
func advance_day() -> void:
	if current_cycle != Cycle.DAY:
		push_warning("CycleManager.advance_day() вызван вне дневного цикла — игнорируется.")
		return

	day_dialogue_index += 1

	if day_dialogue_index < DAY_DIALOGUES.size():
		# Следующий диалог в той же сцене: перезапускаем dayshift.
		# reload_current_scene() сбрасывает все узлы и вызывает _ready() заново,
		# поэтому dialogue_manager подхватит новый индекс через get_day_dialogue_path().
		get_tree().reload_current_scene()
	else:
		_begin_night()


## Завершить ночную смену и вернуться в хаб.
## Вызывается из ночной сцены, когда её условие выполнено.
func finish_night() -> void:
	if current_cycle != Cycle.NIGHT:
		push_warning("CycleManager.finish_night() вызван вне ночного цикла — игнорируется.")
		return

	current_cycle = Cycle.HUB
	get_tree().change_scene_to_file(SCENE_HUB)


# ─────────────────────────────────────────────────────────────
#  Внутренние переходы
# ─────────────────────────────────────────────────────────────

func _begin_night() -> void:
	current_cycle = Cycle.NIGHT
	var scene_path: String = NIGHT_SCENES[night_count % NIGHT_SCENES.size()]
	night_count += 1
	get_tree().change_scene_to_file(scene_path)
