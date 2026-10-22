class_name Sfx
extends Node
## Plays the synthesised sounds in sounds/, a few at a time, and the music. People talk by
## mumbling syllables, a few to every word, pitched to who's talking.

const NAMES := ["plop", "bubble", "puff", "slosh", "zap", "blorp", "hiss", "cork", "coins", "tick", "tap",
		"cheer", "huff", "night", "win", "lose"]

static var me: Sfx

var muted := false
var _streams := {}
var _voices := {"witch": [], "folk": []}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _music: AudioStreamPlayer


func _ready() -> void:
	me = self
	for n: String in NAMES:
		_streams[n] = load("res://sounds/%s.res" % n)
	for who: String in _voices:
		for k in 6:
			_voices[who].append(load("res://sounds/%s_%d.res" % [who, k]))
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	_music.stream = load("res://sounds/music.res")
	_music.volume_db = -7.0
	add_child(_music)


static func play(name: String, pitch := 1.0, volume_db := 0.0) -> void:
	if me == null or me.muted:
		return
	me._play(me._streams[name], pitch, volume_db)


## One mumbled syllable, as `who` ("witch" or "folk") at `pitch`
static func say(who: String, pitch := 1.0) -> void:
	if me == null or me.muted:
		return
	var set: Array = me._voices[who]
	me._play(set[randi() % set.size()], pitch * randf_range(0.88, 1.15), -3.0)


static func music(on: bool, speed := 1.0) -> void:
	if me == null:
		return
	var m := me._music
	m.pitch_scale = speed
	if on and not me.muted and not m.playing:
		m.play()
	elif (not on or me.muted) and m.playing:
		m.stop()


static func set_muted(value: bool) -> void:
	if me == null:
		return
	me.muted = value
	if value:
		me._music.stop()
		for p in me._pool:
			p.stop()


func _play(stream: AudioStream, pitch: float, volume_db: float) -> void:
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = stream
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.play()
