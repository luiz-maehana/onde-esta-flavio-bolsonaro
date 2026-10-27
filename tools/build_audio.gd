extends SceneTree
## Gera toda a trilha e os efeitos do jogo por síntese (WAV 16-bit mono
## 22050 Hz) — mesma técnica do tools/build_sfx.gd do PPKMN, ampliada com
## sequenciador de notas pra trilhas em loop. Guardado (não descartável) pra
## recalibrar volume/andamento sem refazer do zero.
## Roda com: godot --headless --path . --script res://tools/build_audio.gd

const MIX_RATE := 22050
const MUSIC_DIR := "res://assets/audio/music/"
const SFX_DIR := "res://assets/audio/sfx/"

var _rng := RandomNumberGenerator.new()

func _initialize() -> void:
	_rng.seed = 1
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MUSIC_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SFX_DIR))
	_save(MUSIC_DIR + "title.wav", _title_theme())
	_save(MUSIC_DIR + "city.wav", _city_theme())
	_save(MUSIC_DIR + "tension.wav", _tension_theme())
	_save(SFX_DIR + "click.wav", _click())
	_save(SFX_DIR + "type.wav", _type())
	_save(SFX_DIR + "clue.wav", _clue())
	_save(SFX_DIR + "plane.wav", _plane())
	_save(SFX_DIR + "sleep.wav", _sleep())
	_save(SFX_DIR + "pauta.wav", _pauta())
	_save(SFX_DIR + "win.wav", _win())
	_save(SFX_DIR + "lose.wav", _lose())
	_save(SFX_DIR + "alert.wav", _alert())
	quit()

func _save(path: String, samples: PackedFloat32Array) -> void:
	_normalize(samples, 0.85)
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, clampi(int(samples[i] * 32767.0), -32768, 32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = bytes
	stream.save_to_wav(path)
	print("saved: ", path, " (", "%.1f" % (samples.size() / float(MIX_RATE)), "s)")

## --- Síntese ---------------------------------------------------------------

static func midi_hz(note: float) -> float:
	return 440.0 * pow(2.0, (note - 69.0) / 12.0)

func _buffer(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * MIX_RATE))
	return b

func _osc(wave: String, phase: float) -> float:
	var p := fmod(phase, 1.0)
	match wave:
		"square":
			return 1.0 if p < 0.5 else -1.0
		"pulse":
			return 1.0 if p < 0.25 else -1.0
		"triangle":
			return 4.0 * absf(p - 0.5) - 1.0
		"saw":
			return 2.0 * p - 1.0
	return sin(p * TAU)

## Soma uma nota ao buffer: ataque curto, decaimento exponencial `decay`
## (por segundo) e corte suave no fim. `slide` desliza a frequência
## (multiplicador final), usado em efeitos.
func _note(buf: PackedFloat32Array, start: float, dur: float, freq: float, amp: float, wave: String = "sine", decay: float = 2.0, slide: float = 1.0, vibrato: float = 0.0) -> void:
	var s0 := int(start * MIX_RATE)
	var n := int(dur * MIX_RATE)
	var phase := 0.0
	var attack := int(0.006 * MIX_RATE)
	var release := mini(int(0.03 * MIX_RATE), n / 2)
	for i in n:
		var idx := s0 + i
		if idx >= buf.size():
			break
		var t := float(i) / MIX_RATE
		var f := freq * lerpf(1.0, slide, float(i) / n)
		if vibrato > 0.0:
			f *= 1.0 + vibrato * sin(t * TAU * 6.0)
		phase += f / MIX_RATE
		var env := exp(-decay * t)
		if i < attack:
			env *= float(i) / attack
		if i > n - release:
			env *= float(n - i) / release
		buf[idx] += _osc(wave, phase) * amp * env

## Ruído (bateria, chiado). `bright` = passa-alta (prato); sem ele, ruído
## filtrado mais grave (caixa abafada/vento).
func _noise(buf: PackedFloat32Array, start: float, dur: float, amp: float, decay: float, bright: bool = true) -> void:
	var s0 := int(start * MIX_RATE)
	var n := int(dur * MIX_RATE)
	var prev := 0.0
	var low := 0.0
	for i in n:
		var idx := s0 + i
		if idx >= buf.size():
			break
		var w := _rng.randf_range(-1.0, 1.0)
		var v: float
		if bright:
			v = w - prev
		else:
			low += (w - low) * 0.15
			v = low * 2.0
		prev = w
		buf[idx] += v * amp * exp(-decay * float(i) / MIX_RATE)

func _kick(buf: PackedFloat32Array, start: float, amp: float = 0.6) -> void:
	_note(buf, start, 0.18, 110.0, amp, "sine", 18.0, 0.35)

func _normalize(buf: PackedFloat32Array, peak: float) -> void:
	var m := 0.0001
	for v in buf:
		m = maxf(m, absf(v))
	var k := peak / m
	for i in buf.size():
		buf[i] = buf[i] * k

## --- Trilhas -----------------------------------------------------------------

## Tema de título: clima "espião" em mi menor, 132 bpm, 8 compassos.
## Riff cromático de baixo (E-F#-G-F#) + melodia em onda quadrada + bateria.
func _title_theme() -> PackedFloat32Array:
	var e := 60.0 / 132.0 / 2.0
	var bars := 8
	var buf := _buffer(e * 8 * bars)
	var riff_e := [40, 40, 42, 42, 43, 43, 42, 42]
	var riff_a := [45, 45, 47, 47, 48, 48, 47, 47]
	var plan := [riff_e, riff_e, riff_a, riff_e, riff_e, riff_e, riff_a, riff_a]
	for bar in bars:
		var riff: Array = plan[bar]
		for i in 8:
			var t := (bar * 8 + i) * e
			_note(buf, t, e * 0.9, midi_hz(riff[i]), 0.42, "triangle", 3.0)
			_noise(buf, t, 0.05, 0.05 if i % 2 == 0 else 0.03, 60.0)
			if i == 0 or i == 4:
				_kick(buf, t)
			if i == 2 or i == 6:
				_noise(buf, t, 0.14, 0.16, 22.0, false)
	# [nota, início em colcheias, duração em colcheias]
	var melody := [
		[64, 0, 6], [67, 6, 2], [66, 8, 4], [64, 12, 4],
		[71, 16, 3], [72, 19, 1], [71, 20, 4], [69, 24, 8],
		[64, 32, 6], [67, 38, 2], [66, 40, 4], [64, 44, 4],
		[76, 48, 2], [75, 50, 2], [74, 52, 2], [73, 54, 2], [72, 56, 4], [71, 60, 4],
	]
	for m in melody:
		_note(buf, m[1] * e, m[2] * e * 0.95, midi_hz(m[0]), 0.16, "square", 1.2, 1.0, 0.004)
	return buf

## Trilha das cidades: bossa leve, 100 bpm, acordes de vibrafone (senoide
## com decaimento) + baixo + chocalho.
func _city_theme() -> PackedFloat32Array:
	var beat := 60.0 / 100.0
	var chords := [
		[57, 60, 64, 67], [50, 54, 57, 60], [55, 59, 62, 66], [48, 52, 55, 59],
		[54, 57, 60, 64], [47, 51, 54, 57], [52, 55, 59, 62], [52, 55, 59, 62],
	]
	var buf := _buffer(beat * 4 * chords.size())
	for bar in chords.size():
		var t0 := bar * 4 * beat
		var ch: Array = chords[bar]
		# baixo bossa: tônica no 1, quinta no "e" do 2, tônica no 3...
		_note(buf, t0, beat * 1.4, midi_hz(ch[0] - 12), 0.4, "triangle", 2.5)
		_note(buf, t0 + beat * 1.5, beat * 0.5, midi_hz(ch[0] - 5), 0.32, "triangle", 3.0)
		_note(buf, t0 + beat * 2, beat * 1.4, midi_hz(ch[0] - 12), 0.4, "triangle", 2.5)
		_note(buf, t0 + beat * 3.5, beat * 0.5, midi_hz(ch[0] - 5), 0.32, "triangle", 3.0)
		for hit in [0.0, 1.5, 2.5, 3.0]:
			for n in ch:
				_note(buf, t0 + hit * beat, beat * 0.9, midi_hz(n), 0.07, "sine", 4.0)
		for k in 8:
			_noise(buf, t0 + k * beat * 0.5, 0.04, 0.035 if k % 2 == 1 else 0.02, 70.0)
		# frase de vibrafone por cima, uma nota do acorde uma oitava acima
		_note(buf, t0 + beat * 0.5, beat * 1.0, midi_hz(ch[3] + 12), 0.1, "sine", 2.5)
		_note(buf, t0 + beat * 2.0, beat * 1.5, midi_hz(ch[2] + 12), 0.1, "sine", 2.0)
	return buf

## Tensão (última cidade / prazo curto): ostinato rápido em ré menor.
func _tension_theme() -> PackedFloat32Array:
	var s := 60.0 / 150.0 / 4.0
	var bars := 4
	var buf := _buffer(s * 16 * bars)
	var roots := [38, 38, 41, 36]
	for bar in bars:
		for i in 16:
			var t := (bar * 16 + i) * s
			var n: int = roots[bar] + ([0, 12, 7, 12][i % 4])
			_note(buf, t, s * 0.9, midi_hz(n), 0.28, "pulse", 6.0)
			if i % 4 == 0:
				_kick(buf, t, 0.7)
			if i % 8 == 4:
				_noise(buf, t, 0.12, 0.18, 25.0, false)
			_noise(buf, t, 0.03, 0.03, 80.0)
		_note(buf, bar * 16 * s, 16 * s, midi_hz(roots[bar] + 24 + 3), 0.08, "saw", 0.5, 1.0, 0.006)
	return buf

## --- Efeitos -----------------------------------------------------------------

func _click() -> PackedFloat32Array:
	var b := _buffer(0.06)
	_note(b, 0, 0.05, 1320, 0.5, "square", 40.0)
	return b

## Tecla de máquina de escrever (WitnessBox).
func _type() -> PackedFloat32Array:
	var b := _buffer(0.04)
	_noise(b, 0, 0.035, 0.6, 120.0)
	_note(b, 0, 0.02, 2200, 0.15, "square", 100.0)
	return b

func _clue() -> PackedFloat32Array:
	var b := _buffer(0.4)
	_note(b, 0, 0.12, midi_hz(76), 0.4, "square", 6.0)
	_note(b, 0.1, 0.28, midi_hz(83), 0.4, "square", 5.0)
	return b

func _plane() -> PackedFloat32Array:
	var b := _buffer(1.8)
	_noise(b, 0, 1.8, 0.5, 1.2, false)
	_note(b, 0, 1.8, 140, 0.25, "saw", 0.8, 1.6)
	return b

func _sleep() -> PackedFloat32Array:
	var b := _buffer(1.4)
	for i in 3:
		_note(b, i * 0.35, 0.6, midi_hz([79, 76, 72][i]), 0.35, "sine", 3.0)
	return b

## Carimbo da pauta: baque grave + sininho.
func _pauta() -> PackedFloat32Array:
	var b := _buffer(0.7)
	_kick(b, 0, 0.9)
	_noise(b, 0, 0.12, 0.5, 30.0, false)
	_note(b, 0.12, 0.5, midi_hz(88), 0.25, "sine", 5.0)
	return b

func _win() -> PackedFloat32Array:
	var b := _buffer(2.2)
	var notes := [60, 64, 67, 72]
	for i in notes.size():
		_note(b, i * 0.14, 0.3, midi_hz(notes[i]), 0.35, "square", 4.0)
	for n in [72, 76, 79, 84]:
		_note(b, 0.6, 1.5, midi_hz(n), 0.15, "square", 1.2, 1.0, 0.006)
	_kick(b, 0.6, 0.6)
	return b

## Trombone triste.
func _lose() -> PackedFloat32Array:
	var b := _buffer(2.4)
	var notes := [62, 61, 60]
	for i in notes.size():
		_note(b, i * 0.45, 0.42, midi_hz(notes[i]), 0.4, "saw", 1.5, 1.0, 0.01)
	_note(b, 1.35, 1.0, midi_hz(59), 0.4, "saw", 1.0, 0.97, 0.025)
	return b

func _alert() -> PackedFloat32Array:
	var b := _buffer(0.5)
	_note(b, 0, 0.15, 988, 0.4, "square", 4.0)
	_note(b, 0.22, 0.15, 988, 0.4, "square", 4.0)
	return b
