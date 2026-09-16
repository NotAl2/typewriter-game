extends Node
## Pooled one-shot playback plus a few persistent ambience loops.
##
## Every one-shot goes out with a small random pitch and volume offset. Without
## it, holding down a key produces a machine-gun of identical samples and the
## illusion of a physical machine collapses immediately - the variance matters
## more than the sample quality does.

const SFX_DIR := "res://assets/audio/"
const POOL_SIZE := 16

## Sounds that must never be pitch-shifted (a bell that wanders sounds broken).
const FIXED_PITCH := ["bell", "chime_complete"]

## Sounds that loop as ambience rather than firing once.
const AMBIENCE := ["room_tone", "rain", "candle_crackle"]

var _cache: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _ambience: Dictionary = {}
var _key_clack_count := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_pool.append(p)
	while ResourceLoader.exists(SFX_DIR + "key_clack_%d.wav" % (_key_clack_count + 1)):
		_key_clack_count += 1


func _stream(name: String) -> AudioStream:
	if _cache.has(name):
		return _cache[name]
	var path := SFX_DIR + name + ".wav"
	if not ResourceLoader.exists(path):
		push_warning("Audio: missing sound '%s'" % name)
		_cache[name] = null
		return null
	var s: AudioStream = load(path)
	if s is AudioStreamWAV and name in AMBIENCE:
		(s as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		(s as AudioStreamWAV).loop_end = (s as AudioStreamWAV).data.size() / 2
	_cache[name] = s
	return s


## Fire a one-shot. `pitch` and `volume_db` are offsets applied on top of the
## automatic humanising jitter.
func play(name: String, pitch := 1.0, volume_db := 0.0, spread := 0.06) -> void:
	var s := _stream(name)
	if s == null:
		return
	var p := _pool[_next]
	_next = (_next + 1) % POOL_SIZE
	p.stream = s
	if name in FIXED_PITCH:
		p.pitch_scale = pitch
	else:
		p.pitch_scale = maxf(0.05, pitch + randf_range(-spread, spread))
	p.volume_db = volume_db + linear_to_db(Settings.volume_master * Settings.volume_sfx) \
		+ randf_range(-1.2, 1.2)
	p.play()


## A keystroke, drawn from the clack variants so consecutive presses differ.
func play_key(speed_factor := 0.0) -> void:
	if _key_clack_count <= 0:
		return
	var idx := randi_range(1, _key_clack_count)
	# typing faster makes the machine ring a little brighter and harder
	play("key_clack_%d" % idx, 1.0 + speed_factor * 0.06,
		 -1.0 + speed_factor * 2.0, 0.05)
	if randf() < 0.55:
		play("typebar_strike", 1.0 + randf_range(-0.08, 0.08), -9.0)


func start_ambience() -> void:
	for name in AMBIENCE:
		if _ambience.has(name):
			continue
		var s := _stream(name)
		if s == null:
			continue
		var p := AudioStreamPlayer.new()
		p.stream = s
		p.volume_db = linear_to_db(Settings.volume_master * Settings.volume_ambience) \
			+ (-6.0 if name == "candle_crackle" else 0.0)
		add_child(p)
		p.finished.connect(func() -> void:
			# WAV loop flags do not survive every import path, so restart by hand
			if is_instance_valid(p):
				p.play())
		p.play()
		_ambience[name] = p


func stop_ambience() -> void:
	for p in _ambience.values():
		if is_instance_valid(p):
			p.queue_free()
	_ambience.clear()


## Sustained sizzle while wax is held in the flame; call stop_loop to end it.
func start_loop(name: String, volume_db := -6.0) -> void:
	if _ambience.has(name):
		return
	var s := _stream(name)
	if s == null:
		return
	if s is AudioStreamWAV:
		(s as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.volume_db = volume_db + linear_to_db(Settings.volume_master * Settings.volume_sfx)
	add_child(p)
	p.finished.connect(func() -> void:
		if is_instance_valid(p):
			p.play())
	p.play()
	_ambience[name] = p


func stop_loop(name: String) -> void:
	if _ambience.has(name):
		var p: AudioStreamPlayer = _ambience[name]
		if is_instance_valid(p):
			p.queue_free()
		_ambience.erase(name)


func set_loop_pitch(name: String, pitch: float) -> void:
	if _ambience.has(name):
		var p: AudioStreamPlayer = _ambience[name]
		if is_instance_valid(p):
			p.pitch_scale = pitch
