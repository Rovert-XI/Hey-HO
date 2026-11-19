class_name BarraPaciencia
extends PanelContainer
## Barra de paciencia de un barco cliente (Documento de concepto, sección 9):
## pasa de VERDE a ROJO y en los últimos 10 s parpadea en rojo.

signal agotada

const UMBRAL_PARPADEO := 10.0

@onready var nombre: Label = %Nombre
@onready var prendas: HBoxContainer = %Prendas
@onready var barra: ProgressBar = %Barra

var maximo := 40.0
var _relleno := UITema.caja(UITema.VERDE, Color(0, 0, 0, 0), 0, 6, 0, 0)
var _agotada := false


func _ready() -> void:
	barra.add_theme_stylebox_override("fill", _relleno)


## titulo: "Barco 1" · paciencia_max: segundos (40 en el concepto) · sucias: prendas por lavar.
func configurar(titulo: String, paciencia_max: float, sucias := 2, limpias := 0) -> void:
	nombre.text = titulo
	maximo = paciencia_max
	poner_prendas(sucias, limpias)
	actualizar(paciencia_max)


## Sucias en MADERA (manchadas de marrón), limpias en CREMA.
func poner_prendas(sucias: int, limpias: int) -> void:
	for hijo in prendas.get_children():
		hijo.queue_free()
	for i in sucias + limpias:
		var p := Panel.new()
		p.custom_minimum_size = Vector2(16, 16)
		var color := UITema.MADERA if i < sucias else UITema.CREMA
		p.add_theme_stylebox_override("panel", UITema.caja(color, UITema.NOCHE, 2, 4, 0, 0))
		prendas.add_child(p)


## Llamar cada frame con los segundos que le quedan al cliente.
func actualizar(restante: float) -> void:
	var fraccion := clampf(restante / maximo, 0.0, 1.0)
	barra.value = fraccion
	var color := UITema.VERDE.lerp(UITema.ROJO, clampf((0.5 - fraccion) * 2.0, 0.0, 1.0))
	if restante <= UMBRAL_PARPADEO and restante > 0.0:
		var encendido := int(Time.get_ticks_msec() / 250.0) % 2 == 0
		color = UITema.ROJO if encendido else UITema.NOCHE
	_relleno.bg_color = color
	if restante <= 0.0 and not _agotada:
		_agotada = true
		agotada.emit()


## Cierra el pedido con una animación corta: verde si se entregó, rojo si el barco se fue.
func cerrar(entregado: bool) -> void:
	_relleno.bg_color = UITema.VERDE if entregado else UITema.ROJO
	barra.value = 1.0 if entregado else 0.0
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.5).set_delay(0.3)
	t.tween_callback(queue_free)
