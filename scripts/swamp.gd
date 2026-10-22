class_name Swamp
extends Node3D
## The swamp, as a diorama, where ingredients are gathered between nights: each one waits at its
## own place (newts in the pool, toadstools on the log, bats in the dead tree, frogs on the lily
## pads, a spider by the reeds, moon flowers on the mound, ghost peppers among the graves, scales by
## the dragon's bones). A tap gathers one; it grows back after a moment. Sits far off in the world.

## Where each ingredient is found, on the diorama
const PLACES := [
	Vector3(-0.35, 0.06, 0.05),
	Vector3(-1.9, 0.28, 0.9),
	Vector3(0.75, 1.25, -1.3),
	Vector3(-1.05, 0.06, -0.45),
	Vector3(1.55, 0.05, -0.7),
	Vector3(0.9, 0.24, 1.4),
	Vector3(-1.75, 0.05, -1.3),
	Vector3(2.2, 0.08, 0.15),
]
const REGROW := 2.0

var camera_at := Transform3D()
## id -> {at, r}, for picking what's tapped (as the hut has)
var spots := {}
var _items := {}
var _gone := {}
var _t := 0.0


func _ready() -> void:
	add_child(Models.make("swamp"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	Tower.night_sky(self, rng, -14.0)
	camera_at = Transform3D(Basis(), Vector3(0, 4.2, 5.0)).looking_at(Vector3(0, 0.3, 0.1))
	for i in PLACES.size():
		var holder := Node3D.new()
		holder.name = "gather%d" % i
		holder.position = PLACES[i]
		add_child(holder)
		var item := Models.make(Hut.INGREDIENT_MODELS[i])
		item.scale = Vector3.ONE * 1.6
		holder.add_child(item)
		var ring := Shape.new().ring(Vector3.ZERO, 0.32, 0.025, Color("fff27a"), 20, 4)
		holder.add_child(ring.piece("ring", Shape.flame_mat(Color.WHITE, 0.7)))
		_items[i] = holder


## Shows only what grows in time for the night ahead
func open_for(count: int) -> void:
	spots.clear()
	_gone.clear()
	for i in PLACES.size():
		var holder: Node3D = _items[i]
		holder.visible = i < count
		holder.scale = Vector3.ONE
		if i < count:
			spots["gather%d" % i] = {"at": global_transform * (PLACES[i] + Vector3(0, 0.25, 0)), "r": 0.45}


## Gathers ingredient `i` if it's there; true if it was
func gather(i: int) -> bool:
	if _gone.has(i) or not spots.has("gather%d" % i):
		return false
	_gone[i] = REGROW
	Sfx.play("plop", 1.4, -4.0)
	return true


func _process(dt: float) -> void:
	_t += dt
	for i in _items:
		var holder: Node3D = _items[i]
		if _gone.has(i):
			_gone[i] -= dt
			var k: float = _gone[i] / REGROW
			# Gone with a hop, then growing back
			holder.scale = Vector3.ONE * (smoothstep(0.0, 1.0, 1.0 - k) if k < 0.8 else maxf(0.0, (k - 0.8) * 5.0) * 1.2)
			if _gone[i] <= 0.0:
				_gone.erase(i)
				holder.scale = Vector3.ONE
		else:
			holder.position.y = PLACES[i].y + sin(_t * 2.0 + i) * 0.04
			holder.rotation.y = sin(_t * 0.7 + i) * 0.3
