class_name Lore
## The old logic of the cauldron, which the book hints at in verse and no witch writes down plainly.
##
## Every ingredient carries an element and a virtue. The first thing into the pot is the ROOT: its
## virtue is what the potion does. The next different thing is the TWIST, which can turn it into
## something stranger. The fire is the TEMPER: warm, hot or roaring, the stronger the brew (a cold
## brew does nothing, unless its root is fiery and brings its own heat). Stirring SUNWISE lets the
## virtue wax; stirring WIDDERSHINS makes it wane into its opposite. Airy and spirited roots fly
## off unless QUICKENED with the wand. More of the root, a hotter fire and the wand's spark all make
## it stronger.

## Element and virtue for each ingredient, in Book.INGREDIENTS order
const NATURE := [
	{"element": "water", "virtue": "sight"},
	{"element": "earth", "virtue": "dreams"},
	{"element": "air", "virtue": "flight"},
	{"element": "water", "virtue": "leaping"},
	{"element": "earth", "virtue": "binding"},
	{"element": "air", "virtue": "love"},
	{"element": "fire", "virtue": "spirit"},
	{"element": "fire", "virtue": "might"},
]

## What each virtue does when it waxes, and when it wanes
const EFFECTS := {
	"love": ["love", "loathing"],
	"sight": ["second sight", "blindness"],
	"dreams": ["sleep", "wakefulness"],
	"flight": ["floating", "heaviness"],
	"leaping": ["bouncing", "stumbling"],
	"binding": ["stillness", "wild hair"],
	"might": ["growing", "shrinking"],
	"spirit": ["vanishing", "haunting"],
}

## Pairs of root and twist that make something else entirely
const TWISTS := {
	"love+sight": "love at first sight",
	"spirit+might": "dragon's breath",
	"might+spirit": "dragon's breath",
	"leaping+binding": "toadishness",
	"binding+leaping": "toadishness",
	"dreams+love": "sweet dreams",
	"spirit+sight": "ghost sight",
	"flight+leaping": "moon jump",
}

## How each effect is described, and what it looks like when someone drinks it
const DESCRIBE := {
	"love": "Whoever drinks it is smitten with the first face they see.",
	"loathing": "Whoever drinks it scowls at all the world, and stamps.",
	"second sight": "The drinker's eyes shine; they see in the dark, and maybe further.",
	"blindness": "The drinker's eyes screw shut and will not open.",
	"sleep": "The drinker nods off where they stand.",
	"wakefulness": "The drinker won't sit still for a week.",
	"floating": "The drinker rises off the ground like thistledown.",
	"heaviness": "The drinker sinks, squashed flat as a toad under a cart.",
	"bouncing": "The drinker bounds about like a hare in March.",
	"stillness": "The drinker goes stiff as a gravestone.",
	"stumbling": "The drinker's knees turn to jelly.",
	"wild hair": "Every hair on the drinker's head stands on end.",
	"growing": "The drinker grows great as a giant.",
	"shrinking": "The drinker dwindles to the size of a mouse.",
	"vanishing": "The drinker fades away like mist at dawn.",
	"haunting": "Ghostly lights gather round the drinker and wail.",
	"love at first sight": "Hearts in the eyes, hearts all round: true love, for an hour.",
	"dragon's breath": "The drinker belches great gouts of flame.",
	"toadishness": "The drinker turns green, croaks, and hops.",
	"sweet dreams": "The drinker sleeps, smiling, and dreams of their sweetheart.",
	"ghost sight": "The drinker's eyes glow, and the spirits come to look back.",
	"moon jump": "The drinker leaps clean over the moon.",
	"nothing": "Warm swamp water. It does nothing at all.",
}


## What a brew does: the steps done so far (Book step dictionaries) to
## {effect, root, twist, waning, temper, potency, colour}
static func resolve(steps: Array) -> Dictionary:
	var root := -1
	var twist := -1
	var temper := 0
	var turning := 0
	var quickened := false
	var root_count := 0
	var col := Book.WATER
	var added := 0
	for s: Dictionary in steps:
		match s.kind:
			Book.ADD:
				added += 1
				col = col.lerp(Book.INGREDIENTS[s.what].brew, 1.0 if added == 1 else 0.5)
				if root < 0:
					root = s.what
					root_count = 1
				elif s.what == root:
					root_count += 1
				elif twist < 0 and NATURE[s.what].virtue != NATURE[root].virtue:
					twist = s.what
			Book.HEAT:
				temper = maxi(temper, s.level)
			Book.STIR:
				turning += s.dir * s.turns
			Book.ZAP:
				quickened = true
				col = col.lightened(0.18)
	var out := {"effect": "nothing", "root": root, "twist": twist, "waning": turning < 0, "temper": temper,
			"potency": 0, "colour": col}
	if root < 0:
		return out
	var nature: Dictionary = NATURE[root]
	if temper == 0 and nature.element == "fire":
		temper = 1
	if temper == 0:
		return out
	if (nature.element == "air" or nature.virtue == "spirit") and not quickened:
		return out
	var virtue: String = nature.virtue
	var effect: String = EFFECTS[virtue][1 if turning < 0 else 0]
	if twist >= 0 and turning >= 0:
		var key: String = virtue + "+" + NATURE[twist].virtue
		effect = TWISTS.get(key, effect)
	out.effect = effect
	out.temper = temper
	out.potency = clampi(temper + (root_count - 1) + (1 if quickened else 0), 1, 5)
	return out


## A name for a brew nobody wrote down: "a Strong Draught of Floating"
static func name_of(result: Dictionary) -> String:
	if result.effect == "nothing":
		return "Swamp Water"
	var strength: String = ["", "Mild", "", "Strong", "Mighty", "Terrible"][result.potency]
	var effect := String(result.effect).capitalize()
	return ("%s Draught of %s" % [strength, effect]).strip_edges()
