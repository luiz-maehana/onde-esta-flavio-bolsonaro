class_name PixelPortrait
extends RefCounted
## Fachada dos retratos usada pelas telas (spec 003): devolve textura pronta,
## com cache. Os retratos são gerados por PortraitFactory, mas uma imagem em
## assets/portraits/<nome>.png substitui o gerado (RF22) — dá pra trocar por
## arte própria sem mexer em código.
## Exibir sempre com TEXTURE_FILTER_NEAREST (ver make_rect).

const SIZE := PortraitPainter.SIZE
const OVERRIDE_DIR := "res://assets/portraits/"

static var _cache: Dictionary = {}

## Procurado: fedora e sobretudo vermelhos (identidade do jogo).
static func flavio() -> Texture2D:
	return _cached("flavio", func(): return PortraitFactory.flavio_wanted_spec())

## Foto oficial de senador, de terno.
static func flavio_official() -> Texture2D:
	return _cached("flavio_oficial", func(): return PortraitFactory.flavio_official_spec())

## O senador com o figurino de um disfarce (campo "portrait" do disguises.json).
static func flavio_disguised(disguise_id: String) -> Texture2D:
	return _cached("flavio_" + disguise_id, func():
		return PortraitFactory.flavio_spec(GameData.disguise(disguise_id).get("portrait", {})))

## Testemunha: figurino do local + traços sorteados com semente fixa por
## `key` (ex.: "rio:hotel"), então a mesma pessoa sempre tem a mesma cara.
static func witness(key: String, loc_id: String = "") -> Texture2D:
	return _cached("witness_" + key, func():
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(key)
		var outfit: Dictionary = GameData.location_info(loc_id).get("outfit", {}) if loc_id != "" else {}
		return PortraitFactory.witness_spec(rng, outfit))

static func _cached(name: String, make_spec: Callable) -> Texture2D:
	if _cache.has(name):
		return _cache[name]
	var tex: Texture2D
	var override_path := OVERRIDE_DIR + name + ".png"
	if ResourceLoader.exists(override_path):
		tex = load(override_path)
	else:
		tex = ImageTexture.create_from_image(PortraitFactory.paint(make_spec.call()))
	_cache[name] = tex
	return tex

## TextureRect pronto pra exibir um retrato com `display_px` de lado.
static func make_rect(texture: Texture2D, display_px: int = 192) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = texture
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = Vector2(display_px, display_px)
	return tr
