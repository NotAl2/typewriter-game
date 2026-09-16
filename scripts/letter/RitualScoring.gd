class_name RitualResult
extends Resource
## The verdict on one finished letter.
##
## Deliberately a Resource with no node references: this is the hand-off to the
## day loop, and it is also the record the story consults. `faults` in
## particular is kept as a list of named, human-readable complaints, because the
## recipient's reply quotes them back at you - being told *why* your work was
## unsatisfactory is what makes an angry letter land instead of feeling random.
##
## Note there is no address fault. The address is pre-printed on the envelope,
## so it is not something the player can get wrong at the keys.

enum Grade { PERFECT, GOOD, POOR, RUINED }

## What a letter has to clear to be considered satisfactory work.
const ACCURACY_FLOOR := 0.92
## Any smudge at all counts. A jam leaves permanent ink on a letter somebody is
## going to read, and the player always has the option of scrapping the page and
## starting again - that is what the basket is for.
const SMUDGE_LIMIT := 0
## A few struck-over corrections were ordinary for the period. A page full of
## them says you could not type it cleanly.
const OVERSTRIKE_LIMIT := 3

@export var document_title := ""
@export var document_id := ""
@export var elapsed_seconds := 0.0
@export var wpm := 0.0
@export var accuracy := 1.0
@export var chars_expected := 0
@export var chars_correct := 0
## Defects, kept apart: a typo, a gap, and something you invented.
@export var chars_wrong := 0
@export var chars_missing := 0
@export var chars_stray := 0
@export var overstrikes := 0
@export var smudges := 0
@export var sheets_spoiled := 0
@export var wax_sticks_spoiled := 0
@export var wax_sticks_used := 0
@export var seal_grade: int = Grade.GOOD
@export var seal_score := 0.0
## "row:col expected -> typed"
@export var typos: PackedStringArray = PackedStringArray()
## Human-readable complaints, in severity order. Empty means clean work.
@export var faults: PackedStringArray = PackedStringArray()


static func grade_name(g: int) -> String:
	match g:
		Grade.PERFECT: return "Perfect"
		Grade.GOOD: return "Good"
		Grade.POOR: return "Poor"
		_: return "Ruined"


## Length ignoring trailing spaces. A typist who taps the space bar before
## throwing the carriage has not made a mistake, and neither has one who did
## not - trailing whitespace is simply not content.
static func _content_len(s: String) -> int:
	var n := s.length()
	while n > 0 and s[n - 1] == " ":
		n -= 1
	return n


## Compare what is on the page against what the document asked for.
##
## Three kinds of defect, kept apart because they mean different things to a
## reader: a WRONG character is a typo, a MISSING one is a gap where the reader
## expected a word, and a STRAY one is something you added that was never in the
## source. Lumping them together as "wrong" told the player nothing useful.
static func score_page(page: TypedPage, doc: DocumentData,
		rows: int, cols: int) -> Dictionary:
	var expected := 0
	var correct := 0
	var wrong := 0
	var missing := 0
	var stray := 0
	var typos := PackedStringArray()

	for r in rows:
		var want := doc.line(r)
		var got := page.line_text(r, cols)
		var want_len := _content_len(want)
		var got_len := _content_len(got)
		# only compare as far as either side actually has content: everything
		# past that on both sides is trailing space, which counts for nothing
		var span: int = mini(cols, maxi(want_len, got_len))
		for c in span:
			var wch := want[c] if c < want.length() else " "
			var gch := got[c] if c < got.length() else " "
			if wch == " " and gch == " ":
				continue
			expected += 1
			if wch == gch:
				correct += 1
				continue
			var note := ""
			if gch == " ":
				missing += 1
				note = "%d:%d missing '%s'" % [r, c, wch]
			elif wch == " ":
				stray += 1
				note = "%d:%d stray '%s'" % [r, c, gch]
			else:
				wrong += 1
				note = "%d:%d '%s' -> '%s'" % [r, c, wch, gch]
			if typos.size() < 60:
				typos.append(note)

	return {
		"expected": expected,
		"correct": correct,
		"wrong": wrong,
		"missing": missing,
		"stray": stray,
		"accuracy": (float(correct) / float(expected)) if expected > 0 else 1.0,
		"typos": typos,
	}


## Fill in `faults` from the raw counts. Called once, after everything is set.
func evaluate() -> void:
	faults = PackedStringArray()

	# Each kind of defect is named for what it actually is. Being told "39
	# characters wrong" when most of them were never typed at all is useless to
	# a player trying to work out what they did.
	if accuracy < ACCURACY_FLOOR:
		if chars_wrong > 0:
			faults.append("%d character%s mistyped" % [chars_wrong,
				"" if chars_wrong == 1 else "s"])
		if chars_missing > 0:
			var share := float(chars_missing) / maxf(1.0, float(chars_expected))
			if share > 0.35:
				faults.append("%d characters missing - the letter is unfinished"
							  % chars_missing)
			else:
				faults.append("%d character%s missing" % [chars_missing,
					"" if chars_missing == 1 else "s"])
		if chars_stray > 0:
			faults.append("%d character%s that were never in my letter"
						  % [chars_stray, "" if chars_stray == 1 else "s"])
		if chars_wrong == 0 and chars_missing == 0 and chars_stray == 0:
			faults.append("the text does not match what I sent you")

	if smudges > SMUDGE_LIMIT:
		if smudges == 1:
			faults.append("an ink smudge across the writing")
		else:
			faults.append("%d ink smudges across the page" % smudges)

	if overstrikes > OVERSTRIKE_LIMIT:
		faults.append("%d corrections struck over the text" % overstrikes)

	match seal_grade:
		Grade.RUINED:
			faults.append("the seal did not take at all")
		Grade.POOR:
			faults.append("the wax seal is smeared and broken")
		_:
			pass


func is_satisfactory() -> bool:
	return faults.is_empty()


## 0.0 = flawless, 1.0 = about as bad as a letter can be. Drives how angry the
## reply is when the letter is unsatisfactory.
func severity() -> float:
	var s := 0.0
	s += clampf((ACCURACY_FLOOR - accuracy) / ACCURACY_FLOOR, 0.0, 1.0) * 0.55
	s += clampf(float(smudges) / 6.0, 0.0, 1.0) * 0.18
	s += clampf(float(overstrikes) / 10.0, 0.0, 1.0) * 0.12
	s += [0.0, 0.0, 0.10, 0.15][clampi(seal_grade, 0, 3)]
	return clampf(s, 0.0, 1.0)


## Overall letter grade: accuracy first, then the seal, then the mess.
func overall_grade() -> int:
	if accuracy < 0.55 or seal_grade == Grade.RUINED:
		return Grade.RUINED
	var score := accuracy
	score -= smudges * 0.02
	score -= overstrikes * 0.015
	score -= sheets_spoiled * 0.03
	score -= [0.0, 0.04, 0.12, 0.30][clampi(seal_grade, 0, 3)]
	if score >= 0.97:
		return Grade.PERFECT
	if score >= 0.85:
		return Grade.GOOD
	if score >= 0.6:
		return Grade.POOR
	return Grade.RUINED


func summary_lines() -> PackedStringArray:
	var out := PackedStringArray([
		"%s" % document_title,
		"accuracy  %d%%" % roundi(accuracy * 100.0),
		"speed     %d wpm" % roundi(wpm),
		"seal      %s" % grade_name(seal_grade),
		"errors    %d mistyped, %d missing, %d stray"
			% [chars_wrong, chars_missing, chars_stray],
		"marks     %d overstruck, %d smudged" % [overstrikes, smudges],
		"waste     %d sheet(s), %d stick(s)" % [sheets_spoiled,
											wax_sticks_spoiled + wax_sticks_used],
		"verdict   %s" % grade_name(overall_grade()),
	])
	if not faults.is_empty():
		out.append("")
		out.append("this will not pass:")
		for f in faults:
			out.append("  - %s" % f)
	return out
