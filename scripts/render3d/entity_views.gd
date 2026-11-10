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
# Inimigos do pool: item -> vista
var _enemy_views: Dictionary = {}
# Itens (power-ups, kits, baús) e orbes de XP: item do pool -> vista
var _item_views: Dictionary = {}
var _orb_views: Dictionary = {}
var _clock: float = 0.0  # tempo de jogo, só para giros decorativos
# Chefe (fora do pool): conjunto de peças montado quando ele entra
var _boss: Boss
var _boss_root: Node3D
var _boss_parts: Dictionary = {}


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


func _process(delta: float) -> void:
	_clock += delta
	_sync_player()
	_sync_companion()
	_sync_body_fx()
	_sync_enemies()
	_sync_boss()
	_sync_items()
	_sync_orbs()


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
	instance.set_instance_shader_parameter(&"flash", Color(flash, flash.a * Params.flash_strength_3d))
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


# --- Inimigos comuns, rochas e elites (pool) ---

func _sync_enemies() -> void:
	var pool: NodePool = _game.get("enemies")
	if pool == null:
		return
	for child in pool.get_children():
		var enemy := child as Enemy
		if enemy == null:
			continue
		var view: MeshInstance3D = _enemy_views.get(enemy)
		if view == null:
			view = _make("Enemy")
			_enemy_views[enemy] = view
		view.visible = enemy.visible and enemy.data != null
		if not view.visible:
			continue
		var data: EnemyData = enemy.data
		view.mesh = ModelLibrary.rock(enemy.rock_variant()) if data.look == EnemyData.Look.ROCK else ModelLibrary.enemy(data.sides)
		# O raio de colisão dá o tamanho (elites já vêm com o raio maior)
		view.transform = Transform3D(_yaw(enemy.rotation).scaled(Vector3.ONE * enemy.radius * _scale), _at(enemy.position))
		_paint(view, enemy.tint(), enemy.flash_color(), Params.elite_glow_3d if enemy.elite else 0.0)


# --- Chefe: casco, miolo girando, espinhos, placas, torretas, olho e rachaduras ---

func _sync_boss() -> void:
	var boss: Boss = _game.get("boss")
	if boss != null and not is_instance_valid(boss):
		boss = null
	if boss != _boss:
		if _boss_root != null:
			_boss_root.queue_free()
			_boss_root = null
		_boss_parts.clear()
		_boss = boss
		if boss != null and boss.boss_data != null:
			_build_boss(boss.boss_data)
	if _boss == null or _boss_root == null:
		return
	var data: BossData = _boss.boss_data
	_boss_root.visible = _boss.visible
	if not _boss.visible:
		return
	# Raio 1 nas peças: o raio de colisão e a escala da entrada (surgimento) dão o tamanho
	var size: float = _boss.radius * _boss.scale.x * _scale
	_boss_root.transform = Transform3D(_yaw(_boss.rotation).scaled(Vector3.ONE * maxf(size, 0.0001)), _at(_boss.position))
	var opacity: float = _boss.modulate.a
	var flash: Color = _boss.flash_color()
	var fury: float = _boss.fury()
	var h: float = Params.model_height_ratio_3d
	_paint(_boss_parts["hull"], data.color, flash, 0.0, opacity)
	var core: MeshInstance3D = _boss_parts["core"]
	core.basis = _yaw(_boss.core_angle())
	_paint(core, data.color.darkened(0.45), flash, 0.0, opacity)
	var spikes: Array = _boss_parts["spikes"]
	for i in spikes.size():
		(spikes[i] as MeshInstance3D).basis = _yaw(_boss.spike_angle(i))
		_paint(spikes[i], data.color.darkened(0.3), flash, 0.0, opacity)
	var plates: Array = _boss_parts["plates"]
	for i in plates.size():
		(plates[i] as MeshInstance3D).basis = _yaw(_boss.plate_angle(i))
		_paint(plates[i], data.accent_color.darkened(0.2), flash, 0.0, opacity)
	var player: Player = _game.get("player")
	var turrets: Array = _boss_parts["turrets"]
	for i in turrets.size():
		var turret := turrets[i] as MeshInstance3D
		var spot: Vector2 = _boss.turret_spot(i)
		var aim: float = PI * 0.5
		if player != null:
			aim = (player.position - (_boss.position + spot)).angle()
		# O cano do modelo aponta para +Z (ângulo 90° no 2D)
		turret.transform = Transform3D(_yaw(aim - PI * 0.5), Vector3(spot.x, 0.0, spot.y) / maxf(_boss.radius, 1.0))
		_paint(turret, data.accent_color, flash, 0.0, opacity)
	# Olho: segue a nave e fica vermelho na fúria
	var eye: MeshInstance3D = _boss_parts["eye"]
	var eye_r: float = 0.26
	var pulse: float = _boss.eye_pulse()
	eye.transform = Transform3D(Basis.from_scale(Vector3(eye_r, eye_r * 0.5, eye_r) * (1.0 + 0.04 * pulse)), Vector3(0.0, h * 0.7, 0.0))
	_paint(eye, Color.WHITE, flash, 0.35 + 0.25 * pulse, opacity)
	var look := Vector2.ZERO
	if player != null:
		look = (player.position - _boss.position).normalized() * eye_r * 0.45
	var pupil: MeshInstance3D = _boss_parts["pupil"]
	pupil.transform = Transform3D(Basis.from_scale(Vector3.ONE * eye_r * 0.45), Vector3(look.x, h * 0.7 + eye_r * 0.42, look.y))
	_paint(pupil, Color(0.1, 0.05, 0.1).lerp(Color(0.9, 0.1, 0.15), fury), NO_FLASH, fury * 0.8, opacity)
	var cracks: Array = _boss_parts["cracks"]
	var count: int = _boss.crack_count()
	for i in cracks.size():
		(cracks[i] as MeshInstance3D).visible = i < count
		if i < count:
			_paint(cracks[i], Params.boss_crack_color_3d, NO_FLASH, Params.boss_crack_glow_3d * (0.7 + 0.3 * pulse), opacity)


func _build_boss(data: BossData) -> void:
	_boss_root = Node3D.new()
	_boss_root.name = "Boss"
	add_child(_boss_root)
	_boss_parts["hull"] = _boss_part("Hull", ModelLibrary.boss_hull(data.sides))
	_boss_parts["core"] = _boss_part("Core", ModelLibrary.boss_core(data.sides))
	_boss_parts["eye"] = _boss_part("Eye", MeshFactory.icosphere_low())
	_boss_parts["pupil"] = _boss_part("Pupil", ModelLibrary.boss_pupil())
	var spikes: Array = []
	for i in data.spikes:
		spikes.append(_boss_part("Spike", ModelLibrary.boss_spike()))
	_boss_parts["spikes"] = spikes
	var plates: Array = []
	for i in data.plates:
		plates.append(_boss_part("Plate", ModelLibrary.boss_plate(data.plates)))
	_boss_parts["plates"] = plates
	var turrets: Array = []
	for i in data.turrets:
		turrets.append(_boss_part("Turret", ModelLibrary.boss_turret()))
	_boss_parts["turrets"] = turrets
	var cracks: Array = []
	for i in 6:
		cracks.append(_boss_part("Crack", ModelLibrary.boss_crack(i)))
	_boss_parts["cracks"] = cracks


func _boss_part(node_name: String, mesh: Mesh) -> MeshInstance3D:
	var part := _make(node_name, mesh)
	remove_child(part)
	_boss_root.add_child(part)
	part.visible = true
	return part


# --- Itens: power-up (octaedro girando), kit médico (caixa com cruz) e baú ---

func _sync_items() -> void:
	var pool: NodePool = _game.get("power_ups")
	if pool == null:
		return
	for child in pool.get_children():
		var item := child as PowerUp
		if item == null:
			continue
		var view: MeshInstance3D = _item_views.get(item)
		if view == null:
			view = _make("Item")
			_item_views[item] = view
		view.visible = item.visible
		if not view.visible:
			continue
		var radius: float = Params.powerup_radius * item.scale.x
		var color: Color = Params.powerup_color
		var basis: Basis = _yaw(item.rotation)
		var lift: float = 0.0
		match item.kind:
			PowerUp.Kind.HEAL:
				view.mesh = ModelLibrary.medkit()
				color = Params.medkit_color
				# O kit não gira no 2D: aqui balança de leve para chamar atenção
				basis = Basis(Vector3.BACK, sin(_clock * 3.0) * 0.18)
			PowerUp.Kind.CHEST:
				view.mesh = ModelLibrary.chest()
				color = Params.chest_color
				radius *= Params.chest_scale
				basis = Basis(Vector3.BACK, sin(_clock * 3.0) * 0.12)
			PowerUp.Kind.COMPANION:
				view.mesh = ModelLibrary.gem()
				color = Params.companion_powerup_color
				radius *= 0.95
				lift = radius * 0.7
			_:
				view.mesh = ModelLibrary.gem()
				radius *= 0.75
				lift = radius * 0.7
		view.transform = Transform3D(basis.scaled(Vector3.ONE * radius * _scale), _at(item.position, lift))
		_paint(view, color, NO_FLASH, Params.item_glow_3d)


# --- Orbes de XP (modo Incursão) ---

func _sync_orbs() -> void:
	var pool: NodePool = _game.get("orbs")
	if pool == null:
		return
	for child in pool.get_children():
		var orb := child as XpOrb
		if orb == null:
			continue
		var view: MeshInstance3D = _orb_views.get(orb)
		if not orb.visible:
			if view != null:
				view.visible = false
			continue
		if view == null:
			view = _make("XpOrb", ModelLibrary.gem(0.7))
			_orb_views[orb] = view
		view.visible = true
		var radius: float = orb.draw_radius()
		# Cada orbe gira num ritmo um pouco diferente (pela posição no pool)
		var spin: float = _clock * Params.orb_spin_3d + orb.get_index() * 0.7
		view.transform = Transform3D(Basis(Vector3.UP, spin).scaled(Vector3.ONE * radius * _scale), _at(orb.position, radius * 0.7))
		_paint(view, Params.xp_orb_color, NO_FLASH, Params.item_glow_3d)
