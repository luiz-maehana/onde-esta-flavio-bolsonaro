class_name SaveService
extends RefCounted
## Formato do save (JSON em user://) — isolado do GameManager, que só é dono
## do estado. Só a carreira persiste; caso em andamento não é salvo.

const SAVE_PATH := "user://career.json"

static func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

static func save(career: Career) -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveService: não conseguiu gravar %s" % SAVE_PATH)
		return
	file.store_string(JSON.stringify(career.to_dict(), "\t"))

## Career vazia se não existir ou estiver corrompido.
static func load() -> Career:
	if not has_save():
		return Career.new()
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var data = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return Career.new()
	return Career.from_dict(data)
