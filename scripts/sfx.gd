extends Node
## Autoload "Sfx". Plays sound effects by name from assets/audio and runs the
## music. Missing files are skipped, so real sounds can be dropped in later
## under the same name as .ogg or .wav (.ogg wins).
##
##   Sfx.play("hit")           Sfx.play_music()

const DIR := "res://assets/audio/"
const VOICES := 12
const LOOPED := ["rewind_loop", "music_level"]
const MUSIC_DB := -9.0
## Music slows and drops in pitch while time runs backwards.
const REWIND_PITCH := 0.6

var _streams := {}
var _voices: Array[AudioStreamPlayer] = []
var _next := 0
var _music := AudioStreamPlayer.new()
var _rewind := AudioStreamPlayer.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		player.process_mode = Node.PROCESS_MODE_PAUSABLE # effects pause with the game
		add_child(player)
		_voices.append(player)
	_music.volume_db = MUSIC_DB
	add_child(_music)
	_rewind.volume_db = -8.0
	add_child(_rewind)
	Rewind.rewind_started.connect(_on_rewind_started)
	Rewind.rewind_ended.connect(_on_rewind_ended)


func _process(delta: float) -> void:
	var target := REWIND_PITCH if Rewind.is_rewinding else 1.0
	_music.pitch_scale = move_toward(_music.pitch_scale, target, delta * 2.5)


func play(sound: String, volume_db := 0.0, pitch_jitter := 0.06) -> void:
	var stream := _stream(sound)
	if stream == null:
		return
	var player := _voices[_next]
	_next = (_next + 1) % VOICES
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	player.play()


func play_music(track := "music_level") -> void:
	var stream := _stream(track)
	if stream == null or (_music.stream == stream and _music.playing):
		return
	_music.stream = stream
	_music.play()


func set_music_volume(db: float) -> void:
	_music.volume_db = db


func _on_rewind_started() -> void:
	_rewind.stream = _stream("rewind_loop")
	if _rewind.stream:
		_rewind.play()


func _on_rewind_ended(_undone_frames: Array) -> void:
	_rewind.stop()
	play("rewind_end", -2.0)


func _stream(sound: String) -> AudioStream:
	if _streams.has(sound):
		return _streams[sound]
	var stream: AudioStream = null
	for ext in [".ogg", ".wav"]:
		if ResourceLoader.exists(DIR + sound + ext):
			stream = load(DIR + sound + ext)
			break
	if stream and sound in LOOPED:
		if stream is AudioStreamWAV:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_begin = 0
			stream.loop_end = int(stream.get_length() * stream.mix_rate)
		elif stream is AudioStreamOggVorbis:
			stream.loop = true
	_streams[sound] = stream
	return stream
