import 'dart:math' as math;

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
              Expanded(child: _buildTableFelt(view)),
              _buildBottomControls(context, client, view),
              _ChatBar(client: client),
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
      case 'trickEnd':
        return 'Baza completa';
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

  /// Mesa ovalada de casino, con cada jugador en su asiento alrededor
  /// (nombre, canto, bazas hechas y puntos) y la baza en el medio.
  Widget _buildTableFelt(PlayerView view) {
    return Container(
      margin: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF6B4423), width: 10),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 4)),
        ],
        gradient: const RadialGradient(
          center: Alignment.center,
          radius: 1.1,
          colors: [Color(0xFF1E7A46), Color(0xFF0B4027)],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const seatWidth = 74.0;
          const seatHeight = 58.0;
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;

          final n = view.players.length;
          final yourIndex = view.players.indexWhere((p) => p.id == view.yourId);
          final alignments = _seatAlignments(n);

          return Stack(
            children: [
              Center(child: _buildTrickArea(view)),
              for (var i = 0; i < n; i++)
                Builder(builder: (context) {
                  final relative = yourIndex == -1 ? i : (i - yourIndex + n) % n;
                  final align = alignments[relative];
                  final dx = (width - seatWidth) / 2 * (1 + align.x);
                  final dy = (height - seatHeight) / 2 * (1 + align.y);
                  final p = view.players[i];
                  final isTurn = view.phase == 'trickEnd'
                      ? p.id == view.trickWinnerId
                      : i == view.currentTurnIndex;
                  final isDealer = i == view.dealerIndex;
                  final isYou = i == yourIndex;
                  return Positioned(
                    left: dx,
                    top: dy,
                    width: seatWidth,
                    child: _buildSeat(p, isTurn: isTurn, isDealer: isDealer, isYou: isYou),
                  );
                }),
            ],
          );
        },
      ),
    );
  }

  /// Posiciones fijas por cantidad de jugadores (no una elipse pareja),
  /// para que los asientos de arriba queden bien separados aunque la
  /// mesa sea angosta. El índice 0 siempre es "vos" (abajo, centro).
  List<Alignment> _seatAlignments(int n) {
    switch (n) {
      case 2:
        return const [Alignment(0, 0.95), Alignment(0, -0.95)];
      case 3:
        return const [
          Alignment(0, 0.95),
          Alignment(-0.9, -0.55),
          Alignment(0.9, -0.55),
        ];
      case 4:
        return const [
          Alignment(0, 0.95),
          Alignment(-0.95, 0),
          Alignment(0, -0.95),
          Alignment(0.95, 0),
        ];
      case 5:
        return const [
          Alignment(0, 0.95),
          Alignment(-0.95, 0.35),
          Alignment(-0.6, -0.95),
          Alignment(0.6, -0.95),
          Alignment(0.95, 0.35),
        ];
      case 6:
        return const [
          Alignment(0, 0.95),
          Alignment(-0.95, 0.5),
          Alignment(-0.95, -0.55),
          Alignment(0, -0.95),
          Alignment(0.95, -0.55),
          Alignment(0.95, 0.5),
        ];
      default:
        return List.generate(n, (i) {
          final angle = (math.pi / 2) + i * (2 * math.pi / n);
          return Alignment(math.cos(angle), math.sin(angle) * 0.95);
        });
    }
  }

  /// Un asiento individual: avatar circular (con el ícono de dealer si le
  /// toca repartir), nombre, canto/hechas, y un "chip" con el puntaje.
  Widget _buildSeat(
    PlayerInfo p, {
    required bool isTurn,
    required bool isDealer,
    required bool isYou,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isTurn ? Colors.amberAccent : Colors.white24,
          width: isTurn ? 2.5 : 1,
        ),
        boxShadow: isTurn
            ? [BoxShadow(color: Colors.amberAccent.withOpacity(0.6), blurRadius: 10)]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: isYou ? Colors.amber.shade700 : Colors.blueGrey.shade600,
                child: const Icon(Icons.person, color: Colors.white),
              ),
              if (isDealer)
                Positioned(
                  top: -4,
                  right: -4,
                  child: CircleAvatar(
                    radius: 9,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.style, size: 11, color: Colors.brown.shade700),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            p.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
          ),
          Text(
            'Canto ${p.bid ?? "-"} · Hizo ${p.tricksWon}',
            style: const TextStyle(color: Colors.white70, fontSize: 10),
          ),
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.green.shade900,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${p.totalScore} pts',
              style: const TextStyle(
                color: Colors.amberAccent,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrickArea(PlayerView view) {
    if (view.currentTrick.isEmpty) {
      return const Center(
        child: Text(
          'Esperando la primera carta de la mano…',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        children: view.currentTrick.map((play) {
          final playerName = view.players.firstWhere((p) => p.id == play.playerId).name;
          return _DealtCard(
            key: ValueKey('${play.playerId}-${play.card.suit}-${play.card.rank}'),
            playerName: playerName,
            card: play.card,
          );
        }).toList(),
      ),
    );
  }Widget _buildBottomControls(BuildContext context, GameClient client, PlayerView view) {
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

    if (view.phase == 'trickEnd') {
      return _buildTrickEndControls(client, view);
    }

    return const SizedBox(height: 16);
  }

  Widget _buildTrickEndControls(GameClient client, PlayerView view) {
    final winnerName = view.players
        .firstWhere(
          (p) => p.id == view.trickWinnerId,
          orElse: () => view.currentTurnPlayer,
        )
        .name;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Se la llevó $winnerName', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          FilledButton.icon(
            icon: const Icon(Icons.thumb_up_alt_outlined),
            label: const Text('Listo'),
            onPressed: client.collectTrick,
          ),
        ],
      ),
    );
  }

  Widget _buildHandPreview(PlayerInfo you) {
    final hand = you.hand ?? [];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: SizedBox(
        height: 72,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: hand.map((card) => PlayingCardWidget(card: card, width: 48)).toList(),
        ),
      ),
    );
  }

  Widget _buildBiddingControls(GameClient client, PlayerView view, bool isYourTurn) {
    if (!isYourTurn) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Text('Esperando el canto de ${view.currentTurnPlayer.name}…'),
      );
    }

    final max = view.round.cardsPerPlayer;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 6,
        runSpacing: 4,
        children: List.generate(max + 1, (n) {
          return SizedBox(
            width: 40,
            height: 36,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
              onPressed: () => client.bid(n),
              child: Text('$n'),
            ),
          );
        }),
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

/// Una carta jugada en la mesa: cuando aparece por primera vez (nueva
/// key), hace una animación corta de "caída" — entra desde arriba con un
/// leve rebote y un fade-in. Al reconstruirse con la misma key (por otros
/// cambios de estado) no vuelve a animarse.
class _DealtCard extends StatefulWidget {
  final String playerName;
  final GameCard card;

  const _DealtCard({super.key, required this.playerName, required this.card});

  @override
  State<_DealtCard> createState() => _DealtCardState();
}

class _DealtCardState extends State<_DealtCard> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 320));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, -0.7), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.playerName, style: const TextStyle(fontSize: 12, color: Colors.white)),
            const SizedBox(height: 4),
            PlayingCardWidget(card: widget.card, width: 48),
          ],
        ),
      ),
    );
  }
}

/// Franja de chat fija en la parte de abajo de la pantalla, siempre
/// visible: historial de mensajes arriba y campo para escribir abajo.
class _ChatBar extends StatefulWidget {
  final GameClient client;

  const _ChatBar({required this.client});

  @override
  State<_ChatBar> createState() => _ChatBarState();
}

class _ChatBarState extends State<_ChatBar> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.client.sendChat(text);
    _controller.clear();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }
@override
  Widget build(BuildContext context) {
    final messages = widget.client.chatMessages;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });

    return Container(
      height: 130,
      decoration: const BoxDecoration(
        color: Color(0xFF1B1B1B),
        border: Border(top: BorderSide(color: Colors.black26)),
      ),
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              itemCount: messages.length,
              itemBuilder: (context, i) {
                final m = messages[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '${m.senderName}: ',
                          style: TextStyle(fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: m.isYou ? Colors.amberAccent : Colors.lightBlueAccent,
                          ),
                        ),
                        TextSpan(
                          text: m.text,
                          style: const TextStyle(fontSize: 12, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: 'Escribí un mensaje…',
                      hintStyle: TextStyle(color: Colors.white38),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.white),
                  onPressed: _send,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
