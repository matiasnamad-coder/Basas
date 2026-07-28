import { randomUUID } from 'crypto';
import type { WebSocket } from 'ws';

import { placeBid } from '../engine/bidding';
import { advanceRound, createGameWithDealerReveal, MIN_PLAYERS } from '../engine/game';
import { playCard, validatePlay } from '../engine/trick';
import { GameState } from '../engine/types';
import { buildPlayerView } from '../engine/view';

export const MAX_PLAYERS = 8;
const RECONNECT_TIMEOUT_SECONDS = 60;
// readyState === 1 significa OPEN según el estándar de WebSocket.
const WS_OPEN = 1;

type SeatStatus = 'connected' | 'reconnecting' | 'absent';

interface LobbyEntry {
  sessionId: string;
  name: string;
}

/**
 * Una sala = una partida de Las Basas. El estado autoritativo del juego
 * (GameState del motor) vive únicamente en el servidor. A cada jugador le
 * llega solo su propia "vista" (buildPlayerView) — nunca las manos ajenas.
 *
 * A diferencia de la versión con Colyseus, acá el manejo de sockets,
 * reconexión y matchmaking está hecho a mano (ver GameServer.ts) porque
 * Colyseus no tiene cliente oficial para Flutter/Dart.
 */
export class GameRoom {
  readonly id: string;

  private lobby: LobbyEntry[] = [];
  private seatOrder: string[] = []; // sessionIds, fijo una vez arranca la partida
  private sockets: Map<string, WebSocket> = new Map();
  private seatStatus: Map<string, SeatStatus> = new Map();
  private reconnectTimers: Map<string, ReturnType<typeof setTimeout>> = new Map();
  private gameState: GameState | null = null;

  constructor(id: string = randomUUID()) {
    this.id = id;
  }

  get isInLobby(): boolean {
    return this.gameState === null;
  }

  get hasSpace(): boolean {
    return this.isInLobby && this.lobby.length < MAX_PLAYERS;
  }

  // ---------- Entrada de jugadores ----------

  handleJoin(ws: WebSocket, name: string | undefined): string {
    if (!this.isInLobby) {
      this.send(ws, 'error', { message: 'La partida ya empezó' });
      ws.close();
      return '';
    }

    const sessionId = randomUUID();
    const safeName = (name ?? `Jugador ${this.lobby.length + 1}`).slice(0, 24);

    this.lobby.push({ sessionId, name: safeName });
    this.seatOrder.push(sessionId);
    this.sockets.set(sessionId, ws);
    this.seatStatus.set(sessionId, 'connected');
    this.bindSocket(sessionId, ws);

    this.send(ws, 'welcome', { sessionId, roomId: this.id });
    this.broadcastLobby();
    return sessionId;
  }

  handleReconnect(ws: WebSocket, sessionId: string) {
    if (!this.seatOrder.includes(sessionId)) {
      this.send(ws, 'error', { message: 'Esa sesión no pertenece a esta sala' });
      ws.close();
      return;
    }

    const timer = this.reconnectTimers.get(sessionId);
    if (timer) {
      clearTimeout(timer);
      this.reconnectTimers.delete(sessionId);
    }

    this.sockets.set(sessionId, ws);
    this.seatStatus.set(sessionId, 'connected');
    this.bindSocket(sessionId, ws);

    this.send(ws, 'welcome', { sessionId, roomId: this.id });
    this.broadcast('player-reconnected', { seatId: sessionId });
    this.sendStateTo(sessionId);
  }

  private bindSocket(sessionId: string, ws: WebSocket) {
    ws.removeAllListeners('message');
    ws.removeAllListeners('close');

    ws.on('message', (raw: Buffer) => this.handleMessage(sessionId, raw));
    ws.on('close', () => this.handleClose(sessionId, ws));
  }

  private handleClose(sessionId: string, ws: WebSocket) {
    // Si ya hay un socket más nuevo para este asiento (reconexión rápida),
    // este cierre es del socket viejo — lo ignoramos.
    if (this.sockets.get(sessionId) !== ws) return;

    if (this.isInLobby) {
      this.lobby = this.lobby.filter((p) => p.sessionId !== sessionId);
      this.seatOrder = this.seatOrder.filter((id) => id !== sessionId);
      this.sockets.delete(sessionId);
      this.seatStatus.delete(sessionId);
      this.broadcastLobby();
      return;
    }

    // Partida en curso: damos un tiempo de espera antes de dar por
    // ausente al jugador (se cortó sin avisar).
    this.seatStatus.set(sessionId, 'reconnecting');
    this.broadcast('player-reconnecting', {
      seatId: sessionId,
      timeoutSeconds: RECONNECT_TIMEOUT_SECONDS,
    });

    const timer = setTimeout(() => {
      this.reconnectTimers.delete(sessionId);
      if (this.seatStatus.get(sessionId) === 'reconnecting') {
        this.markAbsent(sessionId);
      }
    }, RECONNECT_TIMEOUT_SECONDS * 1000);
    this.reconnectTimers.set(sessionId, timer);
  }

  private markAbsent(sessionId: string) {
    this.seatStatus.set(sessionId, 'absent');
    this.broadcast('player-absent', { seatId: sessionId });
    this.tryAutoResolveCurrentTurn();
  }

  // ---------- Mensajes del cliente ----------

  private handleMessage(sessionId: string, raw: Buffer) {
    let msg: { type: string; payload?: any };
    try {
      msg = JSON.parse(raw.toString());
    } catch {
      return;
    }

    switch (msg.type) {
      case 'start-game':
        this.handleStartGame(sessionId);
        break;
      case 'bid':
        this.handleBid(sessionId, msg.payload);
        break;
      case 'play-card':
        this.handlePlayCard(sessionId, msg.payload);
        break;
      case 'advance-round':
        this.handleAdvanceRound(sessionId);
        break;
    }
  }

  private handleStartGame(sessionId: string) {
    if (!this.isInLobby) return;
    const ws = this.sockets.get(sessionId);

    if (this.lobby.length < MIN_PLAYERS) {
      if (ws) this.send(ws, 'error', { message: `Hacen falta al menos ${MIN_PLAYERS} jugadores` });
      return;
    }
    if (this.lobby.length > MAX_PLAYERS) {
      if (ws) this.send(ws, 'error', { message: `Como mucho ${MAX_PLAYERS} jugadores` });
      return;
    }

    const names = this.seatOrder.map((id) => this.lobby.find((p) => p.sessionId === id)!.name);

    let result;
    try {
      result = createGameWithDealerReveal(names);
    } catch (err) {
      if (ws) this.send(ws, 'error', { message: (err as Error).message });
      return;
    }

    this.gameState = result.state;

    this.broadcast('dealer-draw', {
      draw: result.dealerDraw.map((d) => ({
        seatId: this.seatOrder[d.playerIndex],
        name: names[d.playerIndex],
        card: d.card,
      })),
      dealerSeatId: this.seatOrder[this.gameState.dealerIndex],
    });

    this.broadcastGameState();
  }

  private playerIdFor(sessionId: string): string | null {
    const seatIndex = this.seatOrder.indexOf(sessionId);
    return seatIndex === -1 ? null : `p${seatIndex}`;
  }

  private handleBid(sessionId: string, payload: { value: number }) {
    if (!this.gameState) return;
    const playerId = this.playerIdFor(sessionId);
    if (!playerId) return;

    try {
      this.gameState = placeBid(this.gameState, playerId, payload?.value);
    } catch (err) {
      this.sendErrorTo(sessionId, (err as Error).message);
      return;
    }

    this.broadcastGameState();
    this.tryAutoResolveCurrentTurn();
  }

  private handlePlayCard(sessionId: string, payload: { card: { suit: string; rank: string } }) {
    if (!this.gameState) return;
    const playerId = this.playerIdFor(sessionId);
    if (!playerId) return;

    try {
      this.gameState = playCard(this.gameState, playerId, payload?.card as any);
    } catch (err) {
      this.sendErrorTo(sessionId, (err as Error).message);
      return;
    }

    this.afterCardPlayed();
    this.tryAutoResolveCurrentTurn();
  }

  private handleAdvanceRound(sessionId: string) {
    if (!this.gameState || this.gameState.phase !== 'roundEnd') return;
    this.gameState = advanceRound(this.gameState);
    this.broadcastGameState();
    this.tryAutoResolveCurrentTurn();

    if (this.gameState.phase === 'gameEnd') {
      this.broadcast('game-ended', {
        finalScores: this.gameState.players
          .map((p) => ({ id: p.id, name: p.name, totalScore: p.totalScore }))
          .sort((a, b) => b.totalScore - a.totalScore),
      });
    }
  }

  /**
   * Lógica común después de resolverse una jugada de carta (manual o
   * automática por ausencia).
   */
  private afterCardPlayed() {
    if (!this.gameState) return;
    this.broadcastGameState();

    if (this.gameState.phase === 'roundEnd') {
      this.broadcast('round-ended', {
        scores: this.gameState.players.map((p) => ({
          id: p.id,
          name: p.name,
          bid: p.bid,
          tricksWon: p.tricksWon,
        })),
      });
    }
  }

  /**
   * Si le toca el turno a un jugador ya marcado ausente: en fase de
   * canto se le canta 0 automático; en fase de jugar se le juega la
   * primera carta válida de su mano. Se encadena si el siguiente en la
   * fila también está ausente.
   */
  private tryAutoResolveCurrentTurn() {
    if (!this.gameState) return;

    const currentPlayer = this.gameState.players[this.gameState.currentTurnIndex];
    if (!currentPlayer) return;

    const seatId = this.seatOrder[this.gameState.currentTurnIndex];
    if (this.seatStatus.get(seatId) !== 'absent') return;

    if (this.gameState.phase === 'bidding') {
      try {
        this.gameState = placeBid(this.gameState, currentPlayer.id, 0);
      } catch {
        return; // caso límite sin regla definida (ver README) — el turno queda esperando
      }
      this.broadcastGameState();
      this.tryAutoResolveCurrentTurn();
      return;
    }

    if (this.gameState.phase === 'playing') {
      const card = currentPlayer.hand.find(
        (c) => validatePlay(this.gameState!, currentPlayer.id, c).valid
      );
      if (!card) return;

      try {
        this.gameState = playCard(this.gameState, currentPlayer.id, card);
      } catch {
        return;
      }
      this.afterCardPlayed();
      this.tryAutoResolveCurrentTurn();
    }
  }

  // ---------- Envío de mensajes ----------

  private broadcastLobby() {
    this.broadcast('lobby', {
      players: this.lobby.map((p) => ({ id: p.sessionId, name: p.name })),
      minPlayers: MIN_PLAYERS,
      maxPlayers: MAX_PLAYERS,
      canStart: this.lobby.length >= MIN_PLAYERS,
    });
  }

  private broadcastGameState() {
    if (!this.gameState) return;
    for (const sessionId of this.seatOrder) {
      this.sendStateTo(sessionId);
    }
  }

  private sendStateTo(sessionId: string) {
    if (!this.gameState) return;
    const ws = this.sockets.get(sessionId);
    if (!ws) return;
    const playerId = this.playerIdFor(sessionId);
    if (!playerId) return;
    this.send(ws, 'state', buildPlayerView(this.gameState, playerId));
  }

  private sendErrorTo(sessionId: string, message: string) {
    const ws = this.sockets.get(sessionId);
    if (ws) this.send(ws, 'error', { message });
  }

  private send(ws: WebSocket, type: string, payload: unknown) {
    if (ws.readyState === WS_OPEN) {
      ws.send(JSON.stringify({ type, payload }));
    }
  }

  private broadcast(type: string, payload: unknown) {
    for (const ws of this.sockets.values()) {
      this.send(ws, type, payload);
    }
  }
}
