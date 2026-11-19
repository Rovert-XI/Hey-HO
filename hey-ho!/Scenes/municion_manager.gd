extends Node
class_name MunicionManager

signal cantidad_prendas_cambiada(nueva_cantidad: int)

@export var prendas_iniciales := 0

var cantidad_prendas: int = 0


func _ready() -> void:
	cantidad_prendas = max(prendas_iniciales, 0)
	cantidad_prendas_cambiada.emit(cantidad_prendas)


func tiene_prendas() -> bool:
	return cantidad_prendas > 0


func agregar_prendas(cantidad: int = 1) -> void:
	if cantidad <= 0:
		return
	cantidad_prendas += cantidad
	cantidad_prendas_cambiada.emit(cantidad_prendas)
	print("Prendas en inventario: ", cantidad_prendas)


func consumir_prenda(cantidad: int = 1) -> bool:
	if cantidad_prendas < cantidad:
		return false
	cantidad_prendas -= cantidad
	cantidad_prendas_cambiada.emit(cantidad_prendas)
	print("Prendas restantes: ", cantidad_prendas)
	return true
