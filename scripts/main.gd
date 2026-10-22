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
var progress := 0
## How far along the step that's being done is (heat held, turns stirred), 0 to 1
var step_fill := 0.0
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
var witch: Witch
var hud: Hud
var sfx: Sfx

var _spawn_t := 0.0
var _hold := 0.0
var _boil := 0.0
var _stir_done := 0.0
var _stir_wrong := 0.0
var _stir_stray := 0.0
var _stir_angle := 0.0
var _stir_sound := 0.0
var _stir_seen := 0.0
var _bubble_t := 0.0
var _tick := 0
var _next_order_id := 0
var _last_kind := ""
var _keys_down := {}


func _ready() -> void:
	randomize()
	sfx = Sfx.new()
	sfx.name = "sfx"
	add_child(sfx)
	hut = Hut.new()
	hut.name = "hut"
	add_child(hut)
	witch = Witch.make("witch_grumblewart", true)
	witch.name = "witch"
	witch.position = Vector3(-0.95, 0, -0.85)
	witch.rotation.y = 0.45
	witch.brew = Hut.BREW_LEVEL
	witch.stick = hut.stick
	add_child(witch)
	camera = Camera3D.new()
	camera.name = "camera"
	camera.current = true
	add_child(camera)
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Hud.new()
	hud.shop = self
	hud.name = "hud"
	layer.add_child(hud)
	get_viewport().size_changed.connect(_frame)
	_load()
	_frame()
	_to_title()


func _frame() -> void:
	var s := get_viewport().get_visible_rect().size
	var tall := s.y > s.x * 1.1
	if tall:
		# Phone: the 3D sits between the tickets and the controls, so it is framed by width
		camera.keep_aspect = Camera3D.KEEP_WIDTH
		camera.fov = 54.0
		# Close in and looking well down, so the window, the pot and the stepped table stack up the screen
		var spare := clampf((s.y / s.x - 2.17) * 1.2, -0.5, 0.6)
		camera.position = Vector3(0.25, 3.05 + spare * 0.5, 4.5 + spare * 0.4)
		camera.look_at(Vector3(0.25, 0.78, -0.5))
	else:
		camera.keep_aspect = Camera3D.KEEP_HEIGHT
		camera.fov = 50.0
		camera.position = Vector3(0.25, 3.4, 6.0)
		camera.look_at(Vector3(0.25, 1.32, -0.1))
	if hud != null:
		hud.layout()


func screen_of(p: Vector3) -> Vector2:
	return camera.unproject_position(p)


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
	if id.begins_with("jar"):
		var which := int(id.substr(3))
		if which < Book.ingredients_on(night):
			add(which)
		else:
			hut.poke(id, true)
			Sfx.play("huff", 1.5, -8.0)
		return
	match id:
		"bellows":
			pump()
		"wand":
			if night >= 3:
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
	progress = 0
	spoil_t = 0.0
	night_coins = 0
	served = 0
	lost = 0
	heat = 10.0
	hut.fresh()
	hut.stock(Book.ingredients_on(night))
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
		witch.act("cheer")
		_say_witch(Book.rhyme("night_done"))
	else:
		state = "over"
		Sfx.play("lose")
		witch.act("grumble")
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
		night += 1
		_start_night()
	elif state == "over":
		_to_title()


func toggle_pause() -> void:
	if state in ["play", "intro"]:
		paused = not paused
		book_open = false
		Sfx.music(not paused and state == "play")
		Sfx.play("tap")


func quit_to_title() -> void:
	paused = false
	_to_title()


func toggle_book() -> void:
	book_open = not book_open
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
	for f in floaters:
		f.t += dt
	floaters = floaters.filter(func(f: Dictionary) -> bool: return f.t < 1.4)
	intro_t += dt
	_eyes()
	if paused:
		return
	if state == "play":
		_play(dt)
	else:
		heat = move_toward(heat, 30.0 if state == "title" else 12.0, dt * 5.0)
		if state == "title" and randf() < dt * 0.15:
			witch.act("cackle")
	hut.heat = heat
	_bubble_t -= dt
	if _bubble_t < 0.0 and state != "title":
		_bubble_t = randf_range(0.3, 1.2) / (0.4 + heat / 60.0)
		Sfx.play("bubble", randf_range(0.7, 1.5), -14.0 + heat / 12.0)


func _play(dt: float) -> void:
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
	# The fire dies down by itself
	heat = maxf(0.0, heat - (4.5 + heat * 0.045) * dt)
	_keys_stir(dt)
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
	# A spoilt brew sits murky a moment, then it's tipped out
	if spoil_t > 0.0:
		spoil_t -= dt
		if spoil_t <= 0.0:
			hut.fresh()
			_reset_brew()
		return
	# Boiling over
	if heat >= BOIL_AT:
		_boil += dt
		if _boil >= BOIL_TIME:
			_boil = 0.0
			heat = 62.0
			Sfx.play("hiss")
			witch.act("shock")
			if progress > 0:
				_spoil(Book.rhyme("boil"))
			else:
				_say_witch(Book.rhyme("boil"))
	else:
		_boil = maxf(0.0, _boil - dt)
	# Holding the heat at the right band
	var want := current_step()
	step_fill = 0.0
	if want.get("kind", -1) == Book.HEAT:
		if Book.band_of(heat) == want.level:
			_hold += dt
			if _hold >= HOLD:
				_advance()
		else:
			_hold = maxf(0.0, _hold - dt * 2.0)
		step_fill = _hold / HOLD
	elif want.get("kind", -1) == Book.STIR:
		step_fill = _stir_done / (TAU * want.turns)
	# Forgive a little wobble of the ladle over time
	_stir_wrong = maxf(0.0, _stir_wrong - dt * 0.6)
	_stir_stray = maxf(0.0, _stir_stray - dt * 0.6)
	_stir_seen = maxf(0.0, _stir_seen - dt)
	witch.stirring = _stir_seen > 0.0


func _eyes() -> void:
	var o := selected_order()
	if not o.is_empty() and is_instance_valid(o.customer):
		witch.look_at_point = Hut.WINDOW_HEAD if speech.get("who", "") != "witch" else camera.global_position
		o.customer.look_at_point = witch.global_position + Vector3(0, 2.0, 0)
	elif state == "play":
		witch.look_at_point = Vector3(0, Hut.BREW_LEVEL, 0)
	else:
		witch.look_at_point = camera.global_position
	if witch.stirring:
		witch.look_at_point = Vector3(0, Hut.BREW_LEVEL, 0.3)


func selected_order() -> Dictionary:
	return orders[selected] if selected >= 0 and selected < orders.size() else {}


func current_step() -> Dictionary:
	var o := selected_order()
	if o.is_empty() or progress >= o.steps.size():
		return {}
	return o.steps[progress]


## Whether the selected order's recipe is shown, or hidden because she ought to know it
func recipe_hidden() -> bool:
	var o := selected_order()
	return night >= 4 and not o.is_empty() and learned.has(o.potion)


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
	add_child(customer)
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
	var was := selected
	selected = i
	var o := orders[i]
	o.customer.duck(false)
	var line: String = Book.ORDER_LINES[o.id % Book.ORDER_LINES.size()] % Book.POTIONS[o.potion].name
	_say_folk(line, o.who.voice, o.customer)
	# The brew so far carries over if the new recipe starts the same way; otherwise out it goes
	if was >= 0 and progress > 0 and spoil_t <= 0.0:
		if not _same_start(old.steps, o.steps, progress):
			hut.fresh()
			_reset_brew()
			Sfx.play("slosh", 0.7)
	Sfx.play("tap")


func _same_start(a: Array, b: Array, n: int) -> bool:
	if b.size() < n:
		return false
	for i in n:
		if a[i].hash() != b[i].hash():
			return false
	return true


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
	var old_steps: Array = orders[i].steps
	orders.remove_at(i)
	if selected > i:
		selected -= 1
	elif was_selected:
		selected = -1
		if not orders.is_empty():
			# The next one up is whoever has waited longest
			var prev_progress := progress
			selected = 0
			var o := orders[0]
			o.customer.duck(false)
			if is_instance_valid(o.customer):
				var line: String = Book.ORDER_LINES[o.id % Book.ORDER_LINES.size()] % Book.POTIONS[o.potion].name
				_say_folk(line, o.who.voice, o.customer)
			if prev_progress > 0 and spoil_t <= 0.0 and not _same_start(old_steps, o.steps, prev_progress):
				hut.fresh()
				_reset_brew()
		elif spoil_t <= 0.0 and progress > 0:
			hut.fresh()
			_reset_brew()


# --- what she does at the cauldron ---

func add(which: int) -> void:
	if not _brewing() or which >= Book.ingredients_on(night):
		return
	witch.act("toss")
	hut.poke("jar%d" % which)
	hut.plop(Book.INGREDIENTS[which].brew)
	Sfx.play("plop", randf_range(0.9, 1.15))
	_act({"kind": Book.ADD, "what": which})


func pump() -> void:
	if not _brewing():
		return
	heat = minf(100.0, heat + PUMP)
	Sfx.play("puff", randf_range(0.9, 1.1), -3.0)
	hut.squeeze()
	hut.poke("bellows")


func zap() -> void:
	if not _brewing() or night < 3:
		return
	witch.act("zap")
	hut.poke("wand")
	hut.zap()
	Sfx.play("zap")
	_act({"kind": Book.ZAP})


func bottle() -> void:
	if not _brewing():
		return
	var want := current_step()
	if want.get("kind", -1) == Book.BOTTLE:
		hut.poke("bottle")
		_serve()
	else:
		Sfx.play("huff", 1.4, -6.0)
		hut.poke("bottle", true)
		if not selected_order().is_empty():
			_float("Not ready yet!", screen_of(Vector3(0, Hut.CAULDRON_RIM + 0.6, 0)), Color("ffd0a0"))


## The ladle dragged round by `angle` radians (positive with the sun)
func stir(angle: float) -> void:
	if not _brewing() or night < 2 or absf(angle) < 0.0001:
		return
	_stir_angle += angle
	witch.stir_angle = _stir_angle
	_stir_seen = 0.25
	hut.stir_to(_stir_angle)
	_stir_sound += absf(angle)
	if _stir_sound > PI * 0.6:
		_stir_sound = 0.0
		Sfx.play("slosh", randf_range(0.85, 1.15), -4.0)
	var want := current_step()
	var dir := 1 if angle > 0.0 else -1
	if want.get("kind", -1) == Book.STIR:
		if dir == want.dir:
			_stir_done += absf(angle)
			if _stir_done >= TAU * want.turns:
				_advance()
		else:
			_stir_wrong += absf(angle)
			if _stir_wrong > PI * 1.2:
				_spoil(Book.rhyme("spoil"), "Wrong way round!")
	elif not selected_order().is_empty():
		_stir_stray += absf(angle)
		if _stir_stray > TAU * 0.9:
			_spoil(Book.rhyme("spoil"), "Not now, no stirring!")


func _brewing() -> bool:
	return state == "play" and not paused and spoil_t <= 0.0


func _keys_stir(dt: float) -> void:
	var d := 0.0
	if _keys_down.get(KEY_RIGHT, false) or _keys_down.get(KEY_D, false):
		d += 1.0
	if _keys_down.get(KEY_LEFT, false) or _keys_down.get(KEY_A, false):
		d -= 1.0
	if d != 0.0:
		stir(d * KEY_STIR_SPEED * dt)


## Something was done to the brew: right if it's the next step, spoilt if not
func _act(did: Dictionary) -> void:
	var want := current_step()
	if want.is_empty():
		_spoil("Nobody ordered that, you silly old thing!", "Nobody ordered that!")
		return
	if want.kind == did.kind and (did.kind != Book.ADD or want.what == did.what):
		_advance()
	else:
		var what := "Wrong ingredient!" if did.kind == Book.ADD else "Not yet!"
		_spoil(Book.rhyme("spoil"), what)


func _advance() -> void:
	var o := selected_order()
	var st: Dictionary = o.steps[progress]
	progress += 1
	done_kinds[st.kind] = done_kinds.get(st.kind, 0) + 1
	_hold = 0.0
	_stir_done = 0.0
	_stir_wrong = 0.0
	_stir_stray = 0.0
	# The brew takes on the colour of what went in
	var col := Book.WATER
	var added := 0
	for k in progress:
		var s: Dictionary = o.steps[k]
		if s.kind == Book.ADD:
			added += 1
			col = col.lerp(Book.INGREDIENTS[s.what].brew, 1.0 if added == 1 else 0.5)
		elif s.kind == Book.ZAP:
			col = col.lightened(0.18)
	hut.set_brew(col)
	hud.tick_step(progress - 1)
	if st.kind != Book.ADD:
		Sfx.play("tap", 1.5, -2.0)


func _spoil(rhyme: String, short := "") -> void:
	spoil_t = 1.5
	combo = 0
	hut.set_brew(Color("6a5a3a"), true)
	hut.poof()
	Sfx.play("blorp")
	witch.act("grumble")
	_say_witch(rhyme)
	if short != "":
		_float(short, screen_of(Vector3(0, Hut.CAULDRON_RIM + 0.6, 0)), Color("ff9a8a"))


func _reset_brew() -> void:
	progress = 0
	_hold = 0.0
	_stir_done = 0.0
	_stir_wrong = 0.0
	_stir_stray = 0.0
	spoil_t = 0.0


func _serve() -> void:
	var i := selected
	var o := orders[i]
	var steps: int = o.steps.size() - 1
	var base := 10 + steps * 5
	var tip := int(round(base * 0.6 * clampf(o.patience / o.full, 0.0, 1.0)))
	combo += 1
	var bonus := mini(combo - 1, 5) * 3
	var coins := base + tip + bonus
	night_coins += coins
	score += coins
	served += 1
	learned[o.potion] = true
	done_kinds[Book.BOTTLE] = done_kinds.get(Book.BOTTLE, 0) + 1
	Sfx.play("cork")
	Sfx.play("coins", 1.0, -2.0)
	Sfx.play("cheer", 1.0, -4.0)
	witch.act("cackle")
	var at := screen_of(Hut.WINDOW_HEAD + Vector3(0, 0.2, 0.3))
	_float("+%d" % coins, at, Color("ffe060"), true)
	if combo > 1:
		_float("Combo x%d!" % combo, at + Vector2(0, 50), Color("a0ffb0"))
	_fly_bottle(o.colour, o.customer)
	if randf() < 0.6:
		_say_witch(Book.rhyme("serve"))
	_remove_order(i)
	hut.fresh()
	_reset_brew()


func _fly_bottle(col: Color, customer: Witch) -> void:
	var b := Node3D.new()
	b.add_child(Models.make("potion", Shape.mat(0.3)))
	var liquid := Shape.mat(0.35)
	liquid.set_shader_parameter("tint", Shape.lin3(col))
	b.add_child(Models.make("potion_liquid", liquid))
	add_child(b)
	var from := Vector3(0, Hut.CAULDRON_RIM + 0.2, 0)
	var to := Hut.WINDOW_HEAD + Vector3(0.2, -0.45, 0.45)
	var tw := create_tween()
	tw.tween_method(func(t: float) -> void:
		b.position = from.lerp(to, t) + Vector3(0, sin(t * PI) * 1.1, 0)
		b.rotation.z = t * TAU, 0.0, 1.0, 0.55)
	tw.tween_callback(func() -> void:
		b.queue_free()
		if is_instance_valid(customer):
			customer.happy())


# --- talk ---

func _say_witch(text: String) -> void:
	speech = {"who": "witch", "text": text, "shown": 0.0, "life": 2.2 + text.length() * 0.045, "voice": 1.0}


func _say_folk(text: String, voice: float, customer: Witch) -> void:
	if speech.get("who", "") == "witch" and speech.shown < speech.text.length():
		return
	speech = {"who": "folk", "text": text, "shown": 0.0, "life": 1.6 + text.length() * 0.04, "voice": voice, "customer": customer}


func _update_speech(dt: float) -> void:
	if speech.is_empty():
		witch.talking = false
		return
	var before := int(speech.shown)
	speech.shown = minf(speech.text.length(), speech.shown + dt * 38.0)
	var now := int(speech.shown)
	var talking: bool = now < speech.text.length()
	for k in range(before, now):
		var ch: String = speech.text[k]
		if k % 3 == 0 and ch != " " and ch != "\n":
			Sfx.say("witch" if speech.who == "witch" else "folk", speech.voice)
	witch.talking = talking and speech.who == "witch"
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


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(save_path) == OK:
		best = cfg.get_value("shop", "best", 0)
		Sfx.set_muted(not cfg.get_value("shop", "sound", true))


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("shop", "best", best)
	cfg.set_value("shop", "sound", not sfx.muted)
	cfg.save(save_path)
