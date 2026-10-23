class_name Brew
extends Node3D
## What's in the cauldron, alive: its surface (shaders/brew.gdshader, after GameCommon's water) on a
## real wave pool (Waves) that the stick and everything dropped in disturb, bubbles that swell and
## burst into rings, steam winding up in Wind Waker streamers, sparkles fizzing up, splashes
## when things go in (tiers of brew with ragged crests, rings and flung drops, after Salmon Run 2's),
## and the light it throws on the hut. How it all looks is a PotionLook; the brew eases from one
## look to the next. Stands at the middle of the surface.

const RADIUS := 0.8
const MAX_BUBBLES := 28
const MAX_SPARKS := 48

var look := PotionLook.from_colour(Book.WATER)
## 0 to 1, from the fire
var heat := 0.0
## How far the stick has turned it, and how spoilt it is (0 to 1)
var spin := 0.0
var murk := 0.0

var _target: PotionLook = look
var _mat: ShaderMaterial
var _light: OmniLight3D
var _bubbles: MultiMeshInstance3D
var _streamers: Streamers
var _waves: Waves
var _sparks: MultiMeshInstance3D
var _b: Array[Dictionary] = []
var _s: Array[Dictionary] = []
var _clock := 0.0
var _bubble_due := 0.0
var _puff_due := 0.0
var _spark_due := 0.0
var _vents: Array[Vector2] = []
var _flash := 0.0
var _splashes: Array[Splash] = []
var _next_splash := 0


func _ready() -> void:
	_waves = Waves.new(RADIUS)
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://shaders/brew.gdshader")
	_mat.set_shader_parameter("radius", RADIUS)
	_mat.set_shader_parameter("waves", _waves.texture)
	_mat.set_shader_parameter("height_range", Waves.HEIGHT_RANGE)
	_mat.set_shader_parameter("slope_range", Waves.SLOPE_RANGE)
	var surface := MeshInstance3D.new()
	surface.name = "surface"
	surface.mesh = _surface_mesh()
	surface.material_override = _mat
	add_child(surface)
	_light = OmniLight3D.new()
	_light.position = Vector3(0, 0.55, 0.15)
	_light.omni_range = 9.0
	_light.omni_attenuation = 1.3
	add_child(_light)
	_bubbles = _multi("bubbles", _dome(), preload("res://shaders/bubble.gdshader"), MAX_BUBBLES)
	_streamers = Streamers.new()
	_streamers.name = "streamers"
	add_child(_streamers)
	_sparks = _multi("sparks", _card(), preload("res://shaders/spark.gdshader"), MAX_SPARKS)
	for i in 3:
		_vents.append(Vector2(randf_range(-0.4, 0.4), randf_range(-0.4, 0.4)))
	for i in 3:
		var sp := Splash.new()
		add_child(sp)
		_splashes.append(sp)
	_apply(look)


## The look it's becoming (it eases toward it), or at once
func set_look(l: PotionLook, at_once := false) -> void:
	_target = l
	if at_once:
		look = l
		_apply(look)


## Rings out from where something touched the surface (local x, z)
func ripple(at: Vector2, power := 1.0) -> void:
	_waves.push(at, 0.014 * power, 0.05 + 0.025 * minf(power, 2.0))


## The stick drawn through the brew at a point (local x, z), going speed metres a second: a wake
func wake(at: Vector2, speed: float) -> void:
	_waves.push(at, clampf(0.0015 + speed * 0.0035, 0.0, 0.012), 0.045)


## A splash where something dropped in (local), as big as `strength`
func splash(at: Vector3, strength := 1.0) -> void:
	var sp := _splashes[_next_splash]
	_next_splash = (_next_splash + 1) % _splashes.size()
	sp.start(Vector3(at.x, 0.0, at.z), strength, look)
	ripple(Vector2(at.x, at.z), 1.6 * strength)
	_flash = maxf(_flash, 0.25 * strength)


func flash(amount: float) -> void:
	_flash = maxf(_flash, amount)


## A burst of smoke (steam, spores) from a point on the surface (local), in a colour: streamers
## that wind up quick and curly
func puffs(at: Vector3, count: int, col: Color, speed := 0.6, size := 1.0) -> void:
	for i in maxi(3, count * 2 / 3):
		_streamers.add(Vector3(at.x + randf_range(-0.12, 0.12), 0.03, at.z + randf_range(-0.12, 0.12)), col, clampf(speed, 0.3, 1.0), size * 1.3)


## A burst of sparks flung up from a point (local)
func sparks(at: Vector3, count: int, col: Color, speed := 1.5) -> void:
	for i in count:
		var dir := Vector3(randf_range(-0.6, 0.6), 1.0, randf_range(-0.6, 0.6)).normalized()
		_add_spark(Vector3(at.x, 0.04, at.z), dir * speed * randf_range(0.6, 1.3), col, randf_range(0.6, 1.2))


## A crop of bubbles all at once
func bubble_burst(count: int, size := 1.5) -> void:
	for i in count:
		_add_bubble(size)


func _process(dt: float) -> void:
	_clock += dt
	# Ease toward the look it's becoming
	if look != _target:
		look = PotionLook.blend(look, _target, minf(1.0, dt * 2.5))
		if _close(look, _target):
			look = _target
		_apply(look)
	_flash = maxf(0.0, _flash - dt * 2.0)
	_mat.set_shader_parameter("clock", _clock)
	_mat.set_shader_parameter("spin", spin)
	_mat.set_shader_parameter("boil", clampf(heat * 1.3 - 0.2, 0.0, 1.0))
	_mat.set_shader_parameter("murk", murk)
	_mat.set_shader_parameter("flash", _flash)
	var flick := 0.88 + 0.12 * sin(_clock * 7.3) * sin(_clock * 3.1 + 1.0)
	_light.light_color = look.light_colour.lerp(Color(0.5, 0.4, 0.25), murk)
	_light.light_energy = look.light_energy * (0.9 + heat * 1.4) * flick * (1.0 - murk * 0.6) + _flash * 3.0
	_tend_bubbles(dt)
	_tend_steam(dt)
	_waves.keep = lerpf(0.988, 0.965, look.thickness)
	_waves.speed = lerpf(0.34, 0.2, look.thickness)
	_waves.update(dt)
	_tend_sparks(dt)


# --- bubbles: swell, then burst into a ring ---

func _add_bubble(size_k := 1.0) -> void:
	if _b.size() >= MAX_BUBBLES:
		return
	var a := randf() * TAU
	var r := sqrt(randf()) * 0.68
	var thick := look.thickness
	_b.append({"at": Vector2(cos(a), sin(a)) * r, "size": randf_range(0.035, 0.075) * look.bubble_size * size_k * (1.0 + thick * 0.8),
			"t": 0.0, "life": randf_range(0.45, 1.0) * (1.0 + thick * 1.5)})


func _tend_bubbles(dt: float) -> void:
	_bubble_due += dt * look.bubbles * (0.4 + heat * 3.0) * (1.0 - murk * 0.7)
	while _bubble_due >= 1.0:
		_bubble_due -= 1.0
		_add_bubble()
	var mm := _bubbles.multimesh
	var shown := 0
	for i in range(_b.size() - 1, -1, -1):
		var b := _b[i]
		b.t += dt
		var k: float = b.t / b.life
		if k >= 1.0:
			# Pop: a ring, and now and then a drop or two
			ripple(b.at, clampf(b.size * 6.0, 0.15, 0.8))
			if randf() < 0.3:
				sparks(Vector3(b.at.x, 0, b.at.y), 2, look.bubble_colour, 0.8)
			_b.remove_at(i)
	for b in _b:
		var k: float = b.t / b.life
		var s: float = b.size * (smoothstep(0.0, 0.7, k) + 0.25 * maxf(0.0, (k - 0.85) / 0.15))
		var at: Vector2 = b.at
		mm.set_instance_transform(shown, Transform3D(Basis().scaled(Vector3(s, s * 0.85, s)), Vector3(at.x, -s * 0.2, at.y)))
		mm.set_instance_color(shown, Color(1, 1, 1, minf(1.0, k * 5.0)))
		shown += 1
	mm.visible_instance_count = shown


# --- steam winding up off it from wandering vents ---

func _tend_steam(dt: float) -> void:
	for i in _vents.size():
		_vents[i] += Vector2(sin(_clock * 0.7 + i * 2.0), cos(_clock * 0.5 + i * 3.0)) * dt * 0.15
		_vents[i] = _vents[i].limit_length(0.5)
	_puff_due += dt * look.steam * (0.3 + heat) * 4.0 * (1.0 - murk * 0.5)
	while _puff_due >= 1.0:
		_puff_due -= 1.0
		var v := _vents[randi() % _vents.size()]
		var sc := look.steam_colour
		_streamers.add(Vector3(v.x + randf_range(-0.08, 0.08), 0.02, v.y + randf_range(-0.08, 0.08)), Color(sc, minf(1.0, sc.a * 1.5)))


# --- sparkles fizzing up ---

func _add_spark(at: Vector3, vel: Vector3, col: Color, life: float) -> void:
	if _s.size() >= MAX_SPARKS:
		_s.remove_at(0)
	_s.append({"at": at, "vel": vel, "col": col, "t": 0.0, "life": life})


func _tend_sparks(dt: float) -> void:
	_spark_due += dt * look.sparkles * (0.5 + heat) * 7.0
	while _spark_due >= 1.0:
		_spark_due -= 1.0
		var a := randf() * TAU
		var r := sqrt(randf()) * 0.6
		_add_spark(Vector3(cos(a) * r, 0.03, sin(a) * r), Vector3(randf_range(-0.1, 0.1), randf_range(0.5, 1.1), randf_range(-0.1, 0.1)), look.sparkle_colour, randf_range(0.8, 1.5))
	var mm := _sparks.multimesh
	var shown := 0
	for i in range(_s.size() - 1, -1, -1):
		var s := _s[i]
		s.t += dt
		if s.t >= s.life:
			_s.remove_at(i)
			continue
		s.vel += Vector3(0, -2.0, 0) * dt * 0.4
		s.at += s.vel * dt
	for s in _s:
		var k: float = s.t / s.life
		var size := 0.05 * (1.0 - k * 0.6) * (0.7 + 0.3 * sin(s.t * 20.0))
		mm.set_instance_transform(shown, Transform3D(Basis().scaled(Vector3.ONE * size), s.at))
		var col: Color = s.col
		col.a = 1.0 - k
		mm.set_instance_color(shown, col)
		shown += 1
	mm.visible_instance_count = shown


# --- making it ---

func _apply(l: PotionLook) -> void:
	_mat.set_shader_parameter("liquid", l.liquid)
	_mat.set_shader_parameter("deep", l.deep)
	_mat.set_shader_parameter("foam", l.foam)
	_mat.set_shader_parameter("glow", l.glow)
	_mat.set_shader_parameter("lines", l.lines)
	_mat.set_shader_parameter("glints", l.glints)
	_mat.set_shader_parameter("thickness", l.thickness)
	_mat.set_shader_parameter("swirl", l.swirl)
	var bm := _bubbles.material_override as ShaderMaterial
	bm.set_shader_parameter("tint", l.bubble_colour)
	bm.set_shader_parameter("opacity", l.bubble_opacity)
	bm.set_shader_parameter("shine", l.bubble_shine)


static func _close(a: PotionLook, b: PotionLook) -> bool:
	return a.liquid.is_equal_approx(b.liquid) or (Vector3(a.liquid.r, a.liquid.g, a.liquid.b) - Vector3(b.liquid.r, b.liquid.g, b.liquid.b)).length() < 0.004


func _multi(name: String, mesh: Mesh, shader: Shader, count: int) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = count
	mm.visible_instance_count = 0
	var node := MultiMeshInstance3D.new()
	node.name = name
	node.multimesh = mm
	var mat := ShaderMaterial.new()
	mat.shader = shader
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.custom_aabb = AABB(Vector3(-2, -1, -2), Vector3(4, 6, 4))
	add_child(node)
	return node


## A disc of rings for the surface, fine enough to ripple
func _surface_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 20
	var seg := 56
	for i in rings:
		for j in seg:
			var a0 := TAU * j / seg
			var a1 := TAU * (j + 1) / seg
			var r0 := RADIUS * float(i) / rings
			var r1 := RADIUS * float(i + 1) / rings
			var p := [Vector3(cos(a0) * r0, 0, sin(a0) * r0), Vector3(cos(a1) * r0, 0, sin(a1) * r0),
					Vector3(cos(a1) * r1, 0, sin(a1) * r1), Vector3(cos(a0) * r1, 0, sin(a0) * r1)]
			for k: int in [0, 2, 1, 0, 3, 2]:
				st.set_normal(Vector3.UP)
				st.add_vertex(p[k])
	return st.commit()


## A dome for a bubble: the top of a ball
static func _dome() -> Mesh:
	var m := SphereMesh.new()
	m.radius = 1.0
	m.height = 2.0
	m.radial_segments = 10
	m.rings = 5
	return m


static func _card() -> Mesh:
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	return q


## A splash, after Salmon Run 2's: three tubes of brew, one inside another like the tiers of a cake
## (the outer wide and low, the inner narrow and tall), that shoot up with ragged crests and fall
## back, and a burst of splattery drops. Kept and used again, not made afresh each time.
class Splash:
	extends Node3D

	const LIFE := 0.9
	## Each tube: how far out, how tall, how many waves in its crest, when it goes up
	const TUBES := [[0.06, 0.42, 5.0, 0.0], [0.13, 0.27, 7.0, 0.05], [0.21, 0.14, 10.0, 0.1]]
	const TUBE_TIME := 0.58

	var _t := 9.0
	var _strength := 1.0
	var _tubes: Array[MeshInstance3D] = []
	var _drops: Array[CPUParticles3D] = []

	func _init() -> void:
		visible = false
		set_process(false)
		var tube_mesh := _tube_mesh()
		for i in TUBES.size():
			var node := MeshInstance3D.new()
			node.mesh = tube_mesh
			var mat := ShaderMaterial.new()
			mat.shader = preload("res://shaders/splash.gdshader")
			mat.set_shader_parameter("waves", TUBES[i][2])
			node.material_override = mat
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(node)
			_tubes.append(node)
		var drop_mat := StandardMaterial3D.new()
		drop_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		drop_mat.vertex_color_use_as_albedo = true
		for spec: Array in [[10, 0.045, 1.4, 2.6], [18, 0.02, 1.2, 3.2]]:
			var p := CPUParticles3D.new()
			var ball := SphereMesh.new()
			ball.radius = 1.0
			ball.height = 2.0
			ball.radial_segments = 6
			ball.rings = 3
			p.mesh = ball
			p.material_override = drop_mat
			p.amount = spec[0]
			p.one_shot = true
			p.emitting = false
			p.explosiveness = 0.95
			p.lifetime = 0.7
			p.local_coords = true
			p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			p.emission_sphere_radius = 0.06
			p.direction = Vector3.UP
			p.spread = 50.0
			p.gravity = Vector3(0, -9.0, 0)
			p.initial_velocity_min = spec[2]
			p.initial_velocity_max = spec[3]
			p.scale_amount_min = spec[1] * 0.6
			p.scale_amount_max = spec[1] * 1.3
			var shrink := Curve.new()
			shrink.add_point(Vector2(0.0, 1.0))
			shrink.add_point(Vector2(0.7, 0.8))
			shrink.add_point(Vector2(1.0, 0.0))
			p.scale_amount_curve = shrink
			add_child(p)
			_drops.append(p)

	func start(at: Vector3, strength: float, look: PotionLook) -> void:
		position = at
		_strength = strength
		_t = 0.0
		var body := look.liquid.lerp(look.foam, 0.15)
		for node in _tubes:
			var mat := node.material_override as ShaderMaterial
			mat.set_shader_parameter("phase", randf() * TAU)
			mat.set_shader_parameter("white", look.foam)
			mat.set_shader_parameter("pale", body.lerp(look.foam, 0.55))
			mat.set_shader_parameter("blue", body)
			node.visible = false
		for p in _drops:
			p.color = body.lerp(look.foam, 0.4)
			p.initial_velocity_max = 3.0 * sqrt(strength)
			p.restart()
			p.emitting = true
		visible = true
		set_process(true)

	func _process(dt: float) -> void:
		_t += dt
		if _t > LIFE:
			visible = false
			set_process(false)
			return
		for i in _tubes.size():
			var u := (_t - float(TUBES[i][3])) / TUBE_TIME
			var node := _tubes[i]
			node.visible = u > 0.0 and u < 1.0
			if not node.visible:
				continue
			# Up fast, hang at the top, drop back
			var rise := sin(minf(u / 0.2, 1.0) * PI * 0.5) if u < 0.2 else 1.0 - pow((u - 0.2) / 0.8, 2.0)
			var r := float(TUBES[i][0]) * sqrt(_strength) * (1.0 + 0.4 * u)
			node.scale = Vector3(r, maxf(float(TUBES[i][1]) * _strength * rise, 0.01), r)
			(node.material_override as ShaderMaterial).set_shader_parameter("spent", smoothstep(0.3, 1.0, u))

	static func _tube_mesh() -> ArrayMesh:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var seg := 24
		var rows := 4
		for j in rows + 1:
			var v := float(j) / rows
			var radius := 1.0 + 0.16 * v * v
			for i in seg + 1:
				var a := TAU * i / seg
				st.set_uv(Vector2(float(i) / seg, v))
				st.add_vertex(Vector3(cos(a) * radius, v, sin(a) * radius))
		for j in rows:
			for i in seg:
				var a := j * (seg + 1) + i
				var b := a + seg + 1
				for k: int in [a, b, a + 1, a + 1, b, b + 1]:
					st.add_index(k)
		return st.commit()
