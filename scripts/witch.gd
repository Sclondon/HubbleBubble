class_name Witch
extends Node3D
## Granny Grumblewart: green, hook-nosed, goggle-eyed, in a crooked hat. Rigid pieces like an old
## console character; her arms reach for things (two-bone IK), the right one always on the ladle.

const SKIN := Color("8fd04c")
const SKIN_D := Color("5a9630")
const DRESS := Color("8a55c8")
const DRESS_D := Color("4c2a7e")
const HAT := Color("5a3296")
const HAT_D := Color("2e1858")
const GOLD := Color("f2c840")
const HAIR := Color("4a4a5e")
const HAIR_D := Color("2a2a38")

const UPPER := 0.42
const LOWER := 0.42

var cauldron := Vector3.ZERO
var rim := 1.36
var brew := 1.24
## Where she looks, in the world
var look_at_point := Vector3(0, 1.4, 4)
var talking := false
## Driven by the game: how far the ladle has gone round
var stir_angle := 0.0
var stirring := false

var _bob: Node3D
var _head: Node3D
var _hat: Node3D
var _mouth: Node3D
var _eyes: Array[Node3D] = []
var _brows: Array[Node3D] = []
var _arm_r: Array[Node3D] = []
var _arm_l: Array[Node3D] = []
var _ladle: Node3D
var _wand: Node3D
var _t := 0.0
var _blink := 2.0
var _mood := ""
var _mood_t := 0.0
var _toss_t := 9.0
var _zap_t := 9.0
var _ladle_angle := 0.0


func _ready() -> void:
	_bob = Node3D.new()
	_bob.name = "bob"
	add_child(_bob)
	_build_body()
	_build_head()
	_arm_r = _build_arm("arm_r", 1.0)
	_arm_l = _build_arm("arm_l", -1.0)
	_build_ladle()
	_build_wand()


## A short act: "toss" (throws something in), "zap" (the wand), "cackle", "grumble", "cheer", "shock"
func act(what: String) -> void:
	match what:
		"toss":
			_toss_t = 0.0
		"zap":
			_zap_t = 0.0
		_:
			_mood = what
			_mood_t = 0.0


func _process(dt: float) -> void:
	_t += dt
	_mood_t += dt
	_toss_t += dt
	_zap_t += dt
	if _mood != "" and _mood_t > 1.6:
		_mood = ""
	# Bobbing and swaying, bouncier when she's pleased
	var bounce := absf(sin(_t * 3.2)) * 0.035
	var sway := sin(_t * 1.6) * 0.04
	if _mood == "cackle" or _mood == "cheer":
		bounce = absf(sin(_t * 12.0)) * 0.09
	_bob.position = Vector3(0, bounce, 0)
	_bob.rotation = Vector3(0, 0, sway)
	# The head: looks where it's told, shakes when cross, throws back when cackling
	var to_look := global_transform.affine_inverse() * look_at_point
	var yaw := clampf(atan2(to_look.x, maxf(0.2, to_look.z)), -0.6, 0.6)
	var head_turn := Vector3(sin(_t * 0.9) * 0.05, yaw, 0)
	match _mood:
		"cackle":
			head_turn = Vector3(-0.35 + sin(_t * 20.0) * 0.08, 0, sin(_t * 10.0) * 0.1)
		"grumble":
			head_turn = Vector3(0.15, sin(_t * 18.0) * 0.3, 0)
		"shock":
			head_turn = Vector3(-0.2, 0, 0)
		"cheer":
			head_turn = Vector3(-0.2, sin(_t * 8.0) * 0.15, 0)
	_head.rotation = _head.rotation.lerp(head_turn, minf(1.0, dt * 10.0))
	_hat.rotation = Vector3(sin(_t * 2.1) * 0.06, 0, sin(_t * 1.7) * 0.08 + _head.rotation.z * 0.6)
	# Eyes follow the thing she's looking at, and blink now and then
	_blink -= dt
	var lid := 1.0
	if _blink < 0.0:
		lid = 0.12
		if _blink < -0.12:
			_blink = randf_range(1.5, 4.0)
	if _mood == "shock":
		lid = 1.25
	var local := _head.global_transform.affine_inverse() * look_at_point
	var dir := Vector2(local.x, local.y - 0.4) / maxf(0.5, absf(local.z))
	for e in _eyes:
		e.scale.y = lerpf(e.scale.y, lid, minf(1.0, dt * 25.0))
		Shape.look(e, dir * 1.2)
	for i in _brows.size():
		var sgn := 1.0 if i == 0 else -1.0
		var mean := 0.35 if _mood in ["grumble", ""] else -0.25
		_brows[i].rotation.z = lerpf(_brows[i].rotation.z, sgn * mean, minf(1.0, dt * 8.0))
	# Mouth flaps when she talks, gapes when she cackles
	var open := 0.35
	if talking:
		open = 0.4 + absf(sin(_t * 17.0)) * 1.1
	if _mood == "cackle" or _mood == "shock":
		open = 1.6
	_mouth.scale.y = lerpf(_mouth.scale.y, open, minf(1.0, dt * 20.0))
	_arms(dt)


func _arms(dt: float) -> void:
	# The ladle: round the pot when stirring, otherwise leant against the far side
	var target := stir_angle if stirring else (_ladle_angle + 0.0)
	if not stirring:
		target = lerp_angle(_ladle_angle, -PI * 0.5 + sin(_t * 1.3) * 0.25, minf(1.0, dt * 2.0))
	_ladle_angle = target
	var dip := cauldron + Vector3(cos(_ladle_angle) * 0.42, brew - 0.12, sin(_ladle_angle) * 0.42)
	var back := (global_position - cauldron)
	back.y = 0
	back = back.normalized()
	var top := dip + (back * 0.8 + Vector3.UP * 0.75).normalized() * 1.2 * global_transform.basis.get_scale().x
	if _mood == "cheer" or _mood == "cackle":
		top += Vector3.UP * 0.12 * absf(sin(_t * 12.0))
	_ladle.global_position = top
	_ladle.look_at(dip, back)
	_reach(_arm_r, top.lerp(dip, 0.3), Vector3(1, -0.6, -0.4))
	# The left: on her hip, flinging a handful in, waving the wand, or up in the air
	var rest := global_transform * Vector3(-0.42, 1.05, 0.15)
	var hand := rest
	_wand.visible = _zap_t < 0.9
	if _toss_t < 0.5:
		var k := _toss_t / 0.5
		var high := global_transform * Vector3(-0.5, 2.0, 0.1)
		var over := cauldron + Vector3(0, rim + 0.4, 0)
		hand = high.lerp(over, smoothstep(0.2, 0.7, k)) if k > 0.2 else rest.lerp(high, k / 0.2)
	elif _zap_t < 0.9:
		var k := _zap_t / 0.9
		hand = global_transform * Vector3(-0.55, 1.95 + sin(k * PI * 3.0) * 0.12, 0.35 + k * 0.2)
	elif _mood == "cheer" or _mood == "cackle":
		hand = global_transform * Vector3(-0.6, 2.2 + sin(_t * 12.0) * 0.08, 0.1)
	elif _mood == "grumble":
		hand = global_transform * Vector3(-0.3, 1.9 + sin(_t * 18.0) * 0.04, 0.25)
	_reach(_arm_l, hand, Vector3(-1, -0.5, -0.5))
	if _wand.visible:
		var hand_node: Node3D = _arm_l[1]
		_wand.global_transform = hand_node.global_transform.translated_local(Vector3(0, 0, -LOWER))
		_wand.rotate_object_local(Vector3.RIGHT, -1.0)


## Two-bone reach: points the upper arm and forearm so the hand lands on `target` (world), with
## the elbow pushed toward `pole` (in her own space)
func _reach(arm: Array[Node3D], target: Vector3, pole: Vector3) -> void:
	var upper := arm[0]
	var fore := arm[1]
	var k := global_transform.basis.get_scale().x
	var up_len := UPPER * k
	var low_len := LOWER * k
	var s := upper.global_position
	var to := target - s
	var d := clampf(to.length(), 0.05, up_len + low_len - 0.001)
	var dirn := to.normalized()
	var a := (up_len * up_len + d * d - low_len * low_len) / (2.0 * up_len * d)
	var bend := acos(clampf(a, -1.0, 1.0))
	var p := (global_transform.basis * pole).normalized()
	p = (p - dirn * p.dot(dirn)).normalized()
	var elbow := s + (dirn * cos(bend) + p * sin(bend)) * up_len
	var hand := s + dirn * d
	upper.look_at(elbow, p if absf(p.dot((elbow - s).normalized())) < 0.99 else Vector3.UP)
	fore.global_position = elbow
	fore.look_at(hand, p if absf(p.dot((hand - elbow).normalized())) < 0.99 else Vector3.UP)


func _build_body() -> void:
	var s := Shape.new()
	s.tube(Vector3(0, 0, 0), Vector3(0, 1.5, 0), 0.6, 0.2, DRESS_D, DRESS, 12)
	s.ring(Vector3(0, 0.04, 0), 0.6, 0.06, DRESS_D.darkened(0.2), 14, 4)
	# Patches sewn on, a belt with a big buckle
	s.box(Vector3(0.22, 0.55, 0.42), Vector3(0.2, 0.2, 0.04), Color("3fa070"), null, Basis(Vector3.UP, 0.45) * Basis(Vector3.FORWARD, 0.2))
	s.box(Vector3(-0.3, 0.3, 0.42), Vector3(0.18, 0.16, 0.04), Color("d06a3a"), null, Basis(Vector3.UP, -0.55))
	s.tube(Vector3(0, 1.0, 0), Vector3(0, 1.1, 0), 0.32, 0.3, Color("2a1a14"), null, 12)
	s.box(Vector3(0, 1.05, 0.31), Vector3(0.18, 0.15, 0.04), GOLD, GOLD.darkened(0.3))
	s.box(Vector3(0, 1.05, 0.33), Vector3(0.09, 0.07, 0.03), Color("2a1a14"))
	# Shoulders and a shawl
	s.ball(Vector3(0, 1.48, 0), Vector3(0.34, 0.16, 0.24), DRESS, DRESS_D, 10, 6)
	s.ball(Vector3(0, 1.42, 0.02), Vector3(0.38, 0.12, 0.27), Color("3a2c4a"), Color("241a30"), 10, 5)
	s.tube(Vector3(0, 1.5, 0), Vector3(0, 1.72, 0), 0.1, 0.09, SKIN_D, SKIN, 8)
	_bob.add_child(s.piece("body"))


func _build_head() -> void:
	_head = Node3D.new()
	_head.name = "head"
	_head.position = Vector3(0, 1.68, 0)
	_bob.add_child(_head)
	var s := Shape.new()
	s.ball(Vector3(0, 0.3, 0), Vector3(0.33, 0.35, 0.31), SKIN, SKIN_D, 14, 9)
	# A long chin that juts out, and the nose: hooked, with a wart
	s.bend([Vector3(0, 0.12, 0.12), Vector3(0, 0.0, 0.26), Vector3(0, -0.05, 0.36)], 0.14, 0.035, SKIN, SKIN_D, 8)
	s.bend([Vector3(0, 0.38, 0.24), Vector3(0, 0.36, 0.46), Vector3(0, 0.27, 0.6), Vector3(0, 0.15, 0.62)], 0.085, 0.03, SKIN, SKIN_D.lightened(0.1), 8)
	s.ball(Vector3(0.065, 0.36, 0.46), Vector3(0.035, 0.035, 0.035), Color("a07a3a"), null, 6, 4)
	s.ball(Vector3(0.075, 0.39, 0.47), Vector3(0.012, 0.012, 0.012), Color("2a2a2a"), null, 4, 3)
	# Pointed ears
	for sgn: float in [-1.0, 1.0]:
		s.tube(Vector3(sgn * 0.3, 0.32, -0.02), Vector3(sgn * 0.55, 0.44, -0.08), 0.09, 0.0, SKIN, SKIN_D, 6, true, 0.45)
	# Cheeks
	for sgn: float in [-1.0, 1.0]:
		s.ball(Vector3(sgn * 0.2, 0.22, 0.22), Vector3(0.08, 0.06, 0.05), Color("b8d870"), null, 6, 4)
	# Stringy hair down her back and sides
	for i in 9:
		var a := lerpf(-1.75, 1.75, i / 8.0)
		var root := Vector3(sin(a) * 0.3, 0.52, -cos(a) * 0.26)
		var out := Vector3(sin(a), 0, -cos(a))
		var swing := 0.05 * sin(i * 1.7)
		s.bend([root, root + out * 0.12 + Vector3(swing, -0.25, 0), root + out * 0.16 + Vector3(-swing, -0.55, -0.02), root + out * 0.2 + Vector3(swing, -0.78, -0.06)], 0.05, 0.018, HAIR, HAIR_D, 5)
	_head.add_child(s.piece("face"))
	# Big googly eyes up by the nose, cross little brows
	for sgn: float in [-1.0, 1.0]:
		var e := Shape.eye(Vector3(0.125, 0.155, 0.085), Color("fffbe8"), 0.32)
		e.position = Vector3(sgn * 0.115, 0.45, 0.26)
		e.rotation = Vector3(-0.1, sgn * 0.25, 0)
		_head.add_child(e)
		_eyes.append(e)
		var brow := Node3D.new()
		brow.position = Vector3(sgn * 0.12, 0.6, 0.28)
		brow.add_child(Shape.new().box(Vector3.ZERO, Vector3(0.16, 0.035, 0.04), HAIR_D).piece("brow"))
		_head.add_child(brow)
		_brows.append(brow)
	# The mouth, dark, with her one tooth
	_mouth = Node3D.new()
	_mouth.name = "mouth"
	_mouth.position = Vector3(0, 0.2, 0.27)
	var m := Shape.new()
	m.ball(Vector3.ZERO, Vector3(0.14, 0.05, 0.05), Color("401020"), Color("200810"), 10, 5)
	m.box(Vector3(0.04, 0.025, 0.035), Vector3(0.035, 0.04, 0.02), Color("fff2b0"))
	_mouth.add_child(m.piece("mouth"))
	_head.add_child(_mouth)
	# The hat: wide brim, gold band and buckle, crooked bent point
	_hat = Node3D.new()
	_hat.name = "hat"
	_hat.position = Vector3(0, 0.62, -0.03)
	_hat.rotation_degrees = Vector3(-6, 0, 6)
	var h := Shape.new()
	h.tube(Vector3(0, -0.02, 0), Vector3(0, 0.03, 0), 0.68, 0.66, HAT_D, HAT, 18)
	h.tube(Vector3(0, 0.03, 0), Vector3(0, 0.14, 0), 0.34, 0.32, GOLD, GOLD, 14, false)
	h.box(Vector3(0, 0.085, 0.33), Vector3(0.14, 0.13, 0.03), GOLD.lightened(0.2), GOLD.darkened(0.3))
	h.box(Vector3(0, 0.085, 0.345), Vector3(0.07, 0.06, 0.02), HAT_D)
	h.bend([Vector3(0, 0.12, 0), Vector3(0, 0.5, -0.04), Vector3(0.04, 0.85, -0.14), Vector3(0.18, 1.05, -0.3), Vector3(0.34, 1.08, -0.4)], 0.32, 0.03, HAT, HAT_D.lightened(0.15), 12)
	h.box(Vector3(-0.12, 0.42, 0.22), Vector3(0.12, 0.12, 0.03), Color("3fa070"), null, Basis(Vector3.UP, -0.4) * Basis(Vector3.FORWARD, 0.3))
	_hat.add_child(h.piece("hat"))
	_head.add_child(_hat)


func _build_arm(name: String, sgn: float) -> Array[Node3D]:
	var upper := Node3D.new()
	upper.name = name
	upper.position = Vector3(sgn * 0.3, 1.48, 0.02)
	var u := Shape.new()
	u.ball(Vector3.ZERO, Vector3(0.11, 0.11, 0.11), DRESS, DRESS_D, 8, 5)
	u.tube(Vector3.ZERO, Vector3(0, 0, -UPPER), 0.1, 0.09, DRESS, DRESS_D, 8)
	upper.add_child(u.piece("upper"))
	_bob.add_child(upper)
	var fore := Node3D.new()
	fore.name = name + "_fore"
	var f := Shape.new()
	# A floppy sleeve cuff, a skinny green arm, a knobbly hand with long fingers
	f.tube(Vector3.ZERO, Vector3(0, 0, -0.16), 0.1, 0.15, DRESS, DRESS_D, 8, false)
	f.tube(Vector3(0, 0, -0.05), Vector3(0, 0, -LOWER), 0.05, 0.045, SKIN, SKIN_D, 6)
	f.ball(Vector3(0, 0, -LOWER), Vector3(0.075, 0.06, 0.085), SKIN, SKIN_D, 8, 5)
	for k in 3:
		var off := (k - 1) * 0.035
		f.bend([Vector3(off, 0, -LOWER - 0.05), Vector3(off * 1.3, -0.03, -LOWER - 0.13), Vector3(off * 1.4, -0.07, -LOWER - 0.16)], 0.022, 0.012, SKIN, SKIN_D, 4)
	fore.add_child(f.piece("fore"))
	_bob.add_child(fore)
	return [upper, fore]


func _build_ladle() -> void:
	_ladle = Node3D.new()
	_ladle.name = "ladle"
	var s := Shape.new()
	s.tube(Vector3(0, 0, 0.15), Vector3(0, 0, -1.2), 0.035, 0.03, Color("b07a40"), Color("7a4a24"), 6)
	s.ball(Vector3(0, 0, -1.25), Vector3(0.12, 0.05, 0.14), Color("7a4a24"), Color("5a3418"), 8, 4)
	_ladle.add_child(s.piece("ladle"))
	add_child(_ladle)


func _build_wand() -> void:
	_wand = Node3D.new()
	_wand.name = "wand"
	var s := Shape.new()
	s.tube(Vector3.ZERO, Vector3(0, 0, -0.5), 0.022, 0.016, Color("3a2418"), Color("6a4428"), 5)
	_wand.add_child(s.piece("stick"))
	var star := Shape.new()
	star.ball(Vector3(0, 0, -0.55), Vector3(0.07, 0.07, 0.07), Color("fff27a"), Color("ffc43a"), 6, 4)
	_wand.add_child(star.piece("star", Shape.mat(1.0)))
	_wand.visible = false
	add_child(_wand)
