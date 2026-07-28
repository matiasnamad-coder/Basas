import { validateBid } from './bidding';
import { validatePlay } from './trick';
import { Card, GameState, Player, rankStrength } from './types';

export function chooseBotBid(state: GameState, player: Player): number {
  const { cardsPerPlayer } = state.round;
  const trumpSuit = state.round.trumpSuit;

  let estimate = 0;
  for (const card of player.hand) {
    if (trumpSuit !== null && card.suit === trumpSuit) {
      estimate += 1;
    } else if (rankStrength(card.rank) >= 12) {
      estimate += 0.5;
    }
  }

  let bid = Math.max(0, Math.min(cardsPerPlayer, Math.round(estimate)));

  if (!validateBid(state, player.id, bid).valid) {
    const alternatives = [1, -1, 2, -2, 3, -3];
    for (const delta of alternatives) {
      const candidate = bid + delta;
      if (
        candidate >= 0 &&
        candidate <= cardsPerPlayer &&
        validateBid(state, player.id, candidate).valid
      ) {
        bid = candidate;
        break;
      }
    }
  }

  return bid;
}

export function chooseBotCard(state: GameState, player: Player): Card {
  const validCards = player.hand.filter((c) => validatePlay(state, player.id, c).valid);
  const tricksNeeded = (player.bid ?? 0) - player.tricksWon;

  if (tricksNeeded > 0) {
    return validCards.reduce((best, c) =>
      rankStrength(c.rank) > rankStrength(best.rank) ? c : best
    );
  }

  return validCards.reduce((worst, c) =>
    rankStrength(c.rank) < rankStrength(worst.rank) ? c : worst
  );
}
