extends Node
## Procedural background music loop. No audio assets are needed; the loop is
## generated over a few frames at startup to avoid a hitch on mobile/web.

signal mute_changed(muted: bool)

const SETTINGS_PATH := "user://settings.cfg"
const MIX_RATE := 16000
const CHORD_SECONDS := 2.0
const STEP_SECONDS := 0.25
const SAMPLES_PER_FRAME := 8000
# Am - F - C - G: [bass frequency, [chord tones]].
const CHORDS := [
	[110.0, [220.0, 261.63, 329.63]],
	[87.31, [174.61, 220.0, 261.63]],
	[130.81, [261.63, 329.63, 392.0]],
	[98.0, [196.0, 246.94, 293.66]],
]
const ARPEGGIO := [0, 1, 2, 1, 0, 2, 1, 2]

var muted := false
var _player: AudioStreamPlayer
var _data := PackedByteArray()
var _written := 0
var _total := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		muted = bool(config.get_value("audio", "music_muted", false))
	_player = AudioStreamPlayer.new()
	_player.name = "BackgroundMusic"
	_player.volume_db = -6.0
	add_child(_player)
	_total = int(MIX_RATE * CHORD_SECONDS * CHORDS.size())
	_data.resize(_total * 2)


func _process(_delta: float) -> void:
	var end := mini(_written + SAMPLES_PER_FRAME, _total)
	for i in range(_written, end):
		var value := clampf(_sample(float(i) / MIX_RATE), -1.0, 1.0)
		_data.encode_s16(i * 2, int(value * 32767.0))
	_written = end
	if _written >= _total:
		var stream := AudioStreamWAV.new()
		stream.format = AudioStreamWAV.FORMAT_16_BITS
		stream.mix_rate = MIX_RATE
		stream.stereo = false
		stream.data = _data
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = _total
		_player.stream = stream
		_data = PackedByteArray()
		set_process(false)
		_apply()


func _input(event: InputEvent) -> void:
	if Controls.console_open:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_M:
		toggle_mute()


func toggle_mute() -> void:
	set_muted(not muted)


func set_muted(value: bool) -> void:
	muted = value
	_apply()
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("audio", "music_muted", muted)
	config.save(SETTINGS_PATH)
	mute_changed.emit(muted)


func _apply() -> void:
	if _player == null or _player.stream == null:
		return
	if muted and _player.playing:
		_player.stop()
	elif not muted and not _player.playing:
		_player.play()


## Each chord fades in and out, and each pluck ends at zero, so the loop is seamless.
func _sample(t: float) -> float:
	var chord_index := int(t / CHORD_SECONDS) % CHORDS.size()
	var local := fposmod(t, CHORD_SECONDS)
	var chord: Array = CHORDS[chord_index]
	var tones: Array = chord[1]
	var envelope := clampf(local / 0.3, 0.0, 1.0) * clampf((CHORD_SECONDS - local) / 0.3, 0.0, 1.0)
	var value := sin(TAU * float(chord[0]) * t) * 0.2 * envelope
	for tone in tones:
		value += sin(TAU * float(tone) * t) * 0.07 * envelope
	var step := int(local / STEP_SECONDS)
	var note_time := maxf(local - step * STEP_SECONDS, 0.0)
	var pluck_freq := float(tones[ARPEGGIO[step % ARPEGGIO.size()]]) * 2.0
	var pluck_env := exp(-note_time * 9.0) * clampf(note_time / 0.004, 0.0, 1.0) \
		* clampf((STEP_SECONDS - note_time) / 0.01, 0.0, 1.0)
	value += sin(TAU * pluck_freq * note_time) * 0.12 * pluck_env
	return value
