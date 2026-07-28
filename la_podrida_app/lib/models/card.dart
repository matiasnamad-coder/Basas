import 'package:flutter/material.dart';

/// Representa una carta tal como la manda el servidor: palo y rango son
/// strings (el rango puede ser "2".."10", "J", "Q", "K", "A", o una de las
/// cartas extra numeradas "1", "11", "12", "13" según cuántos jugadores
/// haya en la partida).
@immutable
class GameCard {
  final String suit; // 'corazones' | 'diamantes' | 'treboles' | 'picas'
  final String rank;

  const GameCard({required this.suit, required this.rank});

  factory GameCard.fromJson(Map<String, dynamic> json) {
    return GameCard(suit: json['suit'] as String, rank: json['rank'] as String);
  }

  Map<String, dynamic> toJson() => {'suit': suit, 'rank': rank};

  String get suitSymbol {
    switch (suit) {
      case 'corazones':
        return '♥';
      case 'diamantes':
        return '♦';
      case 'treboles':
        return '♣';
      case 'picas':
        return '♠';
      default:
        return '?';
    }
  }

  Color get suitColor {
    return (suit == 'corazones' || suit == 'diamantes') ? Colors.red.shade700 : Colors.black87;
  }

  String get displayRank => rank; // ya viene legible ('J','Q','K','A' o número)

  String get id => '$rank-$suit';

  @override
  bool operator ==(Object other) => other is GameCard && other.suit == suit && other.rank == rank;

  @override
  int get hashCode => Object.hash(suit, rank);
}
