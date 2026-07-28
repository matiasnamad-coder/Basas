import { GameState, Player } from './types';

/**
 * Puntuación de esta variante:
 * - Si acertás el canto: +10, más 1 punto por cada baza ganada.
 * - Si NO acertás: -10, más 1 punto por cada baza ganada (o sea, las
 *   bazas ganadas siempre suman, acierte o no; lo que cambia es el +-10).
 */
export type ScoringStrategy = (player: Player) => number;

export const defaultScoringStrategy: ScoringStrategy = (player) => {
  const hit = player.bid === player.tricksWon;
  return (hit ? 10 : -10) + player.tricksWon;
};

export function scoreRound(
  state: GameState,
  strategy: ScoringStrategy = defaultScoringStrategy
): GameState {
  const players = state.players.map((p) => ({
    ...p,
    totalScore: p.totalScore + strategy(p),
  }));

  return { ...state, players };
}

export function resetForNextRound(
  state: GameState,
  nextCardsPerPlayer: number
): GameState {
  const nextDealerIndex = (state.dealerIndex + 1) % state.players.length;
  const nextFirstToActIndex = (nextDealerIndex + 1) % state.players.length;

  const players = state.players.map((p) => ({
    ...p,
    bid: null,
    tricksWon: 0,
    hand: [],
  }));

  return {
    ...state,
    players,
    dealerIndex: nextDealerIndex,
    firstToActIndex: nextFirstToActIndex,
    currentTurnIndex: nextFirstToActIndex,
    phase: 'bidding',
    round: { ...state.round, cardsPerPlayer: nextCardsPerPlayer },
    roundNumber: state.roundNumber + 1,
  };
}
