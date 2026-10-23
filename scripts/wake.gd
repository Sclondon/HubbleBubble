class_name Wake
extends MeshInstance3D
## The stick's wake, the way The Wind Waker drew a boat's: two white lines trailing back from where
## the stick cuts the brew, spreading apart into a V as they go and thinning away. It remembers where
## the stick has been for a moment, and builds the two lines from that each frame, riding the waves.
## Stands at the middle of the brew's surface.

const KEEP := 0.75
const WIDTH := 0.022

var _trail: Array[Dictionary] = []
var _mesh := ImmediateMesh.new()
var _waves: Waves


func _init(waves: Waves) -> void:
	_waves = waves


func _ready() -> void:
	mesh = _mesh
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	material_override = m
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	custom_aabb = AABB(Vector3(-1, -0.5, -1), Vector3(2, 1, 2))


## The stick is at this point on the brew (local x, z) now
func stick_at(p: Vector2) -> void:
	if not _trail.is_empty() and _trail[-1].p.distance_to(p) < 0.012:
		return
	_trail.append({"p": p, "t": 0.0})


func _process(dt: float) -> void:
	for d in _trail:
		d.t += dt
	while not _trail.is_empty() and _trail[0].t > KEEP:
		_trail.pop_front()
	_mesh.clear_surfaces()
	if _trail.size() < 3:
		return
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for side: float in [-1.0, 1.0]:
		var last_a := Vector3.ZERO
		var last_b := Vector3.ZERO
		var last_c := Color.WHITE
		for i in range(_trail.size() - 1, 0, -1):
			var d: Dictionary = _trail[i]
			var go: Vector2 = (_trail[i].p - _trail[i - 1].p)
			if go.length() < 0.0001:
				continue
			go = go.normalized()
			var across := Vector2(-go.y, go.x) * side
			var k: float = d.t / KEEP
			# Spreading out behind the stick, the lines thinning and fading
			var spread := 0.02 + k * 0.16
			var c: Vector2 = d.p + across * spread
			var w := WIDTH * (1.0 - k * 0.6)
			var y := _waves.height_at(c) + 0.012
			var a := Vector3(c.x - across.x * w, y, c.y - across.y * w)
			var b := Vector3(c.x + across.x * w, y, c.y + across.y * w)
			var col := Color(1, 1, 1, 0.95 * (1.0 - k) * minf(1.0, (_trail.size() - 1 - i + 1) * 0.5))
			if i < _trail.size() - 1:
				_vert(last_a, last_c)
				_vert(last_b, last_c)
				_vert(b, col)
				_vert(last_a, last_c)
				_vert(b, col)
				_vert(a, col)
			last_a = a
			last_b = b
			last_c = col
	_mesh.surface_end()


func _vert(p: Vector3, c: Color) -> void:
	_mesh.surface_set_color(c)
	_mesh.surface_add_vertex(p)
