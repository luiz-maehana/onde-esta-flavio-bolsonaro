class_name WebTextInput
extends Node
## Campo de texto nativo do navegador por cima de um LineEdit (celular na
## versão Web). O Godot foca o teclado virtual um quadro depois do toque, e
## navegadores de celular — principalmente os internos do Instagram, Facebook
## e WhatsApp — só abrem o teclado com foco dentro do próprio toque. Com um
## <input> de verdade por cima, o toque cai direto nele e o teclado abre.
## O texto digitado volta pro LineEdit; Enter emite `submitted`.

signal submitted

const ELEMENT_ID := "furo-text-input"

var _edit: LineEdit
## Callbacks do JavaScript precisam ficar referenciados enquanto existirem.
var _on_input: JavaScriptObject
var _on_key: JavaScriptObject
## Elemento <input> da página (JavaScriptObject; sem tipo pra acessar
## propriedades do JavaScript como maxLength e style).
var _element

## Só no navegador com tela de toque; no PC o LineEdit do jogo funciona.
static func needed() -> bool:
	return OS.has_feature("web") and Responsive.is_touch()

## Liga o campo nativo ao LineEdit: posição, tamanho limite e visibilidade
## acompanham o LineEdit.
func attach(edit: LineEdit) -> void:
	_edit = edit
	edit.virtual_keyboard_enabled = false
	edit.add_child(self)

func _ready() -> void:
	JavaScriptBridge.eval("""
		(function () {
			var el = document.getElementById('%s');
			if (!el) {
				el = document.createElement('input');
				el.id = '%s';
				el.type = 'text';
				el.autocomplete = 'off';
				el.setAttribute('autocapitalize', 'words');
				el.setAttribute('enterkeyhint', 'done');
				document.body.appendChild(el);
			}
			Object.assign(el.style, {
				position: 'fixed', zIndex: '10', boxSizing: 'border-box', margin: '0',
				padding: '0 10px', border: '3px solid #C8102E', borderRadius: '0',
				background: '#FFFFFF', color: '#141414', fontSize: '18px',
				fontFamily: 'monospace', outline: 'none', display: 'none'
			});
		})();
	""" % [ELEMENT_ID, ELEMENT_ID])
	_element = JavaScriptBridge.get_interface("document").getElementById(ELEMENT_ID)
	_element.maxLength = _edit.max_length
	_element.placeholder = Lang.t(_edit.placeholder_text)
	_element.value = _edit.text
	_on_input = JavaScriptBridge.create_callback(_js_input)
	_on_key = JavaScriptBridge.create_callback(_js_key)
	_element.addEventListener("input", _on_input)
	_element.addEventListener("keydown", _on_key)
	_edit.visibility_changed.connect(_sync)
	_edit.resized.connect(_sync)
	get_tree().root.size_changed.connect(_sync)
	_sync.call_deferred()

func _exit_tree() -> void:
	if _element:
		_element.removeEventListener("input", _on_input)
		_element.removeEventListener("keydown", _on_key)
		_element.style.display = "none"

## Põe o campo nativo exatamente sobre o LineEdit (px de CSS) ou esconde.
func _sync() -> void:
	if not is_instance_valid(_edit) or _element == null:
		return
	if not _edit.is_visible_in_tree():
		_element.style.display = "none"
		return
	var rect := _edit.get_viewport().get_screen_transform() * _edit.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, _edit.size)
	var css := rect.size.abs() / maxf(DisplayServer.screen_get_scale(), 1.0)
	var pos := rect.position / maxf(DisplayServer.screen_get_scale(), 1.0)
	_element.style.left = "%dpx" % int(pos.x)
	_element.style.top = "%dpx" % int(pos.y)
	_element.style.width = "%dpx" % int(css.x)
	_element.style.height = "%dpx" % int(css.y)
	_element.value = _edit.text
	_element.style.display = "block"

func _js_input(_args: Array) -> void:
	_edit.text = str(_element.value).left(_edit.max_length)

func _js_key(args: Array) -> void:
	if args.size() > 0 and str(args[0].key) == "Enter":
		_element.blur()
		submitted.emit()
