extends Node2D
## A first-run guide through the whole ritual.
##
## It teaches by pointing, not by explaining: each card names the thing to do in
## a few words and rings the object you should reach for. Nothing is gated — you
## can ignore a prompt entirely and carry on.
##
## The card shown is derived from the ritual's CURRENT STAGE, never from a
## counter of steps completed. An earlier version advanced an index on events,
## which desynchronised the moment anything went sideways: scrap a page and the
## ritual dropped back to "load paper" while the guide sat on "fold", so the
## folding card and the crumpling card took turns while the ring pointed at the
## paper stack. Reading the stage makes that class of bug impossible.
##
## Each stage's card is shown once — the first time you reach that stage — and
## retires when you leave it, so the guide fades out as you learn rather than
## nagging on every repeat.
##
## Things that cannot be scheduled (an overstrike, the margin bell, a torn
## sheet) appear as short timed NOTES on top of whatever card is showing.

const CARD_W := 220
const NOTE_TIME := 7.0
const PAPER := Color(0.898, 0.855, 0.749, 0.75)
const NOTE_PAPER := Color(0.949, 0.886, 0.741, 0.85)
const EDGE := Color(0.42, 0.34, 0.26, 0.9)
const INK := Color(0.145, 0.106, 0.078)
const RING := Color(1.0, 0.855, 0.545)


class Step:
	var title: String
	var body: PackedStringArray
	func _init(t: String, b: Array) -> void:
		title = t
		body = PackedStringArray(b)


var ritual
var typewriter

var _font: BitmapText
var _stage_steps: Dictionary = {}     # Stage -> Step
var _seen: Dictionary = {}            # Stage -> true, once left behind
var _note: Step = null
var _note_time := 0.0
var _last_stage := -1
var _shown := 0.0
var _pulse := 0.0
var _active := true

signal finished()


func build(font: BitmapText, r, tw) -> void:
	_font = font
	ritual = r
	typewriter = tw
	z_index = 40
	_build_steps()
	_connect_notes()
	_last_stage = ritual.stage


func _build_steps() -> void:
	var S = ritual.Stage
	_stage_steps = {
		S.LOAD_PAPER: Step.new("A SHEET", [
			"Drag a sheet from the pile",
			"into the machine.",
		]),
		S.TYPING: Step.new("TYPE IT", [
			"Follow the faint ghost letters",
			"on the paper. Any mistakes",
			"will appear in red.",
			"",
			"A bell warns you near the",
			"right margin. At the margin",
			"the carriage LOCKS.",
			"",
			"Then grab the lever on the",
			"carriage's left and sweep it",
			"RIGHT to feed a line.",
		]),
		S.JAMMED: Step.new("JAMMED", [
			"Two typebars have locked",
			"against the platen.",
			"",
			"Click them and drag DOWN to",
			"pull them apart.",
			"",
			"They come away inked, and",
			"that ink stays on the page.",
		]),
		S.PAGE_DONE: Step.new("GET IT OUT", [
			"Two ways.",
			"",
			"Wind a knob until the sheet",
			"is clear, then draw it out.",
			"",
			"Or throw the paper release on",
			"the carriage's right and it",
			"comes straight out.",
		]),
		S.ROLL_OUT: Step.new("DRAW IT OUT", [
			"Drag the sheet upward.",
			"",
			"Pull before the platen has",
			"let go and it TEARS.",
		]),
		S.SCRAP: Step.new("WASTE", [
			"This sheet is spoiled.",
			"",
			"Hold it down until it is a",
			"ball, then drag it and flick",
			"it at the basket.",
			"",
			"Miss and you can pick it up",
			"and try again.",
		]),
		S.FOLD: Step.new("FOLD", [
			"Drag the lower half UP.",
			"Then the upper half DOWN.",
		]),
		S.INSERT: Step.new("ENVELOPE", [
			"Carry the letter to the",
			"envelope, then drag the flap",
			"shut.",
			"",
			"The address is already",
			"written on it - that is not",
			"yours to get wrong.",
		]),
		S.SEAL_WAX: Step.new("WAX", [
			"Hold the stick in the flame.",
			"",
			"Too brief and nothing drips.",
			"Too long and it scorches - and",
			"the flame eats the stick, so",
			"it will not last forever.",
			"",
			"Then hold it over the flap.",
		]),
		S.STAMP: Step.new("THE SEAL", [
			"The wax cools the moment it",
			"lands. Press the die too hot",
			"and the rose smears; too cold",
			"and only half of it takes.",
			"",
			"Find the moment between.",
		]),
		S.MAIL_BAG: Step.new("POST IT", [
			"The letter is sealed.",
			"",
			"Drag the envelope to the",
			"mail bag to send it.",
		]),
	}


func _connect_notes() -> void:
	GameEvents.glyph_struck.connect(func(_c: String, _co: int, _r: int, over: bool) -> void:
		if over:
			_show_note("NO ERASING", [
				"This machine cannot erase.",
				"",
				"Backspace only runs the",
				"carriage back a space. Strike",
				"a key there and it prints ON",
				"TOP of what is already inked.",
				"",
				"A mistake is permanent.",
			]))
	GameEvents.margin_bell_rang.connect(func() -> void:
		_show_note("THE MARGIN", [
			"That bell means you are near",
			"the end of the line.",
			"",
			"At the margin the keys go",
			"dead until you throw the",
			"carriage back.",
		]))
	GameEvents.paper_torn.connect(func() -> void:
		_show_note("TORN", [
			"You pulled it before the",
			"platen let go.",
			"",
			"Wind further next time, or",
			"use the paper release.",
		]))
	GameEvents.wax_stick_spent.connect(func() -> void:
		_show_note("BURNT AWAY", [
			"That stick is gone. The flame",
			"consumes it while it melts.",
			"",
			"A fresh one is in the box.",
		]))

func show_open_reply_note() -> void:
	_show_note("REPLY RECEIVED", [
		"To open the letter you",
		"received, swipe the blade",
		"across the seal fast."
	])

func _show_note(title: String, body: Array) -> void:
	if not _active:
		return
	# a note for something the player has already been told is just noise
	if _note != null and _note.title == title:
		return
	_note = Step.new(title, body)
	_note_time = NOTE_TIME


func skip() -> void:
	_active = false
	_note = null
	Settings.tutorial_seen = true
	Settings.save_settings()
	finished.emit()
	queue_redraw()


func is_active() -> bool:
	return _active


func _process(delta: float) -> void:
	_pulse += delta
	if not _active:
		return

	if _note_time > 0.0:
		_note_time -= delta
		if _note_time <= 0.0:
			_note = null
			_shown = 0.0

	if not is_instance_valid(ritual):
		return
	var st: int = ritual.stage
	if st != _last_stage:
		# whatever we were showing has been done; retire it
		if _stage_steps.has(_last_stage):
			_seen[_last_stage] = true
		_last_stage = st
		_shown = 0.0
		_check_finished()
	_shown += delta
	queue_redraw()


func _check_finished() -> void:
	for k in _stage_steps:
		if not _seen.has(k):
			return
	_active = false
	Settings.tutorial_seen = true
	Settings.save_settings()
	finished.emit()


## The card to show right now: a live note first, otherwise the card for the
## stage we are actually in, and only if it has not been retired.
func _current() -> Step:
	if not _active:
		return null
	if _note != null:
		return _note
	if not is_instance_valid(ritual):
		return null
	var st: int = ritual.stage
	if _seen.has(st):
		return null
	return _stage_steps.get(st, null)


func _draw() -> void:
	var step := _current()
	if step == null or _font == null:
		return

	# --- ring whatever the player should be reaching for ---
	var target := Rect2()
	var grab_action := -1
	if is_instance_valid(ritual):
		var targets: Array = ritual._targets()
		if ritual.stage == ritual.Stage.TYPING and not typewriter.carriage.is_locked():
			targets = []
		if not targets.is_empty():
			target = targets[0]["rect"]
			grab_action = targets[0]["grab"]

	if target.size.x > 1.0:
		# Higher contrast pulse with a dark shadow under the ring for visibility
		var a: float = 0.6 + 0.4 * sin(_pulse * 4.0)
		var shadow_col := Color(0.1, 0.05, 0.02, a * 0.7)
		var ring_col := Color(RING.r, RING.g, RING.b, a)
		
		draw_rect(target.grow(1.0), shadow_col, false, 4.0)
		draw_rect(target, ring_col, false, 2.0)
		
		_draw_ghost_action(target, grab_action)

	# --- the card, tucked in the top right so it doesn't obscure the game ---
	var h := (step.body.size() + 4) * Layout.LINE_H + 12
	var cx: float = Layout.VIEW_W - CARD_W - 10.0
	var r := Rect2(cx, 16.0, CARD_W, h)
	var fade: float = clampf(_shown / 0.3, 0.0, 1.0)
	var is_note := _note != null

	draw_rect(Rect2(r.position + Vector2(2, 3), r.size),
			  Color(0, 0, 0, 0.25 * fade)) # softer shadow
	var paper := NOTE_PAPER if is_note else PAPER
	draw_rect(r, Color(paper.r, paper.g, paper.b, paper.a * fade))
	draw_rect(r, Color(EDGE.r, EDGE.g, EDGE.b, EDGE.a * fade), false, 1.0)
	if is_note:
		# a note gets a second rule, so it reads as an aside rather than as the
		# instruction for the step you are on
		draw_rect(r.grow(-3), Color(EDGE.r, EDGE.g, EDGE.b, 0.4 * fade),
				  false, 1.0)

	var ink := Color(INK.r, INK.g, INK.b, fade)
	_font.draw_text(self, step.title, r.position + Vector2(9, 8), ink)
	draw_line(r.position + Vector2(9, 8 + Layout.LINE_H),
			  r.position + Vector2(r.size.x - 9, 8 + Layout.LINE_H),
			  Color(EDGE.r, EDGE.g, EDGE.b, 0.6 * fade), 1.0)
	for i in step.body.size():
		_font.draw_text(self, step.body[i],
						r.position + Vector2(9, 8 + (i + 2) * Layout.LINE_H), ink)

	draw_line(r.position + Vector2(9, r.size.y - 13),
			  r.position + Vector2(r.size.x - 9, r.size.y - 13),
			  Color(EDGE.r, EDGE.g, EDGE.b, 0.4 * fade), 1.0)
	_font.draw_text(self, "F1 to dismiss the guide",
					r.position + Vector2(9, r.size.y - 10),
					Color(INK.r, INK.g, INK.b, 0.5 * fade))

func _draw_ghost_action(r: Rect2, grab: int) -> void:
	if not is_instance_valid(ritual): return
	var start_pos: Vector2 = r.get_center()
	var end_pos: Vector2 = start_pos
	var draw_arrow := false
	
	match grab:
		ritual.Grab.STACK:
			end_pos = start_pos + Vector2(100, 0)
			draw_arrow = true
		ritual.Grab.KNOB:
			end_pos = start_pos + Vector2(0, -60)
			draw_arrow = true
		ritual.Grab.LEVER:
			end_pos = start_pos + Vector2(120, 0)
			draw_arrow = true
		ritual.Grab.RELEASE:
			end_pos = start_pos + Vector2(0, 40)
			draw_arrow = true
		ritual.Grab.JAM:
			end_pos = start_pos + Vector2(0, 60)
			draw_arrow = true
		ritual.Grab.PAGE_PULL:
			end_pos = start_pos + Vector2(0, -80)
			draw_arrow = true
		ritual.Grab.FOLD_LOWER:
			end_pos = start_pos + Vector2(0, -70)
			draw_arrow = true
		ritual.Grab.FOLD_UPPER:
			end_pos = start_pos + Vector2(0, 70)
			draw_arrow = true
		ritual.Grab.CARRY_LETTER:
			if is_instance_valid(ritual.envelope):
				end_pos = ritual.envelope.mouth_rect().get_center()
				draw_arrow = true
		ritual.Grab.FLAP:
			end_pos = start_pos + Vector2(0, 50)
			draw_arrow = true
		ritual.Grab.WAX:
			end_pos = start_pos + Vector2(0, -50)
			draw_arrow = true
		ritual.Grab.STAMP:
			end_pos = start_pos + Vector2(0, 40)
			draw_arrow = true
		ritual.Grab.CRUSH:
			draw_arrow = false
			var t := fmod(_pulse * 1.5, 1.0)
			var a := 0.8 * (1.0 - t)
			var col := Color(RING.r, RING.g, RING.b, a)
			draw_arc(start_pos, 40.0 * (1.0 - t * 0.5), 0, TAU, 32, col, 2.0)
		ritual.Grab.CARRY_BALL:
			end_pos = ritual.bin_mouth()
			draw_arrow = true
		ritual.Grab.CARRY_SEALED:
			# Mail bag is on the upper left wall
			end_pos = Vector2(73, 130)
			draw_arrow = true

	if draw_arrow:
		var t := fmod(_pulse * 1.5, 1.0)
		var current_pos: Vector2 = start_pos.lerp(end_pos, t)
		var col := Color(RING.r, RING.g, RING.b, 0.8 * (1.0 - t))
		
		# Draw a faint dotted/dashed track to look antique/chalk-like
		var track_col := Color(RING.r, RING.g, RING.b, 0.2)
		draw_line(start_pos, end_pos, track_col, 1.0)
		
		# Ghostly indicator (a circle)
		draw_circle(current_pos, 5.0, col)
		
		# An elegant simple arrow head
		var dir := (end_pos - start_pos).normalized()
		if dir.length() > 0:
			var perp := Vector2(-dir.y, dir.x)
			var p1 := current_pos - dir * 12.0 + perp * 6.0
			var p2 := current_pos - dir * 12.0 - perp * 6.0
			var pts := PackedVector2Array([current_pos, p1, p2])
			draw_polygon(pts, PackedColorArray([col, col, col]))
