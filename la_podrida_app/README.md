# Las Basas — App Flutter

Cliente móvil (Android/iOS) para Las Basas. Se conecta al servidor por
WebSocket plano (ver `la-podrida-server`), sin dependencias pagas.

⚠️ Este código lo escribí sin acceso a Flutter SDK ni a internet en mi
entorno, así que no pude correr `flutter pub get`, `flutter analyze` ni
compilarlo. Lo revisé a mano, pero puede haber algún error chico de
sintaxis o de nombres de API que solo aparezca al compilarlo de verdad.
Corré esto localmente y contame qué error tira si lo hay — se arregla
rápido.

## Setup

```
flutter pub get
flutter run
```

Al abrir la app te pide la URL del servidor (`ws://localhost:2567` para
probar en el emulador contra un servidor corriendo en tu máquina — en
Android emulator usá `ws://10.0.2.2:2567` en vez de `localhost`) y tu
nombre. Después entrás a la sala de espera hasta que haya 4+ jugadores
y alguien apriete "Arrancar partida".

## Estructura

- `lib/models/card.dart` — carta (palo, rango, símbolo, color)
- `lib/models/game_view.dart` — la vista del juego que manda el servidor
  (`PlayerView`, `PlayerInfo`, `TrickPlay`, `RoundInfo`)
- `lib/services/game_client.dart` — el `ChangeNotifier` que maneja la
  conexión WebSocket, el protocolo de mensajes, y la reconexión
  automática (guarda `sessionId`/`roomId` con `shared_preferences`)
- `lib/screens/connect_screen.dart` — pantalla inicial (servidor + nombre)
- `lib/screens/lobby_screen.dart` — sala de espera
- `lib/screens/game_screen.dart` — la mesa de juego (cantos, cartas,
  bazas, diálogos de fin de mano/partida)
- `lib/widgets/playing_card_widget.dart` — el visual de una carta

## Cómo funciona la validación

El cliente **no valida nada de las reglas del juego** — solo manda la
intención (`bid`, `play-card`) y muestra el `error` que responde el
servidor si no era válida (por ejemplo, jugar un palo que no correspondía,
o cantar un número prohibido). Esto es a propósito: el servidor es la
única fuente de verdad, así que no hay que duplicar la lógica de reglas
en dos lugares que se puedan desincronizar.

## Reconexión

Si se corta la conexión a mitad de partida, la app reintenta sola cada
2-5 segundos usando el `sessionId`/`roomId` guardado. Si volvés a abrir
la app después de haberla cerrado del todo, `tryResumeSavedSession()` en
`ConnectScreen` intenta retomar la sesión guardada antes de pedirte el
nombre de nuevo.

Recordá: el servidor da 60 segundos antes de marcarte "ausente" (te
sigue jugando 0 bazas / la primera carta válida en tu nombre). Podés
reconectar después de eso igual y vas a ver el estado actual, pero ya
habrás perdido lo que te tocó jugar mientras estabas afuera.

## Pendiente / lo que falta para una versión pulida

- **Notificación push cuando te desconectás**: hoy la app solo reintenta
  la conexión sola; si cerraste la app del todo, no hay ninguna
  notificación que te avise "te toca reconectar" (eso es lo que el
  servidor llama "notificar por otra vía"). Hay que integrar algo como
  Firebase Cloud Messaging para eso — es un paso aparte porque implica
  sumar un proyecto de Firebase (gratis en su capa básica, pero hay que
  configurarlo).
- **Animaciones y pulido visual**: la versión actual es funcional pero
  bien simple (sin animar el movimiento de cartas, sin sonido, etc.) —
  a propósito, para tener primero algo que funcione de punta a punta.
- **Salas con código**: si en algún momento el servidor suma esto, hay
  que agregar un campo para ingresarlo en `ConnectScreen`.
- **Quién puede arrancar la partida / pasar de mano**: hoy cualquiera en
  la sala ve el botón habilitado — si el servidor restringe esto a un
  "host" más adelante, hay que reflejarlo acá (deshabilitar el botón
  para quien no sea el host).
