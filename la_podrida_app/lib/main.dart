import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/connect_screen.dart';
import 'services/game_client.dart';

void main() {
  runApp(const LaPodridaApp());
}

class LaPodridaApp extends StatelessWidget {
  const LaPodridaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => GameClient(),
      child: MaterialApp(
        title: 'Las Basas',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: Colors.green,
          useMaterial3: true,
        ),
        home: const ConnectScreen(),
      ),
    );
  }
}
