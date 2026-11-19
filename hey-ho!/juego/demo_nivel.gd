extends Node
## Escena de DEMOSTRACIÓN: simula un nivel para probar el HUD sin la lógica real.
## Reemplázala por la escena del nivel y llama a los mismos métodos del HUD (ver la guía).
##
## Teclas:  1/2/3 equipar · ESPACIO mantener: carga resortera · G pago +30 · P nuevo pedido
##          S desgastar soga · D romper soga de la lavadora · R mantener: reparar · L alerta loro
##          ENTER terminar aprobado · X perder por sogas · ESC pausa

@onready var hud: HudHeyHo = %Hud

var _n := 1
var _datos: Dictionary
var _tiempo := 120.0
var _oro := 0
var _atendidos := 0
var _siguiente_id := 1
var _pedidos := {}
var _carga := 0.0
var _reparando := 0.0
var _sogas := {"lavadora": [100.0, 100.0], "tendedero": [100.0, 100.0], "despacho": [100.0, 100.0]}
var _terminado := false


func _ready() -> void:
	EstadoJuego.asegurar_carga()
	_n = EstadoJuego.nivel_actual
	_datos = EstadoJuego.datos_nivel(_n)
	_tiempo = float(_datos.duracion)
	hud.iniciar_nivel(_n)
	for p: String in _sogas:      # las sogas pasan de un día a otro (las que compró en el taller)
		for i in 2:
			_sogas[p][i] = EstadoJuego.sogas[p][i]
			hud.poner_soga(p, i, _sogas[p][i])
	_nuevo_pedido()


func _process(delta: float) -> void:
	if _terminado or get_tree().paused:
		return
	_tiempo -= delta
	hud.set_tiempo(_tiempo)
	for id: int in _pedidos.keys():
		_pedidos[id] -= delta
		hud.actualizar_pedido(id, _pedidos[id])
		if _pedidos[id] <= 0.0:
			_pedidos.erase(id)
			hud.quitar_pedido(id, false)
			hud.mostrar_pago(0)
	if Input.is_key_pressed(KEY_SPACE):
		hud.mostrar_carga(true)
		_carga = minf(_carga + delta, HudHeyHo.CARGA_MAX)
		hud.set_carga(_carga)
	elif _carga > 0.0:
		_carga = 0.0
		hud.mostrar_carga(false)
	if Input.is_key_pressed(KEY_R):
		_reparando += delta
		hud.poner_reparacion("lavadora", clampf(_reparando / 2.0, 0.0, 1.0))
		if _reparando >= 2.0:
			_reparando = 0.0
			_poner_soga("lavadora", 0, 50.0)
			hud.poner_inestable("lavadora", false)
	elif _reparando > 0.0:
		_reparando = 0.0
		hud.poner_reparacion("lavadora", 0.0)
	if _tiempo <= 0.0:
		_terminar(false)


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	match k.keycode:
		KEY_1: hud.equipar("resortera")
		KEY_2: hud.equipar("piedra")
		KEY_3: hud.equipar("cana")
		KEY_G: _pagar()
		KEY_P: _nuevo_pedido()
		KEY_S: _poner_soga("tendedero", 1, maxf(0.0, _sogas["tendedero"][1] - 20.0))
		KEY_D:
			_poner_soga("lavadora", 0, 0.0)
			hud.poner_inestable("lavadora", true)
		KEY_L:
			hud.mostrar_aviso("¡Cuidado, un loro!", "peligro")
			hud.alerta_borde(3.0)
		KEY_ENTER: _terminar(false, true)
		KEY_X: _terminar(true)


func _poner_soga(p: String, i: int, v: float) -> void:
	_sogas[p][i] = v
	hud.poner_soga(p, i, v)


func _nuevo_pedido() -> void:
	var id := _siguiente_id
	_siguiente_id += 1
	_pedidos[id] = 40.0
	hud.agregar_pedido(id, "Barco %d" % id, 40.0, 2)


func _pagar() -> void:
	if _pedidos.is_empty():
		return
	var id: int = _pedidos.keys()[0]
	_pedidos.erase(id)
	hud.quitar_pedido(id, true)
	_oro += EstadoJuego.ORO_POR_CLIENTE
	_atendidos += 1
	hud.set_oro(_oro)
	hud.mostrar_pago(EstadoJuego.ORO_POR_CLIENTE)


func _terminar(perdido_por_sogas: bool, forzar_paso := false) -> void:
	if _terminado:
		return
	_terminado = true
	if forzar_paso:
		_oro = maxi(_oro, int(_datos.minimo))
	EstadoJuego.terminar_nivel(_n, _oro, _atendidos, int(_datos.clientes), perdido_por_sogas)
	for p: String in _sogas:      # lo que queda de las sogas viaja al taller
		EstadoJuego.sogas[p] = [_sogas[p][0], _sogas[p][1]]
	hud.mostrar_aviso("Fin del día", "info")
	await get_tree().create_timer(1.0).timeout
	Navegador.ir_a(self, Navegador.RESULTADO)
