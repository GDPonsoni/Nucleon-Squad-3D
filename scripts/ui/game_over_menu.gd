class_name GameOverMenu
extends CanvasLayer
## Tela de fim de jogo: jogar de novo ou voltar ao menu.

var _overlay: ColorRect


func _ready() -> void:
	# Funciona com a árvore pausada
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 60

	_overlay = UiFactory.make_overlay()
	_overlay.visible = false
	add_child(_overlay)

	var column := UiFactory.make_column()
	_overlay.add_child(UiFactory.make_centered(UiFactory.make_panel(column)))
	column.add_child(UiFactory.make_title("GAMEOVER_TITLE"))

	var retry_button := UiFactory.make_button("GAMEOVER_RETRY")
	retry_button.pressed.connect(_change_scene.bind(ScenePaths.GAME))
	column.add_child(retry_button)

	var exit_button := UiFactory.make_button("PAUSE_EXIT_TO_MENU")
	exit_button.pressed.connect(_change_scene.bind(ScenePaths.MENU))
	column.add_child(exit_button)


func open() -> void:
	get_tree().paused = true
	_overlay.visible = true


func _notification(what: int) -> void:
	# Botão Voltar do Android no fim de jogo vai para o menu
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and _overlay.visible:
		_change_scene(ScenePaths.MENU)


func _change_scene(path: String) -> void:
	SceneTransition.go_to(path)
