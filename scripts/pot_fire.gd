class_name PotFire
extends Node3D
## The fire under the cauldron, built the way stylized game fires are (see shaders/flame_soft.gdshader):
## soft puffs of flame born round the bed of the fire under the pot, swelling and rising and eaten
## away as they go, lapping up round the iron; embers drifting up slowly, glowing and winking; sparks
## shooting up fast and streaking; a glow on the ash; and a flickering orange light that casts
## shadows. The bellows blow into it (blow()): the flames lean and roar up, a burst of sparks and
## embers. `intensity` is how fierce it is (the heat); the node is at its foot.

const FLAMES := 26
const EMBERS := 40
const SPARKS := 28

## 0.5 low, 1 a good fire, 2 roaring
var intensity := 1.0
var light_energy := 2.5
## How far out from the middle the flames are born, and how tall one is at intensity 1
var radius := 0.62
var height := 0.62

var _flames: MultiMesh
var _flame_list: Array[Dictionary] = []
var _bits: MultiMesh
var _embers: Array[Dictionary] = []
var _sparks: Array[Dictionary] = []
var _light: OmniLight3D
var _glow_mat: ShaderMaterial
var _skirts: Array[ShaderMaterial] = []
var _t := 0.0
var _ember_due := 0.0
var _spark_due := 0.0
## Where the last puff of the bellows came from (a direction along the ground), and how much is left of it
var _blow_dir := Vector3.ZERO
var _blow := 0.0


func _ready() -> void:
	_flames = MultiMesh.new()
	_flames.transform_format = MultiMesh.TRANSFORM_3D
	_flames.use_custom_data = true
	_flames.use_colors = true
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	q.center_offset = Vector3(0, 0.42, 0)
	_flames.mesh = q
	_flames.instance_count = FLAMES
	var fn := MultiMeshInstance3D.new()
	fn.multimesh = _flames
	var fm := ShaderMaterial.new()
	fm.shader = preload("res://shaders/flame_soft.gdshader")
	fn.material_override = fm
	fn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fn.custom_aabb = AABB(Vector3(-2, -0.5, -2), Vector3(4, 3, 4))
	add_child(fn)
	for i in FLAMES:
		_flame_list.append(_born({}, randf()))
	# Embers and sparks: little glowing cards (sparks stretched along their path)
	_bits = MultiMesh.new()
	_bits.transform_format = MultiMesh.TRANSFORM_3D
	_bits.use_colors = true
	var dot := QuadMesh.new()
	dot.size = Vector2(1, 1)
	_bits.mesh = dot
	_bits.instance_count = EMBERS + SPARKS
	_bits.visible_instance_count = 0
	var bn := MultiMeshInstance3D.new()
	bn.multimesh = _bits
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.vertex_color_use_as_albedo = true
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	bm.cull_mode = BaseMaterial3D.CULL_DISABLED
	bn.material_override = bm
	bn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bn.custom_aabb = AABB(Vector3(-3, -0.5, -3), Vector3(6, 5, 6))
	add_child(bn)
	# Rings of fire round the pot's belly too (shaders/flame_skirt.gdshader), one inside another
	var band_mesh := _band_mesh()
	for spec: Array in [[0.82, 1.0, 0.0], [1.0, 0.75, 3.7], [1.16, 0.5, 8.1]]:
		var band := MeshInstance3D.new()
		band.mesh = band_mesh
		band.scale = Vector3(spec[0], spec[1], spec[0])
		var m := ShaderMaterial.new()
		m.shader = preload("res://shaders/flame_skirt.gdshader")
		m.set_shader_parameter("seed", spec[2])
		band.material_override = m
		band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(band)
		_skirts.append(m)
	# A glow on the ash under it
	var glow := MeshInstance3D.new()
	var disc := PlaneMesh.new()
	disc.size = Vector2(2.2, 2.2)
	glow.mesh = disc
	_glow_mat = ShaderMaterial.new()
	var gs := Shader.new()
	gs.code = "shader_type spatial;\nrender_mode unshaded, blend_add, depth_draw_never, cull_disabled;\nuniform float strength = 1.0;\nvoid fragment() {\n\tfloat d = length(UV * 2.0 - 1.0);\n\tALBEDO = vec3(1.0, 0.35, 0.06) * pow(max(0.0, 1.0 - d), 2.0) * strength;\n}\n"
	_glow_mat.shader = gs
	glow.material_override = _glow_mat
	glow.position = Vector3(0, 0.03, 0)
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(glow)
	# The fire's own light: orange, flickering, casting shadows (the pot's belly throws one up the
	# wall behind; the logs, the bellows throw theirs out across the floor)
	_light = OmniLight3D.new()
	_light.name = "fire_light"
	_light.position = Vector3(0, 0.3, 0.55)
	_light.light_color = Color(1.0, 0.55, 0.2)
	_light.omni_range = 7.0
	_light.omni_attenuation = 1.1
	_light.shadow_enabled = true
	_light.shadow_bias = 0.05
	_light.shadow_normal_bias = 1.5
	# (not on the brew, nor the smoke layer: a shadowed light there stops the smoke camera drawing)
	_light.light_cull_mask = 0xFFFFF & ~2 & ~4
	add_child(_light)


## A puff of the bellows from `from` (a point in the hut, the bellows' nozzle): the flames lean away
## from it and roar up, and sparks and embers burst out
func blow(from: Vector3) -> void:
	var d := global_position - from
	d.y = 0.0
	_blow_dir = global_basis.inverse() * (d.normalized() if d.length() > 0.01 else Vector3.BACK)
	_blow = 1.0
	for i in 10:
		_add_spark(true)
	for i in 8:
		_add_ember(true)


func _born(c: Dictionary, age := 0.0) -> Dictionary:
	var a := randf() * TAU
	var r := sqrt(randf()) * radius
	c.at = Vector3(cos(a) * r, 0.0, sin(a) * r)
	c.life = randf_range(0.55, 0.95)
	c.t = age * c.life
	c.seed = randf()
	c.size = randf_range(0.7, 1.2) * (1.15 - r / radius * 0.4)
	c.out = Vector3(cos(a), 0, sin(a))
	return c


func _add_ember(burst := false) -> void:
	if _embers.size() >= EMBERS:
		_embers.remove_at(0)
	var a := randf() * TAU
	var r := sqrt(randf()) * radius * 1.1
	var push := _blow_dir * (randf_range(0.4, 1.0) if burst else 0.0)
	_embers.append({"at": Vector3(cos(a) * r, 0.15, sin(a) * r), "vel": Vector3(randf_range(-0.1, 0.1), randf_range(0.25, 0.6), randf_range(-0.1, 0.1)) + push,
			"t": 0.0, "life": randf_range(1.5, 3.0), "size": randf_range(0.012, 0.024), "phase": randf() * TAU})


func _add_spark(burst := false) -> void:
	if _sparks.size() >= SPARKS:
		_sparks.remove_at(0)
	var a := randf() * TAU
	var r := sqrt(randf()) * radius
	var dir := Vector3(randf_range(-0.35, 0.35), 1.0, randf_range(-0.35, 0.35)).normalized() + (_blow_dir * 0.6 if burst else Vector3.ZERO)
	_sparks.append({"at": Vector3(cos(a) * r, 0.2, sin(a) * r), "vel": dir * randf_range(1.6, 3.2) * (1.3 if burst else 1.0), "t": 0.0, "life": randf_range(0.35, 0.7)})


func _process(dt: float) -> void:
	_t += dt
	var k := clampf(intensity + _blow * 0.8, 0.2, 3.0)
	_blow = maxf(0.0, _blow - dt * 1.4)
	# Flames: born round the bed, swelling and rising, leaning away from the bellows and lapping up
	# round the iron
	for i in FLAMES:
		var c := _flame_list[i]
		c.t += dt * (0.9 + 0.35 * k)
		if c.t >= c.life:
			_born(c)
		var age: float = c.t / c.life
		var h: float = height * c.size * (0.55 + 0.45 * k) * (0.6 + 0.7 * age)
		var lean: Vector3 = _blow_dir * _blow * 0.35 * age + (c.out as Vector3) * age * 0.18
		var at: Vector3 = c.at + lean + Vector3(0, age * 0.35 * (0.7 + 0.3 * k), 0)
		_flames.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(h * 0.75, h, h * 0.75)), at))
		_flames.set_instance_custom_data(i, Color(c.seed, age, 0, 0))
		_flames.set_instance_color(i, Color(1, 1, 1, clampf(0.55 + 0.25 * k, 0.4, 1.2)))
	# Embers and sparks, more the fiercer it is
	_ember_due += dt * (3.0 + 5.0 * k)
	while _ember_due >= 1.0:
		_ember_due -= 1.0
		_add_ember()
	_spark_due += dt * (1.0 + 4.0 * k * k)
	while _spark_due >= 1.0:
		_spark_due -= 1.0
		_add_spark()
	var cam := get_viewport().get_camera_3d()
	var to_cam := Vector3.BACK
	if cam != null:
		to_cam = global_basis.inverse() * (cam.global_position - global_position).normalized()
	var shown := 0
	for i in range(_embers.size() - 1, -1, -1):
		var e := _embers[i]
		e.t += dt
		if e.t >= e.life:
			_embers.remove_at(i)
			continue
		# drifting up slow, wandering, slowing
		e.vel += Vector3(sin(_t * 2.0 + e.phase) * 0.25, 0.05, cos(_t * 1.7 + e.phase) * 0.25) * dt
		e.vel *= 1.0 - dt * 0.6
		e.at += e.vel * dt
	var face := Basis.looking_at(-to_cam, Vector3.UP)
	for e in _embers:
		var k2: float = e.t / e.life
		var wink := 0.6 + 0.4 * sin(_t * 14.0 + e.phase * 5.0)
		var col := Color(1.0, 0.75, 0.3).lerp(Color(0.9, 0.15, 0.03), k2)
		col.a = (1.0 - k2) * wink
		_bits.set_instance_transform(shown, Transform3D(face.scaled(Vector3.ONE * e.size * (1.0 - 0.4 * k2)), e.at))
		_bits.set_instance_color(shown, col)
		shown += 1
	for i in range(_sparks.size() - 1, -1, -1):
		var s := _sparks[i]
		s.t += dt
		if s.t >= s.life:
			_sparks.remove_at(i)
			continue
		s.vel += Vector3(0, -2.5, 0) * dt
		s.at += s.vel * dt
	for s in _sparks:
		var k3: float = s.t / s.life
		# stretched along the way it's going, as the eye sees a fast spark
		var v: Vector3 = s.vel
		var up := v.normalized()
		var side := up.cross(to_cam).normalized()
		var b := Basis(side * 0.012, up * clampf(v.length() * 0.035, 0.02, 0.12), to_cam)
		var col := Color(1.0, 0.95, 0.7).lerp(Color(1.0, 0.45, 0.1), k3)
		col.a = 1.0 - k3
		_bits.set_instance_transform(shown, Transform3D(b, s.at))
		_bits.set_instance_color(shown, col)
		shown += 1
	_bits.visible_instance_count = shown
	# The light flickers (a few slow waves and a fast shiver), brighter with the heat and the bellows
	var flick := 0.78 + 0.12 * sin(_t * 7.3) + 0.07 * sin(_t * 13.1 + 1.7) + 0.05 * sin(_t * 23.0)
	_light.light_energy = light_energy * flick * (0.6 + 0.4 * k)
	_light.position = Vector3(0.05 * sin(_t * 5.0), 0.3 + 0.04 * sin(_t * 9.0), 0.55)
	_glow_mat.set_shader_parameter("strength", (0.35 + 0.25 * k) * flick)
	for m in _skirts:
		m.set_shader_parameter("clock", _t * (0.8 + 0.3 * k))
		m.set_shader_parameter("reach", clampf(0.6 + 0.3 * k, 0.5, 1.3))


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
			for kk: int in [a, b, a + 1, a + 1, b, b + 1]:
				st.add_index(kk)
	return st.commit()
