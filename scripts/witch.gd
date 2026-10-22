class_name Witch
extends Node3D
## A witch from models/witch_<name>.glb (art/make_models.py): one smooth mesh on a skeleton. The
## game poses the bones itself every frame: the head turns, the eyes look and blink, the mouth
## talks, the brows cross, and the arms reach (two-bone IK). Granny Grumblewart (`player`) keeps
## one hand on the stirring stick; the others are customers at the window, who pop up, wait
## (crosser and crosser), then cheer or stomp off.

signal gone

var model := "witch_grumblewart"
var player := false
## Where she looks, in the world
var look_at_point := Vector3(0, 1.4, 4)
var talking := false
## The player: how far the stick has gone round, and whether it's going
var stir_angle := 0.0
var stirring := false
var cauldron := Vector3.ZERO
var brew := 1.24
var stick: Node3D
## A customer: how much patience is left, 0 to 1
var patience := 1.0

var _bob: Node3D
var _sk: Skeleton3D
var _bones := {}
var _mat: ShaderMaterial
var _wand: Node3D
var _t := 0.0
var _blink := 2.0
var _mood := ""
var _mood_t := 0.0
var _toss_t := 9.0
var _zap_t := 9.0
var _stick_angle := -PI * 0.5
var _state := "in"
var _state_t := 0.0
var _home := Vector3.ZERO


static func make(model_name: String, is_player := false) -> Witch:
	var w := Witch.new()
	w.model = model_name
	w.player = is_player
	return w


func _ready() -> void:
	_t = randf() * 10.0
	_bob = Node3D.new()
	_bob.name = "bob"
	add_child(_bob)
	_mat = Shape.mat()
	var body := Models.make(model, _mat)
	_bob.add_child(body)
	_sk = body.find_children("*", "Skeleton3D", true, false)[0]
	for i in _sk.get_bone_count():
		_bones[_sk.get_bone_name(i)] = i
	_wand = Models.make("wand")
	_wand.visible = false
	add_child(_wand)
	_home = position
	if not player:
		position = _home + Vector3(0, -1.6, 0)


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


## A customer pops up at the window
func arrive() -> void:
	_state = "in"
	_state_t = 0.0
	visible = true


## Ducks down out of sight (another customer is being served), and back
func duck(down: bool) -> void:
	if _state in ["happy", "angry", "done"]:
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
	_mood_t += dt
	_toss_t += dt
	_zap_t += dt
	_state_t += dt
	if _mood != "" and _mood_t > 1.6:
		_mood = ""
	if not player:
		_move_customer(dt)
	_sk.reset_bone_poses()
	_pose_body()
	_pose_face(dt)
	if player:
		_pose_player_arms(dt)
	else:
		_pose_customer_arms()


func _move_customer(dt: float) -> void:
	var cross := clampf(1.0 - patience * 2.5, 0.0, 1.0)
	var down := _home + Vector3(0, -1.6, 0)
	match _state:
		"in":
			var k := clampf(_state_t / 0.5, 0.0, 1.0)
			position = down.lerp(_home, ease(k, 0.4)) + Vector3(0, sin(k * PI) * 0.15, 0)
			if _state_t > 1.2:
				_state = "wait"
		"wait":
			var hop := absf(sin(_t * (3.0 + cross * 6.0))) * (0.03 + cross * 0.06)
			position = _home + Vector3(sin(_t * 40.0) * 0.03 * cross, hop, 0)
		"down":
			position = position.lerp(down, minf(1.0, dt * 8.0))
			if position.y < down.y + 0.1:
				visible = false
		"happy":
			position = _home + Vector3(0, absf(sin(_state_t * 9.0)) * 0.3, 0)
			_bob.rotation.y = _state_t * 9.0
			if _state_t > 1.3:
				position.y -= (_state_t - 1.3) * 6.0
			if _state_t > 1.6:
				_finish()
		"angry":
			position = _home + Vector3(sin(_state_t * 30.0) * 0.05, 0, 0)
			if _state_t > 0.9:
				position.y -= (_state_t - 0.9) * 5.0
			if _state_t > 1.3:
				_finish()
	var red := cross if _state != "happy" else 0.0
	_mat.set_shader_parameter("tint", Vector3(1.0 + red * 0.5, 1.0 - red * 0.35, 1.0 - red * 0.35))


func _finish() -> void:
	if _state != "done":
		_state = "done"
		gone.emit()
		queue_free()


# --- posing the bones ---

func _bone(name: String) -> int:
	return _bones.get(name, -1)


## Turns a bone about an axis given in her own space (x her left, y up, z forward), on top of its pose now
func _turn(name: String, axis: Vector3, angle: float) -> void:
	var b := _bone(name)
	if b < 0 or absf(angle) < 0.0001:
		return
	var g := _sk.get_bone_global_pose(b)
	var local_axis := (g.basis.inverse() * axis).normalized()
	_sk.set_bone_pose_rotation(b, _sk.get_bone_pose_rotation(b) * Quaternion(local_axis, angle))


## Squashes a bone along an axis in her own space (1 is as made)
func _squash(name: String, axis: Vector3, amount: float) -> void:
	var b := _bone(name)
	if b < 0:
		return
	var local_axis := (_sk.get_bone_global_rest(b).basis.inverse() * axis).normalized().abs()
	_sk.set_bone_pose_scale(b, Vector3.ONE - local_axis * (1.0 - amount))


func _pose_body() -> void:
	var sway := sin(_t * 1.6) * 0.04
	var bounce := absf(sin(_t * 3.2)) * 0.03
	if _mood in ["cackle", "cheer"] or _state == "happy":
		bounce = absf(sin(_t * 12.0)) * 0.08
	_bob.position = Vector3(0, bounce, 0)
	_turn("hips", Vector3.FORWARD, sway)
	_turn("spine", Vector3.RIGHT, -0.05 + sin(_t * 2.0) * 0.02)
	# The head: looks where she's told, shakes when cross, throws back to cackle
	var to_look := _sk.global_transform.affine_inverse() * look_at_point
	var head_at := _sk.get_bone_global_pose(_bone("head")).origin
	var d := to_look - head_at
	var yaw := clampf(atan2(d.x, maxf(0.2, d.z)), -0.7, 0.7)
	var pitch := clampf(-atan2(d.y, maxf(0.3, Vector2(d.x, d.z).length())), -0.4, 0.4)
	match _mood:
		"cackle":
			pitch = -0.4 + sin(_t * 20.0) * 0.08
		"grumble":
			yaw += sin(_t * 18.0) * 0.3
			pitch = 0.15
		"shock":
			pitch = -0.25
		"cheer":
			yaw += sin(_t * 8.0) * 0.2
	if _state == "angry":
		yaw += sin(_t * 18.0) * 0.3
	_turn("neck", Vector3.UP, yaw * 0.4)
	_turn("head", Vector3.UP, yaw * 0.6)
	_turn("head", Vector3.RIGHT, pitch)
	_turn("hat", Vector3.FORWARD, sin(_t * 1.7) * 0.07)
	_turn("hat", Vector3.RIGHT, sin(_t * 2.1) * 0.05)


func _pose_face(dt: float) -> void:
	_blink -= dt
	var lid := 1.0
	if _blink < 0.0:
		lid = 0.1
		if _blink < -0.12:
			_blink = randf_range(1.5, 4.0)
	if _mood == "shock":
		lid = 1.2
	if _state == "happy" or _mood == "cackle":
		lid = 0.45
	var head := _sk.get_bone_global_pose(_bone("head"))
	var target := head.affine_inverse() * (_sk.global_transform.affine_inverse() * look_at_point)
	var dir := (Vector2(target.x, target.y - 0.35) / maxf(0.6, absf(target.z))).limit_length(1.0)
	for side: String in ["L", "R"]:
		_squash("eye." + side, Vector3.UP, lid)
		var p := _bone("pupil." + side)
		if p >= 0:
			var eye_basis := _sk.get_bone_global_rest(_bone("eye." + side)).basis
			var offset := eye_basis.inverse() * Vector3(dir.x * 0.055, dir.y * 0.06, 0)
			_sk.set_bone_pose_position(p, _sk.get_bone_rest(p).origin + offset)
		var cross := 0.3 if (_mood in ["grumble", ""] and player) or _state == "angry" or patience < 0.35 else -0.2
		_turn("brow." + side, Vector3.BACK, cross * (1.0 if side == "L" else -1.0))
	var open := 0.4
	if talking:
		open = 0.5 + absf(sin(_t * 17.0)) * 1.2
	if _mood in ["cackle", "shock"] or _state == "happy":
		open = 1.7
	_squash("mouth", Vector3.UP, open)


func _pose_player_arms(dt: float) -> void:
	# The stick: round the pot when stirring, otherwise leant against the far side
	if stirring:
		_stick_angle = stir_angle
	else:
		_stick_angle = lerp_angle(_stick_angle, -PI * 0.5 + sin(_t * 1.3) * 0.25, minf(1.0, dt * 2.0))
	var dip := cauldron + Vector3(cos(_stick_angle) * 0.42, brew - 0.15, sin(_stick_angle) * 0.42)
	var back := global_position - cauldron
	back.y = 0
	back = back.normalized()
	var top := dip + (back * 0.75 + Vector3.UP).normalized() * 1.35
	if _mood in ["cheer", "cackle"]:
		top += Vector3.UP * 0.1 * absf(sin(_t * 12.0))
	if stick != null:
		stick.global_position = top
		stick.look_at(dip, back)
	_reach("L", top.lerp(dip, 0.3), Vector3(1, -0.6, -0.4))
	# The other hand: on her hip, flinging a handful in, waving the wand, or up in the air
	var hand := to_global(Vector3(-0.45, 1.0, 0.18))
	_wand.visible = _zap_t < 0.9
	if _toss_t < 0.5:
		var k := _toss_t / 0.5
		var high := to_global(Vector3(-0.5, 2.0, 0.2))
		var over := cauldron + Vector3(0, 1.75, 0)
		hand = high.lerp(over, smoothstep(0.2, 0.7, k)) if k > 0.2 else hand.lerp(high, k / 0.2)
	elif _zap_t < 0.9:
		var k := _zap_t / 0.9
		hand = to_global(Vector3(-0.5, 1.95 + sin(k * PI * 3.0) * 0.12, 0.45 + k * 0.2))
	elif _mood in ["cheer", "cackle"]:
		hand = to_global(Vector3(-0.55, 2.2 + sin(_t * 12.0) * 0.08, 0.1))
	elif _mood == "grumble":
		hand = to_global(Vector3(-0.25, 2.0 + sin(_t * 18.0) * 0.04, 0.3))
	_reach("R", hand, Vector3(-1, -0.5, -0.5))
	if _wand.visible:
		# Gripped in the hand, pointing on along the forearm and up
		var g := _sk.global_transform * _sk.get_bone_global_pose(_bone("hand.R"))
		_wand.global_position = g.origin
		var along := (g.basis.y.normalized() + Vector3.UP * 0.8).normalized()
		_wand.global_basis = Basis(Quaternion(Vector3.UP, along)) * Basis.from_scale(Vector3.ONE * global_basis.get_scale().x)


func _pose_customer_arms() -> void:
	match _state:
		"happy":
			_reach("L", to_global(Vector3(0.5, 2.3, 0.1)), Vector3(1, 0, -0.5))
			_reach("R", to_global(Vector3(-0.5, 2.3, 0.1)), Vector3(-1, 0, -0.5))
		"angry":
			_reach("L", to_global(Vector3(0.12, 1.25, 0.3)), Vector3(1, 0, 0.2))
			_reach("R", to_global(Vector3(-0.12, 1.3, 0.32)), Vector3(-1, 0, 0.2))
		"in":
			# A wave hello
			_reach("L", to_global(Vector3(0.55, 2.1 + sin(_t * 14.0) * 0.08, 0.15)), Vector3(1, -0.3, -0.4))
		_:
			if patience < 0.3:
				# Hands on hips
				_reach("L", to_global(Vector3(0.32, 1.02, 0.08)), Vector3(1, 0.2, -0.3))
				_reach("R", to_global(Vector3(-0.32, 1.02, 0.08)), Vector3(-1, 0.2, -0.3))
			elif talking:
				_reach("R", to_global(Vector3(-0.35, 1.5 + sin(_t * 9.0) * 0.08, 0.45)), Vector3(-1, -0.4, -0.3))


## Two-bone reach: points the upper arm and forearm of `side` so the hand lands on `target`
## (world), with the elbow pushed toward `pole` (in her own space)
func _reach(side: String, target: Vector3, pole: Vector3) -> void:
	var u := _bone("upper." + side)
	var f := _bone("fore." + side)
	var h := _bone("hand." + side)
	if u < 0:
		return
	var t := _sk.global_transform.affine_inverse() * target
	var gu := _sk.get_bone_global_pose(u)
	var gf := _sk.get_bone_global_pose(f)
	var gh := _sk.get_bone_global_pose(h)
	var s := gu.origin
	var a := gf.origin.distance_to(s)
	var b := gh.origin.distance_to(gf.origin)
	var to := t - s
	var dist := clampf(to.length(), 0.05, a + b - 0.001)
	var dirn := to.normalized()
	var cos_bend := (a * a + dist * dist - b * b) / (2.0 * a * dist)
	var bend := acos(clampf(cos_bend, -1.0, 1.0))
	var p := pole.normalized()
	p = (p - dirn * p.dot(dirn)).normalized()
	var elbow := s + (dirn * cos(bend) + p * sin(bend)) * a
	var hand := s + dirn * dist
	var q1 := Quaternion((gf.origin - s).normalized(), (elbow - s).normalized())
	_sk.set_bone_global_pose(u, Transform3D(Basis(q1) * gu.basis, s))
	gf = _sk.get_bone_global_pose(f)
	gh = _sk.get_bone_global_pose(h)
	var q2 := Quaternion((gh.origin - gf.origin).normalized(), (hand - gf.origin).normalized())
	_sk.set_bone_global_pose(f, Transform3D(Basis(q2) * gf.basis, gf.origin))
