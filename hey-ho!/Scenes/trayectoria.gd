# 'extends' indica que el script hereda de 'Node' (nodo lógico base sin transformada 3D propia).
extends Node
# 'class_name' registra esta clase globalmente para poder referenciarla por su nombre en otros scripts.
class_name TrayectoriaResorte

# '@export' expone estas variables en el Inspector para ajustar el aspecto de la curva sin tocar código.
@export var cantidad_puntos: int = 45
@export var paso_tiempo: float = 0.05
@export var radio_punto: float = 0.07
@export var radio_marcador_caida: float = 0.18
@export var color_puntos: Color = Color(1.0, 1.0, 1.0, 0.95)
@export var color_marcador_caida: Color = Color(0.35, 0.95, 0.65, 1.0)

# Variables privadas ('_' inicial) que almacenan las esferas visuales y su nodo contenedor en el mundo 3D.
var _contenedor_visual: Node3D = null
# 'Array[MeshInstance3D]' declara un arreglo tipado que solo acepta nodos de malla 3D.
var _puntos: Array[MeshInstance3D] = []
var _marcador_caida: MeshInstance3D = null


# Callback que ejecuta Godot una sola vez cuando el nodo entra en el árbol de escena.
# '-> void' indica que la función no devuelve ningún valor.
func _ready() -> void:
	# Crea un nodo 3D independiente ('top_level = true') para ubicar los puntos en coordenadas globales puras
	# sin que hereden la rotación o escala del personaje cuando gira.
	_contenedor_visual = Node3D.new()
	_contenedor_visual.top_level = true
	add_child(_contenedor_visual)
	_contenedor_visual.global_position = Vector3.ZERO
	_contenedor_visual.global_rotation = Vector3.ZERO

	_crear_puntos_visuales()
	ocultar_trayectoria()


# Construye en memoria las esferas blancas de la parábola y el disco verde donde caerá la prenda.
# No recibe parámetros y no devuelve valor (void).
func _crear_puntos_visuales() -> void:
	# 'SphereMesh' crea una geometría esférica procedural compartida por todos los puntos para ahorrar memoria.
	var malla_punto := SphereMesh.new()
	malla_punto.radius = radio_punto
	malla_punto.height = radio_punto * 2.0

	# 'SHADING_MODE_UNSHADED' hace que los puntos brillen con su color puro sin verse oscuros por sombras.
	var mat_punto := StandardMaterial3D.new()
	mat_punto.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_punto.albedo_color = color_puntos

	# 'for i in range(...)' repite la creación de cada punto desde 0 hasta 'cantidad_puntos - 1'.
	for i in range(cantidad_puntos):
		var punto := MeshInstance3D.new()
		punto.mesh = malla_punto
		punto.material_override = mat_punto
		punto.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_contenedor_visual.add_child(punto)
		_puntos.append(punto)

	# Crea el marcador plano al final de la trayectoria para señalar el punto exacto de aterrizaje.
	var malla_caida := SphereMesh.new()
	malla_caida.radius = radio_marcador_caida
	malla_caida.height = radio_marcador_caida * 0.5

	var mat_caida := StandardMaterial3D.new()
	mat_caida.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_caida.albedo_color = color_marcador_caida

	_marcador_caida = MeshInstance3D.new()
	_marcador_caida.mesh = malla_caida
	_marcador_caida.material_override = mat_caida
	_marcador_caida.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_contenedor_visual.add_child(_marcador_caida)


# Simula el tiro parabólico paso a paso usando la gravedad real del proyecto y detecta dónde chocará.
# Recibe: 'origen' (Vector3 inicial en PuntoMano) y 'velocidad_inicial' (Vector3 del lanzamiento). Devuelve: void.
func mostrar_trayectoria(origen: Vector3, velocidad_inicial: Vector3) -> void:
	if velocidad_inicial.length_squared() < 0.01:
		ocultar_trayectoria()
		return

	# Lee la gravedad configurada en Project Settings (por defecto 9.8 m/s²) para coincidir con RigidBody3D.
	var gravedad: float = ProjectSettings.get_setting("physics/3d/default_gravity") as float
	var vector_gravedad := Vector3(0.0, -gravedad, 0.0)
	# Obtiene el espacio físico 3D actual para poder lanzar rayos de colisión (raycasts).
	var espacio_fisico: PhysicsDirectSpaceState3D = _contenedor_visual.get_world_3d().direct_space_state
	var exclusiones: Array[RID] = _obtener_rids_excluidos()

	var punto_anterior: Vector3 = origen
	var impacto_encontrado: bool = false

	for i in range(_puntos.size()):
		# Calcula el instante de tiempo 't' y aplica la ecuación cinemática: pos = p0 + v0*t + 0.5*g*t².
		var t: float = float(i + 1) * paso_tiempo
		var posicion_actual: Vector3 = origen + velocidad_inicial * t + 0.5 * vector_gravedad * t * t

		# Traza un segmento de rayo entre el punto anterior y el actual para detectar si atraviesa una superficie.
		var query := PhysicsRayQueryParameters3D.create(punto_anterior, posicion_actual)
		query.exclude = exclusiones
		# Ignora sensores invisibles (Area3D como CanastoClientes) y detecta solo cuerpos físicos sólidos.
		query.collide_with_areas = false
		query.collide_with_bodies = true

		# 'intersect_ray' devuelve un Dictionary con 'position', 'normal' y 'collider' si hubo impacto (o vacío si no).
		var resultado: Dictionary = espacio_fisico.intersect_ray(query)
		if not resultado.is_empty():
			_puntos[i].visible = false
			if _marcador_caida != null:
				_marcador_caida.global_position = resultado.position + Vector3.UP * 0.04
				_marcador_caida.visible = true
			impacto_encontrado = true

			# Oculta los puntos restantes de la curva que quedarían por debajo del suelo.
			for j in range(i + 1, _puntos.size()):
				_puntos[j].visible = false
			# 'break' interrumpe el bucle principal porque la trayectoria ya encontró su punto de caída.
			break

		_puntos[i].global_position = posicion_actual
		_puntos[i].visible = true
		punto_anterior = posicion_actual

	if not impacto_encontrado and _marcador_caida != null:
		_marcador_caida.visible = false


# Esconde todas las esferas blancas y el marcador verde cuando el jugador suelta o cancela el apuntado.
# No recibe parámetros y no devuelve valor (void).
func ocultar_trayectoria() -> void:
	for punto in _puntos:
		punto.visible = false
	if _marcador_caida != null:
		_marcador_caida.visible = false


# Recopila los identificadores físicos ('RID') del jugador y de prendas en vuelo para que el raycast los ignore.
# No recibe parámetros. Devuelve: 'Array[RID]' (lista de identificadores de colisión a excluir).
func _obtener_rids_excluidos() -> Array[RID]:
	var rids: Array[RID] = []
	for nodo in get_tree().get_nodes_in_group("prendas_proyectil"):
		if nodo is CollisionObject3D:
			rids.append((nodo as CollisionObject3D).get_rid())

	# Sube por la jerarquía de nodos padres hasta el CharacterBody3D del jugador para excluir su cápsula de colisión.
	var padre: Node = get_parent()
	while padre != null:
		if padre is CollisionObject3D:
			rids.append((padre as CollisionObject3D).get_rid())
		padre = padre.get_parent()
	return rids
