class_name Sfx
extends Node
## Placeholder sounds synthesized at startup, so the prototype ships no audio files.

enum Sound { CLICK, PLACE, KILL, NETWORK, SOCIAL, MALWARE, ALARM }

const MIX_RATE := 22050
const MIN_REPEAT_SECONDS := 0.08
const TONES := {
	Sound.CLICK: [880.0, 0.04],
	Sound.PLACE: [520.0, 0.09],
	Sound.KILL: [1200.0, 0.03],
	Sound.NETWORK: [220.0, 0.12],
	Sound.SOCIAL: [660.0, 0.2],
	Sound.MALWARE: [140.0, 0.2],
	Sound.ALARM: [440.0, 0.45],
}

var _players: Dictionary = {}
var _last_played: Dictionary = {}


func _ready() -> void:
	for sound: Sound in TONES:
		var player := AudioStreamPlayer.new()
		player.stream = _tone(TONES[sound][0], TONES[sound][1])
		player.volume_db = -12.0
		add_child(player)
		_players[sound] = player


func play(sound: Sound) -> void:
	if not _players.has(sound):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_played.get(sound, -1.0) < MIN_REPEAT_SECONDS:
		return
	_last_played[sound] = now
	_players[sound].play()


func play_breach(attack: AttackData) -> void:
	play(Sound.ALARM)
	match attack.family:
		GameTypes.Family.NETWORK:
			play(Sound.NETWORK)
		GameTypes.Family.MALWARE:
			play(Sound.MALWARE)


func _tone(frequency: float, seconds: float) -> AudioStreamWAV:
	var count := int(MIX_RATE * seconds)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var fade := 1.0 - float(i) / count
		var sample := sin(TAU * frequency * i / MIX_RATE) * fade
		data.encode_s16(i * 2, int(sample * 28000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.data = data
	return stream
