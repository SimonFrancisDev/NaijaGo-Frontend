import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../../constants.dart';
import '../../models/order.dart';
import '../../models/product.dart';
import '../../models/user.dart';
import '../../widgets/order_tracking_widget.dart';

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({Key? key}) : super(key: key);

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  List<Order> _orders = [];
  bool _isLoading = true;
  String _userId = '';

  Timer? _pollingTimer;
  int _pollCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchUserIdAndOrders();
    _startPolling();
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (!_isLoading) {
        await _fetchOrders();

        _pollCount++;
        if (_pollCount >= 5) {
          await _updatePendingOrdersToProcessing();
          _pollCount = 0;
        }
      }
    });
  }

  Future<void> _updatePendingOrdersToProcessing() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';

    if (token.isEmpty) {
      print('❌ No token found, cannot update pending orders.');
      return;
    }

    final url = '$baseUrl/api/orders/update-pending-to-processing';

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('📡 Pending→Processing update status: ${response.statusCode}');
      print('📄 Response: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        print('✅ Updated pending orders to processing: ${decoded['message']}');

        // 🔹 Commenting out local override to avoid stale/confusing data
        /*
        setState(() {
          _orders = _orders.map((order) {
            if (order.status.toLowerCase() == 'pending') {
              return order.copyWith(status: 'processing');
            }
            return order;
          }).toList();
        });
        */

        // 🔹 Short delay to let DB changes persist, then sync from backend
        await Future.delayed(const Duration(milliseconds: 500));
        await _fetchOrders();
      } else {
        print('❌ Failed to update pending orders.');
      }
    } catch (e) {
      print('❌ Exception updating pending orders: $e');
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchUserIdAndOrders() async {
    print('🔍 Step 1: Getting SharedPreferences...');
    final prefs = await SharedPreferences.getInstance();

    final userData = prefs.getString('user');
    print('📦 Step 2: Retrieved user data: $userData');

    if (userData != null) {
      try {
        final decodedUser = json.decode(userData);
        print('🛠 Step 3: Decoded user JSON: $decodedUser');

        final user = User.fromJson(decodedUser);
        print('👤 Step 4: User object created: ${user.toJson()}');
        print('🆔 Step 5: User ID found: ${user.id}');

        if (user.id.isEmpty) {
          print('❌ ERROR: User ID is empty! Cannot fetch orders.');
          setState(() => _isLoading = false);
          return;
        }

        setState(() {
          _userId = user.id;
        });

        await _fetchOrders();
      } catch (e) {
        print('❌ ERROR decoding user: $e');
        setState(() => _isLoading = false);
      }
    } else {
      print('⚠️ No user found in SharedPreferences.');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchOrders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';

    if (token.isEmpty) {
      print('❌ No token found, cannot fetch orders.');
      setState(() => _isLoading = false);
      return;
    }

    final url = '$baseUrl/api/orders/my';
    print('🌐 Step 6: Fetching orders from: $url');

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('📡 Step 7: Response status code: ${response.statusCode}');
      print('📄 Step 8: Raw response body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);

        if (decoded is List) {
          print('✅ Step 9: Response is a List. Orders count: ${decoded.length}');
          
          // ✨ FIX: Filter out any null items from the list before mapping
          final loadedOrders = (decoded)
              .where((item) => item != null)
              .map((data) => Order.fromJson(data as Map<String, dynamic>))
              .toList();

          // Debug print each order status
          for (var order in loadedOrders) {
            print('🔎 Order ID: ${order.id}, status: ${order.status}');
          }

          setState(() {
            _orders = loadedOrders;
            _isLoading = false;
          });
        } else if (decoded is Map && decoded.containsKey('orders')) {
          print('✅ Step 9: Response is a Map with orders key.');
          
          // ✨ FIX: Filter out any null items from the list before mapping
          final loadedOrders = (decoded['orders'] as List)
              .where((item) => item != null)
              .map((data) => Order.fromJson(data as Map<String, dynamic>))
              .toList();

          // Debug print each order status
          for (var order in loadedOrders) {
            print('🔎 Order ID: ${order.id}, status: ${order.status}');
          }

          setState(() {
            _orders = loadedOrders;
            _isLoading = false;
          });
        } else {
          print('⚠️ Step 9: Unexpected response format: $decoded');
          setState(() => _isLoading = false);
        }
      } else {
        print('❌ Step 10: Failed to load orders. Status: ${response.statusCode}');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('❌ Step 11: Exception while fetching orders: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Orders'),
        backgroundColor: color.primary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
              ? const Center(child: Text('No orders found.'))
              : ListView.builder(
                  itemCount: _orders.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final order = _orders[index];
                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Order ID: ${order.id}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: color.primary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Date: ${DateFormat('yyyy-MM-dd HH:mm').format(order.createdAt)}',
                              style: TextStyle(color: color.onSurface),
                            ),
                            // The debug status text has been removed from here.
                            const SizedBox(height: 8),
                            ...order.orderItems.map((item) {
                              final product = item.product;
                              final imageUrl = (product.imageUrls.isNotEmpty)
                                  ? product.imageUrls.first
                                  : 'https://placehold.co/50x50/CCCCCC/000000?text=No+Image';

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        imageUrl,
                                        width: 50,
                                        height: 50,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            width: 50,
                                            height: 50,
                                            color: Colors.grey[200],
                                            child: Icon(Icons.image_not_supported,
                                                size: 25, color: Colors.grey[600]),
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            product.name,
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w500,
                                              color: color.onSurface,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            'Vendor ID: ${product.vendorId.isNotEmpty ? product.vendorId : 'N/A'}',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: color.onSurface.withOpacity(0.7),
                                            ),
                                          ),
                                          Text(
                                            'Qty: ${item.quantity} x ₦${item.price.toStringAsFixed(2)}',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: color.onSurface.withOpacity(0.8),
                                            ),
                                          ),
                                          Text(
                                            'Total: ₦${(item.quantity * item.price).toStringAsFixed(2)}',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: color.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            const SizedBox(height: 10),
                            Divider(color: color.onSurface.withOpacity(0.2)),
                            const SizedBox(height: 5),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12.0),
                              child: OrderTrackingWidget(
                                key: ValueKey('${order.id}-${order.status}'), // 🔹 Fix: force rebuild on status change
                                orderStatus: order.status,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
