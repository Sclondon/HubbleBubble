class_name Critter
extends Node3D
## A customer at the window: a frog, a mole, a ghost, a goblin, a mushroom man, a pumpkinhead or a
## bat, all googly eyes and bounce. Pops up, waits (crosser and crosser), cheers or stomps off.

signal gone

var kind := "frog"
var patience := 1.0
var talking := false
var look_at_point := Vector3(0, 1.5, 0)

var _body: Node3D
var _mouth: Node3D
var _eyes: Array[Node3D] = []
var _mat: ShaderMaterial
var _t := 0.0
var _state := "in"
var _state_t := 0.0
var _home := Vector3.ZERO
var _blink := 1.0
var _wings: Array[Node3D] = []


static func make(kind_name: String) -> Critter:
	var c := Critter.new()
	c.kind = kind_name
	return c


func _ready() -> void:
	_t = randf() * 10.0
	_mat = Shape.mat()
	_body = Node3D.new()
	_body.name = "body"
	add_child(_body)
	call("_build_" + kind)
	for mi: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		if mi.material_override == Shape.plain():
			mi.material_override = _mat
	_home = position
	position = _home + Vector3(0, -1.4, 0)


## Pops up at the window
func arrive() -> void:
	_state = "in"
	_state_t = 0.0


## Ducks down out of sight (another customer is being served), and back
func duck(down: bool) -> void:
	if _state in ["happy", "angry"]:
		return
	visible = true
	_state = "down" if down else "in"
	_state_t = 0.0


func happy() -> void:
	visible = true
	_state = "happy"
	_state_t = 0.0


func angry() -> void:
	visible = true
	_state = "angry"
	_state_t = 0.0


func _process(dt: float) -> void:
	_t += dt
	_state_t += dt
	var cross := clampf(1.0 - patience * 2.5, 0.0, 1.0)
	var target := _home
	match _state:
		"in":
			var k := clampf(_state_t / 0.45, 0.0, 1.0)
			var over := sin(k * PI) * 0.15
			position = (_home + Vector3(0, -1.4, 0)).lerp(_home, ease(k, 0.4)) + Vector3(0, over, 0)
			if k >= 1.0:
				_state = "wait"
		"wait":
			var hop := absf(sin(_t * (3.0 + cross * 6.0))) * (0.04 + cross * 0.08)
			var shake := sin(_t * 40.0) * 0.03 * cross
			position = target + Vector3(shake, hop, 0)
		"down":
			position = position.lerp(_home + Vector3(0, -1.4, 0), minf(1.0, dt * 8.0))
			if position.y < _home.y - 1.3:
				visible = false
		"happy":
			var jump := absf(sin(_state_t * 9.0)) * 0.35
			position = _home + Vector3(0, jump, 0)
			_body.rotation.y = _state_t * 9.0
			if _state_t > 1.3:
				position.y -= (_state_t - 1.3) * 6.0
			if _state_t > 1.6:
				_finish()
		"angry":
			var stomp := sin(_state_t * 30.0) * 0.05
			position = _home + Vector3(stomp, 0, 0)
			if _state_t > 0.8:
				position.y -= (_state_t - 0.8) * 5.0
			if _state_t > 1.2:
				_finish()
	if kind == "ghost":
		position.y += sin(_t * 2.0) * 0.06
	for i in _wings.size():
		_wings[i].rotation.z = (1.0 if i == 0 else -1.0) * (0.3 + sin(_t * 18.0) * 0.4)
	_mat.set_shader_parameter("tint", Vector3(1.0 + cross * 0.5, 1.0 - cross * 0.35, 1.0 - cross * 0.35) if _state != "happy" else Vector3.ONE)
	# Eyes on the witch or the brew, blinking; the mouth flaps when they talk
	_blink -= dt
	var lid := 1.0
	if _blink < 0.0:
		lid = 0.1
		if _blink < -0.1:
			_blink = randf_range(1.2, 3.5)
	var local := _body.global_transform.affine_inverse() * look_at_point
	var dir := Vector2(local.x, local.y - 0.9) / maxf(0.5, local.z)
	for e in _eyes:
		e.scale.y = lerpf(e.scale.y, lid, minf(1.0, dt * 25.0))
		if e.has_node("pupil"):
			Shape.look(e, dir)
	if _mouth != null:
		var open := 0.5
		if talking:
			open = 0.5 + absf(sin(_t * 16.0)) * 1.2
		if _state == "happy":
			open = 1.5
		if _state == "angry":
			open = 0.25
		_mouth.scale.y = lerpf(_mouth.scale.y, open, minf(1.0, dt * 20.0))


func _finish() -> void:
	if _state != "done":
		_state = "done"
		gone.emit()
		queue_free()


func _eye_pair(at: Vector3, apart: float, r: Vector3, spread := 0.2) -> void:
	for sgn: float in [-1.0, 1.0]:
		var e := Shape.eye(r)
		e.position = at + Vector3(sgn * apart, 0, 0)
		e.rotation.y = sgn * spread
		_body.add_child(e)
		_eyes.append(e)


func _add_mouth(at: Vector3, r: Vector3, col := Color("3a0c18"), tongue := true) -> void:
	_mouth = Node3D.new()
	_mouth.position = at
	var m := Shape.new().ball(Vector3.ZERO, r, col, col.darkened(0.4), 10, 5)
	if tongue:
		m.ball(Vector3(0, -r.y * 0.4, r.z * 0.4), Vector3(r.x * 0.5, r.y * 0.4, r.z * 0.5), Color("e86a8a"), null, 8, 4)
	_mouth.add_child(m.piece("mouth"))
	_body.add_child(_mouth)


func _build_frog() -> void:
	var s := Shape.new()
	var g := Color("6cc840")
	var gd := Color("3e8a2a")
	s.ball(Vector3(0, 0.5, 0), Vector3(0.5, 0.45, 0.42), g, Color("d8e890"), 14, 8)
	s.ball(Vector3(0, 0.95, 0.02), Vector3(0.48, 0.32, 0.4), g, gd, 14, 8)
	for sgn: float in [-1.0, 1.0]:
		s.ball(Vector3(sgn * 0.24, 1.2, 0.08), Vector3(0.16, 0.15, 0.15), g, gd, 10, 6)
		s.ball(Vector3(sgn * 0.3, 0.75, 0.3), Vector3(0.05, 0.05, 0.05), gd, null, 6, 4)
	# A spotty back and a red bow tie
	s.ball(Vector3(0.2, 1.1, -0.25), Vector3(0.08, 0.06, 0.05), gd, null, 6, 4)
	s.ball(Vector3(-0.25, 0.95, -0.3), Vector3(0.07, 0.06, 0.05), gd, null, 6, 4)
	s.tri(Vector3(0, 0.7, 0.42), Vector3(-0.18, 0.78, 0.38), Vector3(-0.18, 0.6, 0.38), Color("e8303a"))
	s.tri(Vector3(0, 0.7, 0.42), Vector3(0.18, 0.6, 0.38), Vector3(0.18, 0.78, 0.38), Color("e8303a"))
	s.ball(Vector3(0, 0.7, 0.42), Vector3(0.05, 0.05, 0.04), Color("c02028"), null, 6, 4)
	_body.add_child(s.piece("frog"))
	_eye_pair(Vector3(0, 1.24, 0.17), 0.24, Vector3(0.12, 0.13, 0.08))
	_add_mouth(Vector3(0, 0.88, 0.37), Vector3(0.3, 0.06, 0.06))


func _build_mole() -> void:
	var s := Shape.new()
	var b := Color("8a5a3a")
	var bd := Color("54341e")
	s.ball(Vector3(0, 0.65, 0), Vector3(0.48, 0.62, 0.42), b, bd, 14, 8)
	s.ball(Vector3(0, 0.55, 0.3), Vector3(0.28, 0.35, 0.15), Color("d8b088"), null, 10, 6)
	s.ball(Vector3(0, 1.0, 0.45), Vector3(0.13, 0.1, 0.12), Color("ff7aa0"), Color("d04a70"), 10, 6)
	for sgn: float in [-1.0, 1.0]:
		s.ball(Vector3(sgn * 0.42, 0.45, 0.25), Vector3(0.14, 0.1, 0.12), Color("ffb0c0"), null, 8, 5)
		for k in 3:
			s.tube(Vector3(sgn * (0.42 + (k - 1) * 0.06), 0.4, 0.33), Vector3(sgn * (0.42 + (k - 1) * 0.08), 0.32, 0.42), 0.025, 0.005, Color("f4ecd8"), null, 4)
		# Round spectacles
		s.ring(Vector3(sgn * 0.15, 1.15, 0.38), 0.11, 0.018, Color("e8c040"), 12, 4, Basis(Vector3.RIGHT, PI * 0.5))
	s.tube(Vector3(-0.04, 1.15, 0.4), Vector3(0.04, 1.15, 0.4), 0.015, 0.015, Color("e8c040"), null, 4)
	# A miner's cap
	s.ball(Vector3(0, 1.25, -0.02), Vector3(0.38, 0.18, 0.36), Color("e0b830"), Color("a88420"), 12, 6)
	s.ball(Vector3(0, 1.32, 0.3), Vector3(0.07, 0.07, 0.04), Color("fff6b0"), null, 6, 4)
	_body.add_child(s.piece("mole"))
	_eye_pair(Vector3(0, 1.15, 0.36), 0.15, Vector3(0.06, 0.065, 0.04), 0.1)
	_add_mouth(Vector3(0, 0.85, 0.38), Vector3(0.12, 0.04, 0.05))


func _build_ghost() -> void:
	var s := Shape.new()
	var w := Color("f2f4ff")
	var wd := Color("b8c0e8")
	s.ball(Vector3(0, 0.95, 0), Vector3(0.45, 0.6, 0.4), w, wd, 14, 9)
	s.tube(Vector3(0, 0.95, 0), Vector3(0, 0.35, 0), 0.45, 0.5, w, wd, 14, false)
	for i in 7:
		var a := TAU * i / 7.0
		s.ball(Vector3(cos(a) * 0.42, 0.35, sin(a) * 0.38), Vector3(0.14, 0.14, 0.14), wd, wd.darkened(0.15), 8, 5)
	for sgn: float in [-1.0, 1.0]:
		s.bend([Vector3(sgn * 0.42, 0.85, 0.05), Vector3(sgn * 0.62, 0.8, 0.15), Vector3(sgn * 0.7, 0.95, 0.22)], 0.1, 0.05, w, wd, 6)
	_body.add_child(s.piece("ghost", Shape.mat(0.35)))
	# Hollow black eyes and a round O of a mouth
	for sgn: float in [-1.0, 1.0]:
		var e := Node3D.new()
		e.position = Vector3(sgn * 0.15, 1.12, 0.36)
		e.add_child(Shape.new().ball(Vector3.ZERO, Vector3(0.08, 0.12, 0.04), Color("181020"), null, 8, 6).piece("hole"))
		_body.add_child(e)
		_eyes.append(e)
	_add_mouth(Vector3(0, 0.85, 0.38), Vector3(0.08, 0.08, 0.04), Color("181020"), false)


func _build_goblin() -> void:
	var s := Shape.new()
	var g := Color("b8d84a")
	var gd := Color("7a9a2a")
	s.ball(Vector3(0, 0.4, 0), Vector3(0.36, 0.42, 0.32), Color("c03a2a"), Color("7a1a14"), 12, 7)
	s.ring(Vector3(0, 0.15, 0), 0.34, 0.05, Color("5a3a1a"), 12, 4)
	s.ball(Vector3(0, 1.0, 0), Vector3(0.38, 0.34, 0.34), g, gd, 14, 8)
	for sgn: float in [-1.0, 1.0]:
		s.tube(Vector3(sgn * 0.3, 1.05, -0.02), Vector3(sgn * 0.78, 1.25, -0.1), 0.16, 0.0, g, gd, 7, true, 0.4)
		s.ball(Vector3(sgn * 0.62, 1.15, -0.06), Vector3(0.04, 0.04, 0.04), Color("f2c840"), null, 6, 4)
	s.bend([Vector3(0, 1.0, 0.3), Vector3(0, 0.98, 0.5), Vector3(0, 0.88, 0.62)], 0.08, 0.04, g.lightened(0.1), gd, 7)
	# Two snaggle teeth and a little cap
	s.ball(Vector3(0, 1.28, 0), Vector3(0.24, 0.1, 0.24), Color("3a5ac8"), Color("223a8a"), 10, 5)
	s.ball(Vector3(0, 1.4, 0), Vector3(0.06, 0.06, 0.06), Color("f2c840"), null, 6, 4)
	_body.add_child(s.piece("goblin"))
	_eye_pair(Vector3(0, 1.1, 0.26), 0.13, Vector3(0.09, 0.11, 0.07))
	_add_mouth(Vector3(0, 0.8, 0.28), Vector3(0.16, 0.04, 0.05))
	var teeth := Shape.new()
	teeth.box(Vector3(-0.07, 0.02, 0.04), Vector3(0.04, 0.06, 0.02), Color("fff6d0"))
	teeth.box(Vector3(0.08, 0.02, 0.04), Vector3(0.04, 0.05, 0.02), Color("fff6d0"))
	_mouth.add_child(teeth.piece("teeth"))


func _build_shroom() -> void:
	var s := Shape.new()
	var stalk := Color("f0e2c0")
	s.tube(Vector3(0, 0.1, 0), Vector3(0, 1.0, 0), 0.36, 0.28, stalk.darkened(0.15), stalk, 12)
	s.ball(Vector3(0, 1.2, 0), Vector3(0.62, 0.38, 0.58), Color("e8382a"), Color("a81c18"), 16, 8)
	s.disc(Vector3(0, 1.0, 0), Vector2(0.58, 0.54), Color("e8d8b0"), 16, Basis(Vector3.RIGHT, PI), Color("c8b080"))
	for i in 7:
		var a := TAU * i / 7.0 + 0.3
		var up := 0.45 if i % 2 else 0.75
		var d := Vector3(cos(a) * sin(up), cos(up), sin(a) * sin(up))
		s.ball(Vector3(0, 1.2, 0) + d * Vector3(0.6, 0.37, 0.56), Vector3(0.1, 0.1, 0.1), Color("fffbf0"), null, 6, 4)
	s.ball(Vector3(0, 1.58, 0), Vector3(0.1, 0.1, 0.1), Color("fffbf0"), null, 6, 4)
	_body.add_child(s.piece("shroom"))
	_eye_pair(Vector3(0, 0.82, 0.3), 0.12, Vector3(0.09, 0.11, 0.06))
	_add_mouth(Vector3(0, 0.55, 0.32), Vector3(0.12, 0.04, 0.05))


func _build_pumpkin() -> void:
	var s := Shape.new()
	# A patched shirt for a body, a pumpkin for a head
	s.tube(Vector3(0, 0.0, 0), Vector3(0, 0.62, 0), 0.32, 0.36, Color("3a6ab8"), Color("4a7ac8"), 10)
	s.box(Vector3(0.12, 0.35, 0.33), Vector3(0.14, 0.14, 0.03), Color("d8a840"))
	for sgn: float in [-1.0, 1.0]:
		s.tube(Vector3(sgn * 0.33, 0.55, 0), Vector3(sgn * 0.45, 0.35, 0.05), 0.05, 0.02, Color("e8c860"), null, 5)
	var o := Color("ff8a1a")
	var od := Color("c05a10")
	for i in 6:
		var a := TAU * i / 6.0
		s.ball(Vector3(cos(a) * 0.2, 1.0, sin(a) * 0.17), Vector3(0.28, 0.36, 0.26), o, od, 10, 7)
	s.bend([Vector3(0, 1.3, 0), Vector3(0.03, 1.45, 0), Vector3(0.12, 1.52, 0)], 0.06, 0.035, Color("5a8a2a"), null, 6)
	_body.add_child(s.piece("pumpkin"))
	# Carved eyes and grin, glowing from inside
	var glow := Shape.new()
	for sgn: float in [-1.0, 1.0]:
		glow.tri(Vector3(sgn * 0.08, 1.02, 0.42), Vector3(sgn * 0.26, 1.02, 0.39), Vector3(sgn * 0.17, 1.2, 0.41), Color("ffe060"))
	glow.tri(Vector3(-0.04, 0.95, 0.44), Vector3(0.04, 0.95, 0.44), Vector3(0, 1.02, 0.44), Color("ffe060"))
	var eyes := glow.piece("eyes", Shape.mat(1.0))
	_body.add_child(eyes)
	_eyes.append(eyes)
	_mouth = Node3D.new()
	_mouth.position = Vector3(0, 0.86, 0.42)
	var m := Shape.new()
	m.ball(Vector3.ZERO, Vector3(0.24, 0.06, 0.03), Color("ffd040"), null, 10, 4)
	m.box(Vector3(-0.08, 0.04, 0.02), Vector3(0.05, 0.05, 0.02), o)
	m.box(Vector3(0.08, -0.04, 0.02), Vector3(0.05, 0.05, 0.02), o)
	_mouth.add_child(m.piece("grin", Shape.mat(1.0)))
	_body.add_child(_mouth)


func _build_bat() -> void:
	var s := Shape.new()
	var p := Color("7a4aa8")
	var pd := Color("432868")
	s.ball(Vector3(0, 0.75, 0), Vector3(0.38, 0.45, 0.34), p, pd, 12, 8)
	s.ball(Vector3(0, 0.62, 0.22), Vector3(0.22, 0.26, 0.14), Color("b890d8"), null, 10, 6)
	for sgn: float in [-1.0, 1.0]:
		s.tube(Vector3(sgn * 0.18, 1.1, 0), Vector3(sgn * 0.34, 1.5, -0.02), 0.13, 0.0, p, pd, 6, true, 0.45)
		s.tube(Vector3(sgn * 0.18, 1.12, 0.03), Vector3(sgn * 0.32, 1.42, 0.02), 0.07, 0.0, Color("e8a0c0"), null, 6, true, 0.3)
	s.ball(Vector3(0, 0.98, 0.33), Vector3(0.06, 0.04, 0.04), Color("e86a8a"), null, 6, 4)
	_body.add_child(s.piece("bat"))
	for sgn: float in [-1.0, 1.0]:
		var wing := Node3D.new()
		wing.position = Vector3(sgn * 0.32, 0.85, -0.05)
		var w := Shape.new()
		w.tri(Vector3.ZERO, Vector3(sgn * 0.7, 0.35, -0.1), Vector3(sgn * 0.55, -0.25, -0.05), pd, p)
		w.tri(Vector3.ZERO, Vector3(sgn * 0.55, -0.25, -0.05), Vector3(sgn * 0.25, -0.35, 0), pd, p)
		w.tube(Vector3.ZERO, Vector3(sgn * 0.7, 0.35, -0.1), 0.03, 0.015, pd, null, 4)
		wing.add_child(w.piece("wing"))
		_body.add_child(wing)
		_wings.append(wing)
	_eye_pair(Vector3(0, 1.03, 0.25), 0.14, Vector3(0.11, 0.12, 0.07))
	_add_mouth(Vector3(0, 0.85, 0.3), Vector3(0.12, 0.04, 0.05))
	var fangs := Shape.new()
	fangs.tube(Vector3(-0.06, 0.0, 0.04), Vector3(-0.06, -0.08, 0.05), 0.022, 0.0, Color("fffbe8"), null, 4)
	fangs.tube(Vector3(0.06, 0.0, 0.04), Vector3(0.06, -0.08, 0.05), 0.022, 0.0, Color("fffbe8"), null, 4)
	_mouth.add_child(fangs.piece("fangs"))
