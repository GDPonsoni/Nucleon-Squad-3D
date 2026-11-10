class_name Scenery3D
extends Node3D
## Cenário de fundo: rochas e planetoides low poly passando abaixo do plano de jogo, entre ele
## e o chão. Só enfeite: sem colisão, sem ligação com a simulação e com sorteio próprio
## (semente fixa pela fase), então não muda nada no jogo. Cores escuras, puxadas do planeta,
## para não disputar a leitura com os tiros.
## Tudo anda na velocidade do chão; a perspectiva faz o que está mais alto passar mais rápido.

var _items: Array[MeshInstance3D] = []
var _spins: Array[Vector3] = []
var _rng := RandomNumberGenerator.new()
var _material: ShaderMaterial
var _center := Vector3.ZERO
var _rock_tint: Color
var _planet_tint: Color
var _planets: int = 0


## center = centro da arena no mundo; stage_id decide a semente (cada fase tem o seu cenário).
func setup(planet: PlanetData, stage_id: String, center: Vector3) -> void:
	_center = center
	_rng.seed = hash("scenery|" + stage_id)
	_material = ShaderMaterial.new()
	_material.shader = load("res://scripts/render3d/shaders/entity.gdshader") as Shader
	_rock_tint = planet.background_color.lerp(planet.star_color, Params.scenery_rock_tint_3d)
	_planet_tint = planet.background_color.lerp(planet.star_color, Params.scenery_planet_tint_3d)
	var reduced: bool = bool(SaveGame.setting("reduced_effects"))
	_planets = Params.scenery_planet_count_3d
	var rocks: int = Params.scenery_rock_count_3d / 2 if reduced else Params.scenery_rock_count_3d
	for i in _planets + rocks:
		var item := MeshInstance3D.new()
		item.material_override = _material
		item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(item)
		_items.append(item)
		_spins.append(Vector3.ZERO)
		# Na primeira vez, espalhados por todo o percurso (não nascem todos no fundo)
		_place(i, _rng.randf_range(Params.scenery_far_z_3d, Params.scenery_near_z_3d))


func item_count() -> int:
	return _items.size()


func _process(delta: float) -> void:
	var step: float = Params.ground_scroll_speed_3d * Params.world_scale_3d * delta
	for i in _items.size():
		var item: MeshInstance3D = _items[i]
		item.position.z += step
		item.rotation += _spins[i] * delta
		# Passou da câmera: volta lá no fundo, em outro lugar e com outro formato
		if item.position.z - _center.z > Params.scenery_near_z_3d:
			_place(i, Params.scenery_far_z_3d)


## Sorteia formato, tamanho, profundidade e posição lateral do item i, na distância z (relativa ao centro).
func _place(index: int, z: float) -> void:
	var item: MeshInstance3D = _items[index]
	var planet: bool = index < _planets
	var size: float
	var tint: Color
	if planet:
		item.mesh = MeshFactory.icosphere(1)
		size = _rng.randf_range(Params.scenery_planet_size_3d.x, Params.scenery_planet_size_3d.y)
		tint = _planet_tint.lerp(_rock_tint, _rng.randf())
		_spins[index] = Vector3(0.0, _rng.randf_range(-0.08, 0.08), 0.0)
		# Planetoides passam pelos lados, longe do centro da arena
		var side: float = -1.0 if _rng.randf() < 0.5 else 1.0
		item.position.x = _center.x + side * _rng.randf_range(Params.scenery_spread_x_3d * 0.35, Params.scenery_spread_x_3d)
	else:
		item.mesh = ModelLibrary.rock(_rng.randi_range(0, maxi(Params.rock_variants_3d - 1, 0)))
		size = _rng.randf_range(Params.scenery_rock_size_3d.x, Params.scenery_rock_size_3d.y)
		tint = _rock_tint.darkened(_rng.randf_range(0.0, 0.35))
		_spins[index] = Vector3(_rng.randf_range(-0.25, 0.25), _rng.randf_range(-0.4, 0.4), 0.0)
		item.position.x = _center.x + _rng.randf_range(-Params.scenery_spread_x_3d, Params.scenery_spread_x_3d)
	# Sempre abaixo do plano de jogo e acima do chão, com folga do tamanho do item
	var top: float = -Params.scenery_min_depth_3d - size
	var bottom: float = -Params.ground_depth_3d + size * 0.6
	item.position.y = _center.y + (_rng.randf_range(bottom, top) if bottom < top else top)
	item.position.z = _center.z + z
	item.rotation = Vector3(_rng.randf_range(0.0, TAU), _rng.randf_range(0.0, TAU), 0.0) if not planet else Vector3.ZERO
	# Rochas são achatadas de fábrica (modelo de jogo): aqui ganham corpo
	item.scale = Vector3(size, size * (1.0 if planet else _rng.randf_range(1.6, 2.4)), size)
	item.set_instance_shader_parameter(&"tint", tint)
