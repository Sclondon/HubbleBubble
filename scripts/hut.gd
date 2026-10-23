class_name Hut
extends Node3D
## Grumblewart's hut in the swamp, seen as she sees it, leaning over her cauldron: the pot in front on
## its fire, a shelf of ingredients curving round behind it below the serving counter, and the back
## wall: the counter window in the middle (its shutters thrown open when the shop's open, shut when
## it's not), the back window on the left looking out over the swamp (where ingredients are
## gathered) and the door out to the balcony on the right (where brews are tried). The swamp night
## outside, the moon crossing it the clock. Lit by the fire under the pot, the brew's own glow, the
## moon and a candle.

const STONE := Color("8a7aa6")
const STONE_D := Color("4f4168")
const WOOD := Color("a8683a")
const WOOD_D := Color("6b3e22")
const PLANK := Color("8f5b33")
const PLANK_D := Color("5e3820")
const SHUTTER := Color("4f8a3a")
const SHUTTER_D := Color("35602a")

## Where the serving window's customer stands
const WINDOW_SPOT := Vector3(0, 0.3, -3.45)
## About where a customer's face is
const WINDOW_HEAD := Vector3(0, 2.0, -3.3)
const CAULDRON_RIM := 1.36
const BREW_LEVEL := 1.24
const BREW_R := 0.8
## The shelf in an arc behind the pot: how far out its middle is, how high its top
const SHELF_R := 1.78
const SHELF_TOP := 1.12
## The holes in the back wall: the counter window, the back window (the swamp), the balcony door
const COUNTER_HOLE := Rect2(-1.1, 1.45, 2.2, 2.15)
const SWAMP_HOLE := Rect2(-2.4, 1.9, 0.9, 1.2)
const DOOR_HOLE := Rect2(1.42, 0.0, 1.0, 2.75)
const WALL_Z := -3.0
## Where the four ingredients on the hung shelves either side of the pot stand
const SIDE_SPOTS := [Vector3(-1.32, 2.95, -1.7), Vector3(-1.32, 2.35, -1.7), Vector3(1.32, 2.95, -1.7), Vector3(1.32, 2.35, -1.7)]
const INGREDIENT_MODELS := ["ing_eye", "ing_shroom", "ing_wing", "ing_leg", "ing_spider", "ing_petal", "ing_pepper", "ing_scale"]
## One of each, as picked up and carried
const ONE_MODELS := ["one_eye", "one_shroom", "one_wing", "one_leg", "one_spider", "one_petal", "one_pepper", "one_scale"]

## Things that can be tapped: id -> node, and id -> {at: where, r: how big}
var props := {}
var spots := {}
var stick: Node3D
var brew: Brew
var fire: PotFire
var moon: Node3D
## 0 to 100, from the bellows
var heat := 0.0
## The stirring stick: where its tip is wanted in the brew (local to the hut), and whether a finger has it
var stick_target := Vector3(0.35, BREW_LEVEL, 0.1)
var stirring := false
## How open the counter shutters are (0 shut, 1 open), and where they're going
var shutters := 0.0
var shutters_to := 0.0
var _shutter_l: Node3D
var _shutter_r: Node3D
var _door_leaf: Node3D
var _bellows_top: Node3D
var _squeeze := 0.0
var _pokes := {}
var _prop_scale := {}
var _tip := Vector3(0.35, BREW_LEVEL, 0.1)
var _wand_t := 9.0
var _wand: Node3D
var _flare := 0.0
var _rng := RandomNumberGenerator.new()
var _night_t := 0.0
## The pot (rattles while it cooks), the thermometer's needle, the floating book and its pages
var _pot: Node3D
var _needle: Node3D
var _book: Node3D
var _book_home := Vector3.ZERO
var _book_scale := 1.0
var _needle_angle := 0.0
var _current_target := 0.0


func _ready() -> void:
	_rng.seed = 7
	_outside()
	_room()
	_counter()
	_bits()
	_cauldron()
	_shelf()
	_lights()
	_set_shutters(0.0)


func _process(dt: float) -> void:
	_animate_props(dt)
	_animate_stick(dt)
	_animate_wand(dt)
	if not is_equal_approx(shutters, shutters_to):
		_set_shutters(move_toward(shutters, shutters_to, dt * 2.2))
	# The fire leaps with the heat (and flares when something fiery goes in)
	var h := heat / 100.0
	_flare = maxf(0.0, _flare - dt * 1.5)
	fire.intensity = 0.6 + h * 1.3 + _flare * 0.6
	fire.light_energy = 2.0 + h * 3.5 + _flare * 2.0
	brew.heat = h
	var t := Time.get_ticks_msec() / 1000.0
	# The thermometer's needle swings to the heat (a little behind, quivering when it's hot)
	var want := deg_to_rad(-135.0 + 270.0 * clampf(heat, 0.0, 100.0) / 100.0)
	_needle_angle = lerp_angle(_needle_angle, want, minf(1.0, dt * 6.0))
	_needle.rotation.z = -(_needle_angle + sin(t * 31.0) * 0.03 * h * h)
	# The pot rattles and jumps while it cooks
	if brew.cooking > 0.0:
		var k := minf(1.0, brew.cooking * 2.0)
		_pot.position = Vector3(sin(t * 47.0) * 0.012, absf(sin(t * 19.0)) * 0.04, cos(t * 41.0) * 0.012) * k
		_pot.rotation = Vector3(sin(t * 23.0) * 0.03, 0, cos(t * 27.0) * 0.03) * k
	else:
		_pot.position = _pot.position.lerp(Vector3.ZERO, minf(1.0, dt * 10.0))
		_pot.rotation = _pot.rotation.lerp(Vector3.ZERO, minf(1.0, dt * 10.0))
	# The current: set going by the stick, dying away slowly after (slower in a thin brew)
	if stirring:
		brew.current = lerpf(brew.current, _current_target, minf(1.0, dt * 2.5))
	else:
		brew.current *= exp(-dt * lerpf(0.5, 1.4, brew.look.thickness))
	_current_target *= exp(-dt * 3.0)
	# The book floats, turning a little
	_book.position = _book_home + Vector3(0, sin(t * 1.3) * 0.04, 0)
	# Turned to whoever's looking, so its pages can be read from anywhere
	var cam := get_viewport().get_camera_3d()
	var to := ((cam.global_position if cam != null else Vector3(0, 3.0, 3.2)) - _book.position).normalized()
	_book.basis = Basis.looking_at(-to, Vector3.UP).scaled(Vector3.ONE * _book_scale) * Basis(Vector3.BACK, sin(t * 0.9) * 0.04)


## The brew becomes what's in it: its look for the effect it's making, murky when spoilt
func set_brew(col: Color, murky := false, effect := "") -> void:
	brew.murk = 1.0 if murky else 0.0
	if murky:
		# Spoilt: a skull and crossbones of dirty smoke
		brew.smoke_shape(2, Color(0.35, 0.3, 0.22, 0.9), 1.1)
	else:
		brew.set_look(PotionLook.for_effect(effect, col) if effect != "" else PotionLook.from_colour(col))


## Clean water again, at once
func fresh() -> void:
	brew.murk = 0.0
	brew.clear_floaters()
	brew.set_look(PotionLook.from_colour(Book.WATER), true)


## Where the moon is, 0 at the start of the night to 1 at the end
func night_progress(t: float) -> void:
	_night_t = t
	moon.position = Vector3(lerpf(-1.0, 1.0, t), 2.6 + sin(t * PI) * 0.7, -6.4)


## Throws the counter shutters open (the shop's open) or swings them shut
func open_shop(open: bool) -> void:
	shutters_to = 1.0 if open else 0.0


func _set_shutters(k: float) -> void:
	shutters = k
	var swing := smoothstep(0.0, 1.0, k) * deg_to_rad(105.0)
	_shutter_l.rotation.y = swing
	_shutter_r.rotation.y = -swing
	# Tapped where they are: across the window when shut, the left one swung out when open
	var at := Vector3(0, 2.5, WALL_Z) if k < 0.5 else Vector3(-1.55, 2.5, WALL_Z + 0.35)
	spots["shutters"] = {"at": at, "r": 0.75 if k < 0.5 else 0.45}


# --- building it ---

## The swamp night beyond the back wall: a sky, stars, dead trees and reeds against it, black water
func _outside() -> void:
	var sky := Shape.new()
	var k1 := Color("8a5ab8").srgb_to_linear()
	var k2 := Color("2a2070").srgb_to_linear()
	var z := -7.0
	var corners := [Vector3(-7.0, -1.0, z), Vector3(7.0, -1.0, z), Vector3(7.0, 6.5, z), Vector3(-7.0, 6.5, z)]
	sky._quad(corners, [Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK], [k1, k1, k2, k2])
	add_child(sky.piece("sky", Shape.mat(1.0)))
	var stars := Shape.new()
	for i in 70:
		var p := Vector3(_rng.randf_range(-6.0, 6.0), _rng.randf_range(2.4, 6.2), -6.9)
		var s := _rng.randf_range(0.015, 0.045)
		stars.ball(p, Vector3(s, s, s), Color("fff6c8"), null, 4, 3)
	add_child(stars.piece("stars", Shape.mat(1.0)))
	var dark := Color("161230")
	var land := Shape.new()
	# Far banks, then black water with the moon's road on it
	land.ball(Vector3(-3.5, 0.6, -6.6), Vector3(3.2, 0.9, 0.3), Color("2a2650"), Color("1c1838"), 14, 6)
	land.ball(Vector3(3.2, 0.5, -6.6), Vector3(3.6, 1.0, 0.3), Color("272352"), Color("1c1838"), 14, 6)
	land.box(Vector3(0, 0.0, -5.0), Vector3(14.0, 0.05, 4.0), Color("141030"), Color("141030"))
	land.box(Vector3(0, 0.03, -5.4), Vector3(0.5, 0.02, 3.0), Color("6a5a9a"), Color("6a5a9a"))
	# Crooked dead trees, moss hanging off them
	for spec: Array in [[-2.9, -5.6, 1.0], [2.6, -5.2, 1.2], [-0.9, -6.2, 0.7], [4.4, -6.0, 0.9]]:
		var x: float = spec[0]
		var zz: float = spec[1]
		var s: float = spec[2]
		var top := Vector3(x + 0.3 * s, 3.4 * s, zz)
		land.bend([Vector3(x, 0.0, zz), Vector3(x + 0.1 * s, 1.4 * s, zz), Vector3(x - 0.15 * s, 2.5 * s, zz), top], 0.16 * s, 0.05 * s, dark)
		land.bend([Vector3(x - 0.1 * s, 2.3 * s, zz), Vector3(x - 0.6 * s, 2.8 * s, zz), Vector3(x - 0.9 * s, 3.3 * s, zz)], 0.06 * s, 0.02 * s, dark)
		land.bend([Vector3(x + 0.05 * s, 1.8 * s, zz), Vector3(x + 0.6 * s, 2.1 * s, zz), Vector3(x + 1.0 * s, 2.6 * s, zz)], 0.05 * s, 0.02 * s, dark)
		for m in 3:
			var mx := x + (m - 1) * 0.4 * s
			land.tube(Vector3(mx, 2.6 * s, zz + 0.05), Vector3(mx + 0.05, 2.0 * s, zz + 0.05), 0.03, 0.005, Color("2a3a30"), null, 4)
	# Reeds and bulrushes along the near edge
	for i in 40:
		var x := _rng.randf_range(-6.0, 6.0)
		var zz := _rng.randf_range(-4.2, -3.4)
		var h := _rng.randf_range(0.5, 1.3)
		var lean := _rng.randf_range(-0.15, 0.15)
		land.tube(Vector3(x, 0.0, zz), Vector3(x + lean, h, zz), 0.02, 0.008, Color("1e2a30"), null, 4)
		if i % 4 == 0:
			land.ball(Vector3(x + lean, h, zz), Vector3(0.035, 0.09, 0.035), Color("3a2418"), null, 5, 4)
	add_child(land.piece("swamp_outside", Shape.mat(0.25)))
	moon = Node3D.new()
	moon.name = "moon"
	var m := Shape.new().ball(Vector3.ZERO, Vector3(0.38, 0.38, 0.1), Color("fff2b0"), Color("f0d070"), 14, 8)
	m.ball(Vector3(0.1, 0.08, 0.06), Vector3(0.07, 0.07, 0.05), Color("e6d48a"), null, 6, 4)
	m.ball(Vector3(-0.12, -0.1, 0.06), Vector3(0.05, 0.05, 0.04), Color("e6d48a"), null, 6, 4)
	moon.add_child(m.piece("moon", Shape.mat(1.0)))
	add_child(moon)
	night_progress(0.0)


func _room() -> void:
	# Plank floor
	var floor_s := Shape.new()
	for i in 12:
		var x := -6.0 + i * 1.0
		var shade := PLANK.lerp(PLANK_D, _rng.randf_range(0.0, 0.45))
		floor_s.box(Vector3(x + 0.5, -0.05, 0.5), Vector3(0.96, 0.1, 9.0), shade, shade.darkened(0.3))
	add_child(floor_s.piece("floor"))
	# The back wall of uneven stones, with its three holes, dark mortar behind
	var wall := Shape.new()
	var mortar := Shape.new()
	var holes := [COUNTER_HOLE]
	for row in 12:
		var y := row * 0.5
		var x := -4.6 + (0.45 if row % 2 else 0.0)
		while x < 4.6:
			var w := _rng.randf_range(0.6, 1.0)
			var centre := Vector2(x + w * 0.5, y + 0.25)
			var cut := false
			for h: Rect2 in holes:
				if h.grow(0.12).has_point(centre):
					cut = true
			if not cut:
				var shade := STONE.lerp(STONE_D, _rng.randf_range(0.0, 0.55))
				wall.box(Vector3(centre.x, centre.y, WALL_Z + _rng.randf_range(-0.04, 0.04)), Vector3(w - 0.06, 0.44, 0.3), shade.lightened(0.08), shade)
			x += w
	for row in 24:
		for col in 38:
			var c := Vector2(-4.75 + col * 0.25 + 0.125, row * 0.25 + 0.125)
			var cut := false
			for h: Rect2 in holes:
				if h.grow(0.02).has_point(c):
					cut = true
			if not cut:
				mortar.box(Vector3(c.x, c.y, WALL_Z - 0.12), Vector3(0.26, 0.26, 0.04), STONE_D.darkened(0.5), STONE_D.darkened(0.5))
	add_child(wall.piece("wall"))
	add_child(mortar.piece("mortar"))
	# Side walls, and beams overhead
	for sgn: float in [-1.0, 1.0]:
		var side := Shape.new()
		for row in 12:
			for k in 8:
				var shade := STONE.lerp(STONE_D, _rng.randf_range(0.2, 0.8))
				side.box(Vector3(sgn * 4.6, row * 0.5 + 0.25, -2.6 + k * 1.0 + (0.5 if row % 2 else 0.0)), Vector3(0.3, 0.44, 0.94), shade, shade.darkened(0.15))
		add_child(side.piece("side"))
	var beams := Shape.new()
	for i in 4:
		beams.box(Vector3(0, 4.6, -2.4 + i * 1.6), Vector3(9.4, 0.3, 0.3), WOOD_D, WOOD_D.darkened(0.3))
	beams.box(Vector3(0, 4.3, -2.75), Vector3(9.4, 0.25, 0.25), WOOD, WOOD_D)
	add_child(beams.piece("beams"))


## The serving counter in the middle of the back wall, and its shutters
func _counter() -> void:
	var frame := Shape.new()
	var x0 := COUNTER_HOLE.position.x
	var x1 := COUNTER_HOLE.end.x
	frame.box(Vector3(0, 1.42, -2.75), Vector3(2.7, 0.18, 0.9), WOOD.lightened(0.1), WOOD_D)
	frame.box(Vector3(0, 1.0, -2.36), Vector3(2.6, 0.7, 0.08), WOOD, WOOD_D)
	for k in 5:
		frame.box(Vector3(-1.15 + k * 0.58, 1.0, -2.31), Vector3(0.06, 0.66, 0.03), WOOD_D, WOOD_D)
	frame.box(Vector3(x0 - 0.06, 2.55, -2.85), Vector3(0.22, 2.3, 0.4), WOOD, WOOD_D)
	frame.box(Vector3(x1 + 0.06, 2.55, -2.85), Vector3(0.22, 2.3, 0.4), WOOD, WOOD_D)
	frame.box(Vector3(0, 3.68, -2.85), Vector3(2.5, 0.24, 0.4), WOOD, WOOD_D)
	# A little sign over it
	frame.box(Vector3(0, 4.05, -2.8), Vector3(1.3, 0.42, 0.08), Color("e8c06a"), WOOD_D)
	add_child(frame.piece("frame"))
	var sign := Label3D.new()
	sign.text = "POTIONS"
	sign.font = load("res://fonts/Fredoka.ttf")
	sign.font_size = 64
	sign.outline_size = 0
	sign.modulate = Color("5a2a12")
	sign.pixel_size = 0.004
	sign.position = Vector3(0, 4.05, -2.75)
	sign.shaded = false
	add_child(sign)
	# Two shutters, hinged at the sides of the window, each half its width
	for sgn: float in [-1.0, 1.0]:
		var hinge := Node3D.new()
		hinge.position = Vector3(sgn * 1.1, 2.52, -2.68)
		add_child(hinge)
		var s := Shape.new()
		var w := 1.1
		s.box(Vector3(-sgn * w * 0.5, 0, 0), Vector3(w - 0.02, 2.0, 0.07), SHUTTER, SHUTTER_D)
		for k in 4:
			s.box(Vector3(-sgn * w * 0.5, -0.75 + k * 0.5, 0.045), Vector3(w - 0.1, 0.03, 0.02), SHUTTER_D, SHUTTER_D)
		s.box(Vector3(-sgn * w * 0.5, 0.55, 0.06), Vector3(w * 0.8, 0.12, 0.05), WOOD_D, WOOD_D)
		s.box(Vector3(-sgn * w * 0.5, -0.55, 0.06), Vector3(w * 0.8, 0.12, 0.05), WOOD_D, WOOD_D)
		# A crescent moon cut in the left one, a star in the right
		if sgn < 0.0:
			s.ball(Vector3(-sgn * w * 0.55, 0.1, 0.05), Vector3(0.14, 0.14, 0.02), Color("f2d070"), null, 10, 4)
			s.ball(Vector3(-sgn * w * 0.55 + 0.06, 0.14, 0.06), Vector3(0.12, 0.12, 0.02), SHUTTER, null, 10, 4)
		else:
			s.ball(Vector3(-sgn * w * 0.55, 0.1, 0.05), Vector3(0.09, 0.09, 0.02), Color("f2d070"), null, 5, 3)
		hinge.add_child(s.piece("shutter"))
		if sgn < 0.0:
			_shutter_l = hinge
		else:
			_shutter_r = hinge


## The back window on the left: a frame with crossed bars and a sill with a pot of something growing
func _back_window() -> void:
	var r := SWAMP_HOLE
	var f := Shape.new()
	var cx := r.get_center().x
	f.box(Vector3(r.position.x - 0.06, r.get_center().y, WALL_Z + 0.12), Vector3(0.14, r.size.y + 0.2, 0.32), WOOD, WOOD_D)
	f.box(Vector3(r.end.x + 0.06, r.get_center().y, WALL_Z + 0.12), Vector3(0.14, r.size.y + 0.2, 0.32), WOOD, WOOD_D)
	f.box(Vector3(cx, r.end.y + 0.06, WALL_Z + 0.12), Vector3(r.size.x + 0.26, 0.14, 0.32), WOOD, WOOD_D)
	f.box(Vector3(cx, r.position.y - 0.05, WALL_Z + 0.22), Vector3(r.size.x + 0.4, 0.1, 0.5), WOOD.lightened(0.1), WOOD_D)
	f.box(Vector3(cx, r.get_center().y, WALL_Z + 0.02), Vector3(0.05, r.size.y, 0.05), WOOD_D, WOOD_D)
	f.box(Vector3(cx, r.get_center().y + 0.1, WALL_Z + 0.02), Vector3(r.size.x, 0.05, 0.05), WOOD_D, WOOD_D)
	# A pot of swamp weed on the sill
	f.tube(Vector3(cx + 0.28, r.position.y, WALL_Z + 0.3), Vector3(cx + 0.28, r.position.y + 0.2, WALL_Z + 0.3), 0.09, 0.12, Color("b8683a"), Color("8a4a2a"), 8)
	for k in 5:
		var a := TAU * k / 5.0
		f.tube(Vector3(cx + 0.28, r.position.y + 0.18, WALL_Z + 0.3), Vector3(cx + 0.28 + cos(a) * 0.12, r.position.y + 0.42 + 0.05 * k, WALL_Z + 0.3 + sin(a) * 0.08), 0.03, 0.008, Color("5f9a3a"), Color("3a6a2a"), 4)
	add_child(f.piece("back_window"))
	# A candle on the sill, so the window's found in the dark
	var candle := Fire.candle()
	candle.position = Vector3(cx - 0.25, r.position.y + 0.02, WALL_Z + 0.32)
	add_child(candle)
	var stub := Shape.new().tube(Vector3(cx - 0.25, r.position.y - 0.18, WALL_Z + 0.32), Vector3(cx - 0.25, r.position.y + 0.02, WALL_Z + 0.32), 0.05, 0.05, Color("f4ecd0"))
	add_child(stub.piece("sill_candle"))
	spots["swamp_window"] = {"at": Vector3(cx, r.get_center().y, WALL_Z), "r": 0.6}


## The door out to the balcony, on the right, standing open on the night
func _door() -> void:
	var r := DOOR_HOLE
	var f := Shape.new()
	var cx := r.get_center().x
	f.box(Vector3(r.position.x - 0.07, r.size.y * 0.5, WALL_Z + 0.12), Vector3(0.16, r.size.y, 0.34), WOOD, WOOD_D)
	f.box(Vector3(r.end.x + 0.07, r.size.y * 0.5, WALL_Z + 0.12), Vector3(0.16, r.size.y, 0.34), WOOD, WOOD_D)
	f.box(Vector3(cx, r.end.y + 0.08, WALL_Z + 0.12), Vector3(r.size.x + 0.3, 0.18, 0.34), WOOD, WOOD_D)
	# The balcony's boards running out, and its rail against the sky
	f.box(Vector3(cx, 0.0, WALL_Z - 1.0), Vector3(r.size.x + 0.6, 0.06, 2.0), PLANK, PLANK_D)
	f.box(Vector3(cx, 0.9, WALL_Z - 1.9), Vector3(r.size.x + 0.8, 0.06, 0.06), WOOD_D, WOOD_D)
	for k in 3:
		f.box(Vector3(r.position.x + 0.1 + k * 0.42, 0.45, WALL_Z - 1.9), Vector3(0.06, 0.9, 0.06), WOOD_D, WOOD_D)
	add_child(f.piece("door_frame"))
	var lantern := Shape.new().box(Vector3(cx + 0.35, 1.1, WALL_Z - 1.85), Vector3(0.14, 0.2, 0.14), Color("ffc060"), Color("ffb040"))
	add_child(lantern.piece("door_lantern", Shape.mat(1.0)))
	var glow := OmniLight3D.new()
	glow.position = Vector3(cx + 0.2, 1.3, WALL_Z - 1.5)
	glow.light_color = Color(1.0, 0.7, 0.35)
	glow.light_energy = 2.2
	glow.omni_range = 3.2
	add_child(glow)
	_door_leaf = Node3D.new()
	_door_leaf.position = Vector3(r.end.x, 0.0, WALL_Z + 0.1)
	_door_leaf.rotation.y = deg_to_rad(-70.0)
	add_child(_door_leaf)
	var leaf := Shape.new()
	leaf.box(Vector3(-r.size.x * 0.5, r.size.y * 0.5, 0), Vector3(r.size.x - 0.04, r.size.y - 0.04, 0.08), SHUTTER, SHUTTER_D)
	for k in 3:
		leaf.box(Vector3(-r.size.x * 0.5, 0.5 + k * 0.85, 0.05), Vector3(r.size.x * 0.85, 0.1, 0.04), WOOD_D, WOOD_D)
	leaf.ball(Vector3(-r.size.x + 0.15, 1.3, 0.08), Vector3(0.05, 0.05, 0.05), Color("f2c840"), null, 6, 4)
	_door_leaf.add_child(leaf.piece("door"))
	spots["balcony"] = {"at": Vector3(cx, 1.9, WALL_Z - 0.4), "r": 0.6}


func _bits() -> void:
	var s := Shape.new()
	# Herbs and garlic hanging off the beams
	for i in 9:
		var x := -4.0 + i * 1.0 + _rng.randf_range(-0.2, 0.2)
		if absf(x) < 1.3:
			continue
		var zz := -2.4 + _rng.randf_range(-0.2, 0.9)
		var drop := _rng.randf_range(0.5, 1.0)
		s.tube(Vector3(x, 4.5, zz), Vector3(x, 4.5 - drop, zz), 0.012, 0.012, Color("d8c8a0"), null, 4)
		if i % 2 == 0:
			for k in 5:
				var a := TAU * k / 5.0
				s.tube(Vector3(x, 4.5 - drop, zz), Vector3(x + cos(a) * 0.14, 4.5 - drop - 0.45, zz + sin(a) * 0.14), 0.04, 0.01, Color("5f9a3a"), Color("3a6a2a"), 4)
		else:
			s.ball(Vector3(x, 4.5 - drop - 0.12, zz), Vector3(0.14, 0.13, 0.14), Color("f4ecd8"), Color("c8b898"), 8, 5)
			s.ball(Vector3(x + 0.15, 4.5 - drop - 0.22, zz), Vector3(0.12, 0.11, 0.12), Color("f4ecd8"), Color("c8b898"), 8, 5)
	# A shelf over the back window: a skull with a candle on it, books, jars
	var sy := SWAMP_HOLE.end.y + 0.45
	var sx := SWAMP_HOLE.get_center().x
	s.box(Vector3(sx, sy, WALL_Z + 0.3), Vector3(1.4, 0.08, 0.45), WOOD.lightened(0.05), WOOD_D)
	s.ball(Vector3(sx - 0.3, sy + 0.18, WALL_Z + 0.32), Vector3(0.15, 0.13, 0.14), Color("f2ead2"), Color("c8bc98"), 10, 6)
	s.ball(Vector3(sx - 0.35, sy + 0.18, WALL_Z + 0.45), Vector3(0.035, 0.045, 0.02), Color("201820"), null, 6, 4)
	s.ball(Vector3(sx - 0.25, sy + 0.18, WALL_Z + 0.45), Vector3(0.035, 0.045, 0.02), Color("201820"), null, 6, 4)
	s.tube(Vector3(sx - 0.3, sy + 0.3, WALL_Z + 0.32), Vector3(sx - 0.3, sy + 0.5, WALL_Z + 0.32), 0.045, 0.045, Color("f4ecd0"))
	for i in 3:
		var bc: Color = [Color("8a2a2a"), Color("2a5a8a"), Color("7a4a8a")][i]
		s.box(Vector3(sx + 0.1 + i * 0.12, sy + 0.24, WALL_Z + 0.3), Vector3(0.1, 0.42 - i * 0.05, 0.32), bc.lightened(0.1), bc)
	s.tube(Vector3(sx + 0.52, sy + 0.04, WALL_Z + 0.3), Vector3(sx + 0.52, sy + 0.3, WALL_Z + 0.3), 0.08, 0.07, Color("5fd6c4"), Color("8ae8d8"), 8)
	# Jars on shelves along the side walls (for wide screens)
	var jar_cols := [Color("e8473a"), Color("5fd6c4"), Color("8a52c9"), Color("86d84a"), Color("ffa22e"), Color("a8c8ff"), Color("ffc4e4"), Color("f4e04a")]
	for sgn: float in [-1.0, 1.0]:
		for row in 3:
			var y := 1.3 + row * 0.95
			s.box(Vector3(sgn * 4.25, y, -1.2), Vector3(0.5, 0.1, 2.6), WOOD.lightened(0.05), WOOD_D)
			var zz := -2.4
			while zz < 0.0:
				var col: Color = jar_cols[_rng.randi() % jar_cols.size()]
				var h := _rng.randf_range(0.25, 0.48)
				var rr := _rng.randf_range(0.1, 0.16)
				zz += rr + 0.03
				s.tube(Vector3(sgn * 4.2, y + 0.05, zz), Vector3(sgn * 4.2, y + 0.05 + h, zz), rr, rr * 0.9, col.darkened(0.2), col.lightened(0.2), 8)
				s.tube(Vector3(sgn * 4.2, y + 0.05 + h, zz), Vector3(sgn * 4.2, y + 0.12 + h, zz), rr * 0.55, rr * 0.55, Color("c89a5a"), null, 6)
				zz += rr + 0.05
	# Cobwebs in the top corners
	for sgn: float in [-1.0, 1.0]:
		var corner := Vector3(sgn * 4.4, 4.45, -2.85)
		for k in 5:
			var a := PI * 0.5 + sgn * (PI * 0.5) + (-sgn) * k * (PI * 0.5) / 4.0
			s.tube(corner, corner + Vector3(cos(a) * -1.0, -absf(sin(a)) * 1.0, 0.05), 0.008, 0.008, Color("d8d8e8"), null, 3)
	add_child(s.piece("bits"))
	var candle := Fire.candle()
	candle.position = Vector3(sx - 0.3, sy + 0.52, WALL_Z + 0.32)
	add_child(candle)


## The fire pit and the pot (Blender models), the fire under it, and the brew
func _cauldron() -> void:
	add_child(Models.make("firepit"))
	# The pot and what's in it move together (it rattles when something cooks)
	_pot = Node3D.new()
	_pot.name = "pot"
	add_child(_pot)
	_pot.add_child(Models.make("cauldron"))
	fire = PotFire.new()
	fire.name = "fire"
	fire.position = Vector3(0, 0.06, 0)
	add_child(fire)
	brew = Brew.new()
	brew.name = "brew"
	brew.position = Vector3(0, BREW_LEVEL, 0)
	_pot.add_child(brew)
	# The thermometer clipped to the rim at the front left, its dial turned up to you
	var thermo := Models.make("thermometer")
	thermo.name = "thermometer"
	thermo.position = Vector3(-0.78, 1.62, 0.3)
	thermo.rotation = Vector3(-0.55, -0.9, 0)
	thermo.scale = Vector3.ONE * 0.85
	_pot.add_child(thermo)
	_needle = Models.make("thermometer_needle")
	thermo.add_child(_needle)


## Moonlight in through the window behind, cool, catching the customers' shoulders
func _lights() -> void:
	var moonlight := DirectionalLight3D.new()
	moonlight.name = "moonlight"
	moonlight.light_color = Color(0.5, 0.55, 1.0)
	moonlight.light_energy = 0.9
	moonlight.rotation = Vector3(deg_to_rad(-28), deg_to_rad(180 + 15), 0)
	add_child(moonlight)
	# A soft fill from where you stand, so the front of things isn't lost in the dark
	var fill := OmniLight3D.new()
	fill.name = "fill"
	fill.position = Vector3(0, 2.6, 2.4)
	fill.light_color = Color(0.75, 0.6, 0.9)
	fill.light_energy = 0.0
	fill.visible = false
	fill.omni_range = 7.0
	add_child(fill)


## The shelf curving round behind the pot below the counter, the ingredients along it in an arc;
## the wand and the empty jars at the ends of the counter; the bellows by the fire, the book by the
## pot. Each thing that can be tapped gets a spot: where it is and how big, for picking it on screen.
func _shelf() -> void:
	var shelf := Models.make("shelf_arc")
	shelf.rotation.y = PI
	add_child(shelf)
	# The first four along the shelf behind the pot; the other four up on little shelves hung either
	# side of it (two on the left, two on the right)
	var hung := Shape.new()
	for i in 8:
		var a := 0.0
		var at := Vector3.ZERO
		if i < 4:
			a = deg_to_rad(lerpf(-38.0, 38.0, i / 3.0))
			at = Vector3(-sin(a) * SHELF_R, SHELF_TOP, -cos(a) * SHELF_R)
		else:
			at = SIDE_SPOTS[i - 4]
			a = -0.35 if at.x > 0.0 else 0.35
			hung.box(at + Vector3(0, -0.03, 0), Vector3(0.62, 0.05, 0.36), WOOD.lightened(0.05), WOOD_D, Basis(Vector3.UP, -a))
			for sgn: float in [-1.0, 1.0]:
				var end := at + Basis(Vector3.UP, -a) * Vector3(sgn * 0.27, 0, 0)
				hung.tube(end, end + Vector3(0, 2.5, 0), 0.01, 0.01, Color("c8b088"), null, 4)
		var holder := Node3D.new()
		holder.name = "jar%d" % i
		holder.position = at
		holder.rotation.y = -a
		add_child(holder)
		var full := Models.make(INGREDIENT_MODELS[i])
		full.name = "full"
		holder.add_child(full)
		var empty := Models.make("ing_empty")
		empty.name = "empty"
		holder.add_child(empty)
		props["jar%d" % i] = holder
		spots["jar%d" % i] = {"at": at + Vector3(0, 0.18, 0), "r": 0.26}
	add_child(hung.piece("side_shelves"))
	var jar := Models.make("wand_jar")
	jar.position = Vector3(-0.95, 1.51, -2.55)
	add_child(jar)
	var wand := Models.make("wand")
	wand.name = "wand"
	wand.position = Vector3(0, 0.12, 0)
	wand.rotation.z = 0.25
	jar.add_child(wand)
	_wand = wand
	props["wand"] = jar
	spots["wand"] = {"at": jar.position + Vector3(0, 0.3, 0), "r": 0.3}
	# The empty jars, big and close at hand on a little shelf hung from the beams by the pot
	var hang := Vector3(1.05, 1.8, -0.72)
	var plank := Shape.new()
	plank.box(hang + Vector3(0, -0.03, 0), Vector3(0.95, 0.05, 0.34), WOOD.lightened(0.05), WOOD_D, Basis(Vector3.UP, -0.5))
	for sgn: float in [-1.0, 1.0]:
		var end := hang + Basis(Vector3.UP, -0.5) * Vector3(sgn * 0.42, 0, 0)
		plank.tube(end, end + Vector3(0, 3.0, 0), 0.012, 0.012, Color("c8b088"), null, 4)
	add_child(plank.piece("bottle_shelf"))
	var rack := Models.make("bottles")
	rack.position = hang
	rack.rotation.y = -0.5
	rack.scale = Vector3.ONE * 1.15
	add_child(rack)
	props["bottle"] = rack
	spots["bottle"] = {"at": hang + Vector3(0, 0.25, 0), "r": 0.45}
	_book = _floating_book()
	# Floating low by the pot on the front left, clear of the shelves
	_book_home = Vector3(-0.72, 1.0, 1.3)
	_book_scale = 0.48
	_book.position = _book_home
	add_child(_book)
	props["book"] = _book
	spots["book"] = {"at": _book_home, "r": 0.34}
	var bellows := Node3D.new()
	bellows.name = "bellows"
	bellows.position = Vector3(0.95, 0.75, 0.95)
	var d := (Vector3(0, 0, 0) - bellows.position).normalized()
	bellows.rotation = Vector3(0, atan2(d.z, -d.x), 0.2)
	bellows.scale = Vector3.ONE * 1.3
	add_child(bellows)
	bellows.add_child(Models.make("bellows"))
	_bellows_top = Models.make("bellows_top")
	bellows.add_child(_bellows_top)
	props["bellows"] = bellows
	spots["bellows"] = {"at": bellows.position + Vector3(0, 0.2, 0), "r": 0.45}
	spots["stir"] = {"at": Vector3(0, CAULDRON_RIM, 0), "r": 0.95}
	stick = Models.make("stick")
	stick.name = "stick"
	add_child(stick)


## The book, floating open under the back window: leather covers, and the two pages it was left
## open at (drawn into a texture by the game: see set_book_pages)
func _floating_book() -> Node3D:
	var b := Node3D.new()
	b.name = "book"
	var holder := Node3D.new()
	b.add_child(holder)
	# Turned to face you, leaning back
	holder.rotation = Vector3.ZERO
	var cover := Shape.new()
	for sgn: float in [-1.0, 1.0]:
		cover.box(Vector3(sgn * 0.3, 0, -0.02), Vector3(0.6, 0.78, 0.03), Color("6a2a3a"), Color("4a1a2a"), Basis(Vector3.UP, sgn * 0.18))
	cover.box(Vector3(0, 0, -0.06), Vector3(0.06, 0.78, 0.06), Color("4a1a2a"), Color("3a1020"))
	holder.add_child(cover.piece("cover"))
	for i in 2:
		var page := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.56, 0.74)
		page.mesh = q
		var sgn := -1.0 if i == 0 else 1.0
		page.position = Vector3(sgn * 0.29, 0, 0.0)
		page.rotation.y = sgn * 0.18
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(0.9, 0.82, 0.68)
		m.uv1_scale = Vector3(0.5, 1, 1)
		m.uv1_offset = Vector3(0.0 if i == 0 else 0.5, 0, 0)
		page.material_override = m
		page.name = "page%d" % i
		# Drawn sharp at full size, over the soft N64 picture, so it can be read
		page.layers = 4
		holder.add_child(page)
	# A little glow under it, as if it's held up by something
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.8, 0.7, 1.0)
	glow.light_energy = 0.8
	glow.omni_range = 1.4
	glow.position = Vector3(0, -0.3, 0.3)
	b.add_child(glow)
	return b


## What the floating book's pages show (a texture of two pages side by side)
func set_book_pages(tex: Texture2D) -> void:
	var holder := _book.get_child(0)
	for i in 2:
		var m: StandardMaterial3D = holder.get_node("page%d" % i).material_override
		m.albedo_texture = tex


## Shows which jars are stocked tonight (the first `count`)
func stock(count: int) -> void:
	var avail := []
	for i in 8:
		avail.append(i < count)
	show_stock(avail)


## Shows each jar full, or an empty cobwebbed bowl
func show_stock(avail: Array) -> void:
	for i in 8:
		var holder: Node3D = props["jar%d" % i]
		holder.get_node("full").visible = avail[i]
		holder.get_node("empty").visible = not avail[i]


## A thing hops when it's tapped (`shake` wobbles it: not now)
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
			node.rotation.x = sin(t * 40.0) * 0.12 * -t
			if t >= 0.0:
				node.rotation.x = 0.0
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


## Where a stirring finger wants the stick's tip (a point on the brew); kept inside the pot
func stir_at(p: Vector3) -> void:
	var flat := Vector2(p.x, p.z).limit_length(BREW_R - 0.16)
	stick_target = Vector3(flat.x, BREW_LEVEL, flat.y)


## The stick's tip follows the finger through the brew, its handle leaning back toward you, and
## drags a wake behind it; let go, it drifts to rest against the rim
func _animate_stick(dt: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var want := stick_target
	if not stirring:
		var rest := 0.4 + sin(t * 0.9) * 0.08
		want = Vector3(cos(rest) * 0.5, BREW_LEVEL, sin(rest) * 0.5)
	var was := _tip
	_tip = _tip.lerp(want, minf(1.0, dt * (22.0 if stirring else 3.0)))
	var flat_out := Vector3(_tip.x, 0, _tip.z)
	var out := flat_out.normalized() if flat_out.length() > 0.05 else Vector3.BACK
	var dip := _tip - Vector3(0, 0.12, 0)
	var top := dip + (out * 0.4 + Vector3.UP + Vector3(0, 0, 0.35)).normalized() * 1.3
	stick.global_position = global_transform * top
	stick.look_at(global_transform * dip, Vector3(out.x, 0.0, out.z) if out.length() > 0.1 else Vector3.BACK)
	var speed := (_tip - was).length() / maxf(dt, 0.001)
	if speed > 0.05:
		brew.wake(Vector2(_tip.x, _tip.z), speed)
	# Going round the middle sets the brew going round
	if stirring and Vector2(_tip.x, _tip.z).length() > 0.12 and Vector2(was.x, was.z).length() > 0.12:
		var turned := wrapf(Vector2(_tip.x, _tip.z).angle() - Vector2(was.x, was.z).angle(), -PI, PI)
		_current_target = lerpf(_current_target, clampf(turned / maxf(dt, 0.001), -8.0, 8.0), minf(1.0, dt * 4.0))


## An ingredient thrown from its place on the shelf into the pot (a key, not a finger)
func toss(which: int, landed: Callable) -> void:
	var holder: Node3D = props["jar%d" % which]
	var bit := Models.make(ONE_MODELS[which])
	add_child(bit)
	var from := holder.global_position + Vector3(0, 0.25, 0)
	var to := Vector3(randf_range(-0.2, 0.2), BREW_LEVEL, randf_range(-0.2, 0.2))
	var tw := create_tween()
	tw.tween_method(func(k: float) -> void:
		bit.global_position = from.lerp(to, k) + Vector3(0, sin(k * PI) * 0.7, 0)
		bit.rotation = Vector3(k * 5.0, k * 3.0, 0), 0.0, 1.0, 0.42)
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
	var over := Vector3(0, BREW_LEVEL + 0.8, 0.2)
	var k := 0.0
	if _wand_t < 0.3:
		k = _wand_t / 0.3
	elif _wand_t < 0.9:
		k = 1.0
	elif _wand_t < 1.2:
		k = 1.0 - (_wand_t - 0.9) / 0.3
	_wand.global_position = home.lerp(over, smoothstep(0.0, 1.0, k))
	_wand.rotation = Vector3(0, 0, 0.25 + k * sin(_wand_t * 22.0) * 0.6)


# --- the brew coming alive ---

## What happens when something goes in: a splash where it landed, and then each ingredient does its
## own thing (`fx`), bigger the more is already in the pot (`strength`). Specials are what certain
## pairs do together.
func react(fx: String, col: Color, strength := 1.0, at := Vector3.ZERO) -> void:
	var k := clampf(strength, 0.6, 2.5)
	var p := at - brew.position
	p.y = 0.0
	brew.splash(p, 0.7 + 0.2 * k)
	match fx:
		"bubbles":
			brew.bubble_burst(int(6 * k), 1.8)
		"spores":
			brew.puffs(p, int(5 * k), Color(1.0, 0.55, 0.45, 0.85), 0.5, 0.8)
			brew.sparks(p, int(6 * k), Color("fff4e0"), 1.2)
		"smoke":
			brew.puffs(p, int(7 * k), Color(0.65, 0.45, 0.95, 0.9), 0.6, 1.0)
		"splash":
			brew.splash(p, 1.2 + 0.3 * k)
		"dark":
			brew.puffs(p, int(7 * k), Color(0.12, 0.1, 0.22, 0.9), 0.5, 1.0)
			brew.bubble_burst(int(4 * k), 1.5)
		"sparkle":
			brew.sparks(p, int(16 * k), Color("cfe0ff"), 1.6)
			brew.flash(0.5)
		"ghost":
			brew.puffs(p, int(6 * k), Color(0.95, 0.95, 1.0, 0.85), 0.3, 1.3)
		"fire":
			brew.sparks(p, int(18 * k), Color("ffa22e"), 2.4)
			brew.flash(0.6)
			_flare = 1.0
		# Specials
		"fireball":
			brew.sparks(p, 48, Color("ff7a1a"), 3.2)
			brew.puffs(p, 10, Color(0.3, 0.22, 0.15, 0.9), 0.9, 1.4)
			brew.flash(1.4)
			brew.splash(p, 2.0)
			_flare = 1.5
		"rainbow":
			for c: Color in [Color("ff5a5a"), Color("ffd84a"), Color("5ae07a"), Color("5ac8ff"), Color("c87aff")]:
				brew.sparks(p, 9, c, 1.8)
			brew.flash(1.0)
		"geyser":
			brew.splash(p, 2.4)
			brew.splash(p, 1.6)
		"stink":
			brew.puffs(p, 12, Color(0.6, 0.85, 0.3, 0.9), 0.7, 1.2)
		"zap":
			brew.sparks(Vector3.ZERO, 26, brew.look.foam, 1.8)
			brew.sparks(Vector3.ZERO, 14, Color("fff27a"), 2.2)
			brew.flash(1.0)
			brew.ripple(Vector2.ZERO, 1.2)


func zap() -> void:
	react("zap", brew.look.liquid, 1.0)


func poof() -> void:
	brew.puffs(Vector3.ZERO, 10, Color(0.3, 0.25, 0.2, 0.9), 0.7, 1.2)
	brew.ripple(Vector2.ZERO, 1.5)


# --- carrying things over to the pot ---

## Picks one up off the shelf (one eye, one toadstool...); it follows the finger until dropped
func hold(which: int) -> Node3D:
	var holder: Node3D = props["jar%d" % which]
	var bit := Models.make(ONE_MODELS[which])
	bit.scale = Vector3.ONE * 1.3
	add_child(bit)
	bit.global_position = holder.global_position + Vector3(0, 0.2, 0)
	poke("jar%d" % which)
	return bit


## Takes an empty jar off the tray, to scoop the brew up in; its liquid starts empty
func hold_bottle() -> Node3D:
	var b := Node3D.new()
	b.add_child(Models.make("potion"))
	b.scale = Vector3.ONE * 1.4
	var liquid := Models.make("potion_liquid", Shape.mat(0.35))
	liquid.name = "liquid"
	liquid.scale = Vector3(1, 0.001, 1)
	liquid.visible = false
	b.add_child(liquid)
	add_child(b)
	b.global_position = (props["bottle"] as Node3D).global_position + Vector3(0, 0.25, 0)
	poke("bottle")
	return b


## Fills a held jar part way (0 to 1) with the colour of the brew
func fill_bottle(b: Node3D, k: float, col: Color) -> void:
	var liquid: Node3D = b.get_node("liquid")
	liquid.visible = k > 0.01
	liquid.scale = Vector3(1, maxf(k, 0.001), 1)
	Models.dress(liquid, _tinted(col))


func _tinted(col: Color) -> ShaderMaterial:
	var m := Shape.mat(0.35)
	m.set_shader_parameter("tint", Shape.lin3(col))
	return m


## Puts an unfilled jar back on its tray
func return_bottle(b: Node3D) -> void:
	var from := b.global_position
	var home: Vector3 = (props["bottle"] as Node3D).global_position + Vector3(0, 0.2, 0)
	var tw := create_tween()
	tw.tween_method(func(k: float) -> void:
		b.global_position = from.lerp(home, k) + Vector3(0, sin(k * PI) * 0.3, 0)
		b.scale = Vector3.ONE * lerpf(1.0, 0.4, k), 0.0, 1.0, 0.3)
	tw.tween_callback(b.queue_free)


## Moves a held thing toward a point, swinging as it goes
func carry(bit: Node3D, to: Vector3, dt: float) -> void:
	var was := bit.global_position
	bit.global_position = was.lerp(to, minf(1.0, dt * 18.0))
	var v := (bit.global_position - was) / maxf(dt, 0.001)
	bit.rotation = bit.rotation.lerp(Vector3(clampf(v.z * 0.15, -0.6, 0.6), 0, clampf(-v.x * 0.15, -0.6, 0.6)), minf(1.0, dt * 10.0))


## Whether a held thing is over the pot's mouth
func over_pot(at: Vector3) -> bool:
	return Vector2(at.x, at.z).length() < BREW_R + 0.2


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
		var home: Vector3 = (props["jar%d" % which] as Node3D).global_position + Vector3(0, 0.2, 0)
		tw.tween_method(func(k: float) -> void:
			bit.global_position = from.lerp(home, k) + Vector3(0, sin(k * PI) * 0.3, 0)
			bit.scale = Vector3.ONE * lerpf(1.3, 0.4, k), 0.0, 1.0, 0.3)
		tw.tween_callback(bit.queue_free)
