class_name ModelLibrary
extends RefCounted
## Modelos low poly do jogo, montados com o MeshFactory a partir dos dados que já existem
## (BodyData.shape, EnemyData.sides, BossData.plates/spikes/turrets...). Tudo com cache.
## Unidades: naves em px do jogo; inimigos, chefes e itens com raio 1 (a vista escala pelo
## raio de colisão). A frente (para onde a nave anda) é -Z; inimigos apontam um vértice para +Z.
## Sorteios usam gerador próprio com semente fixa: nada aqui mexe no sorteio global do jogo.

const BODY_SHADE: float = 0.72
const DARK_SHADE: float = 0.5


## Nave: contorno do corpo extrudado em dois degraus, com o topo afunilado e mais claro.
## O "cockpit" é o núcleo (ModelLibrary.nucleus), que fica no centro e é a hitbox.
static func ship(body: BodyData) -> ArrayMesh:
	return MeshFactory.cached("ship|%s" % body.id, func() -> ArrayMesh:
		return _ship_builder(body.shape).commit())


static func _ship_builder(shape: PackedVector2Array) -> MeshFactory.Builder:
	var b := MeshFactory.Builder.new()
	var points := PackedVector2Array()
	for p in shape:
		points.append(p * Params.ship_size)
	var center: Vector2 = MeshFactory.centroid(points)
	var height: float = Params.ship_height_3d
	var waist := PackedVector2Array()
	for p in points:
		waist.append(center + (p - center) * 0.84)
	b.extrusion(points, 0.0, height * 0.5, 0.84, 0.6, 1.0, center, false)
	b.whiten = 0.18
	b.extrusion(waist, height * 0.5, height, 0.55, 0.82, 1.0, center)
	b.whiten = 0.0
	return b


## Núcleo (hitbox da nave), raio 1: colar escuro que o separa do casco e domo claro facetado.
static func nucleus() -> ArrayMesh:
	return MeshFactory.cached("nucleus", func() -> ArrayMesh:
		var b := MeshFactory.Builder.new()
		var outline: float = 1.0 + Params.nucleus_outline_width / maxf(Params.nucleus_radius, 1.0)
		b.extrusion(MeshFactory.regular_polygon(10, outline), 0.0, 0.2, 1.0, 0.05, 0.05)
		var ring: PackedVector2Array = MeshFactory.regular_polygon(8)
		b.extrusion(ring, 0.2, 0.62, 0.72, 0.82, 1.0, Vector2.ZERO, false)
		b.cone(MeshFactory.regular_polygon(8, 0.72), 0.62, Vector3(0.0, 0.9, 0.0), 1.0)
		return b.commit())


## Pedaço i da nave quebrada (BodyFx): fatia do contorno, do centro até a aresta i, em volta
## do próprio centroide (mesma divisão do efeito 2D).
static func ship_piece(body: BodyData, index: int) -> ArrayMesh:
	return MeshFactory.cached("ship_piece|%s|%d" % [body.id, index], func() -> ArrayMesh:
		var b := MeshFactory.Builder.new()
		var n: int = body.shape.size()
		var a: Vector2 = body.shape[index % n] * Params.ship_size
		var c: Vector2 = body.shape[(index + 1) % n] * Params.ship_size
		var center: Vector2 = (a + c) / 3.0
		b.extrusion(PackedVector2Array([-center, a - center, c - center]), 0.0, Params.ship_height_3d * 0.6, 0.8, 0.7, 1.0)
		return b.commit())


## Inimigo comum: prisma de N lados, topo um pouco menor e cristal escuro no meio.
static func enemy(sides: int) -> ArrayMesh:
	return MeshFactory.cached("enemy|%d" % sides, func() -> ArrayMesh:
		var b := MeshFactory.Builder.new()
		var h: float = Params.model_height_ratio_3d
		var outline: PackedVector2Array = MeshFactory.regular_polygon(sides)
		b.extrusion(outline, 0.0, h * 0.55, 0.82, BODY_SHADE, 1.0)
		b.cone(MeshFactory.regular_polygon(sides, 0.45), h * 0.55, Vector3(0.0, h, 0.0), DARK_SHADE)
		return b.commit())


## Rocha: contorno irregular (mesma regra do 2D: raio entre rock_roughness e 1,08) com altura
## variando por vértice. variant escolhe um dos formatos pré-gerados.
static func rock(variant: int) -> ArrayMesh:
	var count: int = maxi(Params.rock_variants_3d, 1)
	variant = posmod(variant, count)
	return MeshFactory.cached("rock|%d" % variant, func() -> ArrayMesh:
		var rng := RandomNumberGenerator.new()
		rng.seed = 7919 + variant * 104729
		var b := MeshFactory.Builder.new()
		var n: int = Params.rock_points
		var base: Array[Vector3] = []
		var top: Array[Vector3] = []
		var h: float = Params.model_height_ratio_3d
		for i in n:
			var r: float = rng.randf_range(Params.rock_roughness, 1.08)
			var dir := Vector2.from_angle(TAU * i / n + rng.randf_range(-0.2, 0.2))
			base.append(Vector3(dir.x * r, 0.0, dir.y * r))
			var inner: float = r * rng.randf_range(0.5, 0.7)
			top.append(Vector3(dir.x * inner, h * rng.randf_range(0.45, 0.9), dir.y * inner))
		var peak := Vector3(rng.randf_range(-0.12, 0.12), h * 1.05, rng.randf_range(-0.12, 0.12))
		for i in n:
			var j: int = (i + 1) % n
			var out: Vector3 = (base[i] + base[j]) * 0.5 + Vector3(0.0, 0.3, 0.0)
			var shade: float = rng.randf_range(0.55, 0.8)
			b.tri(base[i], base[j], top[j], out, shade)
			b.tri(base[i], top[j], top[i], out, shade * 0.92)
			b.tri(top[i], top[j], peak, Vector3.UP, rng.randf_range(0.8, 1.0))
		return b.commit())


# --- Chefe (peças separadas: cada uma tem a própria cor e gira no seu ritmo) ---

static func boss_hull(sides: int) -> ArrayMesh:
	return MeshFactory.cached("boss_hull|%d" % sides, func() -> ArrayMesh:
		var b := MeshFactory.Builder.new()
		b.extrusion(MeshFactory.regular_polygon(sides), 0.0, Params.model_height_ratio_3d * 0.4, 0.9, BODY_SHADE, 1.0)
		return b.commit())


## Miolo que gira em cima do casco (no 2D: polígono interno de raio 0,6).
static func boss_core(sides: int) -> ArrayMesh:
	sides = mini(sides, 8)
	return MeshFactory.cached("boss_core|%d" % sides, func() -> ArrayMesh:
		var b := MeshFactory.Builder.new()
		var h: float = Params.model_height_ratio_3d
		b.extrusion(MeshFactory.regular_polygon(sides, 0.6), h * 0.4, h * 0.7, 0.8, BODY_SHADE, 1.0)
		return b.commit())


## Espinho apontando para +X, da borda do casco (0,8) até 1,38 do raio.
static func boss_spike() -> ArrayMesh:
	return MeshFactory.cached("boss_spike", func() -> ArrayMesh:
		var b := MeshFactory.Builder.new()
		var h: float = Params.model_height_ratio_3d
		var left := Vector3(0.8, 0.0, -0.16)
		var right := Vector3(0.8, 0.0, 0.16)
		var ridge := Vector3(0.8, h * 0.6, 0.0)
		var tip := Vector3(1.38, h * 0.1, 0.0)
		b.tri(left, ridge, tip, Vector3(0.0, 1.0, -1.0), 0.9)
		b.tri(right, ridge, tip, Vector3(0.0, 1.0, 1.0), 0.65)
		b.tri(left, right, ridge, Vector3(-1.0, 0.2, 0.0), 0.5)
		return b.commit())


## Placa de blindagem: arco de 62% de 1/count de volta, entre 0,92 e 1,18 do raio, começando em +X.
static func boss_plate(count: int) -> ArrayMesh:
	return MeshFactory.cached("boss_plate|%d" % count, func() -> ArrayMesh:
		var b := MeshFactory.Builder.new()
		var span: float = TAU / maxi(count, 1) * 0.62
		var segments: int = 1 if count >= 6 else 2
		var outline := PackedVector2Array()
		for i in segments + 1:
			outline.append(Vector2.from_angle(span * i / segments) * 1.18)
		for i in range(segments, -1, -1):
			outline.append(Vector2.from_angle(span * i / segments) * 0.92)
		b.extrusion(outline, 0.0, Params.model_height_ratio_3d * 0.62, 1.0, 0.6, 1.0)
		return b.commit())


## Torreta: base baixa (raio 0,12) e cano apontando para +Z (a vista gira para a nave).
static func boss_turret() -> ArrayMesh:
	return MeshFactory.cached("boss_turret", func() -> ArrayMesh:
		var b := MeshFactory.Builder.new()
		var h: float = Params.model_height_ratio_3d
		b.extrusion(MeshFactory.regular_polygon(4, 0.14, PI * 0.25), h * 0.4, h * 0.75, 0.75, BODY_SHADE, 1.0)
		var barrel := PackedVector2Array([Vector2(-0.045, 0.05), Vector2(0.045, 0.05), Vector2(0.0, 0.34)])
		b.extrusion(barrel, h * 0.5, h * 0.72, 0.9, 0.55, 0.85)
		return b.commit())


## Rachadura i (0..5) em cima do casco: lasca fina que acende conforme a vida cai.
static func boss_crack(index: int) -> ArrayMesh:
	return MeshFactory.cached("boss_crack|%d" % index, func() -> ArrayMesh:
		var b := MeshFactory.Builder.new()
		var y: float = Params.model_height_ratio_3d * 0.4 + 0.012
		var a: float = TAU * index / 6.0 + 0.4
		var p0: Vector2 = Vector2.from_angle(a) * 0.62
		var p1: Vector2 = Vector2.from_angle(a + 0.25) * 0.76
		var p2: Vector2 = Vector2.from_angle(a - 0.1) * 0.9
		var w: Vector2 = (p1 - p0).orthogonal().normalized() * 0.035
		b.tri(Vector3(p0.x, y, p0.y), Vector3(p1.x - w.x, y, p1.y - w.y), Vector3(p1.x + w.x, y, p1.y + w.y), Vector3.UP)
		b.tri(Vector3(p1.x - w.x, y, p1.y - w.y), Vector3(p1.x + w.x, y, p1.y + w.y), Vector3(p2.x, y, p2.y), Vector3.UP)
		return b.commit())


## Pupila do olho: disco baixo de 6 lados.
static func boss_pupil() -> ArrayMesh:
	return MeshFactory.cached("boss_pupil", func() -> ArrayMesh:
		var b := MeshFactory.Builder.new()
		b.cone(MeshFactory.regular_polygon(6), 0.0, Vector3(0.0, 0.35, 0.0), 1.0)
		return b.commit())


## Triângulos do modelo completo de um chefe (para o orçamento).
static func boss_triangles(data: BossData) -> int:
	var total: int = MeshFactory.triangle_count(boss_hull(data.sides)) + MeshFactory.triangle_count(boss_core(data.sides))
	total += data.spikes * MeshFactory.triangle_count(boss_spike())
	total += data.plates * MeshFactory.triangle_count(boss_plate(data.plates))
	total += data.turrets * MeshFactory.triangle_count(boss_turret())
	total += MeshFactory.triangle_count(MeshFactory.icosphere_low()) + MeshFactory.triangle_count(boss_pupil())
	for i in 6:
		total += MeshFactory.triangle_count(boss_crack(i))
	return total


# --- Itens ---

## Power-up e orbe de XP: octaedro (stretch < 1 = mais estreito, como o losango do orbe).
static func gem(stretch: float = 1.0) -> ArrayMesh:
	return MeshFactory.cached("gem|%.2f" % stretch, func() -> ArrayMesh:
		var b := MeshFactory.Builder.new()
		var base := PackedVector2Array([Vector2(0, -1), Vector2(stretch, 0), Vector2(0, 1), Vector2(-stretch, 0)])
		b.cone(base, 0.0, Vector3(0.0, 0.7, 0.0), 1.0)
		b.cone(base, 0.0, Vector3(0.0, -0.7, 0.0), 0.6)
		# Miolo claro por cima
		b.whiten = 0.85
		var core := PackedVector2Array([Vector2(0, -0.4), Vector2(stretch * 0.4, 0), Vector2(0, 0.4), Vector2(-stretch * 0.4, 0)])
		b.cone(core, 0.42, Vector3(0.0, 0.78, 0.0), 1.0)
		b.whiten = 0.0
		return b.commit())


## Kit médico: caixa branca com a cruz na cor da instância.
static func medkit() -> ArrayMesh:
	return MeshFactory.cached("medkit", func() -> ArrayMesh:
		var b := MeshFactory.Builder.new()
		b.whiten = 1.0
		b.box(Vector3(0.0, 0.25, 0.0), Vector3(1.44, 0.5, 1.44), 0.92)
		b.whiten = 0.0
		b.box(Vector3(0.0, 0.56, 0.0), Vector3(0.96, 0.12, 0.3))
		b.box(Vector3(0.0, 0.56, 0.0), Vector3(0.3, 0.12, 0.96))
		return b.commit())


## Baú: caixa, tampa mais clara e fecho branco.
static func chest() -> ArrayMesh:
	return MeshFactory.cached("chest", func() -> ArrayMesh:
		var b := MeshFactory.Builder.new()
		b.box(Vector3(0.0, 0.25, 0.1), Vector3(1.3, 0.5, 0.75), 0.75)
		b.box(Vector3(0.0, 0.6, 0.1), Vector3(1.42, 0.22, 0.86), 1.0)
		b.whiten = 1.0
		b.box(Vector3(0.0, 0.5, 0.56), Vector3(0.22, 0.34, 0.08), 1.0)
		b.whiten = 0.0
		return b.commit())


# --- Projéteis (cor só da instância; UV.x = quanto a face clareia) ---

static func bullet_orb() -> ArrayMesh:
	return MeshFactory.icosphere_low(true)


## Tiro retangular: caixa de 1×1 de base (a vista escala pelo tamanho do tiro).
static func bullet_box() -> ArrayMesh:
	return MeshFactory.cached("bullet_box", func() -> ArrayMesh:
		var b := MeshFactory.Builder.new()
		b.plain = true
		b.default_uv = Vector2(0.55, 0.0)
		b.extrusion(PackedVector2Array([Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5)]), -0.5, 0.5, 0.6, 1.0, 1.0)
		return b.commit())


## Tiro triangular (mísseis): tetraedro apontando para -Z (a frente).
static func bullet_dart() -> ArrayMesh:
	return MeshFactory.cached("bullet_dart", func() -> ArrayMesh:
		var b := MeshFactory.Builder.new()
		b.plain = true
		b.default_uv = Vector2(0.45, 0.0)
		b.cone(PackedVector2Array([Vector2(0.0, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5)]), -0.3, Vector3(0.0, 0.5, 0.25), 1.0)
		return b.commit())


## Estilhaço das partículas: dois tetraedros colados, raio 1, cor só da partícula.
static func shard() -> ArrayMesh:
	return MeshFactory.cached("shard", func() -> ArrayMesh:
		var b := MeshFactory.Builder.new()
		b.plain = true
		var base: PackedVector2Array = MeshFactory.regular_polygon(3)
		b.cone(base, 0.0, Vector3(0.0, 0.9, 0.0), 1.0)
		b.cone(base, 0.0, Vector3(0.0, -0.9, 0.0), 1.0)
		return b.commit())
