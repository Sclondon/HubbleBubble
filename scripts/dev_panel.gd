class_name DevPanel
extends PanelContainer
## Dev mode: every setting of a potion's look (PotionLook) on sliders and colour pickers, changing the
## brew live as you drag, with Save. In the Godot editor (or a desktop run of the project) Save writes
## looks/<effect>.tres straight into the project; in a browser it keeps your version (it's used from
## then on, in that browser) and downloads the .tres file to drop into looks/. Opened from the pause
## card (or the backquote key).

var shop: Shop
var _effect := ""
var _look: PotionLook
var _picker: OptionButton
var _rows: VBoxContainer
var _note: Label


func _ready() -> void:
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 1.0
	offset_left = -350.0
	offset_right = 0.0
	offset_top = 70.0
	offset_bottom = 0.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.03, 0.09, 0.88)
	sb.set_content_margin_all(10)
	add_theme_stylebox_override("panel", sb)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(330, 400)
	add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	var title := Label.new()
	title.text = "Potion look (dev)"
	box.add_child(title)
	_picker = OptionButton.new()
	_picker.add_item("(what's in the pot)")
	for e: String in _effects():
		_picker.add_item(e)
	_picker.item_selected.connect(func(i: int) -> void: _choose("" if i == 0 else _picker.get_item_text(i)))
	box.add_child(_picker)
	var buttons := HBoxContainer.new()
	box.add_child(buttons)
	for spec: Array in [["Save", _save], ["Revert", func() -> void: _choose(_effect)], ["Close", func() -> void: shop.toggle_dev()]]:
		var b := Button.new()
		b.text = spec[0]
		b.pressed.connect(spec[1])
		buttons.add_child(b)
	_note = Label.new()
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD
	_note.add_theme_font_size_override("font_size", 12)
	box.add_child(_note)
	_rows = VBoxContainer.new()
	box.add_child(_rows)
	_choose("")


## The effects there are looks for
static func _effects() -> Array:
	var out := []
	var d := DirAccess.open("res://looks")
	if d != null:
		for f in d.get_files():
			var name := f.trim_suffix(".remap")
			if name.ends_with(".tres"):
				out.append(name.trim_suffix(".tres"))
	out.sort()
	return out


func _choose(effect: String) -> void:
	_effect = effect if effect != "" else String(shop.hut.brew_effect)
	var src: PotionLook = PotionLook.for_effect(_effect, Book.WATER) if _effect != "" else shop.hut.brew.look
	_look = src.duplicate()
	_note.text = "Editing: %s" % (_effect if _effect != "" else "plain water (nothing to save)")
	shop.hut.brew.set_look(_look, true)
	for c in _rows.get_children():
		c.queue_free()
	for p in _look.get_property_list():
		if not (p.usage & PROPERTY_USAGE_EDITOR) or not (p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var name: String = p.name
		var v: Variant = _look.get(name)
		var row := HBoxContainer.new()
		var l := Label.new()
		l.text = name
		l.custom_minimum_size = Vector2(120, 0)
		l.add_theme_font_size_override("font_size", 12)
		row.add_child(l)
		if v is Color:
			var cp := ColorPickerButton.new()
			cp.color = v
			cp.custom_minimum_size = Vector2(150, 26)
			cp.color_changed.connect(func(c: Color) -> void: _put(name, c))
			row.add_child(cp)
		elif v is float:
			var lo := 0.0
			var hi := 3.0
			if p.hint == PROPERTY_HINT_RANGE:
				var parts := String(p.hint_string).split(",")
				lo = float(parts[0])
				hi = float(parts[1])
			var sl := HSlider.new()
			sl.min_value = lo
			sl.max_value = hi
			sl.step = (hi - lo) / 200.0
			sl.value = v
			sl.custom_minimum_size = Vector2(150, 26)
			sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var val := Label.new()
			val.text = "%.2f" % v
			val.add_theme_font_size_override("font_size", 12)
			sl.value_changed.connect(func(x: float) -> void:
				val.text = "%.2f" % x
				_put(name, x))
			row.add_child(sl)
			row.add_child(val)
		elif v is int:
			var ob := SpinBox.new()
			ob.min_value = 0
			ob.max_value = 6
			ob.value = v
			ob.value_changed.connect(func(x: float) -> void: _put(name, int(x)))
			row.add_child(ob)
		else:
			continue
		_rows.add_child(row)


func _put(name: String, v: Variant) -> void:
	_look.set(name, v)
	shop.hut.brew.set_look(_look, true)


func _save() -> void:
	if _effect == "":
		_note.text = "Nothing to save: put something in the pot, or choose a potion above."
		return
	var file := "%s.tres" % _effect.replace(" ", "_").replace("'", "")
	# Kept for this browser / machine (used from now on)
	DirAccess.make_dir_recursive_absolute("user://looks")
	ResourceSaver.save(_look, "user://looks/" + file)
	if OS.has_feature("editor"):
		var err := ResourceSaver.save(_look, "res://looks/" + file)
		_note.text = "Saved to res://looks/%s (%s)" % [file, "ok" if err == OK else "error %d" % err]
	elif OS.has_feature("web"):
		var text := FileAccess.get_file_as_string("user://looks/" + file)
		JavaScriptBridge.download_buffer(text.to_utf8_buffer(), file, "text/plain")
		_note.text = "Kept in this browser, and downloaded %s: put it in the project's looks/ folder to keep it for everyone." % file
	else:
		_note.text = "Saved to %s" % ProjectSettings.globalize_path("user://looks/" + file)
