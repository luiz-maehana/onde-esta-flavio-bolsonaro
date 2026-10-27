class_name FlagPainter
extends RefCounted
## Bandeira simplificada (campo "flag" de cities.json) desenhada num
## retângulo — reconhecível de relance, não heráldica. Tipos: h/v (listras),
## disc, hdisc (listras + disco), diamond, canton, cross, side, star, crescent.

static func draw(ci: CanvasItem, r: Rect2, flag: Dictionary) -> void:
	var cols: Array = flag.get("colors", ["#CCCCCC"]).map(func(c): return Color(c))
	match flag.get("type", "h"):
		"v":
			_stripes(ci, r, cols, false)
		"disc":
			ci.draw_rect(r, cols[0])
			ci.draw_circle(r.get_center(), r.size.y * 0.3, cols[1])
		"hdisc":
			_stripes(ci, r, cols.slice(0, cols.size() - 1), true)
			ci.draw_circle(r.get_center(), r.size.y * 0.16, cols[-1])
		"diamond":
			ci.draw_rect(r, cols[0])
			var c := r.get_center()
			ci.draw_colored_polygon(PackedVector2Array([
				Vector2(r.position.x + 2, c.y), Vector2(c.x, r.position.y + 2),
				Vector2(r.end.x - 2, c.y), Vector2(c.x, r.end.y - 2)]), cols[1])
			ci.draw_circle(c, r.size.y * 0.22, cols[2])
		"canton":
			var n: int = flag.get("stripes", 7)
			var h := r.size.y / n
			for i in n:
				ci.draw_rect(Rect2(r.position.x, r.position.y + i * h, r.size.x, h + 0.5), cols[i % 2])
			ci.draw_rect(Rect2(r.position, Vector2(r.size.x * 0.4, r.size.y * (0.54 if n > 2 else 0.5))), cols[2])
		"cross":
			ci.draw_rect(r, cols[0])
			ci.draw_line(r.position, r.end, cols[1], 3)
			ci.draw_line(Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.position.y), cols[1], 3)
			ci.draw_rect(Rect2(r.position.x, r.get_center().y - 3, r.size.x, 6), cols[1])
			ci.draw_rect(Rect2(r.get_center().x - 3, r.position.y, 6, r.size.y), cols[1])
			ci.draw_rect(Rect2(r.position.x, r.get_center().y - 1.5, r.size.x, 3), cols[2])
			ci.draw_rect(Rect2(r.get_center().x - 1.5, r.position.y, 3, r.size.y), cols[2])
		"side":
			_stripes(ci, Rect2(r.position + Vector2(r.size.x * 0.28, 0), Vector2(r.size.x * 0.72, r.size.y)), cols.slice(1), true)
			ci.draw_rect(Rect2(r.position, Vector2(r.size.x * 0.28, r.size.y)), cols[0])
		"star":
			ci.draw_rect(r, cols[0])
			ci.draw_circle(r.position + Vector2(r.size.x * 0.22, r.size.y * 0.3), r.size.y * 0.16, cols[1])
		"crescent":
			ci.draw_rect(r, cols[0])
			var cc := r.get_center() - Vector2(r.size.x * 0.08, 0)
			ci.draw_circle(cc, r.size.y * 0.3, cols[1])
			ci.draw_circle(cc + Vector2(r.size.y * 0.1, 0), r.size.y * 0.24, cols[0])
		_:
			_stripes(ci, r, cols, true)
	ci.draw_rect(r, Palette.INK, false, 1.5)

static func _stripes(ci: CanvasItem, r: Rect2, cols: Array, horizontal: bool) -> void:
	var n := cols.size()
	for i in n:
		if horizontal:
			var h := r.size.y / n
			ci.draw_rect(Rect2(r.position.x, r.position.y + i * h, r.size.x, h + 0.5), cols[i])
		else:
			var w := r.size.x / n
			ci.draw_rect(Rect2(r.position.x + i * w, r.position.y, w + 0.5, r.size.y), cols[i])
