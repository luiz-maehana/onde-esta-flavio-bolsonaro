extends Node
## Autoload — toca música (com loop) e efeitos sonoros por nome. Mesmo papel
## do AudioManager do PPKMN; os WAV são gerados por tools/build_audio.gd.
## Pool pequeno de players de SFX pra um efeito não cortar o outro (a
## máquina de escrever do WitnessBox toca junto com cliques).

const MUSIC_DIR := "res://assets/audio/music/"
const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC := ["title", "city", "tension"]
const SFX := ["click", "type", "clue", "plane", "sleep", "pauta", "win", "lose", "alert"]
const SFX_POOL := 4

## Atalhos usados por UiTheme etc.
const SFX_CLICK := "click"
## Barramentos criados em tempo de execução: volume de música e de efeitos
## independentes (RF23), ambos passando pelo Master (mudo geral).
const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"

var _music_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _next_sfx := 0
var _streams: Dictionary = {}
var _current_music := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus(MUSIC_BUS)
	_ensure_bus(SFX_BUS)
	_music_player = AudioStreamPlayer.new()
	_music_player.volume_db = -12.0
	_music_player.bus = MUSIC_BUS
	add_child(_music_player)
	for i in SFX_POOL:
		var p := AudioStreamPlayer.new()
		p.volume_db = -6.0
		p.bus = SFX_BUS
		add_child(p)
		_sfx_players.append(p)
	for m in MUSIC:
		_streams["music/" + m] = _load(MUSIC_DIR + m + ".wav")
	for s in SFX:
		_streams["sfx/" + s] = _load(SFX_DIR + s + ".wav")

func _load(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		push_warning("AudioManager: falta %s (rodar tools/build_audio.gd)" % path)
		return null
	return load(path)

func play_music(music_name: String) -> void:
	if music_name == _current_music:
		return
	var stream: AudioStream = _streams.get("music/" + music_name)
	if stream == null:
		return
	_current_music = music_name
	if stream is AudioStreamWAV:
		## Sem loop_end o Godot entende a região de loop como vazia e para no
		## fim — mesma pegadinha documentada no PPKMN.
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
	_music_player.stream = stream
	_music_player.play()

func stop_music() -> void:
	_current_music = ""
	_music_player.stop()

func play_sfx(sfx_name: String, volume_db: float = -6.0) -> void:
	var stream: AudioStream = _streams.get("sfx/" + sfx_name)
	if stream == null:
		return
	var p := _sfx_players[_next_sfx]
	_next_sfx = (_next_sfx + 1) % SFX_POOL
	p.stream = stream
	p.volume_db = volume_db
	p.play()

func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")

## Volumes 0..1 viram dB; 0 silencia o barramento (linear_to_db(0) = -inf).
func apply_settings(settings: Settings) -> void:
	_set_bus_volume(MUSIC_BUS, settings.music_volume)
	_set_bus_volume(SFX_BUS, settings.sfx_volume)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), settings.muted)

func _set_bus_volume(bus_name: String, volume: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	AudioServer.set_bus_mute(idx, volume <= 0.0)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(volume, 0.0001)))
