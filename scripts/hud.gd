class_name Hud
extends Control
## Everything on the glass, drawn by hand: the order tickets, the recipe being brewed, the jars,
## the bellows and the heat, what people say, and the cards between nights. Multi-touch: one
## finger can stir round the pot while another works the bellows. Laid out tall for phones and
## wide for desktops.

const INK := Color("2a1630")
const PARCH := Color("f6e7c1")
const PARCH_D := Color("d9c08a")
const WOOD := Color("7a4624")
const WOOD_L := Color("a8683a")
const GOLD := Color("f2c840")
const GREEN := Color("7ad84a")
const RED := Color("e8473a")
const HOLD_PUMP := 0.3
## How long a finger held still on the brew takes to tip it out
const TIP_HOLD := 0.9

var shop: Shop
## Drawing only the floating book's two pages, into its own little picture (see Shop.show_book_pages)
var page_only := false
var page_shown := 0
var buttons := {}
var size_now := Vector2.ZERO
var tall := true
var squeeze := 0.0

var font: FontVariation
var font_bold: FontVariation
var book_font: Font
var book_title_font: Font
var note_font: FontVariation
## What customers say is in this: a small font drawn without smoothing and blown up whole pixels at a
## time, so it's chunky like an old console's, not crisp
var speech_font: FontVariation
## The page the book is open at, and its buttons
var book_page := 0
var buttons_book := {}
var _tickets: Array[Rect2] = []
var _strip := Rect2()
var _gauge := Rect2()
var _panel := Rect2()
var _top := Rect2()
var _touches := {}
var _t := 0.0
var _bumps := {}
var _ticks := {}
var _shakes := {}
var _held_pump := {}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var base: FontFile = load("res://fonts/Fredoka.ttf")
	font = FontVariation.new()
	font.base_font = base
	font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 500}
	font_bold = FontVariation.new()
	font_bold.base_font = base
	book_font = load("res://fonts/LibreBaskerville-Italic.ttf")
	book_title_font = load("res://fonts/LibreBaskerville.ttf")
	var chunky: FontFile = (load("res://fonts/Fredoka.ttf") as FontFile).duplicate()
	chunky.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	chunky.fixed_size = 14
	chunky.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_INTEGER_ONLY
	chunky.hinting = TextServer.HINTING_NONE
	speech_font = FontVariation.new()
	speech_font.base_font = chunky
	speech_font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 650}
	note_font = FontVariation.new()
	note_font.base_font = load("res://fonts/Caveat.ttf")
	note_font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 600}
	font_bold.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 650}
	layout()


func bump(i: int) -> void:
	_bumps[i] = 0.0


func tick_step(i: int) -> void:
	_ticks[i] = 0.0


func shake(id: String) -> void:
	_shakes[id] = 0.0


func _process(dt: float) -> void:
	if page_only:
		return
	_t += dt
	squeeze = maxf(0.0, squeeze - dt * 4.0)
	for d: Dictionary in [_bumps, _ticks, _shakes]:
		for k: Variant in d.keys():
			d[k] += dt
			if d[k] > 0.6:
				d.erase(k)
	# A finger held still on the brew tips it out
	for idx: int in _touches.keys():
		var t: Dictionary = _touches[idx]
		if t.get("id", "") == "stir" and t.get("still", 0.0) >= 0.0:
			t.still = t.get("still", 0.0) + dt
			if t.still >= TIP_HOLD:
				t.still = -99.0
				shop.tip_out()
	# Holding the bellows keeps pumping
	for idx: int in _held_pump.keys():
		_held_pump[idx] -= dt
		if _held_pump[idx] <= 0.0:
			_held_pump[idx] = HOLD_PUMP
			shop.pump()
	var s := get_viewport_rect().size
	if s != size_now:
		layout()
	queue_redraw()


func layout() -> void:
	size_now = get_viewport_rect().size
	var w := size_now.x
	var h := size_now.y
	tall = h > w * 1.1
	buttons.clear()
	_tickets.clear()
	_top = Rect2(0, 0, w, 70)
	buttons["pause"] = {"rect": Rect2(w - 74, 8, 62, 56)}
	# Out to the swamp and the balcony (as the back window and the door do)
	# Up the periscope, to watch whoever's drinking a potion out on the island
	buttons["go_scope"] = {"rect": Rect2(w - 76, 84, 64, 64)}
	# The orders: small notes pegged to a string across the top
	var tw := minf(168.0, (w - 70) / 3.0) if tall else 190.0
	for i in 3:
		_tickets.append(Rect2(22 + i * (tw + 12), 100, tw, tw * 0.6))
	if tall:
		_gauge = Rect2(w - 40, 290, 28, h * 0.26)
	else:
		_gauge = Rect2(w - 64, 220, 44, h * 0.42)
	for i in _tickets.size():
		buttons["ticket%d" % i] = {"rect": _tickets[i]}


# --- touches ---

func _input(event: InputEvent) -> void:
	if page_only:
		return
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		if e.pressed:
			_press(e.index, e.position)
		else:
			var was: String = _touches.get(e.index, {}).get("id", "")
			if was == "hold":
				shop.release()
			elif was == "stir":
				shop.stir_release()
			_touches.erase(e.index)
			_held_pump.erase(e.index)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var e := event as InputEventScreenDrag
		# Some iPhones never send the finger going down: a drag from a finger not seen yet takes it up
		if not _touches.has(e.index) and shop.state == "play" and not shop.paused and not shop.book_open:
			var on_button := false
			for id: String in buttons:
				if _hit(id, e.position):
					on_button = true
			if not on_button:
				_touches[e.index] = {"id": "stir", "last": e.position}
		var t: Dictionary = _touches.get(e.index, {})
		if t.get("id", "") == "hold":
			shop.drag_to(e.position)
		elif t.get("id", "") == "stir":
			if e.position.distance_to(t.get("from", e.position)) > 16.0:
				t.still = -99.0
			shop.stir_touch(e.position)
			t.last = e.position
		get_viewport().set_input_as_handled()


func _press(index: int, at: Vector2) -> void:
	# (dev mode's panel down the right takes its own touches)
	if shop.dev != null and at.x > size_now.x - 360:
		return
	if shop.fade > 0.05:
		return
	match shop.state:
		"swamp":
			if _hit("pause", at):
				shop.toggle_pause()
			elif _hit("leave_swamp", at):
				shop.leave_swamp()
			elif not shop.paused:
				shop.gather_at(at)
				return
		"tower":
			if _hit("pause", at):
				shop.toggle_pause()
			elif not shop.paused:
				shop.back_from_tower()
				return
		"intro":
			if _hit("pause", at):
				shop.toggle_pause()
				return
			if not shop.paused:
				shop.begin_play()
				return
		"done", "over":
			shop.next_night()
			return
	if shop.paused:
		if _hit("resume", at):
			shop.toggle_pause()
		elif _hit("sound", at):
			shop.set_sound(Sfx.me.muted)
		elif _hit("dev", at):
			shop.toggle_dev()
		return
	if shop.book_open:
		_book_tap(at)
		return
	for id: String in buttons:
		if id in ["resume", "sound", "dev", "leave_swamp", "go_shop", "go_free", "go_swamp"] or not _hit(id, at):
			continue
		_touches[index] = {"id": id, "last": at}
		if id.begins_with("ticket"):
			shop.select(int(id.substr(6)))
		elif id == "pause":
			shop.toggle_pause()
		elif id == "go_scope":
			shop.visit_balcony()
		return
	var thing := shop.pick(at)
	# On the brew it stirs, unless the finger is right on something standing behind it
	if thing == "" or thing == "stir" or (shop.on_brew(at) and shop.pick_k > 0.6):
		# The pot, or anywhere else in the middle: stirring (or, held still, tipping it out)
		_touches[index] = {"id": "stir", "last": at, "from": at, "still": 0.0}
		shop.stir_touch(at)
		return
	_touches[index] = {"id": thing, "last": at}
	if thing.begins_with("jar"):
		_touches[index].id = "hold"
		shop.grab(int(thing.substr(3)), at)
		return
	if thing == "bottle":
		_touches[index].id = "hold"
		shop.grab_bottle(at)
		return
	shop.tap(thing)
	if thing == "bellows":
		_held_pump[index] = HOLD_PUMP * 1.6


func _hit(id: String, at: Vector2) -> bool:
	return buttons.has(id) and (buttons[id].rect as Rect2).has_point(at)


# --- drawing ---

func _draw() -> void:
	if page_only:
		_draw_open_book()
		return
	if shop.loading():
		_draw_loading()
		return
	match shop.state:
		"tower":
			_draw_tower()
		"swamp":
			_draw_swamp()
		_:
			_draw_top()
			_draw_away()
			# (the order notes hang in the hut now: see Tickets)
			_draw_counts()
			_draw_speech()
			if shop.book_open:
				_draw_book()
			match shop.state:
				"intro":
					_draw_intro()
				"done", "over":
					_draw_summary()
	if shop.paused:
		_draw_pause()
	if shop.fade > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size_now), Color(0.02, 0.01, 0.04, shop.fade))


func _box(r: Rect2, fill: Color, border := INK, width := 5, radius := 18, shadow := true) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = true
	if shadow:
		sb.shadow_color = Color(0, 0, 0, 0.35)
		sb.shadow_size = 4
		sb.shadow_offset = Vector2(0, 5)
	draw_style_box(sb, r)


func _text(s: String, at: Vector2, size: int, col := Color.WHITE, outline := 8, align := HORIZONTAL_ALIGNMENT_CENTER, f: Font = null, width := -1.0) -> void:
	var use: Font = font_bold if f == null else f
	var lines := s.split("\n")
	var line_h := size * 1.12
	var y := at.y - (lines.size() - 1) * line_h * 0.5
	for ln in lines:
		var w := width if width > 0.0 else use.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var x := at.x
		if align == HORIZONTAL_ALIGNMENT_CENTER:
			x -= w * 0.5
		elif align == HORIZONTAL_ALIGNMENT_RIGHT:
			x -= w
		var base := Vector2(x, y + size * 0.36)
		if outline > 0:
			draw_string_outline(use, base, ln, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, INK)
		draw_string(use, base, ln, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
		y += line_h


## Breaks `s` into lines no wider than `width`
func _wrap(s: String, size: int, width: float) -> String:
	var out := []
	for para in s.split("\n"):
		var line := ""
		for word in para.split(" "):
			var trial := word if line == "" else line + " " + word
			if font_bold.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width and line != "":
				out.append(line)
				line = word
			else:
				line = trial
		out.append(line)
	return "\n".join(out)


func _draw_top() -> void:
	var w := size_now.x
	if shop.mode == "free" and shop.state == "play":
		# The counter shut: nothing on the glass but the pause button
		_button_pause(buttons.pause.rect)
		return
	draw_rect(Rect2(0, 0, w, 70), Color(0.08, 0.04, 0.12, 0.55))
	_text("NIGHT %d" % shop.night, Vector2(18, 36), 34, GOLD, 9, HORIZONTAL_ALIGNMENT_LEFT)
	# Coins this night against what the night needs
	var q := Book.quota(shop.night)
	var bar := Rect2(w * 0.5 - 120, 20, 200, 30)
	if not tall:
		bar.position.x = w * 0.5 - 160
		bar.size.x = 260
	_box(bar, Color("3a2448"), INK, 4, 15, false)
	var fill := clampf(float(shop.night_coins) / q, 0.0, 1.0)
	if fill > 0.0:
		_box(Rect2(bar.position + Vector2(4, 4), Vector2((bar.size.x - 8) * fill, bar.size.y - 8)), GOLD if fill < 1.0 else GREEN, INK, 0, 11, false)
	Icons.coin(self, bar.position + Vector2(-4, 15), 22)
	_text("%d / %d" % [shop.night_coins, q], bar.get_center() + Vector2(8, 0), 24, Color.WHITE, 7)
	# The clock: what's left of the night
	var secs := int(ceil(maxf(shop.clock, 0.0)))
	var urgent := shop.state == "play" and shop.clock < 15.0
	var col := Color("ff8a7a") if urgent and int(_t * 4.0) % 2 == 0 else Color.WHITE
	var cx: float = bar.end.x + (buttons.pause.rect.position.x - bar.end.x) * 0.5
	draw_circle(Vector2(cx - 44, 35), 13, Color("fff2b0"))
	draw_circle(Vector2(cx - 38, 30), 11, Color(0.08, 0.04, 0.12, 1.0))
	_text("%d:%02d" % [secs / 60, secs % 60], Vector2(cx + 8, 36), 30, col, 8)
	_button_pause(buttons.pause.rect)


## The eyeball button, top right: up the periscope
func _draw_away() -> void:
	var r: Rect2 = buttons["go_scope"].rect
	_box(r, Color("6a5a9a"), INK, 4, 14)
	var c := r.get_center()
	# a plain cartoon eye: a white almond, a big black pupil glancing about
	var look := Vector2(sin(_t * 0.9) * 5.0, 0.0)
	var almond := PackedVector2Array()
	for k in 24:
		var a := TAU * k / 24.0
		almond.append(c + Vector2(cos(a) * 24.0, sin(a) * 13.0 * (1.0 - 0.25 * absf(cos(a)))))
	Icons.blob(self, almond, Color.WHITE, 4)
	draw_circle(c + look, 8, INK)


func _button_pause(r: Rect2) -> void:
	_box(r, WOOD_L, INK, 4, 14)
	for sgn: float in [-1.0, 1.0]:
		var bar := Rect2(r.get_center() + Vector2(sgn * 10 - 5, -14), Vector2(10, 28))
		draw_rect(bar.grow(3), INK)
		draw_rect(bar, PARCH)


func _draw_tickets() -> void:
	if shop.mode == "free" or shop.orders.is_empty():
		return
	# The string, sagging between two nails
	var x0 := 8.0
	var x1 := _tickets[2].end.x + 14.0
	var y0 := _tickets[0].position.y - 12.0
	var pts := PackedVector2Array()
	for k in 25:
		var u := k / 24.0
		pts.append(Vector2(lerpf(x0, x1, u), y0 + sin(u * PI) * 10.0))
	draw_polyline(pts, Color("2a1a10"), 4.0, true)
	draw_polyline(pts, Color("c8a878"), 2.0, true)
	for p: Vector2 in [pts[0], pts[24]]:
		draw_circle(p, 5, Color("3a3346"))
	for i in mini(_tickets.size(), shop.orders.size()):
		var r := _tickets[i]
		var o: Dictionary = shop.orders[i]
		var sel := i == shop.selected
		var frac: float = clampf(o.patience / o.full, 0.0, 1.0)
		# Hung from a peg at its top middle; it swings a little, more when it's new or she's cross
		var peg := Vector2(r.get_center().x, y0 + sin((r.get_center().x - x0) / (x1 - x0) * PI) * 10.0)
		var swing := sin(_t * 1.6 + i * 1.9) * 0.035
		if _bumps.has(i):
			swing += sin(_bumps[i] / 0.6 * PI * 3.0) * 0.12 * (1.0 - _bumps[i] / 0.6)
		if frac < 0.25:
			swing += sin(_t * 30.0) * 0.04
		var grow := 1.08 if sel else 1.0
		draw_set_transform(peg, swing, Vector2.ONE * grow)
		var w := r.size.x
		var h := r.size.y
		var top := 8.0
		# The note: rough-cut paper, a torn bottom edge
		var paper := PackedVector2Array([Vector2(-w * 0.5, top), Vector2(w * 0.5, top)])
		for k in 9:
			var u := 1.0 - k / 8.0
			paper.append(Vector2(lerpf(-w * 0.5, w * 0.5, u), top + h - (4.0 if k % 2 else 0.0) - 2.0 * sin(k * 2.7 + i)))
		var shadow := PackedVector2Array()
		for p in paper:
			shadow.append(p + Vector2(3, 5))
		draw_colored_polygon(shadow, Color(0, 0, 0, 0.3))
		draw_colored_polygon(paper, Color("f4e8c8") if sel else Color("e8dab4"))
		# She's getting impatient: the paper scorches up from the bottom
		var burn := (1.0 - frac) * h * 0.9
		if burn > 8.0:
			var scorch := PackedVector2Array()
			for k in 9:
				var u := k / 8.0
				scorch.append(Vector2(lerpf(-w * 0.5, w * 0.5, u), top + h - burn + 3.0 * sin(k * 2.1 + _t * 0.5)))
			for k in 9:
				var u := 1.0 - k / 8.0
				scorch.append(Vector2(lerpf(-w * 0.5, w * 0.5, u), top + h - (4.0 if k % 2 else 0.0)))
			draw_colored_polygon(scorch, Color(0.45, 0.24, 0.08, 0.35 + 0.35 * (1.0 - frac)))
		# The peg
		draw_rect(Rect2(-6, -6, 12, 22), Color("6b3e22") if not sel else Color("c8902a"))
		draw_rect(Rect2(-6, -6, 12, 22), INK, false, 2.0)
		# The potion's name, in a hurried hand
		var name: String = Book.POTIONS[o.potion].name
		var fs := 30 if tall else 32
		var lines := _wrap_with(note_font, name, fs, w - 14).split("\n")
		var ly := top + h * 0.5 - (lines.size() - 1) * fs * 0.42
		for ln in lines:
			var lw := note_font.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string(note_font, Vector2(-lw * 0.5, ly + fs * 0.32), ln, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("2a1a3a"))
			ly += fs * 0.84
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _wrap_with(f: Font, s: String, size: int, width: float) -> String:
	var out := []
	var line := ""
	for word in s.split(" "):
		var trial := word if line == "" else line + " " + word
		if f.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width and line != "":
			out.append(line)
			line = word
		else:
			line = trial
	out.append(line)
	return "\n".join(out)


func _check(c: Vector2, s: float) -> void:
	var pts := PackedVector2Array([c + Vector2(-0.8, 0) * s, c + Vector2(-0.2, 0.6) * s, c + Vector2(0.9, -0.6) * s])
	Icons.line(self, pts, s * 0.55)
	Icons.line(self, pts, s * 0.3, GREEN)


## What a customer's saying, the way Banjo-Kazooie did it: a rounded see-through dark box just over
## her head (no pointer), chunky white letters with a dark edge that pop up one at a time as she
## mumbles them, each bouncing in and bobbing gently after
func _draw_speech() -> void:
	var sp := shop.speech
	if sp.is_empty():
		return
	var full: String = String(sp.text).to_upper()
	var shown: float = sp.shown
	var fs := 28
	var f: Font = speech_font
	var max_w := minf(size_now.x * 0.8, 500.0)
	var lines := _wrap_with(f, full, fs, max_w - 36).split("\n")
	var bw := 0.0
	for ln in lines:
		bw = maxf(bw, f.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
	var line_h := fs * 1.18
	var bh := lines.size() * line_h + 26
	bw += 36
	var head := Hut.WINDOW_HEAD
	var who: Variant = sp.get("customer")
	if who != null and is_instance_valid(who):
		head = (who as Node3D).global_position + Vector3(0, 1.75, 0.15)
	var anchor := shop.screen_of(head + Vector3(0, 1.2, 0))
	var box := Rect2(Vector2(anchor.x - bw * 0.5, anchor.y - bh - 6), Vector2(bw, bh))
	var top_limit := (_tickets[0].end.y + 14.0) if not shop.orders.is_empty() and shop.mode == "shop" else 80.0
	if shop.state == "swamp":
		top_limit = 140.0
	box.position.x = clampf(box.position.x, 12, size_now.x - bw - 12)
	# Wide, it keeps up over her head and steps right of the notes instead
	if not tall:
		top_limit = 80.0
		if not shop.orders.is_empty() and shop.mode == "shop" and box.position.y < _tickets[0].end.y + 10.0:
			box.position.x = minf(maxf(box.position.x, _tickets[2].end.x + 16.0), size_now.x - bw - 160.0)
	box.position.y = clampf(box.position.y, top_limit, size_now.y - bh - 12)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.02, 0.07, 0.62)
	sb.set_corner_radius_all(int(minf(26.0, bh * 0.5)))
	sb.anti_aliasing = true
	draw_style_box(sb, box)
	# Letters one at a time, laid out where the whole line will end up
	var k := 0
	var y := box.position.y + 13 + fs * 0.5
	for ln in lines:
		var x := box.position.x + (bw - f.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x) * 0.5
		for i in ln.length():
			if float(k) >= shown:
				return
			var ch := ln[i]
			var cw := f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var age := shown - float(k)
			# Pops up as it's said, then bobs a little
			var pop := maxf(0.0, 1.0 - age / 4.0)
			var at := Vector2(x, y + fs * 0.36 - sin(pop * PI) * fs * 0.35 + sin(_t * 5.0 + k * 0.6) * 1.2)
			var size := fs if pop < 0.5 else fs * 2 - 14
			# A very soft shadow behind it, no outline
			for o: Vector2 in [Vector2(1, 2), Vector2(2, 3), Vector2(3, 4)]:
				draw_string(f, at + o, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0.0, 0.0, 0.0, 0.14))
			draw_string(f, at, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color("fff8e8"))
			x += cw
			k += 1
		k += 1
		y += line_h


func _draw_floaters() -> void:
	for f: Dictionary in shop.floaters:
		var k: float = f.t / 1.4
		var col: Color = f.col
		col.a = 1.0 - k * k
		var size := 52 if f.big else 32
		var ink := INK
		ink.a = col.a
		var at: Vector2 = f.pos + Vector2(0, -k * 90.0)
		var base := at + Vector2(-font_bold.get_string_size(f.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x * 0.5, size * 0.36)
		draw_string_outline(font_bold, base, f.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 10, ink)
		draw_string(font_bold, base, f.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _card(r: Rect2) -> void:
	draw_rect(Rect2(Vector2.ZERO, size_now), Color(0.05, 0.02, 0.08, 0.55))
	_box(r.grow(8), GOLD, INK, 5, 30)
	_box(r, PARCH, INK, 5, 24)


func _speaker(c: Vector2, on: bool) -> void:
	Icons.blob(self, PackedVector2Array([c + Vector2(-18, -8), c + Vector2(-8, -8), c + Vector2(4, -18), c + Vector2(4, 18), c + Vector2(-8, 8), c + Vector2(-18, 8)]), PARCH, 3)
	if on:
		draw_arc(c + Vector2(6, 0), 10, -0.8, 0.8, 8, PARCH, 4, true)
		draw_arc(c + Vector2(6, 0), 18, -0.8, 0.8, 8, PARCH, 4, true)
	else:
		Icons.line(self, PackedVector2Array([c + Vector2(10, -10), c + Vector2(26, 10)]), 5, RED)
		Icons.line(self, PackedVector2Array([c + Vector2(26, -10), c + Vector2(10, 10)]), 5, RED)


func _draw_intro() -> void:
	var w := size_now.x
	var r := Rect2(w * 0.5 - minf(300, w * 0.44), size_now.y * 0.34, minf(600, w * 0.88), 350)
	var drop := (1.0 - minf(1.0, shop.intro_t * 3.0)) * -400.0
	r.position.y += drop
	_card(r)
	_text("NIGHT %d" % shop.night, Vector2(r.get_center().x, r.position.y + 62), 68, GOLD, 14)
	_text("Earn %d coins before the moon sets" % Book.quota(shop.night), Vector2(r.get_center().x, r.position.y + 132), 28, INK, 0)
	if shop.news != "":
		_text(_wrap(shop.news, 26, r.size.x - 50), Vector2(r.get_center().x, r.position.y + 215), 26, Color("7a3aa8"), 0)
	var pulse := 1.0 + sin(_t * 5.0) * 0.05
	_text("Tap to open the shop!", Vector2(r.get_center().x, r.end.y - 34), int(28 * pulse), Color("3a8a2a"), 0)


func _draw_summary() -> void:
	var w := size_now.x
	var r := Rect2(w * 0.5 - minf(300, w * 0.44), size_now.y * 0.3, minf(600, w * 0.88), 400)
	_card(r)
	var won := shop.state == "done"
	_text("SHOP SHUT!" if won else "GAME OVER", Vector2(r.get_center().x, r.position.y + 60), 62, GREEN if won else RED, 14)
	var q := Book.quota(shop.night)
	_text("Night %d takings: %d / %d" % [shop.night, shop.night_coins, q], Vector2(r.get_center().x, r.position.y + 130), 30, INK, 0)
	_text("Potions sold: %d     Stormed off: %d" % [shop.served, shop.lost], Vector2(r.get_center().x, r.position.y + 180), 24, Color("6a4a3a"), 0)
	_text("Total coins: %d" % shop.score, Vector2(r.get_center().x, r.position.y + 240), 38, GOLD, 10)
	if not won:
		_text("Best: %d" % shop.best, Vector2(r.get_center().x, r.position.y + 295), 26, INK, 0)
	if shop.intro_t > 1.0:
		var pulse := 1.0 + sin(_t * 5.0) * 0.05
		_text("Tap for the next night!" if won else "Tap to try again", Vector2(r.get_center().x, r.end.y - 36), int(28 * pulse), Color("3a8a2a"), 0)


func _draw_pause() -> void:
	var w := size_now.x
	var r := Rect2(w * 0.5 - minf(260, w * 0.42), size_now.y * 0.26, minf(520, w * 0.84), 510)
	_card(r)
	_text("PAUSED", Vector2(r.get_center().x, r.position.y + 56), 56, GOLD, 12)
	var bw := r.size.x - 80
	var ids := ["resume", "sound", "dev"]
	var labels := ["Keep brewing", "Sound: %s" % ("off" if Sfx.me.muted else "on"), "Dev: potion look"]
	for i in 3:
		var br := Rect2(r.position.x + 40, r.position.y + 110 + i * 92, bw, 74)
		buttons[ids[i]] = {"rect": br}
		_box(br, [GREEN, Color("8ab8e8"), Color("c8a0f0"), Color("e8a090")][i], INK, 4, 20)
		_text(labels[i], br.get_center(), 32, Color.WHITE, 8)
	if shop.best > 0:
		_text("Best: %d coins" % shop.best, Vector2(r.get_center().x, r.end.y - 92), 26, INK, 0)
	_text("Keys: 1-8 ingredients, Space heat, A/D stir, Z zap, Enter bottle,\nO open/shut the shop, G the swamp, T the balcony, R book", Vector2(r.get_center().x, r.end.y - 40), 18, Color("6a4a3a"), 0)


func _draw_book() -> void:
	var w := size_now.x
	var h := size_now.y
	draw_rect(Rect2(Vector2.ZERO, size_now), Color(0.04, 0.02, 0.06, 0.65))
	var pages := _book_pages()
	book_page = clampi(book_page, 0, pages.size() - 1)
	buttons_book.clear()
	var spread := not tall
	var page_w := minf(w - 40, 640.0) if not spread else minf((w - 80) * 0.5, 620.0)
	var page_h := minf(h - 170, 1100.0)
	var top := 96.0
	if spread:
		var left := Rect2(w * 0.5 - page_w, top, page_w, page_h)
		var right := Rect2(w * 0.5, top, page_w, page_h)
		var first := book_page - book_page % 2
		_old_page(left, pages[first], first)
		if first + 1 < pages.size():
			_old_page(right, pages[first + 1], first + 1)
		else:
			_paper(right)
		draw_rect(Rect2(w * 0.5 - 6, top, 12, page_h), Color(0.2, 0.12, 0.06, 0.5))
	else:
		_old_page(Rect2(w * 0.5 - page_w * 0.5, top, page_w, page_h), pages[book_page], book_page)
	# Turning and closing
	var y := top + page_h + 14
	buttons_book["prev"] = Rect2(w * 0.5 - page_w * (1.0 if spread else 0.5), y, 150, 56)
	buttons_book["next"] = Rect2(w * 0.5 + page_w * (1.0 if spread else 0.5) - 150, y, 150, 56)
	buttons_book["close"] = Rect2(w * 0.5 - 75, y, 150, 56)
	for id: String in ["prev", "close", "next"]:
		var r: Rect2 = buttons_book[id]
		_box(r, Color("6b3e22"), INK, 4, 16)
		_text({"prev": "< Back", "close": "Close", "next": "Turn >"}[id], r.get_center(), 24, Color("f2e2b8"), 6, HORIZONTAL_ALIGNMENT_CENTER, book_font)


## What's in the book: the contents, the craft, the ingredients, a page for each potion she knows
## of tonight, and what she's found by brewing
func _book_pages() -> Array:
	var out: Array = [{"kind": "index"}, {"kind": "craft"}, {"kind": "ingredients"}]
	var pots := Book.potions_for(99 if shop.mode == "free" else shop.night)
	for p: int in pots:
		out.append({"kind": "potion", "potion": p})
	var found: Array = shop.discoveries.keys()
	for i in range(0, maxi(found.size(), 1), 4):
		out.append({"kind": "found", "from": i})
	return out


## The page a potion is on
func book_page_of(potion: int) -> int:
	var pages := _book_pages()
	for i in pages.size():
		if pages[i].kind == "potion" and pages[i].potion == potion:
			return i
	return 0


## A sheet of old paper: browned at the edges, a stain or two
func _paper(r: Rect2) -> void:
	_box(r.grow(4), Color("5a3418"), INK, 4, 10)
	draw_rect(r, Color("f0deb0"))
	for k in 6:
		var g := r.grow(-k * 6.0)
		draw_rect(g, Color(0.45, 0.28, 0.1, 0.05), false, 12.0)
	var seed := int(r.position.x) * 7 + int(r.position.y)
	for k in 3:
		var c := r.position + Vector2(fposmod(sin(seed + k * 3.1) * 999.0, r.size.x), fposmod(sin(seed + k * 7.7) * 777.0, r.size.y))
		draw_arc(c, 30 + k * 12, 0, TAU, 24, Color(0.5, 0.3, 0.1, 0.07), 6.0, true)


func _ink(s: String, at: Vector2, size: int, align := HORIZONTAL_ALIGNMENT_LEFT, title := false, col := Color("3a2414")) -> void:
	_text(s, at, size, col, 0, align, book_title_font if title else book_font)


func _wrap_book(s: String, size: int, width: float) -> String:
	var out := []
	for para in s.split("\n"):
		var line := ""
		for word in para.split(" "):
			var trial := word if line == "" else line + " " + word
			if book_font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width and line != "":
				out.append(line)
				line = word
			else:
				line = trial
		out.append(line)
	return "\n".join(out)


## A sepia picture from the album, or the drawn icon if it hasn't been taken yet
func _picture(name: String, c: Vector2, s: float, fallback := {}) -> void:
	var pic: Texture2D = shop.album.pics.get(name) if shop.album != null else null
	if pic != null:
		draw_texture_rect(pic, Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), false)
	elif not fallback.is_empty():
		Icons.step(self, fallback, c, s * 0.7)


func _step_picture(st: Dictionary, c: Vector2, s: float) -> void:
	match st.kind:
		Book.ADD:
			_picture(Hut.INGREDIENT_MODELS[st.what], c, s, st)
		Book.HEAT:
			_picture("bellows", c, s, st)
		Book.STIR:
			_picture("stick", c, s, st)
		Book.ZAP:
			_picture("wand", c, s, st)
		_:
			_picture("potion", c, s, st)


func _old_page(r: Rect2, page: Dictionary, number: int) -> void:
	_paper(r)
	var x := r.position.x + 34
	var wide := r.size.x - 68
	var y := r.position.y + 50
	match page.kind:
		"index":
			_ink("Grumblewart's", Vector2(r.get_center().x, y), 30, HORIZONTAL_ALIGNMENT_CENTER, true)
			_ink("Booke of Receipts", Vector2(r.get_center().x, y + 44), 40, HORIZONTAL_ALIGNMENT_CENTER, true)
			draw_line(Vector2(x + 40, y + 78), Vector2(x + wide - 40, y + 78), Color(0.23, 0.14, 0.08, 0.6), 2)
			y += 110
			var pages := _book_pages()
			var line_h := minf(46.0, (r.end.y - y - 40) / maxf(pages.size() - 1, 1))
			var size := int(clampf(line_h * 0.55, 18, 26))
			for i in range(1, pages.size()):
				var p: Dictionary = pages[i]
				var label := ""
				match p.kind:
					"craft":
						label = "Of the Craft"
					"ingredients":
						label = "Of the Ingredients"
					"potion":
						label = Book.POTIONS[p.potion].name
					"found":
						label = "Found by Brewing"
				if p.kind == "found" and p.from > 0:
					continue
				var row := Rect2(x, y - line_h * 0.5, wide, line_h)
				buttons_book["page%d" % i] = row
				var want: bool = not shop.selected_order().is_empty() and p.kind == "potion" and p.potion == shop.selected_order().potion
				if want:
					draw_rect(row, Color(0.9, 0.7, 0.3, 0.35))
				_ink(label, Vector2(x, y), size)
				_ink(str(i + 1), Vector2(x + wide, y), size, HORIZONTAL_ALIGNMENT_RIGHT)
				y += line_h
		"craft":
			_ink("Of the Craft", Vector2(r.get_center().x, y), 34, HORIZONTAL_ALIGNMENT_CENTER, true)
			_picture("cauldron", Vector2(r.get_center().x, y + 125), 230)
			var verse := "The first thing in is the root of it all;\nthe next may twist it, great or small.\n\nWarm, hot or roaring, the fire gives might;\nturn widdershins, and the wrong comes right.\n\nWhat's airy or ghostly must feel the wand,\nor off it flies to the world beyond.\n\nNo fire at all, and naught will take,\nsave what was born of the dragon's lake."
			_ink(_wrap_book(verse, 22, wide), Vector2(x, y + 230 + 22 * 12 * 0.5), 22)
		"ingredients":
			_ink("Of the Ingredients", Vector2(r.get_center().x, y), 34, HORIZONTAL_ALIGNMENT_CENTER, true)
			var cell := Vector2(wide * 0.5, (r.end.y - y - 50) / 4.0)
			for i in 8:
				var c := Vector2(x + cell.x * (i % 2) + cell.x * 0.28, y + 30 + cell.y * (i / 2) + cell.y * 0.5)
				_picture(Hut.INGREDIENT_MODELS[i], c, minf(cell.y * 0.9, 120.0))
				var nat: Dictionary = Lore.NATURE[i]
				_ink(Book.INGREDIENTS[i].name, c + Vector2(cell.x * 0.24, -14), 20)
				_ink("%s; for %s" % [nat.element, nat.virtue], c + Vector2(cell.x * 0.24, 14), 17, HORIZONTAL_ALIGNMENT_LEFT, false, Color("6a4a2a"))
		"potion":
			var pot: Dictionary = Book.POTIONS[page.potion]
			_ink(pot.name, Vector2(r.get_center().x, y), 34, HORIZONTAL_ALIGNMENT_CENTER, true)
			var steps := Book.steps_of(pot.recipe)
			_picture(Hut.INGREDIENT_MODELS[steps[0].what], Vector2(r.get_center().x, y + 118), 220)
			var about := _wrap_book(pot.about, 21, wide)
			var lines := about.split("\n").size()
			_ink(about, Vector2(x, y + 225 + lines * 21 * 1.12 * 0.5), 21)
			y += 245 + lines * 24
			_ink("Take:", Vector2(x, y), 24, HORIZONTAL_ALIGNMENT_LEFT, true)
			y += 44
			var row_h := minf(62.0, (r.end.y - y - 30) / steps.size())
			for st: Dictionary in steps:
				_step_picture(st, Vector2(x + row_h * 0.5, y), row_h * 0.95)
				_ink(Book.old_words(st), Vector2(x + row_h + 14, y), int(clampf(row_h * 0.38, 17, 23)))
				y += row_h
		"found":
			_ink("Found by Brewing", Vector2(r.get_center().x, y), 32, HORIZONTAL_ALIGNMENT_CENTER, true)
			y += 56
			var found: Array = shop.discoveries.keys()
			if found.is_empty():
				_ink(_wrap_book("Nothing yet. Brew freely, and send what you make up the tower to be tried: whatever it does will be written here.", 21, wide), Vector2(x, y + 60), 21)
			for k in range(page.from, mini(page.from + 4, found.size())):
				var d: Dictionary = shop.discoveries[found[k]]
				_ink(d.name, Vector2(x, y), 23, HORIZONTAL_ALIGNMENT_LEFT, true)
				var words := []
				for st: Dictionary in d.steps:
					words.append(Book.old_words(st))
				var txt := _wrap_book(", ".join(words) + ".", 18, wide)
				var n := txt.split("\n").size()
				_ink(txt, Vector2(x, y + 30 + (n - 1) * 18 * 0.56), 18, HORIZONTAL_ALIGNMENT_LEFT, false, Color("6a4a2a"))
				y += 60 + n * 21
	_ink(str(number + 1), Vector2(r.get_center().x, r.end.y - 22), 18, HORIZONTAL_ALIGNMENT_CENTER)

func _draw_tower() -> void:
	var w := size_now.x
	var h := size_now.y
	var res: Dictionary = shop.tower_result
	# The periscope's lens: everything but a round view through it in the dark, with its sight marks
	var c := Vector2(w * 0.5, h * 0.46)
	var rad := minf(w, h) * 0.46
	var thick := maxf(w, h) * 1.5
	draw_arc(c, rad + thick * 0.5, 0, TAU, 96, Color(0.03, 0.02, 0.05), thick, true)
	draw_arc(c, rad + 6, 0, TAU, 96, Color("c8902a"), 12, true)
	for k in 4:
		var d := Vector2(cos(k * PI * 0.5), sin(k * PI * 0.5))
		draw_line(c + d * (rad - 28), c + d * (rad - 6), Color(1, 1, 1, 0.5), 3)
	draw_line(c + Vector2(-14, 0), c + Vector2(14, 0), Color(1, 1, 1, 0.35), 2)
	draw_line(c + Vector2(0, -14), c + Vector2(0, 14), Color(1, 1, 1, 0.35), 2)
	_button_pause(buttons.pause.rect)
	var pulse0 := 1.0 + sin(_t * 5.0) * 0.04
	if res.is_empty() or not is_instance_valid(shop.tower.tester):
		_text("Tap to come down", Vector2(w * 0.5, h - 60), int(26 * pulse0), PARCH, 8)
		return
	var tester: Witch = shop.tower.tester
	if tester._effect == "":
		_text(shop.tower.tester_name() + " takes it outside...", Vector2(w * 0.5, 120), 30, PARCH, 9)
		return
	var r := Rect2(w * 0.5 - minf(320, w * 0.45), h - (420 if tall else 330), minf(640, w * 0.9), 300 if tall else 260)
	_box(r.grow(6), GOLD, INK, 5, 26)
	_box(r, PARCH, INK, 5, 22)
	var title := Lore.name_of(res)
	_text(title, Vector2(r.get_center().x, r.position.y + 44), 34, Color("7a3aa8"), 0)
	var about: String = Lore.DESCRIBE.get(res.effect, "")
	_text(_wrap(about, 24, r.size.x - 60), Vector2(r.get_center().x, r.position.y + 118), 24, INK, 0, HORIZONTAL_ALIGNMENT_CENTER, font)
	for i in 5:
		Icons.star(self, Vector2(r.get_center().x - 90 + i * 45, r.position.y + 184), 16, GOLD if i < res.potency else Color("c8b890"), 3.0)
	if shop.tower_new:
		_text("New! Written in your book.", Vector2(r.get_center().x, r.position.y + 226), 24, Color("3a8a2a"), 0)
	var pulse := 1.0 + sin(_t * 5.0) * 0.04
	_text("Tap to go back in", Vector2(r.get_center().x, r.end.y - 22), int(24 * pulse), Color("8a6a4a"), 0)


func _book_tap(at: Vector2) -> void:
	for id: String in buttons_book:
		if not (buttons_book[id] as Rect2).has_point(at):
			continue
		Sfx.play("tap", 0.8)
		if id == "close":
			shop.toggle_book()
		elif id == "prev":
			book_page = maxi(0, book_page - (1 if tall else 2))
		elif id == "next":
			book_page = mini(_book_pages().size() - 1, book_page + (1 if tall else 2))
		elif id.begins_with("page"):
			book_page = int(id.substr(4))
		return
	# A tap on the right of the page turns on; on the left, back
	if at.x > size_now.x * 0.5:
		book_page = mini(_book_pages().size() - 1, book_page + (1 if tall else 2))
	else:
		book_page = maxi(0, book_page - (1 if tall else 2))
	Sfx.play("tap", 0.7)


## A little count by each ingredient on the table (in the shop, where they run out)
func _draw_counts() -> void:
	if shop.mode != "shop" or shop.state != "play":
		return
	for i in 8:
		if i >= Book.ingredients_on(shop.night):
			continue
		var p := shop.spot_screen("jar%d" % i) + Vector2(22, -30)
		var n: int = shop.stock[i]
		draw_circle(p, 12, INK)
		draw_circle(p, 10, Color("f6e7c1") if n > 0 else Color("e8a090"))
		_text(str(n), p, 15, INK, 0)


## Gathering in the swamp: the time left, what's in the basket, and a way out
func _draw_swamp() -> void:
	var w := size_now.x
	var h := size_now.y
	draw_rect(Rect2(0, 0, w, 70), Color(0.08, 0.04, 0.12, 0.55))
	_text("THE SWAMP", Vector2(18, 36), 34, Color("a8e870"), 9, HORIZONTAL_ALIGNMENT_LEFT)
	_button_pause(buttons.pause.rect)
	# The basket: what's on hand
	var count := 8
	var bw := minf(w - 20, 760.0)
	var r := Rect2(w * 0.5 - bw * 0.5, h - 240, bw, 112)
	_box(r, PARCH, INK, 5, 20)
	var slot := bw / 8.0
	for i in 8:
		var c := Vector2(r.position.x + slot * (i + 0.5), r.position.y + 50)
		if i < count:
			Icons.ingredient(self, i, c, slot * 0.7)
			_text(str(shop.stock[i]), c + Vector2(0, 42), 22, INK, 0)
		else:
			Icons.padlock(self, c, slot * 0.5)
	var done := Rect2(w * 0.5 - 170, h - 112, 340, 82)
	buttons["leave_swamp"] = {"rect": done}
	_box(done, GREEN, INK, 5, 22)
	_text("Back inside", done.get_center(), 32, Color.WHITE, 8)


## The first moments, while it warms up: the title over a bubbling pot, like the page's own loading screen
func _draw_loading() -> void:
	var w := size_now.x
	var h := size_now.y
	draw_rect(Rect2(Vector2.ZERO, size_now), Color("170d24"))
	var c := Vector2(w * 0.5, h * 0.5)
	_text("Hubble Bubble", c + Vector2(0, -60), 72, Color("8fe36b"), 14)
	for k in 5:
		var t := fmod(_t * 0.8 + k * 0.2, 1.0)
		var p := c + Vector2((k - 2) * 26 + sin(_t * 3.0 + k) * 6.0, 60 - t * 50)
		draw_circle(p, 9 * (1.0 - t * 0.5), Color(0.55, 1.0, 0.45, 1.0 - t))
	_text("stirring the cauldron...", c + Vector2(0, 100), 24, Color("d8c8f0"), 6)


## The floating book: the page it was left open at, and the next, side by side
func _draw_open_book() -> void:
	size_now = get_viewport_rect().size
	var pages := _book_pages()
	var left := clampi(page_shown, 0, pages.size() - 1)
	var w := size_now.x * 0.5
	# A recipe, seen from the cauldron: just its steps, as big pictures across both pages (the ingredients,
	# the bellows for the fire, the stick, the wand), its name small over them
	if pages[left].kind == "potion":
		var pot: Dictionary = Book.POTIONS[pages[left].potion]
		var lr := Rect2(6, 6, w - 9, size_now.y - 12)
		var rr := Rect2(w + 3, 6, w - 9, size_now.y - 12)
		_paper(lr)
		_paper(rr)
		var steps := Book.steps_of(pot.recipe).filter(func(st: Dictionary) -> bool: return st.kind != Book.BOTTLE)
		_ink(pot.name, Vector2(size_now.x * 0.5, 40), 34, HORIZONTAL_ALIGNMENT_CENTER, true)
		var per := ceili(steps.size() / 2.0)
		for i in steps.size():
			var page_r := lr if i < per else rr
			var k := i if i < per else i - per
			var n := per if i < per else steps.size() - per
			var cell := (page_r.size.y - 90) / maxf(n, 1)
			var sz := minf(cell * 1.3, page_r.size.x * 1.05)
			_step_picture(steps[i], Vector2(page_r.get_center().x, page_r.position.y + 80 + cell * (k + 0.5)), sz)
		return
	_old_page(Rect2(6, 6, w - 9, size_now.y - 12), pages[left], left)
	if left + 1 < pages.size():
		_old_page(Rect2(w + 3, 6, w - 9, size_now.y - 12), pages[left + 1], left + 1)
	else:
		_paper(Rect2(w + 3, 6, w - 9, size_now.y - 12))
