// pharmacist_dashboard.dart (Example for Pharmacist Role)
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:convert';
import 'package:intl/intl.dart'; // Add to pubspec.yaml if needed for formatting
import 'package:shared_preferences/shared_preferences.dart';


// Define your requested colors
const Color deepNavyBlue = Color(0xFF03024C); // Primary App Color
const Color white = Colors.white;             // Secondary App Color

// Placeholder for fetching the PHARMACIST's token.
// IMPORTANT: This MUST be a JWT for a user with the role: 'pharmacist'.
Future<String?> _getPharmacistAuthToken() async {
  try {
    // 1. Get the SharedPreferences instance
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    
    // 2. Retrieve the token stored under the key 'jwt_token'
    // This key holds the token regardless of if it's a regular user or a pharmacist token.
    final String? token = prefs.getString('jwt_token');
    
    // 3. Return the token
    return token;
  } catch (e) {
    print('Error retrieving Pharmacist JWT token from SharedPreferences: $e');
    return null;
  }
}

class PharmacistDashboard extends StatefulWidget {
  const PharmacistDashboard({super.key});

  @override
  State<PharmacistDashboard> createState() => _PharmacistDashboardState();
}

class _PharmacistDashboardState extends State<PharmacistDashboard> {
  late IO.Socket _socket;
  final String _apiUrl = 'https://naijago-backend.onrender.com';
  
  // List to hold incoming chat requests
  final List<Map<String, dynamic>> _incomingRequests = [];
  bool _isOnline = false;

  @override
  void initState() {
    super.initState();
    _connectSocket();
  }

  void _connectSocket() async {
    final token = await _getPharmacistAuthToken();
    if (token == null) {
      print('Pharmacist Auth Failed.');
      return;
    }

    _socket = IO.io(
      _apiUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );

    _socket.connect();

    _socket.onConnect((_) {
      print('Pharmacist Connected and Available.');
      setState(() => _isOnline = true);
      
      // Optionally, broadcast initial availability (though server does this on connection)
    });
    
    // --- 1. Listen for new chat requests ---
    _socket.on('incoming_chat_request', (data) {
      final String sessionId = data['sessionId'];
      
      // Prevent duplicates by checking if the session is already in the queue
      if (_incomingRequests.any((req) => req['sessionId'] == sessionId)) return;

      setState(() {
        _incomingRequests.add({
          'sessionId': sessionId,
          'userId': data['userId'],
          'textPreview': data['textPreview'] ?? 'No preview.',
          'createdAt': data['createdAt'] != null ? DateTime.parse(data['createdAt']) : DateTime.now(),
        });
      });
      
      _showNotification('New Chat Request!', data['textPreview']);
    });

    _socket.onDisconnect((_) {
      print('Pharmacist Disconnected.');
      setState(() => _isOnline = false);
    });
    _socket.onError((err) => print('Pharmacist Socket error: $err'));
  }

  // --- 2. Claim the chat session ---
  void _claimSession(String sessionId) {
    if (!_isOnline) {
      _showNotification('Error', 'You must be online to claim a session.');
      return;
    }
    
    // Use emitWithAck to ensure the claim request is processed by the server
    _socket.emitWithAck('pharmacist_claim_session', {'sessionId': sessionId}, ack: (response) {
      final Map<String, dynamic> data = response.isNotEmpty ? response[0] : {};

      if (data['success'] == true) {
        setState(() {
          // Remove from the queue immediately
          _incomingRequests.removeWhere((req) => req['sessionId'] == sessionId);
        });
        
        // 3. Navigate to the chat screen (same screen as user, but with pharmacist view logic)
        // For simplicity, we just show a message here. In a real app, you'd navigate.
        _showNotification('Claim Successful!', 'You are now assigned to session $sessionId.');
        
        // **REAL-WORLD STEP:** Navigator.push(context, MaterialPageRoute(builder: (_) => PharmacistChatScreen(sessionId: sessionId)));

      } else {
        _showNotification('Claim Failed', data['message'] ?? 'This session might be claimed by another pharmacist.');
        
        // If the claim failed because it was already claimed, remove it from the queue
        if (data['message']?.contains('already claimed') ?? false) {
           setState(() => _incomingRequests.removeWhere((req) => req['sessionId'] == sessionId));
        }
      }
    });
  }

  void _showNotification(String title, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$title: $message'),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  void dispose() {
    _socket.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pharmacist Queue 🧑‍⚕️'),
        backgroundColor: deepNavyBlue,
        actions: [
          IconButton(
            icon: Icon(_isOnline ? Icons.signal_cellular_alt : Icons.signal_cellular_off, 
                      color: _isOnline ? Colors.greenAccent : Colors.redAccent),
            onPressed: () {
              // Toggle availability feature could be implemented here
              _showNotification('Status', _isOnline ? 'Online' : 'Offline');
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Status: ${_isOnline ? 'Online' : 'Offline (Disconnected)'}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _isOnline ? Colors.green[700] : Colors.red[700],
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(left: 16.0, bottom: 8.0),
            child: Text(
              'Pending Chat Requests:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: _incomingRequests.isEmpty
                ? const Center(child: Text('No active chat requests.', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    itemCount: _incomingRequests.length,
                    itemBuilder: (context, index) {
                      final request = _incomingRequests[index];
                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        child: ListTile(
                          leading: const Icon(Icons.person, color: Colors.blueGrey),
                          title: Text('User ID: ${request['userId'].substring(0, 8)}...'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Message: "${request['textPreview']}"'),
                              Text(
                                'Received: ${DateFormat('h:mm a, MMM d').format(request['createdAt'])}',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                          trailing: ElevatedButton(
                            onPressed: () => _claimSession(request['sessionId']),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                            child: const Text('Claim Chat', style: TextStyle(color: Colors.white)),
                          ),
                          onTap: () => _showNotification('Request Details', request['textPreview']),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}