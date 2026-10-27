class_name Settings
extends RefCounted
## Preferências do jogador (RF23) + persistência própria, separada da
## carreira. Tolerante a arquivo adulterado como o SaveService.

const PATH := "user://onde_esta_flavio_settings.json"
const MAX_BYTES := 8192
const TEXT_SPEEDS := ["lenta", "normal", "instantanea"]
## Caracteres por segundo de cada velocidade (0 = instantâneo).
const CHARS_PER_SECOND := {"lenta": 30.0, "normal": 60.0, "instantanea": 0.0}
const MAX_SEEN_TIPS := 64

var music_volume := 0.8
var sfx_volume := 0.9
var muted := false
var fullscreen := false
var text_speed := "normal"
var tips_enabled := true
var seen_tips: Array = []

func chars_per_second() -> float:
	return CHARS_PER_SECOND[text_speed]

func to_dict() -> Dictionary:
	return {
		"music_volume": music_volume, "sfx_volume": sfx_volume, "muted": muted,
		"fullscreen": fullscreen, "text_speed": text_speed,
		"tips_enabled": tips_enabled, "seen_tips": seen_tips,
	}

static func from_dict(d: Dictionary) -> Settings:
	var s := Settings.new()
	s.music_volume = _unit(d.get("music_volume"), s.music_volume)
	s.sfx_volume = _unit(d.get("sfx_volume"), s.sfx_volume)
	s.muted = _bool(d.get("muted"), false)
	s.fullscreen = _bool(d.get("fullscreen"), false)
	s.tips_enabled = _bool(d.get("tips_enabled"), true)
	var speed = d.get("text_speed")
	if typeof(speed) == TYPE_STRING and TEXT_SPEEDS.has(speed):
		s.text_speed = speed
	var tips = d.get("seen_tips", [])
	if typeof(tips) == TYPE_ARRAY:
		for t in tips:
			if typeof(t) == TYPE_STRING and t.length() <= 32 and not s.seen_tips.has(t) and s.seen_tips.size() < MAX_SEEN_TIPS:
				s.seen_tips.append(t)
	return s

## Só booleano de verdade conta (comparar String com bool é erro no Godot 4).
static func _bool(v: Variant, fallback: bool) -> bool:
	return v if typeof(v) == TYPE_BOOL else fallback

## Número entre 0 e 1; qualquer outra coisa vira o padrão.
static func _unit(v: Variant, fallback: float) -> float:
	if typeof(v) != TYPE_INT and typeof(v) != TYPE_FLOAT:
		return fallback
	var f := float(v)
	if is_nan(f):
		return fallback
	return clampf(f, 0.0, 1.0)

func save() -> void:
	if SaveService.read_only:
		return
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(to_dict(), "\t"))

static func load_or_default() -> Settings:
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES:
		return Settings.new()
	var data = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return Settings.new()
	return from_dict(data)
