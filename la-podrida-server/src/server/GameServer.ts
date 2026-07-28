import type { WebSocket, WebSocketServer } from 'ws';

import { GameRoom } from './GameRoom';

/**
 * Matchmaking en memoria, de un solo proceso. Alcanza perfectamente para
 * un proyecto gratuito/hobby: no hay costo de infraestructura extra,
 * pero ojo — si el servidor se reinicia, las partidas en curso se pierden
 * (no hay persistencia en disco/base de datos). Si en algún momento esto
 * se vuelve un problema, se puede sumar Redis u otra store, pero eso ya
 * implica más piezas (y potencialmente costo) para mantener.
 */
export class GameServer {
  private rooms: Map<string, GameRoom> = new Map();
  private waitingRoom: GameRoom | null = null;

  constructor(wss: WebSocketServer) {
    wss.on('connection', (ws: WebSocket) => this.handleConnection(ws));
  }

  private handleConnection(ws: WebSocket) {
    // El primer mensaje de la conexión decide si es un jugador nuevo
    // ('join') o alguien retomando su asiento tras un corte ('reconnect').
    ws.once('message', (raw: Buffer) => {
      let msg: { type: string; payload?: any };
      try {
        msg = JSON.parse(raw.toString());
      } catch {
        ws.close();
        return;
      }

      if (msg.type === 'join') {
        const room = this.getOrCreateWaitingRoom();
        room.handleJoin(ws, msg.payload?.name);
        return;
      }

      if (msg.type === 'reconnect') {
        const roomId = msg.payload?.roomId;
        const sessionId = msg.payload?.sessionId;
        const room = roomId ? this.rooms.get(roomId) : undefined;
        if (!room) {
          ws.send(JSON.stringify({ type: 'error', payload: { message: 'Sala no encontrada' } }));
          ws.close();
          return;
        }
        room.handleReconnect(ws, sessionId);
        return;
      }

      ws.close();
    });
  }

  private getOrCreateWaitingRoom(): GameRoom {
    if (this.waitingRoom && this.waitingRoom.hasSpace) {
      return this.waitingRoom;
    }
    const room = new GameRoom();
    this.rooms.set(room.id, room);
    this.waitingRoom = room;
    return room;
  }
}
