// lib/screens/Main/orders_received_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../constants.dart';

// Use a separate theme file for global theming, but for this refactor,
// we'll fix the constants here.
// You should define colors as constants to avoid magic numbers.
const Color _deepNavyBlue = Color(0xFF000080);
const Color _greenYellow = Color(0xFFADFF2F);
const Color _whiteSmoke = Color(0xFFF5F5F5);

final ThemeData _appTheme = ThemeData(
  scaffoldBackgroundColor: Colors.white,
  appBarTheme: const AppBarTheme(
    backgroundColor: _deepNavyBlue,
    iconTheme: IconThemeData(color: Colors.white),
    titleTextStyle: TextStyle(
      color: Colors.white,
      fontSize: 20,
      fontWeight: FontWeight.bold,
    ),
  ),
  cardColor: _whiteSmoke,
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: _greenYellow,
      foregroundColor: _deepNavyBlue,
    ),
  ),
  snackBarTheme: const SnackBarThemeData(
    backgroundColor: _deepNavyBlue,
    contentTextStyle: TextStyle(color: Colors.white),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: _deepNavyBlue.withOpacity(0.06),
    hintStyle: TextStyle(color: _deepNavyBlue.withOpacity(0.6)),
    prefixIconColor: _deepNavyBlue,
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: _deepNavyBlue.withOpacity(0.2)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _deepNavyBlue, width: 1.2),
    ),
  ),
  chipTheme: ChipThemeData(
    selectedColor: _greenYellow,
    backgroundColor: _deepNavyBlue.withOpacity(0.08),
    labelStyle: TextStyle(color: _deepNavyBlue.withOpacity(0.8)),
  ),
);

// ====== Data Models ======
class VendorOrder {
  final String id;
  final String userId;
  final String buyerName;
  final String? buyerEmail;
  final String? buyerPhone;
  final String orderStatus;
  final DateTime createdAt;
  final List<VendorOrderItem> items;

  const VendorOrder({
    required this.id,
    required this.userId,
    required this.buyerName,
    this.buyerEmail,
    this.buyerPhone,
    required this.orderStatus,
    required this.createdAt,
    required this.items,
  });

  // ✅ FIXED: Parse vendor shipments correctly
  factory VendorOrder.fromJson(Map<String, dynamic> json) {
    // For vendor shipments, the structure is different
    final mainOrder = json['mainOrder'] ?? {};
    final user = mainOrder['user'] ?? {};
    
    return VendorOrder(
      id: (json['_id'] ?? json['id']).toString(),
      userId: (user['_id'] ?? user['id'] ?? '').toString(),
      // ✅ Always show "Customer Order" for vendors (hides buyer info)
      buyerName: 'Customer Order',
      buyerEmail: null, // ✅ Hide email
      buyerPhone: null, // ✅ Hide phone
      // ✅ Use shipmentStatus instead of orderStatus
      orderStatus: (json['shipmentStatus'] ?? 'processing').toString(),
      createdAt: DateTime.tryParse(
              (json['createdAt'] ?? DateTime.now().toIso8601String()).toString()) ??
          DateTime.now(),
      // ✅ Use 'items' array from Shipment model
      items: (json['items'] as List? ?? [])
          .map((itemJson) => VendorOrderItem.fromJson(itemJson))
          .toList(),
    );
  }

  VendorOrder copyWith({
    String? orderStatus,
  }) {
    return VendorOrder(
      id: id,
      userId: userId,
      buyerName: buyerName,
      buyerEmail: buyerEmail,
      buyerPhone: buyerPhone,
      orderStatus: orderStatus ?? this.orderStatus,
      createdAt: createdAt,
      items: items,
    );
  }
}

class VendorOrderItem {
  final String productId;
  final String productName;
  final String? productImageUrl;
  final int quantity;
  final double unitPrice;

  const VendorOrderItem({
    required this.productId,
    required this.productName,
    this.productImageUrl,
    required this.quantity,
    required this.unitPrice,
  });

  factory VendorOrderItem.fromJson(Map<String, dynamic> json) {
    final product = json['product'] ?? {};
    return VendorOrderItem(
      productId: (product['_id'] ?? product['id'] ?? '').toString(),
      productName: (product['name'] ?? 'Product').toString(),
      productImageUrl: (product['imageUrls'] is List && product['imageUrls'].isNotEmpty)
          ? product['imageUrls'][0] as String
          : null,
      quantity: int.tryParse('${json['quantity'] ?? 1}') ?? 1,
      unitPrice: double.tryParse('${json['price'] ?? 0}') ?? 0,
    );
  }
}

// 📦 NEW DATA MODEL FOR VENDOR STATS
class VendorStats {
  final int totalProducts;
  final int productsSold;
  final int productsUnsold;

  const VendorStats({
    required this.totalProducts,
    required this.productsSold,
    required this.productsUnsold,
  });

  factory VendorStats.fromJson(Map<String, dynamic> json) {
    return VendorStats(
      totalProducts: json['totalProducts'] as int? ?? 0,
      productsSold: json['productsSold'] as int? ?? 0,
      productsUnsold: json['productsUnsold'] as int? ?? 0,
    );
  }
}

// ====== Services (New) ======
class OrdersService {
  static const String _ordersListEndpoint = '/api/orders/vendor';
  static const String _updateOrderStatusEndpoint = '/api/orders';
  // 🔗 NEW: Endpoint for vendor stats
  static const String _vendorStatsEndpoint = '/api/vendor/stats';

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  // ✅ NEW METHOD: Fetch vendor statistics
  Future<VendorStats> fetchVendorStats() async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('Authentication token not found. Please log in again.');
    }

    final uri = Uri.parse('$baseUrl$_vendorStatsEndpoint');
    final resp = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      return VendorStats.fromJson(data);
    } else {
      final message = _safeMessage(resp.body) ?? 'Failed to load vendor stats (HTTP ${resp.statusCode}).';
      throw Exception(message);
    }
  }

  Future<List<VendorOrder>> fetchOrders() async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('Authentication token not found. Please log in again.');
    }

    final uri = Uri.parse('$baseUrl$_ordersListEndpoint');
    final resp = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      return (data as List).map((e) => VendorOrder.fromJson(e)).toList();
    } else {
      final message = _safeMessage(resp.body) ?? 'Failed to load orders (HTTP ${resp.statusCode}).';
      throw Exception(message);
    }
  }

  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('Authentication token not found. Please log in again.');
    }

    final uri = Uri.parse('$baseUrl$_updateOrderStatusEndpoint/$orderId/status');
    final resp = await http.put(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json; charset=UTF-8',
        'Accept': 'application/json',
      },
      body: jsonEncode({'status': newStatus}),
    );

    if (resp.statusCode != 200) {
      final message = _safeMessage(resp.body) ?? 'Failed to update order status.';
      throw Exception(message);
    }
  }

  String? _safeMessage(String body) {
    try {
      final m = jsonDecode(body);
      if (m is Map && m['message'] is String) return m['message'];
      return null;
    } catch (_) {
      return null;
    }
  }
}

// ====== Screen ======
class OrdersRecivedScreen extends StatefulWidget {
  const OrdersRecivedScreen({super.key});

  @override
  State<OrdersRecivedScreen> createState() => _OrdersRecivedScreenState();
}

class _OrdersRecivedScreenState extends State<OrdersRecivedScreen> {
  final OrdersService _ordersService = OrdersService();
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;

  List<VendorOrder> _allOrders = [];
  List<VendorOrder> _displayedOrders = [];
  // 📊 NEW: Vendor statistics variable
  VendorStats? _vendorStats;
  bool _isLoading = false;
  String _errorMessage = '';
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ✅ UPDATED METHOD: Fetch both stats and orders
  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      // Fetch stats first
      final stats = await _ordersService.fetchVendorStats();
      // Fetch orders next
      _allOrders = await _ordersService.fetchOrders();

      setState(() {
        _vendorStats = stats;
      });
      _filterOrders();
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _filterOrders() {
    final query = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _displayedOrders = _allOrders.where((order) {
        final matchesStatus = _statusFilter == 'all' || order.orderStatus == _statusFilter;
        // ✅ Search by product name only (not buyer name)
        final matchesSearch = query.isEmpty ||
            order.items.any((item) => item.productName.toLowerCase().contains(query));
        return matchesStatus && matchesSearch;
      }).toList();
    });
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      _filterOrders();
    });
  }

  Future<void> _updateOrderStatus(VendorOrder order, String newStatus) async {
    final oldStatus = order.orderStatus;
    final idx = _displayedOrders.indexWhere((o) => o.id == order.id);
    if (idx == -1) return;

    // Optimistic update
    setState(() {
      _displayedOrders[idx] = order.copyWith(orderStatus: newStatus);
    });

    try {
      await _ordersService.updateOrderStatus(order.id, newStatus);
      _showSnack('Order updated to "$newStatus".');
      _fetchData(); // Refresh both stats and orders to get the latest data
    } catch (e) {
      // Rollback on failure
      setState(() {
        _displayedOrders[idx] = order.copyWith(orderStatus: oldStatus);
      });
      _showSnack(e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Theme.of(context).snackBarTheme.backgroundColor,
      ),
    );
  }

  // ====== UI ======
  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _appTheme,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Orders Received'),
        ),
        body: RefreshIndicator(
          onRefresh: _fetchData,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              SliverToBoxAdapter(child: _buildSummaryCards()),
              SliverToBoxAdapter(child: _buildFilters()),
              if (_errorMessage.isNotEmpty)
                SliverToBoxAdapter(
                  child: _ErrorState(
                    message: _errorMessage,
                    onRetry: _fetchData,
                  ),
                )
              else if (_isLoading)
                const SliverToBoxAdapter(child: _LoadingListSkeleton())
              else if (_displayedOrders.isEmpty)
                const SliverToBoxAdapter(child: _EmptyState())
              else
                SliverList.separated(
                  itemCount: _displayedOrders.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final order = _displayedOrders[index];
                    return _OrderTile(
                      order: order,
                      onUpdateStatus: _updateOrderStatus,
                    );
                  },
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: TextField(
        controller: _searchCtrl,
        onChanged: _onSearchChanged,
        decoration: const InputDecoration(
          hintText: 'Search by product name...', // ✅ Updated hint
          prefixIcon: Icon(Icons.search),
        ),
      ),
    );
  }

  // ✅ UPDATED METHOD: Use the fetched stats instead of calculating them
  Widget _buildSummaryCards() {
    // Show loading skeleton if stats are not yet loaded
    if (_vendorStats == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: [
            Expanded(child: _StatCard(title: 'Total Products', value: '...', icon: Icons.inventory_2_outlined)),
            const SizedBox(width: 12),
            Expanded(child: _StatCard(title: 'Products Sold', value: '...', icon: Icons.shopping_bag_outlined)),
            const SizedBox(width: 12),
            Expanded(child: _StatCard(title: 'Products Unsold', value: '...', icon: Icons.assignment_late_outlined)),
          ],
        ),
      );
    }
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              title: 'Total Products',
              value: '${_vendorStats!.totalProducts}',
              icon: Icons.inventory_2_outlined,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              title: 'Products Sold',
              value: '${_vendorStats!.productsSold}',
              icon: Icons.shopping_bag_outlined,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              title: 'Products Unsold',
              value: '${_vendorStats!.productsUnsold}',
              icon: Icons.assignment_late_outlined,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    final statuses = const [
      ['all', 'All'],
      ['pending', 'Pending'],
      ['processing', 'Processing'],
      ['ready_for_pickup', 'Ready for Pickup'],
      ['out_for_delivery', 'Out for Delivery'],
      ['delivered', 'Delivered'],
      ['cancelled', 'Cancelled'],
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: statuses.map((s) {
          final value = s[0]!;
          final label = s[1]!;
          return ChoiceChip(
            selected: _statusFilter == value,
            label: Text(label),
            onSelected: (sel) {
              setState(() {
                _statusFilter = value;
              });
              _filterOrders();
            },
          );
        }).toList(),
      ),
    );
  }
}

// ====== Reusable Widgets (No Changes Needed) ======
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.appBarTheme.backgroundColor!, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: theme.appBarTheme.backgroundColor!.withOpacity(0.1),
              child: Icon(icon, color: theme.appBarTheme.backgroundColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: theme.appBarTheme.backgroundColor!.withOpacity(0.75),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      color: theme.appBarTheme.backgroundColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ✅ FIXED: _OrderTile class (NO SYNTAX ERRORS)
class _OrderTile extends StatelessWidget {
  final VendorOrder order;
  final Future<void> Function(VendorOrder order, String newStatus) onUpdateStatus;

  const _OrderTile({
    required this.order,
    required this.onUpdateStatus,
  });

  Color _getBadgeColor(String status) {
    switch (status) {
      case 'delivered':
        return Colors.green;
      case 'ready_for_pickup':
        return Colors.blue;
      case 'out_for_delivery':
        return Colors.orange;
      case 'processing':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.blueGrey;
    }
  }

  Color _getResolvedBadgeColor(String status) {
    switch (status) {
      case 'delivered':
        return Colors.green.shade700;
      case 'ready_for_pickup':
        return Colors.blue.shade700;
      case 'out_for_delivery':
        return Colors.orange.shade700;
      case 'processing':
        return Colors.orange.shade700;
      case 'cancelled':
        return Colors.red.shade700;
      default:
        return Colors.blueGrey.shade700;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final badgeColor = _getBadgeColor(order.orderStatus);
    final deepNavyBlue = Theme.of(context).appBarTheme.backgroundColor!;
    final resolvedBadgeColor = _getResolvedBadgeColor(order.orderStatus);

    final totalAmount = order.items.fold(0.0, (sum, item) => sum + (item.unitPrice * item.quantity));

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order ID and Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Shipment ID: ${order.id.substring(0, 8)}...',
                    style: TextStyle(
                      color: deepNavyBlue.withOpacity(0.6),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.12),
                    border: Border.all(color: badgeColor.withOpacity(0.6)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    order.orderStatus.replaceAll('_', ' ').toUpperCase(),
                    style: TextStyle(
                      color: resolvedBadgeColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 20, thickness: 1),
            
            // ✅ Customer Info (HIDDEN - Shows "Customer Order" instead of buyer details)
            Row(
              children: [
                Icon(Icons.shopping_bag_outlined, size: 20, color: deepNavyBlue),
                const SizedBox(width: 8),
                Text(
                  "Customer Order",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontStyle: FontStyle.italic,
                    color: deepNavyBlue.withOpacity(0.7),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Ordered Products Header
            Text('Ordered Products:', style: TextStyle(fontWeight: FontWeight.bold, color: deepNavyBlue.withOpacity(0.8))),
            const SizedBox(height: 8),
            
            // Product List
            ...order.items.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Row(
                    children: [
                      _ProductAvatar(imageUrl: item.productImageUrl, name: item.productName),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.productName,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  'Qty: ${item.quantity}',
                                  style: TextStyle(color: deepNavyBlue.withOpacity(0.7), fontSize: 13),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '₦${item.unitPrice.toStringAsFixed(2)} each',
                                  style: TextStyle(color: deepNavyBlue.withOpacity(0.6), fontSize: 13),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₦${(item.unitPrice * item.quantity).toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          Text(
                            'Total',
                            style: TextStyle(color: deepNavyBlue.withOpacity(0.5), fontSize: 10),
                          ),
                        ],
                      ),
                    ],
                  ),
                )).toList(),
            const Divider(height: 20, thickness: 1),
            
            // Order Total and Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order Total:',
                      style: TextStyle(
                        color: deepNavyBlue.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '₦${totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold, 
                        fontSize: 18, 
                        color: _deepNavyBlue
                      ),
                    ),
                  ],
                ),
                _ActionsMenu(order: order, onUpdateStatus: onUpdateStatus),
              ],
            ),
            
            // Order Date
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                'Order Date: ${_formatDate(order.createdAt)}',
                style: TextStyle(
                  color: deepNavyBlue.withOpacity(0.5),
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductAvatar extends StatelessWidget {
  final String? imageUrl;
  final String name;

  const _ProductAvatar({required this.imageUrl, required this.name});

  @override
  Widget build(BuildContext context) {
    final deepNavyBlue = Theme.of(context).appBarTheme.backgroundColor!;
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(
          imageUrl: imageUrl!,
          width: 54,
          height: 54,
          fit: BoxFit.cover,
          placeholder: (context, url) => _skeletonBox(),
          errorWidget: (context, url, error) => _fallback(deepNavyBlue),
        ),
      );
    }
    return _fallback(deepNavyBlue);
  }

  Widget _fallback(Color deepNavyBlue) {
    final initials = name.isNotEmpty
        ? name.trim().split(RegExp(r'\s+')).map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').take(2).join()
        : 'P';
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: deepNavyBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: deepNavyBlue,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _skeletonBox() => Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: _deepNavyBlue.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
      );
}

class _ActionsMenu extends StatelessWidget {
  final VendorOrder order;
  final Future<void> Function(VendorOrder order, String newStatus) onUpdateStatus;

  const _ActionsMenu({required this.order, required this.onUpdateStatus});

  @override
  Widget build(BuildContext context) {
    final deepNavyBlue = Theme.of(context).appBarTheme.backgroundColor!;
    final List<Map<String, dynamic>> menuItems = [];
    
    // ✅ Updated status transitions based on shipment status
    if (order.orderStatus == 'processing') {
      menuItems.add({'label': 'Ready for Pickup', 'value': 'ready_for_pickup', 'icon': Icons.inventory_2_outlined});
      menuItems.add({'label': 'Out for Delivery', 'value': 'out_for_delivery', 'icon': Icons.local_shipping_outlined});
    }
    if (order.orderStatus == 'ready_for_pickup') {
      menuItems.add({'label': 'Out for Delivery', 'value': 'out_for_delivery', 'icon': Icons.local_shipping_outlined});
    }
    if (order.orderStatus == 'out_for_delivery') {
      menuItems.add({'label': 'Mark Delivered', 'value': 'delivered', 'icon': Icons.check_circle_outline});
    }
    if (order.orderStatus != 'cancelled' && order.orderStatus != 'delivered') {
      menuItems.add({'label': 'Mark Cancelled', 'value': 'cancelled', 'icon': Icons.cancel_outlined});
    }

    if (menuItems.isEmpty) {
      return const SizedBox.shrink();
    }

    return PopupMenuButton<String>(
      icon: Icon(Icons.more_horiz, color: deepNavyBlue),
      onSelected: (value) => onUpdateStatus(order, value),
      itemBuilder: (context) => menuItems
          .map((m) => PopupMenuItem<String>(
                value: m['value'] as String,
                child: Row(
                  children: [
                    Icon(m['icon'] as IconData, size: 18, color: deepNavyBlue),
                    const SizedBox(width: 8),
                    Text(m['label'] as String),
                  ],
                ),
              ))
          .toList(),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final deepNavyBlue = Theme.of(context).appBarTheme.backgroundColor!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 12),
      child: Column(
        children: [
          Icon(Icons.mark_email_read_outlined, size: 80, color: deepNavyBlue.withOpacity(0.4)),
          const SizedBox(height: 16),
          Text(
            'No orders yet',
            style: TextStyle(color: deepNavyBlue, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'When customers buy your products, their orders will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: deepNavyBlue.withOpacity(0.75), fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final deepNavyBlue = Theme.of(context).appBarTheme.backgroundColor!;
    final greenYellow = Theme.of(context).elevatedButtonTheme.style!.backgroundColor!.resolve({});
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 12),
      child: Column(
        children: [
          Icon(Icons.error_outline, size: 80, color: Colors.red.withOpacity(0.75)),
          const SizedBox(height: 16),
          Text(
            'Couldn’t load orders',
            style: TextStyle(color: deepNavyBlue, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: deepNavyBlue.withOpacity(0.8), fontSize: 14),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: Icon(Icons.refresh, color: greenYellow),
            label: Text('Retry', style: TextStyle(color: deepNavyBlue)),
            style: ElevatedButton.styleFrom(
              backgroundColor: greenYellow,
              foregroundColor: deepNavyBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingListSkeleton extends StatelessWidget {
  const _LoadingListSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      primary: false,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, __) => const _SkeletonTile(),
    );
  }
}

class _SkeletonTile extends StatelessWidget {
  const _SkeletonTile();

  @override
  Widget build(BuildContext context) {
    final deepNavyBlue = Theme.of(context).appBarTheme.backgroundColor!;
    
    Widget box({double h = 12, double w = double.infinity, double r = 8}) {
      return Container(
        height: h,
        width: w,
        decoration: BoxDecoration(
          color: deepNavyBlue.withOpacity(0.08),
          borderRadius: BorderRadius.circular(r),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            box(h: 54, w: 54, r: 12),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  box(w: 160, h: 14),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: box(h: 12)),
                      const SizedBox(width: 8),
                      Expanded(child: box(h: 12)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      box(w: 60, h: 12),
                      const SizedBox(width: 12),
                      box(w: 80, h: 12),
                      const SizedBox(width: 12),
                      box(w: 80, h: 12),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}