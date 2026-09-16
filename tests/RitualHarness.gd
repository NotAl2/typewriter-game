extends Node
## Drives complete letters through the real scene, with no player.
##
## Run it with:
##   godot --headless --path . --fixed-fps 120 -- --test-ritual
##
## This is an integration test, not a unit test, and deliberately so: almost
## every bug worth catching in this mechanic lives in the seams - a stage that
## does not unlock the next interaction, a drag threshold nothing can reach, a
## jam that cannot be cleared, a scroll that runs off the end of the world. It
## exercises the same entry points the mouse and keyboard do, so if it passes,
## the ritual is completable.

signal finished(ok: bool)

var ritual
var typewriter
var desk

var _failures: PackedStringArray = PackedStringArray()
var _checks := 0
var _capture := false
var _shot_index := 0


func run(desk_scene) -> void:
	desk = desk_scene
	ritual = desk.ritual
	typewriter = desk.typewriter
	_capture = "--capture-shots" in OS.get_cmdline_user_args()
	await _drive()


func _shot(name: String) -> void:
	if not _capture:
		return
	await RenderingServer.frame_post_draw
	var img: Image = desk.get_viewport().get_texture().get_image()
	if img == null:
		return
	_shot_index += 1
	var dir := "user://shots/"
	DirAccess.make_dir_recursive_absolute(dir)
	var path := "%s%02d_%s.png" % [dir, _shot_index, name]
	img.save_png(path)
	print("    shot -> %s" % ProjectSettings.globalize_path(path))


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if ok:
		print("  ok   %s" % what)
	else:
		_failures.append(what)
		print("  FAIL %s" % what)


func _stage_name() -> String:
	return String(ritual.STAGE_NAMES[ritual.stage])


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _press(pos: Vector2) -> void:
	ritual.mouse_pressed(pos)


func _drag(from: Vector2, to: Vector2, steps: int = 12) -> void:
	for i in range(1, steps + 1):
		ritual.mouse_moved(from.lerp(to, float(i) / steps))
		await get_tree().process_frame


func _release(pos: Vector2) -> void:
	ritual.mouse_released(pos)
	await get_tree().process_frame


func _hold(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		var d: float = get_process_delta_time()
		if d <= 0.0:
			d = 1.0 / 120.0
		ritual.mouse_held(d)
		t += d
		await get_tree().process_frame


func _centre(r: Rect2) -> Vector2:
	return r.position + r.size * 0.5


# --------------------------------------------------------------------------

func _drive() -> void:
	print("\n=== correspondence ritual: headless run ===")
	Settings.jam_rate_scale = 0.0        # jam on demand instead of by luck

	await _load_paper(true)
	await _typing_basics()
	await _hit_tolerance()
	await _roll_clamp()
	await _tear()
	await _scrap_and_bin()

	await _load_paper(false)
	await _type_whole_document()
	await _eject_via_release()
	await _fold()
	await _insert()
	await _wax_burns_down()
	await _seal()
	_scoring_rules()
	_tutorial_follows_the_stage()
	await _judge()

	print("\n%d checks, %d failures" % [_checks, _failures.size()])
	for f in _failures:
		print("  FAILED: %s" % f)
	finished.emit(_failures.is_empty())


# --- paper ----------------------------------------------------------------

func _load_paper(first: bool) -> void:
	print("\n[load paper]")
	if first:
		_check(ritual.stage == ritual.Stage.LOAD_PAPER, "starts at load paper")

	var stack := _centre(ritual._stack_rect())
	var platen := Vector2(Layout.TW_CX, Layout.CARRIAGE_Y + 12)
	_press(stack)
	await _drag(stack, platen)
	await _release(platen)

	await _shot("paper_loaded")
	_check(typewriter.paper_in, "sheet is in the machine")
	_check(ritual.stage == ritual.Stage.TYPING, "advanced to typing")


# --- typing ---------------------------------------------------------------

func _type_line(text: String) -> void:
	for i in text.length():
		ritual.handle_text(text[i])
		await get_tree().process_frame


func _throw_carriage() -> void:
	var lever: Rect2 = typewriter.carriage.lever_rect()
	var from := _centre(lever)
	var to := from + Vector2(Layout.CARRIAGE_TRAVEL + 40.0, 0)
	_press(from)
	await _drag(from, to, 16)
	await _release(to)
	await _frames(20)


func _typing_basics() -> void:
	print("\n[typing]")
	var doc: DocumentData = ritual.document
	var before_row: int = typewriter.carriage.rows_advanced

	await _type_line(doc.line(0))
	_check(not typewriter.page.is_empty(), "ink landed on the page")
	_check(typewriter.carriage.col == doc.line(0).length(),
		   "carriage advanced one column per character")

	var glyphs_before: int = typewriter.page.glyphs.size()
	ritual.handle_backspace()
	_check(typewriter.carriage.col == doc.line(0).length() - 1,
		   "backspace moves the carriage back")
	_check(typewriter.page.glyphs.size() == glyphs_before,
		   "backspace erases nothing")
	ritual.handle_text("x")
	_check(typewriter.page.overstrike_count() == 1,
		   "striking over a character overstrikes it")

	await _shot("typing")
	await _throw_carriage()
	_check(typewriter.carriage.rows_advanced == before_row + 1,
		   "carriage return fed one line")
	_check(typewriter.carriage.col == 0, "carriage returned to the margin")

	var lock_hits := [0]
	GameEvents.key_rejected.connect(func(_c: String, reason: String) -> void:
		if reason == "margin":
			lock_hits[0] += 1)
	for i in Layout.COLS + 4:
		ritual.handle_text("m")
		await get_tree().process_frame
	_check(typewriter.carriage.is_locked(), "carriage locks at the right margin")
	_check(lock_hits[0] >= 3,
		   "keys past the margin print nothing (%d refused)" % lock_hits[0])
	await _throw_carriage()


# --- hitboxes -------------------------------------------------------------

func _hit_tolerance() -> void:
	print("\n[hitboxes]")
	# The lever is 52x13. A press a few pixels OUTSIDE it must still find it -
	# exact-rect hit testing plus a couple of pixels of camera parallax is why
	# small props felt unresponsive.
	var lever: Rect2 = typewriter.carriage.lever_rect()
	var just_outside := lever.position + Vector2(-6, -6)
	var t: Dictionary = ritual.target_at(just_outside)
	_check(not t.is_empty() and int(t["grab"]) == ritual.Grab.LEVER,
		   "a near miss on the return lever still grabs it")

	var far_away := lever.position - Vector2(120, 90)
	_check(ritual.target_at(far_away).is_empty(),
		   "a press nowhere near anything grabs nothing")

	var rel: Rect2 = typewriter.carriage.release_rect()
	var t2: Dictionary = ritual.target_at(_centre(rel))
	_check(not t2.is_empty() and int(t2["grab"]) == ritual.Grab.RELEASE,
		   "the paper release is reachable while typing")


# --- the scroll softlock --------------------------------------------------

func _roll_clamp() -> void:
	print("\n[winding, clamped]")
	ritual.declare_page_finished()
	_check(ritual.stage == ritual.Stage.PAGE_DONE, "page can be declared done")

	# Spin the wheel far past any sane amount. This is the reported softlock:
	# unclamped, the sheet climbs off the top of the screen and the pull-it-free
	# hitbox goes with it, leaving nothing to click.
	for i in 400:
		desk._wheel_roll(true)
	await _frames(2)

	var off: float = typewriter.carriage.paper_offset()
	_check(off <= typewriter.carriage.MAX_PAPER_OFFSET + 0.5,
		   "the platen stops winding (offset %.0f <= %d)"
		   % [off, typewriter.carriage.MAX_PAPER_OFFSET])
	_check(typewriter.carriage.fully_wound(), "the carriage reports fully wound")

	var pr: Rect2 = ritual._paper_rect()
	_check(pr.position.y >= 0.0 and pr.position.y < Layout.VIEW_H,
		   "the sheet's grab area is still on screen (y=%.0f)" % pr.position.y)
	var t: Dictionary = ritual.target_at(_centre(pr))
	_check(not t.is_empty() and int(t["grab"]) == ritual.Grab.PAGE_PULL,
		   "the wound-out sheet can still be grabbed - no softlock")

	# and it must wind back the other way too
	for i in 30:
		desk._wheel_roll(false)
	await _frames(2)
	_check(typewriter.carriage.roll_px >= 0.0, "winding back never goes negative")


# --- tearing and scrapping ------------------------------------------------

func _tear() -> void:
	print("\n[tearing a sheet]")
	# wind back to where the platen still has hold of it
	typewriter.carriage.roll_px = 0.0
	typewriter.carriage.rows_advanced = 1
	typewriter.carriage._update_paper()
	_check(not typewriter.carriage.paper_free_of_grip(),
		   "the platen still has hold of the sheet")

	var torn := [false]
	GameEvents.paper_torn.connect(func() -> void: torn[0] = true, CONNECT_ONE_SHOT)
	var pr: Rect2 = ritual._paper_rect()
	var from := _centre(pr)
	_press(from)
	await _drag(from, from + Vector2(0, -30), 8)
	await _release(from + Vector2(0, -30))
	await _frames(6)

	_check(torn[0], "pulling too early tears the sheet")
	_check(ritual.stage == ritual.Stage.SCRAP,
		   "a torn sheet becomes waste (stage=%s)" % _stage_name())
	_check(ritual.scrap != null, "there is a ruined sheet on the desk")
	_check(ritual.sheets_spoiled == 1, "the spoiled sheet is counted")


func _scrap_and_bin() -> void:
	print("\n[crumple and bin]")
	var scrap = ritual.scrap
	var sr: Rect2 = scrap.rect()
	var from := _centre(sr)

	# 1. crush it
	_press(from)
	var crumpled := [false]
	scrap.crumpled.connect(func() -> void: crumpled[0] = true, CONNECT_ONE_SHOT)
	await _hold(scrap.CRUSH_TIME + 0.25)
	await _release(scrap.position)
	await _frames(60)                      # it drops out of your fist to the desk
	_check(crumpled[0], "holding the sheet down crushes it into a ball")
	_check(scrap.is_ball(), "it is now a ball")
	_check(scrap.position.y > Layout.DESK_TOP_Y,
		   "and lands on the desk, not in mid-air (y=%.0f)" % scrap.position.y)
	await _shot("crumpled")

	# 2. throw it wide - it must land on the desk and stay grabbable
	var ball_pos: Vector2 = scrap.position
	_press(ball_pos)
	await _drag(ball_pos, Vector2(470, 210), 6)
	await _release(Vector2(470, 210))
	await _frames(90)
	_check(not scrap.is_done(), "a throw that misses does not vanish")
	_check(ritual.stage == ritual.Stage.SCRAP, "and the waste is still yours")

	# 3. now actually bin it
	var went_in := [false]
	scrap.landed.connect(func(ok: bool) -> void: went_in[0] = ok)
	var mouth: Vector2 = ritual.bin_mouth()
	var grab_at: Vector2 = scrap.position
	_press(grab_at)
	await _drag(grab_at, mouth - Vector2(0, 18), 10)
	await _release(mouth - Vector2(0, 18))
	await _frames(60)

	_check(went_in[0], "a ball dropped over the basket goes in")
	_check(ritual.stage == ritual.Stage.LOAD_PAPER,
		   "binning the waste clears the desk (stage=%s)" % _stage_name())
	await _shot("binned")


# --- the real page --------------------------------------------------------

func _force_jam() -> void:
	typewriter.jam.jammed = true
	typewriter.jam.bar_a = 3
	typewriter.jam.bar_b = 5
	typewriter.jam.jam_col = typewriter.carriage.col
	typewriter.jam.jam_row = typewriter.carriage.rows_advanced
	typewriter._enter_jam()
	await _frames(2)
	_check(ritual.stage == ritual.Stage.JAMMED, "a clash stops the machine")

	var jr: Rect2 = typewriter.basket.jam_rect()
	var from := _centre(jr)
	_press(from)
	await _drag(from, from + Vector2(0, 40), 14)
	await _release(from + Vector2(0, 40))
	await _frames(3)
	_check(not typewriter.jam.jammed, "dragging the bars apart clears the jam")
	_check(typewriter.page.smudges.size() == 1, "the jam left ink on the page")


func _type_whole_document() -> void:
	print("\n[typing the letter properly]")
	var doc: DocumentData = ritual.document
	var guard := 0
	var jammed_once := false
	while ritual.stage == ritual.Stage.TYPING and guard < Layout.ROWS + 4:
		guard += 1
		var row: int = typewriter.carriage.rows_advanced
		var text := doc.line(row)
		if not text.is_empty():
			await _type_line(text)
		# jam on the page we are actually keeping, so the smudge reaches scoring
		if not jammed_once and row == 2:
			jammed_once = true
			await _force_jam()
		await _throw_carriage()
	_check(jammed_once, "jammed once on the page we keep")
	_check(ritual.stage == ritual.Stage.PAGE_DONE,
		   "page completes after the last line (stage=%s)" % _stage_name())
	_check(typewriter.page.smudges.size() >= 1,
		   "the smudge is still on the finished page")


# --- the direct eject -----------------------------------------------------

func _eject_via_release() -> void:
	print("\n[paper release]")
	var rel: Rect2 = typewriter.carriage.release_rect()
	_check(not typewriter.carriage.released, "the release starts engaged")
	_press(_centre(rel))
	await _release(_centre(rel))
	await _frames(8)

	_check(typewriter.carriage.released or not typewriter.paper_in,
		   "throwing the release frees the sheet")
	_check(ritual.stage == ritual.Stage.FOLD,
		   "a finished page ejects straight to folding, no winding (stage=%s)"
		   % _stage_name())
	_check(ritual.sheet != null, "the sheet is on the desk")
	await _shot("ejected")


# --- folding and posting --------------------------------------------------

func _fold() -> void:
	print("\n[folding]")
	var lower: Rect2 = ritual.sheet.lower_rect()
	var from := _centre(lower)
	_press(from)
	await _drag(from, from + Vector2(0, -40), 14)
	await _release(from + Vector2(0, -40))
	_check(ritual.sheet.fold == ritual.sheet.Fold.ONCE, "first fold made")

	var upper: Rect2 = ritual.sheet.upper_rect()
	var from2 := _centre(upper)
	_press(from2)
	await _drag(from2, from2 + Vector2(0, 40), 14)
	await _release(from2 + Vector2(0, 40))
	await _frames(2)
	_check(ritual.sheet.fold == ritual.sheet.Fold.TWICE, "second fold made")
	_check(ritual.stage == ritual.Stage.INSERT,
		   "a trifolded letter is ready for the envelope")


func _insert() -> void:
	print("\n[envelope]")
	var env = ritual.envelope
	_check(env.state == env.State.OPEN, "the envelope opened its mouth")

	var from := _centre(ritual.sheet.rect())
	var to := _centre(env.mouth_rect())
	_press(from)
	await _drag(from, to, 14)
	await _release(to)
	await _frames(2)
	_check(env.state == env.State.STUFFED, "the letter went in")

	var fr: Rect2 = env.flap_rect()
	var ffrom := _centre(fr)
	_press(ffrom)
	await _drag(ffrom, ffrom + Vector2(0, 40), 14)
	await _release(ffrom + Vector2(0, 40))
	await _frames(2)
	_check(env.state == env.State.CLOSED, "the flap is down")
	_check(ritual.stage == ritual.Stage.SEAL_WAX,
		   "a closed envelope calls for wax (stage=%s)" % _stage_name())
	await _shot("envelope")


# --- wax ------------------------------------------------------------------

func _flame() -> Vector2:
	return Vector2(Layout.FLAME_CX, Layout.FLAME_CY)


## The cursor point that puts the stick's TIP at `target`.
func _stick_grip_for(target: Vector2) -> Vector2:
	# move_stick puts the sprite top at (cursor - 6); the tip is stick_length
	# below that, and stick_length shrinks as the wax burns
	return target - Vector2(0, ritual.kit.stick_length - 6.0)


func _wax_burns_down() -> void:
	print("\n[the stick burns down]")
	var kit = ritual.kit
	var start_len: float = kit.stick_length
	_check(is_equal_approx(start_len, float(Layout.WAX_STICK_H)),
		   "a fresh stick is full length")

	var spent := [0]
	GameEvents.wax_stick_spent.connect(func() -> void: spent[0] += 1)

	_press(_centre(kit.stick_rect()))
	var target := _stick_grip_for(_flame())
	await _drag(_centre(kit.stick_rect()), target, 6)

	# hold it in the fire and keep re-aiming as the tip creeps back
	var guard := 0
	var shortened := false
	while spent[0] == 0 and guard < 1600:
		guard += 1
		ritual.mouse_moved(_stick_grip_for(_flame()))
		if kit.stick_length < start_len - 4.0:
			shortened = true
		await get_tree().process_frame
	_check(shortened, "the flame eats the stick as it melts")
	_check(spent[0] >= 1, "left in the flame, the stick is used up entirely")
	_check(is_equal_approx(kit.stick_length, float(Layout.WAX_STICK_H)),
		   "a fresh stick replaces it")
	await _release(_stick_grip_for(_flame()))
	await _frames(2)


func _seal() -> void:
	print("\n[melt, pour, press]")
	var kit = ritual.kit
	_press(_centre(kit.stick_rect()))
	await _drag(_centre(kit.stick_rect()), _stick_grip_for(_flame()), 6)

	var guard := 0
	while kit.heat < 0.95 and guard < 900:
		guard += 1
		ritual.mouse_moved(_stick_grip_for(_flame()))
		await get_tree().process_frame
	_check(kit.stick_state() == kit.StickState.MOLTEN,
		   "the wax melted (heat %.2f)" % kit.heat)

	var seal_pt: Vector2 = ritual.envelope.seal_point()
	await _drag(_stick_grip_for(_flame()), _stick_grip_for(seal_pt), 8)
	guard = 0
	while not kit.pool_ready() and guard < 600:
		guard += 1
		ritual.mouse_moved(_stick_grip_for(seal_pt))
		await get_tree().process_frame
	_check(kit.pool_ready(), "enough wax pooled to take a seal (%.2f)"
		   % kit.pool_volume)
	await _shot("wax_poured")
	await _release(_stick_grip_for(seal_pt))

	guard = 0
	while kit.pool_temp > 0.7 and guard < 600:
		guard += 1
		await get_tree().process_frame

	var sfrom := _centre(kit.stamp_rect())
	_press(sfrom)
	_check(ritual.stage == ritual.Stage.STAMP, "picking up the die arms the press")
	var die_target := seal_pt - Vector2(0, 6)
	await _drag(sfrom, die_target, 8)
	await _hold(0.6)
	await _release(die_target)
	await _frames(30)
	await _shot("sealed")

	_check(ritual.stage == ritual.Stage.COMPLETE,
		   "the ritual completes (stage=%s)" % _stage_name())
	_check(ritual.result != null, "a result was produced")


# --- how characters are counted -------------------------------------------

func _fake_doc(lines: Array) -> DocumentData:
	var d := DocumentData.new()
	d.lines = PackedStringArray(lines)
	return d


## Strike `text` into `row` starting at `from_col`. A "~" means skip that cell
## entirely - the player never typed anything there.
func _type_into(page: TypedPage, row: int, text: String, from_col: int = 0) -> void:
	for i in text.length():
		if text[i] == "~":
			continue
		page.strike(text[i], from_col + i, row)


func _scoring_rules() -> void:
	print("
[how characters are counted]")
	var doc := _fake_doc(["ABC DEF", "", "GH"])

	# 1. a perfect page, plus the trailing spaces a typist taps before throwing
	var clean := TypedPage.new(1)
	_type_into(clean, 0, "ABC DEF   ")
	_type_into(clean, 2, "GH  ")
	var s := RitualResult.score_page(clean, doc, Layout.ROWS, Layout.COLS)
	_check(int(s["wrong"]) == 0 and int(s["missing"]) == 0
		   and int(s["stray"]) == 0,
		   "trailing spaces after a line are not errors")
	_check(is_equal_approx(float(s["accuracy"]), 1.0), "and accuracy stays 100%")

	# 2. a character never typed is MISSING, not wrong
	var gap := TypedPage.new(2)
	_type_into(gap, 0, "ABC ~EF")        # D never struck
	_type_into(gap, 2, "GH")
	s = RitualResult.score_page(gap, doc, Layout.ROWS, Layout.COLS)
	_check(int(s["missing"]) == 1, "an untyped character counts as missing (%d)"
		   % int(s["missing"]))
	_check(int(s["wrong"]) == 0, "and NOT as mistyped (%d)" % int(s["wrong"]))
	_check(String(s["typos"][0]).contains("missing"),
		   "and is reported as missing: %s" % s["typos"][0])

	# 3. a different character is MISTYPED
	var typo := TypedPage.new(3)
	_type_into(typo, 0, "ABX DEF")
	_type_into(typo, 2, "GH")
	s = RitualResult.score_page(typo, doc, Layout.ROWS, Layout.COLS)
	_check(int(s["wrong"]) == 1 and int(s["missing"]) == 0,
		   "a wrong character counts as mistyped (%d wrong, %d missing)"
		   % [int(s["wrong"]), int(s["missing"])])

	# 4. something typed where the source had nothing is STRAY
	var extra := TypedPage.new(4)
	_type_into(extra, 0, "ABC DEFZ")
	_type_into(extra, 2, "GH")
	s = RitualResult.score_page(extra, doc, Layout.ROWS, Layout.COLS)
	_check(int(s["stray"]) == 1, "an added character counts as stray (%d)"
		   % int(s["stray"]))

	# 5. a page abandoned half-typed is all missing, and says so
	var half := TypedPage.new(5)
	_type_into(half, 0, "ABC DEF")
	s = RitualResult.score_page(half, doc, Layout.ROWS, Layout.COLS)
	_check(int(s["missing"]) == 2 and int(s["wrong"]) == 0,
		   "an unfinished page is missing, not wrong (%d missing, %d wrong)"
		   % [int(s["missing"]), int(s["wrong"])])

	var r := RitualResult.new()
	r.accuracy = float(s["accuracy"])
	r.chars_expected = int(s["expected"])
	r.chars_correct = int(s["correct"])
	r.chars_wrong = int(s["wrong"])
	r.chars_missing = int(s["missing"])
	r.chars_stray = int(s["stray"])
	r.evaluate()
	var named := "
".join(r.faults)
	_check(named.contains("missing"),
		   "and the fault says 'missing': %s" % named.replace("
", " / "))
	_check(not named.contains("mistyped"),
		   "and never calls it mistyped")


func _tutorial_follows_the_stage() -> void:
	print("
[the guide follows the stage]")
	var tut = preload("res://scripts/desk/Tutorial.gd").new()
	desk.add_child(tut)
	tut.build(desk._font, ritual, typewriter)

	# The reported bug: after a scrap the ritual drops back to LOAD_PAPER while
	# the guide sits on a later step, so the folding card and the crumpling card
	# alternate. Walk the stages out of order and require the card to match.
	var real_stage: int = ritual.stage
	var order := [ritual.Stage.LOAD_PAPER, ritual.Stage.TYPING,
				  ritual.Stage.PAGE_DONE, ritual.Stage.SCRAP,
				  ritual.Stage.LOAD_PAPER, ritual.Stage.TYPING,
				  ritual.Stage.FOLD, ritual.Stage.INSERT]
	var mismatches := 0
	var seen_titles := PackedStringArray()
	for st: int in order:
		ritual.stage = st
		tut._process(0.05)
		var step = tut._current()
		if step == null:
			continue                       # already retired: correct, not a bug
		var want = tut._stage_steps.get(st, null)
		if want == null or step.title != want.title:
			mismatches += 1
		seen_titles.append(step.title)
	ritual.stage = real_stage

	_check(mismatches == 0,
		   "the card always matches the current stage (%d mismatches)" % mismatches)
	# once a stage has been left it must not come back and start alternating
	var repeats := 0
	var counts := {}
	for t in seen_titles:
		counts[t] = int(counts.get(t, 0)) + 1
		if int(counts[t]) > 1:
			repeats += 1
	_check(repeats == 0, "and no card is ever shown twice (%d repeats): %s"
		   % [repeats, ", ".join(seen_titles)])
	tut.queue_free()


# --- scoring and the reply chain ------------------------------------------

func _judge() -> void:
	print("\n[judging]")
	var r: RitualResult = ritual.result
	if r == null:
		_check(false, "no result to judge")
		return
	for line in r.summary_lines():
		print("    " + line)

	_check(r.smudges >= 1, "smudges reach the result (%d)" % r.smudges)
	_check(r.sheets_spoiled >= 1, "spoiled sheets reach the result (%d)"
		   % r.sheets_spoiled)
	_check(r.chars_expected > 0, "characters were actually compared (%d)"
		   % r.chars_expected)
	_check(r.accuracy > 0.99, "the kept page was typed accurately (%.2f)"
		   % r.accuracy)

	# the page was typed perfectly, but a jam smudged it - that alone must be
	# enough to fail it, because the player could have scrapped and retyped
	_check(not r.faults.is_empty(), "the smudge alone names a fault")
	_check(not r.is_satisfactory(),
		   "an otherwise perfect but smudged letter is unsatisfactory")

	# --- a deliberately awful letter, for the chain ---
	var bad := RitualResult.new()
	bad.document_title = "test"
	bad.chars_expected = 100
	bad.chars_correct = 61
	bad.accuracy = 0.61
	bad.smudges = 4
	bad.overstrikes = 9
	bad.seal_grade = RitualResult.Grade.POOR
	bad.evaluate()
	_check(bad.faults.size() >= 4, "an awful letter names every fault (%d)"
		   % bad.faults.size())
	_check(bad.severity() > 0.5, "and scores as severe (%.2f)" % bad.severity())

	# --- the chain, at each difficulty ---
	for diff in [RunState.Difficulty.UNFORGIVING, RunState.Difficulty.STANDARD,
				 RunState.Difficulty.LENIENT]:
		RunState.reset(diff)
		var tones: Array[int] = []
		for i in 4:
			tones.append(RunState.submit(bad))
			if RunState.failed:
				break
		var name := RunState.difficulty_name()
		var expect: int = int(RunState.TOLERANCE[diff]) + 1
		_check(tones.size() == expect,
			   "%s: %d poor letters end the run" % [name.to_lower(), expect])
		_check(tones[tones.size() - 1] == RunState.Tone.RAGE,
			   "%s: the last reply is the rage letter" % name.to_lower())
		_check(RunState.failed, "%s: the run is marked failed" % name.to_lower())

	# a clean letter must keep the correspondence warm
	RunState.reset(RunState.Difficulty.STANDARD)
	var good := RitualResult.new()
	good.accuracy = 1.0
	good.seal_grade = RitualResult.Grade.PERFECT
	good.evaluate()
	_check(good.is_satisfactory(), "a clean letter is satisfactory")
	var tone: int = RunState.submit(good)
	_check(tone == RunState.Tone.WARM, "and the reply comes back warm")
	_check(not RunState.failed, "and the run continues")

	var reply: DocumentData = RunState.take_reply()
	_check(reply != null and reply.line_count() > 4,
		   "the reply is a real letter (%d lines)"
		   % (reply.line_count() if reply else 0))

	# and the rage letter must quote the actual faults back
	RunState.reset(RunState.Difficulty.UNFORGIVING)
	RunState.submit(bad)
	var rage: DocumentData = RunState.take_reply()
	var body := "\n".join(rage.lines)
	_check(rage.tone == RunState.Tone.RAGE, "the rage letter is tagged as such")
	_check(body.contains("wrong") or body.contains("smudge")
		   or body.contains("seal") or body.contains("corrections"),
		   "the rage letter names what you actually did wrong")
	print("\n--- the rage letter ---")
	for l in rage.lines:
		print("    " + l)
