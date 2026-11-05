class_name ControlJugador
extends CharacterBody3D
## Coordina las tres piezas. Va en "Jugador"; sus hijos LectorEntrada, Motor y Orientador
## son nodos Node con su script.

@export var mostrar_rapidez := false   # Nivel 1: rapidez real en consola

@onready var lector: LectorEntrada = $LectorEntrada
@onready var motor: Motor = $Motor
@onready var orientador: Orientador = $Orientador

var posicion_anterior := Vector3.ZERO


func _ready() -> void:
	posicion_anterior = position


func _process(delta: float) -> void:
	var direccion := lector.leer_direccion()
	motor.avanzar(direccion, delta)
	orientador.mirar(direccion, delta)

	if mostrar_rapidez and delta > 0.0:
		print("rapidez: %.2f m/s" % (Vectores.longitud(position - posicion_anterior) / delta))
	posicion_anterior = position
