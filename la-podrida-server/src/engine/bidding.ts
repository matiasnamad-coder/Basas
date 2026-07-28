import { GameState } from './types';

export interface BidValidationResult {
  valid: boolean;
  reason?: string;
}

/**
 * Valida el canto de un jugador.
 * Regla clave de "Las Basas": el ÚLTIMO jugador en cantar (normalmente el
 * dador) NO puede cantar un número tal que la suma total de bazas cantadas
 * sea igual a las bazas en juego (cardsPerPlayer). Esto obliga a que
 * siempre haya al menos un jugador que falle su pronóstico.
 */
export function validateBid(
  state: GameState,
  playerId: string,
  bid: number
): BidValidationResult {
  const { cardsPerPlayer } = state.round;

  if (bid < 0 || bid > cardsPerPlayer) {
    return {
      valid: false,
      reason: `El canto debe estar entre 0 y ${cardsPerPlayer}`,
    };
  }

  const playersWhoHaveBid = state.players.filter((p) => p.bid !== null);
  const isLastToBid = playersWhoHaveBid.length === state.players.length - 1;

  if (isLastToBid) {
    const sumSoFar = playersWhoHaveBid.reduce((acc, p) => acc + (p.bid ?? 0), 0);
    const forbidden = cardsPerPlayer - sumSoFar;
    if (bid === forbidden) {
      return {
        valid: false,
        reason: `No podés cantar ${bid}: la suma total no puede ser igual a ${cardsPerPlayer} (bazas en juego)`,
      };
    }
  }

  return { valid: true };
}

export function placeBid(state: GameState, playerId: string, bid: number): GameState {
  const validation = validateBid(state, playerId, bid);
  if (!validation.valid) {
    throw new Error(validation.reason);
  }

  const players = state.players.map((p) =>
    p.id === playerId ? { ...p, bid } : p
  );

  const allBid = players.every((p) => p.bid !== null);

  return {
    ...state,
    players,
    phase: allBid ? 'playing' : 'bidding',
    currentTurnIndex: allBid
      ? state.firstToActIndex
      : (state.currentTurnIndex + 1) % state.players.length,
  };
}
