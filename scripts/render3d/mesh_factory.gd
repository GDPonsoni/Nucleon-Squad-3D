class_name MeshFactory
extends RefCounted
## Gera malhas low poly facetadas (uma normal por face) por código, com cache por forma.
## Convenção: o plano de jogo é XZ. Um ponto 2D (x, y) vira (x, altura, y): a frente da nave
## (y negativo no 2D) aponta para -Z. A cor do vértice guarda só o tom (claro/escuro); a cor
## de verdade vem do material (tint por instância).
## Não usa o gerador global de números aleatórios: a simulação não muda por causa do desenho.

## Monta uma malha juntando partes. Cada triângulo tem a própria normal (flat shading).
class Builder:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	## Quanto as próximas faces puxam para o branco (0 = cor da instância, 1 = branco).
	var whiten: float = 0.0
	## Cor de vértice branca pura (projéteis: a cor vem só da instância do MultiMesh).
	var plain: bool = false
	## UV das próximas faces quando a chamada não informa (projéteis: UV.x = brilho do topo).
	var default_uv := Vector2.ZERO

	## Triângulo com a normal apontando para o lado de `outward`.
	func tri(a: Vector3, b: Vector3, c: Vector3, outward: Vector3, shade: float = 1.0, uv: Vector2 = Vector2.INF) -> void:
		if uv == Vector2.INF:
			uv = default_uv
		var normal: Vector3 = (b - a).cross(c - a)
		if normal.length_squared() < 1e-12:
			return
		if normal.dot(outward) < 0.0:
			var swap: Vector3 = b
			b = c
			c = swap
			normal = -normal
		normal = normal.normalized()
		# r = tom da face, g = branco (lidos pelo shader das entidades)
		var color := Color.WHITE if plain else Color(shade, whiten, 0.0, 1.0)
		# (a, b, c) está anti-horário visto de fora; o Godot quer horário na face da frente
		for v: Vector3 in [a, c, b]:
			vertices.append(v)
			normals.append(normal)
			colors.append(color)
			uvs.append(uv)

	func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector3, shade: float = 1.0, uv: Vector2 = Vector2.INF) -> void:
		tri(a, b, c, outward, shade, uv)
		tri(a, c, d, outward, shade, uv)

	## Contorno 2D extrudado de y0 até y1, com o topo encolhido por top_scale em volta do
	## centro. Sem tampa de baixo (nunca aparece: a câmera olha de cima).
	func extrusion(points: PackedVector2Array, y0: float, y1: float, top_scale: float, side_shade: float, top_shade: float, center: Vector2 = Vector2.INF, cap: bool = true) -> void:
		var n: int = points.size()
		if n < 3:
			return
		if center == Vector2.INF:
			center = MeshFactory.centroid(points)
		var top := PackedVector2Array()
		for p in points:
			top.append(center + (p - center) * top_scale)
		for i in n:
			var j: int = (i + 1) % n
			var a := Vector3(points[i].x, y0, points[i].y)
			var b := Vector3(points[j].x, y0, points[j].y)
			var c := Vector3(top[j].x, y1, top[j].y)
			var d := Vector3(top[i].x, y1, top[i].y)
			var mid: Vector2 = (points[i] + points[j]) * 0.5 - center
			# Tom varia um pouco por face: reforça o facetado mesmo com pouca luz
			var shade: float = side_shade * (0.86 + 0.14 * (0.5 + 0.5 * sin(float(i) * 2.4)))
			quad(a, b, c, d, Vector3(mid.x, 0.35, mid.y), shade)
		if cap and top_scale > 0.001:
			var indices: PackedInt32Array = Geometry2D.triangulate_polygon(top)
			for k in range(0, indices.size(), 3):
				tri(Vector3(top[indices[k]].x, y1, top[indices[k]].y),
					Vector3(top[indices[k + 1]].x, y1, top[indices[k + 1]].y),
					Vector3(top[indices[k + 2]].x, y1, top[indices[k + 2]].y), Vector3.UP, top_shade)

	## Pirâmide: base no contorno (altura y0), ponta em apex.
	func cone(points: PackedVector2Array, y0: float, apex: Vector3, shade: float) -> void:
		var n: int = points.size()
		var center: Vector2 = MeshFactory.centroid(points)
		for i in n:
			var j: int = (i + 1) % n
			var mid: Vector2 = (points[i] + points[j]) * 0.5 - center
			var face_shade: float = shade * (0.8 + 0.2 * (0.5 + 0.5 * sin(float(i) * 1.9 + 0.7)))
			tri(Vector3(points[i].x, y0, points[i].y), Vector3(points[j].x, y0, points[j].y), apex,
				Vector3(mid.x, signf(apex.y - y0) * 0.5, mid.y), face_shade)

	## Anel plano (coroa) deitado no plano XZ, na altura y.
	func flat_ring(inner: float, outer: float, segments: int, y: float, shade: float, from: float = 0.0, to: float = TAU) -> void:
		for i in segments:
			var a0: float = lerpf(from, to, float(i) / segments)
			var a1: float = lerpf(from, to, float(i + 1) / segments)
			var d0 := Vector3(cos(a0), 0.0, sin(a0))
			var d1 := Vector3(cos(a1), 0.0, sin(a1))
			var up := Vector3(0.0, y, 0.0)
			quad(d0 * inner + up, d0 * outer + up, d1 * outer + up, d1 * inner + up, Vector3.UP, shade)

	## Caixa alinhada aos eixos (sem a face de baixo).
	func box(center: Vector3, size: Vector3, shade: float = 1.0) -> void:
		var h: Vector3 = size * 0.5
		var footprint := PackedVector2Array([
			Vector2(center.x - h.x, center.z - h.z), Vector2(center.x + h.x, center.z - h.z),
			Vector2(center.x + h.x, center.z + h.z), Vector2(center.x - h.x, center.z + h.z)])
		extrusion(footprint, center.y - h.y, center.y + h.y, 1.0, shade * 0.72, shade)

	## Malha transformada por xform e somada a este construtor (para compor modelos).
	func append_builder(other: Builder, xform: Transform3D, shade_scale: float = 1.0) -> void:
		for i in other.vertices.size():
			vertices.append(xform * other.vertices[i])
			normals.append((xform.basis * other.normals[i]).normalized())
			var c: Color = other.colors[i]
			colors.append(Color(c.r * shade_scale, c.g, c.b, 1.0))
			uvs.append(other.uvs[i])

	func triangle_count() -> int:
		return vertices.size() / 3

	func commit() -> ArrayMesh:
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		var mesh := ArrayMesh.new()
		if not vertices.is_empty():
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return mesh


static var _cache: Dictionary = {}


static func clear_cache() -> void:
	_cache.clear()


static func cache_size() -> int:
	return _cache.size()


## Devolve a malha guardada em key ou a constrói com build (() -> ArrayMesh).
static func cached(key: String, build: Callable) -> ArrayMesh:
	if _cache.has(key):
		return _cache[key]
	var mesh: ArrayMesh = build.call()
	_cache[key] = mesh
	return mesh


static func triangle_count(mesh: Mesh) -> int:
	var total: int = 0
	for s in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(s)
		total += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return total


static func centroid(points: PackedVector2Array) -> Vector2:
	var sum := Vector2.ZERO
	for p in points:
		sum += p
	return sum / maxf(points.size(), 1.0)


## Polígono regular de raio 1 com um vértice apontando para +Z (para o jogador), como no 2D.
static func regular_polygon(sides: int, radius: float = 1.0, turn: float = 0.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in sides:
		points.append(Vector2.from_angle(PI * 0.5 + turn + TAU * i / sides) * radius)
	return points


# --- Primitivas com cache ---

## Contorno extrudado com topo afunilado.
static func extrude_polygon(points: PackedVector2Array, height: float, top_scale: float = 0.7) -> ArrayMesh:
	var key: String = "extrude|%s|%.3f|%.3f" % [var_to_str(points), height, top_scale]
	return cached(key, func() -> ArrayMesh:
		var b := Builder.new()
		b.extrusion(points, 0.0, height, top_scale, 0.72, 1.0)
		return b.commit())


## Prisma regular de raio 1.
static func prism(sides: int, height: float, top_scale: float = 1.0) -> ArrayMesh:
	return cached("prism|%d|%.3f|%.3f" % [sides, height, top_scale], func() -> ArrayMesh:
		var b := Builder.new()
		b.extrusion(regular_polygon(sides), 0.0, height, top_scale, 0.72, 1.0)
		return b.commit())


## Pirâmide regular de raio 1 (3 lados = tetraedro deitado no chão).
static func pyramid(sides: int, height: float) -> ArrayMesh:
	return cached("pyramid|%d|%.3f" % [sides, height], func() -> ArrayMesh:
		var b := Builder.new()
		b.cone(regular_polygon(sides), 0.0, Vector3(0.0, height, 0.0), 1.0)
		return b.commit())


## Duas pirâmides coladas pela base (4 lados = octaedro), centrada na origem.
static func bipyramid(sides: int, height: float) -> ArrayMesh:
	return cached("bipyramid|%d|%.3f" % [sides, height], func() -> ArrayMesh:
		var b := Builder.new()
		var base: PackedVector2Array = regular_polygon(sides)
		b.cone(base, 0.0, Vector3(0.0, height, 0.0), 1.0)
		b.cone(base, 0.0, Vector3(0.0, -height, 0.0), 0.6)
		return b.commit())


## Anel plano de raio externo 1.
static func ring(inner: float, segments: int = 24) -> ArrayMesh:
	return cached("ring|%.3f|%d" % [inner, segments], func() -> ArrayMesh:
		var b := Builder.new()
		b.flat_ring(inner, 1.0, segments, 0.0, 1.0)
		return b.commit())


## Quadrado de lado 1 deitado no plano XZ, com UV de 0 a 1 (u = x, v = z).
static func quad() -> ArrayMesh:
	return cached("quad", func() -> ArrayMesh:
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		# Horário visto de cima (face da frente para +Y)
		arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([
			Vector3(-0.5, 0.0, -0.5), Vector3(0.5, 0.0, -0.5), Vector3(0.5, 0.0, 0.5),
			Vector3(-0.5, 0.0, -0.5), Vector3(0.5, 0.0, 0.5), Vector3(-0.5, 0.0, 0.5)])
		arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP])
		arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([
			Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 0), Vector2(1, 1), Vector2(0, 1)])
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return mesh)


## Icosaedro de raio 1 (20 faces). O UV.x guarda o quanto a face olha para cima (0..1):
## o material dos projéteis usa isso para clarear o topo (núcleo claro).
static func icosphere_low(plain: bool = false) -> ArrayMesh:
	return cached("icosphere|%s" % plain, func() -> ArrayMesh:
		var b := Builder.new()
		b.plain = plain
		var t: float = (1.0 + sqrt(5.0)) * 0.5
		var raw: Array[Vector3] = [
			Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
			Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
			Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]
		var faces: PackedInt32Array = [
			0, 11, 5, 0, 5, 1, 0, 1, 7, 0, 7, 10, 0, 10, 11, 1, 5, 9, 5, 11, 4, 11, 10, 2, 10, 7, 6, 7, 1, 8,
			3, 9, 4, 3, 4, 2, 3, 2, 6, 3, 6, 8, 3, 8, 9, 4, 9, 5, 2, 4, 11, 6, 2, 10, 8, 6, 7, 9, 8, 1]
		for k in range(0, faces.size(), 3):
			var a: Vector3 = raw[faces[k]].normalized()
			var c: Vector3 = raw[faces[k + 1]].normalized()
			var d: Vector3 = raw[faces[k + 2]].normalized()
			var mid: Vector3 = (a + c + d).normalized()
			b.tri(a, c, d, mid, 1.0, Vector2(clampf(mid.y * 0.5 + 0.5, 0.0, 1.0), 0.0))
		return b.commit())


## Esfera facetada de raio 1: icosaedro subdividido (0 = 20 faces, 1 = 80, 2 = 320).
static func icosphere(subdivisions: int) -> ArrayMesh:
	return cached("icosphere_sub|%d" % subdivisions, func() -> ArrayMesh:
		var source: PackedVector3Array = icosphere_low().surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var triangles: Array[PackedVector3Array] = []
		for k in range(0, source.size(), 3):
			triangles.append(PackedVector3Array([source[k], source[k + 1], source[k + 2]]))
		for step in subdivisions:
			var next: Array[PackedVector3Array] = []
			for t in triangles:
				var ab: Vector3 = ((t[0] + t[1]) * 0.5).normalized()
				var bc: Vector3 = ((t[1] + t[2]) * 0.5).normalized()
				var ca: Vector3 = ((t[2] + t[0]) * 0.5).normalized()
				next.append(PackedVector3Array([t[0], ab, ca]))
				next.append(PackedVector3Array([ab, t[1], bc]))
				next.append(PackedVector3Array([ca, bc, t[2]]))
				next.append(PackedVector3Array([ab, bc, ca]))
			triangles = next
		var b := Builder.new()
		var index: int = 0
		for t in triangles:
			# Tom varia por face (sem sorteio): reforça o facetado
			var shade: float = 0.78 + 0.22 * (0.5 + 0.5 * sin(float(index) * 12.9898))
			b.tri(t[0], t[1], t[2], (t[0] + t[1] + t[2]).normalized(), shade)
			index += 1
		return b.commit())
