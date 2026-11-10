extends "res://scripts/tools/stage_simulator.gd"
## Fotos da partida em 3D: joga a fase com o piloto automático do simulador (invulnerável,
## sem piscar) e salva uma imagem da tela nos instantes pedidos. Rodado por shot_3d.gd, com tela.
##   --stages id       fase (padrão p1_s1)
##   --at a,b,c        segundos de jogo das fotos (padrão 5,12,20)
##   --out pasta       onde salvar (padrão user://shots)
##   --speed N         acelera o jogo entre as fotos (padrão 3)
## Aceita também as opções do simulador (--boss-only, --squad, --companion, --level...).

var _shots: PackedFloat32Array = []
var _out: String = "user://shots"
var _speed: float = 3.0
var _next: int = 0
var _capturing: bool = false


func _ready() -> void:
	var args := _parse_args(OS.get_cmdline_user_args())
	for part in String(args.get("at", "5,12,20")).split(","):
		_shots.append(float(part))
	_out = String(args.get("out", _out))
	_speed = float(args.get("speed", "3"))
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
	if _clock >= _shots[_next]:
		_capture()


func _capture() -> void:
	_capturing = true
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var path: String = "%s/%s_%03d.png" % [_out, _stage_id, int(_shots[_next])]
	image.save_png(path)
	print("[shot] ", ProjectSettings.globalize_path(path))
	_next += 1
	_capturing = false
	if _next >= _shots.size():
		get_tree().quit()
