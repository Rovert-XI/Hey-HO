extends Node
class_name MunicionManager

signal cantidad_prendas_cambiada(nueva_cantidad: int)
signal inventario_prendas_actualizado(cola_prendas: Array[PrendaProyectil.EstadoPrenda])
signal estado_seleccionado_cambiado(estado_activo: PrendaProyectil.EstadoPrenda)

@export var prendas_iniciales := 0
@export var estado_inicial: PrendaProyectil.EstadoPrenda = PrendaProyectil.EstadoPrenda.SUCIA

var estado_seleccionado: PrendaProyectil.EstadoPrenda = PrendaProyectil.EstadoPrenda.SUCIA

var _conteos := {
	PrendaProyectil.EstadoPrenda.SUCIA: 0,
	PrendaProyectil.EstadoPrenda.LAVADA: 0,
	PrendaProyectil.EstadoPrenda.SECA: 0
}

var _hud: HudInventarioPrendas = null

# Propiedad calculada para mantener compatibilidad con scripts o UI que lean cantidad_prendas.
var cantidad_prendas: int:
	get:
		return (
			_conteos[PrendaProyectil.EstadoPrenda.SUCIA]
			+ _conteos[PrendaProyectil.EstadoPrenda.LAVADA]
			+ _conteos[PrendaProyectil.EstadoPrenda.SECA]
		)


func _ready() -> void:
	_conteos[PrendaProyectil.EstadoPrenda.SUCIA] = 0
	_conteos[PrendaProyectil.EstadoPrenda.LAVADA] = 0
	_conteos[PrendaProyectil.EstadoPrenda.SECA] = 0
	estado_seleccionado = estado_inicial

	if prendas_iniciales > 0:
		_conteos[estado_inicial] = prendas_iniciales

	call_deferred("_inicializar_hud")
	_notificar_cambio()


func _inicializar_hud() -> void:
	var raiz := get_tree().current_scene
	if raiz == null:
		return

	_hud = raiz.find_child("HudInventarioPrendas", true, false) as HudInventarioPrendas
	if _hud == null:
		_hud = HudInventarioPrendas.new()
		_hud.name = "HudInventarioPrendas"
		raiz.add_child(_hud)

	if not _hud.tipo_seleccionado_cambiado.is_connected(_on_hud_tipo_seleccionado):
		_hud.tipo_seleccionado_cambiado.connect(_on_hud_tipo_seleccionado)

	_sincronizar_hud()


func tiene_prendas() -> bool:
	return _conteos.get(estado_seleccionado, 0) > 0


func obtener_cantidad_por_estado(estado: PrendaProyectil.EstadoPrenda) -> int:
	return _conteos.get(estado, 0)


# Devuelve el estado seleccionado si tiene al menos 1 unidad disponible, o -1 si está vacío.
func obtener_siguiente_estado() -> int:
	if _conteos.get(estado_seleccionado, 0) <= 0:
		return -1
	return int(estado_seleccionado)


func seleccionar_estado(nuevo_estado: PrendaProyectil.EstadoPrenda) -> void:
	if estado_seleccionado == nuevo_estado:
		return
	estado_seleccionado = nuevo_estado
	_sincronizar_hud()
	estado_seleccionado_cambiado.emit(estado_seleccionado)
	_notificar_cambio()


func agregar_prendas(
	cantidad: int = 1,
	estado: PrendaProyectil.EstadoPrenda = PrendaProyectil.EstadoPrenda.SUCIA
) -> void:
	if cantidad <= 0:
		return

	var activo_estaba_vacio: bool = (_conteos.get(estado_seleccionado, 0) == 0)
	_conteos[estado] = _conteos.get(estado, 0) + cantidad

	if activo_estaba_vacio:
		estado_seleccionado = estado
		estado_seleccionado_cambiado.emit(estado_seleccionado)

	_notificar_cambio()
	print("Inventario -> ", _obtener_resumen_texto())


# Consume 1 prenda del estado seleccionado actualmente y devuelve su EstadoPrenda (o -1 si está en 0).
func consumir_siguiente_prenda() -> int:
	var disponibles: int = _conteos.get(estado_seleccionado, 0)
	if disponibles <= 0:
		return -1

	_conteos[estado_seleccionado] = disponibles - 1
	var estado_consumido := estado_seleccionado
	_notificar_cambio()
	print(
		"Lanzada: ",
		PrendaProyectil.EstadoPrenda.keys()[estado_consumido],
		" | Restante -> ",
		_obtener_resumen_texto()
	)
	return int(estado_consumido)


# Mantiene compatibilidad con llamadas anteriores que solo esperaban un booleano.
func consumir_prenda(cantidad: int = 1) -> bool:
	var disponibles: int = _conteos.get(estado_seleccionado, 0)
	if disponibles < cantidad:
		return false

	_conteos[estado_seleccionado] = disponibles - cantidad
	_notificar_cambio()
	return true


func _on_hud_tipo_seleccionado(nuevo_estado: PrendaProyectil.EstadoPrenda) -> void:
	seleccionar_estado(nuevo_estado)


func _sincronizar_hud() -> void:
	if is_instance_valid(_hud):
		_hud.actualizar_conteos(
			_conteos[PrendaProyectil.EstadoPrenda.SUCIA],
			_conteos[PrendaProyectil.EstadoPrenda.LAVADA],
			_conteos[PrendaProyectil.EstadoPrenda.SECA],
			estado_seleccionado
		)


func _notificar_cambio() -> void:
	_sincronizar_hud()
	cantidad_prendas_cambiada.emit(cantidad_prendas)
	inventario_prendas_actualizado.emit(_construir_lista_compatibilidad())


func _construir_lista_compatibilidad() -> Array[PrendaProyectil.EstadoPrenda]:
	var lista: Array[PrendaProyectil.EstadoPrenda] = []
	var orden := [
		estado_seleccionado,
		PrendaProyectil.EstadoPrenda.SUCIA,
		PrendaProyectil.EstadoPrenda.LAVADA,
		PrendaProyectil.EstadoPrenda.SECA
	]
	var procesados := {}
	for est in orden:
		if procesados.has(est):
			continue
		procesados[est] = true
		for i in range(_conteos.get(est, 0)):
			lista.append(est)
	return lista


func _obtener_resumen_texto() -> String:
	return "Sucia: %d | Lavada: %d | Seca: %d (Activa: %s)" % [
		_conteos[PrendaProyectil.EstadoPrenda.SUCIA],
		_conteos[PrendaProyectil.EstadoPrenda.LAVADA],
		_conteos[PrendaProyectil.EstadoPrenda.SECA],
		PrendaProyectil.EstadoPrenda.keys()[estado_seleccionado]
	]
