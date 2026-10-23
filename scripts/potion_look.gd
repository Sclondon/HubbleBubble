@tool
class_name PotionLook
extends Resource
## How a potion looks in the cauldron: the colour of the liquid and its foam, how it glows and
## lights the room, its lines and glints, how it bubbles, steams and sparkles. One file per effect in
## looks/ (looks/<effect>.tres, e.g. looks/love.tres), edited in Godot's inspector; the brew takes on
## the look of what it's becoming as things go in. tools/make_looks.gd writes the first set.

@export_group("Liquid")
## The colour at the surface, and down in the middle where it's deepest
@export var liquid := Color(0.3, 0.65, 0.55)
@export var deep := Color(0.08, 0.22, 0.2)
## Foam at the rim, in the rings and lines
@export var foam := Color(0.85, 1.0, 0.92)
## Shines by itself (0 none, 1 bright)
@export_range(0.0, 2.0) var glow := 0.15
## The pale lines wandering over it, and glints where the light catches
@export_range(0.0, 1.0) var lines := 0.45
@export_range(0.0, 4.0) var glints := 1.5
## How thick it is: thick brews heave slowly and make fat lazy bubbles (0 water, 1 treacle)
@export_range(0.0, 1.0) var thickness := 0.3
## How fast it swirls by itself
@export_range(0.0, 2.0) var swirl := 0.4

@export_group("Light")
## The light it throws on the hut, and how strong
@export var light_colour := Color(0.4, 1.0, 0.6)
@export_range(0.0, 6.0) var light_energy := 1.2

@export_group("Bubbles")
## How many (with the heat), how big, what colour
@export_range(0.0, 3.0) var bubbles := 1.0
@export_range(0.2, 3.0) var bubble_size := 1.0
@export var bubble_colour := Color(0.7, 1.0, 0.85)
## How solid a bubble's skin is (0 all but invisible, 1 solid), and how bright its rim and glint
@export_range(0.0, 1.0) var bubble_opacity := 0.75
@export_range(0.0, 2.0) var bubble_shine := 1.0

@export_group("Steam")
## How many streamers wind up off it (with the heat), and their colour (alpha: how see-through)
@export_range(0.0, 3.0) var steam := 1.0
@export var steam_colour := Color(0.85, 0.95, 0.9, 0.55)

@export_group("Sparkles")
## Glints that fizz up out of it
@export_range(0.0, 3.0) var sparkles := 0.0
@export var sparkle_colour := Color(1.0, 0.95, 0.6)


## The look for an effect: looks/<effect>.tres if there is one, else one made from `colour`
static func for_effect(effect: String, colour: Color) -> PotionLook:
	var path := "res://looks/%s.tres" % effect.replace(" ", "_").replace("'", "")
	if ResourceLoader.exists(path):
		return load(path)
	return from_colour(colour)


## A plain look made from one colour (for a brew that isn't anything yet)
static func from_colour(colour: Color) -> PotionLook:
	var l := PotionLook.new()
	l.liquid = colour
	l.deep = colour.darkened(0.7)
	l.foam = colour.lightened(0.6)
	l.light_colour = colour.lightened(0.2)
	l.bubble_colour = colour.lightened(0.45)
	l.steam_colour = Color(colour.lightened(0.6), 0.5)
	return l


## A look part way from `a` to `b`
static func blend(a: PotionLook, b: PotionLook, t: float) -> PotionLook:
	var l := PotionLook.new()
	for p in l.get_property_list():
		if not (p.usage & PROPERTY_USAGE_STORAGE) or p.name in ["resource_path", "resource_name", "resource_local_to_scene", "script"]:
			continue
		var x: Variant = a.get(p.name)
		var y: Variant = b.get(p.name)
		if x is float or x is Color:
			l.set(p.name, lerp(x, y, t))
	return l
