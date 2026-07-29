import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/card.dart';
import '../models/game_view.dart';
import '../services/game_client.dart';
import '../widgets/playing_card_widget.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  bool _dealerDrawShown = false;
  bool _roundEndedShown = false;
  bool _gameEndedShown = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<GameClient>(
      builder: (context, client, _) {
        final view = client.view;

        if (view == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowDialogs(context, client));

        return Scaffold(
          appBar: AppBar(
            title: Text(_phaseLabel(view)),
            actions: [
              if (client.status == ConnectionStatus.reconnecting)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Center(child: Text('Reconectando…')),
                ),
            ],
          ),
          body: Column(
            children: [
              _buildRoundInfo(view),
              if (client.errorMessage != null) _buildErrorBanner(client),
              _buildScoreboard(view),
              Expanded(child: _buildTrickArea(view)),
              _buildBottomControls(context, client, view),
            ],
          ),
        );
      },
    );
  }

  String _phaseLabel(PlayerView view) {
    switch (view.phase) {
      case 'bidding':
        return 'Cantando bazas';
      case 'playing':
        return 'Jugando';
      case 'roundEnd':
        return 'Fin de mano';
      case 'gameEnd':
        return 'Partida terminada';
      default:
        return 'Las Basas';
    }
  }

  Widget _buildRoundInfo(PlayerView view) {
    final trump = view.round.trumpSuit;
    return Container(
      width: double.infinity,
      color: Colors.green.shade700,
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Mano ${view.roundNumber + 1}/${view.roundsSchedule.length} · '
            '${view.round.cardsPerPlayer} cartas',
            style: const TextStyle(color: Colors.white),
          ),
          if (trump != null)
            Text(
              'Triunfo: ${_suitSymbol(trump)}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
        ],
      ),
    );
  }

  String _suitSymbol(String suit) {
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
        return suit;
    }
  }

  Widget _buildErrorBanner(GameClient client) {
    return MaterialBanner(
      backgroundColor: Colors.red.shade50,
      content: Text(client.errorMessage!),
      actions: [
        TextButton(onPressed: client.clearError, child: const Text('Cerrar')),
      ],
    );
  }

  Widget _buildScoreboard(PlayerView view) {
    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        itemCount: view.players.length,
        itemBuilder: (context, i) {
          final p = view.players[i];
          final isTurn = i == view.currentTurnIndex;
          final isDealer = i == view.dealerIndex;
          return Container(
            width: 130,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isTurn ? Colors.amber.shade100 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isTurn ? Colors.amber : Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        p.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (isDealer) const Icon(Icons.style, size: 14),
                  ],
                ),
                Text('Canto: ${p.bid ?? "-"}  ·  Hechas: ${p.tricksWon}'),
                Text('Puntos: ${p.totalScore}'),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTrickArea(PlayerView view) {
    if (view.currentTrick.isEmpty) {
      return const Center(child: Text('Esperando la primera carta de la mano…'));
    }
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        children: view.currentTrick.map((play) {
          final playerName = view.players.firstWhere((p) => p.id == play.playerId).name;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(playerName, style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 4),
              PlayingCardWidget(card: play.card, width: 48),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBottomControls(BuildContext context, GameClient client, PlayerView view) {
    final you = view.you;
    final isYourTurn = view.isYourTurn;

    if (view.phase == 'bidding') {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHandPreview(you),
          _buildBiddingControls(client, view, isYourTurn),
        ],
      );
    }

    if (view.phase == 'playing') {
      return _buildHand(client, view, you, isYourTurn);
    }

    return const SizedBox(height: 16);
  }

  Widget _buildHandPreview(PlayerInfo you) {
    final hand = you.hand ?? [];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SizedBox(
        height: 100,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: hand.map((card) => PlayingCardWidget(card: card, width: 64)).toList(),
        ),
      ),
    );
  }

  Widget _buildBiddingControls(GameClient client, PlayerView view, bool isYourTurn) {
    if (!isYourTurn) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Esperando el canto de ${view.currentTurnPlayer.name}…'),
      );
    }

    final max = view.round.cardsPerPlayer;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('¿Cuántas bazas cantás?', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: List.generate(max + 1, (n) {
              return OutlinedButton(
                onPressed: () => client.bid(n),
                child: Text('$n'),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildHand(GameClient client, PlayerView view, PlayerInfo you, bool isYourTurn) {
    final hand = you.hand ?? [];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isYourTurn)
            Text('Esperando la jugada de ${view.currentTurnPlayer.name}…')
          else
            const Text('Tocá una carta para jugarla', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SizedBox(
            height: 100,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: hand.map((card) {
                return PlayingCardWidget(
                  card: card,
                  dimmed: !isYourTurn,
                  onTap: isYourTurn ? () => client.playCard(card) : null,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  void _maybeShowDialogs(BuildContext context, GameClient client) {
    if (client.dealerDraw != null && !_dealerDrawShown) {
      _dealerDrawShown = true;
      _showDealerDrawDialog(context, client.dealerDraw!);
    }
    if (client.view?.phase == 'roundEnd' && client.roundEndedInfo != null && !_roundEndedShown) {
      _roundEndedShown = true;
      _showRoundEndedDialog(context, client);
    }
    if (client.view?.phase != 'roundEnd') {
      _roundEndedShown = false;
    }
    if (client.gameEndedInfo != null && !_gameEndedShown) {
      _gameEndedShown = true;
      _showGameEndedDialog(context, client.gameEndedInfo!);
    }
  }

  void _showDealerDrawDialog(BuildContext context, Map<String, dynamic> draw) {
    final dealerName = (draw['draw'] as List<dynamic>).cast<Map<String, dynamic>>().firstWhere(
          (d) => d['seatId'] == draw['dealerSeatId'],
        )['name'] as String;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('¿Quién reparte?'),
        content: Text('$dealerName sacó la carta más alta y reparte primero.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Listo')),
        ],
      ),
    );
  }

  void _showRoundEndedDialog(BuildContext context, GameClient client) {
    final scores = (client.roundEndedInfo!['scores'] as List<dynamic>).cast<Map<String, dynamic>>();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Fin de la mano'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: scores.map((s) {
            final hit = s['bid'] == s['tricksWon'];
            return ListTile(
              title: Text(s['name'] as String),
              subtitle: Text('Cantó ${s['bid']}, hizo ${s['tricksWon']}'),
              trailing: Icon(
                hit ? Icons.check_circle : Icons.cancel,
                color: hit ? Colors.green : Colors.red,
              ),
            );
          }).toList(),
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              client.advanceRound();
            },
            child: const Text('Siguiente mano'),
          ),
        ],
      ),
    );
  }

  void _showGameEndedDialog(BuildContext context, Map<String, dynamic> gameEnded) {
    final finalScores = (gameEnded['finalScores'] as List<dynamic>).cast<Map<String, dynamic>>();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('¡Partida terminada!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(finalScores.length, (i) {
            final s = finalScores[i];
            return ListTile(
              leading: CircleAvatar(child: Text('${i + 1}')),
              title: Text(s['name'] as String),
              trailing: Text('${s['totalScore']} pts'),
            );
          }),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
  }
}
