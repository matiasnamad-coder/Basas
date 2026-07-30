import 'card.dart';

class TrickPlay {
  final String playerId;
  final GameCard card;

  TrickPlay({required this.playerId, required this.card});

  factory TrickPlay.fromJson(Map<String, dynamic> json) {
    return TrickPlay(
      playerId: json['playerId'] as String,
      card: GameCard.fromJson(json['card'] as Map<String, dynamic>),
    );
  }
}

class PlayerInfo {
  final String id;
  final String name;
  final int? bid;
  final int tricksWon;
  final int totalScore;
  final int handCount;
  final List<GameCard>? hand;

  PlayerInfo({
    required this.id,
    required this.name,
    required this.bid,
    required this.tricksWon,
    required this.totalScore,
    required this.handCount,
    required this.hand,
  });

  factory PlayerInfo.fromJson(Map<String, dynamic> json) {
    final handJson = json['hand'] as List<dynamic>?;
    return PlayerInfo(
      id: json['id'] as String,
      name: json['name'] as String,
      bid: json['bid'] as int?,
      tricksWon: json['tricksWon'] as int? ?? 0,
      totalScore: json['totalScore'] as int? ?? 0,
      handCount: json['handCount'] as int? ?? 0,
      hand: handJson?.map((c) => GameCard.fromJson(c as Map<String, dynamic>)).toList(),
    );
  }
}

class RoundInfo {
  final int cardsPerPlayer;
  final String? trumpSuit;

  RoundInfo({required this.cardsPerPlayer, required this.trumpSuit});

  factory RoundInfo.fromJson(Map<String, dynamic> json) {
    return RoundInfo(
      cardsPerPlayer: json['cardsPerPlayer'] as int,
      trumpSuit: json['trumpSuit'] as String?,
    );
  }
}

/// Tu vista personal del estado del juego: nunca incluye las manos ajenas.
class PlayerView {
  final String phase; // 'bidding' | 'playing' | 'trickEnd' | 'roundEnd' | 'gameEnd'
  final int roundNumber;
  final List<int> roundsSchedule;
  final RoundInfo round;
  final int currentTurnIndex;
  final int dealerIndex;
  final List<TrickPlay> currentTrick;
  final String? trickLeaderSuit;
  final String? trickWinnerId;
  final String yourId;
  final List<PlayerInfo> players;

  PlayerView({
    required this.phase,
    required this.roundNumber,
    required this.roundsSchedule,
    required this.round,
    required this.currentTurnIndex,
    required this.dealerIndex,
    required this.currentTrick,
    required this.trickLeaderSuit,
    required this.trickWinnerId,
    required this.yourId,
    required this.players,
  });

  factory PlayerView.fromJson(Map<String, dynamic> json) {
    return PlayerView(
      phase: json['phase'] as String,
      roundNumber: json['roundNumber'] as int,
      roundsSchedule: (json['roundsSchedule'] as List<dynamic>).map((e) => e as int).toList(),
      round: RoundInfo.fromJson(json['round'] as Map<String, dynamic>),
      currentTurnIndex: json['currentTurnIndex'] as int,
      dealerIndex: json['dealerIndex'] as int,
      currentTrick: (json['currentTrick'] as List<dynamic>)
          .map((e) => TrickPlay.fromJson(e as Map<String, dynamic>))
          .toList(),
      trickLeaderSuit: json['trickLeaderSuit'] as String?,
      trickWinnerId: json['trickWinnerId'] as String?,
      yourId: (json['you'] as Map<String, dynamic>)['id'] as String,
      players: (json['players'] as List<dynamic>)
          .map((e) => PlayerInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  PlayerInfo get you => players.firstWhere((p) => p.id == yourId);

  bool get isYourTurn => players.isNotEmpty && players[currentTurnIndex].id == yourId;

  PlayerInfo get currentTurnPlayer => players[currentTurnIndex];
}
