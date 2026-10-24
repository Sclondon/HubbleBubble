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
## Where the stick cuts the surface (x, z) and how hard it's going (0: not in it)
var stick_in := Vector3.ZERO
## How fast the stick's going through it (x, z, metres a second)
var stick_vel := Vector2.ZERO

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
var _rays: ShaderMaterial
var _spot: SpotLight3D
var _waves: Waves
var _sparks: MultiMeshInstance3D
var _b: Array[Dictionary] = []
var _s: Array[Dictionary] = []
var _clock := 0.0
## The waves' own clock: quicker the hotter it is
var _wave_clock := 0.0
## How far it's been worked up to its finish (Shop.finish_k), 0 when it isn't being
var finish := 0.0
var _bubble_due := 0.0
var _puff_due := 0.0
var _spark_due := 0.0
var _vents: Array[Vector2] = []
var _flash := 0.0
var _splashes: Array[Splash] = []
var _drops: MultiMeshInstance3D
var _drop_list: Array[Dictionary] = []
var _drop_bubbles: MultiMeshInstance3D
var _ring_fx: MultiMeshInstance3D
var _ring_list: Array[Dictionary] = []
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
	# The one light in the hut: the potion's own glow, from just over its surface, casting shadows (the
	# pot's own rim throws everything below it into the dark; the shelves, the ingredients and the
	# stick throw shadows up the walls). Not on the brew itself, nor on the smoke layer (a shadowed
	# light there stops the smoke camera drawing at all).
	_light = OmniLight3D.new()
	_light.name = "potion_light"
	_light.position = Vector3(0, 0.42, 0.1)
	_light.omni_range = 9.0
	_light.omni_attenuation = 0.9
	_light.shadow_enabled = true
	_light.shadow_bias = 0.05
	_light.shadow_normal_bias = 1.5
	_light.light_cull_mask = 0xFFFFF & ~2 & ~4
	add_child(_light)
	# God rays: shafts of the potion's light standing up out of the pot into the dark
	var cone := MeshInstance3D.new()
	cone.name = "god_rays"
	var cm := CylinderMesh.new()
	cm.top_radius = 1.9
	cm.bottom_radius = 0.72
	cm.height = 3.6
	cm.cap_top = false
	cm.cap_bottom = false
	cm.radial_segments = 32
	cm.rings = 1
	cone.mesh = cm
	cone.position = Vector3(0, 1.8, 0)
	_rays = ShaderMaterial.new()
	_rays.shader = preload("res://shaders/god_rays.gdshader")
	cone.material_override = _rays
	cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(cone)
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
	_glow_light.visible = false
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
	_spot.visible = false
	_sparks = _multi("sparks", _card(), preload("res://shaders/spark.gdshader"), MAX_SPARKS)
	# Drops of brew, flung out: little balls, moved here
	var dmm := MultiMesh.new()
	dmm.transform_format = MultiMesh.TRANSFORM_3D
	dmm.use_colors = true
	var ball := SphereMesh.new()
	ball.radius = 1.0
	ball.height = 2.0
	ball.radial_segments = 6
	ball.rings = 3
	dmm.mesh = ball
	dmm.instance_count = 64
	dmm.visible_instance_count = 0
	_drops = MultiMeshInstance3D.new()
	_drops.name = "drops"
	_drops.multimesh = dmm
	var dm := StandardMaterial3D.new()
	dm.vertex_color_use_as_albedo = true
	dm.roughness = 0.5
	_drops.material_override = dm
	_drops.custom_aabb = AABB(Vector3(-3, -2, -3), Vector3(6, 6, 6))
	add_child(_drops)
	_drop_bubbles = _multi("drop_bubbles", _dome(), preload("res://shaders/bubble.gdshader"), 24)
	# Little ring waves where drops land back in (flat cards on the surface)
	var flat_card := QuadMesh.new()
	flat_card.size = Vector2(1, 1)
	flat_card.orientation = PlaneMesh.FACE_Y
	_ring_fx = _multi("drop_rings", flat_card, preload("res://shaders/drop_ring.gdshader"), 40)
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
	if speed > 0.9 and randf() < (speed - 0.9) * 0.25:
		droplets(Vector3(at.x, 0, at.y), 1 + int(speed * 0.5), 0.6 + speed * 0.4)
	_wake.stick_at(at)
	_waves.push(at, clampf(0.006 + speed * 0.012, 0.0, 0.04), 0.055)
	_waves.foam(at, clampf(0.05 + speed * 0.12, 0.0, 0.35), 0.045)


## A splash where something dropped in (local), as big as `strength`
func splash(at: Vector3, strength := 1.0) -> void:
	var sp := _splashes[_next_splash]
	_next_splash = (_next_splash + 1) % _splashes.size()
	sp.start(Vector3(at.x, 0.0, at.z), strength, look)
	droplets(Vector3(at.x, 0.0, at.z), int(3 + 3 * strength), 1.2 + strength * 0.4)
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


## Drops of the brew flung out of it, arcing over and falling back (or over the rim onto the iron)
## What's flung out of the brew (a splash, the stick, a cooking pot), a few of each kind: blobs of
## brew, tiny dots, flecks of foam, and bubbles that drift down light. Each that falls back in leaves
## a little ripple as big as it is; off over the rim they're gone.
func droplets(at: Vector3, count: int, speed := 1.2) -> void:
	var col := look.liquid.lerp(look.foam, 0.2)
	for i in count:
		if _drop_list.size() >= 48:
			_drop_list.remove_at(0)
		var r := randf()
		var kind := "blob" if r < 0.3 else ("dot" if r < 0.6 else ("foam" if r < 0.82 else "bubble"))
		var size: float = {"blob": randf_range(0.01, 0.017), "dot": randf_range(0.005, 0.009), "foam": randf_range(0.012, 0.02), "bubble": randf_range(0.015, 0.025)}[kind]
		var go: float = speed * randf_range(0.5, 1.15) * (0.6 if kind == "bubble" else (1.2 if kind == "dot" else 1.0))
		var dir := Vector3(randf_range(-0.6, 0.6), 1.0, randf_range(-0.6, 0.6)).normalized()
		var c: Color = col if kind != "foam" else look.foam.lerp(Color.WHITE, 0.6)
		_drop_list.append({"at": Vector3(at.x, 0.02, at.z), "vel": dir * go, "col": c, "size": size, "kind": kind, "t": 0.0, "spin": randf() * TAU})


## A little ring wave spreading out from a point on the surface (local x, z), as big as the drop was
func ring_at(at: Vector2, size: float) -> void:
	if _ring_list.size() >= 40:
		_ring_list.remove_at(0)
	_ring_list.append({"at": at, "size": clampf(size * 9.0, 0.08, 0.22), "t": 0.0, "life": randf_range(0.7, 1.0)})


func _tend_rings(dt: float) -> void:
	var mm := _ring_fx.multimesh
	var shown := 0
	for i in range(_ring_list.size() - 1, -1, -1):
		_ring_list[i].t += dt
		if _ring_list[i].t >= _ring_list[i].life:
			_ring_list.remove_at(i)
	var col := look.foam.lerp(Color.WHITE, 0.5)
	for r in _ring_list:
		var k: float = r.t / r.life
		var at: Vector2 = r.at
		var sz: float = r.size * (0.6 + 1.4 * k)
		mm.set_instance_transform(shown, Transform3D(Basis().scaled(Vector3(sz, 1, sz)), Vector3(at.x, surface_at(at) + 0.012, at.y)))
		mm.set_instance_color(shown, Color(col, 1.0 - k))
		shown += 1
	mm.visible_instance_count = shown


func _tend_drops(dt: float) -> void:
	_tend_rings(dt)
	var mm := _drops.multimesh
	var bm := _drop_bubbles.multimesh
	var shown := 0
	var shown_b := 0
	for i in range(_drop_list.size() - 1, -1, -1):
		var d := _drop_list[i]
		d.t += dt
		# bubbles are light: they drift down slowly and wobble
		var fall: float = 2.0 if d.kind == "bubble" else (4.0 if d.kind == "foam" else 6.0)
		d.vel += Vector3(0, -fall, 0) * dt
		if d.kind != "blob" and d.kind != "dot":
			d.vel *= 1.0 - dt * 1.5
		d.at += d.vel * dt
		var flat := Vector2(d.at.x, d.at.z)
		if d.vel.y < 0.0 and d.at.y <= 0.0 and flat.length() < RADIUS * 0.95:
			# back in: a little ring as big as it was (foam leaves a fleck)
			ripple(flat, clampf(d.size * 14.0, 0.15, 0.5))
			ring_at(flat, d.size)
			if d.kind == "foam":
				_waves.foam(flat, 0.4, 0.04)
			_drop_list.remove_at(i)
		elif d.at.y < -1.4 or d.t > 3.0:
			_drop_list.remove_at(i)
	for d in _drop_list:
		var sz: float = d.size
		match d.kind:
			"bubble":
				bm.set_instance_transform(shown_b, Transform3D(Basis().scaled(Vector3.ONE * sz * (1.0 + 0.1 * sin(d.t * 15.0))), d.at))
				bm.set_instance_color(shown_b, Color(1, 1, 1, 1))
				shown_b += 1
			"foam":
				mm.set_instance_transform(shown, Transform3D(Basis(Vector3(0.3, 1, 0.2).normalized(), d.spin + d.t * 6.0).scaled(Vector3(sz, sz * 0.35, sz)), d.at))
				mm.set_instance_color(shown, d.col)
				shown += 1
			_:
				var stretch := 1.0 + minf(d.vel.length() * 0.4, 1.0)
				mm.set_instance_transform(shown, Transform3D(Basis().scaled(Vector3(sz, sz * stretch, sz)), d.at))
				mm.set_instance_color(shown, d.col)
				shown += 1
	mm.visible_instance_count = shown
	bm.visible_instance_count = shown_b


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
	var roll := smoothstep(0.62, 0.85, heat)
	_wave_clock += dt * (1.7 + heat * 1.6 + roll * 1.8)
	_mat.set_shader_parameter("clock", _wave_clock)
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
	# Roaring, it's a rolling boil: great domes heaving up all over and bursting, throwing up spray
	var rolls := dt * roll * 26.0
	while rolls > 0.0:
		if randf() < rolls:
			var a := randf() * TAU
			var r := sqrt(randf()) * 0.62
			var at := Vector2(cos(a), sin(a)) * r
			_waves.push(at, -randf_range(0.008, 0.016), randf_range(0.06, 0.1))
			_waves.foam(at, 0.35, 0.07)
			if randf() < 0.35:
				droplets(Vector3(at.x, 0, at.y), randi_range(1, 3), 0.9)
		rolls -= 1.0
	# Worked up to its finish: it brightens and swirls, golden sparks in it once it's just right,
	# and spitting if it's overworked
	if finish > 0.0:
		if finish >= 0.85 and finish <= 1.1 and randf() < dt * 30.0:
			var a := randf() * TAU
			var r := sqrt(randf()) * 0.5
			_add_spark(Vector3(cos(a) * r, 0.03, sin(a) * r), Vector3(randf_range(-0.2, 0.2), randf_range(0.8, 1.5), randf_range(-0.2, 0.2)), Color(1.0, 0.85, 0.35), randf_range(0.6, 1.1))
		elif finish > 1.1 and randf() < dt * 20.0:
			var a := randf() * TAU
			droplets(Vector3(cos(a) * 0.3, 0, sin(a) * 0.3), 2, 1.2)
	_tend_floaters(dt)
	# The potion's light flickers like a living thing (slow swells, a quicker shiver, a stutter now and
	# then) and sways about over the surface, so the shadows it throws creep and shift
	var flick := 0.8 + 0.1 * sin(_clock * 2.3) + 0.07 * sin(_clock * 6.7 + 1.0) + 0.05 * sin(_clock * 15.3) - 0.08 * maxf(0.0, sin(_clock * 0.9) * sin(_clock * 11.0))
	_light.position = Vector3(sin(_clock * 0.8) * 0.12 + sin(_clock * 2.1) * 0.04, 0.42 + sin(_clock * 1.3) * 0.06, 0.1 + cos(_clock * 0.7) * 0.1)
	_light.light_color = _saturate(look.light_colour, 1.5).lerp(Color(0.5, 0.4, 0.25), murk)
	_light.light_energy = 2.2 * (look.light_energy * (1.6 + heat * 2.2) * flick * (1.0 - murk * 0.6) + _flash * 3.0) * (0.4 + look.glow) * (1.0 + minf(finish, 1.2) * 0.7)
	_glow_light.light_color = _light.light_color
	_rays.set_shader_parameter("tint", look.light_colour)
	_rays.set_shader_parameter("strength", clampf((0.45 + look.glow * 0.45) * (0.8 + heat * 0.6) * (1.0 - murk * 0.7) * flick + _flash * 0.5, 0.0, 1.1))
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
	_cloud_due += dt * look.steam * (0.15 + heat * 1.2 + roll * 5.0) * (1.0 + murk)
	while _cloud_due >= 1.0:
		_cloud_due -= 1.0
		var ca := randf() * TAU
		var cr := randf_range(0.1, 0.55)
		_clouds.add(Vector3(cos(ca) * cr, 0.06, sin(ca) * cr), Color(look.steam_colour.lerp(Color(0.25, 0.2, 0.15), murk), 1.0), randf_range(0.25, 0.4))
	# Glowing tendrils curling up out of it, in its own colour
	_tendril_due += dt * (0.12 + heat * 0.35) * clampf(look.glow * 1.5 + 0.2, 0.0, 1.5) * (1.0 - murk)
	while _tendril_due >= 1.0:
		_tendril_due -= 1.0
		var a := randf() * TAU
		var r := randf_range(0.2, 0.6)
		_tendrils.add_tendril(Vector3(cos(a) * r, 0.02, sin(a) * r), Color(look.light_colour, 0.22))
	_tend_bubbles(dt)
	_tend_steam(dt)
	_waves.keep = lerpf(0.978, 0.95, thick())
	_waves.speed = lerpf(0.36, 0.2, thick())
	_waves.rate = 1.3 + heat * 0.6 + roll * 0.5
	_waves.update(dt)
	_tend_sparks(dt)
	_tend_drops(dt)


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
## How well each thing floats (see _float_body): toadstools and scales sit low, wings ride high
const BUOY := {"one_shroom": 1.6, "one_scale": 1.6, "one_eye": 2.0, "one_leg": 1.9, "one_spider": 2.0, "one_pepper": 1.8, "one_petal": 2.6, "one_wing": 2.6}


func float_in(model: String, at: Vector3) -> void:
	var node := Models.make(model)
	add_child(node)
	node.scale = Vector3.ONE * 1.3
	var p := Vector2(at.x, at.z).limit_length(0.55)
	# A body that floats: where it is and how it's going, which way up it is and how it's turning, and
	# the points on it the brew pushes up on (round its middle, a little apart, so it tips and rolls)
	var box := _bounds(node)
	var size := box.size
	# (the model is moved so the middle of it is its centre: it turns about that)
	for c in node.get_children():
		if c is Node3D:
			(c as Node3D).position -= box.get_center() / node.scale
	var pts: Array[Vector3] = []
	for k in 8:
		pts.append(Vector3((-0.45 if k & 1 else 0.45) * size.x, (-0.45 if k & 2 else 0.45) * size.y, (-0.45 if k & 4 else 0.45) * size.z))
	_floaters.append({"node": node, "at": p, "pos": Vector3(p.x, 0.05, p.y), "vel": Vector3(randf_range(-0.2, 0.2), -1.2, randf_range(-0.2, 0.2)),
			"rot": Basis(Vector3(randf(), randf(), randf()).normalized(), randf_range(0.0, PI)), "spin": Vector3(randf_range(-6, 6), randf_range(-3, 3), randf_range(-6, 6)),
			"pts": pts, "size": maxf(size.x, maxf(size.y, size.z)), "buoy": BUOY.get(model, 1.9), "phase": randf() * TAU, "gone": -1.0})
	node.position = Vector3(p.x, 0.05, p.y)


## A look with its colours pushed richer (the brews read strongly in the dark)
static func _vivid(l: PotionLook) -> PotionLook:
	var v: PotionLook = l.duplicate()
	v.liquid = _saturate(l.liquid, 1.6)
	v.deep = _saturate(l.deep, 1.6)
	v.foam = _saturate(l.foam, 1.3)
	v.light_colour = _saturate(l.light_colour, 1.5)
	v.bubble_colour = _saturate(l.bubble_colour, 1.4)
	return v


static func _saturate(c: Color, k: float) -> Color:
	var o := c
	o.s = clampf(c.s * k + (0.15 if c.s > 0.05 else 0.0), 0.0, 1.0)
	return o


## One drop of cold water falling into the pot from the pipe
func water_drop(at: Vector3) -> void:
	for i in 2:
		if _drop_list.size() >= 48:
			_drop_list.remove_at(0)
		_drop_list.append({"at": at + Vector3(randf_range(-0.02, 0.02), 0, randf_range(-0.02, 0.02)), "vel": Vector3(0, -0.5, 0), "col": Color(0.55, 0.75, 0.7), "size": randf_range(0.01, 0.016), "kind": "blob", "t": 0.0, "spin": 0.0})
	_waves.foam(Vector2(at.x, at.z), 0.3, 0.06)


## One drop of the brew falling out of the tap (a point local to the surface)
func pour_drop(at: Vector3) -> void:
	if randf() > 0.6:
		return
	if _drop_list.size() >= 48:
		_drop_list.remove_at(0)
	_drop_list.append({"at": at, "vel": Vector3(randf_range(-0.05, 0.05), -0.2, 0.25), "col": look.liquid, "size": randf_range(0.01, 0.016), "kind": "blob", "t": 0.0, "spin": 0.0})


## How bright its light is now (0 to about 1): for the little lights on the shelf to follow
func light_now() -> float:
	return clampf(_light.light_energy / 6.0, 0.15, 1.2)


## How thick it is, 0 to 1: every brew is a gloopy one, thicker still if its look says so
func thick() -> float:
	return lerpf(0.55, 1.0, look.thickness)


## Where a model is (its bounds in the model's own space, as it will be drawn)
static func _bounds(node: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		var b := node.global_transform.affine_inverse() * mi.global_transform * mi.get_aabb() if node.is_inside_tree() else mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	box.position *= node.scale
	box.size = (box.size * node.scale).max(Vector3.ONE * 0.04)
	return box


## How high the brew stands at a point (local x, z): its waves, its swell and its stirred dip, as the
## surface shader moves it
func surface_at(p: Vector2) -> float:
	var slow := lerpf(1.0, 0.45, thick())
	var boil := clampf(heat * 1.3 - 0.2, 0.0, 1.0)
	var a := 0.02 + 0.045 * boil
	var t := _wave_clock
	var h := 0.028 * sin(p.dot(Vector2(0.6, 0.8)) * 4.2 - t * 1.3 * slow) + a * (sin(p.dot(Vector2(0.96, 0.28)) * 9.0 + t * 2.1 * slow) + 0.6 * sin(p.dot(Vector2(-0.37, 0.93)) * 13.0 - t * 2.7 * slow) + 0.35 * sin(p.dot(Vector2(0.66, -0.75)) * 19.0 + t * 3.4 * slow))
	var rr := p.length() / RADIUS
	return h + _waves.height_at(p) + minf(current * current, 30.0) * 0.0022 * (rr * rr - 0.5)


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


## Tells the surface where things sit in it, for their collars of foam (the floaters, and the stick)
func _send_bodies() -> void:
	var list: Array[Vector4] = []
	for f in _floaters:
		if f.gone < 0.0:
			list.append(Vector4(f.at.x, f.at.y, 0.085, 1.0 if cooking > 0.0 else 0.3))
	if stick_in.z > 0.0:
		list.append(Vector4(stick_in.x, stick_in.y, 0.03, stick_in.z))
	var n := list.size()
	var packed := PackedVector4Array()
	for i in 10:
		packed.append(list[i] if i < n else Vector4.ZERO)
	_mat.set_shader_parameter("bodies", packed)
	_mat.set_shader_parameter("body_count", mini(n, 10))


func _tend_floaters(dt: float) -> void:
	_send_bodies()
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
		_float_body(f, dt, shake)
		var node_s := 1.0 + shake * 0.15 * sin(t * 24.0 + f.phase)
		node.scale = Vector3(1.0 / sqrt(node_s), node_s, 1.0 / sqrt(node_s)) * 1.3
		if randf() < dt * 4.0:
			_waves.foam(f.at, 0.25, 0.06)
		if randf() < dt * (1.0 + shake * 6.0):
			_waves.push(f.at, 0.0015 + shake * 0.0015, 0.05)


## One floating body stepped on: gravity down; at each of its points under the surface, the brew
## pushes up (more the deeper it is) and drags; the push off-centre tips it over, so it rolls and
## tumbles on the waves. The current carries it round, the iron and the others push it off.
func _float_body(f: Dictionary, dt: float, shake: float) -> void:
	var steps := 3
	var h := dt / steps
	for step in steps:
		var pos: Vector3 = f.pos
		var vel: Vector3 = f.vel
		var rot: Basis = f.rot
		var spin: Vector3 = f.spin
		var force := Vector3(0, -9.8, 0)
		var torque := Vector3.ZERO
		var pts: Array = f.pts
		var under := 0
		for lp: Vector3 in pts:
			var arm := rot * lp
			var wp := pos + arm
			var depth := surface_at(Vector2(wp.x, wp.z)) - wp.y
			if depth > 0.0:
				under += 1
				var point_vel := vel + spin.cross(arm)
				# Pushed up by how deep this point is, as a share of the thing's size: wholly under, the
				# brew lifts it with `buoy` times its weight (2: floats half out; under 1.3, sits low)
				var under_k := clampf(depth / maxf(f.size * 0.12, 0.01), 0.0, 1.0)
				var push := Vector3(0, under_k * 9.8 * f.buoy / pts.size(), 0) - point_vel * (6.0 / pts.size())
				force += push
				torque += arm.cross(push)
		# The current carries it round; stirred, it tumbles more
		var flat := Vector2(pos.x, pos.z)
		var round_v := Vector3(-flat.y, 0, flat.x) * current * 0.9
		if under > 0:
			force += (round_v - Vector3(vel.x, 0, vel.z)) * 2.5
		# Off the iron and the others
		var r := flat.length()
		var wall := 0.6 * pent(flat.angle())
		if r > wall:
			force -= Vector3(flat.x, 0, flat.y).normalized() * (r - wall) * 60.0
		for g in _floaters:
			if g != f and g.gone < 0.0:
				var d: Vector3 = pos - g.pos
				d.y *= 0.5
				var dl := d.length()
				var gap: float = (f.size + g.size) * 0.4
				if dl < gap and dl > 0.0001:
					force += d / dl * (gap - dl) * 80.0
		# The stick: a post standing in the brew where it cuts the surface; things are shoved off it,
		# and knocked along the way it's going
		if stick_in.z > 0.0:
			var sd := Vector2(pos.x, pos.z) - Vector2(stick_in.x, stick_in.y)
			var reach: float = f.size * 0.45 + 0.04
			var sl := sd.length()
			if sl < reach and sl > 0.0001:
				var out := sd / sl
				force += Vector3(out.x, 0.0, out.y) * (reach - sl) * 260.0
				var sv := Vector3(stick_vel.x, 0, stick_vel.y)
				force += sv * 4.0
				# (only a lazy roll: the thick brew soon stops it)
				spin += Vector3(out.y, 0, -out.x) * minf(sv.length(), 1.5) * 0.5 * h * 60.0
		# Cooking: kicked about
		if shake > 0.0 and randf() < h * 3.0:
			droplets(Vector3(pos.x, 0, pos.z), 2, 1.1)
		if shake > 0.0 and randf() < h * 8.0:
			vel += Vector3(randf_range(-0.3, 0.3), randf_range(0.4, 0.9), randf_range(-0.3, 0.3))
			spin += Vector3(randf_range(-10, 10), randf_range(-5, 5), randf_range(-10, 10))
		vel += force * h
		vel *= 1.0 - h * (0.4 + (3.0 * thick() if under > 0 else 0.0))
		spin += torque * 900.0 * h / maxf(f.size * f.size * 40.0, 0.2) / 40.0
		spin *= 1.0 - h * (4.5 if under > 0 else 0.3)
		spin = spin.limit_length(5.0)
		pos += vel * h
		# never through the iron: held inside it, and what was going outward stopped
		var fl := Vector2(pos.x, pos.z)
		var most: float = RADIUS * 0.92 * pent(fl.angle()) - f.size * 0.35
		if fl.length() > most:
			var n_out := fl.normalized()
			fl = n_out * most
			pos.x = fl.x
			pos.z = fl.y
			var vout := vel.x * n_out.x + vel.z * n_out.y
			if vout > 0.0:
				vel.x -= n_out.x * vout * 1.4
				vel.z -= n_out.y * vout * 1.4
		pos.y = minf(pos.y, 0.5)
		if spin.length() > 0.0001:
			rot = Basis(spin.normalized(), spin.length() * h) * rot
		f.pos = pos
		f.vel = vel
		f.rot = rot.orthonormalized()
		f.spin = spin
	f.at = Vector2(f.pos.x, f.pos.z)
	var node: Node3D = f.node
	node.position = f.pos
	node.basis = f.rot


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
	var thick := thick()
	_b.append({"at": Vector2(cos(a), sin(a)) * r, "size": randf_range(0.035, 0.075) * look.bubble_size * size_k * (1.0 + thick * 0.8),
			"t": 0.0, "life": randf_range(0.45, 1.0) * (1.0 + thick * 1.5)})


func _tend_bubbles(dt: float) -> void:
	_bubble_due += dt * (look.bubbles * (0.6 + heat * 5.0) + smoothstep(0.62, 0.85, heat) * 30.0) * (1.0 - murk * 0.7)
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
			ring_at(b.at, b.size * 0.6)
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
	_puff_due += dt * look.steam * (0.3 + heat + smoothstep(0.62, 0.85, heat) * 4.0) * 1.6 * (1.0 - murk * 0.5)
	while _puff_due >= 1.0:
		_puff_due -= 1.0
		var v := _vents[randi() % _vents.size()]
		var sc := look.steam_colour
		_streamers.add(Vector3(v.x + randf_range(-0.08, 0.08), 0.02, v.y + randf_range(-0.08, 0.08)), Color(sc, minf(0.45, sc.a * 0.8)))


# --- sparkles fizzing up ---

func _add_spark(at: Vector3, vel: Vector3, col: Color, life: float) -> void:
	if _s.size() >= MAX_SPARKS:
		_s.remove_at(0)
	_s.append({"at": at, "vel": vel, "col": col, "t": 0.0, "life": life})


func _tend_sparks(dt: float) -> void:
	_spark_due += dt * look.sparkles * (0.5 + heat + smoothstep(0.62, 0.85, heat) * 5.0) * 7.0
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
	l = _vivid(l)
	_mat.set_shader_parameter("liquid", l.liquid)
	_mat.set_shader_parameter("deep", l.deep)
	_mat.set_shader_parameter("foam", l.foam)
	_mat.set_shader_parameter("glow", l.glow)
	_mat.set_shader_parameter("lines", l.lines)
	_mat.set_shader_parameter("glints", l.glints)
	_mat.set_shader_parameter("shine", l.shine)
	_mat.set_shader_parameter("thickness", lerpf(0.55, 1.0, l.thickness))
	_mat.set_shader_parameter("swirl", l.swirl)
	_mat.set_shader_parameter("opacity", l.opacity)
	var bm := _bubbles.material_override as ShaderMaterial
	bm.set_shader_parameter("tint", l.bubble_colour)
	bm.set_shader_parameter("opacity", l.bubble_opacity)
	bm.set_shader_parameter("shine", l.bubble_shine)
	var dbm := _drop_bubbles.material_override as ShaderMaterial
	dbm.set_shader_parameter("tint", l.bubble_colour)
	dbm.set_shader_parameter("opacity", l.bubble_opacity)


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
