extends SceneTree
## Smoke test: opens the shop and brews to order by the cauldron's logic (the right potion pays,
## the wrong one she drinks), holds the heat, stirs, boils over, tips out, reads the book, brews
## freely and sends a bottle up the tower, ends nights pass and fail, and does it all with real
## touches where it can.
## godot --headless --audio-driver Dummy --fixed-fps 60 --path . -s tests/smoke.gd

var main: Shop
var failures := 0


func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	main.save_path = "user://smoke.cfg"
	main.testing = true
	root.add_child(main)
	_run.call_deferred()


func _run() -> void:
	await _frames(5)
	main.discoveries.clear()
	_check(main.state == "title", "starts on the title")
	await _frames(2)
	await _touch((main.hud.buttons["go_shop"].rect as Rect2).get_center())
	_check(main.state == "intro", "Open the Shop starts night 1")
	await _touch(Vector2(360, 700))
	_check(main.state == "play" and main.mode == "shop", "a tap opens the shop")
	await _frames(100)
	_check(main.orders.size() == 1 and main.selected == 0, "a customer comes to the window and is served first")

	# The Sleeping Draught, by the book: a toadstool, a bat wing, warmed
	_order("Sleeping Draught")
	await _add("shroom")
	await _add("wing")
	_check(main.brew.size() == 2, "what goes in is written down (%d)" % main.brew.size())
	main.heat = 35.0
	await _seconds(0.5)
	_check(main.brew.size() == 2, "the heat doesn't count till it's held")
	await _seconds(0.9)
	_check(main.brew.size() == 3 and main.brew[2].kind == Book.HEAT and main.brew[2].level == 1, "held warm a moment, it counts")
	_check(Lore.resolve(main.brew).effect == "sleep", "and it makes Sleep")
	var before := main.night_coins
	main.bottle()
	_check(main.night_coins > before and main.served == 1, "bottled, it sells (%d coins)" % (main.night_coins - before))
	_check(main.brew.is_empty(), "and the pot starts fresh")

	# Another way to the same potion still sells
	_order("Sleeping Draught")
	await _add("shroom")
	main.heat = 55.0
	await _seconds(1.3)
	before = main.night_coins
	main.bottle()
	_check(main.night_coins > before, "any brew with the potion's effect will do")

	# The wrong one: she drinks it anyway, and goes
	_order("Sleeping Draught")
	await _add("eye")
	main.heat = 35.0
	await _seconds(1.3)
	var lost := main.lost
	var customer: Witch = main.orders[0].customer
	main.bottle()
	_check(main.lost == lost + 1 and main.orders.is_empty(), "the wrong potion loses the sale")
	await _seconds(0.8)
	_check(is_instance_valid(customer) and customer._effect == "second sight", "and she drinks it: second sight (%s)" % (customer._effect if is_instance_valid(customer) else "gone"))
	await _seconds(4.0)

	# Boiling over spoils a pot with something in it; holding still on the brew tips it out
	_order("Sleeping Draught")
	await _add("leg")
	for i in 90:
		main.heat = maxf(main.heat, 96.0)
		await process_frame
	_check(main.spoil_t > 0.0, "too much fire boils it over")
	await _seconds(1.7)
	_check(main.brew.is_empty(), "the spoilt brew is tipped out")
	await _add("leg")
	main.tip_out()
	_check(main.brew.is_empty(), "tipping it out empties the pot")

	# Night 2: stirring; widdershins turns it to its opposite
	main.night = 2
	_order("Wakeful Brew")
	await _add("shroom")
	main.heat = 55.0
	await _seconds(1.3)
	for i in 20:
		main.stir(-TAU / 20.0)
	_check(main.brew[-1].kind == Book.STIR and main.brew[-1].dir == -1, "a whole turn widdershins is written down")
	_check(Lore.resolve(main.brew).effect == "wakefulness", "and turns sleep to wakefulness")
	main.bottle()
	_check(main.served >= 3, "the Wakeful Brew sells")

	# Real touches: drag a jar to the pot, the bellows, round the pot, the bottles
	_order("Sleeping Draught")
	main.night = 3
	main.hut.stock(Book.ingredients_on(3))
	var from := _centre("jar1")
	var pot: Vector2 = main.cauldron_screen()[0]
	_send_touch(from, true)
	for i in 12:
		_send_drag(from.lerp(pot, (i + 1) / 12.0))
		await process_frame
	await _frames(10)
	_send_touch(pot, false)
	await _seconds(0.6)
	_check(main.brew.size() == 1 and main.brew[0].what == 1, "dragging the toadstool into the pot adds it")
	_send_touch(_centre("jar0"), true)
	await _frames(3)
	_send_touch(_centre("jar0"), false)
	await _seconds(0.6)
	_check(main.brew.filter(func(s: Dictionary) -> bool: return s.kind == Book.ADD).size() == 1, "letting go of one over the table puts it back")
	var heat0 := main.heat
	await _touch(_centre("bellows"))
	_check(main.heat > heat0, "tapping the bellows heats the fire")
	main.heat = 35.0
	await _seconds(1.3)
	var cs := main.cauldron_screen()
	var c: Vector2 = cs[0]
	var r: float = cs[1] * 0.6
	_send_touch(c + Vector2(r, 0), true)
	for i in 28:
		var a := TAU * (i + 1) / 24.0
		_send_drag(c + Vector2(cos(a), sin(a)) * r)
		await process_frame
	_send_touch(c + Vector2(r, 0), false)
	_check(main.brew[-1].kind == Book.STIR and main.brew[-1].dir == 1, "dragging round the pot clockwise stirs it sunwise")
	before = main.served
	await _touch(_centre("bottle"))
	_check(main.served == before + 1, "the bottles serve it")

	# The book: opens at the contents, turns to a potion's page
	await _touch(_centre("book"))
	_check(main.book_open and main.hud.book_page == 0, "tapping the book opens it at the contents")
	await _frames(2)
	var entry := "page%d" % main.hud.book_page_of(0)
	_check(main.hud.buttons_book.has(entry), "the contents list the potions")
	await _touch((main.hud.buttons_book[entry] as Rect2).get_center())
	_check(main.hud.book_page == main.hud.book_page_of(0), "tapping one turns to its page")
	await _touch((main.hud.buttons_book["close"] as Rect2).get_center())
	_check(not main.book_open, "and it closes")

	# Every control on the screen, tall and wide
	for wide in [false, true]:
		root.size = Vector2i(1600, 900) if wide else Vector2i(720, 1440)
		await _frames(3)
		var clash := []
		for id: String in main.hut.spots:
			var p := main.spot_screen(id)
			if not Rect2(Vector2.ZERO, main.hud.size_now).has_point(p):
				clash.append(id + " off screen")
			elif main.pick(p) != id:
				clash.append(id + " picks as " + main.pick(p))
		_check(clash.is_empty(), "%s: everything in the hut on screen and picked as itself (%s)" % ["wide" if wide else "tall", ", ".join(clash)])
	root.size = Vector2i(450, 800)
	await _frames(3)

	# The end of a night, passed and failed
	main.night_coins = Book.quota(main.night)
	main.clock = 0.05
	await _frames(5)
	_check(main.state == "done", "making the quota shuts the shop for the night")
	await _seconds(1.1)
	main.next_night()
	_check(main.state == "intro", "and the next night begins")
	main.begin_play()
	main.night_coins = 0
	main.clock = 0.05
	await _frames(5)
	_check(main.state == "over", "missing the quota ends the game")
	await _seconds(1.1)
	main.next_night()
	_check(main.state == "title", "and goes back to the title")

	# Brewing freely: a bottle goes up the tower, a witch drinks it, it's written in the book
	await _frames(2)
	await _touch((main.hud.buttons["go_free"].rect as Rect2).get_center())
	_check(main.state == "play" and main.mode == "free" and main.orders.is_empty(), "Brew Freely: no customers, no clock")
	await _add("wing")
	await _add("shroom")
	main.heat = 55.0
	await _seconds(1.3)
	main.zap()
	await _frames(3)
	main.bottle()
	_check(main.state == "tower", "bottled, it goes up the tower")
	_check(main.discoveries.has("floating"), "Floating is written in the book")
	await _seconds(2.2)
	_check(main.tower.tester._effect == "floating", "the witch up there drinks it and floats")
	await _touch(Vector2(360, 700))
	_check(main.state == "play" and main.mode == "free", "a tap brings you back down to brew another")

	print("FAILURES: %d" % failures if failures else "ALL PASSED")
	quit(1 if failures else 0)


func _order(name: String) -> void:
	_clear_orders()
	main._new_order()
	var o: Dictionary = main.orders[0]
	for i in Book.POTIONS.size():
		if Book.POTIONS[i].name == name:
			o.potion = i
			o.steps = Book.steps_of(Book.POTIONS[i].recipe)
	main.selected = 0
	main.tip_out()
	main._reset_brew()
	main.hut.fresh()


func _add(id: String) -> void:
	main.add(Book.ingredient(id))
	await _seconds(0.6)


func _clear_orders() -> void:
	for o in main.orders:
		if is_instance_valid(o.customer):
			o.customer.queue_free()
	main.orders.clear()
	main.selected = -1
	main._reset_brew()
	main._spawn_t = 999.0


func _centre(id: String) -> Vector2:
	return main.spot_screen(id)


func _touch(at: Vector2) -> void:
	_send_touch(at, true)
	await process_frame
	_send_touch(at, false)
	await process_frame


# Touches are sent as window pixels, like a real finger
func _send_touch(at: Vector2, down: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.position = root.get_final_transform() * at
	e.pressed = down
	root.push_input(e)


func _send_drag(at: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.position = root.get_final_transform() * at
	root.push_input(e)


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		failures += 1


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _seconds(s: float) -> void:
	await _frames(int(s * 60.0))
