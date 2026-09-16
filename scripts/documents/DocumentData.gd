class_name DocumentData
extends Resource
## A document the player is paid to transcribe.
##
## Lines are pre-broken to the machine's line width rather than wrapped at
## runtime, because on a typewriter the typist decides where a line ends - the
## hyphenation is part of the writing, and forcing the player to type a hyphen
## and then throw the carriage is the job.

@export var title: String = "Untitled"
@export var sender: String = ""
@export var recipient: String = ""
## The address is PRE-PRINTED on the envelope, not typed by the player, so a
## mangled address can never be one of their faults. Three short lines.
@export var address: PackedStringArray = PackedStringArray()
## Replies are read, never typed. They wrap wider and skip the machine entirely.
@export var is_reply: bool = false
@export var tone: int = 0
## Fee in pence, for the day loop this plugs into later.
@export var fee: int = 0
@export_multiline var notes: String = ""

@export var lines: PackedStringArray = PackedStringArray()


func line_count() -> int:
	return lines.size()


func line(i: int) -> String:
	if i < 0 or i >= lines.size():
		return ""
	return lines[i]


func total_chars() -> int:
	var n := 0
	for l in lines:
		n += l.length()
	return n


## Lines that would not fit the machine. Empty means the document is typeable.
func validate(cols: int) -> PackedStringArray:
	var bad := PackedStringArray()
	for i in lines.size():
		if lines[i].length() > cols:
			bad.append("line %d is %d chars (max %d): %s"
				% [i, lines[i].length(), cols, lines[i]])
	return bad
