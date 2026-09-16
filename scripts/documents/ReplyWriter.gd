class_name ReplyWriter
extends RefCounted
## Composes the letter that comes back in the post.
##
## The reply is written by the CLIENT - the person who paid you to type their
## correspondence - reacting to how their letter was received at the other end.
## That framing is what gives the anger somewhere to go: it is not that you
## typed badly, it is that a man's name went out into the world on a page you
## smudged, and other people read it.
##
## The faults the player actually committed are quoted into the body verbatim,
## so the reply can never accuse you of something you did not do. Being told
## exactly why is what makes an angry letter land instead of feeling arbitrary.

const WRAP := 34


static func compose(result: RitualResult, tone: int, run) -> DocumentData:
	var doc := DocumentData.new()
	doc.sender = "J. Hallow"
	doc.recipient = "A. Whitlock"
	doc.is_reply = true
	doc.tone = tone

	match tone:
		RunState.Tone.WARM:
			doc.title = "A letter from Mr Hallow"
			doc.lines = _wrap_all(_warm(result))
		RunState.Tone.COOL:
			doc.title = "A letter from Mr Hallow"
			doc.lines = _wrap_all(_cool(result))
		RunState.Tone.HOSTILE:
			doc.title = "A second letter from Mr Hallow"
			doc.lines = _wrap_all(_hostile(result))
		_:
			doc.title = "WHITLOCK."
			doc.lines = _wrap_all(_rage(result))
	return doc


# --------------------------------------------------------------------------

static func _fault_block(result: RitualResult, lead: String) -> Array:
	if result.faults.is_empty():
		return []
	var out: Array = ["", lead]
	for f in result.faults:
		out.append("  - " + String(f))
	return out


static func _warm(result: RitualResult) -> Array:
	var praise := "It went out clean."
	if result.overall_grade() == RitualResult.Grade.PERFECT:
		praise = "Not a mark on it anywhere. I am told the seal was so crisp " \
			+ "they were sorry to break it."
	return [
		"Mr Whitlock,",
		"",
		"My letter arrived and was well received. " + praise,
		"",
		"Mrs Ashe remarked that it was the neatest thing to come to that " \
			+ "house in a twelvemonth, and she is not a woman who remarks.",
		"",
		"I have another for you, on the same terms. There is no hurry, " \
			+ "though I would not leave it past Thursday.",
		"",
		"Yours &c.",
		"J. Hallow",
	]


static func _cool(result: RitualResult) -> Array:
	var out: Array = [
		"Mr Whitlock,",
		"",
		"I will be plain with you. The letter you typed for me came back to " \
			+ "my attention with a remark written upon the reverse, and the " \
			+ "remark was not about its contents.",
	]
	out.append_array(_fault_block(result, "What was noted:"))
	out.append_array([
		"",
		"I engaged you for a clean hand. I did not receive one. I am not " \
			+ "angry, Mr Whitlock. I am disappointed, which in my experience " \
			+ "is the more expensive of the two.",
		"",
		"See that the next is better.",
		"",
		"J. Hallow",
	])
	return out


static func _hostile(result: RitualResult) -> Array:
	var out: Array = [
		"Mr Whitlock,",
		"",
		"Twice, now. I am not a man who enjoys repeating himself, and I find " \
			+ "I am doing it in writing, which is worse.",
	]
	out.append_array(_fault_block(result, "Again:"))
	out.append_array([
		"",
		"You are handling my correspondence. You are not scribbling in a " \
			+ "ledger that nobody opens. Every one of these passes beneath " \
			+ "another man's eyes before it reaches mine, and every one of " \
			+ "them carries my name at the foot of it.",
		"",
		"I have defended you once already. I will not do it a second time.",
		"",
		"There will not be a third letter on this subject.",
		"",
		"J. Hallow",
	])
	return out


static func _rage(result: RitualResult) -> Array:
	var out: Array = [
		"WHITLOCK.",
		"",
		"Do not trouble yourself to reply. I have already written to Mr " \
			+ "Barrow, and to Colefax, and to two others besides, and told " \
			+ "them precisely what is done to a man's correspondence in that " \
			+ "room of yours.",
	]
	out.append_array(_fault_block(result, "This is what you sent out under my name:"))
	out.append_array([
		"",
		"My sister read that letter aloud at table. She thought it a jest. " \
			+ "She read it in the voice one uses for a jest, and the table " \
			+ "laughed, and I sat and let them.",
		"",
		"You have made me a joke in my own county. A joke, sir.",
		"",
		"I want nothing further from you. Not an apology, not a discount, " \
			+ "and not the pleasure of your explaining yourself to me.",
		"",
		"Your machine, your candle and your careful little rose can rot in " \
			+ "that room together.",
		"",
		"Do not write to me again.",
	])
	return out


# --------------------------------------------------------------------------

static func _wrap_all(paragraphs: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for p in paragraphs:
		var text := String(p)
		if text.is_empty():
			out.append("")
			continue
		for line in _wrap(text, WRAP):
			out.append(line)
	return out


## Greedy word wrap. Keeps a leading "  - " indent on continuation lines so a
## quoted fault stays visually attached to its bullet.
static func _wrap(text: String, width: int) -> PackedStringArray:
	var out := PackedStringArray()
	var indent := "    " if text.begins_with("  - ") else ""
	var words := text.split(" ", false)
	var line := ""
	for w: String in words:
		var candidate: String = w if line.is_empty() else line + " " + w
		if candidate.length() <= width:
			line = candidate
		else:
			if not line.is_empty():
				out.append(line)
			# a single word longer than the column has to be broken
			while w.length() > width:
				out.append(indent + w.substr(0, width - indent.length() - 1) + "-")
				w = w.substr(width - indent.length() - 1)
			line = indent + w
	if not line.is_empty():
		out.append(line)
	return out
