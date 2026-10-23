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

## The potions customers ask for, after the old cunning-folk remedies and curses. Recipes are
## written short: an ingredient's id adds it; H1-H3 brings it warm, hot or roaring; S+2 stirs it
## sunwise twice, S-1 widdershins once; Z quickens it with the wand. Each recipe is one way to the
## potion's `effect` (Lore decides what a brew does; any brew with that effect will do).
## `night` is the first night it's asked for; `about` is what the book says of it.
const POTIONS := [
	{"name": "Sleeping Draught", "effect": "sleep", "recipe": "shroom wing H1", "night": 1,
		"about": "For the babe that will not settle, or the husband that snores. A toadstool's dreaming, warmed gently, with a bat's wing for the dark."},
	{"name": "Cat's Eye Tincture", "effect": "second sight", "recipe": "eye leg H2", "night": 1,
		"about": "Two drops, and the night is bright as noon, as it is to the cat. The eye of a newt, heated till it spits."},
	{"name": "Spring-Heel Tonic", "effect": "bouncing", "recipe": "leg eye H1", "night": 1,
		"about": "Old Jack drank it and leapt the churchyard wall. A frog's leg, warmed; it remembers jumping."},
	{"name": "Wakeful Brew", "effect": "wakefulness", "recipe": "shroom H2 S-1", "night": 2,
		"about": "For the night watchman. Take the dreams out of a toadstool by turning it against the sun."},
	{"name": "Statue's Stillness", "effect": "stillness", "recipe": "spider eye H1", "night": 2,
		"about": "Holds a thief stock still till the constable comes. The spider binds what she touches."},
	{"name": "Toad's Curse", "effect": "toadishness", "recipe": "leg spider H2 S+1", "night": 2,
		"about": "For the neighbour who will not mend his fence. What leaps, bound fast, becomes a toad."},
	{"name": "Hair-Raising Rinse", "effect": "wild hair", "recipe": "spider H1 S-2", "night": 2,
		"about": "A fright in a bottle. Unbind the spider, widdershins, and every hair goes its own way."},
	{"name": "Love Philtre", "effect": "love at first sight", "recipe": "petal eye H1 S+1 Z", "night": 3,
		"about": "Pour it in a cup of mead, and the one who drinks will follow you like a lamb. The moon's petal for the heart, an eye for the first sight; quicken it, or it flies off."},
	{"name": "Bitter Draught", "effect": "loathing", "recipe": "petal H2 S-1 Z", "night": 3,
		"about": "To sour a sweetheart who will not leave you be. Love, turned against the sun, curdles."},
	{"name": "Flying Ointment", "effect": "floating", "recipe": "wing shroom H2 Z", "night": 3,
		"about": "Rubbed on a broom, or drunk by a fool: either way, up they go. The bat's wing wants the wand's spark to lift."},
	{"name": "Leaden Sorrow", "effect": "heaviness", "recipe": "wing H1 S-2 Z", "night": 3,
		"about": "It weighs on the drinker like a bad conscience. Flight, unwound."},
	{"name": "Sweet Dreams", "effect": "sweet dreams", "recipe": "shroom petal H1", "night": 3,
		"about": "A lullaby you can drink. Dreams first, then a moon petal to sweeten them."},
	{"name": "Giant's Grog", "effect": "growing", "recipe": "scale leg H3", "night": 4,
		"about": "Brewed for the blacksmith; now he cannot fit through his door. A dragon's might, roused to a roar."},
	{"name": "Shrinking Solution", "effect": "shrinking", "recipe": "scale H2 S-2", "night": 4,
		"about": "For hiding in a mouse hole, or under a hat. Might, wound back the wrong way."},
	{"name": "Vanishing Draught", "effect": "vanishing", "recipe": "pepper wing H1 Z", "night": 4,
		"about": "As mist at morning: there, and then not. The ghost in the pepper must be quickened."},
	{"name": "Dragon's Breath", "effect": "dragon's breath", "recipe": "pepper scale H3 Z", "night": 4,
		"about": "Lights the hearth, and the curtains, and the cat. Spirit and might together, roaring."},
	{"name": "Ghost Sight", "effect": "ghost sight", "recipe": "pepper eye H2 Z", "night": 4,
		"about": "See the dead as they see you. A spirit, and an eye to see it with."},
	{"name": "Moon Jump Elixir", "effect": "moon jump", "recipe": "wing leg H2 S+2 Z", "night": 5,
		"about": "Up over the moon, like the cow in the rhyme. Flight, with a leap in it."},
	{"name": "Haunting Mist", "effect": "haunting", "recipe": "pepper H1 S-1 Z", "night": 5,
		"about": "Brings the restless dead round to wail at a door. The pepper's ghost, turned widdershins."},
]


## A step in the book's old words
static func old_words(s: Dictionary) -> String:
	match s.kind:
		ADD:
			return ["an Eye of Newt", "a Toadstool", "a Bat's Wing", "a Frog's Leg", "a Spider", "a Moon Petal",
					"a Ghost Pepper", "a Dragon's Scale"][s.what]
		HEAT:
			return ["", "warm it till it sighs", "heat it till it spits", "rouse it to a roar"][s.level]
		STIR:
			var times: String = ["", "once", "twice", "thrice", "four times", "five times", "six times"][mini(s.turns, 6)]
			return "stir it %s %s" % ["sunwise" if s.dir > 0 else "widdershins", times]
		ZAP:
			return "quicken it with the wand"
	return "and stopper it fast"

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
	"swamp": [
		"Out to the swamp with basket and knife,\ngather the makings of potion and life!",
		"Newts in the pool and bats in the tree,\nthe swamp gives up all its goodies to me!",
	],
	"free": [
		"Brew what you will and brew what you please,\nthen up to the tower, and see what it sees!",
	],
	"wrong": [
		"That's not what she asked for, dear,
and now look what's happened here!",
		"Oh, botheration, wrong again,
she'll not be back here, that I'll ken!",
		"Wrong brew, wrong bottle, wrong old witch,
my reputation's in the ditch!",
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
		"They'll only say the name, you see,\nthe book will tell the rest to me!",
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


## What the customers say, in rhyme (you, the witch, say nothing)
const LINES := {
	"thanks": [
		"Oh that's the one, the very brew!\nGrumblewart, I'm in love with you!",
		"Bottled up and corked so tight,\nI'll sleep like a baby bat tonight!",
		"Bless your warts and bless your pot,\nthat's exactly what I've got!",
		"Smells like feet and looks like sludge,\nthat's the stuff! I'll hold no grudge!",
	],
	"wrong": [
		"That's not what I asked you for!\nWhat have you DONE? I'm out the door!",
		"Wrong, you crone, it's WRONG, you see!\nNow look at what you've done to me!",
		"I said one thing and you made another,\nI'm off to tell my witchy mother!",
	],
	"angry": [
		"Waited long enough, I have!\nI'll take my coin to the hag in the bath!",
		"Slow as a slug in a bucket of glue,\nI'm off, and I'm not coming back to you!",
	],
}


static func line(kind: String) -> String:
	var lines: Array = LINES[kind]
	return lines[randi() % lines.size()]


static func rhyme(kind: String) -> String:
	var lines: Array = RHYMES[kind]
	return lines[randi() % lines.size()]
