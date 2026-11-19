class_name FilaSoga
extends VBoxContainer
## Una fila del panel de sogas del HUD: las dos sogas de una plataforma.
## MADERA = soga sana · ROJO = bajo 30 (se deshilacha) · etiqueta roja cuando la plataforma se desestabiliza.

const UMBRAL_PELIGRO := 30.0

@onready var nombre: Label = %Nombre
@onready var barra_a: ProgressBar = %BarraA
@onready var barra_b: ProgressBar = %BarraB
@onready var estado: Label = %Estado
@onready var barra_reparar: ProgressBar = %BarraReparar

var clave := ""
var _resistencia: Array[float] = [100.0, 100.0]
var _inestable := false


func configurar(clave_plataforma: String, titulo: String) -> void:
	clave = clave_plataforma
	nombre.text = titulo
	poner_resistencia(0, 100.0)
	poner_resistencia(1, 100.0)
	poner_reparacion(0.0)


func poner_resistencia(indice: int, valor: float) -> void:
	_resistencia[indice] = valor
	var barra := barra_a if indice == 0 else barra_b
	barra.value = valor
	barra.theme_type_variation = &"BarraRoja" if valor < UMBRAL_PELIGRO else &"BarraMadera"
	_refrescar_estado()


func poner_inestable(valor: bool) -> void:
	_inestable = valor
	_refrescar_estado()


func poner_reparacion(fraccion: float) -> void:
	barra_reparar.visible = fraccion > 0.0
	barra_reparar.value = fraccion


func _refrescar_estado() -> void:
	var rotas := int(_resistencia[0] <= 0.0) + int(_resistencia[1] <= 0.0)
	if rotas >= 2:
		estado.text = "¡SE SUELTA!"
	elif rotas == 1 or _inestable:
		estado.text = "¡INESTABLE!"
	else:
		estado.text = ""
