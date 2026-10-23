# Hubble Bubble

Granny Grumblewart's potion shop, in the style of an old N64 platformer. You are the witch, leaning over your cauldron
in your hut in the swamp: the pot in front of you on its fire, a shelf of ingredients curving round behind it below the
serving counter, and other witches coming to the counter wanting potions. There are no buttons and no title screen;
everything is done with the things in the hut. Godot 4.7, GL Compatibility, phones first and desktops too, drawn small
and blown up soft and smeared (the N64 filter, always on).

## Playing

- **The hut** is where it starts, the counter shuttered. On its back wall:
  - **the counter shutters** in the middle: tap them to throw them open and open the shop for a night (`O`); tap them
    again mid-night to shut up early (that ends the night there and then);
  - **the back window** on the left: out to the swamp to gather ingredients (`G`);
  - **the door** on the right: out onto the balcony, where brews are tried (`T`).
  The swamp and the balcony are for when the counter's shut.
- **Orders**: a customer at the window names a potion ("I'll take a Love Philtre"). That's all she says: look it up
  in the **book** (`R`) or remember it. Her order is a note pegged to the string across the top, in a hurried
  hand; it scorches up from the bottom as she loses patience. Tap a note to switch (`Tab`).
- **Brewing**, done with the things themselves:
  - **ingredients**: pick one up off the shelf (one eye, one toadstool...) and drag it into the pot (`1`-`8` throw
    one in). It floats there, bobbing on the waves and carried round by the stirring, until the fire cooks it. In
    the shop they run out (a count by each); an empty one is a cobwebbed bowl;
  - **heat**: tap the bellows (`Space`, hold to keep pumping); the dial thermometer clipped to the rim shows it. Heat
    held in a band (WARM, HOT, ROARING) for a moment counts, and cooks what's floating: the pot rattles, everything
    in it jiggles to a little jingle, and melts away. Too far over the top and it boils over and spoils;
  - **stirring**: put a finger on the brew and the stick's tip follows it; take it round the pot (`A`/`D`). Each
    whole turn counts, sunwise or widdershins. The stick leaves a foaming wake, and going round sets the brew
    going round: it dips into a vortex and carries what's floating with it;
  - **the wand** in its jar: tap it (`Z`) to quicken the brew;
  - **bottling**: take an empty jar off the tray on the counter, dip it in the pot and hold it there till it's full,
    then let go: it goes to the customer (the counter open) or out to the balcony to be tried (shut). Let go before
    it's full and it goes back on the tray (`Enter` scoops and hands it over at once).
  - Hold a finger still on the brew to tip it out (`Backspace`).
- **Judging**: what counts is what the brew does (see the logic below), so any brew with the potion's effect will do;
  stronger brews and quick ones pay more. The wrong potion she drinks anyway, and you see what it does to her.
- Each ingredient goes in with its own splash (bubbles, spores, smoke, a splash, dark smoke, sparkles, ghostly wisps,
  embers); some pairs do more (Fireball, Rainbow, Geyser, Phew...).
- **Nights** need so many coins before the moon crosses the window, or the run is over (the score goes to the
  arcade). After a night the shutters close; open them again for the next. Night 2 brings stirring and the Spider, 3
  the wand and Moon Petal, 4 the last two jars.
- **The swamp**, out the back window: the patch behind the hut, where ingredients wait in their places (newts in the
  pool, toadstools on the log, bats in the dead tree...). Tap them to gather them; they grow back. What's gathered keeps.
- **The balcony**: with the counter shut there are no customers, no clock and every ingredient. Each jar filled is
  taken out to the balcony, where a witch drinks it and whatever it does happens to her. New effects are written in
  the book's "Found by Brewing".

**The book** floats open under the back window, showing the pages you last left it at: leave it at the recipe you
want. Tap it to read it close up.

## How each potion looks (looks/)

Each effect has a `PotionLook` resource, `looks/<effect>.tres` (`love.tres`, `dragons_breath.tres`...). Open one in
Godot's inspector to set the liquid's colours, glow, lines, glints, thickness and swirl; the light it throws; its
bubbles (how many, how big, their colour, how solid their skin and how bright their shine); its steam (how many
streamers and their colour); and its sparkles. The brew eases into a potion's look as it becomes that potion.

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
| `scripts/main.gd` | `Shop`: the flow (the hut, the shutters and nights, swamp, balcony), orders, brewing, scooping, judging, stock, keys |
| `scripts/lore.gd` | The cauldron's logic: what a brew does, its name and description |
| `scripts/book.gd` | Ingredients, the folklore potions and their recipes, customers, rhymes, how each night goes |
| `scripts/hud.gd` | The order notes, heat gauge, talk, cards, the old book; sends taps into the hut (`Shop.pick`) |
| `scripts/album.gd` | Photographs each model once and tones it sepia for the book |
| `scripts/hut.gd` | The hut (back wall, shutters, back window, door, the swamp night outside), shelf and what's on it (each with a spot to tap), the stick, carrying and scooping |
| `scripts/brew.gd` | The brew: its surface (a soft hexagon, like the low-poly pot), the stirred current, what's floating and cooking, bubbles, steam streamers, sparkles, splashes (after Salmon Run 2's), its light |
| `scripts/waves.gd` | The brew's wave pool and its foam, worked on the CPU and handed to the surface shader as a texture |
| `scripts/streamers.gd` | Wind Waker steam and smoke: thin winding ribbons built each frame (and the potion's glowing tendrils) |
| `scripts/clouds.gd` | Puffy 3D smoke: lumpy see-through balls of scrolling noise |
| `scripts/pot_fire.gd` | The fire under the pot (cards of `shaders/pot_fire.gdshader`, after the realtimevfx "simple fire" breakdown), sparks, light |
| `scripts/potion_look.gd` | `PotionLook`, how a potion looks (see above) |
| `scripts/witch.gd` | A witch on her skeleton, posed each frame (IK arms, eyes, mouth); customers' moods; drinking potions |
| `scripts/tower.gd` | The balcony where brews are tried (still called the tower); the night sky |
| `scripts/swamp.gd` | The swamp diorama, out in its water, and gathering |
| `scripts/models.gd` | Loads a model, dressed in the vertex-lit look (`*_glass` as glass, `*_glow` shining) |
| `scripts/shape.gd`, `icons.gd` | Code-built room (stones, planks, windows) and materials; hand-drawn icons |
| `scripts/fire.gd` | GameCommon's fire (the candles) |
| `scripts/sfx.gd` | Plays `sounds/*.res`; people talk in syllables |
| `shaders/` | Vertex-lit look (and its fading copy), the brew, bubbles, streamers, splashes, sparks, the pot fire, glass, sky, the N64 filter |
| `art/make_models.py` | Builds every witch and prop in Blender (`art/*.blend`, `models/*.glb`); `art/preview.py` renders one |
| `tools/render_sounds.gd` | Synthesises every sound and the music |
| `tests/` | `smoke.gd` plays it through, `lore.gd` checks the recipes, `shots.gd` takes pictures, `attract.gd` plays itself |

Fonts: Fredoka, Libre Baskerville (the book), Caveat (the order notes), all OFL.

## Commands

```
blender --background --python art/make_models.py -- <this folder> [witches|customers|props]
blender --background art/<name>.blend --python art/preview.py -- <out.png>
godot --headless --path . -s tools/render_sounds.gd
godot --headless --path . --import
godot --headless --audio-driver Dummy --fixed-fps 60 --path . -s tests/smoke.gd
godot --headless --path . -s tests/lore.gd
godot --audio-driver Dummy --path . -s tests/shots.gd -- --shots=<dir> [--wide] [--only=title|brewing|book|react|tower|tower_love|swamp|fire|steam|look_<effect>]
godot --audio-driver Dummy --path . --fixed-fps 30 --write-movie out.avi -s tests/attract.gd -- --night=3 --seconds=20
godot --headless --path . --export-release "Web" build/index.html
```

For a landscape film, drop an `override.cfg` with `[display] window/size/window_width_override=1280` and
`window_height_override=720` in the folder first, and take it out after.

The smoke (streamers, tendrils and puffs) is on a render layer of its own (`Shop.SMOKE_LAYER`), drawn by a second
camera at near full size and laid over the N64 picture, so it stays smooth while everything else is soft and
low-res. Each potion lights the room in its own colour (two lights in `Brew`, kept off the brew's own surface) and
stands a glow up off the pot (`shaders/haze.gdshader`). Customers talk Banjo-Kazooie style: a see-through dark box
over their head, letters popping up one at a time.

**The island and the periscope.** The hut stands on an island after the Isle o' Hags (`models/island.glb`, built in
`art/make_models.py`): hills, a lantern-lit path, a village of round cottages, a spiral mountain, the sea, lit by its
own moon (render layer 8, so the hut stays lit by the potion alone), with witches wandering about. Every witch sold a
potion walks off down the path and drinks it; the eyeball button (`T`) puts the periscope up out of the roof to watch
(`scripts/tower.gd`, Shop's "tower" state). Brewing freely, a witch comes for each bottle and tries it out there.
The swamp is gone; the shelf fills up again each night.
