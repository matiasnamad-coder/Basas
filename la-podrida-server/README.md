# Las Basas — Servidor (WebSocket plano)

Servidor multijugador en tiempo real, sin dependencias pagas. Envuelve
el motor de reglas (`src/engine/`, ya testeado con 17 tests — ver
`la-podrida-engine`) en un manejo de sockets a mano (`src/server/`) que:

- Mantiene el **estado autoritativo** del juego únicamente en el servidor.
- Le manda a cada jugador solo **su propia vista** del estado — nunca las
  cartas de los demás (`src/engine/view.ts`).
- Valida cada canto y cada jugada con las funciones del motor
  (`placeBid`, `playCard`), así que un cliente modificado no puede hacer
  trampa: el servidor rechaza cualquier jugada inválida.

## Por qué WebSocket plano y no Colyseus

Empezamos armando esto con Colyseus, pero **no tiene cliente oficial
para Flutter/Dart** (los SDKs oficiales son para TypeScript, Unity,
Godot, Haxe, Defold, GameMaker, Cocos Creator — no hay Flutter, ni
siquiera uno no oficial mantenido). Como querés que la app sea gratis y
no atarte a un motor de juego específico, un WebSocket plano con
mensajes JSON es la opción más simple y sin costo: Flutter lo soporta
oficialmente muy bien con el paquete `web_socket_channel` (mantenido
por el equipo de Dart), y del lado del servidor solo hace falta la
librería `ws` (gratis, open source, la más usada de Node para esto).

⚠️ No tengo acceso a red en este entorno, así que no pude instalar `ws`
ni correr el servidor de verdad. Sí armé un stub de tipos local para
chequear que el código compila sin errores de sintaxis/tipos — pero
probalo vos localmente (`npm install && npm run dev`) antes de darlo
por bueno.

## Setup

```
npm install
npm run dev     # levanta el servidor en :2567 con recarga automática
```

## Protocolo (mensajes JSON, ver `src/server/protocol.ts`)

**Cliente → servidor**
| mensaje | payload | cuándo |
|---|---|---|
| `join` | `{ name }` | al conectarse por primera vez (matchmaking automático) |
| `reconnect` | `{ sessionId, roomId }` | para retomar el asiento tras un corte de conexión |
| `start-game` | — | arranca la partida (mínimo 4 jugadores en la sala) |
| `bid` | `{ value }` | cuando es tu turno de cantar |
| `play-card` | `{ card: { suit, rank } }` | cuando es tu turno de jugar |
| `advance-round` | — | después de ver el resumen de fin de mano |

**Servidor → cliente**
| mensaje | payload | cuándo |
|---|---|---|
| `welcome` | `{ sessionId, roomId }` | confirma la conexión — **guardalo en el dispositivo** para poder reconectar |
| `lobby` | jugadores en la sala | cada vez que alguien entra/sale antes de arrancar |
| `dealer-draw` | carta que le tocó a cada uno + quién reparte | al arrancar la partida |
| `state` | tu vista del `GameState` (`PlayerView`) | cada vez que el estado cambia |
| `round-ended` | resumen de bazas/cantos de la mano que terminó | al resolverse la última baza |
| `game-ended` | tabla final ordenada por puntaje | al terminar el calendario completo |
| `player-reconnecting` | `{ seatId, timeoutSeconds }` | un jugador se cortó sin avisar |
| `player-reconnected` | `{ seatId }` | volvió a tiempo |
| `player-absent` | `{ seatId }` | no volvió dentro de 60s, o se fue a propósito |
| `error` | `{ message }` | tu canto/jugada fue inválida, o la sesión/sala no existe |

## Cómo reconectar (importante para el cliente)

1. Al conectar por primera vez, mandás `join` y el servidor responde
   `welcome` con `{ sessionId, roomId }`. Guardalos en el dispositivo
   (ej. `shared_preferences` en Flutter).
2. Si la conexión se corta (se cierra el socket sin que vos lo hayas
   pedido), abrí un socket nuevo y mandá `reconnect` con esos mismos
   `sessionId` y `roomId` — el servidor te devuelve directamente tu
   estado actual.
3. Si pasaron más de 60 segundos, el servidor ya te marcó ausente
   (`player-absent`) y siguió jugando en tu nombre (0 bazas cantadas, o
   la primera carta válida jugada). Igual podés reconectar después con
   el mismo `sessionId` y vas a seguir viendo el estado actual de la
   partida.

## Reglas de arranque y ausencias (todas confirmadas e implementadas)

- **Quién reparte primero**: se le tira una carta al azar a cada
  jugador; el que saca la más alta reparte, con re-sorteo entre
  empatados si hace falta (`determineInitialDealer` en el motor). Se
  manda como `dealer-draw` antes del primer `state`.
- **Desconexión sin aviso**: 60 segundos de espera (`player-reconnecting`
  → reconecta o no) antes de marcar ausente. La notificación "por otra
  vía" (push notification al celular) es responsabilidad de la app
  cliente — el servidor solo expone el evento para dispararla desde ahí.
- **Turno de un jugador ausente**: en fase de canto se le canta 0
  automático; en fase de jugar se le juega la primera carta válida de
  su mano. Se encadena si hay más de un ausente seguido.
- **Emparejamiento**: automático (`GameServer` asigna a cualquier sala
  con lugar, o crea una nueva) — no hay salas con código para invitar
  amigos específicos por ahora.

## Cómo probarlo sin la app todavía

Con el paquete `ws` (el mismo que usa el servidor) se puede simular una
partida completa desde la terminal, sin Flutter:

```js
// prueba-manual.js — correr con: node prueba-manual.js
// (hace falta: npm install ws)
import WebSocket from 'ws';

function connect(name) {
  const ws = new WebSocket('ws://localhost:2567');
  ws.on('open', () => ws.send(JSON.stringify({ type: 'join', payload: { name } })));
  ws.on('message', (raw) => {
    const msg = JSON.parse(raw.toString());
    console.log(name, msg.type, msg.payload);
  });
  return ws;
}

const sockets = ['Ana', 'Beto', 'Cami', 'Dana'].map(connect);
setTimeout(() => sockets[0].send(JSON.stringify({ type: 'start-game' })), 1000);
```

## Hosting gratuito

Al ser WebSocket plano sobre Node (sin nada propietario), corre en
cualquier hosting con soporte de Node.js. Para no gastar nada:

- **Render.com** (plan Free de "Web Service") o **Fly.io** (allowance
  gratuito) son las opciones más simples para probar esto en internet
  sin pagar. Ambos "duermen" el servidor tras un rato sin uso en el
  plan gratuito — la primera conexión después de dormido tarda unos
  segundos más en responder, pero para probar con amigos alcanza de
  sobra.
- Si en algún momento la app crece y eso molesta, ahí sí conviene
  evaluar un plan pago o un VPS barato — pero no hace falta pensarlo
  todavía.

## Limitaciones a tener en cuenta (por ser todo gratis/simple)

- **Todo en memoria, un solo proceso**: si el servidor se reinicia, las
  partidas en curso se pierden. Para un juego casual con amigos esto es
  aceptable; si más adelante querés persistencia real, hay que sumar
  una base de datos (eso ya sería una pieza más para mantener).
- **Sin balanceo de carga**: un solo proceso Node atiende todas las
  salas. Para la escala de "jugar con amigos" esto sobra.

## Pendiente / siguientes pasos

- **Quién es "el host"**: cualquiera en la sala puede mandar
  `start-game` o `advance-round` hoy. Si querés restringirlo a quien
  entró primero, es un chequeo chico de agregar.
- **Salas con código**: si más adelante querés armar partidas con
  amigos específicos en vez de emparejamiento automático, se agrega
  bastante fácil (un campo `roomCode` opcional en el mensaje `join`).
