import { Card, cardId, GameState, rankStrength } from './types';

export interface PlayValidationResult {
  valid: boolean;
  reason?: string;
}

/**
 * Valida si un jugador puede jugar esa carta:
 * - Si es el primero en jugar la baza, puede jugar cualquier carta.
 * - Si no es el primero, debe respetar el palo de salida SI TIENE cartas de
 *   ese palo.
 * - Si no tiene el palo de salida pero tiene triunfo, está obligado a
 *   jugar triunfo (no puede tirar cualquier otro palo).
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
  const trumpSuit = state.round.trumpSuit;
  const hasLeadSuit = player.hand.some((c) => c.suit === leadSuit);

  if (hasLeadSuit) {
    if (card.suit !== leadSuit) {
      return {
        valid: false,
        reason: `Debés responder al palo (${leadSuit}) si tenés cartas de ese palo`,
      };
    }
    return { valid: true };
  }

  // No tiene el palo de salida: si tiene triunfo, está obligado a "matar"
  // con triunfo (no puede tirar cualquier otro palo mientras le quede uno).
  if (trumpSuit !== null && leadSuit !== trumpSuit) {
    const hasTrump = player.hand.some((c) => c.suit === trumpSuit);
    if (hasTrump && card.suit !== trumpSuit) {
      return {
        valid: false,
        reason: `No tenés ${leadSuit}: estás obligado a jugar triunfo (${trumpSuit}) si tenés`,
      };
    }
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
 * Determina el ganador de la baza recién completada: suma la baza ganada,
 * pero DEJA las 4 cartas en la mesa (fase 'trickEnd') para que se alcancen
 * a ver antes de levantarlas. collectTrick() es quien realmente las limpia
 * y le pasa el turno al ganador.
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
    }
  }

  const players = state.players.map((p) =>
    p.id === winner.playerId ? { ...p, tricksWon: p.tricksWon + 1 } : p
  );

  return {
    ...state,
    players,
    phase: 'trickEnd',
    trickWinnerId: winner.playerId,
  };
}

/**
 * Levanta la baza que quedó completa en la mesa (fase 'trickEnd'): limpia
 * las cartas jugadas y le da el turno al ganador. Si ya no le quedan
 * cartas en la mano a nadie, la mano terminó (roundEnd).
 */
export function collectTrick(state: GameState): GameState {
  if (state.phase !== 'trickEnd' || state.trickWinnerId === null) return state;

  const winnerIndex = state.players.findIndex((p) => p.id === state.trickWinnerId);
  const roundFinished = state.players[0].hand.length === 0;

  return {
    ...state,
    currentTrick: [],
    trickLeaderSuit: null,
    currentTurnIndex: winnerIndex,
    trickWinnerId: null,
    phase: roundFinished ? 'roundEnd' : 'playing',
  };
}
