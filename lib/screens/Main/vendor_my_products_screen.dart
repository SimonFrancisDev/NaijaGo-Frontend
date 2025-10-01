// lib/screens/Main/vendor_my_products_screen.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:lottie/lottie.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants.dart';
import 'package:cached_network_image/cached_network_image.dart';

// Color constants
const Color deepNavyBlue = Color(0xFF000080);
const Color greenYellow = Color(0xFFADFF2F);
const Color whiteBackground = Colors.white;
const Color whiteSmoke = Color(0xFFF5F5F5);

// Model for Product data
class Product {
  final String id;
  final String name;
  final String category;
  final double price;
  final double averageRating;
  final List<String> imageUrls;

  Product({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.averageRating,
    required this.imageUrls,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['_id'],
      name: json['name'],
      category: json['category'] ?? 'Uncategorized',
      price: json['price'].toDouble(),
      averageRating: json['averageRating']?.toDouble() ?? 0.0,
      imageUrls: List<String>.from(json['imageUrls'] ?? []),
    );
  }
}

class VendorMyProductsScreen extends StatefulWidget {
  const VendorMyProductsScreen({Key? key}) : super(key: key);

  @override
  State<VendorMyProductsScreen> createState() => _VendorMyProductsScreenState();
}

class _VendorMyProductsScreenState extends State<VendorMyProductsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  List<Product> _products = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _animationController =
        AnimationController(vsync: this, duration: const Duration(seconds: 1))
          ..repeat(reverse: true);
    _fetchVendorProducts();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  Future<void> _fetchVendorProducts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token = await _getToken();
      if (token == null) throw Exception("Authentication token not found.");

      final url = Uri.parse('$baseUrl/api/products/myproducts');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> productsData = json.decode(response.body);
        setState(() {
          _products = productsData.map((data) => Product.fromJson(data)).toList();
          _isLoading = false;
        });
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['message'] ?? 'Failed to load products');
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _showComingSoonDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: whiteBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Good Choice!!!',
          style: TextStyle(color: deepNavyBlue, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'This Feature only shows that you can add product, You can add products from the vendor dashboard!',
          style: TextStyle(color: deepNavyBlue),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK', style: TextStyle(color: deepNavyBlue)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteProduct(String productId) async {
    final bool confirm = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: whiteBackground,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Confirm Deletion',
                style: TextStyle(color: deepNavyBlue)),
            content: const Text('Are you sure you want to delete this product?',
                style: TextStyle(color: deepNavyBlue)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel', style: TextStyle(color: deepNavyBlue)),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    try {
      final token = await _getToken();
      if (token == null) throw Exception("Authentication token not found.");

      final url = Uri.parse('$baseUrl/api/products/$productId');
      final response = await http.delete(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _products.removeWhere((product) => product.id == productId);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Product deleted successfully!')),
          );
        }
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['message'] ?? 'Failed to delete product');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: whiteBackground,
      appBar: AppBar(
        title: const Text("My Products", style: TextStyle(color: greenYellow)),
        elevation: 0,
        backgroundColor: deepNavyBlue,
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showComingSoonDialog,
        backgroundColor: deepNavyBlue,
        foregroundColor: greenYellow,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: deepNavyBlue),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 60),
              const SizedBox(height: 10),
              Text(
                'Failed to load products: $_error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: deepNavyBlue),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _fetchVendorProducts,
                style: ElevatedButton.styleFrom(
                  backgroundColor: deepNavyBlue,
                  foregroundColor: greenYellow,
                ),
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset('assets/animations/no-product.json',
                width: 200, height: 200),
            const Text(
              "You have no products yet.",
              style: TextStyle(fontSize: 18, color: deepNavyBlue),
            ),
            const SizedBox(height: 8),
            Text(
              "Tap the '+' button to add your first product.",
              style: TextStyle(color: deepNavyBlue.withOpacity(0.6)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAnalyticsCard(),
          const SizedBox(height: 24),
          _buildProductRatingsBarChart(),
          const SizedBox(height: 24),
          const Text(
            "Your Listings",
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: deepNavyBlue),
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _products.length,
            itemBuilder: (context, index) {
              final product = _products[index];
              final imageUrl = product.imageUrls.isNotEmpty ? product.imageUrls[0] : null;

              return Card(
                color: whiteBackground,
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: deepNavyBlue, width: 1.5),
                ),
                elevation: 0,
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 60,
                      height: 60,
                      child: imageUrl != null
                          ? CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => const Center(
                                  child: CircularProgressIndicator(
                                      color: deepNavyBlue)),
                              errorWidget: (context, url, error) =>
                                  const Icon(Icons.shopping_bag,
                                      color: deepNavyBlue),
                            )
                          : const Icon(Icons.shopping_bag,
                              color: deepNavyBlue),
                    ),
                  ),
                  title: Text(
                    product.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: deepNavyBlue),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        "₦${product.price}",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: greenYellow),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star,
                              color: greenYellow, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            product.averageRating.toStringAsFixed(1),
                            style: const TextStyle(color: deepNavyBlue),
                          ),
                        ],
                      ),
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: deepNavyBlue),
                    onSelected: (value) {
                      if (value == "edit") {
                        _showComingSoonDialog();
                      } else if (value == "delete") {
                        _deleteProduct(product.id);
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: "edit",
                        child: Text("Edit", style: TextStyle(color: deepNavyBlue)),
                      ),
                      PopupMenuItem(
                        value: "delete",
                        child: Text("Delete", style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          _buildSuggestionsSection(),
          const SizedBox(height: 32),
          _buildAnimatedBoostButton(),
        ],
      ),
    );
  }

  Widget _buildAnalyticsCard() {
    Map<String, int> categoryCounts = {};
    for (var product in _products) {
      String category = product.category;
      categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;
    }

    final pieChartSections = categoryCounts.entries.map((entry) {
      final category = entry.key;
      final count = entry.value;
      return PieChartSectionData(
        value: count.toDouble(),
        title: '$category\n($count)',
        color: deepNavyBlue,
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: whiteBackground,
        ),
      );
    }).toList();
    
    return Card(
      color: whiteSmoke,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: deepNavyBlue, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Products by Category",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: deepNavyBlue),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: pieChartSections,
                  sectionsSpace: 4,
                  centerSpaceRadius: 40,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductRatingsBarChart() {
    // Calculate the counts for each rating range
    Map<String, int> ratingCounts = {
      '0.0': 0,
      '1.0-1.9': 0,
      '2.0-2.9': 0,
      '3.0-3.9': 0,
      '4.0-4.9': 0,
      '5.0': 0,
    };

    for (var product in _products) {
      if (product.averageRating == 0.0) {
        ratingCounts['0.0'] = (ratingCounts['0.0'] ?? 0) + 1;
      } else if (product.averageRating >= 1.0 && product.averageRating < 2.0) {
        ratingCounts['1.0-1.9'] = (ratingCounts['1.0-1.9'] ?? 0) + 1;
      } else if (product.averageRating >= 2.0 && product.averageRating < 3.0) {
        ratingCounts['2.0-2.9'] = (ratingCounts['2.0-2.9'] ?? 0) + 1;
      } else if (product.averageRating >= 3.0 && product.averageRating < 4.0) {
        ratingCounts['3.0-3.9'] = (ratingCounts['3.0-3.9'] ?? 0) + 1;
      } else if (product.averageRating >= 4.0 && product.averageRating < 5.0) {
        ratingCounts['4.0-4.9'] = (ratingCounts['4.0-4.9'] ?? 0) + 1;
      } else if (product.averageRating == 5.0) {
        ratingCounts['5.0'] = (ratingCounts['5.0'] ?? 0) + 1;
      }
    }
    
    final barGroups = ratingCounts.entries.toList().asMap().entries.map((entry) {
      final index = entry.key;
      final ratingRange = entry.value.key;
      final count = entry.value.value;
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: count.toDouble(),
            color: greenYellow,
            width: 20,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
    }).toList();

    return Card(
      color: whiteSmoke,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: deepNavyBlue, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "📊 Products by Rating",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: deepNavyBlue),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  barGroups: barGroups,
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final int index = value.toInt();
                          if (index >= 0 && index < ratingCounts.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                ratingCounts.keys.elementAt(index),
                                style: const TextStyle(
                                    color: deepNavyBlue,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() == value) {
                            return Text(
                              value.toInt().toString(),
                              style: const TextStyle(color: deepNavyBlue, fontSize: 12),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: deepNavyBlue.withOpacity(0.2),
                        strokeWidth: 1,
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Tips for Success",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: deepNavyBlue,
          ),
        ),
        const SizedBox(height: 16),
        _buildTipCard(
          icon: Icons.lightbulb_outline,
          text: "Add more photos to your products to attract more buyers.",
        ),
        _buildTipCard(
          icon: Icons.star_outline,
          text: "Encourage customers to leave reviews.",
        ),
        _buildTipCard(
          icon: Icons.check_circle_outline,
          text: "Provide high-quality products consistently.",
        ),
        _buildTipCard(
          icon: Icons.description_outlined,
          text: "Write detailed and accurate product descriptions.",
        ),
        _buildTipCard(
          icon: Icons.support_agent,
          text: "Offer excellent customer service.",
        ),
        const SizedBox(height: 20),
        const Text(
          "🌟 Benefits of Higher Ratings",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: deepNavyBlue,
          ),
        ),
        const SizedBox(height: 8),
        _buildBenefitText("Increases buyer trust and confidence."),
        _buildBenefitText("Boosts chances of repeat customers."),
        _buildBenefitText("Makes your products rank higher in searches."),
        _buildBenefitText("Improves your overall vendor reputation."),
      ],
    );
  }

  Widget _buildTipCard({required IconData icon, required String text}) {
    return Card(
      color: whiteSmoke,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: deepNavyBlue, width: 1.5),
      ),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: Icon(icon, color: greenYellow),
        title: Text(
          text,
          style: const TextStyle(color: deepNavyBlue),
        ),
      ),
    );
  }

  Widget _buildBenefitText(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          const Icon(Icons.check, color: deepNavyBlue, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: deepNavyBlue),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildAnimatedBoostButton() {
    return Center(
      child: ScaleTransition(
        scale: Tween(begin: 1.0, end: 1.1).animate(CurvedAnimation(
          parent: _animationController,
          curve: Curves.easeInOut,
        )),
        child: ElevatedButton.icon(
          onPressed: _showComingSoonDialog,
          icon: const Icon(Icons.trending_up, color: greenYellow),
          label: const Text("Boost My Products Visibility",
              style: TextStyle(color: greenYellow)),
          style: ElevatedButton.styleFrom(
            backgroundColor: deepNavyBlue,
            padding:
                const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
