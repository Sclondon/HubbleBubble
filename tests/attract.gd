extends SceneTree
## Plays the game by itself, at a person's pace, for the arcade's preview film (and for watching it
## work): brews whatever is ordered, now and then fumbling a step so the brew spoils.
## godot --audio-driver Dummy --path . --fixed-fps 30 --write-movie out.avi -s tests/attract.gd -- [--night=3] [--seconds=18] [--shots=<dir>]

var main: Shop
var night := 3
var seconds := 18.0
var shots := ""
var _t := 0.0
var _wait := 0.0
var _fumbled := false
var _shot_n := 0
var _scoop := -1.0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--night="):
			night = int(a.substr(8))
		elif a.begins_with("--seconds="):
			seconds = float(a.substr(10))
		elif a.begins_with("--shots="):
			shots = a.substr(8)
	main = load("res://main.tscn").instantiate()
	main.save_path = "user://attract.cfg"
	main.testing = true
	root.add_child(main)
	process_frame.connect(_tick)
	_start.call_deferred()


func _start() -> void:
	await process_frame
	main._boot_t = 99.0
	main.start_game()
	main.night = night
	main._start_night()
	main.speech = {}
	main.begin_play()
	main._spawn_t = 0.3


func _tick() -> void:
	var dt := 1.0 / 30.0
	_t += dt
	if shots != "" and int(_t * 1.0) > _shot_n:
		_shot_n = int(_t)
		root.get_texture().get_image().save_png("%s/play_%02d.png" % [shots, _shot_n])
	if _t > seconds:
		quit()
		return
	if main.state != "play":
		return
	# Keep a second customer coming so the tickets fill
	if main.orders.size() < 2 and main._spawn_t > 2.5:
		main._spawn_t = 2.5
	# Scooping a jar of it: carried over, dipped till full, let go
	if _scoop >= 0.0:
		_scoop += dt
		if _scoop > 0.35:
			main._held_to = Vector3(0.15, Hut.CAULDRON_RIM + 0.12, 0.2)
		if main._fill >= 1.0 and _scoop > 1.6:
			main._held_to = Vector3(0.1, Hut.CAULDRON_RIM + 0.5, -0.4)
		if main._fill >= 1.0 and _scoop > 2.0:
			main.release()
			_scoop = -1.0
			_wait = 1.0
		return
	_wait -= dt
	if _wait > 0.0 or main.spoil_t > 0.0:
		return
	var o := main.selected_order()
	if o.is_empty():
		return
	# Follows the book: the next of its steps not yet in the pot
	var steps: Array = o.steps
	var done := _done_count(steps)
	if done >= steps.size():
		return
	var want: Dictionary = steps[done]
	match want.kind:
		Book.ADD:
			# Once, early on, grab the wrong jar
			if not _fumbled and _t > 7.0:
				_fumbled = true
				main.add((want.what + 1) % Book.ingredients_on(main.night))
				_wait = 1.0
				return
			main.add(want.what)
			_wait = 0.8
		Book.HEAT:
			var band := Book.band_of(main.heat)
			if band < want.level and main.heat < Book.HEAT_BANDS[want.level] + 8.0:
				main.pump()
				_wait = 0.22
		Book.STIR:
			main.stir(want.dir * TAU * 1.6 * dt)
			main._stir_seen = 0.25
			main.hut.stir_at(Vector3(cos(main._stir_angle), 0, sin(main._stir_angle)) * 0.45)
		Book.ZAP:
			main.zap()
			_wait = 0.8
		Book.BOTTLE:
			main.grab_bottle(Vector2.ZERO)
			_scoop = 0.0


## How many of the recipe's steps are in the pot already (anything else in it: tipped out)
func _done_count(steps: Array) -> int:
	var n := 0
	for s: Dictionary in main.brew:
		if n >= steps.size():
			break
		var w: Dictionary = steps[n]
		if s.kind != w.kind or (s.kind == Book.ADD and s.what != w.what):
			main.tip_out()
			return 0
		if s.kind == Book.STIR and s.turns < w.turns:
			return n
		if s.kind == Book.HEAT and s.level < w.level:
			return n
		n += 1
	return n
