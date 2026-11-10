class_name ParticleView
extends Node3D
## Partículas 3D: estilhaços das explosões, fagulhas dos acertos, rastro do propulsor e brilho
## ao coletar um item. Um MultiMesh só (um draw call), com as partículas simuladas aqui e um
## teto rígido de partículas vivas (Params.particle_budget_3d): nada é instanciado durante a
## partida.
## Não usa GPUParticles3D nem CPUParticles3D de propósito: os dois consomem o sorteio global do
## motor ao serem criados, o que mudaria a sequência de ondas da partida. Aqui o sorteio é
## próprio, com semente fixa.
## Só observa o jogo: percebe uma explosão nova olhando o pool de Explosion (a idade volta a
## zero quando o item é reaproveitado).

var _game: Node2D
var _rig: CameraRig
var _scale: float = 0.01
var _multimesh: MultiMesh
var _rng := RandomNumberGenerator.new()
var _reduced: bool = false

# Partículas vivas ficam em [0, _alive); morrer = trocar com a última
var _alive: int = 0
var _capacity: int = 0
var _pos := PackedVector3Array()
var _vel := PackedVector3Array()
var _life := PackedFloat32Array()  # segundos restantes
var _span := PackedFloat32Array()  # duração total
var _size := PackedFloat32Array()
var _spin := PackedFloat32Array()  # rad/s
var _gravity := PackedFloat32Array()
var _color := PackedColorArray()
var _cursor: int = 0  # teto atingido: as novas substituem as mais antigas, em rodízio
var _trail_debt: float = 0.0
# Última idade vista de cada item dos pools (< 0 = estava inativo)
var _seen: Dictionary = {}
var bursts: int = 0  # rajadas disparadas (testes)


## game pode ser null (testes): aí só valem as rajadas pedidas por emit().
func setup(game: Node2D, rig: CameraRig) -> void:
	_game = game
	_rig = rig
	_scale = rig.world_scale
	_rng.seed = 20261110
	_reduced = bool(SaveGame.setting("reduced_effects"))
	_capacity = maxi(Params.particle_budget_3d, 1)
	_pos.resize(_capacity)
	_vel.resize(_capacity)
	_life.resize(_capacity)
	_span.resize(_capacity)
	_size.resize(_capacity)
	_spin.resize(_capacity)
	_gravity.resize(_capacity)
	_color.resize(_capacity)

	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_multimesh.use_colors = true
	_multimesh.mesh = ModelLibrary.shard()
	_multimesh.instance_count = _capacity
	_multimesh.visible_instance_count = 0
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var instance := MultiMeshInstance3D.new()
	instance.name = "Particles"
	instance.multimesh = _multimesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.custom_aabb = AABB(Vector3(-500.0, -50.0, -500.0), Vector3(1000.0, 100.0, 1000.0))
	add_child(instance)

	if game != null:
		var combat: CombatSystem = game.get("combat")
		if combat != null:
			combat.powerup_collected.connect(_on_powerup_collected)


func alive_count() -> int:
	return _alive


func capacity() -> int:
	return _capacity


## Quantidade de uma rajada: metade com "efeitos visuais reduzidos".
func burst_amount(base: int) -> int:
	return maxi(base / 2 if _reduced else base, 1)


## Solta count partículas em pos (mundo). speed = mínimo e máximo; spread_up = quanto da
## direção é para cima (0 = só para os lados no plano, 1 = bem para cima).
func emit(count: int, pos: Vector3, color: Color, speed: Vector2, size: float, seconds: float, spread_up: float, gravity: float, push := Vector3.ZERO) -> void:
	for i in count:
		var index: int
		if _alive < _capacity:
			index = _alive
			_alive += 1
		else:
			index = _cursor
			_cursor = (_cursor + 1) % _capacity
		var angle: float = _rng.randf() * TAU
		var up: float = _rng.randf() * spread_up
		var dir := Vector3(cos(angle) * (1.0 - up * 0.5), up, sin(angle) * (1.0 - up * 0.5))
		_pos[index] = pos
		_vel[index] = dir * _rng.randf_range(speed.x, speed.y) + push
		var life: float = seconds * _rng.randf_range(0.6, 1.0)
		_life[index] = life
		_span[index] = life
		_size[index] = size * _rng.randf_range(0.6, 1.3)
		_spin[index] = _rng.randf_range(-9.0, 9.0)
		_gravity[index] = gravity
		_color[index] = color


func _process(delta: float) -> void:
	if _game != null:
		_watch(_game.get("explosions"), true)
		var context: CombatContext = _game.get("context")
		if context != null:
			_watch(context.impacts, false)
		_emit_trail(delta)
	step(delta)


## Avança as partículas vivas e escreve as instâncias. delta é tempo de jogo (segue a câmera lenta).
func step(delta: float) -> void:
	var damping: float = maxf(1.0 - Params.particle_damping_3d * delta, 0.0)
	var i: int = 0
	while i < _alive:
		var life: float = _life[i] - delta
		if life <= 0.0:
			# Morreu: a última viva ocupa o lugar (e é processada nesta mesma volta)
			_alive -= 1
			if i < _alive:
				_pos[i] = _pos[_alive]
				_vel[i] = _vel[_alive]
				_life[i] = _life[_alive]
				_span[i] = _span[_alive]
				_size[i] = _size[_alive]
				_spin[i] = _spin[_alive]
				_gravity[i] = _gravity[_alive]
				_color[i] = _color[_alive]
			continue
		_life[i] = life
		var vel: Vector3 = _vel[i] * damping
		vel.y -= _gravity[i] * delta
		_vel[i] = vel
		var pos: Vector3 = _pos[i] + vel * delta
		_pos[i] = pos
		# Encolhe até sumir (sem transparência: mais barato e sem ordenação)
		var t: float = life / _span[i]
		var size: float = _size[i] * minf(t * 2.2, 1.0)
		_multimesh.set_instance_transform(i, Transform3D(Basis(Vector3.UP, _spin[i] * life).scaled(Vector3.ONE * size), pos))
		_multimesh.set_instance_color(i, _color[i])
		i += 1
	_cursor = mini(_cursor, maxi(_alive - 1, 0))
	_multimesh.visible_instance_count = _alive


## Dispara uma rajada para cada item do pool que acabou de ser ativado.
func _watch(pool: NodePool, explosion: bool) -> void:
	if pool == null:
		return
	for item in pool.get_children():
		if not (item is PoolItem):
			continue
		var age: float = -1.0
		if (item as PoolItem).visible:
			age = (item as Explosion).age() if explosion else (item as HitSpark).age()
		var before: float = _seen.get(item, -1.0)
		_seen[item] = age
		if age < 0.0 or (before >= 0.0 and age >= before):
			continue
		bursts += 1
		if explosion:
			var blast := item as Explosion
			var factor: float = clampf(blast.blast_radius() / Params.explosion_reference_radius, 0.5, 2.5)
			emit(burst_amount(Params.particle_explosion_amount_3d), _at(blast.position), blast.tint().lightened(0.3),
				Params.particle_explosion_speed_3d * factor, Params.particle_size_3d * (0.7 + 0.5 * factor),
				Params.particle_explosion_seconds_3d, 0.9, Params.particle_gravity_3d)
		else:
			var spark := item as HitSpark
			var scale: float = clampf(spark.spark_size(), 0.6, 2.0)
			emit(burst_amount(Params.particle_spark_amount_3d), _at(spark.position), spark.tint().lightened(0.5),
				Params.particle_spark_speed_3d * scale, Params.particle_size_3d * 0.55 * scale,
				Params.particle_spark_seconds_3d, 0.7, Params.particle_gravity_3d * 0.4)


func _at(pos: Vector2) -> Vector3:
	return _rig.to_world(pos, Params.bullet_height_3d * _scale)


func _on_powerup_collected(kind: PowerUp.Kind) -> void:
	var player: Player = _game.get("player")
	if player == null:
		return
	var color: Color = Params.powerup_color
	match kind:
		PowerUp.Kind.HEAL:
			color = Params.medkit_color
		PowerUp.Kind.COMPANION:
			color = Params.companion_powerup_color
		PowerUp.Kind.CHEST:
			color = Params.chest_color
	bursts += 1
	# Sobem em volta da nave (gravidade negativa)
	emit(burst_amount(Params.particle_pickup_amount_3d), _at(player.position), color.lightened(0.3),
		Vector2(1.5, 3.5), Params.particle_size_3d * 0.8, 0.5, 1.0, -1.5)


## Rastro: sai da traseira da nave (+Z) enquanto ela tem corpo, na cor do corpo.
func _emit_trail(delta: float) -> void:
	var player: Player = _game.get("player")
	if player == null or player.body == null or player.build_progress() < 1.0:
		_trail_debt = 0.0
		return
	_trail_debt += float(burst_amount(Params.particle_trail_amount_3d)) / maxf(Params.particle_trail_seconds_3d, 0.01) * delta
	var count: int = int(_trail_debt)
	if count <= 0:
		return
	_trail_debt -= count
	var pos: Vector3 = _rig.to_world(player.position + Vector2(0.0, Params.ship_size.y * 0.42), Params.ship_height_3d * 0.5 * _scale)
	emit(mini(count, 8), pos, player.body.color.lightened(0.45), Vector2(0.1, 0.5), Params.particle_size_3d * 0.75,
		Params.particle_trail_seconds_3d, 0.2, 0.0, Vector3(0.0, 0.0, Params.particle_trail_speed_3d))
