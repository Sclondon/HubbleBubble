extends SceneTree
## Writes looks/<effect>.tres, one PotionLook for every effect the cauldron can make: the first
## set, to be tuned in Godot's inspector afterwards. Leaves alone any that are there already
## (run with -- --force to write them all again).
## godot --headless --path . -s tools/make_looks.gd [-- --force]

## effect: liquid, deep, foam, glow, light colour, light energy, lines, glints, thickness, swirl,
## bubbles, bubble size, steam, steam colour, sparkles, sparkle colour
const LOOKS := {
	"love": ["ff6aa8", "6a0a3a", "ffd0e8", 0.5, "ff6aa8", 2.2, 0.5, 2.0, 0.35, 0.6, 1.0, 1.2, 0.8, "ffd0e8", 1.0, "ffb0d8"],
	"loathing": ["7a1a1a", "200404", "c84a3a", 0.25, "ff3a1a", 1.6, 0.2, 0.6, 0.6, 0.2, 1.6, 1.6, 1.6, "5a3a3a", 0.0, "ff6a3a"],
	"second sight": ["e8d040", "4a3a08", "fff6b0", 0.7, "ffe060", 2.4, 0.6, 3.0, 0.2, 0.5, 0.8, 0.8, 0.6, "fff6d0", 0.8, "fff27a"],
	"blindness": ["3a3a4a", "0a0a10", "8a8a9a", 0.0, "6a6a8a", 0.6, 0.1, 0.2, 0.7, 0.1, 0.6, 1.4, 1.4, "5a5a6a", 0.0, "8a8a9a"],
	"sleep": ["5a6ac8", "141a4a", "c8d0ff", 0.35, "8a9aff", 1.5, 0.35, 1.0, 0.7, 0.15, 0.5, 1.8, 1.2, "d0d8ff", 0.4, "c8d0ff"],
	"wakefulness": ["ffa22e", "6a2a04", "fff0b0", 0.6, "ffb040", 2.6, 0.7, 2.4, 0.05, 1.4, 2.6, 0.6, 0.8, "fff0d0", 1.4, "fff27a"],
	"floating": ["a8e0ff", "2a5a8a", "ffffff", 0.45, "b0e8ff", 2.0, 0.5, 2.2, 0.1, 0.8, 2.2, 0.8, 2.0, "f0f8ff", 0.6, "ffffff"],
	"heaviness": ["5a4a3a", "1a120a", "8a7a5a", 0.05, "8a6a4a", 0.8, 0.15, 0.4, 0.95, 0.05, 0.4, 2.6, 0.3, "6a5a4a", 0.0, "8a7a5a"],
	"bouncing": ["86d84a", "1a4a0a", "e0ffb0", 0.35, "a0ff60", 1.8, 0.4, 1.8, 0.2, 0.9, 2.0, 1.1, 0.6, "e0ffd0", 0.4, "e0ffb0"],
	"stumbling": ["a8c84a", "3a4a0a", "e8f0a0", 0.2, "c8e060", 1.2, 0.6, 1.0, 0.4, 1.6, 1.2, 1.0, 0.8, "e8f0c0", 0.2, "e8f0a0"],
	"stillness": ["9aa0b0", "3a3e4a", "e8ecf4", 0.1, "c8d0e8", 1.0, 0.0, 1.4, 1.0, 0.0, 0.1, 1.0, 0.2, "d8dce8", 0.0, "ffffff"],
	"wild hair": ["d84aff", "4a0a6a", "ffc8ff", 0.5, "e870ff", 2.2, 0.8, 2.0, 0.2, 1.8, 2.2, 0.9, 1.0, "f0c8ff", 1.2, "ffb0ff"],
	"growing": ["ff8a1a", "6a2004", "ffe0a0", 0.5, "ff9a2a", 2.6, 0.4, 1.6, 0.5, 0.5, 1.4, 2.2, 1.4, "ffe0c0", 0.6, "ffc040"],
	"shrinking": ["4ac8b8", "0a3a3a", "c8fff4", 0.4, "5ae0d0", 1.6, 0.6, 2.4, 0.1, 1.0, 1.4, 0.4, 0.6, "d0fff8", 0.8, "c8fff4"],
	"vanishing": ["c8d0e8", "5a6080", "ffffff", 0.3, "dce4ff", 1.2, 0.3, 3.0, 0.0, 0.6, 0.6, 0.7, 2.6, "eef2ff", 0.6, "ffffff"],
	"haunting": ["5ae8a0", "0a3a2a", "d0ffe8", 0.9, "5affa8", 2.8, 0.5, 1.6, 0.3, 0.7, 0.8, 1.2, 2.4, "b0ffd8", 1.0, "8affc8"],
	"love at first sight": ["ff4a8a", "5a0a2a", "ffe0f0", 0.8, "ff5a9a", 3.0, 0.6, 2.4, 0.3, 0.7, 1.4, 1.2, 1.0, "ffd8ea", 2.0, "ffb0d8"],
	"dragon's breath": ["ff4a10", "4a0a00", "ffc040", 1.0, "ff6a1a", 3.6, 0.3, 1.0, 0.5, 0.6, 2.4, 1.6, 2.0, "4a3a30", 2.4, "ffa22e"],
	"toadishness": ["4a8a2a", "102a08", "a8d870", 0.15, "6aaa3a", 1.2, 0.3, 0.8, 0.85, 0.2, 1.6, 2.0, 1.2, "8aa86a", 0.0, "a8d870"],
	"sweet dreams": ["b890f0", "3a1a6a", "f0e0ff", 0.55, "c8a0ff", 2.0, 0.45, 1.6, 0.6, 0.3, 0.7, 1.6, 1.0, "f0e8ff", 1.0, "ffd0f0"],
	"ghost sight": ["8af0ff", "0a3a4a", "e8ffff", 0.9, "8af0ff", 2.8, 0.5, 2.8, 0.2, 0.6, 0.8, 1.0, 2.0, "d8f8ff", 1.4, "c8f8ff"],
	"moon jump": ["d0d8ff", "3a4a8a", "ffffff", 0.7, "e0e8ff", 2.6, 0.5, 3.2, 0.1, 1.0, 2.4, 0.9, 1.6, "f4f6ff", 1.6, "fff6c8"],
}


func _initialize() -> void:
	var force := "--force" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://looks"))
	var wrote := 0
	for effect: String in LOOKS:
		var path := "res://looks/%s.tres" % effect.replace(" ", "_").replace("'", "")
		if ResourceLoader.exists(path) and not force:
			continue
		var v: Array = LOOKS[effect]
		var l := PotionLook.new()
		l.liquid = Color(v[0])
		l.deep = Color(v[1])
		l.foam = Color(v[2])
		l.glow = v[3]
		l.light_colour = Color(v[4])
		l.light_energy = v[5]
		l.lines = v[6]
		l.glints = v[7]
		l.thickness = v[8]
		l.swirl = v[9]
		l.bubbles = v[10]
		l.bubble_size = v[11]
		l.bubble_colour = Color(v[2])
		l.steam = v[12]
		var sc := Color(v[13])
		sc.a = 0.55
		l.steam_colour = sc
		l.sparkles = v[14]
		l.sparkle_colour = Color(v[15])
		ResourceSaver.save(l, path)
		wrote += 1
	print("wrote %d looks" % wrote)
	quit()
