class_name Hut
extends Node3D
## Grumblewart's hut, seen as she sees it, standing at her cauldron: the pot in front on its fire,
## a shelf of ingredients curving round behind it below the serving window, the night outside the
## window (the moon crossing it is the clock), stone walls, a plank floor, jars, herbs. Lit by the
## fire under the pot, the brew's own glow, the moon through the window and a candle.

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
## The shelf in an arc behind the pot: how far out its middle is, how high its top
const SHELF_R := 1.78
const SHELF_TOP := 1.12
## The room was built with its window off to one side: it's moved over so the window is in the middle
const ROOM_SHIFT := -1.05
const INGREDIENT_MODELS := ["ing_eye", "ing_shroom", "ing_wing", "ing_leg", "ing_spider", "ing_petal", "ing_pepper", "ing_scale"]
## One of each, as picked up and carried
const ONE_MODELS := ["one_eye", "one_shroom", "one_wing", "one_leg", "one_spider", "one_petal", "one_pepper", "one_scale"]

## Things that can be tapped: id -> node, and id -> {at: where, r: how big}
var props := {}
var spots := {}
var stick: Node3D
var brew: Brew
var fire: Fire
var moon: Node3D
## 0 to 100, from the bellows
var heat := 0.0
## The stirring stick: how far round it's been dragged, and whether it's going
var stir_angle := 0.0
var stirring := false
var _bellows_top: Node3D
var _squeeze := 0.0
var _pokes := {}
var _prop_scale := {}
var _stick_angle := 0.0
var _wand_t := 9.0
var _wand: Node3D
var _wake_t := 0.0
var _flare := 0.0
var _edge_fires: Array[Fire] = []
var _rng := RandomNumberGenerator.new()
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
	_shelf()
	_lights()


func _process(dt: float) -> void:
	_animate_props(dt)
	_animate_stick(dt)
	_animate_wand(dt)
	# The fire leaps with the heat (and flares when something fiery goes in)
	var h := heat / 100.0
	_flare = maxf(0.0, _flare - dt * 1.5)
	fire.intensity = 0.7 + h * 0.75 + _flare * 0.5
	fire.light_energy = 2.0 + h * 3.5 + _flare * 2.0
	fire.scale = Vector3(1.0, 0.7 + h * 0.8 + _flare * 0.4, 1.0)
	for f in _edge_fires:
		f.intensity = 0.6 + h * 0.8 + _flare * 0.5
		f.scale = Vector3.ONE * (0.55 + h * 0.75 + _flare * 0.4)
	brew.heat = h


## How far the stirring has turned the brew (radians)
func stir_to(angle: float) -> void:
	brew.spin = angle


## The brew becomes what's in it: its look for the effect it's making, murky when spoilt
func set_brew(col: Color, murky := false, effect := "") -> void:
	brew.murk = 1.0 if murky else 0.0
	if not murky:
		brew.set_look(PotionLook.for_effect(effect, col) if effect != "" else PotionLook.from_colour(col))


## Clean water again, at once
func fresh() -> void:
	brew.murk = 0.0
	brew.set_look(PotionLook.from_colour(Book.WATER), true)


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
	_candle_flame(Vector3(-2.0, 3.74, -2.5))
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
	var f := Fire.candle()
	f.position = at
	add_child(f)
	var mi := MeshInstance3D.new()
	return mi


## The fire pit and the iron pot (Blender models), GameCommon's fire under it, and the brew
func _cauldron() -> void:
	add_child(Models.make("firepit"))
	add_child(Models.make("cauldron"))
	# The fire: one in the middle with the light, and tongues round the edge licking up the iron
	fire = _flame(Vector3(0, 0.12, 0), 0.55, true)
	for k in 7:
		var a := lerpf(0.15, PI - 0.15, k / 6.0)
		var r := 0.82 + 0.06 * sin(k * 2.3)
		_edge_fires.append(_flame(Vector3(cos(a) * r, 0.08, sin(a) * r * 0.9), 0.32 + 0.1 * sin(k * 1.7), false))
	brew = Brew.new()
	brew.name = "brew"
	brew.position = Vector3(0, BREW_LEVEL, 0)
	add_child(brew)


func _flame(at: Vector3, size: float, lit: bool) -> Fire:
	var f := Fire.new()
	f.size = size
	f.spread = 0.9
	f.core = Color(1.0, 1.0, 0.75)
	f.body = Color(0.55, 1.0, 0.3)
	f.tip = Color(0.1, 0.45, 0.15)
	f.light = lit
	f.light_energy = 2.5
	f.light_range = 9.0
	f.embers = lit
	f.smoke = false
	f.position = at
	add_child(f)
	return f


## Moonlight in through the window behind, cool, catching the customers' shoulders
func _lights() -> void:
	var moonlight := DirectionalLight3D.new()
	moonlight.name = "moonlight"
	moonlight.light_color = Color(0.5, 0.55, 1.0)
	moonlight.light_energy = 0.7
	moonlight.rotation = Vector3(deg_to_rad(-28), deg_to_rad(180 + 15), 0)
	add_child(moonlight)
	# A soft fill from where you stand, so the front of things isn't lost in the dark
	var fill := OmniLight3D.new()
	fill.name = "fill"
	fill.position = Vector3(0, 2.4, 2.6)
	fill.light_color = Color(0.75, 0.6, 0.9)
	fill.light_energy = 0.7
	fill.omni_range = 7.0
	add_child(fill)


## The shelf curving round behind the pot below the counter, the ingredients along it in an arc;
## the wand and the empty jars at the ends of the counter; the bellows by the fire, the book by the
## pot. Each thing that can be tapped gets a spot: where it is and how big, for picking it on screen.
func _shelf() -> void:
	var shelf := Models.make("shelf_arc")
	shelf.rotation.y = PI
	add_child(shelf)
	for i in 8:
		var a := deg_to_rad(lerpf(-56.0, 56.0, i / 7.0))
		var at := Vector3(-sin(a) * SHELF_R, SHELF_TOP, -cos(a) * SHELF_R)
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
	var jar := Models.make("wand_jar")
	jar.position = Vector3(-1.05, 1.51, -2.55)
	add_child(jar)
	var wand := Models.make("wand")
	wand.name = "wand"
	wand.position = Vector3(0, 0.12, 0)
	wand.rotation.z = 0.25
	jar.add_child(wand)
	_wand = wand
	props["wand"] = jar
	spots["wand"] = {"at": jar.position + Vector3(0, 0.3, 0), "r": 0.3}
	var rack := Models.make("bottles")
	rack.position = Vector3(1.0, 1.51, -2.55)
	add_child(rack)
	props["bottle"] = rack
	spots["bottle"] = {"at": rack.position + Vector3(0, 0.18, 0), "r": 0.36}
	var book := Models.make("book")
	book.position = Vector3(-0.92, 0.0, 0.25)
	book.rotation.y = 0.5
	book.scale = Vector3.ONE * 1.4
	add_child(book)
	props["book"] = book
	spots["book"] = {"at": book.position + Vector3(0, 0.25, 0), "r": 0.38}
	var bellows := Node3D.new()
	bellows.name = "bellows"
	bellows.position = Vector3(0.95, 0.14, 0.28)
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
	# The stick drags a little wake round in the brew while it goes
	if stirring:
		_wake_t -= dt
		if _wake_t <= 0.0:
			_wake_t = 0.08
			brew.ripple(Vector2(dip.x, dip.z), 0.35)


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
			brew.puffs(p, int(5 * k), Color(1.0, 0.45, 0.35, 0.7), 0.5, 0.8)
			brew.sparks(p, int(6 * k), Color("fff4e0"), 1.2)
		"smoke":
			brew.puffs(p, int(7 * k), Color(0.55, 0.35, 0.85, 0.7), 0.6, 1.0)
		"splash":
			brew.splash(p, 1.2 + 0.3 * k)
		"dark":
			brew.puffs(p, int(7 * k), Color(0.1, 0.08, 0.2, 0.8), 0.5, 1.0)
			brew.bubble_burst(int(4 * k), 1.5)
		"sparkle":
			brew.sparks(p, int(16 * k), Color("cfe0ff"), 1.6)
			brew.flash(0.5)
		"ghost":
			brew.puffs(p, int(6 * k), Color(0.95, 0.95, 1.0, 0.6), 0.3, 1.3)
		"fire":
			brew.sparks(p, int(18 * k), Color("ffa22e"), 2.4)
			brew.flash(0.6)
			_flare = 1.0
		# Specials
		"fireball":
			brew.sparks(p, 48, Color("ff7a1a"), 3.2)
			brew.puffs(p, 10, Color(0.25, 0.18, 0.12, 0.8), 0.9, 1.4)
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
			brew.puffs(p, 12, Color(0.55, 0.8, 0.25, 0.7), 0.7, 1.2)
		"zap":
			brew.sparks(Vector3.ZERO, 26, brew.look.foam, 1.8)
			brew.sparks(Vector3.ZERO, 14, Color("fff27a"), 2.2)
			brew.flash(1.0)
			brew.ripple(Vector2.ZERO, 1.2)


func plop(_col: Color) -> void:
	brew.splash(Vector3(randf_range(-0.2, 0.2), 0, randf_range(-0.2, 0.2)), 0.8)


func zap() -> void:
	react("zap", brew.look.liquid, 1.0)


func poof() -> void:
	brew.puffs(Vector3.ZERO, 10, Color(0.22, 0.18, 0.15, 0.85), 0.7, 1.2)
	brew.ripple(Vector2.ZERO, 1.5)


# --- carrying ingredients over to the pot ---

## Picks one up off the shelf (one eye, one toadstool...); it follows the finger until dropped
func hold(which: int) -> Node3D:
	var holder: Node3D = props["jar%d" % which]
	var bit := Models.make(ONE_MODELS[which])
	bit.scale = Vector3.ONE * 1.3
	add_child(bit)
	bit.global_position = holder.global_position + Vector3(0, 0.2, 0)
	poke("jar%d" % which)
	return bit


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
