class_name PotFire
extends Node3D
## The fire under the cauldron: a handful of cards of flame (shaders/pot_fire.gdshader), each born
## somewhere in the bed of the fire, swelling, rising a little and going, then born again elsewhere
## (the way a particle system would do it, but just nine of them, moved here); sparks going up; and
## a warm light that wavers. `intensity` is how fierce it is (the bellows); the node is at its foot.

const CARDS := 12

## 0.5 low embers, 1 a good fire, 2 roaring
var intensity := 1.0
var light_energy := 2.5
## How far out from the middle the flames are born
var radius := 0.75
## How tall a flame is at intensity 1
var height := 0.7

var _mm: MultiMesh
var _mat: ShaderMaterial
var _light: OmniLight3D
var _cards: Array[Dictionary] = []
var _sparks: CPUParticles3D
var _skirts: Array[ShaderMaterial] = []
var _t := 0.0


func _ready() -> void:
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_custom_data = true
	_mm.use_colors = true
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	q.center_offset = Vector3(0, 0.5, 0)
	_mm.mesh = q
	_mm.instance_count = CARDS
	var node := MultiMeshInstance3D.new()
	node.multimesh = _mm
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://shaders/pot_fire.gdshader")
	node.material_override = _mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.custom_aabb = AABB(Vector3(-2, -0.5, -2), Vector3(4, 3, 4))
	add_child(node)
	for i in CARDS:
		_cards.append(_born({}, randf()))
	# Rings of fire round the pot's belly (shaders/flame_skirt.gdshader), one inside another: the
	# inner tall, the outer lower, each flickering on its own
	var mesh := _band_mesh()
	for spec: Array in [[0.82, 1.0, 0.0], [1.0, 0.75, 3.7], [1.16, 0.5, 8.1]]:
		var band := MeshInstance3D.new()
		band.mesh = mesh
		band.scale = Vector3(spec[0], spec[1], spec[0])
		var m := ShaderMaterial.new()
		m.shader = preload("res://shaders/flame_skirt.gdshader")
		m.set_shader_parameter("seed", spec[2])
		band.material_override = m
		band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(band)
		_skirts.append(m)
	_light = OmniLight3D.new()
	_light.position = Vector3(0, 0.35, 1.25)
	_light.light_color = Color(1.0, 0.58, 0.24)
	_light.omni_range = 8.0
	_light.omni_attenuation = 1.2
	add_child(_light)
	_sparks = CPUParticles3D.new()
	var dot := QuadMesh.new()
	dot.size = Vector2(0.03, 0.03)
	_sparks.mesh = dot
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	sm.vertex_color_use_as_albedo = true
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_sparks.material_override = sm
	_sparks.amount = 18
	_sparks.lifetime = 1.4
	_sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_sparks.emission_sphere_radius = radius
	_sparks.direction = Vector3.UP
	_sparks.spread = 25.0
	_sparks.gravity = Vector3(0, 0.6, 0)
	_sparks.initial_velocity_min = 0.4
	_sparks.initial_velocity_max = 1.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(2.0, 1.2, 0.4, 1.0))
	ramp.set_color(1, Color(1.0, 0.2, 0.05, 0.0))
	_sparks.color_ramp = ramp
	_sparks.position = Vector3(0, 0.15, 0)
	add_child(_sparks)


func _born(c: Dictionary, age := 0.0) -> Dictionary:
	var a := randf() * TAU
	var r := randf_range(0.88, 1.08) * radius
	c.at = Vector3(cos(a) * r, 0.0, sin(a) * r)
	c.life = randf_range(0.7, 1.15)
	c.t = age * c.life
	c.seed = randf()
	c.size = randf_range(0.8, 1.15)
	return c


func _process(dt: float) -> void:
	_t += dt
	var k := clampf(intensity, 0.2, 2.5)
	for i in CARDS:
		var c := _cards[i]
		c.t += dt * (0.8 + 0.4 * k)
		if c.t >= c.life:
			_born(c)
		var age: float = c.t / c.life
		var h: float = height * c.size * (0.6 + 0.4 * k) * (0.75 + 0.35 * age)
		var w: float = h * 0.85
		var at: Vector3 = c.at + Vector3(0, age * 0.12, 0)
		_mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(w, h, w)), at))
		_mm.set_instance_custom_data(i, Color(c.seed, age, 0, 0))
		_mm.set_instance_color(i, Color.WHITE)
	_mat.set_shader_parameter("intensity", 0.85 + 0.25 * k)
	for m in _skirts:
		m.set_shader_parameter("clock", _t * (0.8 + 0.3 * k))
		m.set_shader_parameter("reach", clampf(0.65 + 0.3 * k, 0.5, 1.3))
	var flick := 0.85 + 0.15 * sin(_t * 9.1) * sin(_t * 3.7 + 1.3)
	_light.light_energy = light_energy * flick
	_sparks.speed_scale = 0.7 + 0.4 * k


## An open band round the pot: wide at the foot and drawing in over the belly, in the pot's soft
## hexagon (Brew.pent), from the ash up to about the belly's widest
static func _band_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 48
	var rows := [[0.0, 0.62], [0.3, 0.82], [0.6, 0.98], [1.0, 1.04]]
	for j in rows.size():
		for i in seg + 1:
			var a := TAU * i / seg
			var r: float = rows[j][1] * Brew.pent(a)
			st.set_uv(Vector2(float(i) / seg, float(j) / (rows.size() - 1)))
			st.add_vertex(Vector3(cos(a) * r, rows[j][0], sin(a) * r))
	for j in rows.size() - 1:
		for i in seg:
			var a := j * (seg + 1) + i
			var b := a + seg + 1
			for k: int in [a, b, a + 1, a + 1, b, b + 1]:
				st.add_index(k)
	return st.commit()
