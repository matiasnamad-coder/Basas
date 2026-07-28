import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/game_client.dart';
import 'game_screen.dart';

class LobbyScreen extends StatelessWidget {
  const LobbyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<GameClient>(
      builder: (context, client, _) {
        // En cuanto el servidor manda el primer 'state', la partida arrancó.
        if (client.isInGame) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const GameScreen()),
            );
          });
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Sala de espera')),
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${client.lobbyPlayers.length} / ${client.maxPlayers} jugadores '
                  '(mínimo ${client.minPlayers} para arrancar)',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: client.lobbyPlayers.length,
                    itemBuilder: (context, i) {
                      final p = client.lobbyPlayers[i];
                      return ListTile(
                        leading: const Icon(Icons.person),
                        title: Text(p['name'] as String? ?? '?'),
                      );
                    },
                  ),
                ),
                if (client.errorMessage != null) ...[
                  Text(
                    client.errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 8),
                ],
                FilledButton(
                  onPressed: client.canStart ? client.startGame : null,
                  child: const Text('Arrancar partida'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
