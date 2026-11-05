class_name Dialog
extends CanvasLayer
## Cena-base de diálogo: fundo escurecido, painel com largura relativa à tela, botão X
## (144 px, >= 48 dp), título opcional e corpo que rola se não couber na altura.
## O botão Voltar do Android e a tecla Esc fecham só o diálogo do topo da pilha.
## Uso: var d := Dialog.open(self, "TITULO"); d.body.add_child(...); d.closed.connect(...)

signal closed

## Pilha de diálogos abertos (o último é o do topo).
static var _stack: Array[Dialog] = []

var title_key: String = ""
## Mostra o X. Sem ele, só fecha por back_handler (ou pelos botões do corpo).
var closable: bool = true
## Chamado no lugar de close() ao pedir para fechar (X / Voltar). Ex.: voltar de uma sub-lista.
var back_handler: Callable = Callable()
var dialog_layer: int = Params.dialog_layer
var body: VBoxContainer
var overlay: ColorRect
var panel: PanelContainer
## Largura útil do corpo (dentro do painel), calculada pela tela.
var content_width: float = 0.0

var _frame: VBoxContainer
var _center: CenterContainer
var _scroll: ScrollContainer
var _close_button: Button
var _ready_frame: int = -1
var _closing: bool = false
var _fit_queued: bool = false
var _close_blocked: bool = false


## Cria o diálogo por cima da tela e já devolve com o corpo pronto para receber nós.
static func open(parent: Node, title: String = "", can_close: bool = true, at_layer: int = Params.dialog_layer) -> Dialog:
	var dialog := Dialog.new()
	dialog.title_key = title
	dialog.closable = can_close
	dialog.dialog_layer = at_layer
	parent.add_child(dialog)
	return dialog


static func is_open() -> bool:
	return not _stack.is_empty()


## Impede (ou libera) fechar. Usado enquanto algo não pode ser interrompido (ex.: anúncio).
var close_blocked: bool:
	get:
		return _close_blocked
	set(value):
		_close_blocked = value
		if _close_button != null:
			_close_button.disabled = value
			_close_button.modulate.a = 0.4 if value else 1.0


func _ready() -> void:
	layer = dialog_layer
	# Funciona com o jogo pausado
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ready_frame = Engine.get_process_frames()
	_stack.append(self)

	overlay = UiFactory.make_overlay()
	add_child(overlay)
	var view: Vector2 = get_viewport().get_visible_rect().size
	var panel_width: float = view.x * Params.dialog_width_ratio
	content_width = panel_width - Params.ui_panel_padding * 2.0

	_frame = VBoxContainer.new()
	_frame.add_theme_constant_override("separation", Params.dialog_spacing)
	panel = UiFactory.make_panel(_frame)
	panel.custom_minimum_size.x = panel_width
	_center = UiFactory.make_centered(panel)
	overlay.add_child(_center)

	if closable:
		_frame.add_child(_make_close_row())
	if not title_key.is_empty():
		_frame.add_child(_make_title())

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_frame.add_child(_scroll)
	body = VBoxContainer.new()
	body.custom_minimum_size.x = content_width
	body.add_theme_constant_override("separation", Params.dialog_spacing)
	_scroll.add_child(body)
	body.minimum_size_changed.connect(_queue_fit)
	# Texto quebra linha desde o primeiro layout (sem isso a janela nasce larga demais)
	body.child_entered_tree.connect(_wrap_label)

	_build_body()
	UiFactory.animate_in(_center)
	_queue_fit()


## Para subclasses (ex.: AdOfferPopup) montarem o corpo.
func _build_body() -> void:
	pass


func _exit_tree() -> void:
	_stack.erase(self)


func _make_close_row() -> Control:
	var row := HBoxContainer.new()
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_close_button = UiFactory.make_button("MENU_BACK")
	_close_button.text = ""  # só o X; a chave serve ao som do botão
	_close_button.custom_minimum_size = Vector2.ONE * Params.dialog_close_size
	_close_button.draw.connect(_draw_close_icon)
	_close_button.pressed.connect(request_close)
	_close_button.disabled = _close_blocked
	row.add_child(_close_button)
	return row


func _draw_close_icon() -> void:
	var c: Vector2 = _close_button.size * 0.5
	var h: float = _close_button.size.y * 0.2
	var width: float = maxf(_close_button.size.y * 0.07, 4.0)
	var color: Color = Params.ui_text_color
	_close_button.draw_line(c + Vector2(-h, -h), c + Vector2(h, h), color, width)
	_close_button.draw_line(c + Vector2(-h, h), c + Vector2(h, -h), color, width)


func _make_title() -> Label:
	var label := UiFactory.make_title(title_key)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", UiFactory.fit_font_size(tr(title_key), content_width, Params.title_font_size))
	return label


## X e Voltar passam por aqui.
func request_close() -> void:
	if _close_blocked or _closing:
		return
	if back_handler.is_valid():
		back_handler.call()
	elif closable:
		close()


## Fecha de vez (os botões do corpo chamam isto).
func close() -> void:
	if _closing:
		return
	_closing = true
	_stack.erase(self)
	closed.emit()
	queue_free()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _is_top():
		_on_back()
		get_viewport().set_input_as_handled()


func _is_top() -> bool:
	return not _stack.is_empty() and _stack.back() == self


func _on_back() -> void:
	# Um diálogo aberto neste mesmo quadro (pelo mesmo Voltar) não fecha na hora
	if _is_top() and Engine.get_process_frames() != _ready_frame:
		request_close()


func _wrap_label(node: Node) -> void:
	if node is Label and (node as Label).autowrap_mode == TextServer.AUTOWRAP_OFF:
		(node as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _queue_fit() -> void:
	if _fit_queued:
		return
	_fit_queued = true
	_fit.call_deferred()


## Ajusta o corpo: textos que quebram linha, fontes de botões que cabem e altura máxima (rola).
func _fit() -> void:
	_fit_queued = false
	if not is_inside_tree() or _scroll == null:
		return
	for child in body.get_children():
		_wrap_label(child)
		if child is Button and not (child as Button).text.is_empty():
			UiFactory.fit_button_text(child as Button, content_width)
	_scroll.custom_minimum_size.y = 0.0
	var view_h: float = get_viewport().get_visible_rect().size.y
	var max_total: float = view_h * Params.dialog_height_ratio - Params.ui_panel_padding * 2.0
	var other: float = _frame.get_combined_minimum_size().y
	var wanted: float = body.get_combined_minimum_size().y
	_scroll.custom_minimum_size.y = minf(wanted, maxf(max_total - other, 200.0))
	# O layout de nascença pode deixar o fundo e o centro maiores que a tela: refaz o tamanho
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_center.size = overlay.size
