class_name WorldShapes
extends RefCounted
## Contornos dos continentes (spec 011, RF86): Natural Earth 1:110m
## simplificado por tools/build_world.gd em data/world.json. Em graus, no
## sistema da janela do WorldMapView: x = longitude, y = -latitude.
## Buracos são mares dentro da terra (o Cáspio). Lidos uma vez.

const PATH := "res://data/world.json"

static var _lands: Array[PackedVector2Array] = []
static var _holes: Array[PackedVector2Array] = []

static func lands() -> Array[PackedVector2Array]:
	_load()
	return _lands

static func holes() -> Array[PackedVector2Array]:
	_load()
	return _holes

static func _load() -> void:
	if not _lands.is_empty():
		return
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	for flat in data["lands"]:
		_lands.append(_ring(flat))
	for flat in data["holes"]:
		_holes.append(_ring(flat))

## [lon, lat, lon, lat, ...] -> pontos (lon, -lat).
static func _ring(flat: Array) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(0, flat.size(), 2):
		pts.append(Vector2(flat[i], -flat[i + 1]))
	return pts
