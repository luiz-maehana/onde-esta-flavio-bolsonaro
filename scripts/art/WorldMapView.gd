class_name WorldMapView
extends Control
## Mapa-múndi (projeção equiretangular recortada) com as cidades do jogo:
## origem, destinos oferecidos, destino em foco e o avião animado na viagem.

signal flight_finished

const LAT_TOP := 80.0
const LAT_BOTTOM := -58.0
const FLIGHT_SECONDS := 1.8

var origin_id := ""
var option_ids: Array = []
var highlighted_id := ""
var trail_ids: Array = []
## Cidade sob o mouse/toque (RF33): mostra nome e país.
var hovered_id := ""

const HOVER_RADIUS := 14.0
const FLAG_SIZE := Vector2(30, 20)

var _flight_to := ""
var _flight_t := -1.0
var _pulse := 0.0
## Etiquetas já desenhadas neste quadro — as seguintes desviam delas.
var _placed: Array[Rect2] = []

func _ready() -> void:
	clip_contents = true
	resized.connect(queue_redraw)

func _process(delta: float) -> void:
	_pulse = fmod(_pulse + delta * 3.0, TAU)
	if _flight_t >= 0.0:
		_flight_t = minf(1.0, _flight_t + delta / FLIGHT_SECONDS)
		if _flight_t >= 1.0:
			_flight_t = -1.0
			flight_finished.emit()
	queue_redraw()

func fly_to(city_id: String) -> void:
	_flight_to = city_id
	_flight_t = 0.0

func project(lon: float, lat: float) -> Vector2:
	return Vector2((lon + 180.0) / 360.0 * size.x, (LAT_TOP - lat) / (LAT_TOP - LAT_BOTTOM) * size.y)

func _city_pos(id: String) -> Vector2:
	var c := GameData.city(id)
	return project(float(c["lon"]), float(c["lat"]))

func _draw() -> void:
	_placed.clear()
	draw_rect(Rect2(Vector2.ZERO, size), Palette.OCEAN)
	for lon in range(-180, 181, 30):
		var x := project(lon, 0).x
		draw_line(Vector2(x, 0), Vector2(x, size.y), Palette.OCEAN_LINE, 1)
	for lat in range(-60, 81, 20):
		var y := project(0, lat).y
		draw_line(Vector2(0, y), Vector2(size.x, y), Palette.OCEAN_LINE, 1)

	for land in WorldShapes.LANDS:
		var pts := PackedVector2Array()
		for p in land:
			pts.append(project(p[0], p[1]))
		draw_colored_polygon(pts, Palette.PAPER)
		pts.append(pts[0])
		draw_polyline(pts, Palette.INK, 2)

	for i in range(1, trail_ids.size()):
		_draw_dashed(_city_pos(trail_ids[i - 1]), _city_pos(trail_ids[i]), Palette.GREY)

	for c in GameData.cities():
		draw_circle(_city_pos(c["id"]), 3, Palette.INK_SOFT)

	var font := UiTheme.BODY_FONT
	for id in option_ids:
		var pos := _city_pos(id)
		var focused: bool = id == highlighted_id
		if focused:
			_draw_dashed(_city_pos(origin_id), pos, Palette.YELLOW)
			draw_circle(pos, 10 + sin(_pulse) * 3, Color(Palette.YELLOW, 0.35))
		draw_circle(pos, 6, Palette.YELLOW if focused else Palette.RED)
		draw_arc(pos, 6, 0, TAU, 16, Palette.INK, 2)
		_draw_tag(font, pos, GameData.city(id), focused, true)

	if origin_id != "":
		var o := _city_pos(origin_id)
		draw_rect(Rect2(o - Vector2(6, 6), Vector2(12, 12)), Palette.RED)
		draw_rect(Rect2(o - Vector2(6, 6), Vector2(12, 12)), Palette.INK, false, 2)

	if hovered_id != "" and not option_ids.has(hovered_id):
		var hp := _city_pos(hovered_id)
		draw_circle(hp, 5, Palette.YELLOW)
		_draw_tag(font, hp, GameData.city(hovered_id), false, false)

	if _flight_t >= 0.0:
		_draw_plane()

## Etiqueta da cidade; destinos oferecidos levam a bandeira, o rótulo de
## hover leva o país.
func _draw_tag(font: Font, pos: Vector2, city: Dictionary, focused: bool, with_flag: bool) -> void:
	var fs := 24
	var text: String = city["name"] if with_flag else "%s — %s" % [city["name"], city["country"]]
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var flag_w := FLAG_SIZE.x + 6 if with_flag else 0.0
	var r := Rect2(pos + Vector2(10, -26), Vector2(tw + 12 + flag_w, 28))
	if r.end.x > size.x:
		r.position.x = pos.x - 10 - r.size.x
	if r.position.y < 0:
		r.position.y = pos.y + 10
	for i in 6:
		var hit := false
		for other in _placed:
			if other.grow(2).intersects(r):
				hit = true
				r.position.y = other.end.y + 3
		if not hit:
			break
	_placed.append(r)
	draw_rect(r, Palette.YELLOW if focused else Palette.PAPER)
	draw_rect(r, Palette.INK, false, 2)
	if with_flag:
		FlagPainter.draw(self, Rect2(r.position + Vector2(4, 4), FLAG_SIZE), city.get("flag", {}))
	draw_string(font, r.position + Vector2(6 + flag_w, 21), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Palette.INK)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or (event is InputEventMouseButton and event.pressed) or event is InputEventScreenTouch:
		hovered_id = _city_at(event.position)

## Cidade mais próxima do ponto, dentro do raio de toque.
func _city_at(point: Vector2) -> String:
	var best := ""
	var best_d := HOVER_RADIUS
	for c in GameData.cities():
		var d := _city_pos(c["id"]).distance_to(point)
		if d < best_d:
			best_d = d
			best = c["id"]
	return best

func _draw_dashed(a: Vector2, b: Vector2, col: Color) -> void:
	draw_dashed_line(a, b, col, 3, 10)

## Avião seguindo um arco (curva de Bézier quadrática) da origem ao destino.
func _draw_plane() -> void:
	var a := _city_pos(origin_id)
	var b := _city_pos(_flight_to)
	var ctrl := (a + b) / 2 - Vector2(0, a.distance_to(b) * 0.35)
	var t := ease(_flight_t, -1.6)
	var pos := a.lerp(ctrl, t).lerp(ctrl.lerp(b, t), t)
	var next := a.lerp(ctrl, minf(1, t + 0.02)).lerp(ctrl.lerp(b, minf(1, t + 0.02)), minf(1, t + 0.02))
	var dir := (next - pos).normalized()
	if dir == Vector2.ZERO:
		dir = (b - a).normalized()
	var side := dir.orthogonal()
	var body := PackedVector2Array([pos + dir * 16, pos + side * 4 - dir * 10, pos - side * 4 - dir * 10])
	var wings := PackedVector2Array([pos + dir * 2, pos + side * 14 - dir * 4, pos - side * 14 - dir * 4])
	draw_colored_polygon(wings, Palette.WHITE)
	draw_colored_polygon(body, Palette.RED)
	draw_polyline(PackedVector2Array([body[0], body[1], body[2], body[0]]), Palette.INK, 2)
