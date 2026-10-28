class_name SaveService
extends RefCounted
## Formato do save (JSON em user://) — isolado do GameManager, que só é dono
## do estado. Só a carreira persiste; caso em andamento não é salvo.
##
## Nome exclusivo do jogo: na versão Web o user:// de todo jogo Godot
## publicado no mesmo domínio (luiz-maehana.github.io) é o mesmo IndexedDB,
## então um "career.json" genérico colidiria com outro jogo.

const SAVE_PATH := "user://onde_esta_flavio_career.json"
## Nome antigo (até a v1.0.0) — lido uma vez e migrado.
const LEGACY_PATH := "user://career.json"
## Save legítimo tem ~100 bytes; acima disso é lixo/adulteração.
const MAX_BYTES := 4096
## Ferramentas (prévia de telas) ligam isso pra nunca gravar por cima dos
## saves reais do jogador.
static var read_only := false

static func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH) or FileAccess.file_exists(LEGACY_PATH)

static func save(career: Career) -> void:
	if read_only:
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveService: não conseguiu gravar %s" % SAVE_PATH)
		return
	file.store_string(JSON.stringify(career.to_dict(), "\t"))

## Career vazia se não existir, estiver corrompido ou grande demais.
static func load() -> Career:
	var path := SAVE_PATH if FileAccess.file_exists(SAVE_PATH) else LEGACY_PATH
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES:
		return Career.new()
	var data = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return Career.new()
	var career := Career.from_dict(data)
	if path == LEGACY_PATH:
		save(career)
	return career

## --- Caso em andamento (RF27) ---------------------------------------------------
## Só semente + configuração + ações (ver CaseState.to_save/from_save).

const CASE_PATH := "user://onde_esta_flavio_case.json"
const CASE_MAX_BYTES := 65536
## Em read_only o caso vai pra memória: testes e prévias exercitam salvar e
## continuar sem ler nem gravar o caso real do jogador.
static var _memory_case := ""

static func save_case(state: CaseState) -> void:
	var text := JSON.stringify(state.to_save())
	if read_only:
		_memory_case = text
		return
	var file := FileAccess.open(CASE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(text)

## Caso salvo refeito, ou null se não houver ou for inválido.
static func load_case() -> CaseState:
	var text := _memory_case
	if not read_only:
		var file := FileAccess.open(CASE_PATH, FileAccess.READ)
		if file == null or file.get_length() > CASE_MAX_BYTES:
			return null
		text = file.get_as_text()
	if text == "":
		return null
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		return null
	var state := CaseState.from_save(data)
	if state == null or state.is_over():
		return null
	return state

static func clear_case() -> void:
	if read_only:
		_memory_case = ""
		return
	if FileAccess.file_exists(CASE_PATH):
		DirAccess.remove_absolute(CASE_PATH)
