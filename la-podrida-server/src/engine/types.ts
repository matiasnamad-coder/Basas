// Tipos base del motor de "Las Basas" (baraja francesa)

export type Suit = 'corazones' | 'diamantes' | 'treboles' | 'picas';

export const SUITS: Suit[] = ['corazones', 'diamantes', 'treboles', 'picas'];

// Los 13 rangos de una baraja francesa estándar de 52 cartas, de menor a mayor.
export const BASE_RANKS: string[] = [
  '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K', 'A',
];

/**
 * Cartas extra numeradas (sin letras) que existen aparte del mazo estándar,
 * para cuando hacen falta más de 52 cartas. Se agregan en este orden fijo:
 * primero el "1" (por debajo del 2), después "11" y "12" (que empatan en
 * fuerza con J y Q pero son cartas distintas), y por último "13" (empata
 * con K). Es una lista fija porque son cartas físicas concretas del mazo,
 * no una extensión matemática infinita.
 */
export const EXTRA_RANKS_POOL: string[] = ['1', '11', '12', '13'];

export type Rank = string;

export interface Card {
  suit: Suit;
  rank: Rank;
}

export function cardId(card: Card): string {
  return `${card.rank}-${card.suit}`;
}

const FACE_STRENGTH: Record<string, number> = { J: 11, Q: 12, K: 13, A: 14 };

/**
 * Fuerza numérica de un rango. Los rangos numéricos usan su propio valor
 * (por eso "11" empata en fuerza con J, "12" con Q, etc. — son cartas
 * distintas pero de igual jerarquía). No se usa el orden del array del
 * mazo para esto, así que dos cartas pueden empatar en fuerza.
 */
export function rankStrength(rank: Rank): number {
  if (rank in FACE_STRENGTH) return FACE_STRENGTH[rank];
  const n = Number(rank);
  if (Number.isNaN(n)) throw new Error(`Rango desconocido: ${rank}`);
  return n;
}

export interface Player {
  id: string;
  name: string;
  hand: Card[];
  bid: number | null;      // bazas cantadas esta mano (null = aún no cantó)
  tricksWon: number;       // bazas ganadas esta mano
  totalScore: number;      // puntaje acumulado de toda la partida
}

export type GamePhase = 'bidding' | 'playing' | 'roundEnd' | 'gameEnd';

export interface TrickPlay {
  playerId: string;
  card: Card;
}

export interface RoundConfig {
  cardsPerPlayer: number;
  trumpSuit: Suit | null;
}

export interface GameState {
  players: Player[];
  dealerIndex: number;
  firstToActIndex: number;
  currentTurnIndex: number;
  phase: GamePhase;
  round: RoundConfig;
  currentTrick: TrickPlay[];
  trickLeaderSuit: Suit | null;
  roundNumber: number;
  roundsSchedule: number[];
  deckRanks: Rank[]; // qué rangos tiene el mazo de esta partida (fijo, según cantidad de jugadores)
}
