class_name Shop
extends Node3D
## Granny Grumblewart's potion shop. Customers come to the window and order potions; each potion is
## a recipe of steps done in order (ingredients in, the fire brought to a heat, stirred round, a zap
## of the wand) and then bottled. A wrong step spoils the brew. Each night needs so many coins.

var save_path := "user://hubble_bubble.cfg"
const PUMP := 13.0
const HOLD := 1.0
const BOIL_AT := 92.0
const BOIL_TIME := 1.2
const KEY_STIR_SPEED := TAU * 1.4
## The most things a pot holds before it's too full
const MAX_STEPS := 8
const N64_LINES := 270.0

## "title", "intro", "play", "done", "over"
var state := "title"
var paused := false
var book_open := false
var night := 1
var score := 0
var best := 0
var night_coins := 0
var clock := 0.0
var heat := 10.0
var orders: Array[Dictionary] = []
var selected := -1
## What's gone into the pot so far, as steps (Book step dictionaries)
var brew: Array = []
## Things found by brewing: effect -> {recipe, name}, written in the book
var discoveries := {}
## "shop" (the nights) or "free" (brewing whatever you like, tried out on the tower top)
var mode := "shop"
## How far along the step that's being done is (heat held, turns stirred), 0 to 1
## How near the heat held is to counting (0 to 1), and how far round the stick is in its turn
var heat_fill := 0.0
var stir_fill := 0.0
var spoil_t := 0.0
var learned := {}
var done_kinds := {}
var combo := 0
var served := 0
var lost := 0
var speech := {}
var floaters: Array[Dictionary] = []
var intro_t := 0.0
var news := ""
var show_intro := true
## Set by tests: never save a best or report a score
var testing := false

var camera: Camera3D
var hut: Hut
var tower: Tower
var swamp: Swamp
## How many of each ingredient are on the table (in the shop; brewing freely there's no end to them)
var stock: Array = [4, 4, 4, 4, 4, 4, 4, 4]
const MAX_STOCK := 9
const SWAMP_TIME := 25.0
## Seconds left gathering in the swamp
var swamp_t := 0.0
## The brew being tried out on the tower top, and how long since
var tower_result := {}
var tower_new := false
var tower_t := 0.0
## The 3D, drawn small in here and blown up soft (the N64 filter), or full size with it off
var view: SubViewport
var screen: TextureRect
var n64 := true
var hud: Hud
var album: Album
var sfx: Sfx

var _spawn_t := 0.0
var _hold := 0.0
var _boil := 0.0
var _band := 0
var _band_t := 0.0
var _band_counted := 0
var _stir_dir := 0
var _stir_run := 0.0
var _stir_angle := 0.0
var _stir_sound := 0.0
var _stir_seen := 0.0
var _bubble_t := 0.0
var _tick := 0
var _next_order_id := 0
var _last_kind := ""
var _keys_down := {}
var _discovered_now := false
var _held: Node3D
var _held_which := 0
var _held_to := Vector3.ZERO
var _held_from := Vector2.ZERO
var _last_added := -1
var _added_count := 0


func _ready() -> void:
	randomize()
	sfx = Sfx.new()
	sfx.name = "sfx"
	add_child(sfx)
	view = SubViewport.new()
	view.name = "view"
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.msaa_3d = Viewport.MSAA_DISABLED
	add_child(view)
	var under := CanvasLayer.new()
	under.layer = -1
	add_child(under)
	screen = TextureRect.new()
	screen.name = "screen"
	screen.texture = view.get_texture()
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.stretch_mode = TextureRect.STRETCH_SCALE
	screen.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.material = ShaderMaterial.new()
	(screen.material as ShaderMaterial).shader = preload("res://shaders/n64.gdshader")
	under.add_child(screen)
	hut = Hut.new()
	hut.name = "hut"
	view.add_child(hut)
	tower = Tower.new()
	tower.name = "tower"
	tower.position = Vector3(200, 0, 0)
	view.add_child(tower)
	swamp = Swamp.new()
	swamp.name = "swamp"
	swamp.position = Vector3(-200, 0, 0)
	view.add_child(swamp)
	camera = Camera3D.new()
	camera.name = "camera"
	camera.current = true
	view.add_child(camera)
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Hud.new()
	hud.shop = self
	hud.name = "hud"
	layer.add_child(hud)
	album = Album.new()
	album.name = "album"
	add_child(album)
	get_viewport().size_changed.connect(_frame)
	_load()
	_frame()
	_to_title()


func _frame() -> void:
	var s := get_viewport().get_visible_rect().size
	# The N64 filter: the 3D is drawn this many lines on its short side, then blown up soft
	var k := (N64_LINES / minf(s.x, s.y)) if n64 else 1.0
	view.size = Vector2i(maxi(2, roundi(s.x * k)), maxi(2, roundi(s.y * k)))
	(screen.material as ShaderMaterial).set_shader_parameter("amount", 1.0 if n64 else 0.0)
	(screen.material as ShaderMaterial).set_shader_parameter("size", Vector2(view.size))
	var tall := s.y > s.x * 1.1
	if state == "swamp":
		# Over the swamp diorama, looking down on it
		camera.keep_aspect = Camera3D.KEEP_WIDTH if tall else Camera3D.KEEP_HEIGHT
		camera.fov = 42.0 if tall else 46.0
		camera.global_transform = swamp.global_transform * swamp.camera_at
		if tall:
			camera.global_position = swamp.global_position + Vector3(0, 7.4, 5.0)
			camera.look_at(swamp.global_position + Vector3(0, 0.0, 0.55))
	elif state == "tower":
		# Up on the tower top, looking at the witch in the circle
		camera.keep_aspect = Camera3D.KEEP_WIDTH if tall else Camera3D.KEEP_HEIGHT
		camera.fov = 60.0 if tall else 50.0
		camera.global_transform = tower.global_transform * tower.camera_at
		if tall:
			camera.global_position += camera.global_basis.z * 0.6 + Vector3(0, 0.3, 0)
	elif tall:
		# Phone: framed by width; you look down over the pot at the table and the window
		camera.keep_aspect = Camera3D.KEEP_WIDTH
		camera.fov = 45.0
		var spare := clampf((s.y / s.x - 2.17) * 1.2, -0.5, 0.6)
		camera.position = Vector3(0, 3.35 + spare * 0.5, 2.05 + spare * 0.4)
		camera.look_at(Vector3(0, 1.1, -1.25))
	else:
		camera.keep_aspect = Camera3D.KEEP_HEIGHT
		camera.fov = 50.0
		camera.position = Vector3(0, 3.6, 2.85)
		camera.look_at(Vector3(0, 1.3, -1.4))
	if hud != null:
		hud.layout()


func set_n64(on: bool) -> void:
	n64 = on
	_frame()
	_save()


func screen_of(p: Vector3) -> Vector2:
	# The camera's picture is the view's size; the screen shows it stretched over the whole window
	return camera.unproject_position(p) * (get_viewport().get_visible_rect().size / Vector2(view.size))


## What in the hut is under a point on the screen ("jar3", "bellows", "stir"...), or ""
func pick(at: Vector2) -> String:
	var best := ""
	var best_k := INF
	for id: String in hut.spots:
		var s: Dictionary = hut.spots[id]
		if camera.is_position_behind(s.at):
			continue
		var c := screen_of(s.at)
		var r := (screen_of(s.at + camera.global_basis.x * s.r) - c).length()
		var k := c.distance_to(at) / maxf(r, 1.0)
		if k < 1.0 and k < best_k:
			best_k = k
			best = id
	return best


func spot_screen(id: String) -> Vector2:
	return screen_of(hut.spots[id].at)


## Something in the hut tapped
func tap(id: String) -> void:
	match id:
		"bellows":
			pump()
		"wand":
			if night >= 3 or mode == "free":
				zap()
			else:
				hut.poke(id, true)
				Sfx.play("huff", 1.5, -8.0)
		"bottle":
			bottle()
		"book":
			hut.poke(id)
			toggle_book()


func cauldron_screen() -> Array:
	var c := screen_of(Vector3(0, Hut.CAULDRON_RIM, 0))
	var e := screen_of(Vector3(0.9, Hut.CAULDRON_RIM, 0))
	return [c, absf(e.x - c.x)]


# --- the flow of a game ---

func _to_title() -> void:
	state = "title"
	orders.clear()
	selected = -1
	_clear_customers()
	hut.fresh()
	hut.stock(8)
	heat = 30.0
	Sfx.music(false)
	_say_witch(Book.rhyme("title"))


func start_game() -> void:
	mode = "shop"
	stock = [4, 4, 4, 4, 4, 4, 4, 4]
	night = 1
	score = 0
	learned = {}
	done_kinds = {}
	combo = 0
	_start_night()


func _start_night() -> void:
	state = "intro"
	intro_t = 0.0
	orders.clear()
	selected = -1
	_clear_customers()
	spoil_t = 0.0
	night_coins = 0
	served = 0
	lost = 0
	heat = 10.0
	hut.fresh()
	_show_stock()
	clock = Book.night_length(night)
	_spawn_t = 1.2
	_tick = 0
	news = ""
	match night:
		1:
			news = "Do each step in order: tap the jars, pump the HEAT to the level shown, then BOTTLE it!"
		2:
			news = "New: stirring!  Drag round the pot."
		3:
			news = "New: the magic wand, and Moon Petals!"
		4:
			news = "Potions you know now hide their recipes. Check the book!"
		5:
			news = "The busiest night yet!"
	if night == 2:
		_say_witch(Book.rhyme("new_stir"))
	elif night == 3:
		_say_witch(Book.rhyme("new_zap"))
	elif night == 4:
		_say_witch(Book.rhyme("new_hidden"))
	else:
		_say_witch(Book.rhyme("night"))
	Sfx.play("night")
	hut.night_progress(0.0)


## Brewing whatever you like, no customers and no clock; bottled brews are tried out on the tower
func start_free() -> void:
	mode = "free"
	state = "play"
	paused = false
	orders.clear()
	selected = -1
	_clear_customers()
	hut.fresh()
	_reset_brew()
	_show_stock()
	heat = 20.0
	Sfx.music(true)
	_say_witch(Book.rhyme("free"))


func _to_tower(result: Dictionary) -> void:
	state = "tower"
	tower_result = result
	tower_new = _discovered_now
	tower_t = 0.0
	hut.fresh()
	_reset_brew()
	_frame()
	tower.try_out(result)


## Back down from the tower to brew another
func back_from_tower() -> void:
	if state != "tower" or tower_t < 1.2:
		return
	state = "play"
	_frame()
	Sfx.play("tap")


## Between nights: off to the swamp to gather what the next night will want
func _to_swamp() -> void:
	state = "swamp"
	swamp_t = SWAMP_TIME
	swamp.open_for(Book.ingredients_on(night + 1))
	_frame()
	Sfx.music(true, 0.9)
	_say_witch(Book.rhyme("swamp"))


## Gathers whatever's tapped in the swamp
func gather_at(at: Vector2) -> void:
	var best := ""
	var best_k := INF
	for id: String in swamp.spots:
		var sp: Dictionary = swamp.spots[id]
		var c := screen_of(sp.at)
		var r := (screen_of(sp.at + camera.global_basis.x * sp.r) - c).length()
		var k := c.distance_to(at) / maxf(r, 1.0)
		if k < 1.0 and k < best_k:
			best_k = k
			best = id
	if best == "":
		return
	var i := int(best.substr(6))
	if stock[i] >= MAX_STOCK:
		_float("Full!", at, Color("ffd0a0"))
		return
	if swamp.gather(i):
		stock[i] += 1
		_float("+1 %s" % Book.INGREDIENTS[i].name, at + Vector2(0, -40), Color("c8f0a0"))


## Done gathering: on to the next night
func leave_swamp() -> void:
	if state != "swamp":
		return
	Sfx.music(false)
	night += 1
	_start_night()
	_frame()


func begin_play() -> void:
	if state == "intro":
		state = "play"
		Sfx.music(true, 1.0)


func _close_shop() -> void:
	clock = 0.0
	for o in orders:
		if is_instance_valid(o.customer):
			o.customer.duck(true)
			o.customer.queue_free()
	orders.clear()
	selected = -1
	Sfx.music(false)
	if night_coins >= Book.quota(night):
		state = "done"
		Sfx.play("win")
		_say_witch(Book.rhyme("night_done"))
	else:
		state = "over"
		Sfx.play("lose")
		_say_witch(Book.rhyme("game_over"))
		if score > best and not testing:
			best = score
			_save()
		# Hand the score to the hosting page (the Scareathon arcade cabinet) for its leaderboard
		if OS.has_feature("web") and score > 0 and not testing:
			JavaScriptBridge.eval("window.parent.postMessage({ type: 'PLAYER_DIED', score: %d }, '*')" % score, true)
	intro_t = 0.0


## A tap on the card at the end of a night
func next_night() -> void:
	if intro_t < 1.0:
		return
	if state == "done":
		_to_swamp()
	elif state == "over":
		_to_title()


func toggle_pause() -> void:
	if state in ["play", "intro", "tower", "swamp"]:
		paused = not paused
		book_open = false
		Sfx.music(not paused and state == "play")
		Sfx.play("tap")


func quit_to_title() -> void:
	paused = false
	if state in ["tower", "swamp"]:
		state = "play"
		_frame()
	_to_title()


func toggle_book() -> void:
	book_open = not book_open
	if book_open:
		hud.book_page = 0
	if book_open and not selected_order().is_empty():
		selected_order().looked = true
	Sfx.play("tap")


func set_sound(on: bool) -> void:
	Sfx.set_muted(not on)
	_save()
	if on and state == "play" and not paused:
		Sfx.music(true)


func _clear_customers() -> void:
	for c in get_tree().get_nodes_in_group("customer"):
		c.queue_free()


# --- every frame ---

func _process(dt: float) -> void:
	_update_speech(dt)
	if is_instance_valid(_held):
		hut.carry(_held, _held_to, dt)
	for f in floaters:
		f.t += dt
	floaters = floaters.filter(func(f: Dictionary) -> bool: return f.t < 1.4)
	intro_t += dt
	_eyes()
	if paused:
		return
	if state == "play":
		_play(dt)
	elif state == "tower":
		tower_t += dt
	elif state == "swamp":
		swamp_t -= dt
		if swamp_t <= 0.0:
			leave_swamp()
	else:
		heat = move_toward(heat, 30.0 if state == "title" else 12.0, dt * 5.0)
	hut.heat = heat
	_bubble_t -= dt
	if _bubble_t < 0.0 and state != "title":
		_bubble_t = randf_range(0.3, 1.2) / (0.4 + heat / 60.0)
		Sfx.play("bubble", randf_range(0.7, 1.5), -14.0 + heat / 12.0)


func _play(dt: float) -> void:
	if mode == "free":
		_tend(dt)
		return
	clock -= dt
	var length := Book.night_length(night)
	hut.night_progress(1.0 - clock / length)
	if clock <= 15.0 and Sfx.me != null and Sfx.me._music.pitch_scale < 1.1:
		Sfx.music(true, 1.12)
	if clock <= 10.0 and int(ceil(clock)) != _tick and clock > 0.0:
		_tick = int(ceil(clock))
		Sfx.play("tick", 1.0, -4.0)
	if clock <= 0.0:
		_close_shop()
		return
	# Customers
	_spawn_t -= dt
	if _spawn_t <= 0.0 and orders.size() < Book.most_waiting(night) and clock > 12.0:
		_new_order()
		_spawn_t = Book.gap(night) * randf_range(0.8, 1.25)
	for i in range(orders.size() - 1, -1, -1):
		var o := orders[i]
		o.patience -= dt
		if is_instance_valid(o.customer):
			o.customer.patience = o.patience / o.full
		if o.patience <= 0.0:
			_storm_off(i)
	if orders.is_empty() and _spawn_t > 2.0:
		_spawn_t = 2.0
	_tend(dt)


## The fire and the stick, every frame while brewing: boiling over spoils it; heat held in a band
## a moment counts as that heat
func _tend(dt: float) -> void:
	heat = maxf(0.0, heat - (4.5 + heat * 0.045) * dt)
	_keys_stir(dt)
	_stir_seen = maxf(0.0, _stir_seen - dt)
	hut.stirring = _stir_seen > 0.0
	if spoil_t > 0.0:
		spoil_t -= dt
		if spoil_t <= 0.0:
			hut.fresh()
			_reset_brew()
		return
	if heat >= BOIL_AT:
		_boil += dt
		if _boil >= BOIL_TIME:
			_boil = 0.0
			heat = 62.0
			Sfx.play("hiss")
			if not brew.is_empty():
				_spoil(Book.rhyme("boil"))
			else:
				_say_witch(Book.rhyme("boil"))
	else:
		_boil = maxf(0.0, _boil - dt)
	var band := Book.band_of(heat)
	if band >= 1 and band == _band:
		_band_t += dt
		if _band_t >= HOLD and band > _band_counted and not brew.is_empty():
			_band_counted = band
			_record({"kind": Book.HEAT, "level": band})
			Sfx.play("tap", 1.5, -2.0)
	else:
		_band = band
		_band_t = 0.0
	heat_fill = clampf(_band_t / HOLD, 0.0, 1.0) if band > _band_counted and not brew.is_empty() else 0.0


func _eyes() -> void:
	# The customer looks at you (just over the pot)
	var o := selected_order()
	if not o.is_empty() and is_instance_valid(o.customer):
		o.customer.look_at_point = camera.global_position + Vector3(0, -0.6, 0)


func selected_order() -> Dictionary:
	return orders[selected] if selected >= 0 and selected < orders.size() else {}


# --- customers ---

func _new_order() -> void:
	var pool := Book.potions_for(night)
	var open := orders.map(func(o: Dictionary) -> int: return o.potion)
	var choices := pool.filter(func(p: int) -> bool: return not open.has(p))
	if choices.is_empty():
		choices = pool
	# The newest potions turn up more often, so each night's new recipes get made
	var weights := choices.map(func(p: int) -> float: return 2.5 if Book.POTIONS[p].night == night else 1.0)
	var total := 0.0
	for w: float in weights:
		total += w
	var r := randf() * total
	var potion: int = choices[0]
	for i in choices.size():
		r -= weights[i]
		if r <= 0.0:
			potion = choices[i]
			break
	var kinds := Book.CUSTOMERS.map(func(c: Dictionary) -> String: return c.model)
	var used := orders.map(func(o: Dictionary) -> String: return o.who.model)
	var free := range(Book.CUSTOMERS.size()).filter(func(i: int) -> bool: return not used.has(kinds[i]))
	var who: Dictionary = Book.CUSTOMERS[free[randi() % free.size()]]
	var steps := Book.steps_of(Book.POTIONS[potion].recipe)
	var full := Book.patience(steps.size(), night)
	var customer := Witch.make(who.model)
	customer.add_to_group("customer")
	customer.position = Hut.WINDOW_SPOT
	customer.scale = Vector3.ONE * 1.05
	view.add_child(customer)
	_next_order_id += 1
	var o := {"id": _next_order_id, "potion": potion, "steps": steps, "patience": full, "full": full,
			"customer": customer, "who": who, "colour": Book.colour_of(Book.POTIONS[potion].recipe), "born": clock}
	orders.append(o)
	Sfx.play("tap", 0.6)
	if selected < 0:
		select(orders.size() - 1)
	else:
		customer.duck(true)
		hud.bump(orders.size() - 1)


func select(i: int) -> void:
	if i < 0 or i >= orders.size() or i == selected:
		return
	var old := selected_order()
	if not old.is_empty() and is_instance_valid(old.customer):
		old.customer.duck(true)
	selected = i
	var o := orders[i]
	o.customer.duck(false)
	var line: String = Book.ORDER_LINES[o.id % Book.ORDER_LINES.size()] % Book.POTIONS[o.potion].name
	_say_folk(line, o.who.voice, o.customer)
	Sfx.play("tap")


func _storm_off(i: int) -> void:
	var o := orders[i]
	if is_instance_valid(o.customer):
		o.customer.duck(false)
		o.customer.angry()
	Sfx.play("huff")
	combo = 0
	lost += 1
	_say_witch(Book.rhyme("angry"))
	_remove_order(i)


func _remove_order(i: int) -> void:
	var was_selected := i == selected
	orders.remove_at(i)
	if selected > i:
		selected -= 1
	elif was_selected:
		selected = -1
		if not orders.is_empty():
			# The next one up is whoever has waited longest
			selected = 0
			var o := orders[0]
			if is_instance_valid(o.customer):
				o.customer.duck(false)
				var line: String = Book.ORDER_LINES[o.id % Book.ORDER_LINES.size()] % Book.POTIONS[o.potion].name
				_say_folk(line, o.who.voice, o.customer)


# --- what she does at the cauldron ---

## A key (or anything not dragged): it's thrown in from the table
func add(which: int) -> void:
	if not _brewing() or not stocked(which):
		return
	hut.poke("jar%d" % which)
	hut.toss(which, _land)


## Picks an ingredient up off the table, to carry over to the pot
func grab(which: int, at: Vector2) -> void:
	if not _brewing() or not stocked(which):
		hut.poke("jar%d" % which, true)
		Sfx.play("huff", 1.5, -8.0)
		return
	if is_instance_valid(_held):
		_held.queue_free()
	_held = hut.hold(which)
	_held_which = which
	_held_from = at
	_held_to = _held.global_position
	Sfx.play("tap", 0.8)


func drag_to(at: Vector2) -> void:
	# It stays put till the finger has really moved off it
	if is_instance_valid(_held) and at.distance_to(_held_from) > 30.0:
		_held_from = Vector2(-9999, -9999)
		_held_to = _over(at)
	elif is_instance_valid(_held) and _held_from.x < -9000.0:
		_held_to = _over(at)


## Lets go of what's held: into the pot, or back to the table
func release() -> void:
	if not is_instance_valid(_held):
		return
	var bit := _held
	_held = null
	if hut.over_pot(bit.global_position) and _brewing():
		hut.drop(bit, _held_which, _land)
	else:
		hut.drop(bit, _held_which, _land)
		if not hut.over_pot(bit.global_position):
			_float("Drop it in the pot!", screen_of(bit.global_position), Color("ffe8a0"))


## Where a finger on the screen is, out over the pot at the height things are carried
func _over(at: Vector2) -> Vector3:
	var p := at * (Vector2(view.size) / get_viewport().get_visible_rect().size)
	var from := camera.project_ray_origin(p)
	var dir := camera.project_ray_normal(p)
	var height := Hut.CAULDRON_RIM + 0.45
	if absf(dir.y) < 0.001:
		return from
	var t := (height - from.y) / dir.y
	return from + dir * maxf(t, 0.0)


## Something landed in the brew: it does its thing (more, the fuller the pot), and counts as a step
func _land(which: int, at: Vector3) -> void:
	if not _brewing():
		return
	var ing: Dictionary = Book.INGREDIENTS[which]
	var fx: String = ing.fx
	var c := Book.combo(_last_added, which) if _last_added >= 0 else []
	var strength := 1.0 + 0.3 * _added_count
	if not c.is_empty():
		fx = c[2]
		_float(c[3], screen_of(Vector3(0, Hut.CAULDRON_RIM + 0.8, 0)), Color("ffe060"), true)
		Sfx.play("zap", 0.7, -4.0)
	hut.react(fx, ing.brew, strength, at)
	Sfx.play("plop", randf_range(0.9, 1.15))
	_last_added = which
	_added_count += 1
	if mode == "shop":
		stock[which] = maxi(0, stock[which] - 1)
		_show_stock()
	_record({"kind": Book.ADD, "what": which})


func pump() -> void:
	if not _brewing():
		return
	heat = minf(100.0, heat + PUMP)
	Sfx.play("puff", randf_range(0.9, 1.1), -3.0)
	hut.squeeze()
	hut.poke("bellows")


func zap() -> void:
	if not _brewing() or night < 3 and mode == "shop":
		return
	hut.wave_wand()
	Sfx.play("zap")
	_record({"kind": Book.ZAP})


## Bottles what's in the pot: in the shop it goes to the customer, brewing freely it goes up the tower
func bottle() -> void:
	if not _brewing():
		return
	if brew.is_empty():
		Sfx.play("huff", 1.4, -6.0)
		hut.poke("bottle", true)
		_float("The pot's empty!", screen_of(Vector3(0, Hut.CAULDRON_RIM + 0.6, 0)), Color("ffd0a0"))
		return
	var result := Lore.resolve(brew)
	_discovered_now = not discoveries.has(result.effect) and result.effect != "nothing"
	_discover(result)
	if mode == "free":
		hut.poke("bottle")
		Sfx.play("cork")
		_to_tower(result)
		return
	if selected_order().is_empty():
		Sfx.play("huff", 1.4, -6.0)
		hut.poke("bottle", true)
		_float("Nobody to sell it to!", screen_of(Vector3(0, Hut.CAULDRON_RIM + 0.6, 0)), Color("ffd0a0"))
		return
	hut.poke("bottle")
	_serve(result)


## The ladle dragged round by `angle` radians (positive with the sun)
## The stick dragged round by `angle` radians (positive with the sun); each whole turn counts
func stir(angle: float) -> void:
	if not _brewing() or night < 2 and mode == "shop" or absf(angle) < 0.0001:
		return
	_stir_angle += angle
	hut.stir_angle = _stir_angle
	_stir_seen = 0.25
	hut.stir_to(_stir_angle)
	_stir_sound += absf(angle)
	if _stir_sound > PI * 0.6:
		_stir_sound = 0.0
		Sfx.play("slosh", randf_range(0.85, 1.15), -4.0)
	var dir := 1 if angle > 0.0 else -1
	if dir != _stir_dir:
		_stir_dir = dir
		_stir_run = 0.0
	_stir_run += absf(angle)
	if _stir_run >= TAU:
		_stir_run -= TAU
		if brew.is_empty():
			return
		_record({"kind": Book.STIR, "dir": dir, "turns": 1})
		Sfx.play("tap", 1.3 if dir > 0 else 1.1, -3.0)
	stir_fill = _stir_run / TAU


func _brewing() -> bool:
	return state == "play" and not paused and spoil_t <= 0.0


## Whether an ingredient is on the table now: in the shop, as the nights bring them; brewing freely, all
func stocked(which: int) -> bool:
	return mode == "free" or (which < Book.ingredients_on(night) and stock[which] > 0)


## Puts the table right: what's there to use, and how many
func _show_stock() -> void:
	var avail := []
	for i in 8:
		avail.append(stocked(i))
	hut.show_stock(avail)


func _keys_stir(dt: float) -> void:
	var d := 0.0
	if _keys_down.get(KEY_RIGHT, false) or _keys_down.get(KEY_D, false):
		d += 1.0
	if _keys_down.get(KEY_LEFT, false) or _keys_down.get(KEY_A, false):
		d -= 1.0
	if d != 0.0:
		stir(d * KEY_STIR_SPEED * dt)


## Something was done to the brew: right if it's the next step, spoilt if not
## Something was done to the brew: written down (a turn of the stick the same way as the last adds
## to it; the fire's heat counts once, at its hottest), and the brew takes the colour of it all
func _record(step: Dictionary) -> void:
	var last: Dictionary = brew[-1] if not brew.is_empty() else {}
	if step.kind == Book.STIR and last.get("kind", -1) == Book.STIR and last.dir == step.dir:
		last.turns += 1
	elif step.kind == Book.HEAT and last.get("kind", -1) == Book.HEAT:
		last.level = maxi(last.level, step.level)
	elif step.kind == Book.ZAP and last.get("kind", -1) == Book.ZAP:
		return
	else:
		if brew.size() >= MAX_STEPS:
			_spoil(Book.rhyme("spoil"), "The pot's too full!")
			return
		brew.append(step.duplicate())
	done_kinds[step.kind] = done_kinds.get(step.kind, 0) + 1
	hut.set_brew(Lore.resolve(brew).colour)
	hud.tick_step(brew.size() - 1)


## Tips the pot out to start again
func tip_out() -> void:
	if not _brewing() or brew.is_empty():
		return
	hut.poof()
	hut.fresh()
	Sfx.play("slosh", 0.6)
	_reset_brew()


## A brew bottled for the first time is written in the book, with how it was made
func _discover(result: Dictionary) -> void:
	if result.effect == "nothing" or discoveries.has(result.effect):
		return
	discoveries[result.effect] = {"name": Lore.name_of(result), "steps": brew.duplicate(true)}
	_float("New in the book: " + String(result.effect).capitalize() + "!", screen_of(Vector3(0, Hut.CAULDRON_RIM + 1.0, 0)), Color("c8f0ff"))
	_save()


func _spoil(rhyme: String, short := "") -> void:
	spoil_t = 1.5
	combo = 0
	hut.set_brew(Color("6a5a3a"), true)
	hut.poof()
	Sfx.play("blorp")
	_say_witch(rhyme)
	if short != "":
		_float(short, screen_of(Vector3(0, Hut.CAULDRON_RIM + 0.6, 0)), Color("ff9a8a"))


func _reset_brew() -> void:
	brew.clear()
	_last_added = -1
	_added_count = 0
	_hold = 0.0
	_band_t = 0.0
	_band_counted = 0
	_stir_run = 0.0
	spoil_t = 0.0


## Hands the brew over. What it does is what counts: the potion she asked for, made any way at all,
## pays (more for a strong one, and a tip for speed); anything else she drinks anyway, and you see
## what it does to her before she storms off
func _serve(result: Dictionary) -> void:
	var i := selected
	var o := orders[i]
	var wanted: String = Book.POTIONS[o.potion].effect
	Sfx.play("cork")
	if result.effect == wanted:
		var base: int = 15 + (o.steps.size() - 1) * 5 + result.potency * 3
		var tip := int(round(base * 0.6 * clampf(o.patience / o.full, 0.0, 1.0)))
		combo += 1
		var coins: int = base + tip + mini(combo - 1, 5) * 3
		night_coins += coins
		score += coins
		served += 1
		learned[o.potion] = true
		Sfx.play("coins", 1.0, -2.0)
		Sfx.play("cheer", 1.0, -4.0)
		var at := screen_of(Hut.WINDOW_HEAD + Vector3(0, 0.2, 0.3))
		_float("+%d" % coins, at, Color("ffe060"), true)
		if combo > 1:
			_float("Combo x%d!" % combo, at + Vector2(0, 50), Color("a0ffb0"))
		_fly_bottle(result.colour, o.customer, func(c: Witch) -> void: c.happy())
		if randf() < 0.6:
			_say_witch(Book.rhyme("serve"))
	else:
		combo = 0
		lost += 1
		Sfx.play("huff")
		_float(Lore.name_of(result) + "?!", screen_of(Hut.WINDOW_HEAD + Vector3(0, 0.3, 0.3)), Color("ff9a8a"))
		_fly_bottle(result.colour, o.customer, func(c: Witch) -> void: c.drink(result, true))
		_say_witch(Book.rhyme("wrong"))
	_remove_order(i)
	hut.fresh()
	_reset_brew()


func _fly_bottle(col: Color, customer: Witch, then: Callable) -> void:
	var b := Node3D.new()
	b.add_child(Models.make("potion", Shape.mat(0.3)))
	var liquid := Shape.mat(0.35)
	liquid.set_shader_parameter("tint", Shape.lin3(col))
	b.add_child(Models.make("potion_liquid", liquid))
	view.add_child(b)
	var from := Vector3(0, Hut.CAULDRON_RIM + 0.2, 0)
	var to := Hut.WINDOW_HEAD + Vector3(0.2, -0.45, 0.45)
	var tw := create_tween()
	tw.tween_method(func(t: float) -> void:
		b.position = from.lerp(to, t) + Vector3(0, sin(t * PI) * 1.1, 0)
		b.rotation.z = t * TAU, 0.0, 1.0, 0.55)
	tw.tween_callback(func() -> void:
		b.queue_free()
		if is_instance_valid(customer):
			then.call(customer))


# --- talk ---

func _say_witch(text: String) -> void:
	speech = {"who": "witch", "text": text, "shown": 0.0, "life": 2.2 + text.length() * 0.045, "voice": 1.0}


func _say_folk(text: String, voice: float, customer: Witch) -> void:
	if speech.get("who", "") == "witch" and speech.shown < speech.text.length():
		return
	speech = {"who": "folk", "text": text, "shown": 0.0, "life": 1.6 + text.length() * 0.04, "voice": voice, "customer": customer}


func _update_speech(dt: float) -> void:
	if speech.is_empty():
		return
	var before := int(speech.shown)
	speech.shown = minf(speech.text.length(), speech.shown + dt * 38.0)
	var now := int(speech.shown)
	var talking: bool = now < speech.text.length()
	for k in range(before, now):
		var ch: String = speech.text[k]
		if k % 3 == 0 and ch != " " and ch != "\n":
			Sfx.say("witch" if speech.who == "witch" else "folk", speech.voice)
	var c: Variant = speech.get("customer")
	if c != null and is_instance_valid(c):
		(c as Witch).talking = talking
	if not talking:
		speech.life -= dt
		if speech.life <= 0.0:
			if c != null and is_instance_valid(c):
				(c as Witch).talking = false
			speech = {}


func _float(text: String, at: Vector2, col: Color, big := false) -> void:
	floaters.append({"text": text, "pos": at, "t": 0.0, "col": col, "big": big})


# --- keys (touch and mouse go through the hud) ---

func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null:
		return
	_keys_down[key.keycode] = key.pressed
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_ESCAPE, KEY_P:
			if book_open:
				toggle_book()
			else:
				toggle_pause()
			return
	if state == "title":
		if key.keycode in [KEY_SPACE, KEY_ENTER]:
			start_game()
		elif key.keycode == KEY_F:
			start_free()
		return
	if state == "tower":
		if key.keycode in [KEY_SPACE, KEY_ENTER]:
			back_from_tower()
		return
	if state == "swamp":
		if key.keycode in [KEY_SPACE, KEY_ENTER]:
			leave_swamp()
		elif key.keycode >= KEY_1 and key.keycode <= KEY_8:
			gather_at(screen_of(swamp.spots.get("gather%d" % (key.keycode - KEY_1), {"at": Vector3.ZERO}).at))
		return
	if state == "intro":
		begin_play()
		return
	if state in ["done", "over"]:
		if key.keycode in [KEY_SPACE, KEY_ENTER]:
			next_night()
		return
	if paused:
		return
	match key.keycode:
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8:
			add(key.keycode - KEY_1)
		KEY_SPACE, KEY_UP, KEY_W:
			pump()
		KEY_Z, KEY_X:
			zap()
		KEY_ENTER, KEY_B, KEY_DOWN, KEY_S:
			bottle()
		KEY_TAB:
			if not orders.is_empty():
				select((selected + 1) % orders.size())
		KEY_R:
			toggle_book()
		KEY_BACKSPACE, KEY_DELETE:
			tip_out()


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(save_path) == OK:
		best = cfg.get_value("shop", "best", 0)
		n64 = cfg.get_value("shop", "n64", true)
		discoveries = cfg.get_value("shop", "discoveries", {})
		Sfx.set_muted(not cfg.get_value("shop", "sound", true))


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("shop", "best", best)
	cfg.set_value("shop", "sound", not sfx.muted)
	cfg.set_value("shop", "n64", n64)
	cfg.set_value("shop", "discoveries", discoveries)
	cfg.save(save_path)
