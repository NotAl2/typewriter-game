extends Node
## Signal bus.
##
## Systems talk through here rather than holding node references to each other,
## so the typewriter does not need to know the ritual exists, the ritual does not
## need to know the audio system exists, and any of them can be tested alone.

# --- typing ---------------------------------------------------------------

## A character was actually printed on the page.
signal glyph_struck(ch: String, col: int, row: int, overstruck: bool)
## A key was pressed but nothing printed (margin locked, or jammed).
signal key_rejected(ch: String, reason: String)
signal carriage_moved(col: int)
signal margin_bell_rang()
signal margin_locked()
signal carriage_returned(row: int)
signal line_fed(row: int)
signal page_finished()

# --- jamming --------------------------------------------------------------

signal jam_started(bar_a: int, bar_b: int)
signal jam_cleared(smudge_col: int, smudge_row: int)

# --- paper ----------------------------------------------------------------

signal paper_loaded()
signal paper_rolled(notches: int)
signal paper_released()
signal paper_freed()
signal paper_torn()
signal letter_folded(stage: int)
signal letter_inserted()
signal envelope_closed()

# --- scrapping ------------------------------------------------------------

## A sheet became waste: torn, or ejected before it was finished.
signal paper_scrapped(reason: String)
signal paper_crumpled()
signal paper_binned(went_in: bool)

# --- the run --------------------------------------------------------------

signal wax_stick_spent()
signal letter_sent(result: Resource)
signal reply_delivered(doc: Resource, tone: int)
signal run_failed(reason: String)
signal tutorial_advanced(step: int)

# --- wax and seal ---------------------------------------------------------

signal wax_heat_changed(heat: float)
signal wax_scorched()
signal wax_dripped(volume: float)
signal seal_pressed(grade: int, score: float)

# --- ritual ---------------------------------------------------------------

signal stage_changed(from_stage: int, to_stage: int)
signal ritual_completed(result: Resource)
signal hint_requested(target: String)

# --- presentation ---------------------------------------------------------

signal shake_requested(strength: float)
signal cursor_hint(kind: int)
