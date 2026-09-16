# The Correspondence Ritual

The game's core mechanic: producing one letter, end to end, with the player
performing every physical step.

```
load a sheet → type it → (bell → throw the carriage) → (rare jam → clear it)
   → wind it out OR throw the paper release → fold it → into the envelope
   → melt the wax → pour it → press the rose
   → the post brings a reply, and the reply depends on how good it was
```

Any page can be abandoned at any moment. Throw the paper release on unfinished
work and it comes out as waste: crush it in your fist and throw it in the
basket.

Nothing in that chain is automated and nothing is a button. Every step is a
deliberate drag or keystroke, because the design document (§19) is explicit that
*the typing is how the player experiences the story* — the ritual has to be worth
performing several hundred times.

---

## Controls

| Action | Input |
|---|---|
| Type | Any printable key |
| Run the carriage back one column | `Backspace` |
| Finish the page early | `Tab` |
| Carriage return | **Drag the lever left→right** (or `Enter` if the assist is on) |
| Read the source letter close up | Hold **right mouse** on it |
| Turn the platen | Drag a knob down, or the scroll wheel |
| Everything else | Left-click and drag the object |
| Eject the sheet immediately | Click the **paper release** on the right of the carriage |
| Crush a ruined page | Click and **hold** it |
| Throw it away | Drag the ball and flick it at the basket |
| Dismiss the guide | `F1` |
| Restart / back to menu | `F5` · `Esc` |
| Screenshot to `user://shots/` | `F9` |

### There is no erase

`Backspace` moves the carriage back a column and prints nothing. Strike a
character there and it lands **on top of** what is already inked, leaving a
permanent scar. The only correction available is the one a period typist had:
back up and overstrike with `x`.

This is the mechanic the whole story turns on — the game's inciting incident is
a single mistyped address that could not be taken back — so it is not a
difficulty setting.

---

## The steps

### 1. Load a sheet
Drag a sheet from the stack to the platen. The paper feeds in with a ratchet.

### 2. Type
Each keystroke: the keycap dips, a typebar swings and strikes, ink lands with a
randomized vertical offset and density, and the carriage slips one column left.
Strike hard (fast) and the slug bites deeper.

### 3. The bell and the margin
At column `BELL_COL` a bell rings. At column `COLS` the carriage **locks** —
further keys produce a dead thunk and print nothing.

### 4. Throw the carriage
The carriage travels right→left as you type, so returning it means shoving it
back to the **right**. The lever sits on the carriage's left end and the drag
runs left→right. It is proportional, not a button: the first ~10px trips the
line-feed ratchet, the rest carries the carriage, and releasing before ~72% of
the sweep springs it back with the line feed already made.

You can throw the carriage from column 0 — that is how blank lines happen.

### 5. Jams
A clash needs **two conditions**, not a dice roll: two strikes inside ~55ms of
each other *and* two typebars that are near neighbours in the basket. Likelihood
scales with typing speed. It cannot happen in the opening strikes of a page and
cannot chain.

When it happens, two bars freeze crossed against the platen and all typing is
dead. Click them and **drag downward** to pull them apart. They come away inked,
and that ink lands on the page as a permanent smudge.

### 6. Getting it out — two ways
**Wind it.** Turn a knob until the sheet clears the platen's grip, then draw it
out. Pull before it is clear and it **tears**.

**Or throw the paper release.** Real machines have one: it lifts the feed
rollers off the platen so a sheet comes straight out. It works from any stage
with paper in the machine, so nobody has to wind a page all the way through
just to get at it.

The platen is hard-clamped at `MAX_PAPER_OFFSET`. Winding past the end of the
sheet does nothing — without that clamp the wheel scrolls the page off the top
of the screen, and since the pull-it-free hitbox *is* the sheet, the run
softlocks with nothing left to click.

### 6b. Waste
A torn page, or one ejected before it was finished, becomes waste on the desk.

* **Crush it** — click and hold. It crumples frame by frame under the pressure.
* **Throw it** — drag the ball and flick. It flies on a real arc. Miss and it
  lands on the desk, where you can pick it up and try again.

Binning it clears the desk and you start a fresh sheet. Every spoiled sheet is
counted against the job.

### 7. Trifold
Drag the lower half up, then the upper half down. The page keeps its own typed
texture through both folds, so the player watches their own typos disappear into
the packet.

### 8. Envelope
Drag the folded letter into the mouth, then drag the flap down.

### 9. Wax
Drag the stick into the flame and hold. It softens, then runs molten, then — if
you hold too long — **scorches black** and you take a fresh stick.

**The flame eats the stick.** It burns down as it melts (fastest while
scorching, slower while merely molten) and pouring consumes it too. Left in the
fire it is used up entirely and a fresh one comes out of the box. The tip creeps
back toward your hand as it shortens, so a nearly spent stick has to be held
lower to reach the flame.

Carry the molten stick over the flap junction and hold to pour; the pool grows
through eight stages.

### 10. Press the rose
The pool starts cooling the moment it lands. Press the brass die too hot and the
rose **smears**; too cold and only half of it takes. There is a window, and
finding it is the skill.

The die carries a rose, per §10 of the design document — so every letter the
player sends goes out marked with one, long before the rose starts meaning
anything.

---

## Judging, and what comes back

Every finished letter is judged (`RitualResult.evaluate`). There is **no address
fault** — the address is pre-printed on the envelope in the client's hand, so it
is not something the player can get wrong at the keys.

A letter is unsatisfactory if any of these is true:

| Fault | Threshold |
|---|---|
| Characters wrong | accuracy below `ACCURACY_FLOOR` (92%) |
| Ink smudges from jams | **any** smudge at all |
| Overstruck corrections | more than `OVERSTRIKE_LIMIT` (3) |
| The wax seal | graded Poor or Ruined |

### Three kinds of character error

They are counted and reported separately, because they mean different things to
whoever reads the letter, and telling a player "39 characters wrong" when most
of them were never typed at all tells them nothing they can act on.

| Kind | What happened | Named as |
|---|---|---|
| **mistyped** | you struck a different character | "4 characters mistyped" |
| **missing** | the source had a character, you typed nothing | "9 characters missing" |
| **stray** | you typed something the source never had | "2 characters that were never in my letter" |

A page abandoned half-typed is overwhelmingly *missing*, and says so:
"128 characters missing - the letter is unfinished".

**Trailing spaces are not content.** Each line is compared only as far as either
side actually has something on it, so tapping the space bar before throwing the
carriage — or not tapping it — is never an error either way.

Smudges count from the first one, because a jam leaves permanent ink on a letter
somebody is going to read — and the player always has the option of scrapping
the page and retyping it. That is what the basket is for.

The reply that arrives in the next post is written by **the client**, reacting to
how their letter was received at the other end. That framing is what gives the
anger somewhere to go: it is not that you typed badly, it is that a man's name
went out into the world on a page you smudged, and other people read it.

```
satisfactory   → WARM      ordinary, pleased, business as usual
1 poor letter  → COOL      plain, disappointed, a warning
2 poor         → HOSTILE   "twice, now"
over tolerance → RAGE      you are read aloud at table. The run ends.
```

The faults you actually committed are quoted verbatim into the body, so a reply
can never accuse you of something you did not do.

### Difficulty

Chosen in the start menu, which is itself a letter: a note of engagement from
Mr Hallow, with the terms laid out as a list you mark up before sitting down.
A menu drawn as a UI panel would sit on top of the fiction; one written on a
sheet of paper is the fiction. It also settles the contrast problem, because
dark ink on bright paper is the most readable surface in the game.

Difficulty changes only how many poor letters you may send before the rage
letter arrives — the writing and the judging are identical.

| Mode | Tolerance | Meaning |
|---|---|---|
| **LENIENT** | 2 | two warnings — cool, then hostile |
| **STANDARD** | 1 | one warning, then dismissal |
| **UNFORGIVING** | 0 | the very first poor letter ends the run |

The rage letter is delivered and **read on the desk** before the dismissal card
appears. The failure state is a piece of writing; cutting straight to a card
would throw it away.

---

## The guide

A first-run tutorial (toggleable in the menu) points at each object in turn and
waits for you to use it. It never gates anything.

**The card shown is derived from the ritual's current stage**, never from a
counter of steps completed. An earlier version advanced an index on events,
which desynchronised the moment anything went sideways: scrap a page and the
ritual dropped back to *load paper* while the guide sat on *fold*, so the
folding card and the crumpling card took turns while the ring pointed at the
paper stack. Reading the stage makes that class of bug impossible, and there is
a test (`_tutorial_follows_the_stage`) that walks the stages out of order and
requires the card to match.

Each stage's card appears the first time you reach that stage and retires when
you leave it, so the guide fades out as you learn rather than nagging on every
repeat. Things that cannot be scheduled — an overstrike, the margin bell, a torn
sheet, a burnt-away wax stick — appear as short timed *notes* on top. `F1`
dismisses the whole guide.

---

## The desk

Objects the ritual uses are taught by the guide and ringed by the affordance
pulse. Everything else is scenery, and resting the cursor on it for a moment
says so in as many words (`PropLabels.gd`):

| Object | Purpose |
|---|---|
| Paper stack, basket, candle, wax box | Used by the ritual |
| **Inkwell** | Scenery. For the pen, not the machine |
| **Quill** | Scenery. For signing and for the day book |
| **Day book** | Scenery. Where the day's jobs would be entered |
| **Portrait** | Story. Eleanor, 1879 |

The inkwell, quill and day book are deliberate hooks for the investigation
systems in §20 of the design document — signing off work, and a ledger of who
sent what — but nothing reads or writes them yet, and the captions say so rather
than letting a player hunt for a control that is not there.

---

## Tuning

All geometry lives in `tools/layout.py` and is generated into `scripts/Layout.gd`
so the art and the code cannot disagree. Regenerate with `python tools/gen_art.py`.

| Constant | Where | Meaning |
|---|---|---|
| `COLS` / `CHAR_ADV` | `layout.py` | Line width; drives carriage travel and sheet width |
| `ROWS` / `LINE_H` | `layout.py` | Lines per sheet |
| `BELL_COL` | `layout.py` | Where the margin bell rings |
| `CLASH_WINDOW_MS` | `JamController.gd` | How close two strikes must be to foul |
| `NEIGHBOUR_SPAN` | `JamController.gd` | How near in the basket two bars must be |
| `BASE_CHANCE` / `SPEED_CHANCE` | `JamController.gd` | Jam likelihood, flat and speed-scaled |
| `RETURN_COMMIT` | `Carriage.gd` | Fraction of the sweep that counts as a return |
| `GRIP_RELEASE` | `Carriage.gd` | How far the sheet must roll before it can be pulled |
| `TEAR_AT` / `FREE_AT` | `LetterRitual.gd` | Pull distance to tear / to free |
| `HIT_TOLERANCE` | `LetterRitual.gd` | How far outside a target a press still counts |
| `MAX_PAPER_OVERSHOOT` | `layout.py` | How far past the sheet the platen will wind |
| `CRUSH_TIME` / `AIM_ASSIST` | `ScrapPaper.gd` | Crumple duration; basket forgiveness |
| `HEAT_RATE` / `COOL_RATE` | `SealingKit.gd` | Wax thermodynamics |
| `BURN_RATE` / `MELT_RATE` / `POUR_COST` | `SealingKit.gd` | How fast the stick is consumed |
| `ACCURACY_FLOOR` / `SMUDGE_LIMIT` / `OVERSTRIKE_LIMIT` | `RitualScoring.gd` | What makes a letter unsatisfactory |
| `TOLERANCE` | `RunState.gd` | Poor letters allowed per difficulty |
| `MOLTEN_AT` / `SCORCH_AT` | `SealingKit.gd` | Stick state thresholds |
| `POOL_COOL_RATE` | `SealingKit.gd` | The stamping window |
| `TEMP_IDEAL_LO/HI` | `SealingKit.gd` | The band that yields a crisp rose |

## Settings

`scripts/autoload/Settings.gd`, persisted to `user://settings.cfg`.

| Flag | Default | Effect |
|---|---|---|
| `assist_carriage_return` | off | `Enter` performs the return instead of the lever drag |
| `jam_rate_scale` | 1.0 | Scales jam frequency; `0.0` disables jams |
| `drag_assist` | 0.0 | Grows every draggable's hit area |
| `reduced_shake` | off | Suppresses the camera kicks |
| `uppercase_only` | off | **Historical**: Remington No. 1 had no shift key |
| `blind_write` | off | **Historical**: the No. 1 struck the *underside* of the platen |

### The blind-writer flag

The Remington No. 1 was a blind-writer — the type hit the underside of the
platen, so the typist could not see a word until they rolled the paper up.
`PageRenderer` keeps *committed* and *revealed* as separate concepts precisely so
this stays a one-flag change.

It is the highest-value horror hook in the codebase. Later in the game, what
appears on the page when you roll it up need not be what you typed.

---

## Architecture

```
LetterRitual ──── owns the stage machine AND decides what is interactive
   │              (those are the same question, so they live together)
   ├── Typewriter ── Carriage (platen, paper, knobs, return lever)
   │                 Keyboard (keycap dip / reject shudder)
   │                 TypebarBasket (swing, jam, drag-to-clear)
   │                 JamController (pure logic, no nodes)
   │                 TypedPage → PageRenderer (SubViewport)
   ├── Envelope (carries the pre-printed address)
   ├── SealingKit (stick heat + length, pool volume+temp, die press)
   ├── PaperSheet (created when the page is freed)
   └── ScrapPaper (created when a page is ruined: crush, throw, bin)

RunState ──── the campaign: difficulty, strikes, which letter is next
   └── ReplyWriter ── composes the reply in the tone the run has earned

DeskScene phases:
   MENU → PLAYING → RESULTS → READING → (next letter | GAME_OVER)
```

Cross-system messages go through the `GameEvents` signal bus; no system holds a
node path into another.

**Why the page renders into a SubViewport:** it makes the finished sheet a real
texture, so it survives being pulled out of the machine, folded, and posted — and
it can be filed as evidence for the investigation acts later. It also gives
per-glyph control a `Label` cannot.

**Why the scene is built in code:** every position comes from `Layout.gd`, which
is generated from the same file the art generator draws with. Laying sprites out
by hand in a `.tscn` would fork those numbers.

**Draw order is load-bearing.** Back to front: paper → carriage frame → platen →
typebars → body → keycaps. The sheet rests *against* the paper table, so the table
goes behind it; the platen goes in front of the sheet's bottom edge. Get this
wrong and the line the player just typed vanishes behind the carriage.

---

## Verifying

```bash
python tools/gen_art.py && python tools/gen_audio.py
godot --headless --path . --import
godot --headless --path . --fixed-fps 120 -- --test-ritual
```

`tests/RitualHarness.gd` drives the real scene through every stage with no
player — including the deliberate failure paths (margin lock, a forced jam, a
torn sheet, a scorched and a fully consumed wax stick, a thrown ball that misses
the basket) — and asserts **83 conditions**, among them:

* the platen clamps and the wound-out sheet is still grabbable (the softlock);
* a press a few pixels *outside* a small prop still grabs it;
* the paper release ejects a finished page straight to folding;
* smudges, overstrikes and spoiled sheets all reach the scored result;
* every difficulty ends the run after exactly its tolerance of poor letters;
* the rage letter names the faults that were actually committed. It is an
integration test on purpose: almost every bug worth catching in this mechanic
lives in the seams between stages.

Add `--capture-shots` and run windowed to write a frame per stage to
`user://shots/`.

> **After regenerating art, always re-import** (`--headless --import`) before
> running. Godot caches imported textures, and a stale cache will silently show
> you the previous version of a sprite.
