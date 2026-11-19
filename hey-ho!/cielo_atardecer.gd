class_name CieloAtardecer
extends CanvasLayer
## Cielo de atardecer en 2D DETRÁS del mundo 3D, con el sol visible en el fondo.
##
## Por qué hace falta: con una cámara ortogonal el Sky de Godot sale de un solo color (todos los rayos van
## en la misma dirección), así que no se vería ni el degradado ni el sol. Aquí el cielo es una capa 2D y
## el Environment se pone en modo "Canvas" para dibujarla detrás de todo lo 3D.
##
## El sol sigue a SistemaSol: a mayor elevación horaria (14 h = 120°, 16,67 h = 160°) está más cerca del
## horizonte. El horizonte lo marca el borde lejano del plano de agua (ver `horizonte`).

## Altura del horizonte medida desde arriba (0 = borde superior, 1 = inferior).
## Debe coincidir con el borde lejano del plano de agua en pantalla (con cámara 30°, Size 9 y agua
## que termina en z = -6, vale ≈ 0.25).
@export_range(0.05, 0.6) var horizonte := 0.25
## WorldEnvironment del nivel (el mismo que usa SistemaSol): se pone en modo Canvas automáticamente.
@export var entorno: WorldEnvironment
@export var horas_por_nivel: Array[float] = [14.0, 14.6667, 15.3333, 16.0, 16.6667]
## Lado de la pantalla donde está el sol (0 = izquierda, 1 = derecha).
@export_range(0.0, 1.0) var posicion_x := 0.72

const NOCHE := Color("#0D1B2A")
const AZUL := Color("#10288C")
const NARANJA_CALIDO := Color(1.0, 0.55, 0.3)

var _raiz: Control
var _cielo: TextureRect
var _gradiente := Gradient.new()
var _halo: Panel
var _sol: Panel
var _velo: ColorRect
var _estilo_halo := StyleBoxFlat.new()
var _estilo_sol := StyleBoxFlat.new()
var _hora := 14.0
var _oscuridad := 0.0
var _construido := false


func _ready() -> void:
	layer = -10
	_construir()
	if entorno:
		configurar_entorno(entorno.environment)
	get_viewport().size_changed.connect(func() -> void: poner_hora(_hora, 1.0 - _oscuridad))
	poner_hora(_hora)


## Pone el Environment en modo Canvas para que esta capa se dibuje detrás del 3D.
func configurar_entorno(env: Environment) -> void:
	env.background_mode = Environment.BG_CANVAS
	env.background_canvas_max_layer = layer


## Usa la misma hora que SistemaSol. `apagado` (1 = normal, 0 = derrota) oscurece el cielo.
func poner_hora(hora: float, apagado := 1.0) -> void:
	_construir()        # SistemaSol puede llamar antes de que este nodo haga su _ready()
	_hora = hora
	_oscuridad = 1.0 - apagado
	var tam := get_viewport().get_visible_rect().size
	var elevacion := CicloDia.elevacion(hora)
	var altura := clampf(minf(elevacion, 180.0 - elevacion), 0.0, 90.0)   # grados sobre el horizonte
	var lado := 1.0 if elevacion >= 90.0 else -1.0                          # tarde: a la derecha
	var y_horizonte := tam.y * horizonte
	var radio := tam.y * 0.07
	var cy := y_horizonte - (altura / 90.0) * (y_horizonte * 0.85)
	var cx := tam.x * (0.5 + (posicion_x - 0.5) * lado)

	var calido := CicloDia.color_sol(hora).lerp(NARANJA_CALIDO, 0.4)
	_gradiente.colors = PackedColorArray([NOCHE, AZUL, calido.lerp(NARANJA_CALIDO, 0.5)])
	_gradiente.offsets = PackedFloat32Array([0.0, horizonte * 0.55, horizonte])
	_estilo_sol.bg_color = calido
	_estilo_halo.bg_color = Color(calido, 0.22)
	_sol.position = Vector2(cx - radio, cy - radio)
	_sol.size = Vector2.ONE * radio * 2.0
	_estilo_sol.set_corner_radius_all(int(radio))
	var r_halo := radio * 2.6
	_halo.position = Vector2(cx - r_halo, cy - r_halo)
	_halo.size = Vector2.ONE * r_halo * 2.0
	_estilo_halo.set_corner_radius_all(int(r_halo))
	_velo.color = Color(NOCHE, _oscuridad * 0.7)


func _construir() -> void:
	if _construido:
		return
	_construido = true
	_raiz = Control.new()
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_raiz)
	var textura := GradientTexture2D.new()
	textura.gradient = _gradiente
	textura.fill_from = Vector2(0, 0)
	textura.fill_to = Vector2(0, 1)
	textura.width = 8
	textura.height = 256
	_cielo = TextureRect.new()
	_cielo.texture = textura
	_cielo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cielo.stretch_mode = TextureRect.STRETCH_SCALE
	_cielo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cielo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(_cielo)
	_halo = _circulo(_estilo_halo)
	_sol = _circulo(_estilo_sol)
	_velo = ColorRect.new()
	_velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(_velo)


func _circulo(estilo: StyleBoxFlat) -> Panel:
	var p := Panel.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	estilo.anti_aliasing = true
	p.add_theme_stylebox_override("panel", estilo)
	_raiz.add_child(p)
	return p
