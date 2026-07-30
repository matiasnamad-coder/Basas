import { GameState } from './types';

export interface PlayerView {
  phase: GameState['phase'];
  roundNumber: number;
  roundsSchedule: number[];
  round: { cardsPerPlayer: number; trumpSuit: string | null };
  currentTurnIndex: number;
  dealerIndex: number;
  currentTrick: { playerId: string; card: { suit: string; rank: string } }[];
  trickLeaderSuit: string | null;
  trickWinnerId: string | null;
  you: { id: string };
  players: {
    id: string;
    name: string;
    bid: number | null;
    tricksWon: number;
    totalScore: number;
    handCount: number;
    hand?: { suit: string; rank: string }[]; // solo presente para el propio jugador
  }[];
}

export function buildPlayerView(state: GameState, viewerId: string): PlayerView {
  return {
    phase: state.phase,
    roundNumber: state.roundNumber,
    roundsSchedule: state.roundsSchedule,
    round: state.round,
    currentTurnIndex: state.currentTurnIndex,
    dealerIndex: state.dealerIndex,
    currentTrick: state.currentTrick,
    trickLeaderSuit: state.trickLeaderSuit,
    trickWinnerId: state.trickWinnerId,
    you: { id: viewerId },
    players: state.players.map((p) => ({
      id: p.id,
      name: p.name,
      bid: p.bid,
      tricksWon: p.tricksWon,
      totalScore: p.totalScore,
      handCount: p.hand.length,
      hand: p.id === viewerId ? p.hand : undefined,
    })),
  };
    }
