extends SceneTree
## Synthesises every sound in the game into sounds/*.res: the music (a bouncy, swung oom-pah tune in
## D minor: tuba, marimba, plucked chords, a woodblock), the cauldron's noises, and the mumbled
## syllables Grumblewart and the customers talk in.
## godot --headless --path . -s tools/render_sounds.gd

const RATE := 22050
const OUT := "res://sounds/"

var rng := RandomNumberGenerator.new()


func _initialize() -> void:
	rng.seed = 13
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_music()
	_sfx()
	_voices()
	print("sounds written")
	quit()


func _save(name: String, data: PackedFloat32Array, loop := false) -> void:
	var peak := 0.0
	for x in data:
		peak = maxf(peak, absf(x))
	var gain := 0.9 / peak if peak > 0.9 else 1.0
	var bytes := PackedByteArray()
	bytes.resize(data.size() * 2)
	for i in data.size():
		bytes.encode_s16(i * 2, int(clampf(data[i] * gain, -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = data.size()
	ResourceSaver.save(w, OUT + name + ".res")


static func midi_hz(m: float) -> float:
	return 440.0 * pow(2.0, (m - 69.0) / 12.0)


static func note_midi(name: String) -> int:
	var names := {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
	var n: int = names[name[0]]
	var i := 1
	if name[i] == "#":
		n += 1
		i += 1
	elif name[i] == "b":
		n -= 1
		i += 1
	return n + (int(name.substr(i)) + 1) * 12


# --- instruments, each adds itself into `buf` at sample `at` ---

func marimba(buf: PackedFloat32Array, at: int, hz: float, length: float, vol: float) -> void:
	var n := int(minf(length + 0.6, 1.2) * RATE)
	for i in n:
		var t := float(i) / RATE
		if at + i >= buf.size():
			break
		var env := minf(1.0, t * 300.0) * exp(-t * 6.5)
		var s := sin(TAU * hz * t) + 0.35 * sin(TAU * hz * 3.93 * t) * exp(-t * 20.0) + 0.12 * sin(TAU * hz * 2.0 * t)
		buf[at + i] += s * env * vol


func tuba(buf: PackedFloat32Array, at: int, hz: float, length: float, vol: float) -> void:
	var n := int((length + 0.08) * RATE)
	for i in n:
		var t := float(i) / RATE
		if at + i >= buf.size():
			break
		var env := minf(1.0, t * 40.0) * (0.75 + 0.25 * exp(-t * 6.0))
		if t > length:
			env *= maxf(0.0, 1.0 - (t - length) / 0.08)
		var s := 0.0
		for h in range(1, 7):
			s += sin(TAU * hz * h * t) / pow(h, 1.6)
		buf[at + i] += s * env * vol


func pluck(buf: PackedFloat32Array, at: int, hz: float, vol: float) -> void:
	var n := int(0.35 * RATE)
	for i in n:
		var t := float(i) / RATE
		if at + i >= buf.size():
			break
		var s := 0.0
		for h in range(1, 6):
			s += sin(TAU * hz * h * t) * exp(-t * (8.0 + h * 6.0)) / h
		buf[at + i] += s * minf(1.0, t * 500.0) * vol


func woodblock(buf: PackedFloat32Array, at: int, hz: float, vol: float) -> void:
	var n := int(0.12 * RATE)
	for i in n:
		var t := float(i) / RATE
		if at + i >= buf.size():
			break
		buf[at + i] += (sin(TAU * hz * t) + 0.5 * sin(TAU * hz * 1.52 * t)) * exp(-t * 45.0) * vol


func _music() -> void:
	var bpm := 132.0
	var eighth := 60.0 / bpm / 2.0
	var bars := 16
	var total := int(bars * 8 * eighth * RATE)
	var buf := PackedFloat32Array()
	buf.resize(total + RATE)
	var melody := [
		"A4:1 D5:1 F5:1 A5:1 G#5:1 A5:1 F5:2",
		"E5:1 C#5:1 E5:1 G5:1 F5:1 E5:1 C#5:2",
		"D5:1 F5:1 A5:1 D6:1 C#6:1 D6:1 A5:2",
		"Bb5:1 A5:1 G5:1 Bb5:1 A5:1 G5:1 E5:2",
		"F5:1 E5:1 F5:1 A5:1 D5:2 R:2",
		"D5:1 F5:1 Bb5:2 A5:1 Bb5:1 D6:2",
		"G5:1 Bb5:1 D6:1 Bb5:1 A5:1 G5:1 F5:1 E5:1",
		"C#5:2 E5:2 A4:2 R:2",
		"C5:1 F5:1 A5:1 C6:1 A5:2 F5:2",
		"E5:1 G5:1 C6:1 G5:1 E5:2 C5:2",
		"D5:1 F5:1 A5:1 F5:1 D5:1 F5:1 A5:2",
		"C#6:1 A5:1 G5:1 E5:1 C#5:2 A4:2",
		"D6:1 C6:1 Bb5:1 A5:1 Bb5:2 F5:2",
		"G5:1 A5:1 Bb5:1 C6:1 D6:2 Bb5:2",
		"A5:1 G5:1 F5:1 E5:1 C#5:1 E5:1 G5:2",
		"F5:1 E5:1 D5:2 A4:2 D5:2",
	]
	# Each bar's chords: root, fifth and chord tones (two chords where a bar has two)
	var chords := [
		["Dm"], ["A7"], ["Dm"], ["Gm", "A7"], ["Dm"], ["Bb"], ["Gm"], ["A7"],
		["F"], ["C"], ["Dm"], ["A7"], ["Bb"], ["Gm"], ["A7"], ["Dm"],
	]
	var shapes := {
		"Dm": [50, 57, ["D4", "F4", "A4"]],
		"A7": [45, 52, ["C#4", "E4", "G4"]],
		"Gm": [43, 50, ["D4", "G4", "Bb4"]],
		"Bb": [46, 53, ["D4", "F4", "Bb4"]],
		"F": [41, 48, ["C4", "F4", "A4"]],
		"C": [48, 55, ["C4", "E4", "G4"]],
	}
	var at_eighth := func(e: float) -> int:
		# Swung: the off-beat eighths come late
		var whole := floorf(e)
		var swing := 0.32 if int(whole) % 2 == 1 else 0.0
		return int((whole + swing + (e - whole)) * eighth * RATE)
	for bar in bars:
		var e0 := bar * 8
		var pos := 0
		for word: String in melody[bar].split(" ", false):
			var parts := word.split(":")
			var len := int(parts[1])
			if parts[0] != "R":
				marimba(buf, at_eighth.call(e0 + pos), midi_hz(note_midi(parts[0])), len * eighth, 0.32)
				marimba(buf, at_eighth.call(e0 + pos), midi_hz(note_midi(parts[0]) + 12), len * eighth, 0.06)
			pos += len
		var cs: Array = chords[bar]
		for beat in 4:
			var chord: Array = shapes[cs[0] if cs.size() == 1 or beat < 2 else cs[1]]
			var e := e0 + beat * 2
			if beat % 2 == 0:
				var root: int = chord[0] if beat == 0 or cs.size() > 1 else chord[1]
				tuba(buf, at_eighth.call(e), midi_hz(root - 12), eighth * 1.6, 0.42)
			else:
				for nm: String in chord[2]:
					pluck(buf, at_eighth.call(e), midi_hz(note_midi(nm)), 0.11)
				woodblock(buf, at_eighth.call(e), 900.0, 0.18)
			if beat == 3 and bar % 2 == 1:
				woodblock(buf, at_eighth.call(e + 1), 1250.0, 0.12)
	# Wrap the tail that rang past the end round to the start, so the loop has no seam
	for i in RATE:
		buf[i] += buf[total + i]
	buf.resize(total)
	_save("music", buf, true)


func _sfx() -> void:
	# Plop: something dropped in, a falling blob and a splash of noise
	var b := _buf(0.35)
	for i in b.size():
		var t := float(i) / RATE
		var hz := 520.0 * exp(-t * 9.0) + 140.0
		b[i] = sin(TAU * hz * t * (1.0 + t)) * exp(-t * 14.0) * 0.8 + _noise() * exp(-t * 25.0) * 0.25
	_save("plop", b)
	# Bubble: a little rising bloop
	b = _buf(0.09)
	for i in b.size():
		var t := float(i) / RATE
		b[i] = sin(TAU * (300.0 + t * 7000.0) * t) * sin(PI * t / 0.09) * 0.6
	_save("bubble", b)
	# Bellows: a puff of breathy noise
	b = _filtered_noise(0.4, 0.12, func(t: float) -> float: return sin(PI * minf(t / 0.4, 1.0)) ** 1.5)
	_save("puff", b)
	# Slosh: the ladle going round, low and wet
	b = _filtered_noise(0.3, 0.05, func(t: float) -> float: return sin(PI * t / 0.3) * (0.7 + 0.3 * sin(t * 60.0)))
	_save("slosh", b)
	# Zap: a sparkly run up
	b = _buf(0.7)
	var run := [84, 88, 91, 96, 100]
	for k in run.size():
		var start := int(k * 0.06 * RATE)
		var hz := midi_hz(run[k])
		for i in range(start, b.size()):
			var t := float(i - start) / RATE
			b[i] += (sin(TAU * hz * t) + 0.4 * sin(TAU * hz * 2.01 * t)) * exp(-t * 7.0) * 0.25
	_save("zap", b)
	# Spoilt: a low gloopy blorp that sags
	b = _buf(0.8)
	for i in b.size():
		var t := float(i) / RATE
		var hz := 180.0 * exp(-t * 2.2) + 50.0 + sin(t * 40.0) * 12.0
		var ph := TAU * hz * t
		b[i] = (sin(ph) + 0.4 * sin(ph * 2.0) + 0.2 * signf(sin(ph))) * minf(1.0, t * 40.0) * exp(-t * 3.0) * 0.6
	_save("blorp", b)
	# Boiling over: a hiss
	b = _filtered_noise(0.9, 0.6, func(t: float) -> float: return minf(1.0, t * 10.0) * exp(-t * 2.5))
	_save("hiss", b)
	# Cork: a pop then a glug
	b = _buf(0.45)
	for i in b.size():
		var t := float(i) / RATE
		b[i] = sin(TAU * 700.0 * t * (1.0 - t)) * exp(-t * 60.0) * 0.9
		if t > 0.12:
			var u := t - 0.12
			b[i] += sin(TAU * (220.0 + sin(u * 50.0) * 60.0) * u) * exp(-u * 9.0) * 0.4
	_save("cork", b)
	# Coins: two bright pings
	b = _buf(0.6)
	for k in 2:
		var start := int(k * 0.09 * RATE)
		var hz := 1900.0 + k * 500.0
		for i in range(start, b.size()):
			var t := float(i - start) / RATE
			b[i] += (sin(TAU * hz * t) + 0.5 * sin(TAU * hz * 2.76 * t) + 0.25 * sin(TAU * hz * 5.4 * t)) * exp(-t * 9.0) * 0.22
	_save("coins", b)
	# Tick-tock of the last seconds
	b = _buf(0.08)
	for i in b.size():
		var t := float(i) / RATE
		b[i] = sin(TAU * 1500.0 * t) * exp(-t * 80.0) * 0.6
	_save("tick", b)
	# Tap on a button
	b = _buf(0.06)
	for i in b.size():
		var t := float(i) / RATE
		b[i] = sin(TAU * 660.0 * t) * exp(-t * 70.0) * 0.5
	_save("tap", b)
	# Jingles, on the band's own instruments
	_jingle("cheer", [[0.0, "D5"], [0.09, "F5"], [0.18, "A5"], [0.27, "D6"]], [])
	_jingle("huff", [], [[0.0, "A2", 0.25], [0.3, "G#2", 0.5]])
	_jingle("night", [[0.0, "D5"], [0.14, "A5"], [0.28, "F5"], [0.42, "D6"], [0.56, "C#6"], [0.7, "D6"]], [[0.0, "D2", 0.3], [0.42, "A2", 0.3], [0.7, "D2", 0.5]])
	_jingle("win", [[0.0, "F5"], [0.12, "A5"], [0.24, "C6"], [0.36, "F6"], [0.6, "E6"], [0.72, "F6"]], [[0.0, "F2", 0.3], [0.36, "C3", 0.25], [0.6, "F2", 0.6]])
	_jingle("lose", [[0.0, "A4"], [0.35, "G#4"], [0.7, "G4"], [1.05, "F#4"]], [[0.0, "A2", 0.3], [0.35, "G#2", 0.3], [0.7, "G2", 0.3], [1.05, "D2", 0.8]])
	_cook()


## Cooking: the pot rattling on the fire (a clatter of woodblocks) under a bouncy little run of
## marimba that climbs and climbs, then lands on a bright "ta-da!"
func _cook() -> void:
	var b := _buf(2.6)
	var run := ["D5", "F#5", "A5", "F#5", "E5", "G5", "B5", "G5", "F#5", "A5", "D6", "A5", "G5", "B5", "E6", "C#6"]
	for k in run.size():
		var at := k * 0.1
		marimba(b, int(at * RATE), midi_hz(note_midi(run[k])), 0.1, 0.32)
		woodblock(b, int(at * RATE), 900.0 + (k % 2) * 260.0, 0.22)
		woodblock(b, int((at + 0.05) * RATE), 1300.0, 0.12)
	for k in 4:
		tuba(b, int(k * 0.4 * RATE), midi_hz(note_midi(["D3", "E3", "F#3", "A2"][k])), 0.3, 0.3)
	# Ta-da
	for n: String in ["D6", "F#6", "A6", "D5"]:
		marimba(b, int(1.72 * RATE), midi_hz(note_midi(n)), 0.6, 0.3)
	marimba(b, int(1.62 * RATE), midi_hz(note_midi("A5")), 0.1, 0.25)
	tuba(b, int(1.72 * RATE), midi_hz(note_midi("D2")), 0.6, 0.4)
	_save("cook", b)


func _jingle(name: String, high: Array, low: Array) -> void:
	var b := _buf(2.0)
	for n: Array in high:
		marimba(b, int(n[0] * RATE), midi_hz(note_midi(n[1])), 0.3, 0.4)
	for n: Array in low:
		tuba(b, int(n[0] * RATE), midi_hz(note_midi(n[1])), n[2], 0.45)
	var end := b.size() - 1
	while end > 0 and absf(b[end]) < 0.002:
		end -= 1
	b.resize(end + 1)
	_save(name, b)


func _buf(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * RATE))
	return b


func _noise() -> float:
	return rng.randf_range(-1.0, 1.0)


# Noise smoothed by a one-pole filter (`bright` 0 to 1), shaped by `env`
func _filtered_noise(seconds: float, bright: float, env: Callable) -> PackedFloat32Array:
	var b := _buf(seconds)
	var y := 0.0
	for i in b.size():
		y += (_noise() - y) * bright
		b[i] = y * env.call(float(i) / RATE) * (1.5 / sqrt(bright))
	return b


# The mumbled syllables people talk in: a buzzy voice through vowel formants, each with a little
# consonant at its start. Grumblewart's are low and raspy with a wobble; the folk's are plain and
# pitched up or down as each customer talks.
func _voices() -> void:
	var vowels := [[730, 1090, 2440], [530, 1840, 2480], [300, 2200, 2900], [570, 840, 2410], [440, 1020, 2240], [660, 1700, 2400]]
	for who: String in ["witch", "folk"]:
		for k in vowels.size():
			var f0 := 175.0 if who == "witch" else 235.0
			var length := rng.randf_range(0.085, 0.12)
			var b := _buf(length)
			var f: Array = vowels[k]
			var ph := 0.0
			for i in b.size():
				var t := float(i) / RATE
				var hz := f0 * (1.0 + 0.25 * (1.0 - t / length)) * (1.0 + (0.04 * sin(t * 70.0) if who == "witch" else 0.0))
				ph += TAU * hz / RATE
				var s := 0.0
				var h := 1
				while h * hz < 4000.0:
					var fh := h * hz
					var w := 0.0
					for j in 3:
						var bw: float = 90.0 + j * 60.0
						w += exp(-pow((fh - float(f[j])) / bw, 2.0)) * (1.0 - j * 0.3)
					s += sin(ph * h) * (w + 0.02) / sqrt(h)
					h += 1
				var env := minf(1.0, t * 120.0) * minf(1.0, (length - t) * 60.0)
				if who == "witch":
					s += _noise() * 0.15
				if t < 0.018:
					s += _noise() * (1.0 - t / 0.018) * 0.6
				b[i] = s * env * 0.5
			_save("%s_%d" % [who, k], b)
