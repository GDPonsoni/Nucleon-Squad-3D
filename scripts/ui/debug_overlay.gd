class_name DebugOverlay
extends CanvasLayer
## Mostra FPS e time scale no canto da tela (só em build de debug).
## Texto técnico de debug: fica fora da tabela de tradução.

var _label: Label


func _ready() -> void:
	layer = 100
	_label = Label.new()
	_label.position = Params.debug_margin
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("font_size", Params.debug_font_size)
	add_child(_label)


func _process(_delta: float) -> void:
	var text: String = "FPS %d\ntime scale %.2f" % [Engine.get_frames_per_second(), Engine.time_scale]
	if _label.text != text:
		_label.text = text
