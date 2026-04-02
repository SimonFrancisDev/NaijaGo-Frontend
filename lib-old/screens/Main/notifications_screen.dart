// lib/screens/Main/notification_screen.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants.dart'; // Import your base URL

// Defined custom colors for consistency and enchantment
const Color deepNavyBlue = Color(0xFF000080); // Deep Navy Blue - primary for backgrounds, cards
const Color greenYellow = Color(0xFFADFF2F); // Green Yellow - accent for important text, buttons
const Color whiteBackground = Colors.white; // Explicitly defining white for main backgrounds, text on navy

class NotificationsScreen extends StatefulWidget {
  final List<dynamic> notifications; // List of notifications passed from VendorScreen

  const NotificationsScreen({super.key, required this.notifications});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late List<dynamic> _displayNotifications; // Mutable list for UI updates
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _displayNotifications = List.from(widget.notifications); // Initialize with passed data
    // Sort notifications by createdAt, newest first
    _displayNotifications.sort((a, b) => DateTime.parse(b['createdAt']).compareTo(DateTime.parse(a['createdAt'])));
  }

  Future<void> _markNotificationAsRead(String notificationId) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('jwt_token');

    if (token == null) {
      setState(() {
        _errorMessage = 'Authentication token not found. Please log in again.';
        _isLoading = false;
      });
      return;
    }

    try {
      // Assuming a backend route like /api/auth/notifications/mark-read/:notificationId
      final Uri url = Uri.parse('$baseUrl/api/auth/notifications/mark-read/$notificationId');
      final response = await http.put(
        url,
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          // Find the notification and mark it as read in the local list
          final index = _displayNotifications.indexWhere((n) => n['_id'] == notificationId);
          if (index != -1) {
            _displayNotifications[index]['read'] = true;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification marked as read.')),
        );
      } else {
        final responseData = jsonDecode(response.body);
        setState(() {
          _errorMessage = responseData['message'] ?? 'Failed to mark notification as read.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred: $e';
      });
      print('Mark notification as read network error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Removed color scheme reference and using custom constants
    // final color = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: whiteBackground,
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(color: greenYellow),
        ),
        backgroundColor: deepNavyBlue,
        elevation: 1,
        iconTheme: const IconThemeData(color: greenYellow),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: deepNavyBlue))
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: deepNavyBlue, fontSize: 16),
                    ),
                  ),
                )
              : _displayNotifications.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.notifications_none, size: 80, color: deepNavyBlue.withOpacity(0.5)),
                            const SizedBox(height: 20),
                            Text(
                              'You\'re all caught up!',
                              style: TextStyle(color: deepNavyBlue, fontSize: 18, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'All your notifications will appear here.',
                              style: TextStyle(color: deepNavyBlue.withOpacity(0.7), fontSize: 16),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16.0),
                      itemCount: _displayNotifications.length,
                      itemBuilder: (context, index) {
                        final notification = _displayNotifications[index];
                        final isRead = notification['read'] ?? false;
                        final notificationType = notification['type'] ?? 'general';
                        final createdAt = DateTime.parse(notification['createdAt']);

                        IconData icon;
                        Color iconColor;
                        switch (notificationType) {
                          case 'product_sold':
                            icon = Icons.shopping_bag_outlined;
                            iconColor = greenYellow;
                            break;
                          case 'payment_received':
                            icon = Icons.payments_outlined;
                            iconColor = greenYellow;
                            break;
                          case 'wallet_deposit':
                            icon = Icons.account_balance_wallet_outlined;
                            iconColor = greenYellow;
                            break;
                          case 'wallet_withdrawal':
                            icon = Icons.send_outlined;
                            iconColor = greenYellow;
                            break;
                          case 'vendor_status_update':
                            icon = Icons.store_outlined;
                            iconColor = greenYellow;
                            break;
                          default:
                            icon = Icons.info_outline;
                            iconColor = greenYellow;
                        }

                        return Card(
                          elevation: isRead ? 2 : 6, // Unread notifications have a higher elevation
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          margin: const EdgeInsets.only(bottom: 12.0),
                          color: isRead ? deepNavyBlue.withOpacity(0.1) : deepNavyBlue, // Different colors for read/unread
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                            leading: CircleAvatar(
                              backgroundColor: greenYellow.withOpacity(0.2),
                              child: Icon(icon, color: greenYellow, size: 24),
                            ),
                            title: Text(
                              notification['message'],
                              style: TextStyle(
                                fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                color: isRead ? deepNavyBlue : whiteBackground,
                              ),
                            ),
                            subtitle: Text(
                              '${createdAt.toLocal().toIso8601String().split('T')[0]} - ${createdAt.toLocal().hour}:${createdAt.toLocal().minute}',
                              style: TextStyle(
                                color: isRead ? deepNavyBlue.withOpacity(0.7) : whiteBackground.withOpacity(0.7),
                                fontSize: 12,
                              ),
                            ),
                            trailing: isRead
                                ? const Icon(Icons.check_circle, color: greenYellow, size: 20)
                                : IconButton(
                                    icon: const Icon(Icons.mark_email_unread, color: greenYellow),
                                    onPressed: () => _markNotificationAsRead(notification['_id']),
                                  ),
                            onTap: () {
                              if (!isRead) {
                                _markNotificationAsRead(notification['_id']);
                              }
                              // Optionally, navigate to a detailed view or related item
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Notification: ${notification['message']}')),
                              );
                            },
                          ),
                        );
                      },
                    ),
    );
  }
}