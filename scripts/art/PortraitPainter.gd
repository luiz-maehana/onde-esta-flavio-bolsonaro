class_name PortraitPainter
extends RefCounted
## Primitivas de desenho pixel a pixel numa Image 48x48 (retratos). Tudo em
## coordenadas inteiras de pixel; quem compõe o retrato é PortraitFactory.

const SIZE := 48

var img: Image

func _init() -> void:
	img = Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

func px(x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < SIZE and y < SIZE and c.a > 0.0:
		img.set_pixel(x, y, c)

func get_px(x: int, y: int) -> Color:
	if x < 0 or y < 0 or x >= SIZE or y >= SIZE:
		return Color(0, 0, 0, 0)
	return img.get_pixel(x, y)

func is_filled(x: int, y: int) -> bool:
	return get_px(x, y).a > 0.0

func rect(x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			px(xx, yy, c)

func hline(x1: int, x2: int, y: int, c: Color) -> void:
	for x in range(mini(x1, x2), maxi(x1, x2) + 1):
		px(x, y, c)

## Pixel dentro da elipse (centro e raios em float, amostra no centro do pixel).
static func in_ellipse(x: int, y: int, cx: float, cy: float, rx: float, ry: float) -> bool:
	var dx := (x + 0.5 - cx) / rx
	var dy := (y + 0.5 - cy) / ry
	return dx * dx + dy * dy <= 1.0

func ellipse(cx: float, cy: float, rx: float, ry: float, c: Color) -> void:
	for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
		for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
			if in_ellipse(x, y, cx, cy, rx, ry):
				px(x, y, c)

## Elipse com luz vindo da esquerda/topo: sombra no lado direito e embaixo,
## brilho pequeno em cima à esquerda.
func shaded_ellipse(cx: float, cy: float, rx: float, ry: float, base: Color) -> void:
	var shadow := base.darkened(0.18)
	var light := base.lightened(0.12)
	for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
		for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
			if not in_ellipse(x, y, cx, cy, rx, ry):
				continue
			var nx := (x + 0.5 - cx) / rx
			var ny := (y + 0.5 - cy) / ry
			var c := base
			if nx > 0.5 or ny > 0.72:
				c = shadow
			elif nx < -0.35 and ny < -0.3:
				c = light
			px(x, y, c)

func poly(points: Array, c: Color) -> void:
	var pts := PackedVector2Array()
	var min_v := Vector2(SIZE, SIZE)
	var max_v := Vector2.ZERO
	for p in points:
		var v := Vector2(p[0], p[1])
		pts.append(v)
		min_v = min_v.min(v)
		max_v = max_v.max(v)
	for y in range(int(min_v.y) - 1, int(max_v.y) + 2):
		for x in range(int(min_v.x) - 1, int(max_v.x) + 2):
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), pts):
				px(x, y, c)

## Linha de Bresenham com espessura em pixels.
func line(x1: int, y1: int, x2: int, y2: int, c: Color, thickness: int = 1) -> void:
	var dx := absi(x2 - x1)
	var dy := -absi(y2 - y1)
	var sx := 1 if x1 < x2 else -1
	var sy := 1 if y1 < y2 else -1
	var err := dx + dy
	var x := x1
	var y := y1
	while true:
		rect(x, y, thickness, thickness, c)
		if x == x2 and y == y2:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x += sx
		if e2 <= dx:
			err += dx
			y += sy

## Escurece os pixels já pintados dentro de uma região (sombra de roupa).
func darken_region(x: int, y: int, w: int, h: int, amount: float) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			var c := get_px(xx, yy)
			if c.a > 0.0:
				px(xx, yy, c.darkened(amount))

## Contorno externo de 1px: todo pixel vazio encostado (4 vizinhos) num
## pintado vira `c` — o "traço de tinta" clássico de pixel art.
func outline(c: Color) -> void:
	var to_paint: Array[Vector2i] = []
	for y in SIZE:
		for x in SIZE:
			if is_filled(x, y):
				continue
			if is_filled(x - 1, y) or is_filled(x + 1, y) or is_filled(x, y - 1) or is_filled(x, y + 1):
				to_paint.append(Vector2i(x, y))
	for p in to_paint:
		img.set_pixel(p.x, p.y, c)
