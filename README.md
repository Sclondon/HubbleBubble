# Hubble Bubble

Granny Grumblewart's potion shop, in the style of an old N64 platformer. You are the witch: the cauldron is in front
of you, the table of ingredients behind it, and other witches come to the serving window wanting potions. There are no
buttons; everything is done with the things in the hut. Godot 4.7, GL Compatibility, phones first and desktops too,
drawn small and blown up soft (the N64 filter, which can be switched off in the pause card).

## Playing

- **The title** has two doors: **Open the Shop** (the nights) and **Brew Freely in the Tower**.
- **Orders**: a customer at the window names a potion ("One Love Philtre, if you please!"). That's all she says:
  look it up in the **book** on the front of the table (`R`) or remember it. Tickets along the top show who's
  waiting and their patience; tap one to switch (`Tab`).
- **Brewing**, done with the things themselves:
  - **ingredients**: pick one up off the table and drag it into the pot (`1`-`8` throw one in). Eye of Newt,
    Toadstool, Bat Wing, Frog Leg on the top step; Spider, Moon Petal, Ghost Pepper, Dragon Scale on the lower.
    In the shop they run out (a count by each); an empty one is a cobwebbed bowl;
  - **heat**: tap the bellows (`Space`, hold to keep pumping). Heat held in a band (WARM, HOT, ROARING) for a
    moment counts. Too far over the top and it boils over and spoils;
  - **stirring**: drag round the pot (`A`/`D`, arrows). Each whole turn counts, sunwise or widdershins;
  - **the wand** in its jar: tap it (`Z`) to quicken the brew;
  - **bottle**: tap the rack of bottles (`Enter`).
  - Hold a finger still on the brew to tip it out (`Backspace`).
  The strip at the foot shows what's gone into the pot so far.
- **Judging**: what counts is what the brew does (see the logic below), so any brew with the potion's effect will do;
  stronger brews and quick ones pay more. The wrong potion she drinks anyway, and you see what it does to her.
- Each ingredient goes in with its own splash (bubbles, spores, purple smoke, a splash, dark smoke, sparkles, ghostly
  wisps, embers); some pairs do more (Fireball, Rainbow, Geyser, Phew...).
- **Nights** need so many coins before the moon crosses the window, or the game is over (the score goes to the
  arcade). Night 2 brings stirring and the Spider, 3 the wand and Moon Petal, 4 the last two jars.
- **The swamp**, between nights: a diorama where ingredients wait in their places (newts in the pool, toadstools on
  the log, bats in the dead tree...). Tap them to gather them for the night ahead; they grow back.
- **Brewing freely**: no customers, no clock, every ingredient. Each bottle goes up the **witches' tower**, where a
  witch drinks it and whatever it does happens to her. New effects are written in the book's "Found by Brewing".

## The cauldron's logic (scripts/lore.gd)

Each ingredient has an element and a virtue (Eye of Newt: water, sight; Toadstool: earth, dreams; Bat Wing: air,
flight; Frog Leg: water, leaping; Spider: earth, binding; Moon Petal: air, love; Ghost Pepper: fire, spirit; Dragon
Scale: fire, might). The first thing in is the **root** (its virtue is what the potion does); the next different one
is the **twist** (some pairs make something else: love + sight is love at first sight, spirit + might is dragon's
breath, leaping + binding is toadishness...). The fire's **temper** must be warm or more (fiery roots bring their
own); **widdershins** turns the effect to its opposite (growing to shrinking, love to loathing); airy and spirited
roots need the **wand**. More of the root, a hotter fire and the wand make it stronger. The book's verse says as
much, vaguely; `tests/lore.gd` checks every recipe in the book makes its potion.

## Layout

| | |
| --- | --- |
| `scripts/main.gd` | `Shop`: the flow (title, nights, swamp, free brewing, tower), orders, brewing, judging, stock, talk, keys |
| `scripts/lore.gd` | The cauldron's logic: what a brew does, its name and description |
| `scripts/book.gd` | Ingredients, the folklore potions and their recipes, customers, rhymes, how each night goes |
| `scripts/hud.gd` | Tickets, the strip, heat gauge, talk, cards, the old book; sends taps into the hut (`Shop.pick`) |
| `scripts/album.gd` | Photographs each model once and tones it sepia for the book |
| `scripts/hut.gd` | The hut, table and what's on it (each with a spot to tap), cauldron, brew surface, reactions, carrying |
| `scripts/witch.gd` | A witch on her skeleton, posed each frame (IK arms, eyes, mouth); customers' moods; drinking potions |
| `scripts/tower.gd` | The tower top where brews are tried; the night sky |
| `scripts/swamp.gd` | The swamp diorama and gathering |
| `scripts/models.gd` | Loads a model, dressed in the vertex-lit look (`*_glass` as glass, `*_glow` shining) |
| `scripts/shape.gd`, `icons.gd` | Code-built room (stones, planks, window) and materials; hand-drawn icons |
| `scripts/sfx.gd` | Plays `sounds/*.res`; people talk in syllables |
| `shaders/` | Vertex-lit look (and its fading copy), the brew (ripples, swirl, boil), fire, glass, sky, the N64 filter |
| `art/make_models.py` | Builds every witch and prop in Blender (`art/*.blend`, `models/*.glb`); `art/preview.py` renders one |
| `tools/render_sounds.gd` | Synthesises every sound and the music |
| `tests/` | `smoke.gd` plays it through, `lore.gd` checks the recipes, `shots.gd` takes pictures, `attract.gd` plays itself |

## Commands

```
blender --background --python art/make_models.py -- <this folder> [witches|customers|props]
blender --background art/<name>.blend --python art/preview.py -- <out.png>
godot --headless --path . -s tools/render_sounds.gd
godot --headless --path . --import
godot --headless --audio-driver Dummy --fixed-fps 60 --path . -s tests/smoke.gd
godot --headless --path . -s tests/lore.gd
godot --audio-driver Dummy --path . -s tests/shots.gd -- --shots=<dir> [--wide] [--only=brewing|book|react|tower|tower_love|swamp]
godot --audio-driver Dummy --path . --fixed-fps 30 --write-movie out.avi -s tests/attract.gd -- --night=3 --seconds=17
godot --headless --path . --export-release "Web" build/index.html
```

For a landscape film, drop an `override.cfg` with `[display] window/size/window_width_override=1280` and
`window_height_override=720` in the folder first, and take it out after.
