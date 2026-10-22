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

var shop: Shop
var buttons := {}
var size_now := Vector2.ZERO
var tall := true
var squeeze := 0.0

var font: FontVariation
var font_bold: FontVariation
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
				return
			Sfx.play("tap")
			shop.start_game()
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
		shop.toggle_book()
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
		# The pot, or anywhere else in the middle: stirring
		_touches[index] = {"id": "stir", "last": at}
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
	_draw_top()
	_draw_tickets()
	_draw_stir_ring()
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
	var want := shop.current_step()
	if want.get("kind", -1) != Book.STIR:
		return
	var cs := shop.cauldron_screen()
	var c: Vector2 = cs[0]
	var r: float = cs[1] * 1.15
	var dir: int = want.dir
	var col := Color(0.55, 0.85, 1.0, 0.75) if dir > 0 else Color(1.0, 0.62, 0.82, 0.75)
	# Dashes going round the way to stir
	for i in 12:
		var a := TAU * i / 12.0 + _t * 2.5 * dir
		var a2 := a + 0.3
		draw_arc(c, r, a, a2, 6, col, 7, true)
	var tip_a := _t * 2.5 * dir + PI * 0.5
	var tip := c + Vector2.from_angle(tip_a) * r
	var along := Vector2.from_angle(tip_a + PI * 0.5 * dir)
	Icons.blob(self, PackedVector2Array([tip + along * 22, tip + along.orthogonal() * 14, tip - along.orthogonal() * 14]), Color(col, 1.0), 4)
	var turns: int = want.turns
	var done := int(floor(shop.step_fill * turns + 0.0001))
	_text("%s  %d / %d" % ["STIR RIGHT" if dir > 0 else "STIR LEFT", mini(done, turns), turns], c + Vector2(0, -r * 0.62 - 40), 28, Color(col, 1.0).lightened(0.4), 8)


func _draw_gauge() -> void:
	var g := _gauge
	_box(g.grow(6), WOOD, INK, 4, 16)
	var bands := Book.HEAT_BANDS
	var want := shop.current_step()
	var want_level: int = want.level if want.get("kind", -1) == Book.HEAT else -1
	for b in 4:
		var y0: float = g.end.y - g.size.y * bands[b] / 100.0
		var y1: float = g.end.y - g.size.y * minf(bands[b + 1], 100.0) / 100.0
		var col: Color = Book.HEAT_COLOURS[b]
		if want_level >= 0 and b != want_level:
			col = col.darkened(0.45)
		draw_rect(Rect2(g.position.x, y1, g.size.x, y0 - y1), col)
		if b == want_level:
			var pulse := 0.5 + 0.5 * sin(_t * 8.0)
			draw_rect(Rect2(g.position.x - 4, y1, g.size.x + 8, y0 - y1), Color(1, 1, 1, 0.25 + pulse * 0.35), false, 4)
			# Little arrows pointing at the band wanted
			var mid := (y0 + y1) * 0.5
			var ax := g.position.x - 12
			Icons.blob(self, PackedVector2Array([Vector2(ax, mid), Vector2(ax - 18, mid - 12), Vector2(ax - 18, mid + 12)]), Color.WHITE, 3)
	# Over the top: boiling over
	var top_y: float = g.end.y - g.size.y * bands[4] / 100.0
	draw_rect(Rect2(g.position.x, g.position.y, g.size.x, top_y - g.position.y), Color("ff2a6a") if int(_t * 6.0) % 2 == 0 and shop.heat > Book.HEAT_BANDS[4] else Color("8a1a3a"))
	draw_rect(g, INK, false, 3)
	var y := g.end.y - g.size.y * clampf(shop.heat, 0.0, 100.0) / 100.0
	Icons.blob(self, PackedVector2Array([Vector2(g.position.x - 8, y - 10), Vector2(g.end.x + 8, y - 10), Vector2(g.end.x + 8, y + 10), Vector2(g.position.x - 8, y + 10)]), Color.WHITE, 4)
	var band := Book.band_of(shop.heat)
	if shop.heat >= Book.HEAT_BANDS[4]:
		_text("TOO\nHOT!", Vector2(g.get_center().x, g.position.y - 40), 22, Color("ff8a9a"), 7)
	else:
		_text(Book.HEAT_NAMES[band], Vector2(g.get_center().x - (10 if tall else 0), g.position.y - 26), 20, Book.HEAT_COLOURS[band], 7)


func _draw_strip() -> void:
	var o := shop.selected_order()
	var r := _strip
	_box(r, PARCH, INK, 5, 20)
	if o.is_empty():
		_text("Waiting for customers..." if shop.state == "play" else "", r.get_center(), 28, Color("8a6a4a"), 0)
		return
	var steps: Array = o.steps
	var hidden := shop.recipe_hidden()
	var name: String = Book.POTIONS[o.potion].name
	_text(name, Vector2(r.position.x + 18, r.position.y + 2), 22, GOLD, 7, HORIZONTAL_ALIGNMENT_LEFT)
	var n := steps.size()
	var slot := minf(96.0, (r.size.x - 30) / n)
	var x0 := r.get_center().x - slot * n * 0.5
	var cy := r.position.y + r.size.y * 0.56
	var icon := slot * 0.78
	for i in n:
		var c := Vector2(x0 + slot * (i + 0.5), cy)
		var st: Dictionary = steps[i]
		var done := i < shop.progress
		var now := i == shop.progress and shop.spoil_t <= 0.0
		if now:
			var pulse := 1.0 + sin(_t * 7.0) * 0.06
			draw_circle(c, slot * 0.47 * pulse, GOLD)
			draw_arc(c, slot * 0.47 * pulse, 0, TAU, 32, INK, 4, true)
			if shop.step_fill > 0.0:
				draw_arc(c, slot * 0.47 * pulse - 6, -PI * 0.5, -PI * 0.5 + TAU * shop.step_fill, 32, Color("3aa04a"), 8, true)
		else:
			draw_circle(c, slot * 0.42, PARCH_D if not done else Color("c8e8b0"))
		if hidden and not done and not now and st.kind != Book.BOTTLE:
			_text("?", c, int(icon * 0.7), Color("8a6a4a"), 0)
		elif hidden and now and st.kind != Book.BOTTLE:
			_text("?", c, int(icon * 0.7), INK, 0)
		else:
			var pop := 1.0
			if _ticks.has(i):
				pop = 1.0 + sin(_ticks[i] / 0.6 * PI) * 0.35
			Icons.step(self, st, c, icon * pop * (0.85 if done else 1.0))
			if st.kind == Book.STIR:
				_text("x%d" % st.turns, c + Vector2(slot * 0.3, slot * 0.3), int(slot * 0.28), Color.WHITE, 6)
			elif st.kind == Book.HEAT:
				_text(Book.HEAT_NAMES[st.level], c + Vector2(0, slot * 0.42), int(slot * 0.19), Book.HEAT_COLOURS[st.level], 5)
		if done:
			_check(c + Vector2(slot * 0.25, -slot * 0.22), slot * 0.22)
		if i < n - 1:
			var a := c + Vector2(slot * 0.47, 0)
			draw_circle(a, 4, Color("8a6a4a"))
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


## A pointing hand over what to press next, until she's done each kind of step a few times
func _draw_hint() -> void:
	if shop.state != "play" or shop.spoil_t > 0.0 or shop.paused:
		return
	var want := shop.current_step()
	if want.is_empty() or shop.done_kinds.get(want.kind, 0) >= 3 or shop.recipe_hidden():
		return
	var target := Vector2.ZERO
	match want.kind:
		Book.ADD:
			var from := shop.spot_screen("jar%d" % want.what)
			var to: Vector2 = shop.cauldron_screen()[0]
			var k := fmod(_t * 0.8, 1.0)
			target = from.lerp(to, smoothstep(0.15, 0.85, k))
		Book.HEAT:
			if Book.band_of(shop.heat) < want.level:
				target = shop.spot_screen("bellows")
			else:
				return
		Book.ZAP:
			target = shop.spot_screen("wand")
		Book.BOTTLE:
			target = shop.spot_screen("bottle")
		Book.STIR:
			var cs := shop.cauldron_screen()
			var a: float = _t * 3.0 * want.dir
			target = cs[0] + Vector2(cos(a), sin(a) * 0.5) * cs[1] * 0.8
	var bob := absf(sin(_t * 6.0)) * 14.0
	_hand(target + Vector2(10, 18 + bob))


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
	var tap := "TAP TO START BREWING!" if tall else "CLICK OR PRESS SPACE TO START BREWING!"
	_text(tap, Vector2(w * 0.5, h - (220 if tall else 120)), int(36 * pulse), GOLD, 10)
	if shop.best > 0:
		_text("Best: %d coins" % shop.best, Vector2(w * 0.5, h - (160 if tall else 70)), 28, Color.WHITE, 8)
	var how := "Brew each order in the right order:\ningredients, heat, stirring and the wand, then bottle it!"
	_text(how, Vector2(w * 0.5, h - (95 if tall else 190)), 22 if tall else 26, Color("d8c8f0"), 7)
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
	var pots := Book.potions_for(shop.night)
	var cols := 1 if tall else 2
	var rows := int(ceil(pots.size() / float(cols)))
	var r := Rect2(16, 90, w - 32, h - 120)
	if not tall:
		r = Rect2(w * 0.5 - minf(900, w * 0.47), 90, minf(1800, w * 0.94), h - 120)
	_card(r)
	_text("GRUMBLEWART'S RECIPES", Vector2(r.get_center().x, r.position.y + 40), 38, GOLD, 10)
	var row_h := minf(78.0, (r.size.y - 110) / rows)
	var col_w := (r.size.x - 40) / cols
	for k in pots.size():
		var p: int = pots[k]
		var cx := r.position.x + 20 + (k / rows) * col_w
		var y := r.position.y + 84 + (k % rows) * row_h + row_h * 0.5
		var steps := Book.steps_of(Book.POTIONS[p].recipe)
		Icons.bottle(self, Vector2(cx + row_h * 0.35, y + 2), row_h * 0.7, Book.colour_of(Book.POTIONS[p].recipe))
		var name_w := minf(230.0, col_w * 0.36)
		_text(_wrap(Book.POTIONS[p].name, int(minf(24, row_h * 0.34)), name_w), Vector2(cx + row_h * 0.75, y), int(minf(24, row_h * 0.34)), INK, 0, HORIZONTAL_ALIGNMENT_LEFT)
		var icon := minf(row_h * 0.82, (col_w - name_w - row_h * 0.8 - 10) / steps.size())
		for i in steps.size():
			var c := Vector2(cx + row_h * 0.8 + name_w + 10 + icon * (i + 0.5), y)
			Icons.step(self, steps[i], c, icon * 0.9)
			if steps[i].kind == Book.STIR:
				_text("x%d" % steps[i].turns, c + Vector2(icon * 0.3, icon * 0.3), int(icon * 0.3), Color.WHITE, 5)
	_text("Tap to close", Vector2(r.get_center().x, r.end.y - 18), 22, Color("6a4a3a"), 0)
