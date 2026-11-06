class_name TipBalloon
extends CanvasLayer
## Dica do tutorial na partida: balão translúcido no alto da tela. Não pausa nem muda o tempo
## e só deixa de ignorar o toque nos próprios botões ("Pular" e "Não mostrar mais"), então
## nunca atrapalha o desvio. Só aparece depois de um tempo seguido de calma (sem tiro ou
## inimigo perto da nave). Pode destacar o botão do especial ou a barra de troca.

## () -> bool. Verdadeiro quando é seguro mostrar (ninguém perto da nave, partida rolando).
var safe_check: Callable
## (nome: String) -> Rect2. Área a destacar ("special", "switcher").
var highlight_rect: Callable

var _panel: PanelContainer
var _label: Label
var _glow: Control
var _holder: Control
var _done: Callable = Callable()
var _left: float = 0.0
var _calm_since: int = -1
var _target := Rect2()
var _tween: Tween


func _ready() -> void:
	layer = Params.tip_balloon_layer
	_holder = Control.new()
	_holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_holder.visible = false
	UiFactory.apply_theme(_holder)
	add_child(_holder)

	_glow = Control.new()
	_glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow.draw.connect(_draw_glow)
	_holder.add_child(_glow)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override("font_size", Params.tip_balloon_font_size)
	column.add_child(_label)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	buttons.add_child(_button("TIP_SKIP", func() -> void: _finish()))
	buttons.add_child(_button("TIP_DISABLE", func() -> void:
		Tutorial.disable_tips()
		_finish()))
	column.add_child(buttons)
	_panel = UiFactory.make_panel(column)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.modulate.a = Params.tip_balloon_alpha
	_holder.add_child(_panel)


func _button(text_key: String, action: Callable) -> Button:
	var button := UiFactory.make_button(text_key)
	button.custom_minimum_size = Vector2(0.0, Params.tip_balloon_button_height)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", Params.tip_balloon_button_font_size)
	button.pressed.connect(action)
	return button


## Calma contínua por tip_safe_seconds (tempo real).
func can_show(_tip: Dictionary) -> bool:
	if not safe_check.is_valid() or not safe_check.call():
		_calm_since = -1
		return false
	var now: int = Time.get_ticks_msec()
	if _calm_since < 0:
		_calm_since = now
	return now - _calm_since >= int(Params.tip_safe_seconds * 1000.0)


func present(tip: Dictionary, done: Callable) -> void:
	_done = done
	_label.text = String(tip["text_key"])
	_left = Params.tip_balloon_seconds
	_target = Rect2()
	if tip.has("highlight") and highlight_rect.is_valid():
		_target = highlight_rect.call(String(tip["highlight"]))
	var view: Vector2 = get_viewport().get_visible_rect().size
	var width: float = view.x * Params.tip_balloon_width_ratio
	# Largura do texto fixa: sem ela o texto quebra letra a letra e o balão nasce altíssimo
	_label.custom_minimum_size.x = width - Params.ui_panel_padding * 2.0
	_panel.custom_minimum_size.x = width
	_label.size = Vector2(_label.custom_minimum_size.x, 0.0)
	_panel.size = Vector2(width, 0.0)
	_refit.call_deferred()
	_panel.position = Vector2((view.x - width) * 0.5, view.y * Params.tip_balloon_y)
	_holder.visible = true
	_holder.modulate.a = 0.0
	_fade(1.0)
	Audio.play(&"ui_click")
	set_process(true)


## Depois do layout: o texto já quebrou na largura certa, então o balão encolhe à altura do texto.
func _refit() -> void:
	_label.reset_size()
	_panel.reset_size()
	_panel.size.x = _panel.custom_minimum_size.x


func is_showing() -> bool:
	return _holder != null and _holder.visible


## A partida acabou ou foi pausada para sempre: some sem contar como pulado.
func cancel() -> void:
	if is_showing():
		_finish()


func _process(delta: float) -> void:
	if not is_showing():
		return
	# Tempo real: o balão não dura mais na câmera lenta
	_left -= delta / maxf(Engine.time_scale, 0.05)
	if _left <= 0.0:
		_finish()
	if _target.size != Vector2.ZERO:
		_glow.queue_redraw()


func _finish() -> void:
	if not is_showing() or _done.is_null():
		_holder.visible = false
		return
	var done: Callable = _done
	_done = Callable()
	_fade(0.0)
	_target = Rect2()
	_glow.queue_redraw()
	done.call()


func _fade(alpha: float) -> void:
	if _tween != null:
		_tween.kill()
	_tween = create_tween().set_ignore_time_scale(true)
	_tween.tween_property(_holder, "modulate:a", alpha, 0.25)
	if alpha <= 0.0:
		_tween.tween_callback(func() -> void: _holder.visible = false)


## Anel pulsante em volta do que a dica fala.
func _draw_glow() -> void:
	if _target.size == Vector2.ZERO:
		return
	var beat: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.001 * TAU * 1.6)
	var rect: Rect2 = _target.grow(8.0 + 8.0 * beat)
	var color := Color(Params.tip_highlight_color, 0.45 + 0.5 * beat)
	_glow.draw_rect(rect, color, false, 6.0)
