class_name Dossier
extends RefCounted
## Filtro de disfarces do Dossiê (RF08). `selected` é trait -> valor, com
## "" (ou chave ausente) significando "ainda não sei".

static func matching(selected: Dictionary) -> Array:
	var result: Array = []
	for d in GameData.disguises():
		if _matches(d, selected):
			result.append(d)
	return result

static func _matches(disguise: Dictionary, selected: Dictionary) -> bool:
	for trait_key in selected:
		var value: String = selected[trait_key]
		if value != "" and disguise.get(trait_key, "") != value:
			return false
	return true
