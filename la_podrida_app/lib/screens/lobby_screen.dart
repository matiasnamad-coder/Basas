import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/game_client.dart';
import 'game_screen.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  int? _targetTotal;

  @override
  Widget build(BuildContext context) {
    return Consumer<GameClient>(
      builder: (context, client, _) {
        if (client.isInGame) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const GameScreen()),
            );
          });
        }

        final currentPlayers = client.lobbyPlayers.length;
        final minTotal = currentPlayers < client.minPlayers ? client.minPlayers : currentPlayers;
        _targetTotal ??= minTotal;
        if (_targetTotal! < minTotal) _targetTotal = minTotal;
        if (_targetTotal! > client.maxPlayers) _targetTotal = client.maxPlayers;

        final canAddComputers = currentPlayers < client.maxPlayers && _targetTotal! > currentPlayers;

        return Scaffold(
          appBar: AppBar(title: const Text('Sala de espera')),
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '$currentPlayers / ${client.maxPlayers} jugadores '
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
                Row(
                  children: [
                    const Text('Completar con computadoras hasta:'),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: _targetTotal! > minTotal
                          ? () => setState(() => _targetTotal = _targetTotal! - 1)
                          : null,
                    ),
                    Text('$_targetTotal', style: const TextStyle(fontSize: 18)),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: _targetTotal! < client.maxPlayers
                          ? () => setState(() => _targetTotal = _targetTotal! + 1)
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.computer),
                  label: const Text('Agregar computadoras'),
                  onPressed: canAddComputers
                      ? () => client.addComputers(_targetTotal!)
                      : null,
                ),
                const SizedBox(height: 16),
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
