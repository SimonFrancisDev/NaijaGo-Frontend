import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart'; // For price formatting
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import '../../constants.dart';
import '../../models/product.dart';
import '../../providers/cart_provider.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product product;
  final String heroTag;

  const ProductDetailScreen({
    super.key,
    required this.product,
    required this.heroTag,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  bool _isSaved = false;
  bool _isLoadingSave = false;

  final TextEditingController _commentController = TextEditingController();
  int _userRating = 0;
  bool _isSubmittingReview = false;

  List<Product> _relatedProducts = [];
  bool _isLoadingRelated = true;

  @override
  void initState() {
    super.initState();
    _checkIfProductIsSaved();
    _fetchRelatedProducts();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _checkIfProductIsSaved() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('jwt_token');

    if (token == null) return;

    try {
      final Uri url = Uri.parse('$baseUrl/api/auth/me');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final List<dynamic> savedItems = responseData['savedItems'] ?? [];
        setState(() {
          _isSaved = savedItems.contains(widget.product.id);
        });
      }
    } catch (e) {
      debugPrint('Error checking saved status: $e');
    }
  }

  Future<void> _fetchRelatedProducts() async {
    setState(() => _isLoadingRelated = true);

    try {
      final String encodedCategory =
          Uri.encodeComponent(widget.product.category ?? '');
      final Uri url = Uri.parse('$baseUrl/api/products?category=$encodedCategory');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final products =
            data.map((e) => Product.fromJson(e)).toList().cast<Product>();

        setState(() {
          _relatedProducts =
              products.where((p) => p.id != widget.product.id).toList();
          _isLoadingRelated = false;
        });
      } else {
        setState(() => _isLoadingRelated = false);
      }
    } catch (e) {
      debugPrint('Error fetching related products: $e');
      setState(() => _isLoadingRelated = false);
    }
  }

  Future<void> _toggleSaveProduct() async {
    setState(() {
      _isLoadingSave = true;
    });

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('jwt_token');

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to save items.')),
      );
      setState(() => _isLoadingSave = false);
      return;
    }

    try {
      final String endpoint = _isSaved
          ? '$baseUrl/api/auth/saved-items/${widget.product.id}'
          : '$baseUrl/api/auth/saved-items';

      final http.Response response = _isSaved
          ? await http.delete(
              Uri.parse(endpoint),
              headers: {
                'Content-Type': 'application/json; charset=UTF-8',
                'Authorization': 'Bearer $token',
              },
            )
          : await http.post(
              Uri.parse(endpoint),
              headers: {
                'Content-Type': 'application/json; charset=UTF-8',
                'Authorization': 'Bearer $token',
              },
              body: jsonEncode({'productId': widget.product.id}),
            );

      final Map<String, dynamic> responseData = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() {
          _isSaved = !_isSaved;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(responseData['message'] ??
                (_isSaved ? 'Product saved!' : 'Product unsaved.')),
            backgroundColor: _isSaved ? Colors.green : Colors.orange,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(responseData['message'] ?? 'Action failed.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e')),
      );
    } finally {
      setState(() => _isLoadingSave = false);
    }
  }

  Future<void> _submitReview() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('jwt_token');

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to submit a review.')),
      );
      return;
    }

    if (_userRating == 0 || _commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a rating and comment.')),
      );
      return;
    }

    setState(() => _isSubmittingReview = true);

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/reviews'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'productId': widget.product.id,
          'rating': _userRating,
          'comment': _commentController.text.trim(),
        }),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Review submitted successfully!')),
        );
        setState(() {
          _commentController.clear();
          _userRating = 0;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(responseData['message'] ?? 'Submission failed')),
        );
      }
    } catch (e) {
      debugPrint('Review error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isSubmittingReview = false);
    }
  }

  // ── Open full-screen image gallery when tapping any image ──
  void _openImageGallery(int initialIndex) {
    final allImages = widget.product.imageUrls;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Stack(
              children: [
                PhotoViewGallery.builder(
                  scrollPhysics: const BouncingScrollPhysics(),
                  builder: (BuildContext context, int index) {
                    return PhotoViewGalleryPageOptions(
                      imageProvider: NetworkImage(allImages[index]),
                      initialScale: PhotoViewComputedScale.contained,
                      heroAttributes: PhotoViewHeroAttributes(tag: 'image_$index'),
                      minScale: PhotoViewComputedScale.contained * 0.8,
                      maxScale: PhotoViewComputedScale.covered * 3.0,
                    );
                  },
                  itemCount: allImages.length,
                  loadingBuilder: (context, event) => Center(
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        value: event == null
                            ? 0
                            : event.cumulativeBytesLoaded / (event.expectedTotalBytes ?? 1),
                        color: Colors.white,
                      ),
                    ),
                  ),
                  backgroundDecoration: const BoxDecoration(color: Colors.black),
                  pageController: PageController(initialPage: initialIndex),
                ),
                Positioned(
                  top: 16,
                  right: 16,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 32),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductImage() {
    final imageUrl = widget.product.imageUrls.isNotEmpty
        ? widget.product.imageUrls.first
        : 'https://placehold.co/400x300/CCCCCC/000000?text=No+Image';

    return GestureDetector(
      onTap: () => _openImageGallery(0),
      child: Hero(
        tag: widget.heroTag,
        child: Container(
          height: 350,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
            child: Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey[200],
                  child: Center(
                    child: Icon(Icons.image_not_supported,
                        size: 80, color: Colors.grey[600]),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExtraImagesGallery() {
    final extraImages = widget.product.imageUrls.skip(1).toList();

    if (extraImages.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 10.0),
      child: SizedBox(
        height: 80,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: extraImages.length,
          separatorBuilder: (context, index) => const SizedBox(width: 10),
          itemBuilder: (context, index) {
            final imageUrl = extraImages[index];
            return GestureDetector(
              onTap: () => _openImageGallery(index + 1),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: Image.network(
                  imageUrl,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 80,
                      height: 80,
                      color: Colors.grey[200],
                      child: const Center(
                        child: Icon(Icons.image_not_supported,
                            size: 30, color: Colors.grey),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Formatted price with commas (e.g. ₦1,234,567.00) ──
  String _formatPrice(double price) {
    final formatter = NumberFormat.currency(
      locale: 'en_NG',
      symbol: '₦',
      decimalDigits: 2,
    );
    return formatter.format(price);
  }

  Widget _buildPriceAndName() {
    const Color deepNavyBlue = Color(0xFF0A2A66);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.product.name,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: deepNavyBlue,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              _formatPrice(widget.product.price),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                widget.product.stockQuantity > 0 ? 'In Stock' : 'Out of Stock',
                style: TextStyle(
                  color: widget.product.stockQuantity > 0
                      ? Colors.green.shade700
                      : Colors.red.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProductDetails() {
    const Color deepNavyBlue = Color(0xFF0A2A66);
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.category_outlined,
                    size: 20, color: deepNavyBlue),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Category: ${widget.product.category ?? 'N/A'}',
                    style: const TextStyle(
                        fontSize: 16,
                        color: deepNavyBlue,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                const Icon(Icons.store_outlined,
                    size: 20, color: deepNavyBlue),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Sold by: ${widget.product.vendorBusinessName ?? 'Unknown Vendor'}',
                    style: const TextStyle(
                        fontSize: 16,
                        color: deepNavyBlue,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Color(0xFF0A2A66),
        ),
      ),
    );
  }

  Widget _buildDescriptionCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          widget.product.description ?? 'No description available.',
          style: TextStyle(fontSize: 15, height: 1.6, color: Colors.grey[800]),
        ),
      ),
    );
  }

  Widget _buildRelatedProductsSection() {
    return _isLoadingRelated
        ? const Center(child: CircularProgressIndicator())
        : SizedBox(
            height: 260,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _relatedProducts.length,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (ctx, index) {
                final related = _relatedProducts[index];
                return _buildRelatedProductCard(related);
              },
            ),
          );
  }

  Widget _buildRelatedProductCard(Product product) {
    const Color deepNavyBlue = Color(0xFF0A2A66);
    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    final imageUrl = product.imageUrls.isNotEmpty
        ? product.imageUrls.first
        : 'https://placehold.co/170x130/CCCCCC/000000?text=No+Image';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailScreen(
              product: product,
              heroTag: 'product_${product.id}',
            ),
          ),
        );
      },
      child: Container(
        width: 170,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 10,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Hero(
              tag: 'product_${product.id}',
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16)),
                child: Image.network(
                  imageUrl,
                  height: 130,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 130,
                    color: Colors.grey[200],
                    child: Center(
                      child: Icon(Icons.image_not_supported,
                          color: Colors.grey[600]),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: deepNavyBlue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatPrice(product.price),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 36,
                    child: ElevatedButton(
                      onPressed: product.stockQuantity > 0
                          ? () {
                              cartProvider.addProduct(product);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text('${product.name} added to cart!')),
                              );
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            product.stockQuantity > 0 ? deepNavyBlue : Colors.grey,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      child: Text(
                        product.stockQuantity > 0 ? 'Add to Cart' : 'Out',
                        style: const TextStyle(fontSize: 14),
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
  }

  Widget _buildReviewForm() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return IconButton(
                  icon: Icon(
                    index < _userRating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 32,
                  ),
                  onPressed: () => setState(() => _userRating = index + 1),
                );
              }),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _commentController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Share your thoughts on this product...',
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSubmittingReview ? null : _submitReview,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 46, 188, 131),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                child: _isSubmittingReview
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text(
                        'Submit Review',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color deepNavyBlue = Color(0xFF0A2A66);
    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: deepNavyBlue),
        title: Text(
          widget.product.name,
          style: const TextStyle(
              color: deepNavyBlue, fontWeight: FontWeight.w600, fontSize: 16),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: _isLoadingSave
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(_isSaved ? Icons.bookmark : Icons.bookmark_border,
                      color: deepNavyBlue),
              onPressed: _isLoadingSave ? null : _toggleSaveProduct,
            ),
          )
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.transparent,
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: widget.product.stockQuantity > 0
                      ? () {
                          cartProvider.addProduct(widget.product);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content:
                                  Text('${widget.product.name} added to cart!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      : null,
                  icon: const Icon(Icons.shopping_cart),
                  label: Text(
                      widget.product.stockQuantity > 0
                          ? 'Add to Cart'
                          : 'Out of Stock',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.product.stockQuantity > 0
                        ? deepNavyBlue
                        : Colors.grey,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 6,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProductImage(),
            _buildExtraImagesGallery(),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPriceAndName(),
                  const SizedBox(height: 16),
                  _buildProductDetails(),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Product Description'),
                  _buildDescriptionCard(),
                  const SizedBox(height: 24),
                  if (_relatedProducts.isNotEmpty) ...[
                    _buildSectionTitle('Similar Products'),
                    _buildRelatedProductsSection(),
                    const SizedBox(height: 24),
                  ],
                  _buildSectionTitle('Customer Reviews'),
                  _buildReviewForm(),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';
// import 'package:shared_preferences/shared_preferences.dart';
// import '../../constants.dart';
// import '../../models/product.dart';
// import '../../providers/cart_provider.dart';

// class ProductDetailScreen extends StatefulWidget {
//   final Product product;
//   final String heroTag;

//   const ProductDetailScreen({
//     super.key,
//     required this.product,
//     required this.heroTag,
//   });

//   @override
//   State<ProductDetailScreen> createState() => _ProductDetailScreenState();
// }

// class _ProductDetailScreenState extends State<ProductDetailScreen> {
//   bool _isSaved = false;
//   bool _isLoadingSave = false;

//   final TextEditingController _commentController = TextEditingController();
//   int _userRating = 0;
//   bool _isSubmittingReview = false;

//   List<Product> _relatedProducts = [];
//   bool _isLoadingRelated = true;

//   @override
//   void initState() {
//     super.initState();
//     _checkIfProductIsSaved();
//     _fetchRelatedProducts();
//   }

//   @override
//   void dispose() {
//     _commentController.dispose();
//     super.dispose();
//   }

//   Future<void> _checkIfProductIsSaved() async {
//     final SharedPreferences prefs = await SharedPreferences.getInstance();
//     final String? token = prefs.getString('jwt_token');

//     if (token == null) return;

//     try {
//       final Uri url = Uri.parse('$baseUrl/api/auth/me');
//       final response = await http.get(
//         url,
//         headers: {
//           'Content-Type': 'application/json; charset=UTF-8',
//           'Authorization': 'Bearer $token',
//         },
//       );

//       if (response.statusCode == 200) {
//         final Map<String, dynamic> responseData = jsonDecode(response.body);
//         final List<dynamic> savedItems = responseData['savedItems'] ?? [];
//         setState(() {
//           _isSaved = savedItems.contains(widget.product.id);
//         });
//       }
//     } catch (e) {
//       debugPrint('Error checking saved status: $e');
//     }
//   }

//   Future<void> _fetchRelatedProducts() async {
//     setState(() => _isLoadingRelated = true);

//     try {
//       final String encodedCategory =
//           Uri.encodeComponent(widget.product.category ?? '');
//       final Uri url = Uri.parse('$baseUrl/api/products?category=$encodedCategory');
//       final response = await http.get(url);

//       if (response.statusCode == 200) {
//         final List<dynamic> data = jsonDecode(response.body);
//         final products =
//             data.map((e) => Product.fromJson(e)).toList().cast<Product>();

//         setState(() {
//           _relatedProducts =
//               products.where((p) => p.id != widget.product.id).toList();
//           _isLoadingRelated = false;
//         });
//       } else {
//         setState(() => _isLoadingRelated = false);
//       }
//     } catch (e) {
//       debugPrint('Error fetching related products: $e');
//       setState(() => _isLoadingRelated = false);
//     }
//   }

//   Future<void> _toggleSaveProduct() async {
//     setState(() {
//       _isLoadingSave = true;
//     });

//     final SharedPreferences prefs = await SharedPreferences.getInstance();
//     final String? token = prefs.getString('jwt_token');

//     if (token == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Please log in to save items.')),
//       );
//       setState(() => _isLoadingSave = false);
//       return;
//     }

//     try {
//       final String endpoint = _isSaved
//           ? '$baseUrl/api/auth/saved-items/${widget.product.id}'
//           : '$baseUrl/api/auth/saved-items';

//       final http.Response response = _isSaved
//           ? await http.delete(
//               Uri.parse(endpoint),
//               headers: {
//                 'Content-Type': 'application/json; charset=UTF-8',
//                 'Authorization': 'Bearer $token',
//               },
//             )
//           : await http.post(
//               Uri.parse(endpoint),
//               headers: {
//                 'Content-Type': 'application/json; charset=UTF-8',
//                 'Authorization': 'Bearer $token',
//               },
//               body: jsonEncode({'productId': widget.product.id}),
//             );

//       final Map<String, dynamic> responseData = jsonDecode(response.body);

//       if (response.statusCode == 200 || response.statusCode == 201) {
//         setState(() {
//           _isSaved = !_isSaved;
//         });
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text(responseData['message'] ??
//                 (_isSaved ? 'Product saved!' : 'Product unsaved.')),
//             backgroundColor: _isSaved ? Colors.green : Colors.orange,
//           ),
//         );
//       } else {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text(responseData['message'] ?? 'Action failed.')),
//         );
//       }
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('An error occurred: $e')),
//       );
//     } finally {
//       setState(() => _isLoadingSave = false);
//     }
//   }

//   Future<void> _submitReview() async {
//     final SharedPreferences prefs = await SharedPreferences.getInstance();
//     final String? token = prefs.getString('jwt_token');

//     if (token == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Please log in to submit a review.')),
//       );
//       return;
//     }

//     if (_userRating == 0 || _commentController.text.trim().isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Please provide a rating and comment.')),
//       );
//       return;
//     }

//     setState(() => _isSubmittingReview = true);

//     try {
//       final response = await http.post(
//         Uri.parse('$baseUrl/api/reviews'),
//         headers: {
//           'Content-Type': 'application/json',
//           'Authorization': 'Bearer $token',
//         },
//         body: jsonEncode({
//           'productId': widget.product.id,
//           'rating': _userRating,
//           'comment': _commentController.text.trim(),
//         }),
//       );

//       final responseData = jsonDecode(response.body);

//       if (response.statusCode == 201) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Review submitted successfully!')),
//         );
//         setState(() {
//           _commentController.clear();
//           _userRating = 0;
//         });
//       } else {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//               content: Text(responseData['message'] ?? 'Submission failed')),
//         );
//       }
//     } catch (e) {
//       debugPrint('Review error: $e');
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error: $e')),
//       );
//     } finally {
//       setState(() => _isSubmittingReview = false);
//     }
//   }

//   Widget _buildExtraImagesGallery() {
//     // Skip the first image, which is the main image already displayed.
//     // This works because the Product.fromJson now ensures all images are in imageUrls,
//     // and the first one is always the main one.
//     final extraImages = widget.product.imageUrls.skip(1).toList();

//     if (extraImages.isEmpty) {
//       return const SizedBox.shrink(); // Hide if there are no extra images
//     }

//     return Padding(
//       padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 10.0),
//       child: SizedBox(
//         height: 80, // Height of the horizontal list of thumbnails
//         child: ListView.separated(
//           scrollDirection: Axis.horizontal,
//           itemCount: extraImages.length,
//           separatorBuilder: (context, index) => const SizedBox(width: 10),
//           itemBuilder: (context, index) {
//             final imageUrl = extraImages[index];
//             return ClipRRect(
//               borderRadius: BorderRadius.circular(8.0),
//               child: Image.network(
//                 imageUrl,
//                 width: 80,
//                 height: 80,
//                 fit: BoxFit.cover,
//                 errorBuilder: (context, error, stackTrace) {
//                   return Container(
//                     width: 80,
//                     height: 80,
//                     color: Colors.grey[200],
//                     child: const Center(
//                       child: Icon(Icons.image_not_supported,
//                           size: 30, color: Colors.grey),
//                     ),
//                   );
//                 },
//               ),
//             );
//           },
//         ),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     const Color deepNavyBlue = Color(0xFF0A2A66);
//     final cartProvider = Provider.of<CartProvider>(context, listen: false);

//     return Scaffold(
//       backgroundColor: Colors.grey[100],
//       appBar: AppBar(
//         backgroundColor: Colors.white,
//         elevation: 0,
//         iconTheme: const IconThemeData(color: deepNavyBlue),
//         title: Text(
//           widget.product.name,
//           style: const TextStyle(
//               color: deepNavyBlue, fontWeight: FontWeight.w600, fontSize: 16),
//           maxLines: 1,
//           overflow: TextOverflow.ellipsis,
//         ),
//         actions: [
//           Padding(
//             padding: const EdgeInsets.only(right: 8.0),
//             child: IconButton(
//               icon: _isLoadingSave
//                   ? const SizedBox(
//                       width: 24,
//                       height: 24,
//                       child: CircularProgressIndicator(strokeWidth: 2))
//                   : Icon(_isSaved ? Icons.bookmark : Icons.bookmark_border,
//                       color: deepNavyBlue),
//               onPressed: _isLoadingSave ? null : _toggleSaveProduct,
//             ),
//           )
//         ],
//       ),
//       bottomNavigationBar: SafeArea(
//         child: Container(
//           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//           color: Colors.transparent,
//           child: Row(
//             children: [
//               Expanded(
//                 child: ElevatedButton.icon(
//                   onPressed: widget.product.stockQuantity > 0
//                       ? () {
//                           cartProvider.addProduct(widget.product);
//                           ScaffoldMessenger.of(context).showSnackBar(
//                             SnackBar(
//                               content:
//                                   Text('${widget.product.name} added to cart!'),
//                               backgroundColor: Colors.green,
//                             ),
//                           );
//                         }
//                       : null,
//                   icon: const Icon(Icons.shopping_cart),
//                   label: Text(
//                       widget.product.stockQuantity > 0
//                           ? 'Add to Cart'
//                           : 'Out of Stock',
//                       style: const TextStyle(
//                           fontSize: 16, fontWeight: FontWeight.bold)),
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: widget.product.stockQuantity > 0
//                         ? deepNavyBlue
//                         : Colors.grey,
//                     padding: const EdgeInsets.symmetric(vertical: 14),
//                     shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(12)),
//                     elevation: 6,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//       body: SingleChildScrollView(
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             _buildProductImage(),
//             _buildExtraImagesGallery(),
//             const SizedBox(height: 18),
//             Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 20.0),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   _buildPriceAndName(),
//                   const SizedBox(height: 16),
//                   _buildProductDetails(),
//                   const SizedBox(height: 24),
//                   _buildSectionTitle('Product Description'),
//                   _buildDescriptionCard(),
//                   const SizedBox(height: 24),
//                   if (_relatedProducts.isNotEmpty) ...[
//                     _buildSectionTitle('Similar Products'),
//                     _buildRelatedProductsSection(),
//                     const SizedBox(height: 24),
//                   ],
//                   _buildSectionTitle('Customer Reviews'),
//                   _buildReviewForm(),
//                   const SizedBox(height: 80),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildProductImage() {
//     // 💡 FIX: Updated index access [0] to .first for main product image,
//     // ensuring robust access and consistency with other screens.
//     final imageUrl = widget.product.imageUrls.isNotEmpty
//         ? widget.product.imageUrls.first
//         : 'https://placehold.co/400x300/CCCCCC/000000?text=No+Image';

//     return Stack(
//       children: [
//         Hero(
//           tag: widget.heroTag,
//           child: Container(
//             height: 350,
//             width: double.infinity,
//             decoration: BoxDecoration(
//               borderRadius: const BorderRadius.vertical(
//                   bottom: Radius.circular(30)),
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.black.withOpacity(0.1),
//                   blurRadius: 15,
//                   offset: const Offset(0, 8),
//                 ),
//               ],
//             ),
//             child: ClipRRect(
//               borderRadius: const BorderRadius.vertical(
//                   bottom: Radius.circular(30)),
//               child: Image.network(
//                 imageUrl, // Use the safely determined imageUrl
//                 fit: BoxFit.cover,
//                 errorBuilder: (context, error, stackTrace) {
//                   return Container(
//                     color: Colors.grey[200],
//                     child: Center(
//                       child: Icon(Icons.image_not_supported,
//                           size: 80, color: Colors.grey[600]),
//                     ),
//                   );
//                 },
//               ),
//             ),
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildPriceAndName() {
//     const Color deepNavyBlue = Color(0xFF0A2A66);
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           widget.product.name,
//           style: const TextStyle(
//             fontSize: 26,
//             fontWeight: FontWeight.bold,
//             color: deepNavyBlue,
//             letterSpacing: -0.5,
//           ),
//         ),
//         const SizedBox(height: 8),
//         Row(
//           crossAxisAlignment: CrossAxisAlignment.baseline,
//           textBaseline: TextBaseline.alphabetic,
//           children: [
//             Text(
//               '₦${widget.product.price.toStringAsFixed(2)}',
//               style: const TextStyle(
//                 fontSize: 28,
//                 fontWeight: FontWeight.w800,
//                 color: Colors.green,
//               ),
//             ),
//             const SizedBox(width: 12),
//             Container(
//               padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
//               decoration: BoxDecoration(
//                 color: Colors.green.withOpacity(0.15),
//                 borderRadius: BorderRadius.circular(20),
//               ),
//               child: Text(
//                 widget.product.stockQuantity > 0 ? 'In Stock' : 'Out of Stock',
//                 style: TextStyle(
//                   color: widget.product.stockQuantity > 0
//                       ? Colors.green.shade700
//                       : Colors.red.shade700,
//                   fontWeight: FontWeight.bold,
//                   fontSize: 12,
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ],
//     );
//   }

//   Widget _buildProductDetails() {
//     const Color deepNavyBlue = Color(0xFF0A2A66);
//     return Card(
//       elevation: 4,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//       child: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           children: [
//             Row(
//               children: [
//                 const Icon(Icons.category_outlined,
//                     size: 20, color: deepNavyBlue),
//                 const SizedBox(width: 10),
//                 Expanded(
//                   child: Text(
//                     'Category: ${widget.product.category}',
//                     style: const TextStyle(
//                         fontSize: 16,
//                         color: deepNavyBlue,
//                         fontWeight: FontWeight.w500),
//                   ),
//                 ),
//               ],
//             ),
//             const Divider(height: 24),
//             Row(
//               children: [
//                 const Icon(Icons.store_outlined,
//                     size: 20, color: deepNavyBlue),
//                 const SizedBox(width: 10),
//                 Expanded(
//                   child: Text(
//                     'Sold by: ${widget.product.vendorBusinessName ?? 'Unknown Vendor'}',
//                     style: const TextStyle(
//                         fontSize: 16,
//                         color: deepNavyBlue,
//                         fontWeight: FontWeight.w500),
//                   ),
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildSectionTitle(String title) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 8.0),
//       child: Text(
//         title,
//         style: const TextStyle(
//           fontSize: 20,
//           fontWeight: FontWeight.bold,
//           color: Color(0xFF0A2A66),
//         ),
//       ),
//     );
//   }

//   Widget _buildDescriptionCard() {
//     return Card(
//       elevation: 4,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//       child: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Text(
//           widget.product.description ?? '',
//           style: TextStyle(fontSize: 15, height: 1.6, color: Colors.grey[800]),
//         ),
//       ),
//     );
//   }

//   Widget _buildRelatedProductsSection() {
//     return _isLoadingRelated
//         ? const Center(child: CircularProgressIndicator())
//         : SizedBox(
//             height: 260,
//             child: ListView.separated(
//               scrollDirection: Axis.horizontal,
//               itemCount: _relatedProducts.length,
//               separatorBuilder: (_, __) => const SizedBox(width: 16),
//               itemBuilder: (ctx, index) {
//                 final related = _relatedProducts[index];
//                 return _buildRelatedProductCard(related);
//               },
//             ),
//           );
//   }

//   Widget _buildRelatedProductCard(Product product) {
//     const Color deepNavyBlue = Color(0xFF0A2A66);
//     final cartProvider = Provider.of<CartProvider>(context, listen: false);

//     // 💡 FIX: Updated index access [0] to .first for related product images,
//     // ensuring robust access and consistency with other screens.
//     final imageUrl = product.imageUrls.isNotEmpty
//         ? product.imageUrls.first
//         : 'https://placehold.co/170x130/CCCCCC/000000?text=No+Image';

//     return GestureDetector(
//       onTap: () {
//         Navigator.push(
//           context,
//           MaterialPageRoute(
//             builder: (_) => ProductDetailScreen(
//               product: product,
//               heroTag: 'product_${product.id}',
//             ),
//           ),
//         );
//       },
//       child: Container(
//         width: 170,
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.circular(16),
//           boxShadow: [
//             BoxShadow(
//                 color: Colors.black.withOpacity(0.08),
//                 blurRadius: 10,
//                 offset: const Offset(0, 4)),
//           ],
//         ),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Hero(
//               tag: 'product_${product.id}',
//               child: ClipRRect(
//                 borderRadius: const BorderRadius.vertical(
//                     top: Radius.circular(16)),
//                 child: Image.network(
//                   imageUrl, // Use the safely determined imageUrl
//                   height: 130,
//                   width: double.infinity,
//                   fit: BoxFit.cover,
//                   errorBuilder: (context, error, stackTrace) => Container(
//                     height: 130,
//                     color: Colors.grey[200],
//                     child: Center(
//                       child: Icon(Icons.image_not_supported,
//                           color: Colors.grey[600]),
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//             Padding(
//               padding: const EdgeInsets.all(12.0),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     product.name ?? '',
//                     maxLines: 1,
//                     overflow: TextOverflow.ellipsis,
//                     style: const TextStyle(
//                       fontSize: 15,
//                       fontWeight: FontWeight.bold,
//                       color: deepNavyBlue,
//                     ),
//                   ),
//                   const SizedBox(height: 4),
//                   Text(
//                     '₦${product.price.toStringAsFixed(2)}',
//                     style: const TextStyle(
//                       fontSize: 14,
//                       fontWeight: FontWeight.w600,
//                       color: Colors.green,
//                     ),
//                   ),
//                   const SizedBox(height: 8),
//                   SizedBox(
//                     width: double.infinity,
//                     height: 36,
//                     child: ElevatedButton(
//                       onPressed: product.stockQuantity > 0
//                           ? () {
//                               cartProvider.addProduct(product);
//                               ScaffoldMessenger.of(context).showSnackBar(
//                                 SnackBar(
//                                     content: Text('${product.name} added to cart!')),
//                               );
//                             }
//                           : null,
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor:
//                             product.stockQuantity > 0 ? deepNavyBlue : Colors.grey,
//                         padding: EdgeInsets.zero,
//                         shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(10)),
//                         elevation: 0,
//                       ),
//                       child: Text(
//                         product.stockQuantity > 0 ? 'Add to Cart' : 'Out',
//                         style: const TextStyle(fontSize: 14),
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildReviewForm() {
//     return Card(
//       elevation: 4,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//       child: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Row(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: List.generate(5, (index) {
//                 return IconButton(
//                   icon: Icon(
//                     index < _userRating ? Icons.star : Icons.star_border,
//                     color: Colors.amber,
//                     size: 32,
//                   ),
//                   onPressed: () => setState(() => _userRating = index + 1),
//                 );
//               }),
//             ),
//             const SizedBox(height: 16),
//             TextField(
//               controller: _commentController,
//               maxLines: 4,
//               decoration: InputDecoration(
//                 hintText: 'Share your thoughts on this product...',
//                 filled: true,
//                 fillColor: Colors.grey[100],
//                 border: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(12),
//                   borderSide: BorderSide.none,
//                 ),
//                 contentPadding:
//                     const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//               ),
//             ),
//             const SizedBox(height: 16),
//             SizedBox(
//               width: double.infinity,
//               height: 50,
//               child: ElevatedButton(
//                 onPressed: _isSubmittingReview ? null : _submitReview,
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: const Color.fromARGB(255, 46, 188, 131),
//                   shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(12)),
//                   elevation: 2,
//                 ),
//                 child: _isSubmittingReview
//                     ? const SizedBox(
//                         height: 20,
//                         width: 20,
//                         child: CircularProgressIndicator(
//                             strokeWidth: 2, color: Colors.white))
//                     : const Text(
//                         'Submit Review',
//                         style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//                       ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
