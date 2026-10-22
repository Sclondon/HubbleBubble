extends SceneTree
## Every recipe in the book makes the potion it's for, by the cauldron's own logic (Lore), and
## the logic does what the book's verse says of it.
## godot --headless --path . -s tests/lore.gd

var failures := 0


func _initialize() -> void:
	var effects := {}
	for p: Dictionary in Book.POTIONS:
		var r := Lore.resolve(Book.steps_of(p.recipe))
		_check(r.effect == p.effect, "%s makes %s (got %s)" % [p.name, p.effect, r.effect])
		_check(not effects.has(p.effect), "%s is the only potion for %s" % [p.name, p.effect])
		effects[p.effect] = true
		_check(Lore.DESCRIBE.has(p.effect), "the book describes %s" % p.effect)
		for s: Dictionary in Book.steps_of(p.recipe):
			if s.kind == Book.ADD:
				_check(s.what < Book.ingredients_on(p.night), "%s only uses what's on the table by night %d" % [p.name, p.night])
			if s.kind == Book.STIR:
				_check(p.night >= 2, "%s stirs only from night 2" % p.name)
			if s.kind == Book.ZAP:
				_check(p.night >= 3, "%s zaps only from night 3" % p.name)
	# The rules themselves
	_check(Lore.resolve(Book.steps_of("eye")).effect == "nothing", "a cold brew does nothing")
	_check(Lore.resolve(Book.steps_of("wing H2")).effect == "nothing", "an airy root unquickened flies off")
	_check(Lore.resolve(Book.steps_of("scale")).effect == "growing", "a fiery root brings its own heat")
	_check(Lore.resolve(Book.steps_of("scale H2 S-1")).effect == "shrinking", "widdershins turns it to its opposite")
	_check(Lore.resolve(Book.steps_of("scale scale H3 Z")).potency == 5, "more root, hotter, quickened: strongest")
	_check(Lore.resolve(Book.steps_of("petal eye H1 Z")).effect == "love at first sight", "a twist makes something else")
	for e: String in Lore.EFFECTS:
		for x: String in Lore.EFFECTS[e]:
			_check(Lore.DESCRIBE.has(x), "the book describes %s" % x)
	print("FAILURES: %d" % failures if failures else "ALL PASSED")
	quit(1 if failures else 0)


func _check(ok: bool, what: String) -> void:
	if not ok:
		print("  FAIL " + what)
		failures += 1
