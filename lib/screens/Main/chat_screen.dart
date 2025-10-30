// chat_screen.dart (FIXED)
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// You will need to manage the user's JWT token for socket auth.
// Placeholder for fetching the token.
// In a real app, this would come from a secure state management or auth service.
Future<String?> _getAuthToken() async {
  try {
    // 1. Get the SharedPreferences instance
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    
    // 2. Retrieve the token stored under the key 'jwt_token'
    final String? token = prefs.getString('jwt_token');
    
    // 3. Return the token (will be null if not found)
    return token;
  } catch (e) {
    // Handle any potential errors during retrieval
    print('Error retrieving JWT token from SharedPreferences: $e');
    return null;
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];

  // State variables for chat flow
  String? _sessionId;
  bool _isAssignedToPharmacist = false;
  String? _pharmacistName; 
  bool _isTyping = false;
  
  // Pharmacist presence status
  bool _globalPharmacistOnline = false;

  late IO.Socket _socket;
  final String _apiUrl = 'https://naijago-backend.onrender.com';

  @override
  void initState() {
    super.initState();
    _startChatSessionAndConnect();
  }

  // --- Session Management ---

  Future<void> _startChatSessionAndConnect() async {
    final token = await _getAuthToken();
    if (token == null) {
      // Handle missing token, e.g., show error or navigate to login
      _addSystemMessage('Authentication failed. Please log in again.');
      return;
    }
    
    // 1. Get or create a Chat Session ID via HTTP
    final sessionUri = Uri.parse('$_apiUrl/api/chat/start');
    try {
      final res = await http.post(
        sessionUri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body);
        _sessionId = data['_id'];
        _isAssignedToPharmacist = data['pharmacist'] != null;
        
        // 2. Connect the Socket
        _connectSocket(token);
        
      } else {
        _addSystemMessage('Failed to start chat session. Status: ${res.statusCode}');
      }
    } catch (e) {
      _addSystemMessage('Network error: Could not connect to chat service.');
    }
  }

  // --- Socket Connection ---
  
  void _connectSocket(String token) {
    _socket = IO.io(
      _apiUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token}) // Pass JWT for authentication
          .build(),
    );

    _socket.connect();

    _socket.onConnect((_) {
      print('Connected to chat socket. Joining session: $_sessionId');
      // 3. Join the specific chat room and request history
      // 🔑 FIX 2: Changed emit with callback to emitWithAck
      _socket.emitWithAck('join_chat', {'sessionId': _sessionId}, ack: (response) {
        // response is a List, typically [data] or [error, data]
        final Map<String, dynamic> data = response.isNotEmpty ? response[0] : {};

        if (data['success'] == true) {
          final List<dynamic> messages = data['messages'] ?? [];
          final session = data['session'] ?? {};
          
          setState(() {
            _isAssignedToPharmacist = session['pharmacist'] != null;
            
            // Add historical messages
            _messages.clear(); 
            for (var msg in messages) {
              _messages.add(_formatSocketMessage(msg));
            }
          });
          _scrollToBottom();
          _addSystemMessage(_isAssignedToPharmacist 
            ? 'Chat history loaded. You are chatting with a pharmacist.'
            : 'Chat history loaded. The AI is currently assisting you.'
          );
        } else {
          _addSystemMessage('Failed to join chat room: ${data['error'] ?? 'Unknown error'}');
        }
      });
    });

    // Global pharmacist online status (for showing app bar title)
    _socket.on('pharmacistStatus', (data) {
      setState(() => _globalPharmacistOnline = data['online'] ?? false);
    });

    // Handle new incoming messages (from user, AI, pharmacist, or system)
    _socket.on('new_message', (data) {
      setState(() {
        _isTyping = false; // Stop typing indicator for any incoming message
        _messages.add(_formatSocketMessage(data));
      });
      _scrollToBottom();
    });
    
    // Handle pharmacist joining event (stops AI response)
    _socket.on('pharmacist_joined', (data) {
      final String name = data['name'] ?? 'A certified pharmacist';
      setState(() {
        _isAssignedToPharmacist = true;
        _pharmacistName = name;
        _isTyping = false; // AI stops automatically
      });
      // The system message is already sent from the server via 'new_message'
    });
    
    _socket.onDisconnect((_) => print('Disconnected from chat socket'));
    _socket.onError((err) => print('Socket error: $err'));
  }

  // --- Message Handling ---

  Map<String, dynamic> _formatSocketMessage(Map<String, dynamic> data) {
    String sender = 'user';
    if (data['senderType'] == 'pharmacist') {
      sender = 'pharmacist';
    } else if (data['senderType'] == 'ai') {
      sender = 'ai';
    } else if (data['senderType'] == 'system') {
      sender = 'system';
    }
    
    return {
      'from': sender,
      'text': data['text'],
      'id': data['id'],
      'createdAt': data['createdAt'],
    };
  }
  
  void _addSystemMessage(String text) {
    setState(() {
      _messages.add({
        'from': 'system',
        'text': text,
        'id': 'local-sys-${DateTime.now().millisecondsSinceEpoch}',
      });
    });
    _scrollToBottom();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sessionId == null) return;

    // 1. Show user message instantly
    setState(() {
      _messages.add({'from': 'user', 'text': text});
      _controller.clear();
      // Show typing indicator if waiting for AI/Pharmacist (i.e., not yet assigned)
      if (!_isAssignedToPharmacist) {
        _isTyping = true;
      }
    });
    _scrollToBottom();

    // 2. Send message via socket
    // 🔑 FIX 2: Changed emit with callback to emitWithAck
    _socket.emitWithAck('send_chat_message', {
      'sessionId': _sessionId, 
      'text': text
    }, ack: (response) {
      // response is a List, typically [data] or [error, data]
      final Map<String, dynamic> data = response.isNotEmpty ? response[0] : {};

      // 3. Handle response callback (optional but useful for confirmation/errors)
      if (data['success'] != true) {
        print('Message failed to send via socket: ${data['error'] ?? 'Unknown error'}');
        // Optional: show local error message to user
        setState(() {
          _isTyping = false;
        });
      }
      
      // If AI replied immediately, the 'new_message' event will handle the UI update.
      // If waiting for pharmacist, the 'system' message event will handle the UI update.
    });
  }
  
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // --- UI Building (Omitted for brevity, but remains the same as your provided code) ---
  Widget _buildBubble(Map<String, dynamic> msg) {
    bool isUser = msg['from'] == 'user';
    bool isPharmacist = msg['from'] == 'pharmacist';
    bool isAI = msg['from'] == 'ai';
    bool isSystem = msg['from'] == 'system'; // New type

    Color navyBlue = const Color(0xFF001F3F);
    Color white = Colors.white;

    if (isSystem) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.blueGrey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blueGrey[100]!),
          ),
          child: Text(
            msg['text'],
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.blueGrey[700], fontSize: 13, fontStyle: FontStyle.italic),
          ),
        ),
      );
    }

    Color bubbleColor = isUser
        ? navyBlue
        : isPharmacist
            ? Colors.green[100]! // Distinct color for human pharmacist
            : Colors.grey[200]!; // Color for AI/Bot

    Color textColor = isUser ? white : Colors.black87;

    String senderLabel = isPharmacist ? 'Pharmacist' : isAI ? 'AI' : '';
    
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (senderLabel.isNotEmpty && !isUser)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 10, right: 10, bottom: 2),
              child: Text(
                senderLabel,
                style: TextStyle(
                  fontSize: 12,
                  color: isPharmacist ? Colors.green[700] : Colors.grey[600],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 10),
            padding: const EdgeInsets.all(12),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(14),
                topRight: const Radius.circular(14),
                bottomLeft: Radius.circular(isUser ? 14 : 0),
                bottomRight: Radius.circular(isUser ? 0 : 14),
              ),
            ),
            child: Text(
              msg['text'],
              style: TextStyle(
                color: textColor,
                fontSize: 15,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  @override
  void dispose() {
    _scrollController.dispose();
    _socket.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final navyBlue = const Color(0xFF001F3F);
    
    // Determine the title based on who is handling the chat
    String titleText;
    if (_isAssignedToPharmacist) {
      titleText = _pharmacistName != null ? 'Chat with $_pharmacistName 👩🏽‍⚕️' : 'Pharmacist Joined 👩🏽‍⚕️';
    } else if (_globalPharmacistOnline) {
      titleText = "Waiting for Pharmacist ⏳";
    } else {
      titleText = "AI Assistant 🤖";
    }


    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: navyBlue,
        title: Text(
          titleText,
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, i) {
                if (_isTyping && i == _messages.length) {
                  return Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.blueGrey,
                          ),
                        ),
                        SizedBox(width: 10),
                        Text(
                          _isAssignedToPharmacist ? "Pharmacist is typing..." : "AI is thinking...",
                          style: TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                  );
                }
                return _buildBubble(_messages[i]);
              },
            ),
          ),
          
          // Floating warning
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0, left: 16, right: 16),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                "⚠️ Please do not share personal or sensitive information here.",
                style: TextStyle(color: Colors.white, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
          ),

          // Modern input area
          SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              color: Colors.transparent,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _controller,
                        maxLines: null,
                        decoration: const InputDecoration(
                          isDense: true,
                          hintText: 'Type a message...',
                          hintStyle:
                              TextStyle(color: Colors.grey, fontSize: 15),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: navyBlue,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: navyBlue.withOpacity(0.4),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.send, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}



// import 'package:flutter/material.dart';
// import 'package:socket_io_client/socket_io_client.dart' as IO;
// import 'package:http/http.dart' as http;
// import 'dart:convert';

// class ChatScreen extends StatefulWidget {
//   const ChatScreen({super.key});

//   @override
//   State<ChatScreen> createState() => _ChatScreenState();
// }

// class _ChatScreenState extends State<ChatScreen> {
//   final TextEditingController _controller = TextEditingController();
//   final List<Map<String, dynamic>> _messages = [];
//   bool _pharmacistOnline = false;
//   bool _isTyping = false;
//   late IO.Socket _socket;

//   @override
//   void initState() {
//     super.initState();
//     _connectSocket();
//   }

//   void _connectSocket() {
//     _socket = IO.io(
//       'https://naijago-backend.onrender.com',
//       IO.OptionBuilder()
//           .setTransports(['websocket'])
//           .disableAutoConnect()
//           .build(),
//     );

//     _socket.connect();

//     _socket.onConnect((_) => print('Connected to chat socket'));
//     _socket.on('pharmacistStatus', (data) {
//       setState(() => _pharmacistOnline = data['online']);
//     });

//     _socket.on('message', (data) {
//       setState(() {
//         _messages.add({
//           'from': data['sender'] == 'pharmacist'
//               ? 'pharmacist'
//               : data['sender'] == 'ai'
//                   ? 'ai'
//                   : 'user',
//           'text': data['text'],
//         });
//       });
//     });
//   }

//   Future<void> _sendMessage() async {
//     final text = _controller.text.trim();
//     if (text.isEmpty) return;

//     setState(() {
//       _messages.add({'from': 'user', 'text': text});
//       _controller.clear();
//     });

//     if (_pharmacistOnline) {
//       _socket.emit('sendMessage', {'text': text});
//     } else {
//       setState(() => _isTyping = true);
//       try {
//         final res = await http.post(
//           Uri.parse('https://naijago-backend.onrender.com/api/chatbot'),
//           headers: {'Content-Type': 'application/json'},
//           body: jsonEncode({'message': text}),
//         );
//         if (res.statusCode == 200) {
//           final data = jsonDecode(res.body);
//           setState(() {
//             _messages.add({'from': 'ai', 'text': data['reply']});
//           });
//         } else {
//           setState(() {
//             _messages.add({
//               'from': 'ai',
//               'text': "Sorry, I couldn’t get a response. Try again later."
//             });
//           });
//         }
//       } catch (e) {
//         setState(() {
//           _messages.add({
//             'from': 'ai',
//             'text': "Network error. Please check your connection."
//           });
//         });
//       } finally {
//         setState(() => _isTyping = false);
//       }
//     }
//   }

//   Widget _buildBubble(Map<String, dynamic> msg) {
//     bool isUser = msg['from'] == 'user';
//     bool isPharmacist = msg['from'] == 'pharmacist';
//     bool isAI = msg['from'] == 'ai';

//     Color navyBlue = const Color(0xFF001F3F);
//     Color white = Colors.white;

//     Color bubbleColor = isUser
//         ? navyBlue
//         : isPharmacist
//             ? Colors.blue[100]!
//             : Colors.grey[200]!;

//     Color textColor = isUser ? white : Colors.black87;

//     return Align(
//       alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
//       child: Container(
//         margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
//         padding: const EdgeInsets.all(12),
//         decoration: BoxDecoration(
//           color: bubbleColor,
//           borderRadius: BorderRadius.only(
//             topLeft: const Radius.circular(14),
//             topRight: const Radius.circular(14),
//             bottomLeft: Radius.circular(isUser ? 14 : 0),
//             bottomRight: Radius.circular(isUser ? 0 : 14),
//           ),
//         ),
//         child: Text(
//           msg['text'],
//           style: TextStyle(
//             color: textColor,
//             fontSize: 15,
//             height: 1.3,
//           ),
//         ),
//       ),
//     );
//   }

//   @override
//   void dispose() {
//     _socket.disconnect();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final navyBlue = const Color(0xFF001F3F);

//     return Scaffold(
//       backgroundColor: Colors.grey[50],
//       appBar: AppBar(
//         backgroundColor: navyBlue,
//         title: Text(
//           _pharmacistOnline ? "Pharmacist Chat 👩🏽‍⚕️" : "AI Assistant 🤖",
//           style: const TextStyle(color: Colors.white),
//         ),
//         centerTitle: true,
//       ),
//       body: Stack(
//         children: [
//           Column(
//             children: [
//               Expanded(
//                 child: ListView.builder(
//                   itemCount: _messages.length + (_isTyping ? 1 : 0),
//                   itemBuilder: (context, i) {
//                     if (_isTyping && i == _messages.length) {
//                       return Padding(
//                         padding:
//                             const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
//                         child: Row(
//                           children: const [
//                             SizedBox(
//                               width: 15,
//                               height: 15,
//                               child: CircularProgressIndicator(strokeWidth: 2),
//                             ),
//                             SizedBox(width: 10),
//                             Text(
//                               "AI is thinking...",
//                               style: TextStyle(color: Colors.black54),
//                             ),
//                           ],
//                         ),
//                       );
//                     }
//                     return _buildBubble(_messages[i]);
//                   },
//                 ),
//               ),
//               // ✨ Modern input area
//               SafeArea(
//                 child: Container(
//                   padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
//                   color: Colors.transparent,
//                   child: Row(
//                     crossAxisAlignment: CrossAxisAlignment.end,
//                     children: [
//                       Expanded(
//                         child: Container(
//                           padding: const EdgeInsets.symmetric(
//                               horizontal: 14, vertical: 10),
//                           decoration: BoxDecoration(
//                             color: Colors.white,
//                             borderRadius: BorderRadius.circular(25),
//                             boxShadow: [
//                               BoxShadow(
//                                 color: Colors.grey.withOpacity(0.3),
//                                 blurRadius: 6,
//                                 offset: const Offset(0, 2),
//                               ),
//                             ],
//                           ),
//                           child: TextField(
//                             controller: _controller,
//                             maxLines: null,
//                             decoration: const InputDecoration(
//                               isDense: true,
//                               hintText: 'Type a message...',
//                               hintStyle:
//                                   TextStyle(color: Colors.grey, fontSize: 15),
//                               border: InputBorder.none,
//                             ),
//                           ),
//                         ),
//                       ),
//                       const SizedBox(width: 8),
//                       GestureDetector(
//                         onTap: _sendMessage,
//                         child: Container(
//                           padding: const EdgeInsets.all(12),
//                           decoration: BoxDecoration(
//                             color: navyBlue,
//                             shape: BoxShape.circle,
//                             boxShadow: [
//                               BoxShadow(
//                                 color: navyBlue.withOpacity(0.4),
//                                 blurRadius: 6,
//                                 offset: const Offset(0, 3),
//                               ),
//                             ],
//                           ),
//                           child: const Icon(Icons.send, color: Colors.white, size: 20),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ],
//           ),
//           // Floating warning
//           Positioned(
//             bottom: 80,
//             left: 16,
//             right: 16,
//             child: Container(
//               padding:
//                   const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
//               decoration: BoxDecoration(
//                 color: Colors.red.withOpacity(0.9),
//                 borderRadius: BorderRadius.circular(10),
//               ),
//               child: const Text(
//                 "⚠️ Please do not share personal or sensitive information here.",
//                 style: TextStyle(color: Colors.white, fontSize: 13),
//                 textAlign: TextAlign.center,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }