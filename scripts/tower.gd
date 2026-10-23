class_name Tower
extends Node3D
## The balcony off the hut, out over the swamp, where a brew made freely is tried out: a witch stands
## in the chalk circle under the moon, catches the bottle, drinks it, and whatever it does happens to
## her. (Still called the tower, as it was.) It sits off from the hut in the same world.

const WITCHES := ["witch_gristle", "witch_hattie", "witch_bella", "witch_bogwort", "witch_polly", "witch_esme"]

var tester: Witch
var camera_at := Transform3D()
var _next := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 9
	add_child(Models.make("tower_top"))
	Tower.night_sky(self, _rng)
	camera_at = Transform3D(Basis(), Vector3(0, 2.3, 3.9)).looking_at(Vector3(0, 1.5, 0))
	_new_tester()


## A witch steps up to try the next brew (a different one each time)
func _new_tester() -> void:
	if is_instance_valid(tester):
		tester.queue_free()
	tester = Witch.make(WITCHES[_next % WITCHES.size()])
	_next += 1
	tester.position = Vector3(0, 0, 0)
	add_child(tester)
	tester.arrive()


func tester_name() -> String:
	for c: Dictionary in Book.CUSTOMERS:
		if c.model == tester.model:
			return c.name
	return "A witch"


## Nothing to try yet: whoever's out there waits for something
func wait() -> void:
	if not is_instance_valid(tester):
		_new_tester()


## The bottle comes out through the door behind; she catches it and drinks
func try_out(result: Dictionary) -> void:
	_new_tester()
	var b := Node3D.new()
	b.add_child(Models.make("potion", Shape.mat(0.3)))
	var liquid := Shape.mat(0.35)
	liquid.set_shader_parameter("tint", Shape.lin3(result.colour))
	b.add_child(Models.make("potion_liquid", liquid))
	add_child(b)
	var from := Vector3(0.0, 1.2, -2.2)
	var to := Vector3(0.3, 1.6, 0.4)
	var tw := create_tween()
	tw.tween_interval(0.6)
	tw.tween_method(func(k: float) -> void:
		b.position = from.lerp(to, k) + Vector3(0, sin(k * PI) * 1.2, 0)
		b.rotation.z = k * TAU * 1.5, 0.0, 1.0, 0.7)
	tw.tween_callback(func() -> void:
		b.queue_free()
		Sfx.play("cork")
		tester.drink(result))


## The night all round: a starry sky, a big low moon, hills in silhouette far below
static func night_sky(parent: Node3D, rng: RandomNumberGenerator, low := -6.0) -> void:
	var sky := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 60.0
	ball.height = 120.0
	ball.flip_faces = true
	sky.mesh = ball
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/sky.gdshader")
	sky.material_override = m
	parent.add_child(sky)
	# The moon, big and low, and the swamp far below in silhouette
	var moon := Shape.new().ball(Vector3.ZERO, Vector3(3.0, 3.0, 0.5), Color("fff2b0"), Color("f0d070"), 18, 10)
	var mm := moon.piece("moon", Shape.mat(1.0))
	mm.position = Vector3(-9, 9, -30)
	parent.add_child(mm)
	var hills := Shape.new()
	for k in 9:
		var x := -40.0 + k * 10.0 + rng.randf_range(-3, 3)
		hills.ball(Vector3(x, low, -36), Vector3(rng.randf_range(7, 12), rng.randf_range(4, 8), 2), Color("3a2e5a"), Color("241c40"), 12, 6)
	parent.add_child(hills.piece("hills", Shape.mat(0.8)))
