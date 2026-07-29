import { createDeckForPlayers, deal, MAX_HAND_SIZE, shuffle } from './deck';
import { scoreRound } from './scoring';
import { drawTrumpSuit } from './trump';
import { Card, GameState, Player, rankStrength } from './types';

export const MIN_PLAYERS = 4;

/**
 * Sortea quién reparte primero: se le tira una carta al azar a cada
 * jugador y la más alta reparte. Si hay empate en el valor más alto,
 * vuelven a sortear pero solo entre los jugadores empatados.
 */
export function determineInitialDealer(
  numPlayers: number,
  rng: () => number = Math.random
): { dealerIndex: number; draw: { playerIndex: number; card: Card }[] } {
  let candidates = Array.from({ length: numPlayers }, (_, i) => i);
  let firstDraw: { playerIndex: number; card: Card }[] | null = null;

  while (candidates.length > 1) {
    const { deck } = createDeckForPlayers(numPlayers);
    const shuffled = shuffle(deck, rng);
    const draw = candidates.map((playerIndex, i) => ({ playerIndex, card: shuffled[i] }));

    if (!firstDraw) firstDraw = draw;

    const maxStrength = Math.max(...draw.map((d) => rankStrength(d.card.rank)));
    candidates = draw
      .filter((d) => rankStrength(d.card.rank) === maxStrength)
      .map((d) => d.playerIndex);
  }

  return { dealerIndex: candidates[0], draw: firstDraw! };
}

/**
 * Calendario de manos:
 * - Ascendente: 1, 2, 3 ... 8 (mano máxima).
 * - Meseta: tantas manos de 8 cartas como jugadores haya (una "mano de
 *   área" por cada participante).
 * - Descendente: 7, 6, 5 ... 1 (vuelta al mínimo, sin repetir el 8).
 */
export function buildRoundsSchedule(numPlayers: number): number[] {
  const ascending = Array.from({ length: MAX_HAND_SIZE }, (_, i) => i + 1);
  const plateau = Array.from({ length: numPlayers }, () => MAX_HAND_SIZE);
  const descending = ascending.slice(0, -1).reverse(); // 7,6,5,4,3,2,1
  return [...ascending, ...plateau, ...descending];
}

export function createGame(
  playerNames: string[],
  rng: () => number = Math.random
): GameState {
  return createGameWithDealerReveal(playerNames, rng).state;
}

/**
 * Igual que createGame, pero además devuelve el detalle del sorteo de
 * carta inicial (qué le tocó a cada jugador) para poder mostrarlo en la UI
 * antes de arrancar a jugar.
 */
export function createGameWithDealerReveal(
  playerNames: string[],
  rng: () => number = Math.random
): { state: GameState; dealerDraw: { playerIndex: number; card: Card }[] } {
  if (playerNames.length < MIN_PLAYERS) {
    throw new Error(`Se necesitan al menos ${MIN_PLAYERS} jugadores`);
  }
  const { dealerIndex, draw } = determineInitialDealer(playerNames.length, rng);

  const players: Player[] = playerNames.map((name, i) => ({
    id: `p${i}`,
    name,
    hand: [],
    bid: null,
    tricksWon: 0,
    totalScore: 0,
  }));

  const roundsSchedule = buildRoundsSchedule(players.length);
  const { deckRanks } = createDeckForPlayers(players.length);
  const firstToActIndex = (dealerIndex + 1) % players.length;

  const state: GameState = {
    players,
    dealerIndex,
    firstToActIndex,
    currentTurnIndex: firstToActIndex,
    phase: 'bidding',
    round: { cardsPerPlayer: roundsSchedule[0], trumpSuit: null },
    currentTrick: [],
    trickLeaderSuit: null,
    trickWinnerId: null,
    roundNumber: 0,
    roundsSchedule,
    deckRanks,
  };

  return { state: startRound(state, rng), dealerDraw: draw };
}

export function startRound(state: GameState, rng: () => number = Math.random): GameState {
  const cardsPerPlayer = state.round.cardsPerPlayer;
  const { deck } = createDeckForPlayers(state.players.length);
  const shuffled = shuffle(deck, rng);
  const { hands } = deal(shuffled, state.players.length, cardsPerPlayer);

  const trumpSuit = drawTrumpSuit(rng);

  const players = state.players.map((p, i) => ({
    ...p,
    hand: hands[i],
    bid: null,
    tricksWon: 0,
  }));

  return {
    ...state,
    players,
    round: { ...state.round, trumpSuit },
    phase: 'bidding',
    currentTrick: [],
    trickLeaderSuit: null,
  };
}

/**
 * Se llama cuando una mano terminó (phase === 'roundEnd'):
 * puntúa la mano y, si quedan manos en el calendario, reparte la
 * siguiente. Si era la última mano, pasa a 'gameEnd'.
 */
export function advanceRound(state: GameState, rng: () => number = Math.random): GameState {
  const scored = scoreRound(state);

  const nextRoundNumber = scored.roundNumber + 1;
  const isLastRound = nextRoundNumber >= scored.roundsSchedule.length;

  if (isLastRound) {
    return { ...scored, phase: 'gameEnd' };
  }

  const nextDealerIndex = (scored.dealerIndex + 1) % scored.players.length;
  const nextFirstToActIndex = (nextDealerIndex + 1) % scored.players.length;
  const nextCardsPerPlayer = scored.roundsSchedule[nextRoundNumber];

  const players = scored.players.map((p) => ({ ...p, bid: null, tricksWon: 0, hand: [] }));

  const preRoundState: GameState = {
    ...scored,
    players,
    dealerIndex: nextDealerIndex,
    firstToActIndex: nextFirstToActIndex,
    currentTurnIndex: nextFirstToActIndex,
    roundNumber: nextRoundNumber,
    round: { ...scored.round, cardsPerPlayer: nextCardsPerPlayer },
  };

  return startRound(preRoundState, rng);
      }
