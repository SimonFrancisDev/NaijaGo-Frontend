// screens/category_products_screen.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../models/product.dart';
import '../../constants.dart';
import 'product_detail_screen.dart';

class CategoryProductsScreen extends StatefulWidget {
  final String category;

  const CategoryProductsScreen({super.key, required this.category});

  @override
  State<CategoryProductsScreen> createState() => _CategoryProductsScreenState();
}

class _CategoryProductsScreenState extends State<CategoryProductsScreen> {
  List<Product> _filteredProducts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchFilteredProducts();
  }

  Future<void> _fetchFilteredProducts() async {
    final Uri url = Uri.parse('$baseUrl/api/products?category=${Uri.encodeComponent(widget.category)}');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> productsJson = jsonDecode(response.body);
        setState(() {
          _filteredProducts = productsJson.map((json) => Product.fromJson(json)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const deepNavyBlue = Color(0xFF000080);

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.category} Products'),
        backgroundColor: deepNavyBlue,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredProducts.isEmpty
              ? const Center(child: Text("No products found for this category"))
              : GridView.builder(
                  padding: const EdgeInsets.all(16.0),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16.0,
                    mainAxisSpacing: 16.0,
                    childAspectRatio: 0.6,
                  ),
                  itemCount: _filteredProducts.length,
                  itemBuilder: (context, index) {
                    final product = _filteredProducts[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ProductDetailScreen(
                              product: product,
                              heroTag: 'filtered-product-$index',
                            ),
                          ),
                        );
                      },
                      child: Card(
                        child: Column(
                          children: [
                            Image.network(
                              product.imageUrls.isNotEmpty
                                  ? product.imageUrls[0]
                                  : 'https://placehold.co/200x150?text=No+Image',
                              height: 120,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                                  Text('₦${product.price.toStringAsFixed(2)}'),
                                ],
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
