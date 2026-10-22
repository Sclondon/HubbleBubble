class_name Icons
## Every picture on the controls and tickets, drawn by hand onto a CanvasItem: chunky shapes with a
## thick dark outline and a shine, like a cartoon sticker.

const INK := Color("2a1630")
const SHINE := Color(1, 1, 1, 0.55)


static func oval(c: Vector2, r: Vector2, rot := 0.0, n := 28) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y).rotated(rot))
	return pts


static func blob(ci: CanvasItem, pts: PackedVector2Array, fill: Color, line := 0.0) -> void:
	ci.draw_colored_polygon(pts, fill)
	if line > 0.0:
		var closed := pts.duplicate()
		closed.append(pts[0])
		ci.draw_polyline(closed, INK, line, true)


static func ball(ci: CanvasItem, c: Vector2, r: float, fill: Color, line: float) -> void:
	ci.draw_circle(c, r + line * 0.5, INK)
	ci.draw_circle(c, r - line * 0.5, fill)


static func shine(ci: CanvasItem, c: Vector2, r: Vector2, rot := -0.6) -> void:
	ci.draw_colored_polygon(oval(c, r, rot, 12), SHINE)


static func line(ci: CanvasItem, pts: PackedVector2Array, w: float, col := INK) -> void:
	ci.draw_polyline(pts, col, w, true)
	for p in [pts[0], pts[-1]]:
		ci.draw_circle(p, w * 0.5, col)


## An ingredient, `s` across
static func ingredient(ci: CanvasItem, which: int, c: Vector2, s: float) -> void:
	var k := s / 100.0
	var w := maxf(2.0, 5.0 * k)
	match which:
		0:  # Eye of newt
			ball(ci, c, 40 * k, Color("fbf6e6"), w)
			for a: float in [0.4, 1.9, 3.4, 4.6]:
				var p := c + Vector2.from_angle(a) * 36 * k
				line(ci, PackedVector2Array([p, p.lerp(c, 0.25) + Vector2.from_angle(a + 1.2) * 4 * k, p.lerp(c, 0.45)]), 2.5 * k, Color("d8303a"))
			ball(ci, c + Vector2(4, 2) * k, 21 * k, Color("3ac0a8"), w * 0.6)
			ci.draw_colored_polygon(oval(c + Vector2(4, 2) * k, Vector2(5, 15) * k), INK)
			shine(ci, c + Vector2(-12, -14) * k, Vector2(9, 5) * k)
		1:  # Toadstool
			var stem := PackedVector2Array([c + Vector2(-14, -2) * k, c + Vector2(14, -2) * k, c + Vector2(18, 40) * k, c + Vector2(-18, 40) * k])
			blob(ci, stem, Color("f2e4c0"), w)
			var cap := PackedVector2Array()
			for i in 17:
				var a := PI + PI * i / 16.0
				cap.append(c + Vector2(cos(a) * 46, sin(a) * 40 + 4) * k)
			blob(ci, cap, Color("e8382a"), w)
			for d: Vector3 in [Vector3(-22, -10, 8), Vector3(4, -24, 9), Vector3(24, -8, 7), Vector3(-6, -4, 5)]:
				ci.draw_circle(c + Vector2(d.x, d.y) * k, d.z * k, Color("fffbf0"))
			shine(ci, c + Vector2(-18, -24) * k, Vector2(10, 5) * k)
		2:  # Bat wing
			var pts := PackedVector2Array([c + Vector2(-44, -24) * k, c + Vector2(-10, -34) * k, c + Vector2(20, -30) * k, c + Vector2(46, -38) * k,
				c + Vector2(40, -6) * k, c + Vector2(44, 22) * k, c + Vector2(26, 10) * k, c + Vector2(12, 34) * k, c + Vector2(-2, 14) * k,
				c + Vector2(-20, 32) * k, c + Vector2(-26, 6) * k])
			blob(ci, pts, Color("8a52c9"), w)
			for e: Vector2 in [Vector2(40, -6), Vector2(26, 10), Vector2(-2, 14), Vector2(-26, 6)]:
				line(ci, PackedVector2Array([c + Vector2(-44, -24) * k, c + e * k]), 2.5 * k, Color("4c2a7e"))
			shine(ci, c + Vector2(-8, -22) * k, Vector2(12, 4) * k, 0.0)
		3:  # Frog leg
			blob(ci, oval(c + Vector2(-14, -14) * k, Vector2(20, 28) * k, -0.6), Color("86d84a"), w)
			blob(ci, PackedVector2Array([c + Vector2(-2, 0) * k, c + Vector2(10, -6) * k, c + Vector2(26, 24) * k, c + Vector2(16, 30) * k]), Color("74c43a"), w)
			var foot := PackedVector2Array([c + Vector2(16, 26) * k, c + Vector2(44, 22) * k, c + Vector2(38, 32) * k, c + Vector2(46, 40) * k,
				c + Vector2(30, 40) * k, c + Vector2(26, 48) * k, c + Vector2(14, 36) * k])
			blob(ci, foot, Color("a8e870"), w)
			shine(ci, c + Vector2(-22, -26) * k, Vector2(7, 4) * k)
		4:  # Spider
			for sgn: float in [-1.0, 1.0]:
				for i in 4:
					var a := -0.9 + i * 0.55
					var knee := c + Vector2(sgn * 30, -18 + i * 10) * k
					var foot := c + Vector2(sgn * 46, 4 + i * 14) * k + Vector2(0, -abs(a) * 10) * k
					line(ci, PackedVector2Array([c, knee, foot]), 5 * k)
			ball(ci, c + Vector2(0, 10) * k, 24 * k, Color("2e2a4a"), w)
			ball(ci, c + Vector2(0, -16) * k, 14 * k, Color("2e2a4a"), w)
			blob(ci, PackedVector2Array([c + Vector2(-6, 2) * k, c + Vector2(6, 2) * k, c + Vector2(0, 10) * k]), Color("e8303a"))
			blob(ci, PackedVector2Array([c + Vector2(-6, 18) * k, c + Vector2(6, 18) * k, c + Vector2(0, 10) * k]), Color("e8303a"))
			ci.draw_circle(c + Vector2(-5, -18) * k, 4 * k, Color.WHITE)
			ci.draw_circle(c + Vector2(5, -18) * k, 4 * k, Color.WHITE)
		5:  # Moon petal
			for i in 5:
				var a := TAU * i / 5.0 - PI * 0.5
				blob(ci, oval(c + Vector2.from_angle(a) * 22 * k, Vector2(22, 13) * k, a), Color("b8d4ff"), w * 0.8)
			ball(ci, c, 13 * k, Color("fff27a"), w * 0.7)
			ci.draw_colored_polygon(oval(c + Vector2(3, -2) * k, Vector2(9, 9) * k), Color("ffd040"))
			shine(ci, c + Vector2(-4, -30) * k, Vector2(7, 3) * k, 0.0)
		6:  # Ghost pepper: a fat white chilli with a ghostly face
			var left := PackedVector2Array()
			var right := PackedVector2Array()
			for i in 13:
				var t := i / 12.0
				var p := Vector2(-18 + t * 40 + sin(t * PI) * 10, -26 + t * 62 - t * t * 8)
				var nxt := Vector2(-18 + (t + 0.01) * 40 + sin((t + 0.01) * PI) * 10, -26 + (t + 0.01) * 62 - (t + 0.01) * (t + 0.01) * 8)
				var side := (nxt - p).normalized().orthogonal()
				var wid := 22.0 * (1.0 - t * t) + 1.0
				left.append(c + (p + side * wid) * k)
				right.append(c + (p - side * wid) * k)
			right.reverse()
			blob(ci, left + right, Color("fff0f6"), w)
			blob(ci, oval(c + Vector2(-20, -30) * k, Vector2(20, 8) * k, -0.2), Color("4a9a3a"), w * 0.8)
			line(ci, PackedVector2Array([c + Vector2(-22, -34) * k, c + Vector2(-30, -46) * k]), 6 * k, Color("3a7a2a"))
			ci.draw_colored_polygon(oval(c + Vector2(-10, -6) * k, Vector2(4, 6) * k), INK)
			ci.draw_colored_polygon(oval(c + Vector2(4, -4) * k, Vector2(4, 6) * k), INK)
			ci.draw_colored_polygon(oval(c + Vector2(-2, 8) * k, Vector2(5, 4) * k), INK)
			shine(ci, c + Vector2(-16, -16) * k, Vector2(4, 8) * k, 0.3)
		7:  # Dragon scale
			var pts := PackedVector2Array([c + Vector2(0, -42) * k, c + Vector2(34, -20) * k, c + Vector2(30, 14) * k, c + Vector2(0, 44) * k,
				c + Vector2(-30, 14) * k, c + Vector2(-34, -20) * k])
			blob(ci, pts, Color("ffa22e"), w)
			blob(ci, PackedVector2Array([c + Vector2(0, -30) * k, c + Vector2(20, -14) * k, c + Vector2(0, 30) * k, c + Vector2(-20, -14) * k]), Color("ffd060"))
			line(ci, PackedVector2Array([c + Vector2(0, -30) * k, c + Vector2(0, 30) * k]), 3 * k, Color("c86a10"))
			shine(ci, c + Vector2(-14, -18) * k, Vector2(8, 4) * k)


## A potion bottle in `col`
static func bottle(ci: CanvasItem, c: Vector2, s: float, col: Color, cork := true) -> void:
	var k := s / 100.0
	var w := maxf(2.0, 5.0 * k)
	blob(ci, PackedVector2Array([c + Vector2(-10, -40) * k, c + Vector2(10, -40) * k, c + Vector2(10, -16) * k, c + Vector2(-10, -16) * k]), Color("d8f0f8"), w)
	ball(ci, c + Vector2(0, 12) * k, 32 * k, col, w)
	ci.draw_colored_polygon(oval(c + Vector2(0, 0) * k, Vector2(28, 6) * k), col.lightened(0.3))
	shine(ci, c + Vector2(-14, 0) * k, Vector2(8, 12) * k, 0.3)
	if cork:
		blob(ci, PackedVector2Array([c + Vector2(-12, -52) * k, c + Vector2(12, -52) * k, c + Vector2(10, -38) * k, c + Vector2(-10, -38) * k]), Color("c8925a"), w * 0.8)


## The bellows
static func bellows(ci: CanvasItem, c: Vector2, s: float, squeeze := 0.0) -> void:
	var k := s / 100.0
	var w := maxf(2.0, 5.0 * k)
	var open := 1.0 - squeeze * 0.45
	line(ci, PackedVector2Array([c + Vector2(-38, -20 * open) * k, c + Vector2(-50, -36 * open) * k]), 8 * k, Color("8a5a2a"))
	line(ci, PackedVector2Array([c + Vector2(-38, 20 * open) * k, c + Vector2(-50, 36 * open) * k]), 8 * k, Color("8a5a2a"))
	blob(ci, PackedVector2Array([c + Vector2(-36, -30 * open) * k, c + Vector2(22, -6) * k, c + Vector2(22, 6) * k, c + Vector2(-36, 30 * open) * k, c + Vector2(-42, 0) * k]), Color("c03a2a"), w)
	blob(ci, PackedVector2Array([c + Vector2(-36, -30 * open) * k, c + Vector2(22, -6) * k, c + Vector2(4, -4) * k, c + Vector2(-34, -6) * k]), Color("b07a40"), w * 0.7)
	blob(ci, PackedVector2Array([c + Vector2(20, -6) * k, c + Vector2(48, -3) * k, c + Vector2(48, 3) * k, c + Vector2(20, 6) * k]), Color("8a8090"), w * 0.7)


static func flame(ci: CanvasItem, c: Vector2, s: float, level: int) -> void:
	var k := s / 100.0
	var col: Color = Book.HEAT_COLOURS[level]
	var h := 22.0 + level * 9.0
	var pts := PackedVector2Array()
	for i in 15:
		var a := lerpf(-PI * 0.18, PI * 1.18, i / 14.0)
		pts.append(c + Vector2(cos(a) * 24, 12 + sin(a) * 24) * k)
	pts.append(c + Vector2(-14, -10 - h * 0.4) * k)
	pts.append(c + Vector2(-4, -14 - h * 0.3) * k)
	pts.append(c + Vector2(4, -12 - h) * k)
	pts.append(c + Vector2(12, -8 - h * 0.45) * k)
	pts.reverse()
	blob(ci, pts, col, maxf(2.0, 5.0 * k))
	blob(ci, oval(c + Vector2(0, 16) * k, Vector2(11, 12) * k), col.lightened(0.5))
static func stir(ci: CanvasItem, c: Vector2, s: float, dir: int) -> void:
	var col := Color("6ad0ff") if dir > 0 else Color("ff9ad0")
	var k := s / 100.0
	var pts := PackedVector2Array()
	var r := 30 * k
	for i in 25:
		var a := lerpf(-PI * 0.75, PI * 0.95, i / 24.0) - PI * 0.5
		pts.append(c + Vector2(cos(a) * dir, sin(a) * 0.8) * r)
	line(ci, pts, 13 * k)
	line(ci, pts, 7 * k, col)
	var tip := pts[-1]
	var back := (pts[-1] - pts[-4]).normalized()
	var side := back.orthogonal()
	blob(ci, PackedVector2Array([tip + back * 14 * k, tip + side * 12 * k, tip - side * 12 * k]), col, 3 * k)
	# The ladle, dipped in the middle
	line(ci, PackedVector2Array([c + Vector2(4, -26) * k, c + Vector2(-2, 6) * k]), 7 * k, Color("8a5a2a"))


static func wand(ci: CanvasItem, c: Vector2, s: float) -> void:
	var k := s / 100.0
	line(ci, PackedVector2Array([c + Vector2(-34, 34) * k, c + Vector2(10, -10) * k]), 12 * k)
	line(ci, PackedVector2Array([c + Vector2(-34, 34) * k, c + Vector2(10, -10) * k]), 7 * k, Color("6a4428"))
	star(ci, c + Vector2(16, -16) * k, 22 * k, Color("fff27a"))
	for d: Vector2 in [Vector2(38, -36), Vector2(-4, -36), Vector2(36, 8)]:
		star(ci, c + d * k, 7 * k, Color("ffffff"), 0.0)


static func star(ci: CanvasItem, c: Vector2, r: float, col: Color, outline := 4.0) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := TAU * i / 10.0 - PI * 0.5
		pts.append(c + Vector2.from_angle(a) * (r if i % 2 == 0 else r * 0.45))
	blob(ci, pts, col, outline * r / 22.0)


static func book(ci: CanvasItem, c: Vector2, s: float) -> void:
	var k := s / 100.0
	var w := maxf(2.0, 5.0 * k)
	blob(ci, PackedVector2Array([c + Vector2(-38, -30) * k, c + Vector2(34, -30) * k, c + Vector2(34, 32) * k, c + Vector2(-38, 32) * k]), Color("8a2a3a"), w)
	blob(ci, PackedVector2Array([c + Vector2(-30, -24) * k, c + Vector2(40, -24) * k, c + Vector2(40, 38) * k, c + Vector2(-30, 38) * k]), Color("f4e4bc"), w * 0.7)
	blob(ci, PackedVector2Array([c + Vector2(-38, -30) * k, c + Vector2(30, -30) * k, c + Vector2(30, 30) * k, c + Vector2(-38, 30) * k]), Color("a83a4a"), w)
	star(ci, c + Vector2(-4, 0) * k, 14 * k, Color("f2c840"), 3.0)


## A customer's little face, for their ticket
static func face(ci: CanvasItem, kind: String, c: Vector2, r: float) -> void:
	var cols := {"frog": Color("6cc840"), "mole": Color("8a5a3a"), "ghost": Color("f2f4ff"), "goblin": Color("b8d84a"),
			"shroom": Color("e8382a"), "pumpkin": Color("ff8a1a"), "bat": Color("7a4aa8")}
	var w := maxf(2.0, r * 0.12)
	match kind:
		"goblin":
			for sgn: float in [-1.0, 1.0]:
				blob(ci, PackedVector2Array([c + Vector2(sgn * r * 0.7, -r * 0.2), c + Vector2(sgn * r * 1.5, -r * 0.6), c + Vector2(sgn * r * 0.8, r * 0.3)]), cols[kind], w)
		"bat":
			for sgn: float in [-1.0, 1.0]:
				blob(ci, PackedVector2Array([c + Vector2(sgn * r * 0.3, -r * 0.7), c + Vector2(sgn * r * 0.75, -r * 1.45), c + Vector2(sgn * r * 0.85, -r * 0.4)]), cols[kind], w)
	ball(ci, c, r, cols[kind], w)
	match kind:
		"shroom":
			ci.draw_circle(c + Vector2(0, r * 0.4), r * 0.6, Color("f0e2c0"))
			ci.draw_circle(c + Vector2(-r * 0.5, -r * 0.4), r * 0.15, Color.WHITE)
			ci.draw_circle(c + Vector2(r * 0.4, -r * 0.55), r * 0.12, Color.WHITE)
		"pumpkin":
			for sgn: float in [-1.0, 1.0]:
				blob(ci, PackedVector2Array([c + Vector2(sgn * r * 0.15, -r * 0.05), c + Vector2(sgn * r * 0.6, -r * 0.05), c + Vector2(sgn * r * 0.38, -r * 0.45)]), Color("ffe060"))
			blob(ci, oval(c + Vector2(0, r * 0.4), Vector2(r * 0.55, r * 0.15)), Color("ffe060"))
			line(ci, PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.2, -r * 1.3)]), w * 1.4, Color("4a8a2a"))
			return
		"ghost":
			ci.draw_colored_polygon(oval(c + Vector2(-r * 0.32, -r * 0.1), Vector2(r * 0.17, r * 0.27)), INK)
			ci.draw_colored_polygon(oval(c + Vector2(r * 0.32, -r * 0.1), Vector2(r * 0.17, r * 0.27)), INK)
			ci.draw_circle(c + Vector2(0, r * 0.45), r * 0.15, INK)
			return
		"mole":
			ci.draw_circle(c + Vector2(0, r * 0.25), r * 0.22, Color("ff7aa0"))
	var ey := -r * 0.15 if kind != "shroom" else r * 0.15
	for sgn: float in [-1.0, 1.0]:
		ci.draw_circle(c + Vector2(sgn * r * 0.34, ey), r * 0.26, INK)
		ci.draw_circle(c + Vector2(sgn * r * 0.34, ey), r * 0.2, Color.WHITE)
		ci.draw_circle(c + Vector2(sgn * r * 0.3, ey + r * 0.03), r * 0.09, INK)
	ci.draw_arc(c + Vector2(0, r * 0.3), r * 0.3, 0.3, PI - 0.3, 10, INK, w * 0.8, true)


static func coin(ci: CanvasItem, c: Vector2, r: float) -> void:
	ball(ci, c, r, Color("f6c838"), maxf(2.0, r * 0.18))
	ci.draw_circle(c, r * 0.62, Color("e0a820"))
	ci.draw_circle(c, r * 0.48, Color("f6c838"))
	shine(ci, c + Vector2(-r * 0.35, -r * 0.35), Vector2(r * 0.25, r * 0.14))


static func padlock(ci: CanvasItem, c: Vector2, s: float) -> void:
	var k := s / 100.0
	ci.draw_arc(c + Vector2(0, -8) * k, 16 * k, PI, TAU, 12, INK, 14 * k, true)
	ci.draw_arc(c + Vector2(0, -8) * k, 16 * k, PI, TAU, 12, Color("a8a0b0"), 7 * k, true)
	blob(ci, PackedVector2Array([c + Vector2(-24, -8) * k, c + Vector2(24, -8) * k, c + Vector2(24, 26) * k, c + Vector2(-24, 26) * k]), Color("e0b030"), 5 * k)
	ci.draw_circle(c + Vector2(0, 6) * k, 5 * k, INK)


static func gear(ci: CanvasItem, c: Vector2, s: float) -> void:
	var k := s / 100.0
	for i in 3:
		var y := (-20 + i * 20) * k
		line(ci, PackedVector2Array([c + Vector2(-26 * k, y), c + Vector2(26 * k, y)]), 12 * k)
		line(ci, PackedVector2Array([c + Vector2(-26 * k, y), c + Vector2(26 * k, y)]), 6 * k, Color("f4e4bc"))


static func step(ci: CanvasItem, st: Dictionary, c: Vector2, s: float) -> void:
	match st.kind:
		Book.ADD:
			ingredient(ci, st.what, c, s)
		Book.HEAT:
			flame(ci, c + Vector2(0, s * 0.08), s, st.level)
		Book.STIR:
			stir(ci, c, s, st.dir)
		Book.ZAP:
			wand(ci, c, s * 0.9)
		Book.BOTTLE:
			bottle(ci, c, s * 0.85, Color("c8e8ff"))
