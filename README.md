# Hubble Bubble

Granny Grumblewart's potion shop, in the style of an old N64 platformer: a green, hook-nosed, goggle-eyed
witch who talks in rhyme (and in mumbled syllables), a stone hut with a cauldron on a green fire, and other
witches at the window wanting potions. There are no buttons: everything is done with the things in the hut. Customers order potions; each potion is a recipe of steps done
in order, then bottled. Godot 4.7, GL Compatibility, made for phones first and desktops too.

## Playing

- **Orders**: tickets along the top (down the left on a wide screen). The one picked out is the customer at the
  window and the recipe on the strip above the shelf. Tap another ticket to switch (`Tab`); the brew carries over
  only if the new recipe starts the same way. The bar on a ticket is patience; at the end of it they storm off.
- **Steps**, in the order on the strip:
  - an ingredient: tap it on the table (`1`-`8`): Eye of Newt, Toadstool, Bat Wing, Frog Leg on the top step;
    Spider, Moon Petal, Ghost Pepper, Dragon Scale on the lower one. Ones not stocked yet are cobwebbed bowls;
  - heat (WARM, HOT, ROARING): tap the bellows by the fire (`Space`, hold to keep pumping) until the gauge is in that band and
    hold it there a second. The fire dies down by itself. Too far over the top for a moment and it boils over;
  - stir right or left so many times: drag the stick round the pot (`A`/`D` or the arrows). A nudge is forgiven, a whole
    turn the wrong way or when no stirring is asked for spoils it;
  - zap: the wand in its jar at the front of the table (`Z`);
  - bottle: tap the rack of bottles (`Enter`): serves it. Too soon only grumbles.
- Anything else spoils the brew: it goes murky, she rhymes about it, and it's tipped out.
- **Coins**: more for longer recipes, a tip for speed, a bonus for a run without spoiling. Each night needs so
  many coins before the moon crosses the window; miss it and the game is over (the score goes to the arcade).
- **Nights**: 1 has four jars and heat; 2 adds stirring and the Spider; 3 the wand and Moon Petal; 4 the last
  two jars, and potions already made once hide their recipes (the **Book** open on the table, `R`, has them all). From 5 on it gets
  busier. A pointing hand shows what to do for each kind of step until it's been done three times.
- Pause: the button top right (`Esc`/`P`): sound, back to the title.

## Layout

| | |
| --- | --- |
| `scripts/main.gd` | `Shop`: the nights, orders, the rules of the brew, scoring, talk, keys |
| `scripts/book.gd` | Ingredients, potions and recipes, customers, rhymes, how each night goes |
| `scripts/hud.gd` | The tickets, recipe strip, heat gauge, talk and cards; sends taps into the hut (`Shop.pick`) |
| `scripts/icons.gd` | The hand-drawn pictures on the controls |
| `scripts/hut.gd` | The hut, window and moon, the table and what's on it (each with a spot to tap), the cauldron, fire and particles |
| `art/make_models.py` | Builds every witch and prop in Blender (`art/*.blend`, `models/*.glb`); `art/preview.py` renders one |
| `scripts/witch.gd` | A witch on her skeleton: head, eyes, brows, mouth and IK arms posed each frame; Grumblewart on the stick, customers popping up, waiting, cheering or stomping off |
| `scripts/models.gd` | Loads a model and dresses it in the vertex-lit look |
| `scripts/shape.gd` | The look's materials, and code-built meshes for the room itself (stones, planks, window) |
| `scripts/sfx.gd` | Plays `sounds/*.res`; people talk in syllables |
| `shaders/` | Vertex-lit look, the brew's swirl, additive fire |
| `tools/render_sounds.gd` | Synthesises every sound and the music (no recorded samples) |
| `tests/` | `smoke.gd` plays it through, `shots.gd` takes pictures, `attract.gd` plays itself (preview film) |

## Commands

```
blender --background --python art/make_models.py -- <this folder> [witches|props]
blender --background art/<name>.blend --python art/preview.py -- <out.png>
godot --headless --path . -s tools/render_sounds.gd
godot --headless --path . --import
godot --headless --audio-driver Dummy --fixed-fps 60 --path . -s tests/smoke.gd
godot --audio-driver Dummy --path . -s tests/shots.gd -- --shots=<dir> [--wide] [--only=brewing]
godot --audio-driver Dummy --path . --fixed-fps 30 --write-movie out.avi -s tests/attract.gd -- --night=3 --seconds=17
godot --headless --path . --export-release "Web" build/index.html
```

For a landscape film, drop an `override.cfg` with `[display] window/size/window_width_override=1280` and
`window_height_override=720` in the folder first, and take it out after.
