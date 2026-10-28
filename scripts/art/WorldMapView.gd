class_name WorldMapView
extends Control
## Mapa-múndi (projeção equiretangular recortada) com as cidades do jogo:
## origem, destinos oferecidos, destino em foco e o avião animado na viagem.
## Mesma escala nos dois eixos em qualquer tela (RF73): sobra de largura
## mostra mais longitude — o mapa dá a volta (RF74) — e sobra de altura,
## mais latitude/oceano.
## Duas camadas (RF88/90): oceano e continentes em pixel art numa SubViewport
## (fator ART_SCALE, sem filtro) atrás, refeitos só quando a janela muda; rota,
## cidades, etiquetas e avião por cima, na resolução da tela, a cada quadro.

signal flight_finished

const LAT_TOP := 80.0
const LAT_BOTTOM := -58.0
const FLIGHT_SECONDS := 1.8

var origin_id := ""
var option_ids: Array = []
var highlighted_id := "":
	set(value):
		highlighted_id = value
		queue_redraw()
var trail_ids: Array = []
## Cidade sob o mouse/toque (RF33): mostra nome e país.
var hovered_id := "":
	set(value):
		hovered_id = value
		queue_redraw()
## Em pé (RF36): mostra só a região da origem, destinos e trilha.
var crop_to_cities := false

const HOVER_RADIUS := 14.0
const FLAG_SIZE := Vector2(30, 20)
## Folga em graus em volta das cidades no recorte.
const CROP_PADDING := 14.0
## Folga em graus pras cidades não ficarem coladas na borda do mundo inteiro.
const EDGE_PADDING := 4.0
const WORLD := Rect2(-180.0, -LAT_TOP, 360.0, LAT_TOP - LAT_BOTTOM)
## Px do jogo por pixel de arte do mapa.
const ART_SCALE := 2
## Px do jogo por pixel do avião (cresce com a escala de texto do celular).
const PLANE_SCALE := 3
## Ondas do oceano: uma a cada tantos graus (presas ao mapa, dão a volta).
const WAVE_STEP := Vector2(12, 9)

var _base := SubViewportContainer.new()
var _base_viewport := SubViewport.new()
var _land := Control.new()

var _flight_to := ""
var _flight_t := -1.0
var _pulse := 0.0
## Etiquetas já desenhadas neste quadro — as seguintes desviam delas.
var _placed: Array[Rect2] = []
## Janela visível em graus (x = longitude, y = -latitude), sempre com a
## proporção do controle.
var _view := WORLD
## Px por grau, igual nos dois eixos.
var _scale := 1.0
## Longitude da origem: cada cidade é desenhada na cópia a menos de 180°
## dela, então rota e avião vão pelo caminho mais curto (RF75).
var _ref_lon := 0.0
## Ponto do último hover, pra etiqueta sair na cópia que está sob o dedo.
var _hover_point := Vector2(-1, -1)

func _ready() -> void:
	clip_contents = true
	_base.stretch = true
	_base.stretch_shrink = ART_SCALE
	_base.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_base.show_behind_parent = true
	_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_base.set_anchors_preset(Control.PRESET_FULL_RECT)
	_base_viewport.disable_3d = true
	_land.set_anchors_preset(Control.PRESET_FULL_RECT)
	_land.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_land.draw.connect(_paint_land)
	_land.resized.connect(_land.queue_redraw)
	_base_viewport.add_child(_land)
	_base.add_child(_base_viewport)
	add_child(_base)
	resized.connect(_update_view)
	_update_view()

func _process(delta: float) -> void:
	_pulse = fmod(_pulse + delta * 3.0, TAU)
	if _flight_t >= 0.0:
		_flight_t = minf(1.0, _flight_t + delta / FLIGHT_SECONDS)
		if _flight_t >= 1.0:
			_flight_t = -1.0
			flight_finished.emit()
	# parado, nada anima: só o pulso do destino em foco e o voo (RF95)
	if _flight_t >= 0.0 or highlighted_id != "":
		queue_redraw()

func fly_to(city_id: String) -> void:
	_flight_to = city_id
	_flight_t = 0.0

func project(lon: float, lat: float) -> Vector2:
	return (Vector2(lon, -lat) - _view.position) * _scale

## Px por grau de longitude e de latitude (RF73: os dois iguais).
func pixels_per_degree() -> Vector2:
	return Vector2(project(1, 0).x - project(0, 0).x, project(0, 0).y - project(0, 1).y)

func _update_view() -> void:
	if size.x <= 0 or size.y <= 0:
		return
	_ref_lon = float(GameData.city(origin_id)["lon"]) if origin_id != "" else 0.0
	var cities := _cities_box()
	_view = _fit_view(cities.grow(CROP_PADDING) if crop_to_cities and cities != Rect2() else _world_box(cities))
	_scale = size.x / _view.size.x
	_land.queue_redraw()
	queue_redraw()

## Caixa (em graus) das cidades em jogo, nas cópias perto da origem.
func _cities_box() -> Rect2:
	var ids: Array = ([origin_id] if origin_id != "" else []) + option_ids + trail_ids
	if ids.is_empty():
		return Rect2()
	var box := Rect2(_unwrapped(ids[0]), Vector2.ZERO)
	for id in ids:
		box = box.expand(_unwrapped(id))
	return box

## O mundo inteiro, deslizado em longitude o mínimo pra caber as cidades em
## jogo (quando a rota mais curta cruza a borda do mapa).
func _world_box(cities: Rect2) -> Rect2:
	var box := WORLD
	if cities == Rect2():
		return box
	cities = cities.grow(EDGE_PADDING)
	if cities.position.x < box.position.x:
		box.position.x = cities.position.x
	elif cities.end.x > box.end.x:
		box.position.x = cities.end.x - box.size.x
	return box

## Alarga a caixa até a proporção do controle, sem esticar. Na vertical
## fica dentro das latitudes do mapa quando cabe; senão, centraliza.
func _fit_view(box: Rect2) -> Rect2:
	var ratio := size.x / size.y
	var s := box.size
	if s.x / s.y < ratio:
		s.x = s.y * ratio
	else:
		s.y = s.x / ratio
	var view := Rect2(box.get_center() - s / 2, s)
	if s.y <= WORLD.size.y:
		view.position.y = clampf(view.position.y, WORLD.position.y, WORLD.end.y - s.y)
	else:
		view.position.y = WORLD.get_center().y - s.y / 2
	return view

## Posição em graus da cópia da cidade a menos de 180° da origem.
func _unwrapped(id: String) -> Vector2:
	var c := GameData.city(id)
	return Vector2(_ref_lon + wrapf(float(c["lon"]) - _ref_lon, -180.0, 180.0), -float(c["lat"]))

func _city_pos(id: String) -> Vector2:
	var p := _unwrapped(id)
	return project(p.x, -p.y)

## Deslocamentos de 360° em que alguma cópia do mundo aparece na janela.
func _wraps() -> Array:
	return range(ceili((_view.position.x - 180.0) / 360.0), floori((_view.end.x + 180.0) / 360.0) + 1)

## Todas as cópias da cidade na janela (ou perto dela).
func _copies(c: Dictionary) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for k in _wraps():
		out.append(project(float(c["lon"]) + 360.0 * k, float(c["lat"])))
	return out

## Base em pixels de arte: oceano com grade e ondas, continentes com sombra
## e litoral (todas as cópias da volta ao mundo) e a rosa dos ventos.
func _paint_land() -> void:
	var area := Vector2(_base_viewport.size)
	_land.draw_rect(Rect2(Vector2.ZERO, area), Palette.OCEAN)
	for lon in range(ceili(_view.position.x / 30.0) * 30, ceili(_view.end.x) + 1, 30):
		_land.draw_rect(Rect2(_art(lon, 0).x, 0, 1, area.y), Palette.OCEAN_LINE)
	for lat in range(-80, 81, 20):
		_land.draw_rect(Rect2(0, _art(0, lat).y, area.x, 1), Palette.OCEAN_LINE)
	var row := 0
	for lat in range(-90, 91, int(WAVE_STEP.y)):
		var shift := WAVE_STEP.x / 2 if row % 2 == 1 else 0.0
		for lon in range(floori(_view.position.x / WAVE_STEP.x) * int(WAVE_STEP.x), ceili(_view.end.x) + 1, int(WAVE_STEP.x)):
			var p := _art(lon + shift, lat)
			_land.draw_rect(Rect2(p, Vector2(2, 1)), Palette.OCEAN_WAVE)
			_land.draw_rect(Rect2(p + Vector2(2, -1), Vector2(2, 1)), Palette.OCEAN_WAVE)
		row += 1

	for k in _wraps():
		var shapes: Array = []
		for land in WorldShapes.lands():
			shapes.append(_art_ring(land, 360.0 * k))
		for pts in shapes:
			_land.draw_colored_polygon(_offset(pts, Vector2(1, 1)), Palette.LAND_SHADOW)
		for pts in shapes:
			_land.draw_colored_polygon(pts, Palette.PAPER)
		for hole in WorldShapes.holes():
			var pts := _art_ring(hole, 360.0 * k)
			_land.draw_colored_polygon(pts, Palette.OCEAN)
			shapes.append(pts)
		for pts in shapes:
			_land.draw_polyline(_offset(pts, Vector2.ZERO, true), Palette.INK_SOFT, 1)

	if area.x > 120 and area.y > 60:
		var c := Vector2(12, area.y - 12)
		_land.draw_colored_polygon(PackedVector2Array([c + Vector2(-9, 0), c + Vector2(0, 2), c + Vector2(9, 0), c + Vector2(0, -2)]), Palette.PAPER_DARK)
		_land.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -9), c + Vector2(2, 0), c + Vector2(0, 9), c + Vector2(-2, 0)]), Palette.PAPER)
		_land.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -9), c + Vector2(2, 0), c + Vector2(-2, 0)]), Palette.RED)
		_land.draw_rect(Rect2(c - Vector2(0, 0), Vector2(1, 1)), Palette.INK)

## Ponto em pixels de arte da base.
func _art(lon: float, lat: float) -> Vector2:
	return (project(lon, lat) / ART_SCALE).round()

## Contorno (em graus, y = -lat) em pixels de arte, deslocado `shift_lon`.
func _art_ring(ring: PackedVector2Array, shift_lon: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in ring:
		out.append((Vector2(p.x + shift_lon, p.y) - _view.position) * _scale / ART_SCALE)
	return out

func _offset(pts: PackedVector2Array, by: Vector2, closed: bool = false) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(p + by)
	if closed and not pts.is_empty():
		out.append(pts[0] + by)
	return out

func _draw() -> void:
	_placed.clear()
	for i in range(1, trail_ids.size()):
		_draw_dashed(_city_pos(trail_ids[i - 1]), _city_pos(trail_ids[i]), Palette.GREY)

	for c in GameData.cities():
		for pos in _copies(c):
			draw_circle(pos, 3, Palette.INK_SOFT)

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
		var hp := _hovered_pos()
		draw_circle(hp, 5, Palette.YELLOW)
		_draw_tag(font, hp, GameData.city(hovered_id), false, false)

	if _flight_t >= 0.0:
		_draw_plane()

## Cópia da cidade sob o dedo; sem hover recente, a perto da origem.
func _hovered_pos() -> Vector2:
	if _hover_point.x < 0:
		return _city_pos(hovered_id)
	var best := Vector2.INF
	for pos in _copies(GameData.city(hovered_id)):
		if pos.distance_to(_hover_point) < best.distance_to(_hover_point):
			best = pos
	return best

## Etiqueta da cidade; destinos oferecidos levam a bandeira, o rótulo de
## hover leva o país. Cresce com a escala de texto do celular (RF89) e não
## sai do quadro.
func _draw_tag(font: Font, pos: Vector2, city: Dictionary, focused: bool, with_flag: bool) -> void:
	var k := Responsive.text_scale()
	var fs := roundi(24 * k)
	var flag_size := (FLAG_SIZE * k).round()
	var text: String = city["name"] if with_flag else "%s — %s" % [city["name"], city["country"]]
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var flag_w := flag_size.x + 6 if with_flag else 0.0
	var tag_h := roundf(28 * k)
	var r := Rect2(pos + Vector2(10, 2 - tag_h), Vector2(tw + 12 + flag_w, tag_h))
	if r.end.x > size.x:
		r.position.x = pos.x - 10 - r.size.x
	r.position.x = clampf(r.position.x, 0.0, maxf(size.x - r.size.x, 0.0))
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
		FlagPainter.draw(self, Rect2(r.position + ((Vector2(0, tag_h) - Vector2(0, flag_size.y)) / 2).round() + Vector2(4, 0), flag_size), city.get("flag", {}))
	draw_string(font, r.position + Vector2(6 + flag_w, roundf(21 * k)), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Palette.INK)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or (event is InputEventMouseButton and event.pressed) or event is InputEventScreenTouch:
		_hover_point = event.position
		hovered_id = _city_at(event.position)

## Cidade mais próxima do ponto (em qualquer cópia), dentro do raio de toque.
func _city_at(point: Vector2) -> String:
	var best := ""
	var best_d := HOVER_RADIUS
	for c in GameData.cities():
		for pos in _copies(c):
			var d := pos.distance_to(point)
			if d < best_d:
				best_d = d
				best = c["id"]
	return best

func _draw_dashed(a: Vector2, b: Vector2, col: Color) -> void:
	draw_dashed_line(a, b, col, 3, 10)

## Ponto e rumo do avião no instante `progress` (0 a 1) do voo: arco (Bézier
## quadrática) da origem ao destino, com decolagem e pouso suavizados.
func plane_at(progress: float) -> Array:
	var a := _city_pos(origin_id)
	var b := _city_pos(_flight_to)
	var ctrl := (a + b) / 2 - Vector2(0, a.distance_to(b) * 0.35)
	var curve := func(t: float) -> Vector2: return a.lerp(ctrl, t).lerp(ctrl.lerp(b, t), t)
	var t := ease(clampf(progress, 0.0, 1.0), -1.6)
	var pos: Vector2 = curve.call(t)
	var dir: Vector2 = (curve.call(minf(1.0, t + 0.02)) - curve.call(maxf(0.0, t - 0.02))).normalized()
	if dir == Vector2.ZERO:
		dir = (b - a).normalized()
	return [pos, dir]

## Avião em pixel art (RF97–100): rastro de fumaça que some aos poucos,
## sombra no mapa que se afasta no meio do voo (altitude) e o quadro da
## direção mais próxima do rumo.
func _draw_plane() -> void:
	var zoom := float(maxi(PLANE_SCALE, roundi(PLANE_SCALE * Responsive.text_scale())))
	# rastro: baforadas atrás do avião, maiores e mais apagadas quanto mais velhas
	for i in range(10, 0, -1):
		if _flight_t - i * 0.02 <= 0.0:
			continue
		var puff: Vector2 = plane_at(_flight_t - i * 0.02)[0]
		draw_circle(puff.round(), (1.0 + i * 0.35) * zoom, Color(Palette.WHITE, 0.5 - i * 0.045))
	var here := plane_at(_flight_t)
	var tex := PlaneSprite.frame_for(here[1])
	var box := Vector2(PlaneSprite.FRAME, PlaneSprite.FRAME) * zoom
	var lift := sin(_flight_t * PI)
	draw_texture_rect(tex, Rect2((here[0] - box / 2 + Vector2(3, 5) * zoom * lift).round(), box), false, Color(0, 0, 0, 0.3))
	draw_texture_rect(tex, Rect2((here[0] - box / 2).round(), box), false)
