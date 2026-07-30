import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/card.dart';
import '../models/game_view.dart';

enum ConnectionStatus { disconnected, connecting, connected, reconnecting }

/// Encapsula toda la comunicación con el servidor (ver el protocolo en
/// la_podrida_server/src/server/protocol.ts). Guarda sessionId/roomId en
/// el dispositivo para poder reconectar si se corta la conexión.
class GameClient extends ChangeNotifier {
  WebSocketChannel? _channel;
  String? _serverUrl;
  String? _playerName;
  String? _sessionId;
  String? _roomId;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;

  ConnectionStatus status = ConnectionStatus.disconnected;
  String? errorMessage;

  List<Map<String, dynamic>> lobbyPlayers = [];
  int minPlayers = 4;
  int maxPlayers = 8;
  bool canStart = false;

  Map<String, dynamic>? dealerDraw;

  PlayerView? view;
  Map<String, dynamic>? roundEndedInfo;
  Map<String, dynamic>? gameEndedInfo;

  bool get isInGame => view != null;

  Future<void> connectAndJoin(String serverUrl, String playerName) async {
    _serverUrl = serverUrl;
    _playerName = playerName;
    _reconnectAttempts = 0;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('serverUrl', serverUrl);
    await prefs.setString('playerName', playerName);

    await _openSocket(onOpen: () => _send('join', {'name': playerName}));
  }

  Future<bool> tryResumeSavedSession() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString('serverUrl');
    final sessionId = prefs.getString('sessionId');
    final roomId = prefs.getString('roomId');
    if (url == null || sessionId == null || roomId == null) return false;

    _serverUrl = url;
    _sessionId = sessionId;
    _roomId = roomId;

    await _openSocket(onOpen: () => _send('reconnect', {'sessionId': sessionId, 'roomId': roomId}));
    return true;
  }

  Future<void> _openSocket({required VoidCallback onOpen}) async {
    _reconnectTimer?.cancel();
    status = ConnectionStatus.connecting;
    notifyListeners();

    try {
      final channel = WebSocketChannel.connect(Uri.parse(_serverUrl!));
      _channel = channel;
      await channel.ready;

      status = ConnectionStatus.connected;
      _reconnectAttempts = 0;
      notifyListeners();
      onOpen();

      channel.stream.listen(
        _handleRawMessage,
        onDone: _handleDisconnect,
        onError: (_) => _handleDisconnect(),
      );
    } catch (_) {
      _handleDisconnect();
    }
  }

  void _handleDisconnect() {
    _channel = null;

    if (isInGame && _sessionId != null && _roomId != null) {
      status = ConnectionStatus.reconnecting;
      notifyListeners();
      _scheduleReconnect();
    } else {
      status = ConnectionStatus.disconnected;
      notifyListeners();
    }
  }

  void _scheduleReconnect() {
    _reconnectAttempts++;
    final delaySeconds = _reconnectAttempts <= 5 ? 2 : 5;
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () async {
      if (_sessionId == null || _roomId == null || _serverUrl == null) return;
      await _openSocket(
        onOpen: () => _send('reconnect', {'sessionId': _sessionId, 'roomId': _roomId}),
      );
    });
  }

  void _handleRawMessage(dynamic raw) {
    late Map<String, dynamic> msg;
    try {
      msg = jsonDecode(raw as String) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    final type = msg['type'] as String?;
    final payload = msg['payload'] as Map<String, dynamic>?;

    switch (type) {
      case 'welcome':
        _sessionId = payload?['sessionId'] as String?;
        _roomId = payload?['roomId'] as String?;
        _persistSession();
        break;
      case 'lobby':
        lobbyPlayers = (payload?['players'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
        minPlayers = payload?['minPlayers'] as int? ?? 4;
        maxPlayers = payload?['maxPlayers'] as int? ?? 8;
        canStart = payload?['canStart'] as bool? ?? false;
        break;
      case 'dealer-draw':
        dealerDraw = payload;
        break;
      case 'state':
        view = PlayerView.fromJson(payload!);
        roundEndedInfo = null;
        break;
      case 'round-ended':
        roundEndedInfo = payload;
        break;
      case 'game-ended':
        gameEndedInfo = payload;
        break;
      case 'error':
        errorMessage = payload?['message'] as String?;
        break;
      case 'player-reconnecting':
      case 'player-reconnected':
      case 'player-absent':
        break;
    }

    notifyListeners();
  }

  Future<void> _persistSession() async {
    final prefs = await SharedPreferences.getInstance();
    if (_sessionId != null) await prefs.setString('sessionId', _sessionId!);
    if (_roomId != null) await prefs.setString('roomId', _roomId!);
  }

  void clearError() {
    errorMessage = null;
    notifyListeners();
  }

  void startGame() => _send('start-game');

  void addComputers(int targetTotal) => _send('add-computers', {'targetTotal': targetTotal});

  void collectTrick() => _send('collect-trick');

  void bid(int value) => _send('bid', {'value': value});

  void playCard(GameCard card) => _send('play-card', {'card': card.toJson()});

  void advanceRound() => _send('advance-round');

  void _send(String type, [Map<String, dynamic>? payload]) {
    _channel?.sink.add(jsonEncode({'type': type, if (payload != null) 'payload': payload}));
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    super.dispose();
  }
}
