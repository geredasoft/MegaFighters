# Organización de scripts

Los scripts ligados a escenas conservan sus rutas actuales para no romper referencias de escenas y recursos. Las responsabilidades reutilizables se extraen a `components/`, `factories/` y `strategies/`.

## Responsabilidades

- `player.gd` conserva el contrato público del actor, las referencias de escena y la coordinación del estado. `components/player_input_controller.gd` interpreta entradas y bloqueo; `components/player_portal_controller.gd` aplica el traslado del portal; `components/player_ladder_controller.gd` administra la escalada; `components/player_movement_controller.gd` implementa movimiento normal y roll; `components/player_combat_controller.gd` implementa ataque y daño; `components/player_lifecycle_controller.gd` coordina muerte y reinicio.
- `enemy.gd` conserva el contrato público del actor, las referencias de escena y la coordinación del estado. `components/enemy_state_decision_controller.gd` evalúa transiciones tácticas; `components/enemy_navigation_controller.gd` ejecuta patrulla, persecución y posicionamiento; `components/enemy_attack_controller.gd` administra anticipación, ataque, recuperación y cancelación; `components/enemy_lifecycle_controller.gd` coordina muerte y reinicio; `components/enemy_portal_controller.gd` aplica el traslado y reinicia maniobras; `components/enemy_world_sensor.gd` adquiere al jugador y consulta visión/terreno; `components/enemy_separation_controller.gd` calcula el espacio entre enemigos; los controladores de plataforma deciden y ejecutan sus maniobras; `components/enemy_combat_controller.gd` administra hitbox, ventana y daño.
- `components/sprite_animation_controller.gd` valida y reproduce animaciones, incluida la locomoción común; los actores eligen los parámetros a partir de su estado.
- `components/attack_hitbox_controller.gd` activa y desactiva la detección física del hitbox; los controladores de combate de cada personaje mantienen sus ventanas y reglas particulares.
- `components/character_physics_controller.gd` comparte gravedad, damping y aplicación del impulso de knockback; cada actor conserva sus parámetros y decide cuándo aplicarlos.
- `components/combat_hit_processor.gd` valida hurtboxes, evita golpear dos veces al mismo objetivo durante un ataque y aplica daño/empuje; cada actor conserva sus grupos y parámetros de combate.
- `danable.gd` concentra la vida, publica señales y define el contrato común de reinicio, gravedad, damping, portal y empuje.
- `hub.gd` coordina la UI de vida. `iu/enemy_health_bar.gd` construye y actualiza la fila visual de cada enemigo.
- `juego.gd` mantiene las conexiones de la escena; `components/game_flow_controller.gd` dirige victoria, derrota y reinicio, y `iu/level_message_view.gd` presenta los mensajes.
- `enemy_spawner.gd` y `SpawnArmas.gd` gestionan el ciclo de aparición. Las fábricas crean instancias y la estrategia selecciona puntos.

## Patrones aplicados

- **Máquina de estados:** `player.gd` y `enemy.gd` dirigen el comportamiento según su estado actual.
- **Observer:** las señales de vida y de `EnemySpawner` notifican a UI y flujo de nivel sin acoplarlos a sus emisores.
- **Factory:** `factories/enemy_factory.gd` y `factories/weapon_factory.gd` crean instancias y validan el tipo de nodo raíz.
- **Strategy:** `strategies/spawn_point_strategy.gd` define la política de selección y `random_spawn_point_strategy.gd` implementa la selección aleatoria sin repetición.
- **Composición:** los controladores de entrada, movimiento, combate, percepción, navegación, animación y UI mantienen sus responsabilidades separadas del controlador del personaje.

Las escenas nuevas mantienen conexiones y parámetros configurables en los scripts consumidores. Para añadir otra política de selección, se puede implementar el método `seleccionar(puntos, cantidad)` y asignar ese recurso en `estrategia_puntos`.
