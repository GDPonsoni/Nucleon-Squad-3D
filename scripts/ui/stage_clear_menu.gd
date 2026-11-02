class_name StageClearMenu
extends CanvasLayer
## Tela de fase concluída: seguir para a próxima fase ou voltar ao menu.

var _overlay: ColorRect
var _next_button: Button


func _ready() -> void:
	# Funciona com a árvore pausada
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 60

	_overlay = UiFactory.make_overlay()
	_overlay.visible = false
	add_child(_overlay)

	var column := UiFactory.make_column()
	_overlay.add_child(UiFactory.make_centered(UiFactory.make_panel(column)))
	column.add_child(UiFactory.make_title("STAGE_CLEAR_TITLE"))

	_next_button = UiFactory.make_button("STAGE_NEXT")
	_next_button.pressed.connect(_on_next_pressed)
	column.add_child(_next_button)

	var exit_button := UiFactory.make_button("PAUSE_EXIT_TO_MENU")
	exit_button.pressed.connect(_change_scene.bind(ScenePaths.MENU))
	column.add_child(exit_button)


func open() -> void:
	get_tree().paused = true
	_next_button.visible = Session.has_next()
	_overlay.visible = true


func _on_next_pressed() -> void:
	Session.select_next()
	_change_scene(ScenePaths.GAME)


func _change_scene(path: String) -> void:
	SceneTransition.go_to(path)
