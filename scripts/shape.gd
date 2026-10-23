class_name Shape
extends RefCounted
## Builds chunky low-poly meshes out of balls, tubes, boxes and rings, with the colour painted on the
## corners, the way the old console characters were put together. One finished Shape is one rigid piece.

const LOOK: Shader = preload("res://shaders/look.gdshader")
const FLAME: Shader = preload("res://shaders/flame.gdshader")

## Every solid material made, so the light can be changed on all of them at once
static var made: Array[ShaderMaterial] = []
static var _plain: ShaderMaterial

var v := PackedVector3Array()
var n := PackedVector3Array()
var c := PackedColorArray()


static func plain() -> ShaderMaterial:
	if _plain == null:
		_plain = mat()
	return _plain


static func mat(glow := 0.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = LOOK
	m.set_shader_parameter("glow", glow)
	made.append(m)
	return m


static func flame_mat(colour: Color, strength := 1.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = FLAME
	m.set_shader_parameter("colour", lin3(colour))
	m.set_shader_parameter("strength", strength)
	return m


static func set_all(setting: String, value: Variant) -> void:
	for m in made:
		m.set_shader_parameter(setting, value)


static func lin3(col: Color) -> Vector3:
	var l := col.srgb_to_linear()
	return Vector3(l.r, l.g, l.b)


func _add(p: Vector3, normal: Vector3, col: Color) -> void:
	v.append(p)
	n.append(normal)
	c.append(col)


func _quad(p: Array, q: Array, k: Array) -> void:
	for i: int in [0, 1, 2, 0, 2, 3]:
		_add(p[i], q[i], k[i])


## An egg round `at` with radii `r`: `top` colour on top fading to `bottom` underneath
## `cut` below 1 leaves the top open from that height (-1 to 1) up
func ball(at: Vector3, r: Vector3, top: Color, bottom: Variant = null, seg := 10, rings := 7, turn := Basis(), cut := 1.0) -> Shape:
	var t0 := acos(clampf(cut, -1.0, 1.0))
	var lo: Color = (top if bottom == null else bottom).srgb_to_linear()
	var hi := top.srgb_to_linear()
	for i in rings:
		for j in seg:
			var ps := []
			var ns := []
			var ks := []
			for corner: Vector2i in [Vector2i(i, j), Vector2i(i + 1, j), Vector2i(i + 1, j + 1), Vector2i(i, j + 1)]:
				var t := lerpf(t0, PI, float(corner.x) / rings)
				var a := TAU * corner.y / seg
				var d := Vector3(sin(t) * cos(a), cos(t), sin(t) * sin(a))
				ps.append(at + turn * (d * r))
				ns.append((turn * (d / r)).normalized())
				ks.append(lo.lerp(hi, (d.y + 1.0) * 0.5))
			_quad(ps, ns, ks)
	return self


## A tube or cone from `a` (radius ra) to `b` (radius rb), coloured from `ca` to `cb`.
## `squash` flattens it across one side (1 is round).
func tube(a: Vector3, b: Vector3, ra: float, rb: float, ca: Color, cb: Variant = null, seg := 8, caps := true, squash := 1.0) -> Shape:
	var k1 := ca.srgb_to_linear()
	var k2: Color = (ca if cb == null else cb).srgb_to_linear()
	var axis := (b - a)
	var length := axis.length()
	if length < 0.0001:
		return self
	axis /= length
	var u := axis.cross(Vector3.UP if absf(axis.y) < 0.95 else Vector3.RIGHT).normalized()
	var w := axis.cross(u).normalized()
	var slope := (ra - rb) / length
	for j in seg:
		var a0 := TAU * j / seg
		var a1 := TAU * (j + 1) / seg
		var d0 := u * cos(a0) * squash + w * sin(a0)
		var d1 := u * cos(a1) * squash + w * sin(a1)
		var n0 := (u * cos(a0) / squash + w * sin(a0)).normalized() + axis * slope
		var n1 := (u * cos(a1) / squash + w * sin(a1)).normalized() + axis * slope
		_quad([a + d0 * ra, b + d0 * rb, b + d1 * rb, a + d1 * ra], [n0.normalized(), n0.normalized(), n1.normalized(), n1.normalized()], [k1, k2, k2, k1])
		if caps:
			_add(a, -axis, k1)
			_add(a + d1 * ra, -axis, k1)
			_add(a + d0 * ra, -axis, k1)
			_add(b, axis, k2)
			_add(b + d0 * rb, axis, k2)
			_add(b + d1 * rb, axis, k2)
	return self


## A bendy horn or tail through `points`, thinning from `ra` to `rb`
func bend(points: Array, ra: float, rb: float, ca: Color, cb: Variant = null, seg := 6) -> Shape:
	var last: Color = ca if cb == null else cb
	for i in points.size() - 1:
		var t0 := float(i) / (points.size() - 1)
		var t1 := float(i + 1) / (points.size() - 1)
		tube(points[i], points[i + 1], lerpf(ra, rb, t0), lerpf(ra, rb, t1), ca.lerp(last, t0), ca.lerp(last, t1), seg, false)
		if i < points.size() - 2:
			var r := lerpf(ra, rb, t1)
			ball(points[i + 1], Vector3(r, r, r), ca.lerp(last, t1), null, seg, 4)
	var end := rb
	ball(points[-1], Vector3(end, end, end), last, null, seg, 4)
	return self


## A box round `at`, `top` colour on its top face and `side` on the rest
func box(at: Vector3, size: Vector3, top: Color, side: Variant = null, turn := Basis()) -> Shape:
	var kt := top.srgb_to_linear()
	var ks: Color = (top if side == null else side).srgb_to_linear()
	var h := size * 0.5
	for axis in 3:
		for sgn: float in [-1.0, 1.0]:
			var nrm := Vector3.ZERO
			nrm[axis] = sgn
			var e1 := Vector3.ZERO
			var e2 := Vector3.ZERO
			e1[(axis + 1) % 3] = 1.0
			e2[(axis + 2) % 3] = 1.0
			var centre := nrm * h
			var a1 := e1 * h
			var a2 := e2 * h
			var k := kt if (axis == 1 and sgn > 0) else ks
			if axis == 1 and sgn < 0:
				k = ks.darkened(0.25)
			var ps := [centre - a1 - a2, centre + a1 - a2, centre + a1 + a2, centre - a1 + a2]
			for i in 4:
				ps[i] = at + turn * ps[i]
			var tn := turn * nrm
			_quad(ps, [tn, tn, tn, tn], [k, k, k, k])
	return self


## A ring lying flat round `at` (round its own up), of radius `big`, as thick as `small`
func ring(at: Vector3, big: float, small: float, col: Color, seg := 16, sides := 6, turn := Basis(), inner: Variant = null) -> Shape:
	var k := col.srgb_to_linear()
	var ki: Color = (col if inner == null else inner).srgb_to_linear()
	for i in seg:
		for j in sides:
			var ps := []
			var ns := []
			var ks := []
			for corner: Vector2i in [Vector2i(i, j), Vector2i(i + 1, j), Vector2i(i + 1, j + 1), Vector2i(i, j + 1)]:
				var a := TAU * corner.x / seg
				var b := TAU * corner.y / sides
				var out := Vector3(cos(a), 0, sin(a))
				var d := out * cos(b) + Vector3.UP * sin(b)
				ps.append(at + turn * (out * big + d * small))
				ns.append(turn * d)
				ks.append(ki.lerp(k, clampf(cos(b) + 0.5, 0.0, 1.0)))
			_quad(ps, ns, ks)
	return self


## A flat disc facing up (or `down`), for the tops of things
func disc(at: Vector3, r: Vector2, col: Color, seg := 16, turn := Basis(), edge: Variant = null) -> Shape:
	var k := col.srgb_to_linear()
	var ke: Color = (col if edge == null else edge).srgb_to_linear()
	var up := turn * Vector3.UP
	for j in seg:
		var a0 := TAU * j / seg
		var a1 := TAU * (j + 1) / seg
		_add(at, up, k)
		_add(at + turn * Vector3(cos(a1) * r.x, 0, sin(a1) * r.y), up, ke)
		_add(at + turn * Vector3(cos(a0) * r.x, 0, sin(a0) * r.y), up, ke)
	return self


## A flat triangle (fins, ears, flame tongues), both sides
func tri(a: Vector3, b: Vector3, d: Vector3, col: Color, tip: Variant = null) -> Shape:
	var k := col.srgb_to_linear()
	var kt: Color = (col if tip == null else tip).srgb_to_linear()
	var nrm := (b - a).cross(d - a).normalized()
	_add(a, nrm, k)
	_add(b, nrm, k)
	_add(d, nrm, kt)
	return self


func is_empty() -> bool:
	return v.is_empty()


func mesh() -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = n
	arrays[Mesh.ARRAY_COLOR] = c
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


## The finished piece, wearing `material` (the shared solid look if none)
func piece(name := "piece", material: Material = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = mesh()
	mi.material_override = material if material != null else Shape.plain()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return mi


## A googly eye: a white egg with a black pupil that can look about and blink.
## The returned node is the eye; its child "pupil" moves, and scaling the eye on y blinks it.
static func eye(r: Vector3, white := Color("fffdf2"), pupil_size := 0.38, pupil_col := Color("140d12")) -> Node3D:
	var e := Node3D.new()
	e.name = "eye"
	e.add_child(Shape.new().ball(Vector3.ZERO, r, white, white.darkened(0.12), 12, 8).piece("white"))
	var p := Node3D.new()
	p.name = "pupil"
	var pr := minf(r.x, r.y) * pupil_size
	p.add_child(Shape.new().ball(Vector3.ZERO, Vector3(pr, pr * 1.15, pr * 0.5), pupil_col, null, 8, 6).piece("dot"))
	var shine := Shape.new().ball(Vector3(-pr * 0.35, pr * 0.4, pr * 0.42), Vector3(pr * 0.3, pr * 0.3, pr * 0.15), Color.WHITE, null, 6, 4)
	p.add_child(shine.piece("shine", Shape.mat(1.0)))
	p.position = Vector3(0, 0, r.z * 0.92)
	p.set_meta("reach", Vector2(r.x, r.y) * 0.45)
	p.set_meta("depth", r.z)
	e.add_child(p)
	return e


## Points an eye's pupil `dir` (x right, y up, each -1..1)
static func look(e: Node3D, dir: Vector2) -> void:
	var p: Node3D = e.get_node("pupil")
	var reach: Vector2 = p.get_meta("reach")
	var depth: float = p.get_meta("depth")
	var d := dir.limit_length(1.0)
	p.position = Vector3(d.x * reach.x, d.y * reach.y, depth * (0.92 - d.length_squared() * 0.12))
