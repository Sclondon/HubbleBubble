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
var buttons := {}
var size_now := Vector2.ZERO
var tall := true
var squeeze := 0.0

var font: FontVariation
var font_bold: FontVariation
var book_font: Font
var book_title_font: Font
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
	font_bold.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 650}
	layout()


func bump(i: int) -> void:
	_bumps[i] = 0.0


func tick_step(i: int) -> void:
	_ticks[i] = 0.0


func shake(id: String) -> void:
	_shakes[id] = 0.0


func _process(dt: float) -> void:
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
	if tall:
		var tw := (w - 40) / 3.0
		for i in 3:
			_tickets.append(Rect2(10 + i * (tw + 10), 80, tw, 150))
		_strip = Rect2(10, h - 132, w - 20, 118)
		_gauge = Rect2(w - 40, 290, 28, h * 0.26)
	else:
		for i in 3:
			_tickets.append(Rect2(12, 84 + i * 160, 320, 150))
		_strip = Rect2(12, h - 142, minf(w * 0.3, 760.0), 128)
		_gauge = Rect2(w - 64, 220, 44, h * 0.42)
	for i in _tickets.size():
		buttons["ticket%d" % i] = {"rect": _tickets[i]}


# --- touches ---

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		if e.pressed:
			_press(e.index, e.position)
		else:
			if _touches.get(e.index, {}).get("id", "") == "hold":
				shop.release()
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
			var cs := shop.cauldron_screen()
			var c: Vector2 = cs[0]
			var a0: float = (t.last - c).angle()
			var a1: float = (e.position - c).angle()
			if (e.position - c).length() > 12.0 and (t.last - c).length() > 12.0:
				shop.stir(wrapf(a1 - a0, -PI, PI))
			t.last = e.position
		get_viewport().set_input_as_handled()


func _press(index: int, at: Vector2) -> void:
	match shop.state:
		"title":
			if _hit("sound", at):
				shop.set_sound(Sfx.me.muted)
			elif _hit("go_shop", at):
				Sfx.play("tap")
				shop.start_game()
			elif _hit("go_free", at):
				Sfx.play("tap")
				shop.start_free()
			return
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
		elif _hit("n64", at):
			shop.set_n64(not shop.n64)
		elif _hit("quit", at):
			shop.quit_to_title()
		return
	if shop.book_open:
		_book_tap(at)
		return
	for id: String in buttons:
		if id in ["resume", "sound", "n64", "quit"] or not _hit(id, at):
			continue
		_touches[index] = {"id": id, "last": at}
		if id.begins_with("ticket"):
			shop.select(int(id.substr(6)))
		elif id == "pause":
			shop.toggle_pause()
		return
	var thing := shop.pick(at)
	if thing == "" or thing == "stir":
		# The pot, or anywhere else in the middle: stirring (or, held still, tipping it out)
		_touches[index] = {"id": "stir", "last": at, "from": at, "still": 0.0}
		return
	_touches[index] = {"id": thing, "last": at}
	if thing.begins_with("jar"):
		_touches[index].id = "hold"
		shop.grab(int(thing.substr(3)), at)
		return
	shop.tap(thing)
	if thing == "bellows":
		_held_pump[index] = HOLD_PUMP * 1.6


func _hit(id: String, at: Vector2) -> bool:
	return buttons.has(id) and (buttons[id].rect as Rect2).has_point(at)


# --- drawing ---

func _draw() -> void:
	match shop.state:
		"title":
			_draw_speech()
			_draw_title()
			return
		"tower":
			_draw_tower()
			if shop.paused:
				_draw_pause()
			return
		"swamp":
			_draw_swamp()
			_draw_speech()
			_draw_floaters()
			if shop.paused:
				_draw_pause()
			return
	_draw_top()
	_draw_tickets()
	_draw_stir_ring()
	_draw_counts()
	_draw_gauge()
	_draw_strip()
	_draw_speech()
	_draw_floaters()
	_draw_hint()
	if shop.book_open:
		_draw_book()
	match shop.state:
		"intro":
			_draw_intro()
		"done", "over":
			_draw_summary()
	if shop.paused:
		_draw_pause()


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
	draw_rect(Rect2(0, 0, w, 70), Color(0.08, 0.04, 0.12, 0.55))
	if shop.mode == "free":
		_text("BREWING FREELY", Vector2(18, 36), 34, Color("c8a0f0"), 9, HORIZONTAL_ALIGNMENT_LEFT)
		_text("%d found" % shop.discoveries.size(), Vector2(w - 100, 36), 26, Color.WHITE, 7, HORIZONTAL_ALIGNMENT_RIGHT)
		_button_pause(buttons.pause.rect)
		return
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


func _button_pause(r: Rect2) -> void:
	_box(r, WOOD_L, INK, 4, 14)
	for sgn: float in [-1.0, 1.0]:
		var bar := Rect2(r.get_center() + Vector2(sgn * 10 - 5, -14), Vector2(10, 28))
		draw_rect(bar.grow(3), INK)
		draw_rect(bar, PARCH)


func _draw_tickets() -> void:
	for i in _tickets.size():
		var r := _tickets[i]
		if i >= shop.orders.size():
			_box(r, Color(0.1, 0.05, 0.15, 0.25), Color(1, 1, 1, 0.12), 3, 16, false)
			continue
		var o: Dictionary = shop.orders[i]
		var sel := i == shop.selected
		var lift := -8.0 if sel else 0.0
		if _bumps.has(i):
			lift -= sin(_bumps[i] / 0.6 * PI) * 16.0
		r.position.y += lift
		var frac: float = clampf(o.patience / o.full, 0.0, 1.0)
		var shake_x := sin(_t * 40.0) * 3.0 if frac < 0.25 else 0.0
		r.position.x += shake_x
		if sel:
			_box(r.grow(6), GOLD, INK, 4, 22)
		_box(r, PARCH, INK, 4, 16)
		var face_r := 25.0
		Icons.face(self, o.who, r.position + Vector2(36, 38), face_r)
		Icons.bottle(self, r.position + Vector2(r.size.x - 38, 52), 62, o.colour)
		var name: String = Book.POTIONS[o.potion].name
		var fs := 22 if tall else 24
		var wrapped := _wrap(name, fs, r.size.x - 24)
		_text(wrapped, Vector2(r.get_center().x, r.position.y + 98), fs, INK, 0, HORIZONTAL_ALIGNMENT_CENTER)
		if not tall:
			_text(o.who.name, Vector2(r.position.x + 70, r.position.y + 38), 22, Color("6a4a3a"), 0, HORIZONTAL_ALIGNMENT_LEFT)
		# Patience: green to red, and the customer getting cross
		var bar := Rect2(r.position + Vector2(14, r.size.y - 26), Vector2(r.size.x - 28, 14))
		draw_rect(bar.grow(3), INK)
		draw_rect(bar, Color("4a3040"))
		var pc := GREEN.lerp(Color("ffd84a"), clampf((0.7 - frac) * 2.5, 0.0, 1.0)).lerp(RED, clampf((0.35 - frac) * 4.0, 0.0, 1.0))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * frac, bar.size.y)), pc)
		if shop.learned.has(o.potion) and shop.night >= 4:
			Icons.book(self, r.position + Vector2(r.size.x - 22, 18), 26)


func _draw_stir_ring() -> void:
	if shop.state != "play":
		return
	var cs := shop.cauldron_screen()
	var c: Vector2 = cs[0]
	var r: float = cs[1] * 1.12
	# How far round this turn of the stick is (a turn counts when it comes all the way round)
	if shop.stir_fill > 0.02 and shop.hut.stirring:
		var dir: int = shop._stir_dir
		var col := Color(0.55, 0.85, 1.0, 0.8) if dir > 0 else Color(1.0, 0.62, 0.82, 0.8)
		var a0 := -PI * 0.5
		draw_arc(c, r, a0, a0 + TAU * shop.stir_fill * dir, 40, col, 9, true)
	# Held still on the brew: tipping it out
	for t: Dictionary in _touches.values():
		if t.get("id", "") == "stir" and t.get("still", 0.0) > 0.25 and not shop.brew.is_empty():
			var k: float = clampf((t.still - 0.25) / (TIP_HOLD - 0.25), 0.0, 1.0)
			draw_arc(t.last, 60, -PI * 0.5, -PI * 0.5 + TAU * k, 32, Color("ff9a6a"), 10, true)
			_text("Tip it out", t.last + Vector2(0, -84), 24, Color("ffd0a0"), 7)


func _draw_gauge() -> void:
	var g := _gauge
	_box(g.grow(6), WOOD, INK, 4, 16)
	var bands := Book.HEAT_BANDS
	for b in 4:
		var y0: float = g.end.y - g.size.y * bands[b] / 100.0
		var y1: float = g.end.y - g.size.y * minf(bands[b + 1], 100.0) / 100.0
		draw_rect(Rect2(g.position.x, y1, g.size.x, y0 - y1), Book.HEAT_COLOURS[b])
	var top_y: float = g.end.y - g.size.y * bands[4] / 100.0
	draw_rect(Rect2(g.position.x, g.position.y, g.size.x, top_y - g.position.y), Color("ff2a6a") if int(_t * 6.0) % 2 == 0 and shop.heat > Book.HEAT_BANDS[4] else Color("8a1a3a"))
	draw_rect(g, INK, false, 3)
	var y := g.end.y - g.size.y * clampf(shop.heat, 0.0, 100.0) / 100.0
	Icons.blob(self, PackedVector2Array([Vector2(g.position.x - 8, y - 10), Vector2(g.end.x + 8, y - 10), Vector2(g.end.x + 8, y + 10), Vector2(g.position.x - 8, y + 10)]), Color.WHITE, 4)
	# Filling while a heat is held long enough to count
	if shop.heat_fill > 0.0:
		draw_arc(Vector2(g.get_center().x, y), 26, -PI * 0.5, -PI * 0.5 + TAU * shop.heat_fill, 24, Color("ffe060"), 6, true)
	var band := Book.band_of(shop.heat)
	if shop.heat >= Book.HEAT_BANDS[4]:
		_text("TOO\nHOT!", Vector2(g.get_center().x - 8, g.position.y - 40), 22, Color("ff8a9a"), 7)
	else:
		_text(Book.HEAT_NAMES[band], Vector2(g.get_center().x - 14, g.position.y - 24), 20, Book.HEAT_COLOURS[band], 7)


## The page at the foot of the screen: what she asked for (just the name: the book has the rest),
## and what has gone into the pot so far, in order
func _draw_strip() -> void:
	var o := shop.selected_order()
	var r := _strip
	_box(r, PARCH, INK, 5, 20)
	var title := ""
	if shop.mode == "free":
		title = "Brew what you like; bottle it for the tower"
	elif not o.is_empty():
		title = "\"%s\"" % Book.POTIONS[o.potion].name
	elif shop.state == "play":
		title = "Waiting for customers..."
	_text(title, Vector2(r.position.x + 18, r.position.y + 4), 24, GOLD, 7, HORIZONTAL_ALIGNMENT_LEFT)
	var steps: Array = shop.brew
	var cy := r.position.y + r.size.y * 0.58
	if steps.is_empty():
		_text("The pot holds only water.", Vector2(r.get_center().x, cy), 24, Color("8a6a4a"), 0, HORIZONTAL_ALIGNMENT_CENTER, font)
		return
	var slot := minf(84.0, (r.size.x - 30) / maxf(steps.size(), 1))
	var x0 := r.position.x + 18
	for i in steps.size():
		var c := Vector2(x0 + slot * (i + 0.5), cy)
		var st: Dictionary = steps[i]
		var pop := 1.0
		if _ticks.has(i):
			pop = 1.0 + sin(_ticks[i] / 0.6 * PI) * 0.35
		draw_circle(c, slot * 0.44, PARCH_D)
		Icons.step(self, st, c, slot * 0.74 * pop)
		if st.kind == Book.STIR:
			_text("x%d" % st.turns, c + Vector2(slot * 0.3, slot * 0.3), int(slot * 0.3), Color.WHITE, 6)
		elif st.kind == Book.HEAT:
			_text(Book.HEAT_NAMES[st.level], c + Vector2(0, slot * 0.42), int(slot * 0.2), Book.HEAT_COLOURS[st.level], 5)
	if shop.spoil_t > 0.0:
		_box(r.grow(-6), Color(0.3, 0.22, 0.12, 0.85), INK, 0, 16, false)
		_text("Spoilt! Tipping it out...", r.get_center(), 30, Color("ffcf9a"), 8)


func _check(c: Vector2, s: float) -> void:
	var pts := PackedVector2Array([c + Vector2(-0.8, 0) * s, c + Vector2(-0.2, 0.6) * s, c + Vector2(0.9, -0.6) * s])
	Icons.line(self, pts, s * 0.55)
	Icons.line(self, pts, s * 0.3, GREEN)


func _draw_speech() -> void:
	var sp := shop.speech
	if sp.is_empty():
		return
	var text: String = sp.text.substr(0, int(sp.shown))
	var full: String = sp.text
	var fs := 26 if tall else 28
	var max_w := minf(size_now.x * 0.86, 560.0)
	var wrapped := _wrap(full, fs, max_w - 40)
	var lines := wrapped.split("\n")
	var bw := 0.0
	for ln in lines:
		bw = maxf(bw, font_bold.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
	var bh := lines.size() * fs * 1.12 + 28
	bw += 40
	var anchor: Vector2
	if sp.who == "witch":
		anchor = shop.screen_of(Vector3(0, Hut.CAULDRON_RIM + 0.5, 0.6))
	else:
		anchor = shop.screen_of(Hut.WINDOW_HEAD + Vector3(0, 0.9, 0))
	var top_limit := 270.0 if tall else 84.0
	var low_limit := size_now.y * 0.62
	var box := Rect2(anchor + Vector2(-bw * 0.5, -bh - 40), Vector2(bw, bh))
	if shop.state == "title":
		box.position.y = anchor.y - bh - 30
		top_limit = size_now.y * 0.36
	elif shop.state == "swamp":
		box.position.y = 140.0
		top_limit = 0.0
		low_limit = size_now.y
	elif sp.who == "witch" and tall:
		# Your own words, down by the recipe, clear of the brew
		box.position.y = _strip.position.y - bh - 18
		top_limit = 0.0
		low_limit = size_now.y
	box.position.x = clampf(box.position.x, 12, size_now.x - bw - 12)
	box.position.y = clampf(box.position.y, top_limit, low_limit - bh)
	var tail_to := Vector2(clampf(anchor.x, box.position.x + 30, box.end.x - 30), box.end.y + 30)
	var tail_from := Vector2(clampf(anchor.x, box.position.x + 40, box.end.x - 60), box.end.y - 4)
	var tail := PackedVector2Array([tail_from, tail_from + Vector2(34, 0), tail_to])
	var fill := Color("fffaf0") if sp.who == "witch" else Color("e8f4ff")
	Icons.blob(self, tail, fill, 5)
	_box(box, fill, INK, 5, 24)
	draw_colored_polygon(PackedVector2Array([tail_from + Vector2(4, -6), tail_from + Vector2(30, -6), tail_from + Vector2(17, 6)]), fill)
	# Typed out a letter at a time, laid out where the whole text will end up
	var shown_lines := _wrap(full, fs, max_w - 40).split("\n")
	var left := text.length()
	var y := box.position.y + 14 + fs * 0.5
	for ln in shown_lines:
		var part := ln.substr(0, maxi(0, left))
		left -= ln.length() + 1
		_text(part, Vector2(box.position.x + 20, y), fs, Color("3a1a4a") if sp.who == "witch" else Color("1a2a4a"), 0, HORIZONTAL_ALIGNMENT_LEFT)
		y += fs * 1.12
	if sp.who == "witch":
		_text("You (Grumblewart)", Vector2(box.position.x + 18, box.position.y - 2), 20, Color("a8e870"), 6, HORIZONTAL_ALIGNMENT_LEFT)


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


## A pointing hand at the book while a customer wants something not made yet
func _draw_hint() -> void:
	if shop.state != "play" or shop.paused or shop.book_open or shop.mode != "shop":
		return
	var o := shop.selected_order()
	if o.is_empty() or shop.learned.has(o.potion) or o.get("looked", false):
		return
	var bob := absf(sin(_t * 6.0)) * 14.0
	_hand(shop.spot_screen("book") + Vector2(10, 18 + bob))


func _hand(tip: Vector2) -> void:
	var s := 1.0
	var palm := tip + Vector2(14, 46) * s
	Icons.blob(self, Icons.oval(palm, Vector2(26, 24) * s), Color("fff0d8"), 5)
	Icons.blob(self, Icons.oval(tip + Vector2(0, 16) * s, Vector2(10, 24) * s), Color("fff0d8"), 5)
	Icons.blob(self, Icons.oval(palm, Vector2(22, 20) * s), Color("fff0d8"))


func _card(r: Rect2) -> void:
	draw_rect(Rect2(Vector2.ZERO, size_now), Color(0.05, 0.02, 0.08, 0.55))
	_box(r.grow(8), GOLD, INK, 5, 30)
	_box(r, PARCH, INK, 5, 24)


func _draw_title() -> void:
	var w := size_now.x
	var h := size_now.y
	var cy := h * 0.17 if tall else h * 0.2
	# Bouncy letters, one at a time
	var title := "HUBBLE BUBBLE"
	var fs := 92 if tall else 120
	var total := font_bold.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if total > w - 40:
		fs = int(fs * (w - 40) / total)
		total = font_bold.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var x := w * 0.5 - total * 0.5
	var colours := [Color("8fe36b"), Color("f2c840"), Color("c890ff"), Color("ff8a5a")]
	for i in title.length():
		var ch := title[i]
		var cw := font_bold.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var y := cy + sin(_t * 4.0 + i * 0.6) * 10.0
		draw_string_outline(font_bold, Vector2(x, y + 8), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 22, INK)
		draw_string(font_bold, Vector2(x, y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, colours[i % colours.size()])
		x += cw
	_text("Granny Grumblewart's Potion Shop", Vector2(w * 0.5, cy + fs * 0.55), 32 if tall else 38, PARCH, 9)
	var pulse := 1.0 + sin(_t * 5.0) * 0.05
	var bw := minf(w - 80, 520.0)
	var by := h - (330 if tall else 300)
	for i in 2:
		var id: String = ["go_shop", "go_free"][i]
		var br := Rect2(w * 0.5 - bw * 0.5, by + i * 110, bw, 92)
		buttons[id] = {"rect": br}
		_box(br.grow(4 if i == 0 else 0), [GREEN, Color("b890f0")][i], INK, 5, 24)
		_text(["Open the Shop", "Brew Freely in the Tower"][i], br.get_center() + Vector2(0, -8), int((36 if i == 0 else 30) * (pulse if i == 0 else 1.0)), Color.WHITE, 9)
		_text(["Customers, orders, a coin to earn each night", "Make anything, and watch a witch drink it"][i], br.get_center() + Vector2(0, 28), 18, Color(1, 1, 1, 0.85), 5)
	if shop.best > 0:
		_text("Best: %d coins" % shop.best, Vector2(w * 0.5, by - 40), 28, Color.WHITE, 8)
	var r := Rect2(w - 84, 14, 70, 60)
	buttons["sound"] = {"rect": r}
	_box(r, WOOD_L, INK, 4, 14)
	_speaker(r.get_center(), not Sfx.me.muted)


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
	var r := Rect2(w * 0.5 - minf(260, w * 0.42), size_now.y * 0.26, minf(520, w * 0.84), 560)
	_card(r)
	_text("PAUSED", Vector2(r.get_center().x, r.position.y + 56), 56, GOLD, 12)
	var bw := r.size.x - 80
	var ids := ["resume", "sound", "n64", "quit"]
	var labels := ["Keep brewing", "Sound: %s" % ("off" if Sfx.me.muted else "on"), "N64 filter: %s" % ("on" if shop.n64 else "off"), "Back to the title"]
	for i in 4:
		var br := Rect2(r.position.x + 40, r.position.y + 110 + i * 92, bw, 74)
		buttons[ids[i]] = {"rect": br}
		_box(br, [GREEN, Color("8ab8e8"), Color("c8a0f0"), Color("e8a090")][i], INK, 4, 20)
		_text(labels[i], br.get_center(), 32, Color.WHITE, 8)
	_text("Keys: 1-8 ingredients, Space heat, A/D or arrows stir,\nZ zap, Enter bottle, Tab next order, R book", Vector2(r.get_center().x, r.end.y - 40), 18, Color("6a4a3a"), 0)


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
	_button_pause(buttons.pause.rect)
	_text(shop.tower.tester_name() + " tries it...", Vector2(w * 0.5, 120), 30, PARCH, 9)
	if shop.tower_t < 1.4:
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
	_text("Tap to brew another", Vector2(r.get_center().x, r.end.y - 22), int(24 * pulse), Color("8a6a4a"), 0)


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
		var p := shop.spot_screen("jar%d" % i) + Vector2(30, 26)
		var n: int = shop.stock[i]
		draw_circle(p, 17, INK)
		draw_circle(p, 14, Color("f6e7c1") if n > 0 else Color("e8a090"))
		_text(str(n), p, 20, INK, 0)


## Gathering in the swamp: the time left, what's in the basket, and a way out
func _draw_swamp() -> void:
	var w := size_now.x
	var h := size_now.y
	draw_rect(Rect2(0, 0, w, 70), Color(0.08, 0.04, 0.12, 0.55))
	_text("THE SWAMP", Vector2(18, 36), 34, Color("a8e870"), 9, HORIZONTAL_ALIGNMENT_LEFT)
	_text("%d" % int(ceil(maxf(shop.swamp_t, 0.0))), Vector2(w * 0.5, 36), 34, Color.WHITE, 9)
	_button_pause(buttons.pause.rect)
	_text("Tap things to gather them for night %d" % (shop.night + 1), Vector2(w * 0.5, 104), 26, PARCH, 8)
	# The basket: what's on hand for the night
	var count := Book.ingredients_on(shop.night + 1)
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
	_text("Open the shop!", done.get_center(), 32, Color.WHITE, 8)
