class_name SkylineView
extends SubViewportContainer
## Paisagem da cidade atual (spec 011): céu pela hora do relógio com nuvens,
## fundo do terreno (morros, montanhas, dunas), prédios no estilo da cidade
## em dois planos, o marco no meio (SkylineLandmarks) e a frente — rua, orla
## ou água, com vegetação. Terreno e estilo vêm de data/scenery.json; a mesma
## cidade sempre tem o mesmo perfil (semente pelo id).
## A cena é desenhada numa SubViewport pequena — a tela de pixel art — e
## ampliada por um fator inteiro sem filtro (RF76/78): tudo tem o mesmo
## pixel e nada estica. Medidas abaixo em pixels de arte.
## Céu e cidade são desenhos parados (refeitos só quando cidade, hora ou
## tamanho mudam); nuvens e brilho da água andam a cada quadro (RF84/90).

## O fator é o maior inteiro que deixa pelo menos esta altura e esta
## largura de arte (a largura cabe o marco mais largo no tamanho cheio).
const REF_HEIGHT := 100
const REF_WIDTH := 130
const GROUND_HEIGHT := 14.0
## Altura de referência do chão até o topo: prédios medem por ela, não pelo
## quadro, pra não virar arranha-céu em pé (RF76).
const REF_GROUND := REF_HEIGHT - GROUND_HEIGHT
## Folga mínima do marco até as bordas da cena.
const LANDMARK_MARGIN := 2.0
## Folga entre o marco e os prédios/árvores do mesmo plano.
const LANDMARK_CLEARANCE := 3.0
## Override (decisão F4): assets/skylines/<cidade>.png substitui o marco
## desenhado — 1 texel = 1 pixel de arte, apoiado no chão, centralizado.
const OVERRIDE_DIR := "res://assets/skylines/"
const LAMP := Color("#FFD166")
## Limiares 4x4 (Bayer) do pontilhado do céu.
const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
const SKY_LEVELS := 7

## Prédios por estilo: largura, altura (fração de REF_GROUND) no fundo e no
## meio, e espaço entre eles.
const STYLES := {
	"tower": {"w": Vector2(10, 22), "far": Vector2(0.25, 0.55), "mid": Vector2(0.15, 0.4), "gap": Vector2(0, 3)},
	"colonial": {"w": Vector2(14, 26), "far": Vector2(0.15, 0.35), "mid": Vector2(0.12, 0.26), "gap": Vector2(0, 1)},
	"low": {"w": Vector2(12, 22), "far": Vector2(0.12, 0.3), "mid": Vector2(0.08, 0.18), "gap": Vector2(0, 3)},
	"adobe": {"w": Vector2(10, 20), "far": Vector2(0.1, 0.25), "mid": Vector2(0.07, 0.16), "gap": Vector2(0, 2)},
}
const TERRAINS := ["plain", "water", "beach", "desert"]
const BACKDROPS := ["none", "hills", "mountains", "dunes", "fuji"]
const VEGETATION := ["none", "palm", "tree", "conifer", "cypress"]

var city: Dictionary = {}:
	set(value):
		city = value
		_scenery = GameData.scenery(city.get("id", ""))
		_redraw()
var hour := 12:
	set(value):
		hour = value
		_redraw()

var _viewport := SubViewport.new()
var _sky := Control.new()
var _clouds := Control.new()
var _city := Control.new()
var _fx := Control.new()
var _scenery: Dictionary = {}
var _time := 0.0
## Textura do céu em uso: o comando de desenho não segura a referência, então
## o cache pode esvaziar sem apagar o céu de quem está na tela.
var _sky_tex: Texture2D
static var _sky_cache: Dictionary = {}
static var _overrides: Dictionary = {}

func _init() -> void:
	stretch = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport.disable_3d = true
	add_child(_viewport)
	_sky.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	for layer in [[_sky, _paint_sky], [_clouds, _paint_clouds], [_city, _paint_city], [_fx, _paint_fx]]:
		var c: Control = layer[0]
		c.set_anchors_preset(Control.PRESET_FULL_RECT)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.draw.connect(layer[1])
		c.resized.connect(c.queue_redraw)
		_viewport.add_child(c)
	resized.connect(_fit)

## Tamanho dado antes de entrar na árvore não emite `resized`.
func _ready() -> void:
	_fit()

func _process(delta: float) -> void:
	if city.is_empty() or not is_visible_in_tree():
		return
	_time += delta
	_clouds.queue_redraw()
	if _terrain() in ["water", "beach"]:
		_fx.queue_redraw()

## Quantos px do jogo vale um pixel de arte.
func art_scale() -> int:
	return stretch_shrink

## Tamanho da cena em pixels de arte.
func art_size() -> Vector2:
	return Vector2(_viewport.size)

func _fit() -> void:
	stretch_shrink = maxi(1, mini(floori(size.y / REF_HEIGHT), floori(size.x / REF_WIDTH)))
	_redraw()

func _redraw() -> void:
	for layer in [_sky, _clouds, _city, _fx]:
		layer.queue_redraw()

func _terrain() -> String:
	return _scenery.get("terrain", "plain")

func _ground() -> float:
	return art_size().y - GROUND_HEIGHT

## --- Luz -------------------------------------------------------------------

func _night() -> bool:
	return hour >= 19 or hour < 6

## Topo/base do gradiente do céu por faixa de horário.
func _sky_colors() -> Array:
	var day: Color = Color(city.get("palette", ["#88AACC"])[0])
	if hour >= 20 or hour < 5:
		return [Color("#0B1026"), Color("#2B2F5A")]
	if hour < 8:
		return [Color("#5B6EAE"), Color("#F4A261")]
	if hour >= 17:
		return [Color("#6A4C93"), Color("#FF7E5F")]
	return [day.darkened(0.15), day.lightened(0.45)]

## Cor pela hora (escurece e azula à noite) e pela distância (`haze` puxa
## pra cor do horizonte — perspectiva atmosférica).
func _tone(c: Color, haze: float = 0.0) -> Color:
	var out := c
	if hour >= 20 or hour < 5:
		out = out.darkened(0.5).lerp(Color("#1B2142"), 0.25)
	elif hour < 8 or hour >= 17:
		out = out.darkened(0.2)
	return out.lerp(_sky_colors()[1], haze)

## --- Céu -------------------------------------------------------------------

func _paint_sky() -> void:
	if city.is_empty():
		return
	var size_art := art_size()
	_sky_tex = _sky_texture(int(size_art.y))
	_sky.draw_texture_rect(_sky_tex, Rect2(Vector2.ZERO, size_art), true)
	_draw_celestial(size_art.x, _ground())

## Gradiente em faixas com pontilhado entre elas: textura de 4 px de
## largura repetida (o padrão de Bayer se repete a cada 4 px).
func _sky_texture(h: int) -> Texture2D:
	var colors := _sky_colors()
	var key := "%d|%s|%s" % [h, colors[0].to_html(), colors[1].to_html()]
	if _sky_cache.has(key):
		return _sky_cache[key]
	if _sky_cache.size() > 24:
		_sky_cache.clear()
	var img := Image.create_empty(4, maxi(h, 1), false, Image.FORMAT_RGBA8)
	for y in h:
		var v := float(y) / maxf(h - 1, 1) * (SKY_LEVELS - 1)
		var level := floori(v)
		for x in 4:
			var step := level + (1 if v - level > (BAYER[(y % 4) * 4 + x] + 0.5) / 16.0 else 0)
			img.set_pixel(x, y, colors[0].lerp(colors[1], float(mini(step, SKY_LEVELS - 1)) / (SKY_LEVELS - 1)))
	var tex := ImageTexture.create_from_image(img)
	_sky_cache[key] = tex
	return tex

## Sol (dia) ou lua (noite) fazendo um arco conforme a hora.
func _draw_celestial(w: float, ground: float) -> void:
	var night := _night()
	var t: float = fposmod(hour - 19, 24) / 11.0 if night else (hour - 6) / 13.0
	var pos := Vector2(w * (0.1 + 0.8 * t), ground - sin(t * PI) * ground * 0.75 - 7).round()
	if night:
		var star_rng := RandomNumberGenerator.new()
		star_rng.seed = 7
		for i in int(w * ground / 160):
			_sky.draw_rect(Rect2(floorf(star_rng.randf() * w), floorf(star_rng.randf() * ground * 0.7), 1, 1), Color(1, 1, 1, star_rng.randf_range(0.4, 0.9)))
		_sky.draw_circle(pos, 6, Color("#F5F3CE"))
		_sky.draw_circle(pos + Vector2(3, -2), 5, _sky_colors()[0].lerp(_sky_colors()[1], pos.y / ground))
	else:
		_sky.draw_circle(pos, 9, Color("#FFE66D", 0.25))
		_sky.draw_circle(pos, 6, Color("#FFE66D"))

## Nuvens de pixel atravessando o céu devagar.
func _paint_clouds() -> void:
	if city.is_empty():
		return
	var w := art_size().x
	var ground := _ground()
	var night := hour >= 20 or hour < 5
	var light := Color("#6B7196") if night else Color.WHITE.lerp(_sky_colors()[1], 0.15)
	var shade := light.lerp(_sky_colors()[0], 0.35)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(city["id"]) + 11
	for i in 3 + int(w / 70):
		var cw := roundf(rng.randf_range(12, 28))
		var cy := roundf(rng.randf_range(6, ground * 0.45))
		var speed := rng.randf_range(0.6, 1.6)
		var x := roundf(fposmod(rng.randf() * (w + cw) + _time * speed, w + cw * 2) - cw)
		for b in rng.randi_range(2, 4):
			_clouds.draw_circle(Vector2(x + roundf(rng.randf_range(3, cw - 3)), cy), rng.randi_range(2, 4), light)
		_clouds.draw_rect(Rect2(x, cy, cw, 3), light)
		_clouds.draw_rect(Rect2(x + 1, cy + 2, cw - 2, 1), shade)

## --- Cidade ----------------------------------------------------------------

func _paint_city() -> void:
	if city.is_empty():
		return
	var w := art_size().x
	var ground := _ground()
	var style: Dictionary = STYLES.get(_scenery.get("style", "low"), STYLES["low"])
	var palette: Array = city.get("palette", ["#88AACC", "#CCCCCC", "#C8102E"])
	var building := Color(palette[1])
	var seed_value := hash(city["id"])
	var lm := landmark_rect()
	_draw_backdrop(seed_value + 3, w, ground)
	_row(seed_value + 4, w, style, func(rng: RandomNumberGenerator, x: float, bw: float) -> void:
		_draw_far_building(rng, x, bw, ground, building, style))
	_draw_landmark(w, ground)
	_row(seed_value, w, style, func(rng: RandomNumberGenerator, x: float, bw: float) -> void:
		if x < lm.end.x + LANDMARK_CLEARANCE and x + bw > lm.position.x - LANDMARK_CLEARANCE:
			return
		_draw_building(rng, x, bw, ground, building, style))
	_draw_front(seed_value + 6, w, ground, Color(palette[2]))
	_draw_vegetation(seed_value + 8, w, ground, lm)

## Caixa do marco na cena, em pixels de arte (RF77: sempre inteiro).
func landmark_rect() -> Rect2:
	var tex := _override()
	if tex:
		return Rect2(roundf(art_size().x / 2 - tex.get_width() / 2.0), _ground() - tex.get_height(), tex.get_width(), tex.get_height())
	var layout := _landmark_layout()
	var b: Rect2 = layout[2]
	var u: float = layout[1]
	return Rect2(layout[0] + b.position.x * u, _ground() - b.end.y * u, b.size.x * u, b.size.y * u)

## [centro x, unidade, caixa em unidades]: 1 unidade = 1 pixel de arte,
## reduzido só se o marco não couber; centralizado pela própria caixa.
func _landmark_layout() -> Array:
	var size_art := art_size()
	var b := SkylineLandmarks.bounds(city["landmark"])
	var u := minf(1.0, (size_art.x - LANDMARK_MARGIN * 2) / maxf(b.size.x, 1.0))
	u = minf(u, (_ground() - LANDMARK_MARGIN) / maxf(b.end.y, 1.0))
	return [roundf(size_art.x / 2 - b.get_center().x * u), u, b]

func _override() -> Texture2D:
	var id: String = city.get("id", "")
	if not _overrides.has(id):
		var path := OVERRIDE_DIR + id + ".png"
		_overrides[id] = load(path) if ResourceLoader.exists(path) else null
	return _overrides[id]

func _draw_landmark(w: float, ground: float) -> void:
	var tex := _override()
	if tex:
		_city.draw_texture(tex, landmark_rect().position, _tone(Color.WHITE, 0.05))
		return
	var layout := _landmark_layout()
	SkylineLandmarks.draw(_city, city["landmark"], layout[0], ground, layout[1], func(c: Color) -> Color: return _tone(c, 0.06), _night())

## Morros, montanhas, dunas ou o Fuji: duas fileiras, a de trás mais
## apagada; encosta virada pra direita mais escura (luz da esquerda).
## Medido a partir do centro, então quadro largo só revela mais.
func _draw_backdrop(seed_value: int, w: float, ground: float) -> void:
	var kind: String = _scenery.get("backdrop", "none")
	if kind == "none":
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var ph := [rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU]
	var center := floorf(w / 2)
	var rows: Array = []
	match kind:
		"hills":
			rows = [[Color("#5E8F55"), 0.5, func(d: float) -> float: return 24 + 8 * sin(d * 0.05 + ph[0]) + 5 * sin(d * 0.11 + ph[1])],
				[Color("#4C7A45"), 0.3, func(d: float) -> float: return 13 + 6 * sin(d * 0.07 + ph[2]) + 3 * sin(d * 0.17 + ph[0])]]
		"mountains":
			rows = [[Color("#7C8AA0"), 0.45, func(d: float) -> float: return 36 + 14 * _tri(d * 0.03 + ph[0]) + 7 * _tri(d * 0.09 + ph[1])],
				[Color("#6D7A8C"), 0.3, func(d: float) -> float: return 16 + 6 * _tri(d * 0.05 + ph[2]) + 3 * _tri(d * 0.13 + ph[1])]]
		"dunes":
			rows = [[Color("#D9B26F"), 0.45, func(d: float) -> float: return 12 + 4 * sin(d * 0.04 + ph[0]) + 2 * sin(d * 0.1 + ph[1])],
				[Color("#CFA35E"), 0.25, func(d: float) -> float: return 6 + 3 * sin(d * 0.06 + ph[2])]]
		"fuji":
			rows = [[Color("#7D8FB3"), 0.45, func(d: float) -> float: return minf(42.0, maxf(0.0, 46 - absf(d - 52) * 0.62))],
				[Color("#5E8F55"), 0.3, func(d: float) -> float: return 9 + 4 * sin(d * 0.06 + ph[2])]]
	for r in rows.size():
		var row: Array = rows[r]
		var col := _tone(row[0], row[1])
		var height: Callable = row[2]
		for x in int(w):
			var d := x - center
			var hgt := roundf(height.call(d))
			if hgt <= 0:
				continue
			var c := col.darkened(0.12) if height.call(d + 1) < height.call(d) else col
			_city.draw_rect(Rect2(x, ground - hgt, 1, hgt), c)
			var snow := 0.0
			if kind == "mountains" and r == 0:
				snow = clampf(hgt - 42, 0, 6)
			elif kind == "fuji" and r == 0:
				snow = clampf(hgt - 30, 0, 14) + (1 if x % 3 == 0 else 0)
			if snow > 0:
				_city.draw_rect(Rect2(x, ground - hgt, 1, snow), _tone(Color("#F4F6FA"), row[1]))

## Onda triangular de -1 a 1 (picos das montanhas).
static func _tri(t: float) -> float:
	return 2.0 * absf(fposmod(t / TAU, 1.0) * 2.0 - 1.0) - 1.0

## Prédios do centro pras bordas, um rng por lado: a parte do meio é a mesma
## em qualquer largura e quadro largo só revela mais cidade (RF85). Cada
## prédio ganha um rng próprio pros detalhes, então pular um prédio (atrás
## do marco) não muda os outros.
func _row(seed_value: int, w: float, style: Dictionary, draw_one: Callable) -> void:
	var center := floorf(w / 2)
	for side in [1, -1]:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value + (0 if side == 1 else 1)
		var dist := 0.0
		while dist < w / 2 + 4:
			var bw := roundf(rng.randf_range(style["w"].x, style["w"].y))
			var detail := RandomNumberGenerator.new()
			detail.seed = rng.randi()
			draw_one.call(detail, center + dist if side == 1 else center - dist - bw, bw)
			dist += bw + roundf(rng.randf_range(style["gap"].x, style["gap"].y))

## Fundo: silhueta apagada pela distância, com o detalhe do estilo no
## telhado e poucas janelas acesas à noite.
func _draw_far_building(rng: RandomNumberGenerator, x: float, bw: float, ground: float, building: Color, style: Dictionary) -> void:
	var bh := roundf(rng.randf_range(style["far"].x, style["far"].y) * REF_GROUND)
	var col := _tone(building.darkened(0.15), 0.5)
	var top := ground - bh
	_city.draw_rect(Rect2(x, top, bw, bh), col)
	var roll := rng.randf()
	match _scenery.get("style", "low"):
		"tower":
			if roll < 0.4:
				_city.draw_rect(Rect2(x + floorf(bw / 2), top - 5, 1, 5), col)
			elif roll < 0.7:
				_city.draw_rect(Rect2(x + 2, top - 4, bw - 4, 4), col)
		"colonial":
			if roll < 0.2:
				_city.draw_rect(Rect2(x + floorf(bw / 2) - 2, top - 9, 4, 9), col)
				_city.draw_colored_polygon(PackedVector2Array([Vector2(x + floorf(bw / 2) - 3, top - 9), Vector2(x + floorf(bw / 2) + 3, top - 9), Vector2(x + floorf(bw / 2), top - 14)]), col)
			elif roll < 0.35:
				_city.draw_circle(Vector2(x + floorf(bw / 2), top), 4, col)
		"adobe":
			if roll < 0.25:
				_city.draw_circle(Vector2(x + floorf(bw / 2), top), minf(bw / 3, 5), col)
		_:
			if roll < 0.3:
				_city.draw_rect(Rect2(x + 2, top - 3, 4, 3), col)
	if _night():
		for i in int(bw * bh / 40):
			_city.draw_rect(Rect2(x + 1 + floorf(rng.randf() * (bw - 2)), top + 1 + floorf(rng.randf() * (bh - 2)), 1, 1), LAMP.darkened(0.25))

## Meio: prédio com cor própria (variação da paleta), luz no alto, sombra à
## direita, janelas e telhado conforme o estilo.
func _draw_building(rng: RandomNumberGenerator, x: float, bw: float, ground: float, building: Color, style: Dictionary) -> void:
	var kind: String = _scenery.get("style", "low")
	var bh := roundf(rng.randf_range(style["mid"].x, style["mid"].y) * REF_GROUND)
	var spread := 0.12 if kind == "colonial" else 0.05
	var face := Color.from_hsv(fposmod(building.h + rng.randf_range(-spread, spread), 1.0),
		clampf(building.s * rng.randf_range(0.7, 1.6 if kind == "colonial" else 1.3), 0.0, 1.0),
		clampf(building.v * rng.randf_range(0.82, 1.05), 0.0, 1.0))
	if kind == "tower":
		face = face.lerp(_sky_colors()[1], 0.2)
	face = _tone(face, 0.05)
	var top := ground - bh
	_city.draw_rect(Rect2(x, top, bw, bh), face)
	_city.draw_rect(Rect2(x + bw - 2, top, 2, bh), face.darkened(0.18))
	_city.draw_rect(Rect2(x, top, bw, 1), face.lightened(0.15))
	# janela: [largura, altura, passo x, passo y, margem, chance de existir]
	var grid: Array = {"tower": [2, 1, 3, 2, 2, 1.0], "colonial": [2, 3, 4, 5, 2, 1.0], "low": [2, 2, 4, 4, 2, 1.0], "adobe": [2, 2, 5, 5, 3, 0.5]}[kind]
	var dark := face.darkened(0.35)
	if kind == "tower":
		dark = _tone(_sky_colors()[1], 0.0).lerp(face, 0.5)
	var y := top + 3
	while y + grid[1] < ground - 2:
		var wx: float = x + grid[4]
		while wx + grid[0] < x + bw - 2:
			var roll := rng.randf()
			if rng.randf() < grid[5]:
				_city.draw_rect(Rect2(wx, y, grid[0], grid[1]), LAMP if _night() and roll < 0.45 else dark)
			wx += grid[2]
		y += grid[3]
	var roof := rng.randf()
	match kind:
		"tower":
			if roof < 0.35:
				_city.draw_rect(Rect2(x + floorf(bw / 3), top - rng.randi_range(3, 7), 1, 7), face.darkened(0.3))
			elif roof < 0.65:
				_city.draw_rect(Rect2(x + 2, top - 3, bw - 4, 3), face.darkened(0.1))
		"colonial":
			if roof < 0.6:
				_city.draw_colored_polygon(PackedVector2Array([Vector2(x - 1, top), Vector2(x + bw + 1, top), Vector2(x + bw / 2, top - 5)]), _tone(Color("#B5533C"), 0.05))
			else:
				_city.draw_rect(Rect2(x, top - 3, bw, 3), _tone(Color("#56606E"), 0.05))
				for dx in range(2, int(bw) - 2, 5):
					_city.draw_rect(Rect2(x + dx, top - 2, 1, 1), face.lightened(0.2))
			_city.draw_rect(Rect2(x + floorf(bw / 2) - 1, ground - 4, 3, 4), face.darkened(0.45))
		"low":
			if roof < 0.4:
				_city.draw_rect(Rect2(x + 2, top - 3, 4, 3), _tone(Color("#5B7FA6"), 0.05))
			elif roof < 0.6:
				_city.draw_rect(Rect2(x + bw - 6, top - 2, 3, 2), face.darkened(0.25))
		"adobe":
			_city.draw_rect(Rect2(x, top - 1, bw, 1), face.lightened(0.1))
			if roof < 0.2:
				_city.draw_circle(Vector2(x + floorf(bw / 2), top), minf(bw / 3, 5), _tone(Color("#EDEBE3"), 0.05))
			_city.draw_rect(Rect2(x + floorf(bw / 2) - 1, ground - 4, 3, 4), face.darkened(0.45))

## Frente: faixa da cor da cidade e, embaixo, rua, cais com água, orla ou
## areia, conforme o terreno.
func _draw_front(seed_value: int, w: float, ground: float, accent: Color) -> void:
	var h := art_size().y
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	_city.draw_rect(Rect2(0, ground, w, 1), _tone(accent))
	var y := ground + 1
	match _terrain():
		"water":
			_city.draw_rect(Rect2(0, y, w, 2), _tone(Color("#9A9488")))
			_city.draw_rect(Rect2(0, y + 2, w, 1), _tone(Color("#5C5850")))
			_draw_water(rng, w, y + 3, h)
		"beach":
			# calçadão em ondas pretas e brancas
			for x in int(w):
				for row in 2:
					var wave := posmod(x + (2 if row == 1 else 0), 4) < 2
					_city.draw_rect(Rect2(x, y + row, 1, 1), _tone(Color("#EDE7DA") if wave else Color("#3A3A3A")))
			_city.draw_rect(Rect2(0, y + 2, w, 4), _tone(Color("#E8D3A0")))
			for i in int(w / 4):
				_city.draw_rect(Rect2(floorf(rng.randf() * w), y + 2 + floorf(rng.randf() * 4), 1, 1), _tone(Color("#CDB27A")))
			_draw_water(rng, w, y + 6, h)
		"desert":
			_city.draw_rect(Rect2(0, y, w, h - y), _tone(Color("#D8B979")))
			_city.draw_rect(Rect2(0, y + 4, w, 2), _tone(Color("#8C7A5A")))
			for i in int(w / 2):
				var c := Color("#E6CB92") if rng.randf() < 0.5 else Color("#C4A266")
				_city.draw_rect(Rect2(floorf(rng.randf() * w), y + floorf(rng.randf() * (h - y)), 1, 1), _tone(c))
		_:
			_city.draw_rect(Rect2(0, y, w, 2), _tone(Color("#B9B4A8")))
			_city.draw_rect(Rect2(0, y + 2, w, 1), _tone(Color("#77736B")))
			_city.draw_rect(Rect2(0, y + 3, w, 6), _tone(Color("#3E3F46")))
			var center := floorf(w / 2)
			for k in range(-int(w / 16) - 1, int(w / 16) + 2):
				_city.draw_rect(Rect2(center + k * 8, y + 5, 4, 1), _tone(Color("#E9E3C9")))
			_city.draw_rect(Rect2(0, y + 9, w, h - y - 9), _tone(accent.darkened(0.45)))
			for k in range(-int(w / 60) - 1, int(w / 60) + 2):
				_draw_lamp_post(center + 15 + k * 30, ground + 1)

func _draw_water(rng: RandomNumberGenerator, w: float, top: float, h: float) -> void:
	var water := _tone(Color("#2F6E9E").lerp(_sky_colors()[1], 0.3))
	_city.draw_rect(Rect2(0, top, w, h - top), water)
	for i in int(w / 6):
		_city.draw_rect(Rect2(floorf(rng.randf() * w), top + 1 + floorf(rng.randf() * (h - top - 1)), rng.randi_range(2, 6), 1), water.lightened(0.12))

func _draw_lamp_post(x: float, base: float) -> void:
	var pole := _tone(Color("#4A4A52"))
	_city.draw_rect(Rect2(x, base - 8, 1, 8), pole)
	_city.draw_rect(Rect2(x - 1, base - 9, 3, 1), pole)
	if _night():
		_city.draw_circle(Vector2(x, base - 8), 3, Color(LAMP, 0.25))
		_city.draw_rect(Rect2(x - 1, base - 8, 3, 1), LAMP)

## Árvores na calçada/cais, do centro pras bordas, longe do marco.
func _draw_vegetation(seed_value: int, w: float, ground: float, lm: Rect2) -> void:
	var kind: String = _scenery.get("vegetation", "none")
	if kind == "none":
		return
	var center := floorf(w / 2)
	for side in [1, -1]:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value + (0 if side == 1 else 1)
		var dist := rng.randf_range(8, 24)
		while dist < w / 2 + 8:
			var x := roundf(center + dist * side)
			var growth := rng.randf()
			if x < lm.position.x - 4 or x > lm.end.x + 4:
				_draw_plant(kind, x, ground, growth)
			dist += rng.randf_range(18, 40)

func _draw_plant(kind: String, x: float, ground: float, growth: float) -> void:
	var leaf := _tone(Color("#2E8B57"))
	var trunk := _tone(Color("#6B4A2B"))
	match kind:
		"palm":
			var h := 10 + roundf(growth * 4)
			for i in h:
				_city.draw_rect(Rect2(x + roundf(sin(i * 0.15) * 1.5), ground - i - 1, 1, 1), trunk)
			var top := Vector2(x + roundf(sin(h * 0.15) * 1.5), ground - h)
			for f in [Vector2(-5, 3), Vector2(-4, -1), Vector2(0, -3), Vector2(4, -1), Vector2(5, 3)]:
				_city.draw_line(top, top + f, leaf, 1.0)
			_city.draw_rect(Rect2(top.x, top.y + 1, 1, 1), _tone(Color("#5A3E1F")))
		"tree":
			var r := 3.0 + roundf(growth)
			_city.draw_rect(Rect2(x, ground - 3, 1, 3), trunk)
			_city.draw_circle(Vector2(x, ground - 3 - r), r, leaf)
			_city.draw_circle(Vector2(x - 1, ground - 4 - r), r - 1.5, leaf.lightened(0.15))
		"conifer":
			var h := 9 + roundf(growth * 3)
			_city.draw_rect(Rect2(x, ground - 2, 1, 2), trunk)
			_city.draw_colored_polygon(PackedVector2Array([Vector2(x - 3, ground - 2), Vector2(x + 4, ground - 2), Vector2(x + 0.5, ground - h)]), leaf.darkened(0.25))
		"cypress":
			var h := 9 + roundf(growth * 4)
			_city.draw_rect(Rect2(x - 1, ground - h, 3, h - 1), leaf.darkened(0.3))
			_city.draw_rect(Rect2(x, ground - h - 1, 1, 1), leaf.darkened(0.3))

## --- Animação (RF84) ---------------------------------------------------------

## Brilho na água e espuma na orla, mudando com o tempo.
func _paint_fx() -> void:
	if city.is_empty() or not _terrain() in ["water", "beach"]:
		return
	var w := art_size().x
	var h := art_size().y
	var top := _ground() + (7.0 if _terrain() == "beach" else 4.0)
	var spark := Color(LAMP, 0.6) if _night() else Color(1, 1, 1, 0.7)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in int(w / 10):
		var x := floorf(rng.randf() * w)
		var y := top + 1 + floorf(rng.randf() * maxf(h - top - 2, 1))
		if fposmod(_time * rng.randf_range(0.4, 1.0) + rng.randf(), 1.0) < 0.4:
			_fx.draw_rect(Rect2(x, y, 2, 1), spark)
	if _terrain() == "beach":
		for x in int(w):
			if sin(x * 0.3 + _time * 2.0) > 0.5:
				_fx.draw_rect(Rect2(x, top - 1, 1, 1), Color(1, 1, 1, 0.8))
