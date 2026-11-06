class_name ScreenTipPresenter
extends RefCounted
## Apresentador de dicas das telas (esquadrão, evolução, seletor): abre uma janela por cima
## da tela, só quando não há outra janela aberta.

var _screen: Node


func _init(screen: Node) -> void:
	_screen = screen


func can_show(_tip: Dictionary) -> bool:
	return is_instance_valid(_screen) and _screen.is_inside_tree() and not Dialog.is_open()


func present(tip: Dictionary, done: Callable) -> void:
	var dialog := TipDialog.open_tip(_screen, tip)
	dialog.closed.connect(done)
