extends Node
## Tuning and accessibility flags.
##
## Two of these are not accessibility options at all - `uppercase_only` and
## `blind_write` are the historically accurate Remington No. 1 behaviours, left
## wired up and switched off. The No. 1 typed only capitals and struck the
## UNDERSIDE of the platen, so the typist could not see a word until they rolled
## the paper up. That is a devastating horror mechanic for later in the game -
## what appears on the page need not be what the player typed - so the code path
## stays live rather than being something to retrofit.

const CONFIG_PATH := "user://settings.cfg"

# --- authenticity ---------------------------------------------------------

## Remington No. 1 had no shift key. Off: the machine behaves like a No. 2.
var uppercase_only := false
## Hide typed text until the platen is rolled up far enough to read it.
var blind_write := false

# --- accessibility --------------------------------------------------------

## Let Enter perform the carriage return instead of requiring the lever drag.
var assist_carriage_return := false
## Scales how often typebars clash. 0.0 disables jamming entirely.
var jam_rate_scale := 1.0
## Grows every draggable's hit area by this many pixels.
var drag_assist := 0.0
## Suppress the small camera kicks on slams, jams and stamp presses.
var reduced_shake := false

# --- volumes --------------------------------------------------------------

## Set once the player has been through (or dismissed) the guide.
var tutorial_seen := false

var volume_master := 0.9
var volume_sfx := 1.0
var volume_ambience := 0.55


func _ready() -> void:
	load_settings()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return
	for prop in _persisted():
		if cfg.has_section_key("settings", prop):
			set(prop, cfg.get_value("settings", prop))


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for prop in _persisted():
		cfg.set_value("settings", prop, get(prop))
	cfg.save(CONFIG_PATH)


func _persisted() -> PackedStringArray:
	return PackedStringArray([
		"uppercase_only", "blind_write", "assist_carriage_return",
		"jam_rate_scale", "drag_assist", "reduced_shake",
		"volume_master", "volume_sfx", "volume_ambience", "tutorial_seen",
	])
