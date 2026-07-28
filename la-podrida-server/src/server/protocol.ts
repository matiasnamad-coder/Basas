// Protocolo simple: todo mensaje es JSON con forma { type, payload }.
//
// Cliente -> servidor:
//   'join'          { name }                          — entra a una sala (matchmaking automático)
//   'reconnect'     { sessionId, roomId }              — retoma su asiento tras un corte de conexión
//   'start-game'    —                                  — arranca la partida (>= 4 jugadores en la sala)
//   'bid'           { value }                           — canta bazas en su turno
//   'play-card'     { card: { suit, rank } }            — juega una carta en su turno
//   'advance-round' —                                   — pasa a la siguiente mano tras ver el resumen
//
// Servidor -> cliente:
//   'welcome'            { sessionId, roomId }          — confirma la conexión (guardar para reconectar)
//   'lobby'               { players, minPlayers, maxPlayers, canStart }
//   'dealer-draw'         { draw, dealerSeatId }         — quién reparte primero
//   'state'               PlayerView (ver engine/view.ts) — tu vista del juego
//   'round-ended'         { scores }
//   'game-ended'          { finalScores }
//   'player-reconnecting' { seatId, timeoutSeconds }
//   'player-reconnected'  { seatId }
//   'player-absent'       { seatId }
//   'error'               { message }

export interface WireMessage<T = unknown> {
  type: string;
  payload?: T;
}
