import { Card, cardId, GameState, rankStrength } from './types';

export interface PlayValidationResult {
  valid: boolean;
  reason?: string;
}

/**
 * Valida si un jugador puede jugar esa carta:
 * - Si es el primero en jugar la baza, puede jugar cualquier carta.
 * - Si no es el primero, debe respetar el palo de salida SI TIENE cartas de
 *   ese palo. No está obligado a "matar" (jugar carta superior), solo a
 *   responder al palo.
 */
export function validatePlay(
  state: GameState,
  playerId: string,
  card: Card
): PlayValidationResult {
  const player = state.players.find((p) => p.id === playerId);
  if (!player) return { valid: false, reason: 'Jugador no encontrado' };

  const hasCard = player.hand.some((c) => cardId(c) === cardId(card));
  if (!hasCard) return { valid: false, reason: 'El jugador no tiene esa carta' };

  if (state.currentTrick.length === 0) {
    return { valid: true }; // el que sale, sale libre
  }

  const leadSuit = state.trickLeaderSuit;
  const hasLeadSuit = player.hand.some((c) => c.suit === leadSuit);

  if (hasLeadSuit && card.suit !== leadSuit) {
    return {
      valid: false,
      reason: `Debés responder al palo (${leadSuit}) si tenés cartas de ese palo`,
    };
  }

  return { valid: true };
}

export function playCard(state: GameState, playerId: string, card: Card): GameState {
  const validation = validatePlay(state, playerId, card);
  if (!validation.valid) {
    throw new Error(validation.reason);
  }

  const players = state.players.map((p) =>
    p.id === playerId
      ? { ...p, hand: p.hand.filter((c) => cardId(c) !== cardId(card)) }
      : p
  );

  const currentTrick = [...state.currentTrick, { playerId, card }];
  const trickLeaderSuit = state.currentTrick.length === 0 ? card.suit : state.trickLeaderSuit;

  const nextState: GameState = {
    ...state,
    players,
    currentTrick,
    trickLeaderSuit,
    currentTurnIndex: (state.currentTurnIndex + 1) % state.players.length,
  };

  if (currentTrick.length === state.players.length) {
    return resolveTrick(nextState);
  }

  return nextState;
}

/**
 * Determina el ganador de la baza:
 * - Si alguien jugó triunfo, gana el triunfo más alto jugado.
 * - Si no hay triunfos en la baza, gana la carta más alta del palo de salida.
 */
export function resolveTrick(state: GameState): GameState {
  const { currentTrick, round } = state;
  const trumpSuit = round.trumpSuit;

  let winner = currentTrick[0];
  for (const play of currentTrick.slice(1)) {
    const isWinnerTrump = trumpSuit !== null && winner.card.suit === trumpSuit;
    const isPlayTrump = trumpSuit !== null && play.card.suit === trumpSuit;

    if (isPlayTrump && !isWinnerTrump) {
      winner = play;
    } else if (isPlayTrump === isWinnerTrump && play.card.suit === winner.card.suit) {
      if (rankStrength(play.card.rank) > rankStrength(winner.card.rank)) {
        winner = play;
      }
      // en caso de empate exacto (ej. J vs la carta extra "11"), gana la
      // que se jugó primero — no cambia el ganador.
    }
    // si play no es triunfo, winner es triunfo, o son de palos distintos
    // sin triunfo de por medio → no cambia el ganador
  }

  const players = state.players.map((p) =>
    p.id === winner.playerId ? { ...p, tricksWon: p.tricksWon + 1 } : p
  );

  const winnerIndex = players.findIndex((p) => p.id === winner.playerId);
  const roundFinished = players[0].hand.length === 0;

  return {
    ...state,
    players,
    currentTrick: [],
    trickLeaderSuit: null,
    currentTurnIndex: winnerIndex,
    phase: roundFinished ? 'roundEnd' : 'playing',
  };
}
