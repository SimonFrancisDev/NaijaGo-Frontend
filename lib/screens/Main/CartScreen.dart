import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../providers/cart_provider.dart';
import 'checkout_screen.dart';
import 'product_detail_screen.dart';
import '../../models/product.dart';

class CartScreen extends StatefulWidget {
  final VoidCallback onOrderSuccess;

  const CartScreen({required this.onOrderSuccess, super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  List<Product> _recentlyViewedProducts = [];
  bool _isLoadingRecentlyViewed = false;
  
  @override
  void initState() {
    super.initState();
    _fetchRecentlyViewedProducts();
  }

  Future<void> _fetchRecentlyViewedProducts() async {
    setState(() {
      _isLoadingRecentlyViewed = true;
    });

    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('jwt_token');
      
      const String baseUrl = 'https://naijago-backend.onrender.com';
      const String endpoint = '/api/products';
      
      final headers = {
        'Content-Type': 'application/json; charset=UTF-8',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final response = await http.get(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        final List<Product> allProducts = jsonList
            .map((json) => Product.fromJson(json))
            .toList();
        
        allProducts.shuffle();
        
        setState(() {
          _recentlyViewedProducts = allProducts.take(12).toList();
        });
      } else {
        _createSimplePlaceholderProducts();
      }
    } catch (e) {
      debugPrint('Error fetching recently viewed: $e');
      _createSimplePlaceholderProducts();
    } finally {
      setState(() {
        _isLoadingRecentlyViewed = false;
      });
    }
  }

  void _createSimplePlaceholderProducts() {
    final placeholderProducts = <Map<String, dynamic>>[
      {
        'id': '1',
        'name': 'Wireless Bluetooth Headphones',
        'price': 25000.0,
        'stockQuantity': 15,
        'imageUrls': ['https://placehold.co/400x300/CCCCCC/000000?text=Headphones'],
        'vendorBusinessName': 'Tech Store',
        'description': 'High quality wireless headphones with noise cancellation',
        'category': 'Electronics',
      },
       {
        'id': '2',
        'name': 'Smart Watch Series 5',
        'price': 45000.0,
        'stockQuantity': 8,
        'imageUrls': ['https://placehold.co/400x300/CCCCCC/000000?text=Smart+Watch'],
        'vendorBusinessName': 'Gadget Hub',
        'description': 'Feature-rich smart watch with heart rate monitor',
        'category': 'Electronics',
      },
      {
        'id': '3',
        'name': 'Premium Running Shoes',
        'price': 15000.0,
        'stockQuantity': 20,
        'imageUrls': ['https://placehold.co/400x300/CCCCCC/000000?text=Shoes'],
        'vendorBusinessName': 'Sports World',
        'description': 'Comfortable running shoes for all terrains',
        'category': 'Sports',
      },
      {
        'id': '4',
        'name': 'Waterproof Backpack',
        'price': 8000.0,
        'stockQuantity': 25,
        'imageUrls': ['https://placehold.co/400x300/CCCCCC/000000?text=Backpack'],
        'vendorBusinessName': 'Travel Gear',
        'description': 'Durable waterproof backpack with laptop compartment',
        'category': 'Fashion',
      },
      {
        'id': '5',
        'name': 'Automatic Coffee Maker',
        'price': 35000.0,
        'stockQuantity': 12,
        'imageUrls': ['https://placehold.co/400x300/CCCCCC/000000?text=Coffee+Maker'],
        'vendorBusinessName': 'Home Essentials',
        'description': 'Programmable coffee maker with thermal carafe',
        'category': 'Home',
      },
      {
        'id': '6',
        'name': 'Fitness Tracker Band',
        'price': 12000.0,
        'stockQuantity': 18,
        'imageUrls': ['https://placehold.co/400x300/CCCCCC/000000?text=Fitness+Band'],
        'vendorBusinessName': 'Health Tech',
        'description': 'Activity tracking fitness band with sleep monitor',
        'category': 'Fitness',
      },
      // Second row products
      {
        'id': '7',
        'name': 'Wireless Earbuds',
        'price': 18000.0,
        'stockQuantity': 22,
        'imageUrls': ['https://placehold.co/400x300/CCCCCC/000000?text=Earbuds'],
        'vendorBusinessName': 'Audio Tech',
        'description': 'True wireless earbuds with charging case',
        'category': 'Electronics',
      },
      {
        'id': '8',
        'name': 'Gaming Laptop',
        'price': 320000.0,
        'stockQuantity': 5,
        'imageUrls': ['https://placehold.co/400x300/CCCCCC/000000?text=Gaming+Laptop'],
        'vendorBusinessName': 'Game Zone',
        'description': 'High performance gaming laptop with RTX graphics',
        'category': 'Electronics',
      },
      {
        'id': '9',
        'name': 'Yoga Mat',
        'price': 6500.0,
        'stockQuantity': 30,
        'imageUrls': ['https://placehold.co/400x300/CCCCCC/000000?text=Yoga+Mat'],
        'vendorBusinessName': 'Fitness World',
        'description': 'Non-slip yoga mat with carrying strap',
        'category': 'Fitness',
      },
      {
        'id': '10',
        'name': 'Smartphone X12',
        'price': 185000.0,
        'stockQuantity': 10,
        'imageUrls': ['https://placehold.co/400x300/CCCCCC/000000?text=Smartphone'],
        'vendorBusinessName': 'Mobile World',
        'description': 'Latest smartphone with triple camera setup',
        'category': 'Electronics',
      },
      {
        'id': '11',
        'name': 'Air Fryer',
        'price': 28000.0,
        'stockQuantity': 14,
        'imageUrls': ['https://placehold.co/400x300/CCCCCC/000000?text=Air+Fryer'],
        'vendorBusinessName': 'Kitchen Pro',
        'description': 'Digital air fryer with multiple cooking functions',
        'category': 'Home',
      },
      {
        'id': '12',
        'name': 'Leather Wallet',
        'price': 5500.0,
        'stockQuantity': 35,
        'imageUrls': ['https://placehold.co/400x300/CCCCCC/000000?text=Wallet'],
        'vendorBusinessName': 'Fashion Store',
        'description': 'Genuine leather wallet with multiple card slots',
        'category': 'Fashion',
      },
    ];

    setState(() {
      _recentlyViewedProducts = placeholderProducts
          .map((data) => Product.fromJson(data))
          .toList();
    });
  }

  // UPDATED: Build cart item with size display
  Widget _buildCartItem(BuildContext context, CartItem cartItem, int index) {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final imageUrl = cartItem.product.imageUrls.isNotEmpty
        ? cartItem.product.imageUrls[0]
        : 'https://placehold.co/80x80/CCCCCC/000000?text=No+Image';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.only(bottom: 12.0),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ProductDetailScreen(
                      product: cartItem.product,
                      heroTag: 'cart_item_${cartItem.product.id}_$index',
                    ),
                  ),
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  imageUrl,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 80,
                      height: 80,
                      color: Colors.grey.shade200,
                      child: const Icon(
                        Icons.image_not_supported,
                        size: 40,
                        color: Colors.grey,
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // UPDATED: Use displayName which includes size
                  Text(
                    cartItem.displayName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0B1A30),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₦${cartItem.product.price.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF0B1A30),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // UPDATED: Show vendor and size info
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Vendor: ${cartItem.product.vendorBusinessName ?? 'N/A'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      if (cartItem.selectedSize != null && cartItem.selectedSize!.isNotEmpty)
                        Text(
                          'Size: ${cartItem.selectedSize}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blueGrey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // UPDATED: Quantity controls with size-specific removal
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.remove_circle_outline,
                        color: Color(0xFF0B1A30),
                      ),
                      onPressed: () {
                        cartProvider.removeSingleItem(
                          cartItem.product.id,
                          selectedSize: cartItem.selectedSize,
                        );
                      },
                    ),
                    Text(
                      cartItem.quantity.toString(),
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF0B1A30),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.add_circle_outline,
                        color: Color(0xFF0B1A30),
                      ),
                      onPressed: () {
                        if (cartItem.quantity < cartItem.product.stockQuantity) {
                          cartProvider.addProduct(
                            cartItem.product,
                            selectedSize: cartItem.selectedSize,
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Max stock reached'),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
                // UPDATED: Remove button with size-specific removal
                IconButton(
                  icon: const Icon(Icons.delete_forever, color: Colors.red),
                  onPressed: () {
                    cartProvider.removeItem(
                      cartItem.product.id,
                      selectedSize: cartItem.selectedSize,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${cartItem.displayName} removed.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);
    final cartItems = cartProvider.items.values.toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Having Issues ? refresh screen',
          style: TextStyle(
            color: Color(0xFF0B1A30),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Color(0xFF0B1A30)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchRecentlyViewedProducts,
            tooltip: 'Refresh products',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cart Items Section
                  if (cartProvider.items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.shopping_cart_outlined,
                              size: 80,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Your cart is empty',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0B1A30),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Start shopping to add items to your cart',
                              style: TextStyle(
                                color: Colors.grey,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: _fetchRecentlyViewedProducts,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0B1A30),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Browse Products',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                              'Cart Items (${cartProvider.itemCount})',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0B1A30),
                              ),
                            ),
                              TextButton.icon(
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Clear Cart'),
                                      content: const Text(
                                          'Are you sure you want to remove all items from your cart?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            cartProvider.clearCart();
                                            Navigator.pop(context);
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                content: Text('Cart cleared'),
                                                backgroundColor: Colors.green,
                                              ),
                                            );
                                          },
                                          child: const Text(
                                            'Clear',
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.delete_sweep,
                                    color: Colors.red, size: 18),
                                label: const Text(
                                  'Clear Cart',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: cartItems.length,
                            itemBuilder: (context, index) {
                              return _buildCartItem(context, cartItems[index], index);
                            },
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),

                  // You Might Also Like Section
                  _buildYouMightAlsoLikeSection(),
                  
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // Total and Checkout Section
          if (cartProvider.itemCount > 0)
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 5,
                    offset: Offset(0, -3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0B1A30),
                        ),
                      ),
                      Text(
                        '₦${cartProvider.totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0B1A30),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => CheckoutScreen(
                                onOrderSuccess: widget.onOrderSuccess),
                          ),
                        );
                      },
                      icon: const Icon(Icons.payment, color: Colors.white),
                      label: const Text(
                        'Proceed to Checkout',
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0B1A30),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // Rest of your methods remain the same...
  Widget _buildYouMightAlsoLikeSection() {
    if (_isLoadingRecentlyViewed) {
      return Container(
        color: Colors.grey[50],
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'You Might Also Like',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0B1A30),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 540,
              child: _buildRecentlyViewedShimmer(),
            ),
          ],
        ),
      );
    }

    if (_recentlyViewedProducts.isEmpty) {
      return const SizedBox.shrink();
    }

    final firstRow = _recentlyViewedProducts.take(6).toList();
    final secondRow = _recentlyViewedProducts.skip(6).take(6).toList();

    return Container(
      color: Colors.grey[50],
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'You Might Also Like',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0B1A30),
                  ),
                ),
                Icon(
                  Icons.trending_up,
                  color: Color(0xFF0B1A30),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          
          // First row of 6 products
          SizedBox(
            height: 270,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              scrollDirection: Axis.horizontal,
              itemCount: firstRow.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final product = firstRow[index];
                final heroTag = 'cart_recent-${product.id}-$index';
                return SizedBox(
                  width: 160,
                  child: _RecentlyViewedProductCard(
                    product: product,
                    heroTag: heroTag,
                  ),
                );
              },
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Second row of 6 products
          SizedBox(
            height: 270,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              scrollDirection: Axis.horizontal,
              itemCount: secondRow.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final product = secondRow[index];
                final adjustedIndex = index + 6;
                final heroTag = 'cart_recent-${product.id}-$adjustedIndex';
                return SizedBox(
                  width: 160,
                  child: _RecentlyViewedProductCard(
                    product: product,
                    heroTag: heroTag,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentlyViewedShimmer() {
    return Column(
      children: [
        SizedBox(
          height: 270,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            scrollDirection: Axis.horizontal,
            itemCount: 6,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              return SizedBox(
                width: 160,
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Shimmer.fromColors(
                        baseColor: Colors.grey[300]!,
                        highlightColor: Colors.grey[100]!,
                        child: Container(
                          height: 120,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Shimmer.fromColors(
                              baseColor: Colors.grey[300]!,
                              highlightColor: Colors.grey[100]!,
                              child: Container(
                                height: 16,
                                width: double.infinity,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Shimmer.fromColors(
                              baseColor: Colors.grey[300]!,
                              highlightColor: Colors.grey[100]!,
                              child: Container(
                                height: 14,
                                width: 80,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Shimmer.fromColors(
                              baseColor: Colors.grey[300]!,
                              highlightColor: Colors.grey[100]!,
                              child: Container(
                                height: 36,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        
        const SizedBox(height: 12),
        
        SizedBox(
          height: 270,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            scrollDirection: Axis.horizontal,
            itemCount: 6,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              return SizedBox(
                width: 160,
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Shimmer.fromColors(
                        baseColor: Colors.grey[300]!,
                        highlightColor: Colors.grey[100]!,
                        child: Container(
                          height: 120,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Shimmer.fromColors(
                              baseColor: Colors.grey[300]!,
                              highlightColor: Colors.grey[100]!,
                              child: Container(
                                height: 16,
                                width: double.infinity,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Shimmer.fromColors(
                              baseColor: Colors.grey[300]!,
                              highlightColor: Colors.grey[100]!,
                              child: Container(
                                height: 14,
                                width: 80,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Shimmer.fromColors(
                              baseColor: Colors.grey[300]!,
                              highlightColor: Colors.grey[100]!,
                              child: Container(
                                height: 36,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// Recently Viewed Product Card with navigation
// 
// Recently Viewed Product Card with navigation
class _RecentlyViewedProductCard extends StatelessWidget {
  final Product product;
  final String heroTag;

  const _RecentlyViewedProductCard({
    required this.product,
    required this.heroTag,
  });

  String _formatPrice(double price) {
    final formatter = NumberFormat.currency(
      locale: 'en_NG',
      symbol: '₦',
      decimalDigits: 2,
    );
    return formatter.format(price);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ProductDetailScreen(
              product: product,
              heroTag: heroTag,
            ),
          ),
        );
      },
      child: Card(
        color: Colors.white,
        elevation: 4,
        shadowColor: const Color(0xFF0B1A30).withOpacity(0.15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Hero(
              tag: heroTag,
              child: Material(
                color: Colors.transparent,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16)),
                  child: CachedNetworkImage(
                    imageUrl: product.imageUrls.isNotEmpty
                        ? product.imageUrls[0]
                        : 'https://placehold.co/400x300/CCCCCC/000000?text=No+Image',
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Shimmer.fromColors(
                      baseColor: Colors.grey[300]!,
                      highlightColor: Colors.grey[100]!,
                      child: Container(
                        height: 120,
                        color: Colors.white,
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 120,
                      color: Colors.grey[200],
                      child: const Icon(Icons.image_not_supported,
                          size: 40, color: Colors.grey),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0B1A30),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatPrice(product.price),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0B1A30),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Vendor: ${product.vendorBusinessName ?? 'N/A'}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        // Show size info if product has sizes
                        if (product.hasSizes)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              '${product.sizeType} Available',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.blueGrey[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          height: 36,
                          child: ElevatedButton(
                            onPressed: () {
                              // Navigate to ProductDetailScreen when button is pressed
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => ProductDetailScreen(
                                    product: product,
                                    heroTag: heroTag,
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: product.stockQuantity > 0
                                  ? const Color(0xFF0B1A30)
                                  : Colors.grey[300],
                              foregroundColor: product.stockQuantity > 0
                                  ? Colors.white
                                  : Colors.grey[700],
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: EdgeInsets.zero,
                              elevation: 0,
                            ),
                            child: Text(
                              product.stockQuantity > 0
                                  ? 'Add to Cart'
                                  : 'Out of Stock',
                              style: TextStyle(
                                fontSize: 12,
                                color: product.stockQuantity > 0
                                    ? Colors.white
                                    : Colors.grey[400],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}