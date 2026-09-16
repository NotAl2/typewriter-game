extends Node
## The campaign: which letter you are on, how much patience your clients have
## left, and whether the next post brings a pleasantry or a dismissal.
##
## The chain is the point. Each letter you send is judged (see
## RitualResult.evaluate), and the reply that comes back is written in a tone
## chosen by how many unsatisfactory letters you have sent so far. Send good
## work and the correspondence stays warm and ordinary. Send bad work and it
## cools, then turns hostile, then ends the run.
##
## Difficulty only changes how many poor letters you are allowed before the rage
## letter arrives - the writing, the faults and the judging are identical.

enum Difficulty { UNFORGIVING, STANDARD, LENIENT }
enum Tone { WARM, COOL, HOSTILE, RAGE }

## How many unsatisfactory letters you may send BEFORE the rage letter.
const TOLERANCE := {
	Difficulty.UNFORGIVING: 0,     # the very first bad letter ends it
	Difficulty.STANDARD: 1,        # one cold warning, then out
	Difficulty.LENIENT: 2,         # two warnings - cool, then hostile
}

const DIFFICULTY_NAMES := {
	Difficulty.UNFORGIVING: "UNFORGIVING",
	Difficulty.STANDARD: "STANDARD",
	Difficulty.LENIENT: "LENIENT",
}

const DIFFICULTY_BLURB := {
	Difficulty.UNFORGIVING: "one poor letter ends the run",
	Difficulty.STANDARD: "one warning, then dismissal",
	Difficulty.LENIENT: "two warnings before dismissal",
}

const LETTERS := [
	"res://scripts/documents/letters/day1_eleanor.tres",
	"res://scripts/documents/letters/day2_hallow.tres",
	"res://scripts/documents/letters/day3_notice.tres",
	"res://scripts/documents/letters/day4_ashgrove.tres",
]

var difficulty: int = Difficulty.STANDARD
var tutorial_enabled := true

var letter_index := 0
var day_offset := 0
var poor_letters := 0
var failed := false
var finished_run := false
## Results in order, so a day summary can look back over the week.
var history: Array[RitualResult] = []
## The reply waiting to be read before the next letter is typed.
var pending_reply: DocumentData = null
var pending_tone: int = Tone.WARM


func reset(diff: int = -1) -> void:
	if diff >= 0:
		difficulty = diff
	letter_index = 0
	day_offset = 0
	poor_letters = 0
	failed = false
	finished_run = false
	history.clear()
	pending_reply = null
	pending_tone = Tone.WARM


func tolerance() -> int:
	return int(TOLERANCE.get(difficulty, 1))


func difficulty_name() -> String:
	return String(DIFFICULTY_NAMES.get(difficulty, "STANDARD"))


## The document the player types today. Null once the run is over.
func current_document() -> DocumentData:
	if letter_index < 0 or letter_index >= LETTERS.size():
		return null
	var path: String = LETTERS[letter_index]
	if not ResourceLoader.exists(path):
		push_error("RunState: missing letter %s" % path)
		return null
	return load(path)


func letters_remaining() -> int:
	return maxi(0, LETTERS.size() - letter_index)


## Record a finished letter and work out what comes back in the post.
## Returns the tone of the reply that is now pending.
func submit(result: RitualResult) -> int:
	history.append(result)
	GameEvents.letter_sent.emit(result)

	var tone := Tone.WARM
	if not result.is_satisfactory():
		poor_letters += 1
		if poor_letters > tolerance():
			tone = Tone.RAGE
		elif poor_letters >= 2:
			tone = Tone.HOSTILE
		else:
			tone = Tone.COOL

	pending_tone = tone
	pending_reply = ReplyWriter.compose(result, tone, self)

	day_offset += randi_range(2, 3)

	if tone == Tone.RAGE:
		failed = true
	else:
		letter_index += 1
		if letter_index >= LETTERS.size():
			finished_run = true

	return tone


func take_reply() -> DocumentData:
	var r := pending_reply
	pending_reply = null
	return r


## A one-line note for the results card, so the player can see the pressure.
func standing() -> String:
	if failed:
		return "dismissed"
	var left: int = tolerance() - poor_letters
	if poor_letters == 0:
		return "%s - in good standing" % difficulty_name().to_lower()
	if left <= 0:
		return "one more poor letter ends this"
	return "%d poor letter(s) sent, %d allowed" % [poor_letters, left]
