class_name Tower
extends Node3D
## The island the hut stands on, after Banjo-Kazooie's Isle o' Hags (models/island.glb): hills, a
## village of round cottages, a spiral mountain, the sea, lit by its own moon (on a layer of its own,
## so the hut inside stays lit by the potion alone). Witches wander about the village. Whoever's been
## sold a potion (or tries one brewed freely) walks off down the path from the window and drinks it,
## and the periscope out of the hut's roof watches her (Shop's "tower" state). Still called the tower,
## as the testing ground was.

const WITCHES := ["witch_gristle", "witch_hattie", "witch_bella", "witch_bogwort", "witch_polly", "witch_esme"]
## The island's render layer (the moon lights only this)
const LAYER := 128
## Where someone sent off with a potion goes to drink it: down the path, then aside onto the grass
const SPOTS := [Vector3(-2.5, 0, -12.5), Vector3(2.8, 0, -13.5), Vector3(-1.5, 0, -16.0), Vector3(3.0, 0, -17.0)]
## The village, where the others wander
const VILLAGE := [Vector3(-9, 0, -12), Vector3(8, 0, -14), Vector3(-12, 0, -22), Vector3(12, 0, -24), Vector3(2, 0, -28), Vector3(-5, 0, -26)]

## The witch being watched through the periscope (who drank the latest potion), if any
var tester: Witch
var _next := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 9
	var isle := Models.make("island")
	isle.name = "island"
	add_child(isle)
	Tower.on_layer(isle, LAYER)
	Tower.night_sky(self, _rng, -12.0, false)
	var moon := DirectionalLight3D.new()
	moon.name = "moonlight"
	moon.light_color = Color(0.55, 0.62, 1.0)
	moon.light_energy = 2.6
	# (shining out from behind the hut, so whoever stands out there facing it is lit)
	moon.rotation = Vector3(deg_to_rad(-42), deg_to_rad(15), 0)
	moon.light_cull_mask = LAYER
	add_child(moon)
	# Witches about the village
	for i in 4:
		var w := Witch.make(WITCHES[(i + 2) % WITCHES.size()])
		w.position = VILLAGE[i] + Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1))
		add_child(w)
		Tower.on_layer(w, LAYER | 1)
		w.wander(Array(VILLAGE, TYPE_VECTOR3, "", null))


## Puts every mesh under `node` on these render layers
static func on_layer(node: Node, layers: int) -> void:
	for mi: VisualInstance3D in node.find_children("*", "VisualInstance3D", true, false):
		if mi is MeshInstance3D:
			mi.layers = layers


func tester_name() -> String:
	if not is_instance_valid(tester):
		return "A witch"
	for c: Dictionary in Book.CUSTOMERS:
		if c.model == tester.model:
			return c.name
	return "A witch"


## Sends a witch off from the window with a potion: down the path to a spot on the grass, where she
## drinks it and it does whatever it does (`storm_off`: she wanted something else, and goes off cross)
func send_off(w: Witch, result: Dictionary, storm_off := false) -> void:
	tester = w
	Tower.on_layer(w, LAYER | 1)
	var spot: Vector3 = SPOTS[_next % SPOTS.size()]
	_next += 1
	var pts: Array[Vector3] = [Vector3(0, 0, -4.4), Vector3(0.3, 0, -7.0), spot]
	w.walk_to(pts, func() -> void:
		if is_instance_valid(w):
			# turned round to face the hut (and the periscope), then drinks
			w.rotation.y = atan2(-w.position.x, -w.position.z)
			w.look_at_point = Vector3(0, 4.0, -3.0)
			w.drink(result, storm_off))


## Brewing freely: a witch comes to the window for the bottle, then off she goes to try it
func try_out(result: Dictionary) -> Witch:
	var w := Witch.make(WITCHES[_next % WITCHES.size()])
	w.position = Hut.WINDOW_SPOT + Vector3(0, -0.3, 0)
	get_parent().add_child(w)
	w.add_to_group("customer")
	send_off(w, result)
	return w


## Nothing to try: the periscope looks over the village
func wait() -> void:
	pass


## The night all round: a starry sky, a big low moon, hills in silhouette far below
static func night_sky(parent: Node3D, rng: RandomNumberGenerator, low := -6.0, with_moon := true) -> void:
	var sky := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 150.0
	ball.height = 300.0
	ball.flip_faces = true
	sky.mesh = ball
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/sky.gdshader")
	sky.material_override = m
	parent.add_child(sky)
	if not with_moon:
		return
	var moon := Shape.new().ball(Vector3.ZERO, Vector3(6.0, 6.0, 1.0), Color("fff2b0"), Color("f0d070"), 18, 10)
	var mm := moon.piece("moon", Shape.mat(1.0))
	mm.position = Vector3(-30, 40, -110)
	parent.add_child(mm)
