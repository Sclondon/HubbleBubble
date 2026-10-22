class_name Book
## Granny Grumblewart's book: the ingredients on her shelf, every potion and its recipe, the
## customers who come knocking, the rhymes she mutters, and what each night asks of her.

enum { ADD, HEAT, STIR, ZAP, BOTTLE }

const INGREDIENTS := [
	{"id": "eye", "name": "Eye of Newt", "brew": Color("5fd6c4"), "key": "1", "fx": "bubbles"},
	{"id": "shroom", "name": "Toadstool", "brew": Color("e8473a"), "key": "2", "fx": "spores"},
	{"id": "wing", "name": "Bat Wing", "brew": Color("8a52c9"), "key": "3", "fx": "smoke"},
	{"id": "leg", "name": "Frog Leg", "brew": Color("86d84a"), "key": "4", "fx": "splash"},
	{"id": "spider", "name": "Spider", "brew": Color("3b3a8c"), "key": "5", "fx": "dark"},
	{"id": "petal", "name": "Moon Petal", "brew": Color("a8c8ff"), "key": "6", "fx": "sparkle"},
	{"id": "pepper", "name": "Ghost Pepper", "brew": Color("ffc4e4"), "key": "7", "fx": "ghost"},
	{"id": "scale", "name": "Dragon Scale", "brew": Color("ffa22e"), "key": "8", "fx": "fire"},
]

const WATER := Color("4a9a8a")

## What two ingredients do when one goes in on top of the other: [first, second, effect, its name]
const COMBOS := [
	["scale", "pepper", "fireball", "Fireball!"],
	["pepper", "scale", "fireball", "Fireball!"],
	["petal", "eye", "rainbow", "Rainbow!"],
	["eye", "petal", "rainbow", "Rainbow!"],
	["leg", "leg", "geyser", "Geyser!"],
	["shroom", "leg", "stink", "Phew!"],
	["leg", "shroom", "stink", "Phew!"],
	["spider", "wing", "smoke", "Batty!"],
	["wing", "spider", "dark", "Creepy!"],
]


static func combo(first: int, second: int) -> Array:
	for c: Array in COMBOS:
		if INGREDIENTS[first].id == c[0] and INGREDIENTS[second].id == c[1]:
			return c
	return []

## Heat bands, 0 to 100
const HEAT_NAMES := ["COLD", "WARM", "HOT", "ROARING"]
const HEAT_BANDS := [0.0, 22.0, 47.0, 72.0, 92.0]
const HEAT_COLOURS := [Color("7fb8ff"), Color("ffd84a"), Color("ff9a2e"), Color("ff4a2a")]

## Recipes, written short: an ingredient's id adds it; H1-H3 brings it warm, hot or roaring;
## S+2 stirs it round twice with the sun, S-1 once against; Z is a zap of the wand.
## Every recipe ends with bottling. `night` is the first night it is ordered.
const POTIONS := [
	{"name": "Hiccup Tonic", "recipe": "leg eye H1", "night": 1},
	{"name": "Bat-Eyed Brew", "recipe": "wing eye H2", "night": 1},
	{"name": "Toadstool Soup", "recipe": "shroom H1 shroom", "night": 1},
	{"name": "Belch Broth", "recipe": "shroom leg H2", "night": 1},
	{"name": "Night Sight", "recipe": "eye wing H1 eye", "night": 1},
	{"name": "Spider Cider", "recipe": "spider H2 S+2", "night": 2},
	{"name": "Wobble Juice", "recipe": "leg S+1 shroom S-1", "night": 2},
	{"name": "Creepy Cream", "recipe": "spider eye S-2", "night": 2},
	{"name": "Grumble Gargle", "recipe": "wing H3 S+2 shroom", "night": 2},
	{"name": "Moonlight Elixir", "recipe": "petal H1 Z", "night": 3},
	{"name": "Love Draught", "recipe": "petal shroom S+2 Z", "night": 3},
	{"name": "Shrinking Syrup", "recipe": "spider petal H2 S-1 Z", "night": 3},
	{"name": "Bounce Potion", "recipe": "leg leg H3 S+1 Z", "night": 3},
	{"name": "Ghostly Gargle", "recipe": "pepper H1 S-2 eye Z", "night": 4},
	{"name": "Dragon's Breath", "recipe": "scale H3 pepper S+3", "night": 4},
	{"name": "Witch's Wonder", "recipe": "scale petal H2 S+1 wing Z", "night": 4},
	{"name": "Fireball Fizz", "recipe": "scale shroom H3 Z S-2", "night": 4},
	{"name": "Vanishing Ink", "recipe": "pepper spider H1 Z S+2 eye", "night": 5},
	{"name": "Giant's Grog", "recipe": "leg scale H3 S-1 shroom H1 Z", "night": 5},
]

## Who comes to the window: other witches (models/witch_<model>.glb). `voice` is how high they talk;
## the colours are for the little face on their ticket.
const CUSTOMERS := [
	{"name": "Hattie Hexley", "model": "witch_hattie", "voice": 1.4, "skin": Color("ffcfaa"), "hat": Color("2a6a3a"), "hair": Color("ff7a2a")},
	{"name": "Granny Gristle", "model": "witch_gristle", "voice": 0.8, "skin": Color("a9b49a"), "hat": Color("4a3a2a"), "hair": Color("f2f0e8")},
	{"name": "Bella Nightshade", "model": "witch_bella", "voice": 1.15, "skin": Color("9ad84a"), "hat": Color("1a2450"), "hair": Color("ff4aa8")},
	{"name": "Mother Bogwort", "model": "witch_bogwort", "voice": 0.72, "skin": Color("7a9a4a"), "hat": Color("3a5a32"), "hair": Color("3a5a2a")},
	{"name": "Polly Pumpkins", "model": "witch_polly", "voice": 1.2, "skin": Color("c8a8f0"), "hat": Color("ff8a1a"), "hair": Color("d8302a")},
	{"name": "Esme Wisp", "model": "witch_esme", "voice": 1.3, "skin": Color("eceaff"), "hat": Color("c8c8e8"), "hair": Color("b8c8ff")},
]

const ORDER_LINES := [
	"One %s, if you please!",
	"I'll take a %s, quick!",
	"%s! Hurry, hurry!",
	"Got any %s? I'm desperate!",
	"Mum sent me for %s.",
	"A %s, extra bubbly!",
]

## What Grumblewart says about things, in rhyme, the way she always does
const RHYMES := {
	"title": [
		"Hubble bubble, toil and trouble,\nbrew them right and brew them double!",
	],
	"night": [
		"Night has fallen, moon is high,\ngrubby customers stopping by!",
		"Out come the bats, up comes the moon,\nthe shop is open, they'll be here soon!",
		"Stoke the fire and dust the shelf,\nthe finest witch is me, myself!",
		"Cauldron's bubbling, shelves are stocked,\nthe door's wide open, never locked!",
	],
	"serve": [
		"Bottled up and out the door,\nhappy fools come back for more!",
		"Grumblewart, the finest witch,\nbrews it right without a hitch!",
		"Cork it tight and take it home,\nmind it doesn't start to foam!",
		"Pay me well, you snivelling sprout,\nnow off you go, get out, get out!",
		"Another brew without a flaw,\nthe crowd goes wild, they gasp in awe!",
		"Tasty, toasty, warm and green,\nthe finest potion ever seen!",
	],
	"spoil": [
		"Blech and bother, what a stink!\nThat's not right, now stop and think!",
		"Mucky muck, oh what a mess,\nthat's not the order, more or less!",
		"Silly me, that's not the way,\ntip it out and start the day!",
		"Sludge and slime and lumpy goo,\nthat's not the recipe, that's stew!",
	],
	"boil": [
		"Bubble, bubble, OVER the top!\nToo much fire, you'd better stop!",
		"Hot, hot, HOT, it's boiling over!\nNow it smells like burnt-up clover!",
	],
	"angry": [
		"Off they stomp, the grumpy lout,\nslowcoach witch, you've missed them out!",
		"Waited long and left in a huff,\nmy brewing wasn't quick enough!",
	],
	"wrong_order": [
		"That brew won't do for this one, dear,\nI'll tip it out and start it here.",
	],
	"night_done": [
		"Coins enough to fill my pot!\nRest your broom, you've earned a lot!",
		"Moon goes down and night is through,\nthe shop is shut till night comes new!",
	],
	"game_over": [
		"Not enough coin, oh what a shame,\nGrumblewart has lost the game!",
		"Empty purse and empty pot,\nthe shop is shut, I've lost the lot!",
	],
	"new_stir": [
		"A new trick now, so listen near:\ndrag round the pot to stir it, dear!",
	],
	"new_zap": [
		"Now a zap of my magic wand,\nof sparkly brews I'm very fond!",
	],
	"new_hidden": [
		"Potions you've made, you ought to know!\nForgot? The book's on the shelf below.",
	],
}

## How each night goes: how long, how many coins it needs, how patient people are
static func night_length(night: int) -> float:
	return 120.0 if night < 5 else 135.0


static func quota(night: int) -> int:
	return [0, 60, 110, 160, 210][night] if night <= 4 else 210 + 60 * (night - 4)


static func patience(steps: int, night: int) -> float:
	var hurry := clampf(1.0 - 0.07 * (night - 1), 0.55, 1.0)
	return (28.0 + steps * 7.5) * hurry


static func gap(night: int) -> float:
	return clampf(12.0 - night * 1.3, 4.5, 12.0)


static func most_waiting(night: int) -> int:
	return 2 if night == 1 else 3


static func ingredients_on(night: int) -> int:
	return [0, 4, 5, 6, 8][mini(night, 4)]


## A recipe written out as steps, ending with the bottle
static func steps_of(recipe: String) -> Array:
	var out := []
	for word in recipe.split(" ", false):
		if word.begins_with("H"):
			out.append({"kind": HEAT, "level": int(word.substr(1))})
		elif word.begins_with("S"):
			out.append({"kind": STIR, "dir": 1 if word[1] == "+" else -1, "turns": int(word.substr(2))})
		elif word == "Z":
			out.append({"kind": ZAP})
		else:
			out.append({"kind": ADD, "what": ingredient(word)})
	out.append({"kind": BOTTLE})
	return out


static func ingredient(id: String) -> int:
	for i in INGREDIENTS.size():
		if INGREDIENTS[i].id == id:
			return i
	push_error("No ingredient " + id)
	return 0


## The colour the brew ends up, from what goes in
static func colour_of(recipe: String) -> Color:
	var col := WATER
	var added := 0
	for s: Dictionary in steps_of(recipe):
		if s.kind == ADD:
			added += 1
			col = col.lerp(INGREDIENTS[s.what].brew, 1.0 if added == 1 else 0.5)
		elif s.kind == ZAP:
			col = col.lightened(0.18)
	return col


static func potions_for(night: int) -> Array:
	var out := []
	for i in POTIONS.size():
		if POTIONS[i].night <= night:
			out.append(i)
	return out


static func step_words(s: Dictionary) -> String:
	match s.kind:
		ADD:
			return INGREDIENTS[s.what].name
		HEAT:
			return HEAT_NAMES[s.level]
		STIR:
			return "Stir %s x%d" % ["right" if s.dir > 0 else "left", s.turns]
		ZAP:
			return "Zap!"
	return "Bottle"


static func band_of(heat: float) -> int:
	for b in range(3, -1, -1):
		if heat >= HEAT_BANDS[b]:
			return b
	return 0


static func rhyme(kind: String) -> String:
	var lines: Array = RHYMES[kind]
	return lines[randi() % lines.size()]
