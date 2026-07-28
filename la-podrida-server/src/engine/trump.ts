import { shuffle } from './deck';
import { Suit, SUITS } from './types';

/**
 * En esta variante el triunfo NO sale de las cartas repartidas: hay un
 * mazo aparte de 4 ases (uno por palo) que se baraja y se revela una
 * carta al azar en cada mano para determinar el palo de triunfo.
 * Como los 4 "ases indicadores" son equivalentes entre sí a los fines de
 * elegir el palo, esto equivale a elegir un palo al azar de forma
 * uniforme, pero lo modelamos explícitamente para que quede claro en el
 * código y sea fácil de mostrar en la UI ("se revela el As de picas").
 */
export function drawTrumpSuit(rng: () => number = Math.random): Suit {
  const shuffled = shuffle(SUITS, rng);
  return shuffled[0];
}
