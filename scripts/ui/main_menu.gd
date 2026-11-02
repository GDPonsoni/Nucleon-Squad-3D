extends Control
## Menu inicial: entrar na partida ou sair do jogo.


func _ready() -> void:
	RenderingServer.set_default_clear_color(Params.background_color)
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var column := UiFactory.make_column()
	add_child(UiFactory.make_centered(column))

	column.add_child(UiFactory.make_title("GAME_TITLE"))

	var play_button := UiFactory.make_button("MENU_PLAY")
	play_button.pressed.connect(_on_play_pressed)
	column.add_child(play_button)

	var quit_button := UiFactory.make_button("MENU_QUIT")
	quit_button.pressed.connect(_on_quit_pressed)
	column.add_child(quit_button)


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file(ScenePaths.GAME)


func _on_quit_pressed() -> void:
	get_tree().quit()
