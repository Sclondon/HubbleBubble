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
const N64_LINES := 260.0
## The render layer smoke is on: drawn sharp at near full size over the soft N64 picture
const SMOKE_LAYER := 4

## "play" (at the cauldron), "intro", "done", "over" (the cards of a night), "swamp", "tower" (the balcony)
var state := "play"
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
## "shop" (the counter open, a night on) or "free" (shut: brewing whatever you like, tried out on the balcony)
var mode := "free"
## Whether a run of nights is under way (it carries on from one night to the next until one is failed)
var run_active := false
## Black over everything while the view moves between the hut, the swamp and the balcony (0 to 1)
var fade := 0.0
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
var _speech_queue: Array[Dictionary] = []
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
## The 3D, drawn small in here and blown up soft (the N64 filter, always on)
var view: SubViewport
var screen: TextureRect
var n64 := true
## The floating book's two pages, drawn by a second Hud into their own little picture
var pages_view: SubViewport
## The smoke, drawn by a camera of its own at near full size, laid over the N64 picture
var smoke_view: SubViewport
var smoke_camera: Camera3D
var smoke_screen: TextureRect
var pages_hud: Hud
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
var _boot_t := 0.0
## How near the middle of the last thing picked the point was (0 dead on, 1 at its edge)
var pick_k := 1.0
## "night" (between nights) or "visit" (from the title): where the swamp goes back to
var swamp_from := "night"
var _held: Node3D
var _held_which := 0
## "bit" (an ingredient) or "bottle" (an empty jar to scoop the brew up in), and how full the jar is
var _held_kind := "bit"
var _fill := 0.0
var _finger_stir := false
var _stir_last := Vector2.INF
var _moving := false
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
	view.world_3d = World3D.new()
	add_child(view)
	smoke_view = SubViewport.new()
	smoke_view.name = "smoke_view"
	smoke_view.transparent_bg = true
	smoke_view.world_3d = view.world_3d
	smoke_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	smoke_view.msaa_3d = Viewport.MSAA_2X
	add_child(smoke_view)
	smoke_camera = Camera3D.new()
	smoke_camera.cull_mask = SMOKE_LAYER
	var clear := Environment.new()
	clear.background_mode = Environment.BG_CLEAR_COLOR
	clear.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	clear.ambient_light_color = Color.WHITE
	smoke_camera.environment = clear
	smoke_camera.current = true
	smoke_view.add_child(smoke_camera)
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
	smoke_screen = TextureRect.new()
	smoke_screen.name = "smoke"
	smoke_screen.texture = smoke_view.get_texture()
	smoke_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	smoke_screen.stretch_mode = TextureRect.STRETCH_SCALE
	smoke_screen.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	smoke_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var premul := CanvasItemMaterial.new()
	premul.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	smoke_screen.material = premul
	under.add_child(smoke_screen)
	var env := WorldEnvironment.new()
	env.environment = _atmosphere()
	view.add_child(env)
	hut = Hut.new()
	hut.name = "hut"
	view.add_child(hut)
	tower = Tower.new()
	tower.name = "tower"
	tower.position = Vector3.ZERO
	view.add_child(tower)
	swamp = Swamp.new()
	swamp.name = "swamp"
	swamp.position = Vector3(-400, 0, 0)
	view.add_child(swamp)
	# (the swamp is gone: ingredients come back each night)
	swamp.visible = false
	swamp.process_mode = Node.PROCESS_MODE_DISABLED
	camera = Camera3D.new()
	camera.name = "camera"
	camera.current = true
	camera.cull_mask = 0xFFFFF & ~SMOKE_LAYER
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
	pages_view = SubViewport.new()
	pages_view.name = "pages"
	pages_view.size = Vector2i(1100, 760)
	pages_view.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(pages_view)
	pages_hud = Hud.new()
	pages_hud.shop = self
	pages_hud.page_only = true
	pages_view.add_child(pages_hud)
	hut.set_book_pages(pages_view.get_texture())
	get_viewport().size_changed.connect(_frame)
	_load()
	_frame()
	_to_hut()


func _frame() -> void:
	var s := get_viewport().get_visible_rect().size
	# The N64 filter: the 3D is drawn this many lines on its short side, then blown up soft
	var k := N64_LINES / minf(s.x, s.y)
	view.size = Vector2i(maxi(2, roundi(s.x * k)), maxi(2, roundi(s.y * k)))
	var ks := minf(1.0, 1400.0 / maxf(s.x, s.y))
	smoke_view.size = Vector2i(maxi(2, roundi(s.x * ks)), maxi(2, roundi(s.y * ks)))
	(screen.material as ShaderMaterial).set_shader_parameter("amount", 1.0)
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
		# Up the periscope out of the roof
		camera.keep_aspect = Camera3D.KEEP_WIDTH if tall else Camera3D.KEEP_HEIGHT
		camera.fov = 46.0 if tall else 40.0
		_scope_camera(1.0)
	elif tall:
		# Phone: framed by width; you lean over the pot and look down into it, the counter beyond
		camera.keep_aspect = Camera3D.KEEP_WIDTH
		camera.fov = 44.0
		var spare := clampf((s.y / s.x - 2.17) * 1.2, -0.9, 0.6)
		# (a shorter screen shows less top to bottom: back off and up, to keep it all in)
		var back := maxf(0.0, -spare)
		camera.position = Vector3(0, 2.7 + maxf(spare, 0.0) * 0.2 + back * 0.25, 2.55 + maxf(spare, 0.0) * 0.5 + back * 0.45)
		camera.look_at(Vector3(0, 1.45, -1.0))
	else:
		# Wide: framed by height, close enough that the walls either side don't take over
		camera.keep_aspect = Camera3D.KEEP_HEIGHT
		camera.fov = 56.0
		camera.position = Vector3(0, 2.95, 3.3)
		camera.look_at(Vector3(0, 1.3, -1.0))
	if hud != null:
		hud.layout()


## The periscope's head, out of the hut's roof, turned on whoever's out there with a potion (or the
## village, if nobody), easing round to follow her
const SCOPE_AT := Vector3(-0.6, 5.2, -3.9)
var _scope_look := Vector3(0, 0, -18)


func _scope_camera(ease_k: float) -> void:
	var want := Vector3(0, 0.5, -18)
	if is_instance_valid(tower.tester):
		want = tower.tester.global_position + Vector3(0, 1.3, 0)
	_scope_look = _scope_look.lerp(want, ease_k)
	camera.position = SCOPE_AT
	camera.look_at(_scope_look)


## Dark and close: a dim violet ambient, fog gathering in the corners, a glow round bright things
func _atmosphere() -> Environment:
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.03, 0.02, 0.05)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.05, 0.045, 0.08)
	e.ambient_light_energy = 1.0
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 1.45
	e.fog_enabled = true
	e.fog_light_color = Color(0.1, 0.07, 0.16)
	e.fog_density = 0.018
	e.fog_aerial_perspective = 0.0
	e.glow_enabled = true
	e.glow_intensity = 0.7
	e.glow_bloom = 0.08
	e.glow_hdr_threshold = 0.9
	return e


## The floating book shows the pages it was left open at (redrawn when they change, and while
## the book's pictures are still being taken)
func show_book_pages() -> void:
	pages_hud.page_shown = hud.book_page
	pages_hud.queue_redraw()
	pages_view.render_target_update_mode = SubViewport.UPDATE_ONCE


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
	pick_k = best_k
	return best


func spot_screen(id: String) -> Vector2:
	return screen_of(hut.spots[id].at)


## Something in the hut tapped
func tap(id: String) -> void:
	match id:
		"shutters":
			toggle_shop()
		"tap":
			drain()
		"swamp_window":
			visit_swamp()
		"balcony":
			visit_balcony()
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


## Whether a point on the screen is on the brew (an oval, seen at an angle)
func on_brew(at: Vector2) -> bool:
	var c := screen_of(Vector3(0, Hut.BREW_LEVEL, 0))
	var rx := absf(screen_of(Vector3(Hut.BREW_R, Hut.BREW_LEVEL, 0)).x - c.x)
	var ry := absf(screen_of(Vector3(0, Hut.BREW_LEVEL, Hut.BREW_R)).y - c.y)
	var d := (at - c) / Vector2(maxf(rx, 1.0), maxf(ry, 1.0))
	return d.length() < 0.95


func cauldron_screen() -> Array:
	var c := screen_of(Vector3(0, Hut.CAULDRON_RIM, 0))
	var e := screen_of(Vector3(0.9, Hut.CAULDRON_RIM, 0))
	return [c, absf(e.x - c.x)]


# --- the flow of a game ---

## At the cauldron with the counter shut: brewing whatever you like, nobody waiting
func _to_hut() -> void:
	state = "play"
	mode = "free"
	paused = false
	orders.clear()
	selected = -1
	_clear_customers()
	hut.open_shop(false)
	hut.fresh()
	_reset_brew()
	_show_stock()
	heat = 20.0
	Sfx.music(false)


## The counter shutters: thrown open, the shop opens for the night (a new run, or the next night of
## this one); swung shut while a night's on, it ends there and then
func toggle_shop() -> void:
	if state == "play" and mode == "free":
		if not run_active:
			start_game()
		else:
			mode = "shop"
			_start_night()
		hut.open_shop(true)
		Sfx.play("tap", 0.7)
	elif mode == "shop" and state in ["play", "intro"]:
		_close_shop()


func start_game() -> void:
	mode = "shop"
	run_active = true
	for i in 8:
		stock[i] = maxi(stock[i], 4)
	night = 1
	score = 0
	learned = {}
	done_kinds = {}
	combo = 0
	hut.open_shop(true)
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
	_reset_brew()
	_show_stock()
	for i in 8:
		stock[i] = maxi(stock[i], 4)
	_show_stock()
	clock = Book.night_length(night)
	_spawn_t = 1.2
	_tick = 0
	news = ""
	match night:
		1:
			news = "Customers will ask for potions by name. Look them up in the book!"
		2:
			news = "New: stirring! Drag the stick round the pot."
		3:
			news = "New: the magic wand, and Moon Petals!"
		4:
			news = "The busiest nights are coming."
	Sfx.play("night")
	hut.night_progress(0.0)


## Brewing whatever you like, no customers and no clock; bottled brews are tried out on the balcony
func start_free() -> void:
	_to_hut()


## Moves the view somewhere else in a blink: a dip to black, `then` called in the dark, and back up
func _move(then: Callable) -> void:
	if _moving:
		return
	_moving = true
	var tw := create_tween()
	tw.tween_property(self, "fade", 1.0, 0.22)
	tw.tween_callback(func() -> void:
		then.call()
		_frame())
	tw.tween_property(self, "fade", 0.0, 0.3)
	tw.tween_callback(func() -> void: _moving = false)


## Out onto the balcony, where a witch tries the brew
func _to_tower(result: Dictionary) -> void:
	tower_result = result
	tower_new = _discovered_now
	tower_t = 0.0
	hut.fresh()
	_reset_brew()
	_move(func() -> void:
		state = "tower"
		tower.try_out(result))


## Through the door onto the balcony with nothing to try: the witch waits there to be brought something
func visit_balcony() -> void:
	if state != "play" or paused:
		return
	tower_result = {}
	tower_t = 9.0
	tower_new = false
	_move(func() -> void:
		state = "tower"
		if is_instance_valid(tower.tester):
			tower_result = {"effect": tower.tester._effect, "potency": tower.tester._potency, "colour": Color.WHITE} if tower.tester._effect != "" else {})


## Back in from the balcony
func back_from_tower() -> void:
	if state != "tower" or tower_t < 0.5:
		return
	Sfx.play("tap")
	_move(func() -> void: state = "play")


## The swamp and the balcony are only for when the counter's shut
func _away_ok() -> bool:
	if state != "play" or mode != "free" or paused:
		if state == "play" and mode == "shop":
			Sfx.play("huff", 1.5, -8.0)
		return false
	return true


## Still warming up: the first moments, and while the book's pictures are taken
func loading() -> bool:
	return _boot_t < 0.8 or (album != null and album.is_processing() and _boot_t < 8.0)


## Out of the back window to the swamp, to gather (what's gathered keeps)
func visit_swamp() -> void:
	if not _away_ok():
		return
	swamp_from = "visit"
	_move(func() -> void:
		state = "swamp"
		swamp.open_for(8)
		Sfx.music(true, 0.9))


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
		Sfx.play("huff", 1.5, -8.0)
		return
	if swamp.gather(i):
		stock[i] += 1


## Back in through the window
func leave_swamp() -> void:
	if state != "swamp":
		return
	Sfx.music(false)
	_save()
	_move(func() -> void:
		state = "play"
		_show_stock())


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
	hut.open_shop(false)
	if night_coins >= Book.quota(night):
		state = "done"
		Sfx.play("win")
	else:
		state = "over"
		Sfx.play("lose")
		run_active = false
		if score > best and not testing:
			best = score
			_save()
		# Hand the score to the hosting page (the Scareathon arcade cabinet) for its leaderboard
		if OS.has_feature("web") and score > 0 and not testing:
			JavaScriptBridge.eval("window.parent.postMessage({ type: 'PLAYER_DIED', score: %d }, '*')" % score, true)
	intro_t = 0.0


## A tap on the card at the end of a night: back to the cauldron with the counter shut (open it
## again for the next night)
func next_night() -> void:
	if intro_t < 1.0:
		return
	if state == "done":
		night += 1
	elif state == "over":
		night = 1
	else:
		return
	_to_hut()


func toggle_pause() -> void:
	if state in ["play", "intro", "tower", "swamp"]:
		paused = not paused
		book_open = false
		Sfx.music(not paused and state == "play" and mode == "shop")
		Sfx.play("tap")


func toggle_book() -> void:
	book_open = not book_open
	if not book_open:
		show_book_pages()
	if book_open and not selected_order().is_empty():
		selected_order().looked = true
	Sfx.play("tap")


func set_sound(on: bool) -> void:
	Sfx.set_muted(not on)
	_save()
	if on and state == "play" and not paused:
		Sfx.music(true)


func _clear_customers() -> void:
	_speech_queue.clear()
	for c in get_tree().get_nodes_in_group("customer"):
		c.queue_free()


# --- every frame ---

func _process(dt: float) -> void:
	_boot_t += dt
	smoke_camera.global_transform = camera.global_transform
	smoke_camera.fov = camera.fov
	smoke_camera.keep_aspect = camera.keep_aspect
	# The floating book keeps up on the left of the view beside the pot, whatever its shape
	if state == "play" or state == "intro":
		hut._book_home = camera.project_position(Vector2(view.size) * Vector2(0.15, 0.42), 2.6)
		hut.spots["book"].at = hut._book_home
		hut.spots["book"].r = 0.22
		# and the bellows at the lower right, by the fire
		var bp := camera.project_position(Vector2(view.size) * Vector2(0.84, 0.83), 2.4)
		hut.props["bellows"].position = bp
		# its nozzle turned on the fire
		var to_fire := Vector3(0, 0.15, 0) - bp
		hut.props["bellows"].rotation = Vector3(0, atan2(to_fire.z, -to_fire.x), clampf(atan2(-to_fire.y, Vector2(to_fire.x, to_fire.z).length()), -0.6, 0.6))
		hut.spots["bellows"].at = bp + Vector3(0, 0.12, 0)
		hut.spots["bellows"].r = 0.28
	if album != null and album.is_processing() and int(_boot_t * 2.0) != int((_boot_t - dt) * 2.0):
		show_book_pages()
	_update_speech(dt)
	if is_instance_valid(_held):
		var to := _held_to
		if _held_kind == "bottle" and hut.over_pot(_held.global_position) and _brewing() and not brew.is_empty():
			# Dipped into the brew, it fills (glugging) till it's full
			to.y = Hut.BREW_LEVEL - 0.08
			if _held.global_position.y < Hut.BREW_LEVEL + 0.12 and _fill < 1.0:
				_fill = minf(1.0, _fill + dt / 0.8)
				hut.fill_bottle(_held, _fill, Lore.resolve(brew).colour)
				hut.brew.ripple(Vector2(_held.global_position.x, _held.global_position.z), 0.25)
				if randf() < dt * 8.0:
					Sfx.play("bubble", randf_range(1.2, 1.6), -6.0)
				if _fill >= 1.0:
					Sfx.play("cork", 1.2, -4.0)
		elif _held_kind == "bottle" and _fill >= 1.0:
			to.y = maxf(to.y, Hut.CAULDRON_RIM + 0.25)
		hut.carry(_held, to, dt)
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
		_scope_camera(minf(1.0, dt * 3.0))
		# the shop keeps going while you watch
		if mode == "shop":
			_play(dt)
	elif state != "swamp":
		heat = move_toward(heat, 12.0, dt * 5.0)
	hut.heat = heat
	_bubble_t -= dt
	if _bubble_t < 0.0 and state in ["play", "intro"]:
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
	hut.stirring = _finger_stir or _stir_seen > 0.0
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
	if is_instance_valid(o.customer):
		_say_folk(Book.line("angry"), o.who.voice, o.customer, true)
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
	_held_kind = "bit"
	_held_which = which
	_held_from = at
	_held_to = _held.global_position
	Sfx.play("tap", 0.8)


## Takes an empty jar off the tray, to dip in the brew and fill by hand
func grab_bottle(at: Vector2) -> void:
	if not _brewing():
		return
	if is_instance_valid(_held):
		_held.queue_free()
	_held = hut.hold_bottle()
	_held_kind = "bottle"
	_fill = 0.0
	_held_from = at
	_held_to = _held.global_position
	Sfx.play("tap", 0.7)


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
	if _held_kind == "bottle":
		# Full, it's handed over (or taken out to the balcony); not full, it goes back on the tray
		if _fill >= 1.0 and _brewing() and _bottle_from(bit.global_position):
			bit.queue_free()
		else:
			hut.return_bottle(bit)
		_fill = 0.0
		return
	hut.drop(bit, _held_which, _land)


## Where a finger on the screen is, out over the pot at the height things are carried
func _over(at: Vector2) -> Vector3:
	var p := _on_plane(at, Hut.CAULDRON_RIM + 0.12)
	# Up over the counter the level plane runs away toward the horizon: there, it's held up on an
	# upright plane in front of the counter instead, so it follows the finger without jumping
	if p.z < -1.5 or p.distance_to(camera.global_position) > 6.0:
		var sp := at * (Vector2(view.size) / get_viewport().get_visible_rect().size)
		var from := camera.project_ray_origin(sp)
		var dir := camera.project_ray_normal(sp)
		if dir.z < -0.001:
			var t := (-1.5 - from.z) / dir.z
			p = from + dir * t
	p.y = clampf(p.y, Hut.CAULDRON_RIM + 0.05, 3.4)
	p.x = clampf(p.x, -1.9, 1.9)
	p.z = clampf(p.z, -1.5, 1.2)
	return p


## Where a point on the screen is on the level plane at `height`
func _on_plane(at: Vector2, height: float) -> Vector3:
	var p := at * (Vector2(view.size) / get_viewport().get_visible_rect().size)
	var from := camera.project_ray_origin(p)
	var dir := camera.project_ray_normal(p)
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
	# It stays bobbing on the brew till the fire cooks it
	hut.brew.float_in(Hut.ONE_MODELS[which], at - Vector3(0, Hut.BREW_LEVEL, 0))
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
	# the puff goes into the fire
	hut.fire.blow(hut.props["bellows"].global_position)
	hut.poke("bellows")


func zap() -> void:
	if not _brewing() or night < 3 and mode == "shop":
		return
	hut.wave_wand()
	Sfx.play("zap")
	_record({"kind": Book.ZAP})


## Bottles what's in the pot: in the shop it goes to the customer, brewing freely it goes up the tower
## (A key: scooped up and handed over at once)
func bottle() -> void:
	if _brewing():
		_bottle_from(Vector3(0, Hut.CAULDRON_RIM + 0.2, 0))


## A jar full of the brew, held at `from`: sold to the customer at the window, or (the counter shut)
## taken out to the balcony to be tried. False if there's nothing to bottle or nobody to have it.
func _bottle_from(from: Vector3) -> bool:
	if brew.is_empty():
		Sfx.play("huff", 1.4, -6.0)
		hut.poke("bottle", true)
		return false
	if mode == "shop" and selected_order().is_empty():
		Sfx.play("huff", 1.4, -6.0)
		hut.poke("bottle", true)
		return false
	var result := Lore.resolve(brew)
	_discovered_now = not discoveries.has(result.effect) and result.effect != "nothing"
	_discover(result)
	if mode == "free":
		Sfx.play("cork")
		_to_tower(result)
		return true
	_serve(result, from)
	return true


## The ladle dragged round by `angle` radians (positive with the sun)
## The stick dragged round by `angle` radians (positive with the sun); each whole turn counts
func stir(angle: float) -> void:
	if not _brewing() or absf(angle) < 0.0001:
		return
	_stir_angle += angle
	hut.brew.spin = _stir_angle
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
		_stir_seen = 0.25
		hut.stir_at(Vector3(cos(_stir_angle), 0, sin(_stir_angle)) * 0.45)


## A finger on the brew: the stick's tip goes where it is, and going round the middle stirs
func stir_touch(at: Vector2) -> void:
	if not _brewing():
		return
	var p := _on_plane(at, Hut.BREW_LEVEL)
	hut.stir_at(p)
	_finger_stir = true
	var flat := Vector2(p.x, p.z).limit_length(Hut.BREW_R - 0.16)
	if flat.length() > 0.12 and _stir_last != Vector2.INF and _stir_last.length() > 0.12:
		stir(wrapf(flat.angle() - _stir_last.angle(), -PI, PI))
	_stir_last = flat


func stir_release() -> void:
	_finger_stir = false
	_stir_last = Vector2.INF


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
	# Brought to heat, what's bobbing in it cooks (the pot rattles, a jingle, and it melts away)
	if step.kind == Book.HEAT and hut.brew.floating() > 0:
		hut.brew.cook()
		Sfx.play("cook", 1.0, -2.0)
	var r := Lore.resolve(brew)
	hut.set_brew(r.colour, false, r.effect if r.effect != "nothing" else "")
	hud.tick_step(brew.size() - 1)


## Opens the tap at the foot of the pot: the brew pours out, and the pot starts again
func drain() -> void:
	if not _brewing():
		return
	hut.pour()
	Sfx.play("slosh", 0.7)
	if not brew.is_empty():
		hut.fresh()
		_reset_brew()


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
func _serve(result: Dictionary, from := Vector3(0, Hut.CAULDRON_RIM + 0.2, 0)) -> void:
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
		_fly_bottle(result.colour, o.customer, func(c: Witch) -> void: tower.send_off(c, result), from)
		_say_folk(Book.line("thanks"), o.who.voice, o.customer, true)
	else:
		combo = 0
		lost += 1
		Sfx.play("huff")
		_float(Lore.name_of(result) + "?!", screen_of(Hut.WINDOW_HEAD + Vector3(0, 0.3, 0.3)), Color("ff9a8a"))
		_fly_bottle(result.colour, o.customer, func(c: Witch) -> void: tower.send_off(c, result, true), from)
		_say_folk(Book.line("wrong"), o.who.voice, o.customer, true)
	_remove_order(i)
	hut.fresh()
	_reset_brew()


func _fly_bottle(col: Color, customer: Witch, then: Callable, from := Vector3(0, Hut.CAULDRON_RIM + 0.2, 0)) -> void:
	var b := Node3D.new()
	b.add_child(Models.make("potion", Shape.mat(0.3)))
	var liquid := Shape.mat(0.35)
	liquid.set_shader_parameter("tint", Shape.lin3(col))
	b.add_child(Models.make("potion_liquid", liquid))
	view.add_child(b)
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

## You don't talk; the customers do
func _say_witch(_text: String) -> void:
	pass


## A customer says something. An urgent line (thanks, a complaint) is said at once; anything else
## waits its turn behind whatever's being said, so nobody's order goes unsaid
func _say_folk(text: String, voice: float, customer: Witch, urgent := false) -> void:
	var line := {"who": "folk", "text": text, "shown": 0.0, "life": 1.6 + text.length() * 0.04, "voice": voice, "customer": customer}
	if speech.is_empty() or urgent:
		speech = line
	else:
		_speech_queue.append(line)


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
		# Someone waiting to speak cuts the pause short
		speech.life -= dt * (3.0 if not _speech_queue.is_empty() else 1.0)
		if speech.life <= 0.0:
			if c != null and is_instance_valid(c):
				(c as Witch).talking = false
			speech = {}
			while not _speech_queue.is_empty() and speech.is_empty():
				var next: Dictionary = _speech_queue.pop_front()
				if next.customer != null and is_instance_valid(next.customer):
					speech = next


## (No floating words: what happens is seen and heard instead)
func _float(_text: String, _at: Vector2, _col: Color, _big := false) -> void:
	pass


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
		KEY_O:
			toggle_shop()
		KEY_T, KEY_G:
			visit_balcony()


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(save_path) == OK:
		best = cfg.get_value("shop", "best", 0)
		discoveries = cfg.get_value("shop", "discoveries", {})
		stock = cfg.get_value("shop", "stock", stock)
		Sfx.set_muted(not cfg.get_value("shop", "sound", true))


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("shop", "best", best)
	cfg.set_value("shop", "sound", not sfx.muted)
	cfg.set_value("shop", "discoveries", discoveries)
	cfg.set_value("shop", "stock", stock)
	cfg.save(save_path)
