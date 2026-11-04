class_name DebugOverlay
extends CanvasLayer
## Mostra FPS e time scale no canto da tela (só em build de debug).
## Texto técnico de debug: fica fora da tabela de tradução.

## Opcional: função que retorna uma linha extra (ex.: contagem de objetos).
var stats: Callable

var _label: Label


func _ready() -> void:
	layer = 40  # acima do HUD, abaixo de pausa e resultados
	_label = Label.new()
	_label.position = Params.debug_margin
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("font_size", Params.debug_font_size)
	add_child(_label)


func _process(_delta: float) -> void:
	# Estatísticas podem ser escondidas nas configurações (ex.: mostrar a demo)
	_label.visible = bool(SaveGame.setting("show_stats"))
	if not _label.visible:
		return
	var text: String = "FPS %d\ntime scale %.2f" % [Engine.get_frames_per_second(), Engine.time_scale]
	if stats.is_valid():
		text += "\n" + stats.call()
	if _label.text != text:
		_label.text = text
