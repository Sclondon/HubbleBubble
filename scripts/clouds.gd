class_name Clouds
extends MultiMeshInstance3D
## Puffy 3D smoke off the brew: lumpy see-through balls (shaders/cloud.gdshader) that billow up,
## swelling, drifting and turning, and thin away. A slow drift of them while it's hot, bursts when
## something goes in. Stands at the middle of the brew's surface.

const MAX := 40

var _all: Array[Dictionary] = []


func _ready() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	var ball := SphereMesh.new()
	ball.radius = 1.0
	ball.height = 2.0
	ball.radial_segments = 14
	ball.rings = 8
	mm.mesh = ball
	mm.instance_count = MAX
	mm.visible_instance_count = 0
	multimesh = mm
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/cloud.gdshader")
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	custom_aabb = AABB(Vector3(-3, -1, -3), Vector3(6, 7, 6))
	layers = 4


## One puff from a point (local), going up at `speed`, as big as `size`, in a colour
func add(at: Vector3, col: Color, speed := 0.35, size := 1.0) -> void:
	# a cluster of puffs, rolling up together
	for k in randi_range(3, 5):
		_one(at + Vector3(randf_range(-0.09, 0.09), randf_range(0.0, 0.1), randf_range(-0.09, 0.09)), col, speed * randf_range(0.85, 1.1), size * randf_range(0.6, 1.0))


func _one(at: Vector3, col: Color, speed: float, size: float) -> void:
	if _all.size() >= MAX:
		_all.remove_at(0)
	_all.append({"at": at, "vel": Vector3(randf_range(-0.08, 0.08), speed * randf_range(0.8, 1.2), randf_range(-0.08, 0.08)),
			"col": col, "t": 0.0, "life": randf_range(2.2, 3.4), "size": randf_range(0.11, 0.17) * size,
			"seed": randf(), "spin": randf_range(-0.6, 0.6)})


func _process(dt: float) -> void:
	var mm := multimesh
	var shown := 0
	for i in range(_all.size() - 1, -1, -1):
		var c := _all[i]
		c.t += dt
		if c.t >= c.life:
			_all.remove_at(i)
			continue
		# wobbling as it rises, pushed about by the air
		var ph: float = c.seed * 20.0 + c.t * 1.7
		c.at += (c.vel + Vector3(sin(ph) * 0.12, 0.0, cos(ph * 1.3) * 0.12)) * dt
		c.vel *= 1.0 - dt * 0.35
	for c in _all:
		var k: float = c.t / c.life
		var s: float = c.size * (0.5 + 1.7 * sqrt(k))
		var b := Basis(Vector3.UP, c.t * c.spin).scaled(Vector3(s, s * 0.85, s))
		mm.set_instance_transform(shown, Transform3D(b, c.at))
		var col: Color = c.col
		col.a = smoothstep(0.0, 0.12, k) * (1.0 - smoothstep(0.45, 1.0, k))
		mm.set_instance_color(shown, col)
		mm.set_instance_custom_data(shown, Color(c.seed, 0, 0, 0))
		shown += 1
	mm.visible_instance_count = shown
