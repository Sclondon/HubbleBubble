class_name Waves
extends RefCounted
## The brew's surface as a real wave pool: a little grid of heights, worked on the CPU each step
## (each cell pulled toward its neighbours, a touch of drag), so whatever touches it (the stick
## dragged through, something dropped in, a bubble bursting, things bobbing) sends rings out that run
## across the pot, pass through one another and bounce back off the iron. Alongside it, foam: left
## where the stick goes (its wake), where things splash in and bubbles burst, fading after a moment.
## Handed to the shader as a small texture: red the height, green and blue its slope, alpha the foam.

const N := 42
const STEP := 1.0 / 50.0
## Heights are written to the texture over +-this many metres, slopes over +-SLOPE_RANGE
const HEIGHT_RANGE := 0.12
const SLOPE_RANGE := 1.5

var radius := 0.8
## How fast waves run (0 to 0.5), and how much is kept each step (thick brews drag more)
var speed := 0.32
var keep := 0.985
## How many times faster than real time it runs (the boil quickens it)
var rate := 1.0
## How much foam is kept each step
var foam_keep := 0.965
var texture: ImageTexture

var _h := PackedFloat32Array()
var _p := PackedFloat32Array()
var _f := PackedFloat32Array()
var _inside := PackedByteArray()
var _bytes := PackedByteArray()
var _img: Image
var _cell := 0.0
var _due := 0.0
var _quiet := 0.0


func _init(r: float) -> void:
	radius = r
	radius *= 1.07
	_cell = radius * 2.0 / N
	_h.resize(N * N)
	_p.resize(N * N)
	_f.resize(N * N)
	_inside.resize(N * N)
	_bytes.resize(N * N * 4)
	for j in N:
		for i in N:
			var x := (i + 0.5) * _cell - radius
			var z := (j + 0.5) * _cell - radius
			var edge := i == 0 or j == 0 or i == N - 1 or j == N - 1
			_inside[j * N + i] = 1 if (not edge and Vector2(x, z).length() < radius * 0.97 * Brew.pent(atan2(z, x))) else 0
	_encode()
	_img = Image.create_from_data(N, N, false, Image.FORMAT_RGBA8, _bytes)
	texture = ImageTexture.create_from_image(_img)


## Pushes the surface down (or up, negative) round a point (local x, z), `amount` metres, over `size` metres
func push(at: Vector2, amount: float, size := 0.08) -> void:
	_spread(at, size, func(k: int, w: float) -> void: _h[k] -= amount * w)


## Leaves foam round a point (0 to 1)
func foam(at: Vector2, amount: float, size := 0.06) -> void:
	_spread(at, size, func(k: int, w: float) -> void: _f[k] = minf(1.0, _f[k] + amount * w))


## How high the surface is at a point (local x, z), in metres
func height_at(at: Vector2) -> float:
	var x := clampf((at.x + radius) / _cell - 0.5, 0.0, N - 1.001)
	var z := clampf((at.y + radius) / _cell - 0.5, 0.0, N - 1.001)
	var i := int(x)
	var j := int(z)
	var fx := x - i
	var fz := z - j
	var k := j * N + i
	var a := lerpf(_h[k], _h[mini(k + 1, N * N - 1)], fx)
	var b := lerpf(_h[mini(k + N, N * N - 1)], _h[mini(k + N + 1, N * N - 1)], fx)
	return lerpf(a, b, fz)


func _spread(at: Vector2, size: float, apply: Callable) -> void:
	var ci := (at.x + radius) / _cell - 0.5
	var cj := (at.y + radius) / _cell - 0.5
	var reach := maxf(size / _cell, 1.0)
	var r := int(ceil(reach * 1.5))
	for j in range(maxi(1, int(cj) - r), mini(N - 1, int(cj) + r + 2)):
		for i in range(maxi(1, int(ci) - r), mini(N - 1, int(ci) + r + 2)):
			var k := j * N + i
			if _inside[k] == 0:
				continue
			var d2 := (Vector2(i, j) - Vector2(ci, cj)).length_squared() / (reach * reach)
			if d2 < 2.25:
				apply.call(k, exp(-d2 * 2.0))
	_quiet = 0.0


## Steps the waves on by `dt`; true if the texture changed
func update(dt: float) -> bool:
	if _quiet > 3.0:
		return false
	_due += dt * rate
	var stepped := false
	while _due >= STEP:
		_due -= STEP
		_step()
		stepped = true
	if not stepped:
		return false
	_quiet += dt
	var most := 0.0
	for k in range(0, N * N, 7):
		most = maxf(most, maxf(absf(_h[k]), _f[k] * 0.01))
	if most > 0.0004:
		_quiet = 0.0
	elif _quiet > 3.0:
		_h.fill(0.0)
		_p.fill(0.0)
		_f.fill(0.0)
	_encode()
	_img.set_data(N, N, false, Image.FORMAT_RGBA8, _bytes)
	texture.update(_img)
	return true


func _step() -> void:
	var c := speed
	var h := _h
	var p := _p
	var f := _f
	var fk := foam_keep
	for j in range(1, N - 1):
		var row := j * N
		for i in range(1, N - 1):
			var k := row + i
			if _inside[k] == 0:
				p[k] = 0.0
				continue
			var hk := h[k]
			# (a neighbour outside the pot counts as this cell: the wave bounces off the iron
			# with its height, rather than being held flat there)
			var around := (h[k - 1] if _inside[k - 1] else hk) + (h[k + 1] if _inside[k + 1] else hk) + (h[k - N] if _inside[k - N] else hk) + (h[k + N] if _inside[k + N] else hk)
			p[k] = (2.0 * hk - p[k] + c * (around - 4.0 * hk)) * keep
			f[k] *= fk
	# The new heights were written over the old-old ones: swap
	_h = p
	_p = h
	_f = f


func _encode() -> void:
	var inv_h := 0.5 / HEIGHT_RANGE
	var inv_s := 0.5 / (SLOPE_RANGE * 2.0 * _cell)
	var h := _h
	var f := _f
	var b := _bytes
	for j in N:
		var row := j * N
		for i in N:
			var k := row + i
			var o := k * 4
			if _inside[k] == 0:
				b[o] = 128
				b[o + 1] = 128
				b[o + 2] = 128
				b[o + 3] = 0
				continue
			b[o] = clampi(int((h[k] * inv_h + 0.5) * 255.0), 0, 255)
			b[o + 1] = clampi(int(((h[k + 1] - h[k - 1]) * inv_s + 0.5) * 255.0), 0, 255)
			b[o + 2] = clampi(int(((h[k + N] - h[k - N]) * inv_s + 0.5) * 255.0), 0, 255)
			b[o + 3] = clampi(int(f[k] * 255.0), 0, 255)
