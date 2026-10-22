extends SceneTree
## Smoke test: brews potions the right way and the wrong way, holds the heat, stirs both ways,
## switches orders, lets a customer storm off, finishes nights pass and fail, and presses the
## controls with real touches.
## godot --headless --audio-driver Dummy --fixed-fps 60 --path . -s tests/smoke.gd

var main: Shop
var failures := 0


func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	main.save_path = "user://smoke.cfg"
	root.add_child(main)
	_run.call_deferred()


func _run() -> void:
	await _frames(5)
	_check(main.state == "title", "starts on the title")
	await _touch(Vector2(360, 700))
	_check(main.state == "intro", "a tap starts night 1")
	await _touch(Vector2(360, 700))
	_check(main.state == "play", "a tap opens the shop")
	await _frames(100)
	_check(main.orders.size() == 1 and main.selected == 0, "a customer comes to the window and is served first")

	# Hiccup Tonic, done right: leg, eye, warm, bottle
	_order("Hiccup Tonic")
	main.add(Book.ingredient("leg"))
	_check(main.progress == 1, "the right ingredient ticks the step")
	main.add(Book.ingredient("eye"))
	_check(main.progress == 2, "and the next")
	main.bottle()
	_check(main.progress == 2 and main.spoil_t <= 0.0, "bottling too soon only grumbles")
	main.heat = 40.0
	await _seconds(1.3)
	_check(main.progress == 3, "holding the fire warm for a second ticks the heat step (%d)" % main.progress)
	var before := main.night_coins
	main.bottle()
	_check(main.night_coins > before, "bottling serves it for coins (%d)" % (main.night_coins - before))
	_check(main.served == 1 and main.progress == 0, "and the pot starts fresh")

	# Spoiling
	await _frames(5)
	_order("Hiccup Tonic")
	main.add(Book.ingredient("shroom"))
	_check(main.spoil_t > 0.0, "the wrong ingredient spoils it")
	main.add(Book.ingredient("leg"))
	_check(main.progress == 0, "nothing can go in while it's spoilt")
	await _seconds(1.7)
	_check(main.spoil_t <= 0.0 and main.progress == 0, "the spoilt brew is tipped out")

	# Boiling over spoils a brew that has something in it
	main.add(Book.ingredient("leg"))
	main.heat = 99.0
	for i in 90:
		main.heat = maxf(main.heat, 96.0)
		await process_frame
	_check(main.spoil_t > 0.0 or main.progress == 0, "too much fire boils it over")
	await _seconds(1.7)

	# Night 2: stirring
	main.night = 2
	_order("Wobble Juice")
	main.add(Book.ingredient("leg"))
	for i in 20:
		main.stir(TAU / 20.0)
	_check(main.progress == 2, "a full turn with the sun does Stir right x1 (%d)" % main.progress)
	main.add(Book.ingredient("shroom"))
	for i in 15:
		main.stir(TAU / 20.0)
	_check(main.spoil_t > 0.0, "stirring the wrong way round spoils it")
	await _seconds(1.7)
	_order("Wobble Juice")
	main.add(Book.ingredient("leg"))
	for i in 20:
		main.stir(TAU / 20.0)
	main.add(Book.ingredient("shroom"))
	for i in 20:
		main.stir(-TAU / 20.0)
	_check(main.progress == 4, "and against it does Stir left (%d)" % main.progress)
	main.bottle()
	_check(main.progress == 0, "served")

	# Stirring that isn't asked for spoils, a little jiggle doesn't
	_order("Spider Cider")
	main.stir(0.5)
	_check(main.spoil_t <= 0.0, "a nudge of the ladle is forgiven")
	for i in 20:
		main.stir(TAU / 20.0)
	_check(main.spoil_t > 0.0, "a whole turn when it isn't wanted spoils it")
	await _seconds(1.7)

	# Night 3: the wand
	main.night = 3
	_order("Moonlight Elixir")
	main.add(Book.ingredient("petal"))
	main.heat = 40.0
	await _seconds(1.3)
	main.zap()
	_check(main.progress == 3, "the wand zaps (%d)" % main.progress)
	main.bottle()

	# Switching orders: the brew carries over only if the new recipe starts the same
	_clear_orders()
	main._new_order()
	main._new_order()
	await _frames(2)
	main.orders[0].potion = Book.POTIONS.map(func(p: Dictionary) -> String: return p.name).find("Hiccup Tonic")
	main.orders[0].steps = Book.steps_of("leg eye H1")
	main.orders[1].steps = Book.steps_of("leg shroom")
	main.select(0)
	main.add(Book.ingredient("leg"))
	main.select(1)
	_check(main.progress == 1, "a brew that suits the other order carries over")
	main.orders[0].steps = Book.steps_of("eye wing H1")
	main.select(0)
	_check(main.progress == 0, "one that doesn't is tipped out")

	# A customer who waits too long storms off
	var n := main.orders.size()
	main.orders[0].patience = 0.05
	await _frames(10)
	_check(main.orders.size() == n - 1 and main.lost >= 1, "an impatient customer storms off")

	# Real touches: a jar, the bellows, a ticket, a drag round the pot
	_clear_orders()
	main.night = 3
	main._new_order()
	await _frames(2)
	main.orders[0].steps = Book.steps_of("eye H2 S+1")
	var heat0 := main.heat
	await _touch(_centre("jar0"))
	_check(main.progress == 1, "tapping the Eye of Newt jar adds it")
	await _touch(_centre("bellows"))
	_check(main.heat > heat0, "tapping the bellows heats the fire")
	main.heat = 60.0
	await _seconds(1.2)
	main.heat = 60.0
	await _seconds(0.3)
	var cs := main.cauldron_screen()
	var c: Vector2 = cs[0]
	var r: float = cs[1] * 1.1
	_send_touch(c + Vector2(r, 0), true)
	for i in 28:
		var a := TAU * (i + 1) / 24.0
		_send_drag(c + Vector2(cos(a), sin(a)) * r)
		await process_frame
	_send_touch(c + Vector2(r, 0), false)
	_check(main.progress == 3, "dragging round the pot clockwise stirs it right (%d)" % main.progress)
	await _touch(_centre("bottle"))
	_check(main.served >= 1 and main.orders.is_empty(), "the bottle button serves it")

	# Every control is on the screen and none overlaps another, tall and wide
	for wide in [false, true]:
		root.size = Vector2i(1600, 900) if wide else Vector2i(720, 1440)
		await _frames(3)
		var clash := []
		var ids := main.hud.buttons.keys().filter(func(k: String) -> bool: return not k in ["resume", "sound", "quit"])
		for i in ids.size():
			var a: Rect2 = main.hud.buttons[ids[i]].rect
			if not Rect2(Vector2.ZERO, main.hud.size_now).encloses(a):
				clash.append(ids[i] + " off screen")
			for j in range(i + 1, ids.size()):
				if a.intersects(main.hud.buttons[ids[j]].rect):
					clash.append(ids[i] + "/" + ids[j])
		_check(clash.is_empty(), "%s: every control on screen, apart (%s)" % ["wide" if wide else "tall", ", ".join(clash)])

	# The end of a night, passed and failed
	main.night_coins = Book.quota(main.night)
	main.clock = 0.05
	await _frames(5)
	_check(main.state == "done", "making the quota shuts the shop for the night")
	await _seconds(1.1)
	main.next_night()
	_check(main.state == "intro" and main.night == 4, "and the next night begins")
	main.begin_play()
	main.night_coins = 0
	main.clock = 0.05
	await _frames(5)
	_check(main.state == "over", "missing the quota ends the game")
	await _seconds(1.1)
	main.next_night()
	_check(main.state == "title", "and goes back to the title")

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
	main._reset_brew()
	main.hut.fresh()


func _clear_orders() -> void:
	for o in main.orders:
		if is_instance_valid(o.critter):
			o.critter.queue_free()
	main.orders.clear()
	main.selected = -1
	main._reset_brew()
	main._spawn_t = 999.0


func _centre(id: String) -> Vector2:
	return (main.hud.buttons[id].rect as Rect2).get_center()


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
