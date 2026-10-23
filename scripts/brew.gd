class_name Brew
extends Node3D
## What's in the cauldron, alive: its surface (shaders/brew.gdshader, after GameCommon's water) on a
## real wave pool (Waves) that the stick and everything dropped in disturb, a current when it's
## stirred (it dips into a vortex and carries things round), what's been put in bobbing about on it
## until the fire cooks it, bubbles that swell and burst into rings, steam winding up in Wind Waker
## streamers, sparkles fizzing up, splashes
## when things go in (tiers of brew with ragged crests, rings and flung drops, after Salmon Run 2's),
## and the light it throws on the hut. How it all looks is a PotionLook; the brew eases from one
## look to the next. Stands at the middle of the surface.

const RADIUS := 0.8
const MAX_BUBBLES := 40
const MAX_SPARKS := 48

var look := PotionLook.from_colour(Book.WATER)
## 0 to 1, from the fire
var heat := 0.0
## How far the stick has turned it, and how spoilt it is (0 to 1)
var spin := 0.0
var murk := 0.0
## How fast it's going round (radians a second, + sunwise), from the stick
var current := 0.0
## Seconds left of the cooking (the pot rattling, what's in it jiggling, then gone)
var cooking := 0.0

var _floaters: Array[Dictionary] = []

var _target: PotionLook = look
var _mat: ShaderMaterial
var _light: OmniLight3D
var _bubbles: MultiMeshInstance3D
var _streamers: Streamers
var _tendrils: Streamers
var _clouds: Clouds
var _wake: Wake
var _shapes: MultiMeshInstance3D
var _shape_list: Array[Dictionary] = []
var _shape_due := 2.0
var _cloud_due := 0.0
var _haze: MultiMeshInstance3D
var _haze_cards: Array[Dictionary] = []
var _tendril_due := 0.0
var _glow_light: OmniLight3D
var _spot: SpotLight3D
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
	# (on a layer of its own, so its own glow lights the room, not itself)
	surface.layers = 2
	add_child(surface)
	_light = OmniLight3D.new()
	_light.position = Vector3(0, 0.55, 0.15)
	_light.omni_range = 9.0
	_light.omni_attenuation = 1.3
	_light.light_cull_mask = 0xFFFFF & ~2
	add_child(_light)
	_bubbles = _multi("bubbles", _dome(), preload("res://shaders/bubble.gdshader"), MAX_BUBBLES)
	_streamers = Streamers.new()
	_streamers.name = "streamers"
	add_child(_streamers)
	_tendrils = Streamers.new()
	_tendrils.name = "tendrils"
	_tendrils.glowing = true
	add_child(_tendrils)
	_wake = Wake.new(_waves)
	_wake.name = "wake"
	add_child(_wake)
	_clouds = Clouds.new()
	_clouds.name = "clouds"
	add_child(_clouds)
	_shapes = _multi("shapes", _card(), preload("res://shaders/smoke_shape.gdshader"), 6)
	_shapes.layers = 4
	_haze = _multi("haze", _card_foot(), preload("res://shaders/haze.gdshader"), 5)
	_haze.multimesh.visible_instance_count = 5
	_haze.custom_aabb = AABB(Vector3(-3, -1, -3), Vector3(6, 8, 6))
	for i in 5:
		_haze_cards.append({"t": randf(), "life": randf_range(3.0, 4.5), "seed": randf(), "x": randf_range(-0.25, 0.25)})
	# A second, wider light high over the pot: the potion's colour washing the room
	_glow_light = OmniLight3D.new()
	_glow_light.position = Vector3(0, 1.6, 0.3)
	_glow_light.omni_range = 11.0
	_glow_light.omni_attenuation = 0.8
	_glow_light.light_cull_mask = 0xFFFFF & ~2
	add_child(_glow_light)
	_spot = SpotLight3D.new()
	_spot.name = "spot"
	_spot.position = Vector3(0, -0.02, 0.0)
	_spot.rotation = Vector3(PI * 0.5 + 0.12, 0, 0)
	_spot.spot_angle = 72.0
	_spot.spot_range = 9.0
	_spot.spot_attenuation = 0.6
	_spot.shadow_enabled = true
	_spot.shadow_bias = 0.04
	# (not on the smoke layer: a shadowed light there stops the smoke camera drawing at all)
	_spot.light_cull_mask = 0xFFFFF & ~2 & ~4
	add_child(_spot)
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
	# Becoming something with a shape of its own, the shape pops out at once
	if l.smoke_shape > 0 and l.smoke_shape != _target.smoke_shape:
		smoke_shape(l.smoke_shape, l.shape_colour, l.shape_size)
		_shape_due = l.shape_every
	_target = l
	if at_once:
		look = l
		_apply(look)


## Rings out from where something touched the surface (local x, z)
func ripple(at: Vector2, power := 1.0) -> void:
	_waves.push(at, 0.03 * power, 0.05 + 0.03 * minf(power, 2.0))


## The stick drawn through the brew at a point (local x, z), going speed metres a second: a wake
func wake(at: Vector2, speed: float) -> void:
	_wake.stick_at(at)
	_waves.push(at, clampf(0.006 + speed * 0.012, 0.0, 0.04), 0.055)
	_waves.foam(at, clampf(0.05 + speed * 0.12, 0.0, 0.35), 0.045)


## A splash where something dropped in (local), as big as `strength`
func splash(at: Vector3, strength := 1.0) -> void:
	var sp := _splashes[_next_splash]
	_next_splash = (_next_splash + 1) % _splashes.size()
	sp.start(Vector3(at.x, 0.0, at.z), strength, look)
	ripple(Vector2(at.x, at.z), 1.6 * strength)
	_waves.foam(Vector2(at.x, at.z), 0.5, 0.09 * sqrt(strength))
	_flash = maxf(_flash, 0.25 * strength)


func flash(amount: float) -> void:
	_flash = maxf(_flash, amount)


## A burst of smoke (steam, spores) from a point on the surface (local), in a colour: streamers
## that wind up quick and curly
func puffs(at: Vector3, count: int, col: Color, speed := 0.6, size := 1.0) -> void:
	for i in maxi(3, count * 2 / 3):
		_streamers.add(Vector3(at.x + randf_range(-0.12, 0.12), 0.03, at.z + randf_range(-0.12, 0.12)), col, clampf(speed, 0.3, 1.0), size * 1.3)
	# and a billow of puffy smoke
	for i in maxi(3, count / 2):
		_clouds.add(Vector3(at.x + randf_range(-0.15, 0.15), 0.08, at.z + randf_range(-0.15, 0.15)), Color(col, 1.0), 0.35 + speed * 0.5, size * randf_range(0.9, 1.4))


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
	_mat.set_shader_parameter("vortex", current)
	# The boil pocks the surface all over
	var boil := clampf(heat * 1.3 - 0.2, 0.0, 1.0)
	if randf() < dt * boil * 30.0 * (1.0 - murk * 0.5):
		var a := randf() * TAU
		var r := sqrt(randf()) * 0.65
		_waves.push(Vector2(cos(a), sin(a)) * r, -0.004 * (0.5 + boil), 0.04)
	_tend_floaters(dt)
	var flick := 0.88 + 0.12 * sin(_clock * 7.3) * sin(_clock * 3.1 + 1.0)
	_light.light_color = look.light_colour.lerp(Color(0.5, 0.4, 0.25), murk)
	_light.light_energy = (look.light_energy * (1.6 + heat * 2.2) * flick * (1.0 - murk * 0.6) + _flash * 3.0) * (0.4 + look.glow)
	_glow_light.light_color = _light.light_color
	_spot.light_color = _light.light_color
	_spot.light_energy = look.light_energy * (1.6 + heat * 1.6) * (0.4 + look.glow) * flick * (1.0 - murk * 0.6) + _flash * 4.0
	_glow_light.light_energy = (look.light_energy * (0.5 + heat * 0.8) * (0.3 + look.glow) * flick * (1.0 - murk * 0.7) + _flash * 1.5) * 0.35
	_tend_haze(dt)
	# Now and then its smoke shape pops out of it (more often when it's hot)
	if look.smoke_shape > 0 and murk < 0.5:
		_shape_due -= dt * (0.5 + heat)
		if _shape_due <= 0.0:
			_shape_due = look.shape_every
			smoke_shape(look.smoke_shape, look.shape_colour, look.shape_size)
	_tend_shapes(dt)
	# Now and then a puff of smoke rolls up off it, more when it's hot
	_cloud_due += dt * look.steam * (0.15 + heat * 1.2) * (1.0 + murk)
	while _cloud_due >= 1.0:
		_cloud_due -= 1.0
		var ca := randf() * TAU
		var cr := randf_range(0.1, 0.55)
		_clouds.add(Vector3(cos(ca) * cr, 0.06, sin(ca) * cr), Color(look.steam_colour.lerp(Color(0.25, 0.2, 0.15), murk), 1.0), randf_range(0.25, 0.4))
	# Glowing tendrils curling up out of it, in its own colour
	_tendril_due += dt * (0.25 + heat * 0.9) * clampf(look.glow * 1.5 + 0.2, 0.0, 1.5) * (1.0 - murk)
	while _tendril_due >= 1.0:
		_tendril_due -= 1.0
		var a := randf() * TAU
		var r := randf_range(0.2, 0.6)
		_tendrils.add_tendril(Vector3(cos(a) * r, 0.02, sin(a) * r), Color(look.light_colour, 0.45))
	_tend_bubbles(dt)
	_tend_steam(dt)
	_waves.keep = lerpf(0.988, 0.965, look.thickness)
	_waves.speed = lerpf(0.34, 0.2, look.thickness)
	_waves.update(dt)
	_tend_sparks(dt)


# --- shapes of smoke ---

## A shape of smoke pops out of the brew and rises, billowing out and fading: 1 a heart, 2 a skull and
## crossbones, 3 a star, 4 a moon, 5 a ghost, 6 a spiral
func smoke_shape(which: int, col: Color, size := 1.0) -> void:
	if _shape_list.size() >= 6:
		_shape_list.remove_at(0)
	_shape_list.append({"shape": which, "col": col, "size": size, "t": 0.0, "life": randf_range(2.6, 3.2), "seed": randf(),
			"x": randf_range(-0.2, 0.2), "drift": randf_range(-0.12, 0.12), "tilt": randf_range(-0.15, 0.15)})
	ripple(Vector2(_shape_list[-1].x, 0.0), 1.0)
	_waves.foam(Vector2(_shape_list[-1].x, 0.0), 0.6, 0.12)


func _tend_shapes(dt: float) -> void:
	var mm := _shapes.multimesh
	var shown := 0
	for i in range(_shape_list.size() - 1, -1, -1):
		_shape_list[i].t += dt
		if _shape_list[i].t >= _shape_list[i].life:
			_shape_list.remove_at(i)
	for sh in _shape_list:
		var k: float = sh.t / sh.life
		# Pops up out of the brew with a bounce, then rises slowly, swelling
		var pop := 1.0 - pow(1.0 - minf(k / 0.15, 1.0), 3.0)
		var s: float = sh.size * (0.25 + 0.4 * pop + 0.35 * k)
		var at := Vector3(sh.x + sh.drift * k + sin(k * 6.0 + sh.seed * 6.0) * 0.04, 0.25 * pop + 0.9 * k + s * 0.5, 0.05)
		mm.set_instance_transform(shown, Transform3D(Basis(Vector3.BACK, sh.tilt * sin(k * 4.0)).scaled(Vector3.ONE * s), at))
		mm.set_instance_custom_data(shown, Color(sh.shape, sh.seed, k, 0))
		mm.set_instance_color(shown, sh.col)
		shown += 1
	mm.visible_instance_count = shown


# --- the glow standing up off it ---

func _tend_haze(dt: float) -> void:
	var mm := _haze.multimesh
	var strength := clampf(look.glow * 0.9 + 0.1, 0.0, 1.6) * (0.5 + heat * 0.8) * (1.0 - murk * 0.8) + _flash * 0.5
	(_haze.material_override as ShaderMaterial).set_shader_parameter("tint", look.light_colour)
	(_haze.material_override as ShaderMaterial).set_shader_parameter("strength", minf(strength, 1.2) * 0.3)
	for i in _haze_cards.size():
		var c := _haze_cards[i]
		c.t += dt / c.life
		if c.t >= 1.0:
			c.t = 0.0
			c.seed = randf()
			c.x = randf_range(-0.25, 0.25)
		var h: float = 2.4 + 0.6 * c.t
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(1.9, h, 1.9)), Vector3(c.x, -0.05 + c.t * 0.3, 0)))
		mm.set_instance_custom_data(i, Color(c.seed, c.t, 0, 0))
		mm.set_instance_color(i, Color(1, 1, 1, 1))


## A card standing on its foot
static func _card_foot() -> Mesh:
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	q.center_offset = Vector3(0, 0.5, 0)
	return q


# --- what's been put in, bobbing about till it's cooked ---

## Something dropped in (a model, at a point local to the surface) stays bobbing on it
func float_in(model: String, at: Vector3) -> void:
	var node := Models.make(model)
	add_child(node)
	var p := Vector2(at.x, at.z).limit_length(0.55)
	_floaters.append({"node": node, "at": p, "vel": Vector2(randf_range(-0.2, 0.2), randf_range(-0.2, 0.2)),
			"phase": randf() * TAU, "spin": randf_range(-1.0, 1.0), "sink": 0.12, "gone": -1.0})
	node.position = Vector3(p.x, -0.12, p.y)


## How many things are bobbing in it
func floating() -> int:
	return _floaters.size()


## The fire's brought it to heat: the pot rattles, everything in it jiggles, then melts away
func cook() -> void:
	if _floaters.is_empty():
		return
	cooking = 1.7


## Everything bobbing in it gone at once (tipped out, bottled, a fresh pot)
func clear_floaters() -> void:
	for f in _floaters:
		if is_instance_valid(f.node):
			f.node.queue_free()
	_floaters.clear()
	cooking = 0.0


func _tend_floaters(dt: float) -> void:
	if cooking > 0.0:
		cooking -= dt
		if cooking <= 0.0:
			# Done: each one pops and melts into the brew
			for f in _floaters:
				f.gone = 0.0
				var p: Vector2 = f.at
				ripple(p, 0.9)
				_waves.foam(p, 0.8, 0.1)
				sparks(Vector3(p.x, 0, p.y), 6, look.sparkle_colour.lerp(look.foam, 0.5), 1.0)
			flash(0.8)
			bubble_burst(10, 1.6)
	var shake := 1.0 if cooking > 0.0 else 0.0
	var t := _clock
	for i in range(_floaters.size() - 1, -1, -1):
		var f := _floaters[i]
		var node: Node3D = f.node
		if f.gone >= 0.0:
			f.gone += dt
			var k: float = f.gone / 0.35
			node.scale = Vector3.ONE * 1.3 * maxf(0.0, 1.0 - k) * (1.0 + 0.5 * sin(k * PI))
			node.position.y -= dt * 0.3
			if k >= 1.0:
				node.queue_free()
				_floaters.remove_at(i)
			continue
		var p: Vector2 = f.at
		var r := p.length()
		# Carried round by the current, wandering, kept off the iron and off one another
		var round_v := Vector2(-p.y, p.x) * current * 0.9
		var push := Vector2.ZERO
		if r > 0.5:
			push -= p.normalized() * (r - 0.5) * 6.0
		for g in _floaters:
			if g != f and g.gone < 0.0:
				var d: Vector2 = p - g.at
				var dl := d.length()
				if dl < 0.16 and dl > 0.0001:
					push += d / dl * (0.16 - dl) * 8.0
		f.vel = (f.vel + (push + Vector2(sin(t * 0.7 + f.phase), cos(t * 0.6 + f.phase * 1.3)) * 0.05) * dt) * (1.0 - dt * 1.5)
		f.at = (p + (f.vel + round_v) * dt).limit_length(0.6)
		f.sink = move_toward(f.sink, 0.0, dt * 0.5)
		# Bobbing on the waves (riding the vortex's dip), jiggling, and jiggling hard while it cooks
		var rr: float = f.at.length() / RADIUS
		var y: float = _waves.height_at(f.at) + minf(current * current, 30.0) * 0.0022 * (rr * rr - 0.5) - f.sink
		var jig := 0.12 + 0.1 * heat + shake * 0.45
		var hop := shake * absf(sin(t * 19.0 + f.phase)) * 0.07
		node.position = Vector3(f.at.x, y - 0.045 + sin(t * 2.6 + f.phase) * 0.012 + hop, f.at.y)
		if randf() < dt * 4.0:
			_waves.foam(f.at, 0.25, 0.06)
		node.rotation = Vector3(sin(t * 7.0 + f.phase) * jig, node.rotation.y + dt * (f.spin + current * 0.6), sin(t * 6.1 + f.phase * 2.0) * jig)
		var sq := 1.0 + shake * 0.18 * sin(t * 24.0 + f.phase)
		node.scale = Vector3(1.0 / sqrt(sq), sq, 1.0 / sqrt(sq)) * 1.3
		# Bobbing, they set little rings going
		if randf() < dt * (1.0 + shake * 6.0):
			_waves.push(f.at, 0.0015 + shake * 0.0015, 0.05)


# --- bubbles: swell, then burst into a ring ---

func _add_bubble(size_k := 1.0) -> void:
	if _b.size() >= MAX_BUBBLES:
		return
	var a := randf() * TAU
	var r := sqrt(randf()) * 0.68
	# Half of them froth up along the iron, in clumps
	if randf() < 0.5:
		r = randf_range(0.66, 0.76) * pent(a)
		if randf() < 0.6 and _b.size() < MAX_BUBBLES - 2:
			for k in 2:
				var a2 := a + randf_range(-0.12, 0.12)
				var r2 := randf_range(0.64, 0.76) * pent(a2)
				_b.append({"at": Vector2(cos(a2), sin(a2)) * r2, "size": randf_range(0.03, 0.06) * look.bubble_size * size_k,
						"t": 0.0, "life": randf_range(0.5, 1.1) * (1.0 + look.thickness * 1.5)})
	var thick := look.thickness
	_b.append({"at": Vector2(cos(a), sin(a)) * r, "size": randf_range(0.035, 0.075) * look.bubble_size * size_k * (1.0 + thick * 0.8),
			"t": 0.0, "life": randf_range(0.45, 1.0) * (1.0 + thick * 1.5)})


func _tend_bubbles(dt: float) -> void:
	_bubble_due += dt * look.bubbles * (0.6 + heat * 5.0) * (1.0 - murk * 0.7)
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
			_waves.foam(b.at, 0.2, b.size)
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
	mm.use_custom_data = true
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


## How far out the pot's sides are at an angle round it (local x, z), as a share of RADIUS: it's a
## soft hexagon, a flat side to the front (as art/make_models.py makes the cauldron)
static func pent(angle: float) -> float:
	return 1.0 + 0.06 * cos(6.0 * angle)


## A disc of rings for the surface, fine enough to ripple, in the pot's soft pentagon
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
			var k0 := pent(a0)
			var k1 := pent(a1)
			var p := [Vector3(cos(a0) * r0 * k0, 0, sin(a0) * r0 * k0), Vector3(cos(a1) * r0 * k1, 0, sin(a1) * r0 * k1),
					Vector3(cos(a1) * r1 * k1, 0, sin(a1) * r1 * k1), Vector3(cos(a0) * r1 * k0, 0, sin(a0) * r1 * k0)]
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
