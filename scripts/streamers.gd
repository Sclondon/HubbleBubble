class_name Streamers
extends MeshInstance3D
## Steam and smoke drawn the Wind Waker way, as Hemlock's Tower draws its wind (scripts/wind_gusts.gd
## there): each streamer is a head that flies up off the brew, swaying gently and now and then
## curling through a loop-de-loop, and leaves a trail of points behind it that fade out after a
## moment. The trail is drawn as a thin ribbon turned to the camera: pointed at the head, full through
## the body, thinning to nothing at the tail. When the head's time is up its tail drifts on and fades.
## Stands where the streamers start from (the middle of the brew's surface).

const MAX := 24
## Seconds a point of the trail lasts, and how far apart they're laid
const TAIL_LIFE := 0.9
const MIN_STEP := 0.025
const LOOP_TIME := 0.9
const LOOP_CHANCE := 0.45

## Drawn glowing, added over what's behind (shaders/streamer_glow.gdshader), for a potion's tendrils
var glowing := false

var _all: Array[Dictionary] = []
var _mesh := ImmediateMesh.new()
var _time := 0.0


func _ready() -> void:
	mesh = _mesh
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/streamer_glow.gdshader") if glowing else preload("res://shaders/streamer.gdshader")
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	custom_aabb = AABB(Vector3(-3, -1, -3), Vector3(6, 7, 6))
	# Drawn sharp over the N64 picture (Shop.SMOKE_LAYER)
	layers = 4


## One streamer from a point (local), in a colour; `lively` makes it quicker and curlier (a burst)
func add(at: Vector3, col: Color, lively := 0.0, width := 1.0) -> void:
	if _all.size() >= MAX:
		_all.remove_at(0)
	var side := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
	_all.append({"at": at, "col": col, "age": 0.0, "life": randf_range(1.1, 1.7) * (1.0 - lively * 0.3),
			"speed": randf_range(0.5, 0.75) * (1.0 + lively * 0.8), "a": 0.0, "side": side,
			"loop_at": randf_range(0.25, 0.9) if randf() < LOOP_CHANCE + lively * 0.3 else INF, "loop_a": -1.0,
			"phase": randf() * TAU, "sway": randf_range(0.25, 0.45) * (1.0 + lively * 0.5),
			"width": randf_range(0.016, 0.024) * width, "pts": []})


## A big slow tendril curling up high (a potion's glow rising off it)
func add_tendril(at: Vector3, col: Color) -> void:
	add(at, col, 0.0, 2.2)
	var s: Dictionary = _all[-1]
	s.life = randf_range(2.0, 2.8)
	s.speed = randf_range(0.4, 0.55)
	s.sway = randf_range(0.5, 0.7)


func count() -> int:
	return _all.size()


func _process(dt: float) -> void:
	_time += dt
	for s in _all:
		s.age += dt
		if s.age < s.life:
			_steer(s, dt)
			var pts: Array = s.pts
			if pts.is_empty() or (pts[-1].pos as Vector3).distance_to(s.at) > MIN_STEP:
				pts.append({"pos": s.at, "t": _time})
		while not s.pts.is_empty() and _time - float(s.pts[0].t) > TAIL_LIFE:
			s.pts.pop_front()
	_all = _all.filter(func(s: Dictionary) -> bool: return s.age < s.life or not s.pts.is_empty())
	_rebuild()


## The head flies up, its heading `a` (in the up / sideways plane) swaying, or spinning through a
## whole turn while it loops
func _steer(s: Dictionary, dt: float) -> void:
	if s.loop_a < 0.0 and s.age >= s.loop_at:
		s.loop_a = 0.0
	if s.loop_a >= 0.0 and s.loop_a < TAU:
		s.loop_a = minf(s.loop_a + TAU * dt / LOOP_TIME, TAU)
		s.a = s.loop_a
	else:
		s.a = s.sway * sin(s.age * 3.0 + s.phase)
	var side: Vector3 = s.side
	s.at += (Vector3.UP * cos(s.a) + side * sin(s.a)) * s.speed * dt
	# and the sideways drifts round slowly
	s.side = side.rotated(Vector3.UP, dt * 0.8 * sin(s.phase))


func _rebuild() -> void:
	_mesh.clear_surfaces()
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var eye := to_local(cam.global_position)
	for s in _all:
		var pts: Array = s.pts
		var n := pts.size()
		if n < 3:
			continue
		_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		var last := Vector3.ZERO
		for i in n:
			var p: Vector3 = pts[i].pos
			var along: Vector3 = ((pts[mini(i + 1, n - 1)].pos as Vector3) - (pts[maxi(i - 1, 0)].pos as Vector3)).normalized()
			var side := along.cross(eye - p).normalized()
			if i > 0 and side.dot(last) < 0.0:
				side = -side
			last = side
			# Thin at the tail, full through the body, pointed at the head
			var life := 1.0 - (_time - float(pts[i].t)) / TAIL_LIFE
			var head := clampf(float(n - 1 - i) / 3.0, 0.0, 1.0) if s.age < s.life else 1.0
			var w: float = s.width * sqrt(maxf(life, 0.0)) * (0.25 + 0.75 * head)
			var col: Color = s.col
			var c := Color(col, col.a * clampf(life * 1.3, 0.0, 1.0))
			_vert(p + side * w, Vector2(0, float(i) / (n - 1)), c)
			_vert(p - side * w, Vector2(1, float(i) / (n - 1)), c)
		_mesh.surface_end()


func _vert(p: Vector3, uv: Vector2, c: Color) -> void:
	_mesh.surface_set_color(c)
	_mesh.surface_set_uv(uv)
	_mesh.surface_add_vertex(p)
