import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/game_client.dart';
import 'lobby_screen.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  final _serverController = TextEditingController(text: 'ws://localhost:2567');
  final _nameController = TextEditingController();
  bool _connecting = false;

  @override
  void initState() {
    super.initState();
    _tryResume();
  }

  Future<void> _tryResume() async {
    final client = context.read<GameClient>();
    final resumed = await client.tryResumeSavedSession();
    if (resumed && mounted) {
      _goToLobby();
    }
  }

  void _goToLobby() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LobbyScreen()),
    );
  }

  Future<void> _connect() async {
    final url = _serverController.text.trim();
    final name = _nameController.text.trim();
    if (url.isEmpty || name.isEmpty) return;

    setState(() => _connecting = true);
    await context.read<GameClient>().connectAndJoin(url, name);
    if (mounted) _goToLobby();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Las Basas')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Conectate a una partida',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _serverController,
                  decoration: const InputDecoration(
                    labelText: 'Servidor (ws://...)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Tu nombre',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _connecting ? null : _connect,
                  child: _connecting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Entrar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
