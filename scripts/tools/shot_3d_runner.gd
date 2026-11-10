extends "res://scripts/tools/stage_simulator.gd"
## Fotos da partida em 3D: joga a fase com o piloto automático do simulador (invulnerável,
## sem piscar) e salva uma imagem da tela nos instantes pedidos. Rodado por shot_3d.gd, com tela.
##   --stages id       fase (padrão p1_s1)
##   --at a,b,c        segundos de jogo das fotos (padrão 5,12,20)
##   --out pasta       onde salvar (padrão user://shots)
##   --speed N         acelera o jogo entre as fotos (padrão 3)
##   --items N         além dos instantes, fotografa as N primeiras vezes em que há um item na tela
## Aceita também as opções do simulador (--boss-only, --squad, --companion, --level...).

var _shots: PackedFloat32Array = []
var _out: String = "user://shots"
var _speed: float = 3.0
var _next: int = 0
var _capturing: bool = false
var _items_left: int = 0
var _item_gap: float = 0.0


func _ready() -> void:
	var args := _parse_args(OS.get_cmdline_user_args())
	for part in String(args.get("at", "5,12,20")).split(","):
		_shots.append(float(part))
	_out = String(args.get("out", _out))
	_speed = float(args.get("speed", "3"))
	_items_left = int(args.get("items", "0"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	Params.invulnerability_alpha = 1.0  # o piloto é invulnerável: não pisca nas fotos
	super()
	if _queue.size() > 1:
		_queue.resize(1)


func _process(delta: float) -> void:
	if _capturing:
		return
	super(delta)
	if _game == null or _next >= _shots.size():
		if _game == null:
			get_tree().quit()
		return
	Engine.time_scale = _speed if _shots[_next] - _clock > 0.6 else 1.0
	_item_gap -= delta
	if _items_left > 0 and _item_gap <= 0.0 and _item_on_screen():
		_items_left -= 1
		_item_gap = 6.0
		_capture("item%d" % _items_left, false)
	elif _clock >= _shots[_next]:
		_capture("%03d" % int(_shots[_next]), true)


func _item_on_screen() -> bool:
	var context: CombatContext = _game.get("context")
	var view: Rect2 = get_viewport().get_visible_rect()
	for item in context.power_ups.active:
		if item.position.y > view.size.y * 0.25 and item.position.y < view.size.y * 0.7:
			return true
	return false


func _capture(label: String, advance: bool) -> void:
	_capturing = true
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var path: String = "%s/%s_%s.png" % [_out, _stage_id, label]
	image.save_png(path)
	print("[shot] ", ProjectSettings.globalize_path(path))
	if advance:
		_next += 1
	_capturing = false
	if _next >= _shots.size():
		get_tree().quit()
