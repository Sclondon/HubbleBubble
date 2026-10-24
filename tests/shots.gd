extends SceneTree
## Pictures of the shop for looking over: the title, a night's intro, brewing with a few customers
## waiting, the book, and the end of a night; tall (phone) and wide (desktop).
## godot --audio-driver Dummy --path . -s tests/shots.gd -- --shots=<dir> [--wide] [--only=name]

var out := "user://shots"
var wide := false
## How long to wait in the tower shot, in seconds
var wait_s := 10.0
## A shorter phone (an iframe in a browser): 720 x 1170
var short := false
var only := ""
var main: Shop


func _initialize() -> void:
	# (waits are counted in frames, as sixtieths of a second)
	Engine.max_fps = 60
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			out = a.substr(8)
		elif a == "--wide":
			wide = true
		elif a.begins_with("--wait="):
			wait_s = float(a.substr(7))
		elif a == "--short":
			short = true
		elif a.begins_with("--only="):
			only = a.substr(7)
	DirAccess.make_dir_recursive_absolute(out)
	var size := Vector2i(1600, 900) if wide else (Vector2i(720, 1170) if short else Vector2i(720, 1560))
	DisplayServer.window_set_size(size)
	root.size = size
	main = load("res://main.tscn").instantiate()
	main.testing = true
	root.add_child(main)
	_run.call_deferred()


func _run() -> void:
	await _frames(240)
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
	if only == "rings":
		main.start_free()
		await _frames(20)
		main.camera.position = Vector3(0.0, 2.35, 1.35)
		main.camera.look_at(Vector3(0, Hut.BREW_LEVEL, 0))
		main.set_process(false)
		main.smoke_camera.global_transform = main.camera.global_transform
		for k in 3:
			main.hut.brew.droplets(Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3)), 8, 1.2)
			await _frames(12)
		await _frames(20)
		root.get_texture().get_image().save_png("%s/rings.png" % out)
		quit()
		return
	if only == "dev":
		main.start_free()
		await _frames(5)
		main.hut.set_brew(Color.WHITE, false, "love")
		main.toggle_dev()
		await _frames(120)
		root.get_texture().get_image().save_png("%s/dev.png" % out)
		quit()
		return
	if only.begins_with("isle"):
		# The island from the periscope's head, looking out over the meadow to the lair
		await _frames(30)
		main.set_process(false)
		main.camera.position = Vector3(-0.6, 5.2, -3.9)
		main.camera.fov = 50.0
		main.camera.look_at(Vector3(0, 5.0, -40.0) if only == "isle" else Vector3(0, 1.0, -15.0))
		await _frames(10)
		root.get_texture().get_image().save_png("%s/%s.png" % [out, only])
		quit()
		return
	if only == "finish":
		# A brew stirred up to its finish: the camera leaning in, then the poof and its marks
		main.start_free()
		await _frames(5)
		main.add(1)
		await _frames(30)
		main.add(2)
		for i in 100:
			main.heat = 35.0
			await process_frame
		main._start_finish(Lore.resolve(main.brew).effect)
		for i in 90:
			main.heat = 35.0
			main.stir(TAU * Shop.FINISH_TURNS * 0.95 / 90.0)
			main._stir_seen = 0.25
			main.hut.stir_at(Vector3(cos(main._stir_angle), 0, sin(main._stir_angle)) * 0.45)
			await process_frame
		root.get_texture().get_image().save_png("%s/finish_lean.png" % out)
		await _frames(70)
		root.get_texture().get_image().save_png("%s/finish_grades.png" % out)
		quit()
		return
	if only == "boil":
		main.start_free()
		await _frames(5)
		main.hut.set_brew(Color.WHITE, false, "dragon's breath")
		for i in 200:
			main.heat = 86.0
			await process_frame
		root.get_texture().get_image().save_png("%s/boil.png" % out)
		quit()
		return
	if only == "spoon":
		# The stirring spoon close up, the brew hidden so the bowl shows
		main.start_free()
		await _frames(30)
		main.set_process(false)
		main.hut.set_process(false)
		var stick: Node3D = main.hut.stick
		stick.global_position = Vector3(-0.3, 2.9, 1.6)
		stick.global_rotation = Vector3(0.6, 0.9, 0.4)
		var lamp := OmniLight3D.new()
		lamp.omni_range = 3.0
		lamp.light_energy = 3.0
		root.add_child(lamp)
		lamp.global_position = Vector3(0.3, 3.2, 2.6)
		main.camera.position = Vector3(0.0, 2.7, 2.9)
		main.camera.look_at(Vector3(-0.1, 2.6, 1.6))
		main.smoke_camera.global_transform = main.camera.global_transform
		await _frames(4)
		root.get_texture().get_image().save_png("%s/spoon.png" % out)
		quit()
		return
	if only == "floaters":
		# Close over the brew with three things floating in it, settled
		main.start_free()
		await _frames(5)
		main.heat = 10.0
		for w in [0, 1, 3]:
			main.add(w)
			await _frames(40)
		await create_timer(3.0).timeout
		for n: String in ["clouds", "streamers", "tendrils", "shapes"]:
			main.hut.brew.get_node(n).visible = false
		main.set_process(false)
		main.camera.position = Vector3(0.0, 2.35, 1.35)
		main.camera.look_at(Vector3(0, Hut.BREW_LEVEL, 0))
		main.smoke_camera.global_transform = main.camera.global_transform
		await _frames(4)
		root.get_texture().get_image().save_png("%s/floaters.png" % out)
		quit()
		return
	if only == "bookfloat":
		main.hud.book_page = main.hud.book_page_of(0)
		main.show_book_pages()
		await _frames(60)
		root.get_texture().get_image().save_png("%s/bookfloat.png" % out)
		quit()
		return
	if only == "cook":
		main.start_free()
		await _frames(5)
		main.heat = 15.0
		for w in [0, 1, 6]:
			main.add(w)
			await _frames(30)
		for i in 60:
			main.heat = 15.0
			main.stir(0.08)
			main._stir_seen = 0.25
			main.hut.stir_at(Vector3(cos(main._stir_angle), 0, sin(main._stir_angle)) * 0.45)
			await process_frame
		root.get_texture().get_image().save_png("%s/cook_floating%s.png" % [out, "_wide" if wide else ""])
		main.heat = 40.0
		await _frames(80)
		root.get_texture().get_image().save_png("%s/cook_cooking%s.png" % [out, "_wide" if wide else ""])
		await _frames(90)
		root.get_texture().get_image().save_png("%s/cook_done%s.png" % [out, "_wide" if wide else ""])
		quit()
		return
	if only == "steam":
		main.camera.position = Vector3(0.0, 2.2, 1.9)
		main.camera.look_at(Vector3(0, 1.7, 0))
		main.set_process(false)
		for i in 150:
			main.hut.heat = 90.0
			await process_frame
		main.hut.brew.puffs(Vector3.ZERO, 8, Color(0.65, 0.45, 0.95, 0.9), 0.6, 1.0)
		await _frames(20)
		root.get_texture().get_image().save_png("%s/steam.png" % out)
		quit()
		return
	if only == "fire":
		# Low by the fire, the pot and the brew out of the way
		main.hut.get_node("pot").visible = false
		for c in main.hut.get_children():
			if c.name.begins_with("cauldron") or (c is Node3D and c.scene_file_path.ends_with("cauldron.glb")):
				c.visible = false
		main.heat = 60.0
		main.camera.position = Vector3(0, 1.0, 2.6)
		main.camera.look_at(Vector3(0, 0.5, 0))
		main.set_process(false)
		for i in 30:
			main.hut.heat = 60.0
			await process_frame
		root.get_texture().get_image().save_png("%s/fire.png" % out)
		quit()
		return
	if only == "swamp":
		main.visit_swamp()
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
		await _frames(int(wait_s * 60.0))
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
