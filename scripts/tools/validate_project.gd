extends SceneTree
## Ferramenta: carrega todos os scripts e recursos de scripts/, data/ e scenes/ e
## acusa os que falham (erros de compilação, recursos quebrados).
## Uso: godot --headless --path . -s res://scripts/tools/validate_project.gd
## Roda no primeiro quadro, quando os autoloads já existem.

const FOLDERS: PackedStringArray = ["res://scripts", "res://data", "res://scenes"]
const EXTENSIONS: PackedStringArray = ["gd", "tres", "tscn"]

var _done: bool = false


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	var failures: int = 0
	var count: int = 0
	for folder in FOLDERS:
		for path in _files(folder):
			count += 1
			var resource: Resource = load(path)
			if resource == null:
				failures += 1
				printerr("FALHOU: ", path)
			elif resource is GDScript and not (resource as GDScript).can_instantiate():
				failures += 1
				printerr("NÃO COMPILA: ", path)
	print("validate_project: %d arquivos, %d com erro" % [count, failures])
	return true


func _files(folder: String) -> PackedStringArray:
	var result := PackedStringArray()
	var dir := DirAccess.open(folder)
	if dir == null:
		return result
	for sub in dir.get_directories():
		result.append_array(_files(folder.path_join(sub)))
	for file in dir.get_files():
		if file.get_extension() in EXTENSIONS:
			result.append(folder.path_join(file))
	return result
