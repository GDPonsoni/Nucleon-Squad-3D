class_name EntityViews
extends Node3D
## Espelha as entidades do jogo em modelos 3D: um MeshInstance3D reaproveitado por entidade,
## sincronizado a cada quadro depois da simulação. Só lê as entidades (posição, cor, estado
## de desenho): nunca muda nada nelas.

const NO_FLASH := Color(1.0, 1.0, 1.0, 0.0)

var _game: Node2D
var _rig: CameraRig
var _material: ShaderMaterial
var _scale: float = 0.01

# Jogador
var _hull: MeshInstance3D
var _nucleus: MeshInstance3D
var _nucleus_ring: MeshInstance3D
var _companion_hull: MeshInstance3D
# Corpos que saem de cena (BodyFx): item do pool -> vistas
var _fx_hulls: Dictionary = {}
var _fx_pieces: Dictionary = {}


func setup(game: Node2D, rig: CameraRig) -> void:
	_game = game
	_rig = rig
	_scale = rig.world_scale
	_material = ShaderMaterial.new()
	_material.shader = load("res://scripts/render3d/shaders/entity.gdshader") as Shader
	_hull = _make("PlayerHull")
	_nucleus = _make("Nucleus", ModelLibrary.nucleus())
	_nucleus_ring = _make("NucleusRing", MeshFactory.ring(0.86, 24))
	_companion_hull = _make("CompanionHull")


func _process(_delta: float) -> void:
	_sync_player()
	_sync_companion()
	_sync_body_fx()


## Cria um modelo escondido com o material comum.
func _make(node_name: String, mesh: Mesh = null) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = _material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.visible = false
	add_child(instance)
	return instance


## Cor, clarão (a = força), brilho próprio e opacidade de um modelo.
func _paint(instance: MeshInstance3D, tint: Color, flash: Color = NO_FLASH, glow: float = 0.0, opacity: float = 1.0) -> void:
	instance.set_instance_shader_parameter(&"tint", tint)
	instance.set_instance_shader_parameter(&"flash", flash)
	instance.set_instance_shader_parameter(&"glow", glow)
	instance.set_instance_shader_parameter(&"opacity", opacity)


## Ponto do jogo (px) -> mundo, com a altura também em px do jogo.
func _at(pos: Vector2, height: float = 0.0) -> Vector3:
	return _rig.to_world(pos, height * _scale)


## Giro 2D (horário na tela) -> giro em volta do eixo Y.
static func _yaw(rotation_2d: float) -> Basis:
	return Basis(Vector3.UP, -rotation_2d)


# --- Jogador ---

func _sync_player() -> void:
	var player: Player = _game.get("player")
	if player == null:
		_hull.visible = false
		_nucleus.visible = false
		_nucleus_ring.visible = false
		return
	var opacity: float = player.draw_opacity()
	var tilt: float = Params.tilt_intensity
	# Rola para o lado do movimento e baixa o nariz ao avançar
	var lean := Basis(Vector3.BACK, -player.bank * Params.ship_roll_3d * tilt) * Basis(Vector3.RIGHT, player.pitch * Params.ship_pitch_3d * tilt)
	var body: BodyData = player.body
	_hull.visible = body != null and player.build_progress() > 0.0
	if _hull.visible:
		_hull.mesh = ModelLibrary.ship(body)
		_hull.transform = Transform3D(lean.scaled(Vector3.ONE * _scale * maxf(player.body_grow(), 0.001)), _at(player.position))
		_paint(_hull, body.color, Color(1.0, 1.0, 1.0, player.entry_glow()), 0.0, opacity)

	# Núcleo: é a hitbox, fica por cima do casco e sempre visível
	_nucleus.visible = true
	var r: float = Params.nucleus_radius * _scale
	_nucleus.transform = Transform3D(lean.scaled(Vector3.ONE * r), _at(player.position, Params.nucleus_height_3d))
	# Cada corpo perdido esquenta a cor do núcleo (no 2D: uma rachadura por corpo)
	var heat: float = clampf(player.cracks * Params.nucleus_crack_heat_3d, 0.0, 0.75)
	_paint(_nucleus, Params.nucleus_color.lerp(Params.hud_hit_flash_color, heat), NO_FLASH, Params.nucleus_glow_3d, opacity)

	var ring: Vector2 = player.nucleus_ring()
	_nucleus_ring.visible = true
	_nucleus_ring.transform = Transform3D(Basis.from_scale(Vector3.ONE * ring.x * _scale),
		_at(player.position, Params.nucleus_height_3d + Params.nucleus_radius * 0.3))
	_paint(_nucleus_ring, Params.nucleus_color, NO_FLASH, 1.0, ring.y * opacity)


# --- Nave auxiliar ---

func _sync_companion() -> void:
	var companion: Companion = _game.get("companion")
	if companion == null or companion.body == null:
		_companion_hull.visible = false
		return
	_companion_hull.visible = true
	_companion_hull.mesh = ModelLibrary.ship(companion.body)
	var size: float = Params.companion_scale * companion.draw_scale() * _scale
	var lean := Basis(Vector3.BACK, -companion.draw_roll() * Params.companion_roll_gain_3d)
	_companion_hull.transform = Transform3D(lean.scaled(Vector3.ONE * size), _at(companion.position))
	_paint(_companion_hull, companion.body.color, NO_FLASH, 0.0, clampf(companion.modulate.a / maxf(Params.companion_alpha, 0.01), 0.0, 1.0))


# --- Corpo que sai de cena (troca) ou quebra (perda) ---

func _sync_body_fx() -> void:
	var pool: NodePool = _game.get("body_fx")
	if pool == null:
		return
	for child in pool.get_children():
		var fx := child as BodyFx
		if fx == null:
			continue
		if not _fx_hulls.has(fx):
			_fx_hulls[fx] = _make("BodyFxHull")
			_fx_pieces[fx] = []
		var hull: MeshInstance3D = _fx_hulls[fx]
		var pieces: Array = _fx_pieces[fx]
		var active: bool = fx.visible and fx.body_data() != null
		hull.visible = active and fx.kind() == BodyFx.Kind.EXIT
		var count: int = fx.piece_count() if active else 0
		while pieces.size() < count:
			pieces.append(_make("BodyFxPiece"))
		for i in pieces.size():
			(pieces[i] as MeshInstance3D).visible = i < count
		if not active:
			continue
		var body: BodyData = fx.body_data()
		var t: float = fx.progress()
		if hull.visible:
			# Recolhe para o núcleo girando, encolhendo e sumindo
			var e: float = fx.exit_ease()
			hull.mesh = ModelLibrary.ship(body)
			hull.transform = Transform3D(_yaw(Params.exit_spin * Params.anim_intensity * e).scaled(Vector3.ONE * _scale * maxf(1.0 - e, 0.001)), _at(fx.position))
			_paint(hull, fx.tint().lightened(0.3 * t), Color(1.0, 1.0, 1.0, fx.exit_glow()), 0.0, fx.fade_alpha())
		for i in count:
			var piece := pieces[i] as MeshInstance3D
			piece.mesh = ModelLibrary.ship_piece(body, i)
			var spin: float = fx.piece_rotation(i)
			var basis: Basis = _yaw(spin) * Basis(Vector3.RIGHT, spin * Params.break_tumble_3d)
			piece.transform = Transform3D(basis.scaled(Vector3.ONE * _scale * fx.piece_scale()), _at(fx.position + fx.piece_position(i)))
			# Borda quente que esfria (no 2D: contorno claro que some)
			_paint(piece, fx.tint().lightened(0.2 * (1.0 - t)), Color(1.0, 0.9, 0.7, 0.35 * (1.0 - t)), 0.0, fx.fade_alpha())
