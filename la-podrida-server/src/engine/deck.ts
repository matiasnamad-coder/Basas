import { BASE_RANKS, Card, EXTRA_RANKS_POOL, Rank, SUITS } from './types';

export const MAX_HAND_SIZE = 8;

/**
 * El mazo siempre se ajusta para tener EXACTAMENTE 8 * numPlayers cartas
 * (ni una de más ni una de menos), que es lo que hace falta para repartir
 * la mano máxima entre todos:
 *
 * - Si sobran cartas respecto del mazo estándar de 52 (pocos jugadores),
 *   se sacan las de menor valor (2, 3, 4...) hasta ajustar.
 * - Si faltan cartas (muchos jugadores), se agregan del pool fijo de
 *   cartas extra numeradas: "1", "11", "12", "13", en ese orden.
 */
export function computeDeckRanks(numPlayers: number): Rank[] {
  const ranksNeeded = (MAX_HAND_SIZE / 4) * numPlayers; // 2 * numPlayers

  if (ranksNeeded <= BASE_RANKS.length) {
    const removeCount = BASE_RANKS.length - ranksNeeded;
    return BASE_RANKS.slice(removeCount);
  }

  const extraCount = ranksNeeded - BASE_RANKS.length;
  if (extraCount > EXTRA_RANKS_POOL.length) {
    throw new Error(
      `No hay suficientes cartas extra definidas para ${numPlayers} jugadores ` +
        `(harían falta ${extraCount} rangos extra, solo hay ${EXTRA_RANKS_POOL.length} definidos: ${EXTRA_RANKS_POOL.join(', ')})`
    );
  }
  return [...BASE_RANKS, ...EXTRA_RANKS_POOL.slice(0, extraCount)];
}

export function createDeckForPlayers(numPlayers: number): { deck: Card[]; deckRanks: Rank[] } {
  const deckRanks = computeDeckRanks(numPlayers);
  const deck: Card[] = [];
  for (const suit of SUITS) {
    for (const rank of deckRanks) {
      deck.push({ suit, rank });
    }
  }
  return { deck, deckRanks };
}

// Fisher-Yates shuffle. Se puede pasar un rng propio para tests deterministas.
export function shuffle<T>(items: T[], rng: () => number = Math.random): T[] {
  const arr = [...items];
  for (let i = arr.length - 1; i > 0; i--) {
    const j = Math.floor(rng() * (i + 1));
    [arr[i], arr[j]] = [arr[j], arr[i]];
  }
  return arr;
}

export function deal(deck: Card[], numPlayers: number, cardsPerPlayer: number): {
  hands: Card[][];
  remaining: Card[];
} {
  const totalNeeded = numPlayers * cardsPerPlayer;
  if (totalNeeded > deck.length) {
    throw new Error(
      `No hay suficientes cartas: se necesitan ${totalNeeded}, hay ${deck.length}`
    );
  }
  const hands: Card[][] = Array.from({ length: numPlayers }, () => []);
  let cursor = 0;
  for (let c = 0; c < cardsPerPlayer; c++) {
    for (let p = 0; p < numPlayers; p++) {
      hands[p].push(deck[cursor]);
      cursor++;
    }
  }
  return { hands, remaining: deck.slice(cursor) };
}
