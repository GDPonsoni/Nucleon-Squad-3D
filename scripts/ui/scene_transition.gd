extends CanvasLayer
## Autoload: troca de cena com fade para preto. Bloqueia toques durante a transição
## e despausa o jogo antes de trocar (a pausa persiste entre cenas).

var _fade: ColorRect
var _busy: bool = false


func _ready() -> void:
	layer = 200
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fade = ColorRect.new()
	_fade.color = Color(Params.transition_color, 0.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)


func go_to(path: String) -> void:
	if _busy:
		return
	_busy = true
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	await _fade_to(1.0)
	get_tree().paused = false
	get_tree().change_scene_to_file(path)
	# A cena nova entra no próximo frame
	await get_tree().process_frame
	await _fade_to(0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false


func _fade_to(alpha: float) -> void:
	var tween := create_tween()
	tween.set_ignore_time_scale(true)
	tween.tween_property(_fade, "color:a", alpha, Params.transition_seconds)
	await tween.finished
