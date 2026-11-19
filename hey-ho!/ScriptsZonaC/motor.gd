class_name Motor
extends Node
## Responsabilidad: la velocidad (aceleración y fricción) y mover al nodo padre.

@export var velocidad_maxima := 5.0   # m/s
@export var aceleracion := 20.0       # m/s²
@export var friccion := 30.0          # m/s²

var velocidad := Vector3.ZERO


func avanzar(direccion: Vector3, dt: float) -> void:
	velocidad = siguiente_velocidad(velocidad, direccion, velocidad_maxima, aceleracion, friccion, dt)
	velocidad.x = 0.0
	(get_parent() as Node3D).position += velocidad * dt


## Función pura: no toca la escena, así que se puede probar con números.
static func siguiente_velocidad(actual: Vector3, direccion: Vector3, maxima: float,
		acel: float, fric: float, dt: float) -> Vector3:
	if direccion != Vector3.ZERO:
		return Vectores.acercar(actual, direccion * maxima, acel * dt)
	return Vectores.acercar(actual, Vector3.ZERO, fric * dt)
