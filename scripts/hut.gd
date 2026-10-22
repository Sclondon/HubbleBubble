class_name Hut
extends Node3D
## Grumblewart's hut: stone walls, a plank floor, shelves of jars, the serving window with the night
## outside it (the moon crossing it is the clock), and the cauldron on its fire in the middle.

const STONE := Color("8a7aa6")
const STONE_D := Color("4f4168")
const WOOD := Color("a8683a")
const WOOD_D := Color("6b3e22")
const PLANK := Color("8f5b33")
const PLANK_D := Color("5e3820")
const IRON := Color("3a3346")
const IRON_L := Color("5d5470")

## Where the serving window's customer stands
const WINDOW_SPOT := Vector3(0, 0.3, -3.45)
## About where a customer's face is
const WINDOW_HEAD := Vector3(0, 2.0, -3.3)
const CAULDRON_RIM := 1.36
const BREW_LEVEL := 1.24
const BREW_R := 0.8
## The table stands between the pot and the serving window
const TABLE := Vector3(0, 0, -1.55)
## The room was built with its window off to one side: it's moved over so the window is in the middle
const ROOM_SHIFT := -1.05
const INGREDIENT_MODELS := ["ing_eye", "ing_shroom", "ing_wing", "ing_leg", "ing_spider", "ing_petal", "ing_pepper", "ing_scale"]

## Things that can be tapped: id -> node, and id -> {at: where, r: how big}
var props := {}
var spots := {}
var stick: Node3D
var _bellows_top: Node3D
var _squeeze := 0.0
var _pokes := {}
var _prop_scale := {}
## The stirring stick: how far round it's been dragged, and whether it's going
var stir_angle := 0.0
var stirring := false
var _stick_angle := 0.0
var _wand_t := 9.0
var _wand: Node3D

var brew_mat: ShaderMaterial
var brew_disc: MeshInstance3D
var moon: Node3D
var fire: Node3D
var flames: Array[MeshInstance3D] = []
var fire_mats: Array[ShaderMaterial] = []
var bubbles: CPUParticles3D
var _bubble_mat: ShaderMaterial
var steam: CPUParticles3D
var splash: CPUParticles3D
var sparkle: CPUParticles3D
var smoke: CPUParticles3D
var wisps: CPUParticles3D
var embers: CPUParticles3D
var big_bubbles: CPUParticles3D
var _ripples := [Vector4.ZERO, Vector4.ZERO, Vector4.ZERO, Vector4.ZERO]
var _next_ripple := 0
var _glow := 0.0
var _last_col := Book.WATER
var heat := 0.0
var brew_col := Book.WATER
var _shown_col := Book.WATER
var _murk := 0.0
var _spin := 0.0
var _rng := RandomNumberGenerator.new()
var _candles: Array[MeshInstance3D] = []
var _night_t := 0.0


func _ready() -> void:
	_rng.seed = 7
	_room()
	_window()
	_shelves()
	_bits()
	for child in get_children():
		if child is Node3D:
			(child as Node3D).position.x += ROOM_SHIFT
	_cauldron()
	_table()


func _process(dt: float) -> void:
	_animate_props(dt)
	_animate_stick(dt)
	_animate_wand(dt)
	var t := Time.get_ticks_msec() / 1000.0
	# The fire leaps with the heat; its light on everything follows
	var h := heat / 100.0
	for i in flames.size():
		var f := flames[i]
		var wob := 0.75 + 0.25 * sin(t * (9.0 + i * 1.7) + i * 2.1)
		f.scale = Vector3(0.7 + h * 0.6, (0.35 + h * 1.25) * wob, 0.7 + h * 0.6)
	for m in fire_mats:
		m.set_shader_parameter("strength", 0.55 + h * 0.8)
	var flick := 0.85 + 0.15 * sin(t * 13.0) * sin(t * 7.3)
	var fire_col := Color("9cf05a").lerp(Color("ffb040"), clampf(h * 1.2 - 0.2, 0.0, 1.0))
	Shape.set_all("lamp_col", Shape.lin3(fire_col) * (0.45 + h * 1.4) * flick)
	for c in _candles:
		c.scale = Vector3.ONE * (0.9 + 0.12 * sin(t * 11.0 + c.position.x * 5.0))
	# The brew catches up with its colour, and turns murky when spoilt
	_shown_col = _shown_col.lerp(brew_col, minf(1.0, dt * 3.0))
	brew_mat.set_shader_parameter("colour", Shape.lin3(_shown_col))
	brew_mat.set_shader_parameter("murk", _murk)
	brew_mat.set_shader_parameter("spin", _spin)
	_glow = maxf(0.0, _glow - dt * 1.2)
	brew_mat.set_shader_parameter("glow", _glow)
	brew_mat.set_shader_parameter("boil", clampf(h * 1.3 - 0.15, 0.0, 1.0))
	brew_mat.set_shader_parameter("now", t)
	brew_mat.set_shader_parameter("colour2", Shape.lin3(_last_col.lerp(_shown_col, 0.2)))
	bubbles.scale_amount_max = 0.8 + h * 1.4
	bubbles.speed_scale = 0.6 + h * 1.4
	var bm := _bubble_mat
	(bm as ShaderMaterial).set_shader_parameter("colour", Shape.lin3(_shown_col.lightened(0.35)))
	steam.emitting = h > 0.3
	brew_disc.position.y = BREW_LEVEL + h * 0.03


## How far the stirring has turned the brew (radians)
func stir_to(angle: float) -> void:
	_spin = angle


func set_brew(col: Color, murky := false) -> void:
	brew_col = col
	_murk = 1.0 if murky else 0.0


## Clean water again, at once
func fresh() -> void:
	brew_col = Book.WATER
	_shown_col = Book.WATER
	_murk = 0.0


func plop(col: Color) -> void:
	_burst(splash, col.lightened(0.2))
	ripple(Vector3(randf_range(-0.2, 0.2), 0, randf_range(-0.2, 0.2)), 0.8)


func zap() -> void:
	react("zap", _shown_col, 1.0)


func poof() -> void:
	_burst(smoke, Color("4a4038"))
	_burst(wisps, Color("2a2420"), 20, 0.8)
	ripple(Vector3.ZERO, 1.5)


## Where the moon is, 0 at the start of the night to 1 at the end
func night_progress(t: float) -> void:
	_night_t = t
	moon.position = Vector3(lerpf(-0.65, 2.75, t) + ROOM_SHIFT, 2.45 + sin(t * PI) * 0.75, -4.6)




func _room() -> void:
	# Plank floor
	var floor_s := Shape.new()
	for i in 14:
		var x := -7.0 + i * 1.0
		var shade := PLANK.lerp(PLANK_D, _rng.randf_range(0.0, 0.45))
		floor_s.box(Vector3(x + 0.5, -0.05, 0.5), Vector3(0.96, 0.1, 9.0), shade, shade.darkened(0.3))
	add_child(floor_s.piece("floor"))
	# Back wall of uneven stones, with the window hole cut out
	var wall := Shape.new()
	var hole := Rect2(-0.05, 1.45, 2.2, 2.15)
	for row in 12:
		var y := row * 0.5
		var x := -7.5 + (0.45 if row % 2 else 0.0)
		while x < 7.5:
			var w := _rng.randf_range(0.7, 1.15)
			var centre := Vector2(x + w * 0.5, y + 0.25)
			if not hole.grow(0.15).has_point(centre):
				var shade := STONE.lerp(STONE_D, _rng.randf_range(0.0, 0.55))
				wall.box(Vector3(centre.x, centre.y, -3.0 + _rng.randf_range(-0.04, 0.04)), Vector3(w - 0.06, 0.44, 0.3), shade.lightened(0.08), shade)
			x += w
	add_child(wall.piece("wall"))
	# Dark mortar behind the stones (with the same hole)
	var mortar := Shape.new()
	mortar.box(Vector3(-3.85, 3.0, -3.12), Vector3(7.5, 6.0, 0.05), STONE_D.darkened(0.5))
	mortar.box(Vector3(5.12, 3.0, -3.12), Vector3(5.6, 6.0, 0.05), STONE_D.darkened(0.5))
	mortar.box(Vector3(1.05, 0.65, -3.12), Vector3(2.6, 1.3, 0.05), STONE_D.darkened(0.5))
	mortar.box(Vector3(1.05, 4.8, -3.12), Vector3(2.6, 2.4, 0.05), STONE_D.darkened(0.5))
	add_child(mortar.piece("mortar"))
	# Side walls, angled in, and beams overhead
	for sgn: float in [-1.0, 1.0]:
		var side := Shape.new()
		for row in 12:
			for k in 8:
				var shade := STONE.lerp(STONE_D, _rng.randf_range(0.2, 0.8))
				side.box(Vector3(sgn * 4.2, row * 0.5 + 0.25, -2.6 + k * 1.0 + (0.5 if row % 2 else 0.0)), Vector3(0.3, 0.44, 0.94), shade, shade.darkened(0.15))
		add_child(side.piece("side"))
	var beams := Shape.new()
	for i in 4:
		beams.box(Vector3(0, 4.6, -2.4 + i * 1.6), Vector3(9.0, 0.3, 0.3), WOOD_D, WOOD_D.darkened(0.3))
	beams.box(Vector3(0, 4.3, -2.75), Vector3(9.0, 0.25, 0.25), WOOD, WOOD_D)
	add_child(beams.piece("beams"))


func _window() -> void:
	# The night outside: a sky card, hills, a crooked tree and the moon
	var sky := Shape.new()
	var top := Color("1b1450")
	var low := Color("5a3a8a")
	var k1 := low.srgb_to_linear()
	var k2 := top.srgb_to_linear()
	var z := -5.2
	var corners := [Vector3(-2.0, 1.0, z), Vector3(4.0, 1.0, z), Vector3(4.0, 5.0, z), Vector3(-2.0, 5.0, z)]
	sky._quad(corners, [Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK], [k1, k1, k2, k2])
	add_child(sky.piece("sky", Shape.mat(1.0)))
	var stars := Shape.new()
	for i in 40:
		var p := Vector3(_rng.randf_range(-1.5, 3.6), _rng.randf_range(2.2, 4.8), -5.15)
		var s := _rng.randf_range(0.015, 0.04)
		stars.ball(p, Vector3(s, s, s), Color("fff6c8"), null, 4, 3)
	add_child(stars.piece("stars", Shape.mat(1.0)))
	var hills := Shape.new()
	hills.ball(Vector3(-0.3, 1.0, -4.9), Vector3(1.8, 0.95, 0.3), Color("2e2a5c"), Color("1c1838"), 14, 6)
	hills.ball(Vector3(2.6, 0.9, -4.95), Vector3(2.2, 1.1, 0.3), Color("272352"), Color("1c1838"), 14, 6)
	hills.bend([Vector3(2.3, 1.7, -4.7), Vector3(2.35, 2.3, -4.7), Vector3(2.2, 2.8, -4.7), Vector3(1.9, 3.05, -4.7)], 0.07, 0.025, Color("161230"))
	hills.bend([Vector3(2.32, 2.35, -4.7), Vector3(2.6, 2.6, -4.7), Vector3(2.75, 2.95, -4.7)], 0.04, 0.015, Color("161230"))
	add_child(hills.piece("hills", Shape.mat(0.6)))
	moon = Node3D.new()
	moon.name = "moon"
	var m := Shape.new().ball(Vector3.ZERO, Vector3(0.33, 0.33, 0.1), Color("fff2b0"), Color("f0d070"), 14, 8)
	m.ball(Vector3(0.1, 0.08, 0.06), Vector3(0.07, 0.07, 0.05), Color("e6d48a"), null, 6, 4)
	m.ball(Vector3(-0.12, -0.1, 0.06), Vector3(0.05, 0.05, 0.04), Color("e6d48a"), null, 6, 4)
	moon.add_child(m.piece("moon", Shape.mat(1.0)))
	add_child(moon)
	night_progress(0.0)
	# The frame and the counter the customers lean on
	var frame := Shape.new()
	var x0 := -0.05
	var x1 := 2.15
	frame.box(Vector3(1.05, 1.42, -2.75), Vector3(2.7, 0.18, 0.9), WOOD.lightened(0.1), WOOD_D)
	frame.box(Vector3(1.05, 1.0, -2.36), Vector3(2.6, 0.7, 0.08), WOOD, WOOD_D)
	for k in 5:
		frame.box(Vector3(-0.1 + k * 0.58, 1.0, -2.31), Vector3(0.06, 0.66, 0.03), WOOD_D, WOOD_D)
	frame.box(Vector3(x0 - 0.06, 2.55, -2.85), Vector3(0.22, 2.3, 0.4), WOOD, WOOD_D)
	frame.box(Vector3(x1 + 0.06, 2.55, -2.85), Vector3(0.22, 2.3, 0.4), WOOD, WOOD_D)
	frame.box(Vector3(1.05, 3.68, -2.85), Vector3(2.5, 0.24, 0.4), WOOD, WOOD_D)
	# Shutters open either side
	for sgn: float in [-1.0, 1.0]:
		var sx := 1.05 + sgn * 1.7
		frame.box(Vector3(sx, 2.55, -2.72), Vector3(1.0, 2.0, 0.08), Color("4f8a3a"), Color("35602a"), Basis(Vector3.UP, sgn * 0.5))
		frame.box(Vector3(sx, 2.55, -2.66), Vector3(0.8, 0.12, 0.06), WOOD_D, WOOD_D, Basis(Vector3.UP, sgn * 0.5))
	# A little sign over it
	frame.box(Vector3(1.05, 4.05, -2.8), Vector3(1.3, 0.42, 0.08), Color("e8c06a"), WOOD_D)
	add_child(frame.piece("frame"))
	var sign := Label3D.new()
	sign.text = "POTIONS"
	sign.font = load("res://fonts/Fredoka.ttf")
	sign.font_size = 64
	sign.outline_size = 0
	sign.modulate = Color("5a2a12")
	sign.pixel_size = 0.004
	sign.position = Vector3(1.05, 4.05, -2.75)
	sign.shaded = false
	add_child(sign)


func _shelves() -> void:
	var s := Shape.new()
	var jar_cols := [Color("e8473a"), Color("5fd6c4"), Color("8a52c9"), Color("86d84a"), Color("ffa22e"), Color("a8c8ff"), Color("ffc4e4"), Color("f4e04a")]
	for row in 3:
		var y := 1.3 + row * 0.95
		s.box(Vector3(-2.6, y, -2.6), Vector3(2.6, 0.1, 0.55), WOOD.lightened(0.05), WOOD_D)
		s.tube(Vector3(-3.6, y - 0.05, -2.45), Vector3(-3.6, y - 0.35, -2.75), 0.04, 0.04, WOOD_D)
		s.tube(Vector3(-1.6, y - 0.05, -2.45), Vector3(-1.6, y - 0.35, -2.75), 0.04, 0.04, WOOD_D)
		var x := -3.75
		while x < -1.5:
			var col: Color = jar_cols[_rng.randi() % jar_cols.size()]
			var h := _rng.randf_range(0.25, 0.48)
			var r := _rng.randf_range(0.1, 0.17)
			x += r + 0.03
			if _rng.randf() < 0.7:
				s.tube(Vector3(x, y + 0.05, -2.55), Vector3(x, y + 0.05 + h, -2.55), r, r * 0.9, col.darkened(0.2), col.lightened(0.2), 8)
				s.tube(Vector3(x, y + 0.05 + h, -2.55), Vector3(x, y + 0.12 + h, -2.55), r * 0.55, r * 0.55, Color("c89a5a"), null, 6)
			else:
				s.ball(Vector3(x, y + 0.05 + r * 1.1, -2.55), Vector3(r * 1.2, r * 1.1, r * 1.2), col.lightened(0.2), col.darkened(0.25), 8, 5)
				s.tube(Vector3(x, y + 0.05 + r * 2.0, -2.55), Vector3(x, y + 0.05 + r * 2.6, -2.55), r * 0.35, r * 0.3, col.darkened(0.1), null, 6)
				s.ball(Vector3(x, y + 0.05 + r * 2.7, -2.55), Vector3(r * 0.4, r * 0.25, r * 0.4), Color("c89a5a"), null, 6, 3)
			x += r + 0.05
	# A skull with a candle on it, books, a spiderweb corner
	s.ball(Vector3(-2.0, 3.36, -2.5), Vector3(0.17, 0.15, 0.16), Color("f2ead2"), Color("c8bc98"), 10, 6)
	s.ball(Vector3(-2.06, 3.36, -2.36), Vector3(0.04, 0.05, 0.02), Color("201820"), null, 6, 4)
	s.ball(Vector3(-1.94, 3.36, -2.36), Vector3(0.04, 0.05, 0.02), Color("201820"), null, 6, 4)
	s.tube(Vector3(-2.0, 3.48, -2.5), Vector3(-2.0, 3.72, -2.5), 0.05, 0.05, Color("f4ecd0"))
	for i in 4:
		var bc: Color = [Color("8a2a2a"), Color("2a5a8a"), Color("3a7a3a"), Color("7a4a8a")][i]
		s.box(Vector3(-3.35 + i * 0.13, 3.43, -2.55), Vector3(0.11, 0.55 - i * 0.04, 0.38), bc.lightened(0.1), bc)
	add_child(s.piece("shelves"))
	_candles.append(_candle_flame(Vector3(-2.0, 3.78, -2.5)))
	# On the right: a broom and a barrel
	var r := Shape.new()
	r.tube(Vector3(3.3, 0.0, -2.2), Vector3(3.3, 0.85, -2.2), 0.45, 0.48, WOOD, WOOD.lightened(0.1), 12)
	r.ring(Vector3(3.3, 0.2, -2.2), 0.46, 0.04, IRON_L, 14, 4)
	r.ring(Vector3(3.3, 0.7, -2.2), 0.48, 0.04, IRON_L, 14, 4)
	r.disc(Vector3(3.3, 0.86, -2.2), Vector2(0.46, 0.46), WOOD_D, 12)
	r.tube(Vector3(2.6, 0.0, -2.5), Vector3(2.35, 2.4, -2.75), 0.04, 0.04, WOOD_D)
	r.tube(Vector3(2.62, 0.45, -2.48), Vector3(2.66, -0.02, -2.46), 0.08, 0.26, Color("d9b24a"), Color("a8822a"), 8)
	r.ring(Vector3(2.62, 0.42, -2.48), 0.09, 0.03, Color("8a2a2a"), 8, 4)
	add_child(r.piece("broom"))


func _bits() -> void:
	# Herbs and garlic hanging off the beams
	var s := Shape.new()
	for i in 6:
		var x := -3.4 + i * 1.25 + _rng.randf_range(-0.2, 0.2)
		if absf(x - 1.0) < 1.4:
			continue
		var zz := -2.2 + _rng.randf_range(-0.3, 0.8)
		var drop := _rng.randf_range(0.5, 1.0)
		s.tube(Vector3(x, 4.5, zz), Vector3(x, 4.5 - drop, zz), 0.012, 0.012, Color("d8c8a0"), null, 4)
		if i % 2 == 0:
			for k in 5:
				var a := TAU * k / 5.0
				s.tube(Vector3(x, 4.5 - drop, zz), Vector3(x + cos(a) * 0.14, 4.5 - drop - 0.45, zz + sin(a) * 0.14), 0.04, 0.01, Color("5f9a3a"), Color("3a6a2a"), 4)
		else:
			s.ball(Vector3(x, 4.5 - drop - 0.12, zz), Vector3(0.14, 0.13, 0.14), Color("f4ecd8"), Color("c8b898"), 8, 5)
			s.ball(Vector3(x + 0.15, 4.5 - drop - 0.22, zz), Vector3(0.12, 0.11, 0.12), Color("f4ecd8"), Color("c8b898"), 8, 5)
	# Cobwebs in the top corners
	for sgn: float in [-1.0, 1.0]:
		var corner := Vector3(sgn * 4.0, 4.45, -2.85)
		for k in 5:
			var a := PI * 0.5 + sgn * (PI * 0.5) + (-sgn) * k * (PI * 0.5) / 4.0
			s.tube(corner, corner + Vector3(cos(a) * 1.0 * -1.0, -absf(sin(a)) * 1.0, 0.05), 0.008, 0.008, Color("d8d8e8"), null, 3)
	add_child(s.piece("hanging"))


func _candle_flame(at: Vector3) -> MeshInstance3D:
	var f := Shape.new()
	f.ball(Vector3(0, 0.08, 0), Vector3(0.05, 0.1, 0.05), Color(1, 0.85, 0.35, 0.9), Color(1, 0.5, 0.1, 0.9), 6, 4)
	var mi := f.piece("candle", Shape.flame_mat(Color.WHITE, 1.0))
	mi.position = at
	add_child(mi)
	return mi


func _cauldron() -> void:
	# The fire pit and the iron pot are Blender models (art/make_models.py); the brew's surface,
	# the flames and the bubbles are the game's own
	add_child(Models.make("firepit"))
	add_child(Models.make("cauldron"))
	brew_mat = ShaderMaterial.new()
	brew_mat.shader = preload("res://shaders/brew.gdshader")
	brew_mat.set_shader_parameter("radius", BREW_R)
	brew_disc = MeshInstance3D.new()
	brew_disc.name = "brew"
	brew_disc.mesh = _brew_mesh()
	brew_disc.material_override = brew_mat
	brew_disc.position.y = BREW_LEVEL
	add_child(brew_disc)
	# Flames licking up round the belly
	fire = Node3D.new()
	fire.name = "fire"
	add_child(fire)
	for i in 9:
		var a := TAU * i / 9.0
		var f := Shape.new()
		var hue := Color(0.6, 1.0, 0.35, 0.85) if i % 2 else Color(1.0, 0.8, 0.3, 0.8)
		f.tube(Vector3(0, 0, 0), Vector3(0, 0.55, 0), 0.16, 0.0, hue, Color(hue.r, hue.g, hue.b, 0.0), 6, false)
		var m := Shape.flame_mat(Color.WHITE, 1.0)
		fire_mats.append(m)
		var mi := f.piece("flame", m)
		mi.position = Vector3(cos(a) * 0.62, 0.12, sin(a) * 0.58)
		fire.add_child(mi)
		flames.append(mi)
	var glow := Shape.new().disc(Vector3.ZERO, Vector2(1.1, 1.0), Color(0.5, 0.9, 0.3, 0.5), 16, Basis(), Color(0.5, 0.9, 0.3, 0.0))
	var gm := Shape.flame_mat(Color.WHITE, 0.7)
	fire_mats.append(gm)
	var gmi := glow.piece("glow", gm)
	gmi.position.y = 0.02
	fire.add_child(gmi)
	_bubble_mat = Shape.flame_mat(Color("aaffaa"), 0.9)
	bubbles = _particles("bubbles", 18, _bubble_mat, 0.07)
	bubbles.position = Vector3(0, BREW_LEVEL, 0)
	bubbles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	bubbles.emission_sphere_radius = 0.55
	bubbles.direction = Vector3.UP
	bubbles.spread = 10.0
	bubbles.gravity = Vector3(0, 0.2, 0)
	bubbles.initial_velocity_min = 0.05
	bubbles.initial_velocity_max = 0.2
	bubbles.lifetime = 1.0
	bubbles.scale_amount_min = 0.5
	bubbles.scale_amount_max = 1.6
	bubbles.scale_amount_curve = _rise_and_pop()
	bubbles.emitting = true
	steam = _particles("steam", 10, Shape.flame_mat(Color("d8ffd0"), 0.12), 0.14)
	steam.position = Vector3(0, BREW_LEVEL + 0.1, 0)
	steam.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	steam.emission_sphere_radius = 0.45
	steam.direction = Vector3.UP
	steam.gravity = Vector3(0, 0.6, 0)
	steam.initial_velocity_min = 0.3
	steam.initial_velocity_max = 0.6
	steam.lifetime = 2.0
	steam.scale_amount_min = 0.6
	steam.scale_amount_max = 1.3
	steam.scale_amount_curve = _rise_and_pop()
	steam.emitting = true
	splash = _particles("splash", 26, Shape.mat(0.4), 0.06)
	splash.position = Vector3(0, BREW_LEVEL + 0.05, 0)
	splash.one_shot = true
	splash.explosiveness = 0.95
	splash.direction = Vector3.UP
	splash.spread = 45.0
	splash.initial_velocity_min = 1.6
	splash.initial_velocity_max = 2.8
	splash.gravity = Vector3(0, -7.0, 0)
	splash.lifetime = 0.8
	splash.emitting = false
	sparkle = _particles("sparkle", 40, Shape.flame_mat(Color.WHITE, 1.4), 0.05)
	sparkle.position = Vector3(0, BREW_LEVEL + 0.2, 0)
	sparkle.one_shot = true
	sparkle.explosiveness = 0.85
	sparkle.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sparkle.emission_sphere_radius = 0.5
	sparkle.direction = Vector3.UP
	sparkle.spread = 70.0
	sparkle.initial_velocity_min = 0.8
	sparkle.initial_velocity_max = 2.2
	sparkle.gravity = Vector3(0, -1.0, 0)
	sparkle.lifetime = 1.0
	sparkle.scale_amount_curve = _rise_and_pop()
	sparkle.emitting = false
	smoke = _particles("smoke", 20, Shape.mat(0.3), 0.22)
	smoke.position = Vector3(0, BREW_LEVEL + 0.2, 0)
	smoke.one_shot = true
	smoke.explosiveness = 0.8
	smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	smoke.emission_sphere_radius = 0.5
	smoke.direction = Vector3.UP
	smoke.spread = 40.0
	smoke.initial_velocity_min = 0.6
	smoke.initial_velocity_max = 1.4
	smoke.gravity = Vector3(0, 0.5, 0)
	smoke.lifetime = 1.6
	smoke.color = Color("4a4038")
	smoke.scale_amount_min = 1.0
	smoke.scale_amount_max = 2.0
	smoke.scale_amount_curve = _rise_and_pop()
	smoke.emitting = false
	_more_particles()


func _particles(name: String, amount: int, material: Material, size: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = name
	p.amount = amount
	var ball := SphereMesh.new()
	ball.radius = size
	ball.height = size * 2.0
	ball.radial_segments = 6
	ball.rings = 3
	ball.material = material
	p.mesh = ball
	p.local_coords = false
	add_child(p)
	return p


func _rise_and_pop() -> Curve:
	var c := Curve.new()
	c.add_point(Vector2(0.0, 0.2))
	c.add_point(Vector2(0.25, 1.0))
	c.add_point(Vector2(0.85, 0.9))
	c.add_point(Vector2(1.0, 0.0))
	return c


## The table in front of the pot, everything on it, the bellows by the fire and the stirring stick.
## Each thing that can be tapped gets a spot: where it is and how big, for picking it on the screen.
func _table() -> void:
	var table := Models.make("table")
	table.position = TABLE
	table.scale = Vector3(1.0, 1.3, 1.0)
	add_child(table)
	# Three rows: the top step (jars 1-4), the lower step (5-8), and the front (wand, book, bottles)
	# Raised so it shows over the pot's rim: the back step (jars 5-8), the lower step (1-4), the front edge
	var lift := 1.3
	var rows_y := [1.0 * lift, 1.18 * lift, 0.82 * lift]
	var rows_z := [TABLE.z - 0.06, TABLE.z - 0.52, TABLE.z + 0.45]
	var cols := [-0.78, -0.26, 0.26, 0.78]
	for i in 8:
		var at := Vector3(TABLE.x + cols[i % 4], rows_y[i / 4], rows_z[i / 4])
		var holder := Node3D.new()
		holder.name = "jar%d" % i
		holder.position = at
		add_child(holder)
		var full := Models.make(INGREDIENT_MODELS[i])
		full.name = "full"
		full.scale = Vector3.ONE * 1.05
		holder.add_child(full)
		var empty := Models.make("ing_empty")
		empty.name = "empty"
		empty.scale = Vector3.ONE * 1.05
		holder.add_child(empty)
		props["jar%d" % i] = holder
		spots["jar%d" % i] = {"at": at + Vector3(0, 0.18, 0), "r": 0.3}
	var book := Models.make("book")
	# The book lies open on the floor to your left, by the fire
	# The book on the front corner of the table, the bellows on the other
	book.position = Vector3(TABLE.x - 1.0, rows_y[2], rows_z[2] + 0.05)
	book.rotation.y = 0.35
	book.scale = Vector3.ONE * 0.95
	book.scale = Vector3.ONE * 1.3
	add_child(book)
	props["book"] = book
	spots["book"] = {"at": book.position + Vector3(0, 0.2, 0), "r": 0.32}
	var jar := Models.make("wand_jar")
	jar.position = Vector3(TABLE.x - 0.6, rows_y[2], rows_z[2])
	jar.scale = Vector3.ONE * 1.1
	add_child(jar)
	var wand := Models.make("wand")
	wand.name = "wand"
	wand.position = Vector3(0, 0.12, 0)
	wand.rotation.z = 0.25
	jar.add_child(wand)
	_wand = wand
	props["wand"] = jar
	spots["wand"] = {"at": jar.position + Vector3(0, 0.35, 0), "r": 0.3}
	var rack := Models.make("bottles")
	rack.position = Vector3(TABLE.x + 0.52, rows_y[2], rows_z[2])
	rack.scale = Vector3.ONE * 1.0
	add_child(rack)
	props["bottle"] = rack
	spots["bottle"] = {"at": rack.position + Vector3(0, 0.2, 0), "r": 0.38}
	# The bellows lie by the fire with their nozzle on it
	var bellows := Node3D.new()
	bellows.name = "bellows"
	bellows.position = Vector3(TABLE.x + 0.98, rows_y[2] + 0.05, rows_z[2] + 0.1)
	var d := Vector3(-0.6, 0, 0.8).normalized()
	bellows.rotation = Vector3(0, atan2(d.z, -d.x), 0.18)
	bellows.scale = Vector3.ONE * 1.1
	add_child(bellows)
	bellows.add_child(Models.make("bellows"))
	_bellows_top = Models.make("bellows_top")
	bellows.add_child(_bellows_top)
	props["bellows"] = bellows
	spots["bellows"] = {"at": bellows.position + Vector3(0, 0.15, 0), "r": 0.5}
	spots["stir"] = {"at": Vector3(0, CAULDRON_RIM, 0), "r": 0.95}
	stick = Models.make("stick")
	stick.name = "stick"
	add_child(stick)


## Shows which jars are stocked tonight
func stock(count: int) -> void:
	for i in 8:
		var holder: Node3D = props["jar%d" % i]
		holder.get_node("full").visible = i < count
		holder.get_node("empty").visible = i >= count


## A thing on the table hops when it's tapped (`shake` wobbles it: not now)
func poke(id: String, shake := false) -> void:
	if not props.has(id):
		return
	_pokes[id] = -1.0 if shake else 0.0


func squeeze() -> void:
	_squeeze = 1.0


func _animate_props(dt: float) -> void:
	_squeeze = maxf(0.0, _squeeze - dt * 3.5)
	if _bellows_top != null:
		_bellows_top.rotation.z = lerpf(0.32, 0.04, _squeeze)
	for id: String in _pokes.keys():
		var t: float = _pokes[id]
		var node: Node3D = props[id]
		var base: Vector3 = _prop_scale.get(id, node.scale)
		_prop_scale[id] = base
		if t < 0.0:
			# A shake: -1 counting up to 0
			t += dt * 2.5
			node.rotation.y = sin(t * 40.0) * 0.12 * -t
			if t >= 0.0:
				node.rotation.y = 0.0
				_pokes.erase(id)
				continue
		else:
			t += dt
			var k := sin(minf(t / 0.3, 1.0) * PI)
			node.scale = base * (1.0 + k * 0.18)
			if t >= 0.3:
				node.scale = base
				_pokes.erase(id)
				continue
		_pokes[id] = t


## The stick stirs itself as you drag round the pot; left alone it leans on the rim
func _animate_stick(dt: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	if stirring:
		_stick_angle = stir_angle
	else:
		_stick_angle = lerp_angle(_stick_angle, -0.35 + sin(t * 1.1) * 0.12, minf(1.0, dt * 2.0))
	var out := Vector3(cos(_stick_angle), 0, sin(_stick_angle))
	var dip := out * 0.4 + Vector3(0, BREW_LEVEL - 0.15, 0)
	var top := dip + (out * 0.55 + Vector3.UP + Vector3(0, 0, 0.15)).normalized() * 1.25
	stick.global_position = top
	stick.look_at(dip, out)


## An ingredient flies from its place on the table into the pot
func toss(which: int, landed: Callable) -> void:
	var holder: Node3D = props["jar%d" % which]
	var bit := Models.make(INGREDIENT_MODELS[which])
	bit.scale = Vector3.ONE * 0.75
	add_child(bit)
	var from := holder.global_position + Vector3(0, 0.25, 0)
	var to := Vector3(0, BREW_LEVEL, 0)
	var tw := create_tween()
	tw.tween_method(func(k: float) -> void:
		bit.global_position = from.lerp(to, k) + Vector3(0, sin(k * PI) * 0.9, 0)
		bit.rotation = Vector3(k * 5.0, k * 3.0, 0)
		bit.scale = Vector3.ONE * lerpf(0.75, 0.4, k), 0.0, 1.0, 0.42)
	tw.tween_callback(func() -> void:
		bit.queue_free()
		landed.call(which, to))


## The wand rises out of its jar, waves over the pot in a shower of sparks, and goes back
func wave_wand() -> void:
	_wand_t = 0.0
	poke("wand")
	zap()


func _animate_wand(dt: float) -> void:
	_wand_t += dt
	if _wand == null:
		return
	var jar: Node3D = props["wand"]
	var home := jar.global_transform * Vector3(0, 0.12, 0)
	var over := Vector3(0, BREW_LEVEL + 0.9, 0.1)
	var k := 0.0
	if _wand_t < 0.25:
		k = _wand_t / 0.25
	elif _wand_t < 0.85:
		k = 1.0
	elif _wand_t < 1.1:
		k = 1.0 - (_wand_t - 0.85) / 0.25
	_wand.global_position = home.lerp(over, smoothstep(0.0, 1.0, k))
	_wand.rotation = Vector3(0, 0, 0.25 + k * sin(_wand_t * 22.0) * 0.6)


# --- the brew coming alive ---

## A disc of rings for the brew's surface, fine enough to ripple
func _brew_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 18
	var seg := 48
	var pts := []
	for i in rings + 1:
		var row := []
		for j in seg:
			var a := TAU * j / seg
			var r := BREW_R * float(i) / rings
			row.append(Vector3(cos(a) * r, 0, sin(a) * r))
		pts.append(row)
	for i in rings:
		for j in seg:
			var a: Vector3 = pts[i][j]
			var b: Vector3 = pts[i][(j + 1) % seg]
			var c: Vector3 = pts[i + 1][(j + 1) % seg]
			var d: Vector3 = pts[i + 1][j]
			for v: Vector3 in [a, c, b, a, d, c]:
				st.set_normal(Vector3.UP)
				st.add_vertex(v)
	return st.commit()


## Rings out from where something hit the brew
func ripple(at: Vector3, strength := 1.0) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	_ripples[_next_ripple] = Vector4(at.x, at.z, t, strength)
	_next_ripple = (_next_ripple + 1) % 4
	brew_mat.set_shader_parameter("ripples", _ripples)


## What happens when something goes in: each ingredient does its own thing (`fx`), bigger the more
## is already in the pot (`strength`). Specials are what certain pairs do together.
func react(fx: String, col: Color, strength := 1.0, at := Vector3.ZERO) -> void:
	var k := clampf(strength, 0.6, 2.5)
	ripple(at, 0.8 * k)
	_burst(splash, col.lightened(0.25), int(14 * k), 1.6 + 0.6 * k)
	_last_col = col
	match fx:
		"bubbles":
			_burst(big_bubbles, col.lightened(0.4), int(10 * k))
		"spores":
			_burst(wisps, Color("ff6a5a"), int(10 * k), 0.8)
			_burst(sparkle, Color("fffbf0"), int(12 * k))
		"smoke":
			_burst(wisps, Color("8a52c9"), int(14 * k), 0.7)
		"splash":
			_burst(splash, col.lightened(0.4), int(24 * k), 2.6 + 0.5 * k)
		"dark":
			_burst(wisps, Color("1a1430"), int(16 * k), 0.6)
			_burst(big_bubbles, Color("3b3a8c"), int(6 * k))
		"sparkle":
			_burst(sparkle, Color("cfe0ff"), int(30 * k))
			_glow = maxf(_glow, 0.5)
		"ghost":
			_burst(wisps, Color("f4f0ff"), int(12 * k), 0.4)
		"fire":
			_burst(embers, Color("ffa22e"), int(26 * k), 3.0)
			_glow = maxf(_glow, 0.6)
		# Specials
		"fireball":
			_burst(embers, Color("ff7a1a"), 60, 4.5)
			_burst(wisps, Color("4a3a30"), 20, 1.4)
			_glow = 1.4
			ripple(at, 2.5)
		"rainbow":
			for c: Color in [Color("ff5a5a"), Color("ffd84a"), Color("5ae07a"), Color("5ac8ff"), Color("c87aff")]:
				_burst(sparkle, c, 12)
			_glow = 1.0
		"geyser":
			_burst(splash, col.lightened(0.3), 60, 5.0)
			ripple(at, 2.5)
		"stink":
			_burst(wisps, Color("8ac83a"), 30, 1.0)
		"zap":
			_burst(sparkle, col.lightened(0.5), 40)
			_burst(sparkle, Color("fff27a"), 20)
			_glow = 1.2
			ripple(Vector3.ZERO, 1.2)


func _burst(p: CPUParticles3D, col: Color, amount := -1, speed := -1.0) -> void:
	# A copy, so bursts can overlap and each keeps its own colour
	var b := p.duplicate() as CPUParticles3D
	b.color = col
	if amount > 0:
		b.amount = clampi(amount, 1, 90)
	if speed > 0.0:
		b.initial_velocity_min = speed * 0.6
		b.initial_velocity_max = speed
	b.one_shot = true
	b.visible = true
	add_child(b)
	b.emitting = true
	get_tree().create_timer(b.lifetime + 0.5).timeout.connect(b.queue_free)


# --- carrying ingredients over to the pot ---

## Picks up a handful of ingredient `which` from the table; it follows the finger until dropped
func hold(which: int) -> Node3D:
	var holder: Node3D = props["jar%d" % which]
	var bit := Models.make(INGREDIENT_MODELS[which])
	bit.scale = Vector3.ONE * 0.9
	add_child(bit)
	bit.global_position = holder.global_position + Vector3(0, 0.15, 0)
	poke("jar%d" % which)
	return bit


## Moves a held thing toward a point, a little behind, swinging as it goes
func carry(bit: Node3D, to: Vector3, dt: float) -> void:
	var was := bit.global_position
	bit.global_position = was.lerp(to, minf(1.0, dt * 18.0))
	var v := (bit.global_position - was) / maxf(dt, 0.001)
	bit.rotation = bit.rotation.lerp(Vector3(clampf(v.z * 0.15, -0.6, 0.6), 0, clampf(-v.x * 0.15, -0.6, 0.6)), minf(1.0, dt * 10.0))


## Whether a held thing is over the pot's mouth
func over_pot(at: Vector3) -> bool:
	return Vector2(at.x, at.z).length() < BREW_R + 0.12


## Lets go: over the pot it drops in (and `landed` is called with where); anywhere else it floats back
func drop(bit: Node3D, which: int, landed: Callable) -> void:
	var from := bit.global_position
	var tw := create_tween()
	if over_pot(from):
		var to := Vector3(from.x, BREW_LEVEL, from.z)
		tw.tween_method(func(k: float) -> void:
			bit.global_position = from.lerp(to, k * k)
			bit.rotation.y += 0.2, 0.0, 1.0, 0.25)
		tw.tween_callback(func() -> void:
			bit.queue_free()
			landed.call(which, to))
	else:
		var home: Vector3 = (props["jar%d" % which] as Node3D).global_position + Vector3(0, 0.15, 0)
		tw.tween_method(func(k: float) -> void:
			bit.global_position = from.lerp(home, k) + Vector3(0, sin(k * PI) * 0.3, 0)
			bit.scale = Vector3.ONE * lerpf(0.9, 0.3, k), 0.0, 1.0, 0.3)
		tw.tween_callback(bit.queue_free)


func _more_particles() -> void:
	# Soft coloured wisps that rise and spread
	wisps = _particles("wisps", 16, Shape.flame_mat(Color.WHITE, 0.55), 0.18)
	wisps.position = Vector3(0, BREW_LEVEL + 0.15, 0)
	wisps.explosiveness = 0.7
	wisps.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	wisps.emission_sphere_radius = 0.45
	wisps.direction = Vector3.UP
	wisps.spread = 35.0
	wisps.gravity = Vector3(0, 0.7, 0)
	wisps.initial_velocity_min = 0.3
	wisps.initial_velocity_max = 0.8
	wisps.damping_min = 0.4
	wisps.damping_max = 0.8
	wisps.lifetime = 2.0
	wisps.scale_amount_min = 0.8
	wisps.scale_amount_max = 2.2
	wisps.scale_amount_curve = _rise_and_pop()
	wisps.emitting = false
	wisps.visible = false
	# Embers that shoot up and fall
	embers = _particles("embers", 30, Shape.flame_mat(Color.WHITE, 1.6), 0.035)
	embers.position = Vector3(0, BREW_LEVEL + 0.05, 0)
	embers.explosiveness = 0.9
	embers.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	embers.emission_sphere_radius = 0.35
	embers.direction = Vector3.UP
	embers.spread = 30.0
	embers.gravity = Vector3(0, -4.0, 0)
	embers.lifetime = 1.2
	embers.scale_amount_curve = _rise_and_pop()
	embers.emitting = false
	embers.visible = false
	# Big bubbles that swell up out of the brew and pop
	big_bubbles = _particles("big_bubbles", 10, Shape.mat(0.5), 0.12)
	big_bubbles.position = Vector3(0, BREW_LEVEL, 0)
	big_bubbles.explosiveness = 0.6
	big_bubbles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	big_bubbles.emission_sphere_radius = 0.5
	big_bubbles.direction = Vector3.UP
	big_bubbles.spread = 15.0
	big_bubbles.gravity = Vector3(0, 0.3, 0)
	big_bubbles.initial_velocity_min = 0.1
	big_bubbles.initial_velocity_max = 0.4
	big_bubbles.lifetime = 1.1
	big_bubbles.scale_amount_min = 0.7
	big_bubbles.scale_amount_max = 1.8
	big_bubbles.scale_amount_curve = _rise_and_pop()
	big_bubbles.emitting = false
	big_bubbles.visible = false
