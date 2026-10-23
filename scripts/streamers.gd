class_name Streamers
extends MeshInstance3D
## Steam and smoke as The Wind Waker drew it: thin ribbons that wind up off the brew, wavering in a
## loose helix that widens as it rises, curling over at the head, and then letting go of the surface
## and drifting up as a loose curl before they fade. Built afresh each frame as one mesh (a ribbon is
## a strip turned to face the camera), drawn with shaders/streamer.gdshader. Stands where the
## streamers start from (the middle of the brew's surface).

const MAX := 30
const SEGMENTS := 28

## Drawn glowing, added over what's behind (shaders/streamer_glow.gdshader), for a potion's tendrils
var glowing := false

var _all: Array[Dictionary] = []
var _mesh := ImmediateMesh.new()


func _ready() -> void:
	mesh = _mesh
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/streamer_glow.gdshader") if glowing else preload("res://shaders/streamer.gdshader")
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	custom_aabb = AABB(Vector3(-3, -1, -3), Vector3(6, 7, 6))
	# Drawn sharp over the N64 picture (Shop.SMOKE_LAYER)
	layers = 4


## A big slow tendril curling up high in S-bends (a potion's glow rising off it)
func add_tendril(at: Vector3, col: Color) -> void:
	add(at, col, 0.0, 3.2)
	var s: Dictionary = _all[-1]
	s.life = randf_range(4.0, 5.5)
	s.rise = randf_range(0.45, 0.6)
	s.turns = randf_range(0.3, 0.5)
	s.wide = randf_range(0.18, 0.28)


## One streamer from a point (local), in a colour; `lively` makes it quicker and curlier (a burst)
func add(at: Vector3, col: Color, lively := 0.0, width := 1.0) -> void:
	if _all.size() >= MAX:
		_all.remove_at(0)
	_all.append({"at": at, "col": col, "t": 0.0, "life": randf_range(2.6, 3.6) * (1.0 - lively * 0.35),
			"rise": randf_range(0.6, 0.8) * (1.0 + lively * 0.8), "turns": randf_range(1.2, 2.0) * (1.0 + lively * 0.5),
			"phase": randf() * TAU, "wide": randf_range(0.06, 0.1) * (1.0 + lively * 0.6), "curl": randf_range(0.8, 1.4) * (1.0 if randf() < 0.5 else -1.0),
			"width": randf_range(0.04, 0.058) * width, "drift": Vector3(randf_range(-0.08, 0.08), 0, randf_range(-0.08, 0.08))})


func count() -> int:
	return _all.size()


func _process(dt: float) -> void:
	for i in range(_all.size() - 1, -1, -1):
		_all[i].t += dt
		if _all[i].t >= _all[i].life:
			_all.remove_at(i)
	_mesh.clear_surfaces()
	if _all.is_empty():
		return
	var cam := get_viewport().get_camera_3d()
	var eye := to_local(cam.global_position) if cam != null else Vector3(0, 3, 3)
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for s in _all:
		_ribbon(s, eye)
	_mesh.surface_end()


func _ribbon(s: Dictionary, eye: Vector3) -> void:
	var t: float = s.t
	var k: float = t / s.life
	var rise: float = s.rise
	# The head climbs, slowing; after a while the tail lets go of the surface and follows it up
	var head: float = rise * (t - 0.12 * t * t / s.life)
	var tail := maxf(0.0, (t - s.life * 0.3) * rise * 0.95)
	var fade := smoothstep(0.0, 0.12, k) * (1.0 - smoothstep(0.6, 1.0, k))
	var col: Color = s.col
	var pts: Array[Vector3] = []
	for j in SEGMENTS + 1:
		var u := float(j) / SEGMENTS
		var y := lerpf(tail, head, u)
		# A loose helix that widens as it goes up, and curls over at the head
		var a: float = s.phase + y * s.turns * TAU - t * 1.3
		var r: float = s.wide * (0.3 + y * 1.2)
		var curl: float = smoothstep(0.7, 1.0, u) * s.curl
		a += curl * PI * 1.4
		r *= 1.0 - 0.45 * smoothstep(0.75, 1.0, u)
		pts.append(s.at + s.drift * y + Vector3(cos(a) * r, y, sin(a) * r))
	# One side for each point (across the line, square to the eye), kept pointing the same way as the
	# last so the ribbon never twists into pieces as the helix turns
	var sides: Array[Vector3] = []
	var last := Vector3.ZERO
	for j in pts.size():
		var along: Vector3 = (pts[mini(j + 1, pts.size() - 1)] - pts[maxi(j - 1, 0)]).normalized()
		var side: Vector3 = along.cross(eye - pts[j])
		if side.length() < 0.0001:
			side = last
		side = side.normalized()
		if j > 0 and side.dot(last) < 0.0:
			side = -side
		last = side
		sides.append(side * s.width)
	var c := Color(col, col.a * fade)
	for j in SEGMENTS:
		var a: Vector3 = pts[j]
		var b: Vector3 = pts[j + 1]
		var u0 := float(j) / SEGMENTS
		var u1 := float(j + 1) / SEGMENTS
		_vert(a - sides[j], Vector2(0, u0), c)
		_vert(a + sides[j], Vector2(1, u0), c)
		_vert(b + sides[j + 1], Vector2(1, u1), c)
		_vert(a - sides[j], Vector2(0, u0), c)
		_vert(b + sides[j + 1], Vector2(1, u1), c)
		_vert(b - sides[j + 1], Vector2(0, u1), c)


func _vert(p: Vector3, uv: Vector2, c: Color) -> void:
	_mesh.surface_set_color(c)
	_mesh.surface_set_uv(uv)
	_mesh.surface_add_vertex(p)
