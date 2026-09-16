# Asset manifest

Every PNG here is produced by `tools/gen_art.py` and is **drop-in replaceable**
by hand-drawn art at the same path and the same dimensions. Nothing in the game
measures a texture at runtime except where noted (frame counts are derived from
width / cell size, so an atlas may gain frames freely).

Regenerate everything:

```bash
python tools/gen_art.py            # sprites + fonts + scripts/Layout.gd
python tools/gen_audio.py          # all 29 sounds
python tools/gen_art.py --preview  # also writes _scene_*.png and _contact_sheet.png
```

**After regenerating, re-import before running the game:**

```bash
godot --headless --path . --import
```

Godot caches imported textures; a stale cache will silently show the previous
version of a sprite (this bit me once during development - the jam sprite kept
rendering at its old size).

## Where the numbers come from

`tools/layout.py` is the single source of geometry. It is imported by the art
generator **and** written out to `scripts/Layout.gd` for the game, so a sprite
and the code that positions it can never disagree. Change a constant there and
regenerate; do not edit `scripts/Layout.gd` by hand.

## Palette

`tools/palette.py`. A warm 1870s candlelit set - walnut, brass, candle gold,
cream paper, ink brown-black - read off the reference art. Light direction is
fixed: the candle is low and to the LEFT, so left-facing surfaces catch warm
light and right-facing surfaces fall into cool shadow. Keep to it or the room
stops reading as one painting.

## Fonts

`tools/gen_font.py` emits, for each face, a `.png` atlas, a `.json` metrics file
(used by `BitmapText.gd`) and an AngelCode `.fnt` (usable by Godot Labels).
Glyphs are authored as ASCII art in that file - editing a letterform means
editing a picture of it.

| Face | Cell | Advance | Used for |
|---|---|---|---|
| `type_5x7` | 5x7 | 6 | The typed page, the source letter, all UI |
| `tiny_3x5` | 3x5 | 4 | Keycap legends, the machine's nameplate |

`CHAR_ADV` in `layout.py` **must** equal the page face's advance. It sets the
line width, and therefore the carriage's travel distance.

## Sprites

| File | Size | Notes |
|---|---|---|
| `bg_room.png` | 640x360 | Full-screen backdrop: panelled wall, shelves, bookcase, window, curtain. |
| `bin.png` | 78x70 | Wicker wastepaper basket. Thrown balls land at BIN_MOUTH_O*. |
| `candlestick.png` | 44x74 | Chamberstick with candle. |
| `chair.png` | 172x84 | Foreground chair back, bottom-left. |
| `cursors.png` | 64x16 | 4 x 16x16: arrow, open hand, closed hand, pointing. |
| `desk.png` | 640x174 | Desk top + apron + drawer. Anchored at y=DESK_TOP_Y. |
| `dust.png` | 3x3 | 3x3 mote for the candle particles. |
| `envelope_closed.png` | 104x62 | Envelope, flap down. The address is drawn on top at runtime. |
| `envelope_open.png` | 104x88 | Envelope with the flap raised; extra height above ENVELOPE_H is the flap. |
| `flame.png` | 90x24 | 6-frame loop. Cell FLAME_W x FLAME_H; the wick is the bottom row. |
| `flame_glow.png` | 96x96 | Additive halo, centred on the flame. |
| `hands.png` | 696x96 | 3 poses (rest, left strike, right strike). GENERATED BUT NOT PLACED - see below. |
| `inkwell.png` | 30x30 | Glass inkwell. Scenery - see the desk table in RITUAL.md. |
| `journal.png` | 66x26 | Leather-bound day book. Scenery. |
| `letter_fold.png` | 104x130 | Flat letter prop (unused; PaperSheet re-uses the live page texture). |
| `letter_fold1.png` | 104x88 | One-fold prop (unused, same reason). |
| `letter_fold2.png` | 96x48 | Trifolded prop (unused, same reason). |
| `menu_letter.png` | 322x252 | The title screen. A note of engagement with the terms on it; MainMenu.gd draws the text and the pen marks at runtime. Carries a pressed rose seal. |
| `paper_ball.png` | 104x24 | Crumple animation, PAPER_BALL_FRAMES cells. Flat sheet -> tight ball. |
| `paper_sheet.png` | 144x200 | Blank sheet. Fills the page SubViewport exactly. |
| `paper_sheet_torn.png` | 144x200 | Ragged-top variant (unused; ScrapPaper crumples the live page instead). |
| `paper_stack.png` | 92x34 | The pile the player draws a fresh sheet from. |
| `photo_frame.png` | 74x104 | Gilt frame, sepia portrait. |
| `quill.png` | 56x44 | Goose quill. Drawn as a solid vane, not a fan of barb strokes: the stroke version read as a scalpel at this size. |
| `reading_sheet.png` | 272x210 | 2x stock for delivered replies and the hold-to-read close-up. |
| `seal_die.png` | 20x20 | The die face (rose in relief). Reference/UI use. |
| `seal_impressions.png` | 136x34 | 4 square frames: perfect, good, poor, smeared. |
| `seal_stamp.png` | 30x46 | Brass die with turned handle, side view. |
| `source_letter.png` | 136x105 | Blank stock for the letter being transcribed. Text is drawn on it at runtime. |
| `tw_basket.png` | 132x70 | Static fan of resting typebars. |
| `tw_body.png` | 252x148 | Machine frame. Open U: two arms + a transparent notch the carriage slides through. |
| `tw_carriage.png` | 210x48 | Carriage rail, paper table, bail, end plates. Slides horizontally. |
| `tw_keycaps.png` | 600x36 | Atlas: 40 keys x 2 states. Cell KEY_W x (KEY_H+3); row 0 up, row 1 down. |
| `tw_knob.png` | 208x26 | Platen end knob, 8 rotation frames, cell = height. |
| `tw_platen.png` | 176x26 | Rubber cylinder. Drawn in front of the sheet. |
| `tw_release_lever.png` | 44x16 | Paper release. 2 frames: engaged, thrown. Ejects the sheet without winding. |
| `tw_return_lever.png` | 52x13 | The carriage-return lever. Pivot right, grip left. |
| `tw_spacebar.png` | 120x11 | 2 frames (up, down), cell SPACEBAR_W x SPACEBAR_H. |
| `tw_typebar_jam.png` | 164x164 | Two bars crossed. Square; pivot row = canvas centre. |
| `tw_typebar_swing.png` | 816x136 | One bar, TYPEBAR_FRAMES square frames, rest -> struck. Pivot = frame centre. |
| `vignette.png` | 640x360 | Screen-space corner darkening overlay (premultiplied alpha). |
| `wax_box.png` | 34x22 | Box of spare sticks. Where a fresh one comes from. |
| `wax_pool.png` | 240x104 | 8 volume stages x 4 temperature rows. Cell WAX_POOL_W x WAX_POOL_H. |
| `wax_stick.png` | 44x46 | 4 frames: cold, soft, molten, scorched. Region is clipped from the BOTTOM as the stick burns down. |

## Deliberately unused

* **`hands.png`** — generated and ready (3 poses, atlas cell `HANDS_W x HANDS_H`),
  but not placed in the scene. The procedural version reads as brown lumps at
  this scale and merges with the brass die on the right of the desk. The cursor
  already *is* the player's hand — it opens and closes over grabbable things — so
  the first-person framing survives without them. To re-enable with hand-drawn
  frames, uncomment the three lines in `DeskScene._build_world()`.
* **`letter_fold*.png`** — `PaperSheet` folds the *live page texture* instead, so
  the player watches their own typing disappear into the packet. These flat props
  are kept for a future scene that needs a generic letter.
* **`paper_sheet_torn.png`** — for a spoiled-sheet prop on the desk, not yet built.

## Audio

`tools/gen_audio.py`, numpy-synthesized to 16-bit 44.1kHz mono WAV. Cohesive and
deliberately unobtrusive, but **placeholder-grade** next to real recordings.
Swapping in real samples is a file copy — same names, same directory.

The typewriter voice is layered the way the machine is: a broadband mechanism
tick, a bright slug-on-platen crack, and a low body thump. Six clack variants
exist so held-down typing never sounds looped, and `Audio.play_key()` adds pitch
and level jitter on top.

Loops (`room_tone`, `rain`, `candle_crackle`, `wax_sizzle`) are cross-faded end
to start so they seam cleanly.
