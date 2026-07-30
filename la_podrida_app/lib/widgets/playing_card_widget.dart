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
    final cornerFontSize = width * 0.22;
    final symbolSize = width * 0.42;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: dimmed ? 0.45 : 1.0,
        child: Container(
          width: width,
          height: height,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(width * 0.12),
            border: Border.all(color: Colors.black.withOpacity(0.3), width: 0.8),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFFDF7), Color(0xFFF1EADC)],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 4,
                offset: const Offset(1, 3),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: 3,
                left: 4,
                child: _cornerIndex(cornerFontSize),
              ),
              Positioned(
                bottom: 3,
                right: 4,
                child: Transform.rotate(
                  angle: 3.14159,
                  child: _cornerIndex(cornerFontSize),
                ),
              ),
              Center(
                child: Text(
                  card.suitSymbol,
                  style: TextStyle(fontSize: symbolSize, color: card.suitColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cornerIndex(double fontSize) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          card.displayRank,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: card.suitColor,
            height: 1,
          ),
        ),
        Text(
          card.suitSymbol,
          style: TextStyle(fontSize: fontSize * 0.85, color: card.suitColor, height: 1),
        ),
      ],
    );
  }
}
