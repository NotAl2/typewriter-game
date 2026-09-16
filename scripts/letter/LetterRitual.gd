extends Node
## The Correspondence Ritual: the whole letter, start to finish.
##
##   load a sheet → type it → (bell → throw the carriage) → (rare jam → clear it)
##   → wind it out OR throw the paper release → fold it → into the envelope
##   → melt the wax → pour it → press the rose
##
## Any page can also be abandoned at any moment: throw the release on unfinished
## work and it comes out as waste, to be crumpled and thrown in the basket.
##
## This is both the state machine and the authority on what the player is
## allowed to touch, because those are the same question. Every stage publishes
## a small set of live targets, which is why the player can never stamp an
## envelope with no wax on it or fold a page still gripped by the platen — not
## because those actions are checked and refused, but because they are not
## reachable.
##
## Hit testing is deliberately forgiving. A press first looks for a target the
## cursor is actually inside; failing that it takes the NEAREST live target
## within HIT_TOLERANCE. Exact-rect-only hit testing is why small props felt
## dead — a 13px lever plus a couple of pixels of camera parallax is a coin
## flip, and the player reads a missed grab as the game ignoring them.

enum Stage {
	IDLE,
	LOAD_PAPER,
	TYPING,
	JAMMED,
	PAGE_DONE,
	ROLL_OUT,
	SCRAP,
	FOLD,
	INSERT,
	SEAL_WAX,
	STAMP,
	MAIL_BAG,
	COMPLETE,
}

const STAGE_NAMES := ["idle", "load paper", "typing", "jammed", "page done",
	"roll out", "scrap", "fold", "insert", "seal", "stamp", "mail bag", "complete"]

## Prompts are diegetic and terse - the game never explains a control twice.
const STAGE_HINTS := {
	Stage.LOAD_PAPER: "take a sheet",
	Stage.TYPING: "",
	Stage.JAMMED: "the bars have locked",
	Stage.PAGE_DONE: "wind it out, or throw the release",
	Stage.ROLL_OUT: "draw the sheet out",
	Stage.SCRAP: "crush it. then the basket",
	Stage.FOLD: "fold it",
	Stage.INSERT: "into the envelope",
	Stage.SEAL_WAX: "the wax, the flame",
	Stage.STAMP: "press the seal",
	Stage.MAIL_BAG: "into the mail bag",
	Stage.COMPLETE: "",
}

## How far outside a target's rect a press still counts.
const HIT_TOLERANCE := 12.0
## How far the sheet must be drawn before it tears / comes free.
const TEAR_AT := 10.0
const FREE_AT := 8.0

enum Grab { NONE, STACK, KNOB, LEVER, RELEASE, JAM, PAGE_PULL,
	FOLD_LOWER, FOLD_UPPER, CARRY_LETTER, FLAP, WAX, STAMP,
	CRUSH, CARRY_BALL, CARRY_SEALED }

var stage: int = Stage.IDLE
var document: DocumentData
var result: RitualResult

# Untyped on purpose - these collaborators are built at runtime and this file
# reaches into their enums and members, which a Node2D annotation would hide.
var typewriter
var envelope
var kit
var source_letter
var sheet                              # the freed page, once it exists
var scrap                              # a ruined page, once it exists
var paper_stack: Sprite2D
var bin_sprite: Sprite2D

var sheets_spoiled := 0
var _started_ms := 0.0
var _sheet_layer: Node2D

var _grab: int = Grab.NONE
var _last_mouse := Vector2.ZERO
var _grab_start := Vector2.ZERO
var _pull_accum := 0.0

signal stage_entered(s: int)
signal completed(r: RitualResult)


func setup(tw, env, sealing, src, stack: Sprite2D, bin: Sprite2D,
		sheet_layer: Node2D, doc: DocumentData) -> void:
	typewriter = tw
	envelope = env
	kit = sealing
	source_letter = src
	paper_stack = stack
	bin_sprite = bin
	_sheet_layer = sheet_layer
	document = doc
	if typewriter.renderer != null:
		typewriter.renderer.document = doc

	GameEvents.jam_started.connect(func(_a: int, _b: int) -> void:
		if stage == Stage.TYPING:
			_set_stage(Stage.JAMMED))
	GameEvents.jam_cleared.connect(func(_c: int, _r: int) -> void:
		if stage == Stage.JAMMED:
			_set_stage(Stage.TYPING))
	envelope.flap_closed.connect(func() -> void:
		if stage == Stage.INSERT:
			_set_stage(Stage.SEAL_WAX))
	kit.seal_stamped.connect(func(_g: int, _s: float) -> void:
		if stage == Stage.STAMP:
			envelope.set_state(envelope.State.FLIPPED)
			if kit.has_method("hide_seal"):
				kit.hide_seal()
			_set_stage(Stage.MAIL_BAG))

	envelope.set_address(doc.address, doc.recipient)
	begin()


func begin() -> void:
	sheets_spoiled = 0
	_started_ms = float(Time.get_ticks_msec())
	envelope.position = Vector2(Layout.ENVELOPE_X, Layout.ENVELOPE_Y)
	envelope.set_state(envelope.State.CLOSED)
	_set_stage(Stage.LOAD_PAPER)


func _set_stage(s: int) -> void:
	if s == stage:
		return
	var from := stage
	stage = s
	typewriter.input_enabled = (s == Stage.TYPING)
	if s == Stage.INSERT:
		envelope.set_state(envelope.State.OPEN)
	GameEvents.stage_changed.emit(from, s)
	stage_entered.emit(s)


func hint() -> String:
	return String(STAGE_HINTS.get(stage, ""))


# --------------------------------------------------------------------------
# typing
# --------------------------------------------------------------------------

func handle_text(ch: String) -> void:
	if stage != Stage.TYPING:
		if stage == Stage.JAMMED:
			typewriter.type_char(ch)        # rejected, but the key still moves
		return
	typewriter.type_char(ch)
	_check_page_done()


func handle_backspace() -> void:
	if stage == Stage.TYPING:
		typewriter.back_space()


func handle_enter() -> void:
	if stage == Stage.TYPING and Settings.assist_carriage_return:
		typewriter.assisted_return()
		_check_page_done()


func _check_page_done() -> void:
	if stage != Stage.TYPING:
		return
	var rows: int = typewriter.carriage.rows_advanced
	if rows >= document.line_count() or rows >= Layout.ROWS:
		_set_stage(Stage.PAGE_DONE)


## The player can decide a page is finished early - the job is theirs to judge.
func declare_page_finished() -> void:
	if stage == Stage.TYPING:
		_set_stage(Stage.PAGE_DONE)


## Winding the platen from the results stage moves us into drawing the sheet
## out. Public so the wheel handler does not have to reach into the state.
func enter_roll_out() -> void:
	if stage == Stage.PAGE_DONE:
		_set_stage(Stage.ROLL_OUT)


# --------------------------------------------------------------------------
# targets
# --------------------------------------------------------------------------

func _t(r: Rect2, grab: int) -> Dictionary:
	return {"rect": r, "grab": grab}


## Everything the player may grab right now, most-important first.
func _targets() -> Array:
	var out: Array = []
	match stage:
		Stage.LOAD_PAPER:
			out.append(_t(_stack_rect(), Grab.STACK))
			if scrap != null and not scrap.is_done():
				_append_scrap_targets(out)

		Stage.TYPING, Stage.JAMMED:
			if stage == Stage.JAMMED:
				out.append(_t(typewriter.basket.jam_rect(), Grab.JAM))
			else:
				out.append(_t(typewriter.carriage.lever_rect(), Grab.LEVER))
			# the release is live during typing too: abandoning a page you have
			# ruined is a legitimate move, not an exploit
			out.append(_t(typewriter.carriage.release_rect(), Grab.RELEASE))

		Stage.PAGE_DONE, Stage.ROLL_OUT:
			out.append(_t(typewriter.carriage.release_rect(), Grab.RELEASE))
			if typewriter.carriage.paper_free_of_grip():
				out.append(_t(_paper_rect(), Grab.PAGE_PULL))
			if not typewriter.carriage.fully_wound():
				out.append(_t(typewriter.carriage.knob_rect(true), Grab.KNOB))
				out.append(_t(typewriter.carriage.knob_rect(false), Grab.KNOB))
			if not typewriter.carriage.paper_free_of_grip():
				out.append(_t(_paper_rect(), Grab.PAGE_PULL))

		Stage.SCRAP:
			_append_scrap_targets(out)

		Stage.FOLD:
			if sheet != null and sheet.can_fold():
				if sheet.fold == sheet.Fold.FLAT:
					out.append(_t(sheet.lower_rect(), Grab.FOLD_LOWER))
				else:
					out.append(_t(sheet.upper_rect(), Grab.FOLD_UPPER))

		Stage.INSERT:
			if envelope.state == envelope.State.STUFFED:
				out.append(_t(envelope.flap_rect(), Grab.FLAP))
			elif sheet != null:
				out.append(_t(sheet.rect(), Grab.CARRY_LETTER))

		Stage.SEAL_WAX, Stage.STAMP:
			if kit.pool_ready():
				out.append(_t(kit.stamp_rect(), Grab.STAMP))
			out.append(_t(kit.stick_rect(), Grab.WAX))
		Stage.MAIL_BAG:
			out.append(_t(envelope.body_rect(), Grab.CARRY_SEALED))
	return out


func _append_scrap_targets(out: Array) -> void:
	if scrap == null or scrap.is_done():
		return
	out.append(_t(scrap.rect(), Grab.CARRY_BALL if scrap.is_ball() else Grab.CRUSH))


static func _rect_distance(r: Rect2, p: Vector2) -> float:
	var dx: float = maxf(maxf(r.position.x - p.x, 0.0), p.x - r.end.x)
	var dy: float = maxf(maxf(r.position.y - p.y, 0.0), p.y - r.end.y)
	return sqrt(dx * dx + dy * dy)


## Nearest live target within tolerance, or an empty dictionary.
func target_at(pos: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var best_d := INF
	var tol := HIT_TOLERANCE + Settings.drag_assist
	for t: Dictionary in _targets():
		var d := _rect_distance(t["rect"], pos)
		if d > tol:
			continue
		# a direct hit always beats a near miss, whatever the ordering
		if d <= 0.0:
			return t
		if d < best_d:
			best_d = d
			best = t
	return best


# --------------------------------------------------------------------------
# mouse
# --------------------------------------------------------------------------

func mouse_pressed(pos: Vector2) -> void:
	_last_mouse = pos
	_grab_start = pos
	_grab = Grab.NONE
	_pull_accum = 0.0

	var t := target_at(pos)
	if t.is_empty():
		return
	var g: int = t["grab"]

	match g:
		Grab.STACK:
			_grab = g
		Grab.LEVER:
			if typewriter.begin_return_drag():
				_grab = g
		Grab.RELEASE:
			_throw_release()
		Grab.JAM:
			typewriter.basket.begin_jam_pull()
			_grab = g
		Grab.KNOB, Grab.PAGE_PULL:
			_grab = g
		Grab.FOLD_LOWER, Grab.FOLD_UPPER:
			sheet.begin_fold()
			_grab = g
		Grab.CARRY_LETTER:
			sheet.grab()
			_grab = g
		Grab.FLAP:
			envelope.begin_flap_pull()
			_grab = g
		Grab.WAX:
			kit.grab_stick()
			_grab = g
			if stage == Stage.STAMP:
				_set_stage(Stage.SEAL_WAX)
		Grab.STAMP:
			if kit.grab_stamp():
				_grab = g
				_set_stage(Stage.STAMP)
		Grab.CRUSH:
			scrap.begin_crush()
			_grab = g
		Grab.CARRY_BALL:
			scrap.grab_ball()
			_grab = g
		Grab.CARRY_SEALED:
			_grab = g


func mouse_moved(pos: Vector2) -> void:
	var d := pos - _last_mouse
	_last_mouse = pos
	match _grab:
		Grab.LEVER:
			typewriter.update_return_drag(d.x)
		Grab.JAM:
			typewriter.basket.update_jam_pull(d.y)
		Grab.KNOB:
			typewriter.carriage.roll(maxf(0.0, d.y) * 0.9)
			if stage == Stage.PAGE_DONE and typewriter.carriage.roll_px > 4.0:
				_set_stage(Stage.ROLL_OUT)
		Grab.PAGE_PULL:
			# accumulated pull, not per-frame velocity: how FAR you drew the
			# sheet is what decides whether it comes away or rips
			if d.y < 0.0:
				_pull_accum += -d.y
				_try_pull_page(_pull_accum)
		Grab.FOLD_LOWER:
			sheet.update_fold(-d.y)          # dragging up folds the bottom in
		Grab.FOLD_UPPER:
			sheet.update_fold(d.y)           # dragging down folds the top over
		Grab.CARRY_LETTER:
			sheet.carry_to(pos)
		Grab.FLAP:
			envelope.update_flap_pull(d.y)
		Grab.WAX:
			kit.move_stick(pos)
		Grab.STAMP:
			kit.move_stamp(pos)
		Grab.CARRY_BALL:
			scrap.carry_to(pos, get_process_delta_time())
		Grab.CARRY_SEALED:
			envelope.position = pos - Vector2(Layout.ENVELOPE_W/2, Layout.ENVELOPE_H/2)
			var bag_rect = Rect2(20, 90, 106, 80)
			if "mail_bag" in get_parent():
				get_parent().mail_bag.set_hovered(bag_rect.grow(HIT_TOLERANCE).has_point(pos))


func mouse_released(pos: Vector2) -> void:
	match _grab:
		Grab.STACK:
			# a sheet only goes in if it was actually carried to the platen
			if _platen_rect().grow(HIT_TOLERANCE).has_point(pos):
				_load_sheet()
		Grab.LEVER:
			if typewriter.end_return_drag():
				_check_page_done()
		Grab.JAM:
			typewriter.basket.end_jam_pull()
		Grab.FOLD_LOWER, Grab.FOLD_UPPER:
			sheet.end_fold()
			if sheet.fold == sheet.Fold.TWICE:
				_set_stage(Stage.INSERT)
		Grab.CARRY_LETTER:
			var at: Vector2 = sheet.release()
			if envelope.mouth_rect().grow(HIT_TOLERANCE).has_point(at):
				sheet.consume()
				envelope.accept_letter()
			else:
				sheet.return_to_rest()
		Grab.FLAP:
			envelope.end_flap_pull()
		Grab.WAX:
			kit.drop_stick()
		Grab.STAMP:
			kit.release_stamp()
		Grab.CRUSH:
			scrap.release_crush()
		Grab.CARRY_BALL:
			scrap.release_ball()
		Grab.CARRY_SEALED:
			if "mail_bag" in get_parent():
				get_parent().mail_bag.set_hovered(false)
			# Mail bag is now on the upper left wall
			var bag_rect = Rect2(20, 90, 106, 80)
			if bag_rect.grow(HIT_TOLERANCE).has_point(pos):
				Audio.play("paper_slide", 0.9, -2.0)
				envelope.visible = false
				_finish()
			else:
				envelope.position = Vector2(Layout.ENVELOPE_X, Layout.ENVELOPE_Y)
	_grab = Grab.NONE


func mouse_held(delta: float) -> void:
	match _grab:
		Grab.STAMP:
			kit.press_stamp(delta)
		Grab.CRUSH:
			scrap.hold_crush(delta)


# --------------------------------------------------------------------------
# paper handling
# --------------------------------------------------------------------------

func _stack_rect() -> Rect2:
	var pad := 4.0 + Settings.drag_assist
	return Rect2(Layout.PAPER_STACK_X - pad, Layout.PAPER_STACK_Y - pad,
				 92.0 + pad * 2.0, 34.0 + pad * 2.0)


func _platen_rect() -> Rect2:
	var c = typewriter.carriage
	return Rect2(c.position.x + 20.0, Layout.CARRIAGE_Y - 14.0,
				 Layout.CARRIAGE_W - 40.0, 60.0)


func _paper_rect() -> Rect2:
	var c = typewriter.carriage
	var off: float = c.paper_offset()
	var vh: float = minf(off, float(Layout.SHEET_H))
	# clipped to the screen: the grabbable area must be somewhere the player can
	# actually put the cursor, even when most of the sheet is above the frame
	var top: float = Layout.STRIKE_Y - off
	var visible_top: float = maxf(top, 0.0)
	var visible_h: float = maxf(8.0, top + vh - visible_top)
	return Rect2(c.position.x + (Layout.CARRIAGE_W - Layout.SHEET_W) / 2.0,
				 visible_top, float(Layout.SHEET_W), visible_h)


func bin_mouth() -> Vector2:
	return Vector2(Layout.BIN_X + Layout.BIN_MOUTH_OX,
				   Layout.BIN_Y + Layout.BIN_MOUTH_OY)


func _load_sheet() -> void:
	typewriter.load_paper()
	Audio.play("paper_feed", 1.0, -3.0)
	_set_stage(Stage.TYPING)


## Throwing the paper release lifts the rollers and the sheet comes straight
## out. This is the escape hatch: it works from any stage that has paper in the
## machine, so nobody has to wind a page all the way through to get at it.
func _throw_release() -> void:
	if not typewriter.paper_in:
		return
	if not typewriter.carriage.throw_release():
		return
	var finished: bool = typewriter.carriage.rows_advanced >= document.line_count() \
		or stage == Stage.PAGE_DONE or stage == Stage.ROLL_OUT
	if finished:
		_free_page()
	else:
		_scrap_page("ejected unfinished")


func _try_pull_page(pulled: float) -> void:
	var c = typewriter.carriage
	if not c.paper_free_of_grip():
		# still gripped by the platen - keep pulling and it rips
		if pulled > TEAR_AT:
			_tear_page()
		return
	if pulled > FREE_AT:
		_free_page()


func _tear_page() -> void:
	_grab = Grab.NONE
	Audio.play("paper_tear", 1.0, -1.0)
	GameEvents.shake_requested.emit(2.0)
	GameEvents.paper_torn.emit()
	_scrap_page("torn")


func _free_page() -> void:
	_grab = Grab.NONE
	var tex: Texture2D = await typewriter.take_paper()
	Audio.play("paper_slide", 1.0, -2.0)
	GameEvents.paper_freed.emit()

	sheet = preload("res://scripts/letter/PaperSheet.gd").new()
	_sheet_layer.add_child(sheet)
	sheet.build(tex, Vector2(Layout.TW_CX - Layout.SHEET_W / 2.0, 176.0))
	_set_stage(Stage.FOLD)


## Turn whatever is in the machine into waste the player has to deal with.
func _scrap_page(why: String) -> void:
	_grab = Grab.NONE
	sheets_spoiled += 1
	var tex: Texture2D = await typewriter.take_paper()
	if scrap != null and is_instance_valid(scrap):
		scrap.queue_free()
	scrap = preload("res://scripts/letter/ScrapPaper.gd").new()
	_sheet_layer.add_child(scrap)
	scrap.build(tex, Vector2(Layout.TW_CX - Layout.SHEET_W / 2.0, 176.0),
				bin_mouth(), why)
	scrap.landed.connect(_on_scrap_landed)
	GameEvents.paper_scrapped.emit(why)
	_set_stage(Stage.SCRAP)


func _on_scrap_landed(went_in: bool) -> void:
	if not went_in:
		return                              # it bounced out; pick it up again
	if is_instance_valid(scrap):
		scrap.queue_free()
	scrap = null
	if stage == Stage.SCRAP:
		_set_stage(Stage.LOAD_PAPER)


# --------------------------------------------------------------------------
# completion
# --------------------------------------------------------------------------

func _finish() -> void:
	var page: TypedPage = typewriter.page
	var scored := RitualResult.score_page(page, document, Layout.ROWS, Layout.COLS)

	result = RitualResult.new()
	result.document_title = document.title
	result.document_id = document.resource_path.get_file().get_basename()
	result.elapsed_seconds = (float(Time.get_ticks_msec()) - _started_ms) / 1000.0
	result.wpm = typewriter.wpm()
	result.accuracy = float(scored["accuracy"])
	result.chars_expected = int(scored["expected"])
	result.chars_correct = int(scored["correct"])
	result.chars_wrong = int(scored["wrong"])
	result.chars_missing = int(scored["missing"])
	result.chars_stray = int(scored["stray"])
	result.typos = scored["typos"]
	result.overstrikes = page.overstrike_count()
	result.smudges = page.smudges.size()
	result.sheets_spoiled = sheets_spoiled
	result.wax_sticks_spoiled = kit.sticks_spoiled
	result.wax_sticks_used = kit.sticks_used
	result.seal_grade = kit.seal_grade
	result.seal_score = kit.seal_score
	result.evaluate()

	_set_stage(Stage.COMPLETE)
	Audio.play("chime_complete", 1.0, -10.0)
	completed.emit(result)
	GameEvents.ritual_completed.emit(result)


# --------------------------------------------------------------------------
# affordances
# --------------------------------------------------------------------------

## What the player should reach for next. The overlay pulses this after an idle
## pause, which teaches the ritual without a single tutorial popup.
func target_rect() -> Rect2:
	if stage == Stage.TYPING and not typewriter.carriage.is_locked():
		return Rect2()
	var targets := _targets()
	if targets.is_empty():
		return Rect2()
	return targets[0]["rect"]
