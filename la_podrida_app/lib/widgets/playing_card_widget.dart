import 'package:flutter/material.dart';

import '../models/card.dart';

class PlayingCardWidget extends StatelessWidget {
  final GameCard card;
  final VoidCallback? onTap;
  final bool dimmed;
  final double width;

  const PlayingCardWidget({
    super.key,
    required this.card,
    this.onTap,
    this.dimmed = false,
    this.width = 56,
  });

  @override
  Widget build(BuildContext context) {
    final height = width * 1.45;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: dimmed ? 0.45 : 1.0,
        child: Container(
          width: width,
          height: height,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.black26),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(0, 1)),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                card.displayRank,
                style: TextStyle(
                  fontSize: width * 0.32,
                  fontWeight: FontWeight.bold,
                  color: card.suitColor,
                ),
              ),
              Text(
                card.suitSymbol,
                style: TextStyle(fontSize: width * 0.32, color: card.suitColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
