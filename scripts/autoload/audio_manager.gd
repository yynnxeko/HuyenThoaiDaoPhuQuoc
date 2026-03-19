extends Node

## Audio manager singleton — procedural sound effects + music
## Generates all sounds programmatically (no audio files needed)

var music_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
const MAX_SFX_PLAYERS: int = 12

var music_volume: float = 0.6
var sfx_volume: float = 0.85

# Ambient ocean
var ambient_player: AudioStreamPlayer
var ambient_stream: AudioStreamGenerator
var ambient_playback: AudioStreamGeneratorPlayback
var ambient_time: float = 0.0

# Current music state
var current_music: String = ""


func _ready() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Master"
	add_child(music_player)
	
	for i in MAX_SFX_PLAYERS:
		var player = AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		sfx_players.append(player)
	
	# Set up ambient ocean generator
	ambient_player = AudioStreamPlayer.new()
	ambient_player.bus = "Master"
	ambient_stream = AudioStreamGenerator.new()
	ambient_stream.mix_rate = 22050.0
	ambient_stream.buffer_length = 0.5
	ambient_player.stream = ambient_stream
	add_child(ambient_player)
	ambient_player.play()
	ambient_playback = ambient_player.get_stream_playback()
	ambient_player.volume_db = linear_to_db(0.12)


func _process(delta: float) -> void:
	ambient_time += delta
	_fill_ambient_buffer()


func _fill_ambient_buffer() -> void:
	if ambient_playback == null:
		return
	var frames = ambient_playback.get_frames_available()
	if frames <= 0:
		return
	var rate = ambient_stream.mix_rate
	for i in range(frames):
		var t = ambient_time + float(i) / rate
		# Ocean waves: layered sine waves + filtered noise
		var wave1 = sin(t * 0.8) * 0.15
		var wave2 = sin(t * 1.3 + 0.5) * 0.1
		var wave3 = sin(t * 2.1 + 1.2) * 0.06
		# Surf noise (pseudo-random from sine)
		var noise = sin(t * 137.0 + sin(t * 59.0) * 3.0) * sin(t * 0.4) * 0.05
		var sample = (wave1 + wave2 + wave3 + noise) * sfx_volume * 0.3
		ambient_playback.push_frame(Vector2(sample, sample))


# ========= PROCEDURAL SOUND GENERATION =========

func _generate_tone(frequency: float, duration: float, volume: float = 0.5, 
					 attack: float = 0.01, decay: float = 0.1, 
					 waveform: String = "sine") -> AudioStreamWAV:
	var sample_rate = 22050
	var num_samples = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(num_samples * 2)  # 16-bit
	
	for i in range(num_samples):
		var t = float(i) / float(sample_rate)
		var env = 1.0
		# Attack
		if t < attack:
			env = t / attack
		# Decay at end
		var decay_start = duration - decay
		if t > decay_start:
			env = (duration - t) / decay
		
		var sample = 0.0
		match waveform:
			"sine":
				sample = sin(t * frequency * TAU)
			"square":
				sample = 1.0 if fmod(t * frequency, 1.0) < 0.5 else -1.0
				sample *= 0.4
			"noise":
				sample = sin(t * 1337.0 + sin(t * 997.0) * 5.0)
			"pluck":
				sample = sin(t * frequency * TAU) * exp(-t * 8.0)
		
		sample *= env * volume
		sample = clampf(sample, -1.0, 1.0)
		var s16 = int(sample * 32767.0)
		data[i * 2] = s16 & 0xFF
		data[i * 2 + 1] = (s16 >> 8) & 0xFF
	
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream


func _generate_multi_tone(notes: Array, duration: float, volume: float = 0.4) -> AudioStreamWAV:
	var sample_rate = 22050
	var num_samples = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(num_samples * 2)
	
	for i in range(num_samples):
		var t = float(i) / float(sample_rate)
		var sample = 0.0
		
		for note in notes:
			var freq = note["freq"]
			var start = note.get("start", 0.0)
			var dur = note.get("dur", duration)
			var nt = t - start
			if nt < 0 or nt > dur:
				continue
			var env = 1.0
			if nt < 0.02:
				env = nt / 0.02
			if nt > dur - 0.05:
				env = (dur - nt) / 0.05
			sample += sin(nt * freq * TAU) * env * note.get("vol", 0.3)
		
		sample *= volume
		sample = clampf(sample, -1.0, 1.0)
		var s16 = int(sample * 32767.0)
		data[i * 2] = s16 & 0xFF
		data[i * 2 + 1] = (s16 >> 8) & 0xFF
	
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream


# ========= GAME SOUND EFFECTS =========

func play_cast() -> void:
	# Whoosh sound: descending tone
	var stream = _generate_tone(800, 0.3, 0.25, 0.01, 0.15, "noise")
	_play_generated_sfx(stream, 0.6)


func play_splash(intensity: float = 1.0) -> void:
	# Water splash: short noise burst
	var stream = _generate_tone(200, 0.2 * intensity, 0.3, 0.005, 0.1, "noise")
	_play_generated_sfx(stream, 0.5 * intensity)


func play_bite_alert() -> void:
	# Quick alert chime: two rising tones
	var stream = _generate_multi_tone([
		{"freq": 880, "start": 0.0, "dur": 0.12, "vol": 0.4},
		{"freq": 1320, "start": 0.1, "dur": 0.15, "vol": 0.35},
	], 0.3, 0.5)
	_play_generated_sfx(stream, 0.7)


func play_reel_tick() -> void:
	# Short clicking sound for reeling
	var stream = _generate_tone(600, 0.05, 0.2, 0.002, 0.02, "pluck")
	_play_generated_sfx(stream, 0.3)


func play_catch_success() -> void:
	# Victory jingle: ascending chord
	var stream = _generate_multi_tone([
		{"freq": 523, "start": 0.0, "dur": 0.2, "vol": 0.35},
		{"freq": 659, "start": 0.1, "dur": 0.2, "vol": 0.35},
		{"freq": 784, "start": 0.2, "dur": 0.3, "vol": 0.35},
		{"freq": 1047, "start": 0.3, "dur": 0.4, "vol": 0.4},
	], 0.8, 0.5)
	_play_generated_sfx(stream, 0.8)


func play_catch_legendary() -> void:
	# Epic victory fanfare
	var stream = _generate_multi_tone([
		{"freq": 523, "start": 0.0, "dur": 0.15, "vol": 0.4},
		{"freq": 659, "start": 0.08, "dur": 0.15, "vol": 0.35},
		{"freq": 784, "start": 0.16, "dur": 0.2, "vol": 0.35},
		{"freq": 1047, "start": 0.3, "dur": 0.25, "vol": 0.4},
		{"freq": 1319, "start": 0.45, "dur": 0.25, "vol": 0.4},
		{"freq": 1568, "start": 0.6, "dur": 0.5, "vol": 0.45},
	], 1.2, 0.55)
	_play_generated_sfx(stream, 1.0)


func play_fish_escape() -> void:
	# Sad descending tone
	var stream = _generate_multi_tone([
		{"freq": 600, "start": 0.0, "dur": 0.2, "vol": 0.3},
		{"freq": 450, "start": 0.15, "dur": 0.2, "vol": 0.25},
		{"freq": 300, "start": 0.3, "dur": 0.3, "vol": 0.2},
	], 0.65, 0.4)
	_play_generated_sfx(stream, 0.6)


func play_line_snap() -> void:
	# Sharp snap sound
	var stream = _generate_tone(1200, 0.08, 0.5, 0.001, 0.04, "noise")
	_play_generated_sfx(stream, 0.7)


func play_ui_click() -> void:
	var stream = _generate_tone(1000, 0.06, 0.2, 0.002, 0.03, "pluck")
	_play_generated_sfx(stream, 0.4)


func play_ui_open() -> void:
	var stream = _generate_multi_tone([
		{"freq": 600, "start": 0.0, "dur": 0.1, "vol": 0.25},
		{"freq": 900, "start": 0.05, "dur": 0.12, "vol": 0.2},
	], 0.2, 0.4)
	_play_generated_sfx(stream, 0.5)


func play_ui_close() -> void:
	var stream = _generate_multi_tone([
		{"freq": 900, "start": 0.0, "dur": 0.1, "vol": 0.2},
		{"freq": 600, "start": 0.05, "dur": 0.12, "vol": 0.25},
	], 0.2, 0.4)
	_play_generated_sfx(stream, 0.5)


func play_sell_fish() -> void:
	# Coin sound
	var stream = _generate_multi_tone([
		{"freq": 1500, "start": 0.0, "dur": 0.08, "vol": 0.3},
		{"freq": 2000, "start": 0.06, "dur": 0.12, "vol": 0.25},
	], 0.2, 0.4)
	_play_generated_sfx(stream, 0.5)


func play_upgrade() -> void:
	# Power-up sound
	var stream = _generate_multi_tone([
		{"freq": 400, "start": 0.0, "dur": 0.1, "vol": 0.3},
		{"freq": 600, "start": 0.08, "dur": 0.1, "vol": 0.3},
		{"freq": 900, "start": 0.16, "dur": 0.15, "vol": 0.35},
		{"freq": 1200, "start": 0.25, "dur": 0.2, "vol": 0.3},
	], 0.5, 0.5)
	_play_generated_sfx(stream, 0.7)


func play_boss_appear() -> void:
	# Deep ominous rumble + horn
	var stream = _generate_multi_tone([
		{"freq": 55, "start": 0.0, "dur": 1.5, "vol": 0.5},
		{"freq": 82, "start": 0.0, "dur": 1.5, "vol": 0.35},
		{"freq": 110, "start": 0.3, "dur": 1.0, "vol": 0.3},
		{"freq": 165, "start": 0.8, "dur": 0.8, "vol": 0.25},
		{"freq": 220, "start": 1.0, "dur": 0.6, "vol": 0.2},
	], 1.8, 0.6)
	_play_generated_sfx(stream, 1.0)


func play_boss_phase() -> void:
	# Dramatic transition
	var stream = _generate_multi_tone([
		{"freq": 200, "start": 0.0, "dur": 0.15, "vol": 0.4},
		{"freq": 300, "start": 0.1, "dur": 0.15, "vol": 0.35},
		{"freq": 400, "start": 0.2, "dur": 0.2, "vol": 0.3},
	], 0.5, 0.5)
	_play_generated_sfx(stream, 0.7)


func play_bobber_dip() -> void:
	# Small water sound
	var stream = _generate_tone(350, 0.1, 0.15, 0.005, 0.05, "noise")
	_play_generated_sfx(stream, 0.3)


func play_zone_enter() -> void:
	# Atmospheric chime
	var stream = _generate_multi_tone([
		{"freq": 523, "start": 0.0, "dur": 0.3, "vol": 0.2},
		{"freq": 784, "start": 0.15, "dur": 0.35, "vol": 0.2},
		{"freq": 1047, "start": 0.3, "dur": 0.4, "vol": 0.15},
	], 0.8, 0.35)
	_play_generated_sfx(stream, 0.5)


# ========= INTERNAL =========

func _play_generated_sfx(stream: AudioStream, volume_scale: float = 1.0) -> void:
	for player in sfx_players:
		if not player.playing:
			player.stream = stream
			player.volume_db = linear_to_db(sfx_volume * volume_scale)
			player.play()
			return
	sfx_players[0].stream = stream
	sfx_players[0].volume_db = linear_to_db(sfx_volume * volume_scale)
	sfx_players[0].play()


func play_music(stream: AudioStream, _fade_in: float = 1.0) -> void:
	if stream == null:
		return
	music_player.stream = stream
	music_player.volume_db = linear_to_db(music_volume)
	music_player.play()


func stop_music(_fade_out: float = 1.0) -> void:
	music_player.stop()


func play_sfx(stream: AudioStream, volume_scale: float = 1.0) -> void:
	if stream == null:
		return
	_play_generated_sfx(stream, volume_scale)


func set_music_volume(vol: float) -> void:
	music_volume = clampf(vol, 0.0, 1.0)
	music_player.volume_db = linear_to_db(music_volume)


func set_sfx_volume(vol: float) -> void:
	sfx_volume = clampf(vol, 0.0, 1.0)
