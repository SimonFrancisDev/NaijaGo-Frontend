// lib/services/socket_service.dart
import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:shared_preferences/shared_preferences.dart';

class SocketService {
  IO.Socket? socket;

  Future<void> connect(String baseUrl) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';

    socket = IO.io(baseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'auth': {'token': token},
      'forceNew': true,
    });

    socket!.connect();

    socket!.onConnect((_) {
      print('Socket connected');
    });

    socket!.onDisconnect((_) {
      print('Socket disconnected');
    });

    socket!.onConnectError((err) {
      print('Socket connect error: $err');
    });
  }

  void joinDispute(String disputeId) {
    socket?.emit('joinDispute', disputeId);
  }

  void leaveDispute(String disputeId) {
    socket?.emit('leaveDispute', disputeId);
  }

  void sendMessage(String disputeId, String text, List<String> attachments) {
    socket?.emit('sendMessage', {
      'disputeId': disputeId,
      'text': text,
      'attachments': attachments,
    });
  }

  void onMessage(void Function(dynamic) cb) {
    socket?.on('message', cb);
  }

  void dispose() {
    socket?.disconnect();
    socket = null;
  }
}
