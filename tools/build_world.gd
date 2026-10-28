extends SceneTree
## Contornos do mapa-múndi (spec 011, RF86): lê o Natural Earth 1:110m
## (domínio público), simplifica e grava data/world.json, que WorldShapes lê.
## O arquivo de origem não fica no repositório; baixar de
## https://raw.githubusercontent.com/nvkelso/natural-earth-vector/v5.1.2/geojson/ne_110m_land.geojson
## Roda com: godot --headless --path . --script res://tools/build_world.gd -- <ne_110m_land.geojson>

const OUT := "res://data/world.json"
## Tolerância da simplificação, em graus (o mapa mostra ~2 px por grau).
const TOLERANCE := 0.35
## Ilhas menores que isso (graus²) somem — no mapa seriam um pixel.
const MIN_AREA := 0.8

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("uso: ... --script res://tools/build_world.gd -- <ne_110m_land.geojson>")
		quit(1)
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	if not data is Dictionary:
		printerr("GeoJSON inválido: ", args[0])
		quit(1)
		return
	var lands: Array = []
	var holes: Array = []
	var points := 0
	for feature in data["features"]:
		var geometry: Dictionary = feature["geometry"]
		var polygons: Array = [geometry["coordinates"]] if geometry["type"] == "Polygon" else geometry["coordinates"]
		for polygon in polygons:
			for r in polygon.size():
				var ring := _simplified(polygon[r])
				if ring.is_empty():
					continue
				(lands if r == 0 else holes).append(_flat(ring))
				points += ring.size()
	var out := FileAccess.open(OUT, FileAccess.WRITE)
	out.store_string(JSON.stringify({
		"source": "Natural Earth 1:110m land v5.1.2 (domínio público), simplificado por tools/build_world.gd",
		"lands": lands, "holes": holes}))
	print("world: %d terras, %d buracos, %d pontos" % [lands.size(), holes.size(), points])
	quit()

## Anel simplificado que ainda triangula (aperta a tolerância se precisar);
## vazio se a ilha for pequena demais.
func _simplified(ring: Array) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for p in ring:
		pts.append(Vector2(p[0], p[1]))
	if pts.size() > 1 and pts[0] == pts[pts.size() - 1]:
		pts.remove_at(pts.size() - 1)
	if absf(_area(pts)) < MIN_AREA:
		return PackedVector2Array()
	var tolerance := TOLERANCE
	while tolerance > 0.01:
		var simple := _dedupe(_douglas_peucker(pts, tolerance))
		if simple.size() >= 3 and not Geometry2D.triangulate_polygon(simple).is_empty():
			return simple
		tolerance /= 2.0
	return pts

func _douglas_peucker(pts: PackedVector2Array, tolerance: float) -> PackedVector2Array:
	if pts.size() < 3:
		return pts
	var keep := []
	keep.resize(pts.size())
	keep.fill(false)
	keep[0] = true
	keep[pts.size() - 1] = true
	var stack := [[0, pts.size() - 1]]
	while not stack.is_empty():
		var span: Array = stack.pop_back()
		var best := -1
		var best_d := tolerance
		for i in range(span[0] + 1, span[1]):
			var d := _segment_distance(pts[i], pts[span[0]], pts[span[1]])
			if d > best_d:
				best_d = d
				best = i
		if best != -1:
			keep[best] = true
			stack.append([span[0], best])
			stack.append([best, span[1]])
	var out := PackedVector2Array()
	for i in pts.size():
		if keep[i]:
			out.append(pts[i])
	return out

func _segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	return p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b))

## Arredonda pra 0,01° e tira pontos repetidos seguidos.
func _dedupe(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		var r := (p * 100.0).round() / 100.0
		if out.is_empty() or out[out.size() - 1] != r:
			out.append(r)
	if out.size() > 1 and out[0] == out[out.size() - 1]:
		out.remove_at(out.size() - 1)
	return out

func _area(pts: PackedVector2Array) -> float:
	var a := 0.0
	for i in pts.size():
		var p := pts[i]
		var q := pts[(i + 1) % pts.size()]
		a += p.x * q.y - q.x * p.y
	return a / 2.0

func _flat(pts: PackedVector2Array) -> Array:
	var out := []
	for p in pts:
		out.append(p.x)
		out.append(p.y)
	return out
