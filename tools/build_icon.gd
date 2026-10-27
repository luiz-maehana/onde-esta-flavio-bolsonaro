extends SceneTree
## Gera assets/icon.png (ícone do projeto) e assets/icon.ico (ícone do .exe)
## a partir do retrato em pixel art do senador sobre fundo amarelo-Brasil.
## O .ico guarda PNGs embutidos (formato aceito desde o Windows Vista).
## Roda com: godot --headless --path . --script res://tools/build_icon.gd

const SIZES := [256, 128, 64, 48, 32, 16]

func _initialize() -> void:
	var big := _icon(256)
	big.save_png("res://assets/icon.png")
	var pngs: Array[PackedByteArray] = []
	for s in SIZES:
		pngs.append(_icon(s).save_png_to_buffer())
	_write_ico("res://assets/icon.ico", pngs)
	print("icon ok")
	quit()

func _icon(px: int) -> Image:
	var portrait := PortraitFactory.paint(PortraitFactory.flavio_wanted_spec())
	var img := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	img.fill(Palette.INK)
	img.fill_rect(Rect2i(8, 8, 240, 240), Palette.YELLOW)
	portrait.resize(240, 240, Image.INTERPOLATE_NEAREST)
	img.blend_rect(portrait, Rect2i(0, 0, 240, 240), Vector2i(8, 8))
	if px != 256:
		img.resize(px, px, Image.INTERPOLATE_NEAREST if px >= 48 else Image.INTERPOLATE_BILINEAR)
	return img

func _write_ico(path: String, pngs: Array[PackedByteArray]) -> void:
	var header := PackedByteArray()
	header.resize(6)
	header.encode_u16(0, 0)
	header.encode_u16(2, 1)
	header.encode_u16(4, pngs.size())
	var entries := PackedByteArray()
	var data := PackedByteArray()
	var offset := 6 + 16 * pngs.size()
	for i in pngs.size():
		var s: int = SIZES[i]
		var e := PackedByteArray()
		e.resize(16)
		e.encode_u8(0, 0 if s >= 256 else s)
		e.encode_u8(1, 0 if s >= 256 else s)
		e.encode_u8(2, 0)
		e.encode_u8(3, 0)
		e.encode_u16(4, 1)
		e.encode_u16(6, 32)
		e.encode_u32(8, pngs[i].size())
		e.encode_u32(12, offset)
		entries.append_array(e)
		data.append_array(pngs[i])
		offset += pngs[i].size()
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(header + entries + data)
