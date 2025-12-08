// my_orders_screen.dart
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
      if (kDebugMode) {
        print('❌ No token found, cannot update pending orders.');
      }
      return;
    }

    // NOTE: This endpoint name implies it handles old "pending" status. 
    // Ensure your backend now looks for 'pending_payment' in its logic.
    final url = '$baseUrl/api/orders/update-pending-to-processing';

    try {
        // ⚠️ FIX 1: Set loading state before API call
        if (mounted) {
            setState(() { _isLoading = true; }); 
        }

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (kDebugMode) {
          print('✅ Updated pending orders to processing: ${decoded['message']}');
        }

        // 🔹 Short delay to let DB changes persist, then sync from backend
        await Future.delayed(const Duration(milliseconds: 500));
        await _fetchOrders();
      } else {
        if (kDebugMode) {
          print('❌ Failed to update pending orders. Status: ${response.statusCode}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Exception updating pending orders: $e');
      }
    } finally {
        // ⚠️ FIX 2: Ensure loading state is reset even on failure
        if (mounted) {
            setState(() {
                _isLoading = false;
            });
        }
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchUserIdAndOrders() async {
    final prefs = await SharedPreferences.getInstance();

    final userData = prefs.getString('user');

    if (userData != null) {
      try {
        final decodedUser = json.decode(userData);

        final user = User.fromJson(decodedUser);

        if (user.id.isEmpty) {
          if (kDebugMode) {
            print('❌ ERROR: User ID is empty! Cannot fetch orders.');
          }
          setState(() => _isLoading = false);
          return;
        }

        setState(() {
          _userId = user.id;
        });

        await _fetchOrders();
      } catch (e) {
        if (kDebugMode) {
          print('❌ ERROR decoding user: $e');
        }
        setState(() => _isLoading = false);
      }
    } else {
      if (kDebugMode) {
        print('⚠️ No user found in SharedPreferences.');
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchOrders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';

    if (token.isEmpty) {
      if (kDebugMode) {
        print('❌ No token found, cannot fetch orders.');
      }
      setState(() => _isLoading = false);
      return;
    }

    final url = '$baseUrl/api/orders/my';
    if (kDebugMode) {
      print('🌐 Fetching orders from: $url');
    }

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);

        List<dynamic> orderList = [];
        if (decoded is List) {
          orderList = decoded;
        } else if (decoded is Map && decoded.containsKey('orders')) {
          orderList = decoded['orders'] as List;
        } else {
          if (kDebugMode) {
            print('⚠️ Unexpected response format: $decoded');
          }
          setState(() => _isLoading = false);
          return;
        }

        // Filter out any null items from the list before mapping
        final loadedOrders = (orderList)
            .where((item) => item != null)
            .map((data) => Order.fromJson(data as Map<String, dynamic>))
            .toList();

        // Debug print each order status
        if (kDebugMode) {
          for (var order in loadedOrders) {
            print('🔎 Order ID: ${order.id}, status: ${order.status}, Total: ₦${order.totalPrice.toStringAsFixed(2)}');
          }
        }

        setState(() {
          _orders = loadedOrders;
          _isLoading = false;
        });

      } else {
        if (kDebugMode) {
          print('❌ Failed to load orders. Status: ${response.statusCode}');
        }
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Exception while fetching orders: $e');
      }
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
                    
                    // Logic to handle nullable paidAt
                    final orderDateText = order.paidAt != null
                      ? DateFormat('yyyy-MM-dd HH:mm').format(order.paidAt!) // Use ! to assert non-null after check
                      : 'Pending Payment/N/A';
                      
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Order ID: ${order.id.substring(0, 8)}...', // Shorten ID for display
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: color.primary,
                                  ),
                                ),
                                Text(
                                  'Total: ₦${order.totalPrice.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: color.error, // Use a distinguishing color for total
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // CORRECTED: Safely access and format the nullable paidAt field
                            Text(
                              'Date: $orderDateText',
                              style: TextStyle(color: color.onSurface),
                            ),
                            const SizedBox(height: 8),
                            ...order.orderItems.map((item) {
                              // FIX CONFIRMED: item is now a strongly-typed OrderItem object, 
                              // which safely contains the 'product' field.
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
                                            'Vendor ID: ${product.vendorId.isNotEmpty ? product.vendorId.substring(0, 8) : 'N/A'}...',
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
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '₦${(item.quantity * item.price).toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: color.primary,
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
                                key: ValueKey('${order.id}-${order.status}'),
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



// //my_orders_screen.dart
// import 'package:flutter/material.dart';
// import 'package:flutter/foundation.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';
// import 'dart:async';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:intl/intl.dart';
// import '../../constants.dart';
// import '../../models/order.dart';
// import '../../models/product.dart';
// import '../../models/user.dart';
// import '../../widgets/order_tracking_widget.dart';

// class MyOrdersScreen extends StatefulWidget {
//   const MyOrdersScreen({Key? key}) : super(key: key);

//   @override
//   State<MyOrdersScreen> createState() => _MyOrdersScreenState();
// }

// class _MyOrdersScreenState extends State<MyOrdersScreen> {
//   List<Order> _orders = [];
//   bool _isLoading = true;
//   String _userId = '';

//   Timer? _pollingTimer;
//   int _pollCount = 0;

//   @override
//   void initState() {
//     super.initState();
//     _fetchUserIdAndOrders();
//     _startPolling();
//   }

//   void _startPolling() {
//     _pollingTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
//       if (!_isLoading) {
//         await _fetchOrders();

//         _pollCount++;
//         if (_pollCount >= 5) {
//           await _updatePendingOrdersToProcessing();
//           _pollCount = 0;
//         }
//       }
//     });
//   }

//   Future<void> _updatePendingOrdersToProcessing() async {
//     final prefs = await SharedPreferences.getInstance();
//     final token = prefs.getString('jwt_token') ?? '';

//     if (token.isEmpty) {
//       if (kDebugMode) {
//         print('❌ No token found, cannot update pending orders.');
//       }
//       return;
//     }

//     final url = '$baseUrl/api/orders/update-pending-to-processing';

//     try {
//       final response = await http.post(
//         Uri.parse(url),
//         headers: {
//           'Content-Type': 'application/json',
//           'Authorization': 'Bearer $token',
//         },
//       );

//       if (response.statusCode == 200) {
//         final decoded = json.decode(response.body);
//         if (kDebugMode) {
//           print('✅ Updated pending orders to processing: ${decoded['message']}');
//         }

//         // 🔹 Short delay to let DB changes persist, then sync from backend
//         await Future.delayed(const Duration(milliseconds: 500));
//         await _fetchOrders();
//       } else {
//         if (kDebugMode) {
//           print('❌ Failed to update pending orders. Status: ${response.statusCode}');
//         }
//       }
//     } catch (e) {
//       if (kDebugMode) {
//         print('❌ Exception updating pending orders: $e');
//       }
//     }
//   }

//   @override
//   void dispose() {
//     _pollingTimer?.cancel();
//     super.dispose();
//   }

//   Future<void> _fetchUserIdAndOrders() async {
//     final prefs = await SharedPreferences.getInstance();

//     final userData = prefs.getString('user');

//     if (userData != null) {
//       try {
//         final decodedUser = json.decode(userData);

//         final user = User.fromJson(decodedUser);

//         if (user.id.isEmpty) {
//           if (kDebugMode) {
//             print('❌ ERROR: User ID is empty! Cannot fetch orders.');
//           }
//           setState(() => _isLoading = false);
//           return;
//         }

//         setState(() {
//           _userId = user.id;
//         });

//         await _fetchOrders();
//       } catch (e) {
//         if (kDebugMode) {
//           print('❌ ERROR decoding user: $e');
//         }
//         setState(() => _isLoading = false);
//       }
//     } else {
//       if (kDebugMode) {
//         print('⚠️ No user found in SharedPreferences.');
//       }
//       setState(() => _isLoading = false);
//     }
//   }

//   Future<void> _fetchOrders() async {
//     final prefs = await SharedPreferences.getInstance();
//     final token = prefs.getString('jwt_token') ?? '';

//     if (token.isEmpty) {
//       if (kDebugMode) {
//         print('❌ No token found, cannot fetch orders.');
//       }
//       setState(() => _isLoading = false);
//       return;
//     }

//     final url = '$baseUrl/api/orders/my';
//     if (kDebugMode) {
//       print('🌐 Fetching orders from: $url');
//     }

//     try {
//       final response = await http.get(
//         Uri.parse(url),
//         headers: {
//           'Content-Type': 'application/json',
//           'Authorization': 'Bearer $token',
//         },
//       );

//       if (response.statusCode == 200) {
//         final decoded = json.decode(response.body);

//         List<dynamic> orderList = [];
//         if (decoded is List) {
//           orderList = decoded;
//         } else if (decoded is Map && decoded.containsKey('orders')) {
//           orderList = decoded['orders'] as List;
//         } else {
//           if (kDebugMode) {
//             print('⚠️ Unexpected response format: $decoded');
//           }
//           setState(() => _isLoading = false);
//           return;
//         }

//         // Filter out any null items from the list before mapping
//         final loadedOrders = (orderList)
//             .where((item) => item != null)
//             .map((data) => Order.fromJson(data as Map<String, dynamic>))
//             .toList();

//         // Debug print each order status
//         if (kDebugMode) {
//           for (var order in loadedOrders) {
//             print('🔎 Order ID: ${order.id}, status: ${order.status}, Total: ₦${order.totalPrice.toStringAsFixed(2)}');
//           }
//         }

//         setState(() {
//           _orders = loadedOrders;
//           _isLoading = false;
//         });

//       } else {
//         if (kDebugMode) {
//           print('❌ Failed to load orders. Status: ${response.statusCode}');
//         }
//         setState(() => _isLoading = false);
//       }
//     } catch (e) {
//       if (kDebugMode) {
//         print('❌ Exception while fetching orders: $e');
//       }
//       setState(() => _isLoading = false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final color = Theme.of(context).colorScheme;

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('My Orders'),
//         backgroundColor: color.primary,
//       ),
//       body: _isLoading
//           ? const Center(child: CircularProgressIndicator())
//           : _orders.isEmpty
//               ? const Center(child: Text('No orders found.'))
//               : ListView.builder(
//                   itemCount: _orders.length,
//                   padding: const EdgeInsets.all(16),
//                   itemBuilder: (context, index) {
//                     final order = _orders[index];
                    
//                     // Logic to handle nullable paidAt
//                     final orderDateText = order.paidAt != null
//                       ? DateFormat('yyyy-MM-dd HH:mm').format(order.paidAt!) // Use ! to assert non-null after check
//                       : 'Pending Payment/N/A';
                      
//                     return Card(
//                       elevation: 3,
//                       margin: const EdgeInsets.only(bottom: 16),
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                       child: Padding(
//                         padding: const EdgeInsets.all(16.0),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Row(
//                               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                               children: [
//                                 Text(
//                                   'Order ID: ${order.id.substring(0, 8)}...', // Shorten ID for display
//                                   style: TextStyle(
//                                     fontWeight: FontWeight.bold,
//                                     fontSize: 16,
//                                     color: color.primary,
//                                   ),
//                                 ),
//                                 Text(
//                                   'Total: ₦${order.totalPrice.toStringAsFixed(2)}',
//                                   style: TextStyle(
//                                     fontWeight: FontWeight.bold,
//                                     fontSize: 16,
//                                     color: color.error, // Use a distinguishing color for total
//                                   ),
//                                 ),
//                               ],
//                             ),
//                             const SizedBox(height: 8),
//                             // CORRECTED: Safely access and format the nullable paidAt field
//                             Text(
//                               'Date: $orderDateText',
//                               style: TextStyle(color: color.onSurface),
//                             ),
//                             const SizedBox(height: 8),
//                             ...order.orderItems.map((item) {
//                               // FIX CONFIRMED: item is now a strongly-typed OrderItem object, 
//                               // which safely contains the 'product' field.
//                               final product = item.product; 
//                               final imageUrl = (product.imageUrls.isNotEmpty)
//                                   ? product.imageUrls.first
//                                   : 'https://placehold.co/50x50/CCCCCC/000000?text=No+Image';

//                               return Padding(
//                                 padding: const EdgeInsets.only(bottom: 8.0),
//                                 child: Row(
//                                   crossAxisAlignment: CrossAxisAlignment.start,
//                                   children: [
//                                     ClipRRect(
//                                       borderRadius: BorderRadius.circular(8),
//                                       child: Image.network(
//                                         imageUrl,
//                                         width: 50,
//                                         height: 50,
//                                         fit: BoxFit.cover,
//                                         errorBuilder: (context, error, stackTrace) {
//                                           return Container(
//                                             width: 50,
//                                             height: 50,
//                                             color: Colors.grey[200],
//                                             child: Icon(Icons.image_not_supported,
//                                                 size: 25, color: Colors.grey[600]),
//                                           );
//                                         },
//                                       ),
//                                     ),
//                                     const SizedBox(width: 10),
//                                     Expanded(
//                                       child: Column(
//                                         crossAxisAlignment: CrossAxisAlignment.start,
//                                         children: [
//                                           Text(
//                                             product.name,
//                                             style: TextStyle(
//                                               fontSize: 15,
//                                               fontWeight: FontWeight.w500,
//                                               color: color.onSurface,
//                                             ),
//                                             maxLines: 2,
//                                             overflow: TextOverflow.ellipsis,
//                                           ),
//                                           Text(
//                                             'Vendor ID: ${product.vendorId.isNotEmpty ? product.vendorId.substring(0, 8) : 'N/A'}...',
//                                             style: TextStyle(
//                                               fontSize: 13,
//                                               color: color.onSurface.withOpacity(0.7),
//                                             ),
//                                           ),
//                                           Text(
//                                             'Qty: ${item.quantity} x ₦${item.price.toStringAsFixed(2)}',
//                                             style: TextStyle(
//                                               fontSize: 13,
//                                               color: color.onSurface.withOpacity(0.8),
//                                             ),
//                                           ),
//                                         ],
//                                       ),
//                                     ),
//                                     // Price Column
//                                     Text(
//                                       '₦${(item.quantity * item.price).toStringAsFixed(2)}',
//                                       style: TextStyle(
//                                         fontSize: 14,
//                                         fontWeight: FontWeight.bold,
//                                         color: color.primary,
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                               );
//                             }).toList(),
//                             const SizedBox(height: 10),
//                             Divider(color: color.onSurface.withOpacity(0.2)),
//                             const SizedBox(height: 5),
//                             Padding(
//                               padding: const EdgeInsets.symmetric(vertical: 12.0),
//                               child: OrderTrackingWidget(
//                                 key: ValueKey('${order.id}-${order.status}'),
//                                 orderStatus: order.status,
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     );
//                   },
//                 ),
//     );
//   }
// }
