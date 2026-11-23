extends Node
class_name MunicionManager

signal cantidad_prendas_cambiada(nueva_cantidad: int)
signal inventario_prendas_actualizado(cola_prendas: Array[PrendaProyectil.EstadoPrenda])

@export var prendas_iniciales := 0
@export var estado_inicial: PrendaProyectil.EstadoPrenda = PrendaProyectil.EstadoPrenda.SUCIA

var _cola_prendas: Array[PrendaProyectil.EstadoPrenda] = []

# Propiedad calculada para mantener compatibilidad con scripts o UI que lean cantidad_prendas.
var cantidad_prendas: int:
	get:
		return _cola_prendas.size()


func _ready() -> void:
	_cola_prendas.clear()
	for i in range(maxi(prendas_iniciales, 0)):
		_cola_prendas.append(estado_inicial)
	_notificar_cambio()


func tiene_prendas() -> bool:
	return not _cola_prendas.is_empty()


# Permite consultar sin consumir qué estado tiene la próxima prenda a disparar.
func obtener_siguiente_estado() -> int:
	if _cola_prendas.is_empty():
		return -1
	return _cola_prendas[0]


func agregar_prendas(
	cantidad: int = 1,
	estado: PrendaProyectil.EstadoPrenda = PrendaProyectil.EstadoPrenda.SUCIA
) -> void:
	if cantidad <= 0:
		return

	for i in range(cantidad):
		_cola_prendas.append(estado)

	_notificar_cambio()
	print("Prendas en inventario: ", cantidad_prendas, " | Cola: ", _obtener_resumen_estados())


# Consume la primera prenda en cola y devuelve su EstadoPrenda (o -1 si el inventario está vacío).
func consumir_siguiente_prenda() -> int:
	if _cola_prendas.is_empty():
		return -1

	var estado_consumido: PrendaProyectil.EstadoPrenda = _cola_prendas.pop_front()
	_notificar_cambio()
	print(
		"Prendas restantes: ",
		cantidad_prendas,
		" | Lanzada: ",
		PrendaProyectil.EstadoPrenda.keys()[estado_consumido]
	)
	return estado_consumido


# Mantiene compatibilidad con llamadas anteriores que solo esperaban un booleano.
func consumir_prenda(cantidad: int = 1) -> bool:
	if _cola_prendas.size() < cantidad:
		return false

	for i in range(cantidad):
		_cola_prendas.pop_front()

	_notificar_cambio()
	print("Prendas restantes: ", cantidad_prendas)
	return true


func _notificar_cambio() -> void:
	cantidad_prendas_cambiada.emit(cantidad_prendas)
	inventario_prendas_actualizado.emit(_cola_prendas.duplicate())


func _obtener_resumen_estados() -> Array[String]:
	var nombres: Array[String] = []
	for estado_item in _cola_prendas:
		nombres.append(PrendaProyectil.EstadoPrenda.keys()[estado_item])
	return nombres
