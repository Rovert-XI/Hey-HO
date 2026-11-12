class_name TarjetaNivel
extends PanelContainer
## Una "perla" del collar de niveles: número, datos del día y botón para jugar.

signal elegido(nivel: int)

@onready var perla: Panel = %Perla
@onready var numero: Label = %Numero
@onready var nombre: Label = %NombreDia
@onready var clientes: Label = %Clientes
@onready var minimo: Label = %Minimo
@onready var mejor: Label = %Mejor
@onready var boton: Button = %Boton

var nivel := 1


func _ready() -> void:
	boton.pressed.connect(func() -> void: elegido.emit(nivel))


func disponible() -> bool:
	return nivel <= EstadoJuego.NIVELES_JUGABLES and nivel <= EstadoJuego.nivel_max_desbloqueado


func configurar(n: int) -> void:
	nivel = n
	var d := EstadoJuego.datos_nivel(n)
	numero.text = str(n)
	nombre.text = "Día %d" % n
	clientes.text = "%d clientes · %s" % [d.clientes, EstadoJuego.formato_tiempo(d.duracion)]
	minimo.text = "Mínimo %d oro" % d.minimo
	var mejor_oro: int = EstadoJuego.mejor_oro[n - 1]
	var superado := mejor_oro >= int(d.minimo)
	mejor.text = "Mejor: %d oro" % mejor_oro if superado else "Sin superar"
	mejor.theme_type_variation = &"LabelExito" if superado else &"LabelPeque"

	var color_perla := UITema.CREMA
	if superado:
		color_perla = UITema.VERDE
	if n > EstadoJuego.NIVELES_JUGABLES:
		boton.text = "PRÓXIMAMENTE"
		boton.disabled = true
		color_perla = UITema.NOCHE
	elif n > EstadoJuego.nivel_max_desbloqueado:
		boton.text = "BLOQUEADO"
		boton.disabled = true
		color_perla = UITema.NOCHE
	else:
		boton.text = "JUGAR"
		boton.disabled = false
	# Bloqueado = botón normal (apagado); disponible = botón primario (naranja).
	boton.theme_type_variation = &"BotonPrimario" if not boton.disabled else &""
	perla.add_theme_stylebox_override("panel", UITema.caja(color_perla, UITema.CELESTE.lerp(UITema.NOCHE, 0.45), 3, 30, 0, 0))
	numero.add_theme_color_override("font_color", UITema.NOCHE if color_perla != UITema.NOCHE else UITema.CELESTE)
	modulate = Color(1, 1, 1, 1) if boton.disabled == false else Color(1, 1, 1, 0.85)
