"""Scene geometry shared between the art generator and the game.

Every number the art and the mechanic BOTH need lives here exactly once.
`gen_art.py` writes these out to `scripts/Layout.gd` as well, so the sprites and
the code that moves them can never disagree about where the platen is.

Coordinate space is the 640x360 base viewport, y down.

The typing geometry is the load-bearing part:

  * A column is CHAR_ADV px wide, matching the 5x7 font's advance.
  * The carriage slides LEFT one column per keystroke, so the next blank column
    always arrives under the fixed strike point at (STRIKE_X, STRIKE_Y).
  * The paper rides with the carriage, and rolls UP one LINE_H per line feed.

Change COLS or CHAR_ADV and the carriage travel, sheet width and margins all
follow from them - nothing else needs touching.
"""

# --------------------------------------------------------------------------
# viewport
# --------------------------------------------------------------------------

VIEW_W = 640
VIEW_H = 360

# --------------------------------------------------------------------------
# room / desk
# --------------------------------------------------------------------------

DESK_TOP_Y = 186          # back edge of the desk surface
DESK_H = VIEW_H - DESK_TOP_Y

# --------------------------------------------------------------------------
# typing metrics  (these drive everything else)
# --------------------------------------------------------------------------

COLS = 20                 # characters per line before the carriage locks
CHAR_ADV = 6              # px per column - must equal the font advance
LINE_H = 9                # px per line feed
ROWS = 16                 # lines per sheet
BELL_COL = 15             # margin bell rings on reaching this column

CARRIAGE_TRAVEL = COLS * CHAR_ADV        # 120

# --------------------------------------------------------------------------
# paper
# --------------------------------------------------------------------------

SHEET_W = 144
SHEET_H = 200
PAGE_MARGIN_X = 12                        # left margin on the sheet
PAGE_MARGIN_TOP = 40                      # how much sheet shows before line 0

assert PAGE_MARGIN_X * 2 + COLS * CHAR_ADV == SHEET_W, "sheet width must fit the text block"
assert PAGE_MARGIN_TOP + ROWS * LINE_H <= SHEET_H, "text block overruns the sheet"

# --------------------------------------------------------------------------
# typewriter
# --------------------------------------------------------------------------

TW_CX = 320               # centre line of the machine
TW_BASE_Y = 304           # where the machine meets the desk

TW_BODY_W = 252
TW_BODY_H = 148
TW_BODY_X = TW_CX - TW_BODY_W // 2        # 194
TW_BODY_Y = TW_BASE_Y - TW_BODY_H         # 156

# the frame is an open U: two tall side arms carrying the ribbon spools and the
# carriage rail, with a notch between them that the carriage slides through.
TW_NOTCH_X0 = 30                          # local to the body sprite
TW_NOTCH_X1 = TW_BODY_W - 30
TW_NOTCH_H = 42
TW_SPOOL_R = 11

# the fixed point where a typebar meets the platen and a glyph appears
STRIKE_X = TW_CX
STRIKE_Y = 172

# carriage assembly (slides horizontally; the platen and paper are its children)
CARRIAGE_W = 210
CARRIAGE_H = 48
CARRIAGE_Y = 154
# x of the carriage sprite's left edge when the machine is at column 0
CARRIAGE_HOME_X = STRIKE_X - PAGE_MARGIN_X + SHEET_W // 2 - CARRIAGE_W // 2   # 275

PLATEN_W = 176
PLATEN_H = 26
PLATEN_Y = 173           # sits just under the strike line, never over it
PLATEN_INSET_X = (CARRIAGE_W - PLATEN_W) // 2

KNOB_R = 11               # platen end knobs

# The paper release lever. Real machines have one: it lifts the feed rollers off
# the platen so a sheet can be pulled straight out without winding it all the way
# through. It is the escape hatch from the roll-out step - and from a page you
# have decided to abandon.
RELEASE_LEVER_W = 22
RELEASE_LEVER_H = 16
RELEASE_LEVER_OX = CARRIAGE_W - 4     # relative to the carriage sprite's left edge
RELEASE_LEVER_OY = 4

# Hard ceiling on how far the platen will wind a sheet. Without it the wheel
# scrolls the page infinitely off the top of the screen, and because the
# pull-it-free hitbox IS the sheet, the run softlocks with nothing to click.
MAX_PAPER_OVERSHOOT = 24

# The carriage travels right-to-left as you type, so returning it means shoving
# it back to the RIGHT. The lever is mounted on the carriage's LEFT end with its
# grip furthest left, and the player's drag gesture runs left-to-right.
RETURN_LEVER_W = 52
RETURN_LEVER_H = 13
RETURN_LEVER_OX = -34     # relative to the carriage sprite's left edge
RETURN_LEVER_OY = -8

# --------------------------------------------------------------------------
# keyboard  (4 arced rows on the front deck)
# --------------------------------------------------------------------------

KEY_W = 15
KEY_H = 15
KEY_SPACING_X = 17
KEY_SPACING_Y = 14
KEYBOARD_TOP_Y = 232
SPACEBAR_Y = 290
SPACEBAR_W = 60
SPACEBAR_H = 11
KEY_ROW_ARC = 3           # px each row bows downward at its edges

# visual QWERTY rows, purely for the keycap animation
KEY_ROWS = [
    "1234567890",
    "QWERTYUIOP",
    "ASDFGHJKL;",
    "ZXCVBNM,.?",
]

# --------------------------------------------------------------------------
# typebar basket
# --------------------------------------------------------------------------

BASKET_CX = TW_CX
BASKET_PIVOT_Y = 232      # where the bars hinge
BASKET_W = 132
BASKET_H = 70
TYPEBAR_LEN = 62          # pivot to type slug
TYPEBAR_FRAMES = 6        # rest -> struck

# --------------------------------------------------------------------------
# desk props  (top-left anchor of each sprite)
# --------------------------------------------------------------------------

CANDLE_W = 44
CANDLE_H = 74
CANDLE_X = 142
CANDLE_Y = 182            # top of the candlestick sprite

# The flame sits on the candle's wick, not floating above it: the sprite is 24
# tall with its wick on the bottom row, so its top is (wick - 23).
FLAME_W = 15
FLAME_H = 24
FLAME_X = CANDLE_X + CANDLE_W // 2 - FLAME_W // 2      # 157
FLAME_Y = CANDLE_Y - FLAME_H + 7                       # 165
FLAME_CX = FLAME_X + FLAME_W // 2                      # 164
FLAME_CY = FLAME_Y + 13                                # 178
FLAME_HEAT_R = 18         # radius within which wax melts

PHOTO_X = 558
PHOTO_Y = 148

INKWELL_X = 598
INKWELL_Y = 318

PAPER_STACK_X = 30
PAPER_STACK_Y = 246

# The source letter is rendered with fully legible 5x7 text at runtime, sized to
# hold exactly one line of the document (COLS characters) plus margins. Making
# it readable in place is what removes the need for any floating transcript UI.
SOURCE_LETTER_MARGIN = 8
SOURCE_LETTER_W = COLS * CHAR_ADV + SOURCE_LETTER_MARGIN * 2      # 136
SOURCE_LETTER_ROWS = 9
SOURCE_LETTER_H = SOURCE_LETTER_ROWS * LINE_H + SOURCE_LETTER_MARGIN * 2 + 8
SOURCE_LETTER_X = 470
SOURCE_LETTER_Y = 202

QUILL_X = 522
QUILL_Y = 330

JOURNAL_X = 300
JOURNAL_Y = 196

# Front row of the desk, left to right: chair, bin, envelope, wax, machine base,
# seal die. Nothing the player has to grab may sit under the chair or the hands.
CHAIR_X = -90
CHAIR_Y = 318
CHAIR_W = 172

# Wastepaper basket. Every ruined sheet ends up crumpled and thrown in here, so
# it has to be a large, obvious, always-reachable target.
BIN_X = 34
BIN_Y = 290
BIN_W = 78
BIN_H = 70
# where a thrown ball lands, relative to the bin sprite
BIN_MOUTH_OX = BIN_W // 2
BIN_MOUTH_OY = 12

PAPER_BALL_W = 26
PAPER_BALL_H = 24
PAPER_BALL_FRAMES = 4      # flat sheet -> fully crumpled

ENVELOPE_X = 150
ENVELOPE_Y = 294
ENVELOPE_W = 104
ENVELOPE_H = 62

# The wax lives on the free desk at the RIGHT, clear of the machine's footprint
# and of the drawer pull. It is a long drag to the candle, but it is one drag,
# and the alternative was wedging it under the machine where it was hard to hit.
WAX_STICK_X = 500
WAX_STICK_Y = 312
WAX_STICK_W = 11
WAX_STICK_H = 46
# Wax burns away as it melts. Below this the stick is spent and a fresh one is
# taken from the box.
WAX_STICK_MIN_LEN = 12

SEAL_STAMP_X = 392
SEAL_STAMP_Y = 302
SEAL_STAMP_W = 30
SEAL_STAMP_H = 46

# where the wax pool forms on a sealed envelope, relative to the envelope sprite
WAX_POOL_OX = ENVELOPE_W // 2
WAX_POOL_OY = ENVELOPE_H // 2 + 2
WAX_POOL_W = 30
WAX_POOL_H = 26
WAX_POOL_STAGES = 8

WAX_BOX_X = 456
WAX_BOX_Y = 322

# --------------------------------------------------------------------------
# the title letter
#
# The start menu is a sheet of paper on the desk rather than a UI panel: the
# player marks up terms of engagement before sitting down. These are the sheet's
# own coordinates; MainMenu.gd lays its text out against them.
# --------------------------------------------------------------------------

MENU_LETTER_W = 322
MENU_LETTER_H = 252
MENU_LETTER_X = (VIEW_W - MENU_LETTER_W) // 2
MENU_LETTER_Y = 50
MENU_MARGIN = 26
MENU_RULE_TOP = 46
MENU_RULE_BOTTOM = 206
MENU_SEAL_X = 46
MENU_SEAL_Y = 222
MENU_ROW_H = 15

# Hands sit low on the desk in front of the machine. Deliberately NOT over the
# keyboard (that would hide the per-key dip animation) and drawn BEFORE the
# envelope and the sealing kit, so they can never cover something the player has
# to reach for.
HANDS_W = 232
HANDS_H = 96
HANDS_X = TW_CX - HANDS_W // 2
HANDS_Y = 262


def as_gdscript():
    """Emit the same constants as a GDScript class so the game reads one truth."""
    import types

    lines = [
        "# AUTO-GENERATED by tools/gen_art.py from tools/layout.py - do not edit.",
        "#",
        "# Scene geometry shared by the art generator and the game. Regenerate with:",
        "#   python tools/gen_art.py",
        "class_name Layout",
        "extends RefCounted",
        "",
    ]
    g = globals()
    for name in sorted(k for k in g if k.isupper()):
        v = g[name]
        if isinstance(v, types.ModuleType):
            continue
        if isinstance(v, bool):
            lines.append("const %s := %s" % (name, "true" if v else "false"))
        elif isinstance(v, int):
            lines.append("const %s := %d" % (name, v))
        elif isinstance(v, float):
            lines.append("const %s := %f" % (name, v))
        elif isinstance(v, str):
            lines.append('const %s := "%s"' % (name, v))
        elif isinstance(v, list) and all(isinstance(x, str) for x in v):
            body = ", ".join('"%s"' % x for x in v)
            lines.append("const %s := [%s]" % (name, body))
    return "\n".join(lines) + "\n"
