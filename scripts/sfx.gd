extends Node
## Autoload "Sfx". Plays sounds from assets/audio by name, and silently does
## nothing for files that don't exist yet, so code can call it before the
## audio lands. Also runs the level music and the rewind loop.
##
##   Sfx.play("slash")   # assets/audio/slash.wav

const DIR := "res://assets/audio/"
const VOICES := 12

var _voices: Array[AudioStreamPlayer] = []
var _next := 0
var _cache := {}
var _music := AudioStreamPlayer.new()
var _rewind_loop := AudioStreamPlayer.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOICES:
		var voice := AudioStreamPlayer.new()
		voice.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(voice)
		_voices.append(voice)
	_music.volume_db = -8.0
	add_child(_music)
	_rewind_loop.volume_db = -4.0
	add_child(_rewind_loop)
	Rewind.rewind_started.connect(_on_rewind_started)
	Rewind.rewind_ended.connect(_on_rewind_ended)
	play_music("music_level")


func play(sound: String, pitch_jitter := 0.08) -> void:
	var stream := _load(sound + ".wav")
	if stream == null:
		return
	var voice := _voices[_next]
	_next = (_next + 1) % VOICES
	voice.stream = stream
	voice.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	voice.play()


func play_music(track: String) -> void:
	var stream := _load(track + ".ogg")
	if stream == null or _music.stream == stream:
		return
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	_music.stream = stream
	_music.play()


func _on_rewind_started() -> void:
	var stream := _load("rewind_loop.wav")
	if stream == null:
		return
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
	_rewind_loop.stream = stream
	_rewind_loop.play()
	_music.pitch_scale = 0.7


func _on_rewind_ended(_undone_frames: Array) -> void:
	_rewind_loop.stop()
	_music.pitch_scale = 1.0


func _load(file: String) -> AudioStream:
	if not _cache.has(file):
		var path := DIR + file
		_cache[file] = load(path) if ResourceLoader.exists(path) else null
	return _cache[file]
