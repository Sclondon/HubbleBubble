# Hubble Bubble

Granny Grumblewart's potion shop, in the style of an old N64 platformer: a green, hook-nosed, goggle-eyed
witch who talks in rhyme (and in mumbled syllables), a stone hut with a cauldron on a green fire, and customers
at the window who are all googly eyes and bounce. Customers order potions; each potion is a recipe of steps done
in order, then bottled. Godot 4.7, GL Compatibility, made for phones first and desktops too.

## Playing

- **Orders**: tickets along the top (down the left on a wide screen). The one picked out is the customer at the
  window and the recipe on the strip above the shelf. Tap another ticket to switch (`Tab`); the brew carries over
  only if the new recipe starts the same way. The bar on a ticket is patience; at the end of it they storm off.
- **Steps**, in the order on the strip:
  - an ingredient: tap its jar (`1`-`8`): Eye of Newt, Toadstool, Bat Wing, Frog Leg, Spider, Moon Petal,
    Ghost Pepper, Dragon Scale;
  - heat (WARM, HOT, ROARING): pump the bellows (`Space`, hold to keep pumping) until the gauge is in that band and
    hold it there a second. The fire dies down by itself. Too far over the top for a moment and it boils over;
  - stir right or left so many times: drag round the pot (`A`/`D` or the arrows). A nudge is forgiven, a whole
    turn the wrong way or when no stirring is asked for spoils it;
  - zap: the wand (`Z`);
  - bottle (`Enter`): serves it. Too soon only grumbles.
- Anything else spoils the brew: it goes murky, she rhymes about it, and it's tipped out.
- **Coins**: more for longer recipes, a tip for speed, a bonus for a run without spoiling. Each night needs so
  many coins before the moon crosses the window; miss it and the game is over (the score goes to the arcade).
- **Nights**: 1 has four jars and heat; 2 adds stirring and the Spider; 3 the wand and Moon Petal; 4 the last
  two jars, and potions already made once hide their recipes (the **Book**, `R`, has them all). From 5 on it gets
  busier. A pointing hand shows what to do for each kind of step until it's been done three times.
- Pause: the button top right (`Esc`/`P`): sound, back to the title.

## Layout

| | |
| --- | --- |
| `scripts/main.gd` | `Shop`: the nights, orders, the rules of the brew, scoring, talk, keys |
| `scripts/book.gd` | Ingredients, potions and recipes, customers, rhymes, how each night goes |
| `scripts/hud.gd` | Every control drawn by hand, multi-touch, tall and wide layouts, the cards |
| `scripts/icons.gd` | The hand-drawn pictures on the controls |
| `scripts/hut.gd` | The hut, window and moon, the cauldron, fire and particles |
| `scripts/witch.gd` | Grumblewart: rigid pieces, IK arms on the ladle and wand, moods |
| `scripts/critter.gd` | The customers: frog, mole, ghost, goblin, mushroom, pumpkinhead, bat |
| `scripts/shape.gd` | Builds the vertex-coloured low-poly meshes (balls, tubes, rings) in code; googly eyes |
| `scripts/sfx.gd` | Plays `sounds/*.res`; people talk in syllables |
| `shaders/` | Vertex-lit look, the brew's swirl, additive fire |
| `tools/render_sounds.gd` | Synthesises every sound and the music (no recorded samples) |
| `tests/` | `smoke.gd` plays it through, `shots.gd` takes pictures, `attract.gd` plays itself (preview film) |

## Commands

```
godot --headless --path . -s tools/render_sounds.gd
godot --headless --path . --import
godot --headless --audio-driver Dummy --fixed-fps 60 --path . -s tests/smoke.gd
godot --audio-driver Dummy --path . -s tests/shots.gd -- --shots=<dir> [--wide] [--only=brewing]
godot --audio-driver Dummy --path . --fixed-fps 30 --write-movie out.avi -s tests/attract.gd -- --night=3 --seconds=17
godot --headless --path . --export-release "Web" build/index.html
```

For a landscape film, drop an `override.cfg` with `[display] window/size/window_width_override=1280` and
`window_height_override=720` in the folder first, and take it out after.
