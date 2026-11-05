class_name Integrador
extends RefCounted
## Solución del Nivel 3. Funciones puras para simular física con Euler semi-implícito.

static func paso(pos: Vector3, vel: Vector3, acel: Vector3, dt: float) -> Array:
	# TODO 1: la velocidad nueva, con la aceleración (Euler semi-implícito: v_nueva = v + a * dt)
	var vel_nueva := vel + acel * dt
	# TODO 2: la posición nueva, con la velocidad NUEVA
	var pos_nueva := pos + vel_nueva * dt
	return [pos_nueva, vel_nueva]

static func simular(pos: Vector3, vel: Vector3, acel: Vector3, dt: float, n: int) -> Array:
	# TODO 3: repetir paso() n veces y devolver [posición, velocidad]
	var p := pos
	var v := vel
	for i in range(n):
		var res := paso(p, v, acel, dt)
		p = res[0]
		v = res[1]
	return [p, v]
