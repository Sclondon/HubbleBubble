extends SceneTree
## Pictures of the shop for looking over: the title, a night's intro, brewing with a few customers
## waiting, the book, and the end of a night; tall (phone) and wide (desktop).
## godot --audio-driver Dummy --path . -s tests/shots.gd -- --shots=<dir> [--wide] [--only=name]

var out := "user://shots"
var wide := false
var only := ""
var main: Shop


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			out = a.substr(8)
		elif a == "--wide":
			wide = true
		elif a.begins_with("--only="):
			only = a.substr(7)
	DirAccess.make_dir_recursive_absolute(out)
	var size := Vector2i(1600, 900) if wide else Vector2i(720, 1560)
	DisplayServer.window_set_size(size)
	root.size = size
	main = load("res://main.tscn").instantiate()
	main.testing = true
	root.add_child(main)
	_run.call_deferred()


func _run() -> void:
	await _frames(10)
	await _shot("title")
	if only.begins_with("look_"):
		main.start_free()
		await _frames(5)
		var effect := only.substr(5).replace("_", " ")
		main.hut.set_brew(Color.WHITE, false, effect)
		for i in 200:
			main.heat = 80.0
			await process_frame
		root.get_texture().get_image().save_png("%s/%s.png" % [out, only])
		quit()
		return
	if only == "swamp":
		main.start_game()
		main.state = "done"
		main.intro_t = 2.0
		main.next_night()
		await _frames(80)
		root.get_texture().get_image().save_png("%s/swamp%s.png" % [out, "_wide" if wide else ""])
		quit()
		return
	if only.begins_with("tower"):
		main.start_free()
		await _frames(5)
		var recipe := "wing shroom H2 Z" if only == "tower" else "petal eye H1 S+1 Z"
		main.brew = Book.steps_of(recipe).slice(0, -1)
		main.bottle()
		await _frames(330)
		var img := root.get_texture().get_image()
		img.save_png("%s/%s.png" % [out, only])
		print("shot ", only)
		quit()
		return
	main.start_game()
	await _frames(20)
	await _shot("intro")
	main.night = 4
	main._start_night()
	main.begin_play()
	await _frames(5)
	main._new_order()
	main._new_order()
	main._new_order()
	await _frames(40)
	main.heat = 55.0
	main.brew = [{"kind": Book.ADD, "what": 0}]
	await _frames(30)
	await _shot("brewing")
	if only == "witch":
		var cam := main.camera
		var keep := cam.transform
		cam.position = main.witch.global_position + Vector3(0.9, 2.3, 2.8)
		cam.look_at(main.witch.global_position + Vector3(0.3, 1.6, 0))
		await _shot("witch")
		cam.position = Hut.WINDOW_SPOT + Vector3(0, 0.4, 2.6)
		cam.look_at(Hut.WINDOW_SPOT + Vector3(0, 0.3, 0))
		await _shot("customer")
		cam.transform = keep
	if only == "react":
		main.hut.react("fireball", Color("ffa22e"), 2.0)
		await _frames(12)
		await _shot("react")
		main.hut.react("rainbow", Color("a8c8ff"), 2.0)
		main.hut.react("bubbles", Color("5fd6c4"), 2.0)
		await _frames(14)
		await _shot("react2")
	main.toggle_book()
	await _frames(5)
	await _shot("book")
	main.hud.book_page = 3
	await _frames(3)
	await _shot("book_potion")
	main.hud.book_page = 2
	await _frames(3)
	await _shot("book_ingredients")
	main.hud.book_page = 1
	await _frames(3)
	await _shot("book_craft")
	main.toggle_book()
	main.state = "done"
	main.intro_t = 2.0
	await _frames(5)
	await _shot("done")
	quit()


func _shot(name: String) -> void:
	if only != "" and only != name and not (only == "react" and name.begins_with("react")) and not (only == "book" and name.begins_with("book")):
		return
	await _frames(3)
	var img := root.get_texture().get_image()
	var path := "%s/%s%s.png" % [out, name, "_wide" if wide else ""]
	img.save_png(path)
	print("shot ", path)


func _frames(n: int) -> void:
	for i in n:
		await process_frame
