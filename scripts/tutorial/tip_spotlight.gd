class_name TipSpotlight
extends CanvasLayer
## Apresentador das dicas da partida: na primeira vez que algo acontece, pausa o jogo, escurece
## a tela deixando um recorte iluminado em volta do elemento (power-up, inimigo, botão, barra),
## com um anel pulsando e uma seta até o card da dica ("Entendi" / "Não mostrar mais").

var can_pause: Callable  # () -> bool: a partida pode ser pausada agora (sem outra janela aberta)
var highlight_rect: Callable  # (String) -> Rect2: retângulo de um elemento da tela pelo nome

const SHADER_CODE: String = """
shader_type canvas_item;
uniform vec2 screen_size;
uniform vec4 hole;  // x, y, largura, altura (px); largura 0 = sem recorte
uniform float corner = 40.0;
uniform float dim = 0.72;
void fragment() {
	vec2 p = UV * screen_size;
	float a = 1.0;
	if (hole.z > 0.0) {
		vec2 c = hole.xy + hole.zw * 0.5;
		vec2 q = abs(p - c) - hole.zw * 0.5 + vec2(corner);
		float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - corner;
		a = smoothstep(0.0, 22.0, d);
	}
	COLOR = vec4(0.0, 0.02, 0.06, dim * a);
}
"""

static var active: bool = false  # uma dica em destaque agora (a pausa ignora o Voltar)

var _root: Control
var _hole := Rect2()
var _card: PanelContainer
var _done: Callable
var _paused_by_me: bool = false
var _clock: float = 0.0


func _ready() -> void:
	layer = Params.tip_spotlight_layer
	process_mode = Node.PROCESS_MODE_ALWAYS


func can_show(_tip: Dictionary) -> bool:
	return _root == null and (not can_pause.is_valid() or can_pause.call())


func is_showing() -> bool:
	return _root != null


## Mostra a dica destacando o alvo: um nó da partida (posição atual) ou o "highlight" da dica.
func present(tip: Dictionary, done: Callable, target: Variant = null) -> void:
	_done = done
	_hole = _target_rect(tip, target)
	_paused_by_me = not get_tree().paused
	get_tree().paused = true
	active = true
	_build(tr(String(tip["text_key"])))


## O "highlight" da dica (elemento fixo da tela) tem prioridade; senão, o nó do evento.
func _target_rect(tip: Dictionary, target: Variant) -> Rect2:
	var name: String = String(tip.get("highlight", ""))
	if not name.is_empty() and highlight_rect.is_valid():
		var rect: Rect2 = highlight_rect.call(name)
		if rect.has_area():
			return rect.grow(Params.tip_spot_rect_margin)
	var node: Node2D = target if target is Node2D and is_instance_valid(target) else null
	if node != null and node.is_inside_tree() and node.visible:
		var r: float = float(node.get("radius")) if node.get("radius") != null else Params.tip_spot_default_radius
		r = maxf(r * Params.tip_spot_padding, Params.tip_spot_min_radius)
		return Rect2(node.global_position - Vector2.ONE * r, Vector2.ONE * r * 2.0)
	return Rect2()


func _build(text: String) -> void:
	var view: Vector2 = get_viewport().get_visible_rect().size
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP  # o jogo não recebe toques enquanto a dica está aberta
	UiFactory.apply_theme(_root)
	add_child(_root)
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = Shader.new()
	material.shader.code = SHADER_CODE
	material.set_shader_parameter("screen_size", view)
	material.set_shader_parameter("hole", Vector4(_hole.position.x, _hole.position.y, _hole.size.x, _hole.size.y))
	material.set_shader_parameter("corner", minf(_hole.size.x, _hole.size.y) * 0.5 if _hole.size.x < 400.0 else 30.0)
	shade.material = material
	_root.add_child(shade)
	# Anel pulsando em volta do recorte e seta até o card
	var marks := Control.new()
	marks.set_anchors_preset(Control.PRESET_FULL_RECT)
	marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marks.draw.connect(_draw_marks.bind(marks))
	_root.add_child(marks)
	# Card: do lado oposto ao elemento destacado
	_card = PanelContainer.new()
	var width: float = view.x * Params.tip_card_width_ratio
	_card.custom_minimum_size.x = width
	_card.position.x = (view.x - width) * 0.5
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 24)
	_card.add_child(column)
	var title := UiFactory.make_subtitle("TIP_TITLE")
	title.add_theme_color_override("font_color", Params.tip_highlight_color)
	column.add_child(title)
	var label := Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", Params.tip_card_font_size)
	label.custom_minimum_size.x = width - Params.ui_panel_padding * 2.0
	column.add_child(label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	var disable := UiFactory.make_button("TIP_DISABLE")
	disable.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	disable.pressed.connect(func() -> void:
		Tutorial.disable_tips()
		close())
	row.add_child(disable)
	var ok := UiFactory.make_primary_button("TIP_OK")
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ok.pressed.connect(close)
	row.add_child(ok)
	column.add_child(row)
	_root.add_child(_card)
	await get_tree().process_frame
	if _card == null:
		return
	var below: bool = not _hole.has_area() or _hole.get_center().y < view.y * 0.5
	if not _hole.has_area():
		_card.position.y = (view.y - _card.size.y) * 0.5
	elif below:
		_card.position.y = minf(_hole.end.y + Params.tip_card_gap, view.y - _card.size.y - 60.0)
	else:
		_card.position.y = maxf(_hole.position.y - Params.tip_card_gap - _card.size.y, 120.0)
	_root.modulate.a = 0.0
	create_tween().tween_property(_root, "modulate:a", 1.0, 0.18)
	Audio.play(&"ui_click")


func _process(delta: float) -> void:
	_clock += delta
	if _root != null:
		for child in _root.get_children():
			(child as CanvasItem).queue_redraw()


func _draw_marks(canvas: Control) -> void:
	if not _hole.has_area() or _card == null:
		return
	var pulse: float = 0.5 + 0.5 * sin(_clock * 6.0)
	var grow: float = 6.0 + pulse * 10.0
	var box := StyleBoxFlat.new()
	box.draw_center = false
	box.border_color = Color(Params.tip_highlight_color, 0.6 + 0.4 * pulse)
	box.set_border_width_all(5)
	box.set_corner_radius_all(int(minf(_hole.size.x, _hole.size.y) * 0.5 + grow) if _hole.size.x < 400.0 else 34)
	canvas.draw_style_box(box, _hole.grow(grow))
	# Seta do card até o elemento
	var card_rect := Rect2(_card.position, _card.size)
	var from := Vector2(_hole.get_center().x, card_rect.position.y if _hole.get_center().y < card_rect.position.y else card_rect.end.y)
	var to := Vector2(_hole.get_center().x, _hole.end.y + grow + 8.0 if _hole.get_center().y < card_rect.position.y else _hole.position.y - grow - 8.0)
	if absf(to.y - from.y) < 30.0:
		return
	canvas.draw_line(from, to, Params.tip_highlight_color, 5.0)
	var dir: Vector2 = (to - from).normalized()
	var side: Vector2 = dir.orthogonal() * 16.0
	canvas.draw_colored_polygon(PackedVector2Array([to, to - dir * 28.0 + side, to - dir * 28.0 - side]), Params.tip_highlight_color)


func close() -> void:
	if _root == null:
		return
	_root.queue_free()
	_root = null
	active = false
	_card = null
	if _paused_by_me:
		get_tree().paused = false
	var done: Callable = _done
	_done = Callable()
	if done.is_valid():
		done.call()


## Fim de partida: fecha sem despausar (a partida pausa por conta própria).
func cancel() -> void:
	_paused_by_me = false
	close()


func _unhandled_input(event: InputEvent) -> void:
	if _root != null and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and _root != null:
		close()
