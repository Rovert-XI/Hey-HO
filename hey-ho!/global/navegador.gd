class_name Navegador
extends RefCounted
## Cambia de escena con un fundido a negro. Sin autoload: todo es estático.
## Uso:  Navegador.ir_a(self, Navegador.MENU)

const SPLASH := "res://ui/menus/splash.tscn"
const MENU := "res://ui/menus/menu_principal.tscn"
const NIVELES := "res://ui/menus/seleccion_nivel.tscn"
const OPCIONES := "res://ui/menus/opciones.tscn"
const CREDITOS := "res://ui/menus/creditos.tscn"
const RESULTADO := "res://ui/juego/resultado.tscn"
const TIENDA := "res://ui/juego/tienda.tscn"
const FINAL := "res://ui/juego/final_reparacion.tscn"

static var _ocupado := false


static func ir_a(desde: Node, ruta: String, duracion := 0.3) -> void:
	if _ocupado:
		return
	_ocupado = true
	var arbol := desde.get_tree()
	arbol.paused = false
	# La capa vive en la raíz del árbol, así sobrevive al cambio de escena.
	var capa := CanvasLayer.new()
	capa.layer = 100
	capa.process_mode = Node.PROCESS_MODE_ALWAYS
	var velo := ColorRect.new()
	velo.color = Color(UITema.NOCHE, 0.0)
	velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	velo.mouse_filter = Control.MOUSE_FILTER_STOP
	capa.add_child(velo)
	arbol.root.add_child(capa)

	var entrada := capa.create_tween()
	entrada.tween_property(velo, "color:a", 1.0, duracion)
	await entrada.finished
	arbol.change_scene_to_file(ruta)
	await arbol.process_frame
	await arbol.process_frame
	var salida := capa.create_tween()
	salida.tween_property(velo, "color:a", 0.0, duracion)
	await salida.finished
	capa.queue_free()
	_ocupado = false


static func salir(desde: Node) -> void:
	desde.get_tree().quit()
