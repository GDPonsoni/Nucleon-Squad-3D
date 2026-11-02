extends SceneTree
## Ferramenta: gera os PNGs do ícone do app a partir dos SVGs.
## Uso: godot --headless --path . -s res://scripts/tools/render_icons.gd

const OUTPUTS := {
	"res://icon.svg": ["res://assets/icon/icon_192.png", 192],
	"res://assets/icon/icon_foreground.svg": ["res://assets/icon/icon_foreground.png", 432],
	"res://assets/icon/icon_background.svg": ["res://assets/icon/icon_background.png", 432],
	"res://assets/icon/icon_monochrome.svg": ["res://assets/icon/icon_monochrome.png", 432],
}


func _initialize() -> void:
	for source: String in OUTPUTS:
		var target: String = OUTPUTS[source][0]
		var size: int = OUTPUTS[source][1]
		var image := Image.new()
		# Os SVGs têm 432 px; a escala ajusta para o tamanho final
		var error := image.load_svg_from_string(FileAccess.get_file_as_string(source), size / 432.0)
		if error != OK:
			push_error("Falha ao ler %s: %s" % [source, error_string(error)])
			continue
		image.save_png(target)
		print("%s -> %s (%dx%d)" % [source, target, image.get_width(), image.get_height()])
	quit()
