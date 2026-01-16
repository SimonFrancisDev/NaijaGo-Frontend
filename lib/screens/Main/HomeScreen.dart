import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';

// Import your existing files
import '../../constants.dart';
import '../../models/product.dart';
import '../../providers/cart_provider.dart';
import 'product_detail_screen.dart';
import 'categories_screen.dart';
import 'CategoryProductsScreen.dart';

// New screen for flash sales products
class FlashSalesScreen extends StatelessWidget {
  final List<Product> flashSales;

  const FlashSalesScreen({super.key, required this.flashSales});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flash Sales 🔥'),
        backgroundColor: primaryNavy,
        foregroundColor: white,
      ),
      body: flashSales.isEmpty
          ? const Center(
              child: Text(
                'No flash sales products available.',
                style: TextStyle(fontSize: 16),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(16.0),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16.0,
                mainAxisSpacing: 16.0,
                childAspectRatio: 0.65,
              ),
              itemCount: flashSales.length,
              itemBuilder: (context, index) {
                final product = flashSales[index];
                final heroTag = 'flash_sales-${product.id}-$index';
                return ProductCard(
                  product: product,
                  heroTag: heroTag,
                  showFlashBadge: true,
                );
              },
            ),
    );
  }
}

String getTimeBasedGreeting(String firstName) {
  final hour = DateTime.now().hour;

  if (hour < 12) {
    return 'Good Morning, $firstName!';
  } else if (hour < 17) {
    return 'Good Afternoon, $firstName!';
  } else {
    return 'Good Evening, $firstName!';
  }
}

// Search Screen (unchanged)
class SearchScreen extends StatefulWidget {
  final String initialQuery;

  const SearchScreen({super.key, required this.initialQuery});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ProductService _productService = ProductService();
  List<Product> _searchResults = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.initialQuery;
    _performSearch(widget.initialQuery);
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _isLoading = false;
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await _productService.searchProducts(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
        });
      }
    } catch (e) {
      debugPrint('Search error: $e');
      String friendlyMessage = 'An error occurred while searching';

      if (e.toString().contains('404')) {
        friendlyMessage = 'Search feature is not available yet (endpoint missing)';
      } else if (e.toString().contains('500') || e.toString().contains('Server error')) {
        friendlyMessage = 'Server is having issues right now... please try again in 30 seconds';
      } else if (e.toString().contains('timeout') || e.toString().contains('Connection')) {
        friendlyMessage = 'Connection problem. Server might be waking up — try again in 15–30 seconds';
      }

      if (mounted) {
        setState(() {
          _errorMessage = '$friendlyMessage\n\nDetails: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onSubmitted: _performSearch,
          decoration: InputDecoration(
            hintText: 'Search products...',
            hintStyle: const TextStyle(color: white),
            border: InputBorder.none,
            suffixIcon: IconButton(
              icon: const Icon(Icons.search, color: white),
              onPressed: () => _performSearch(_searchController.text),
            ),
          ),
          style: const TextStyle(color: white),
        ),
        backgroundColor: primaryNavy,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryNavy))
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!, textAlign: TextAlign.center))
              : _searchResults.isEmpty
                  ? const Center(child: Text('No products found.'))
                  : GridView.builder(
                      padding: const EdgeInsets.all(16.0),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16.0,
                        mainAxisSpacing: 16.0,
                        childAspectRatio: 0.65,
                      ),
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final product = _searchResults[index];
                        final heroTag = 'search-${product.id}-$index';
                        return ProductCard(product: product, heroTag: heroTag);
                      },
                    ),
    );
  }
}

// Service to handle API calls (unchanged)
class ProductService {
  final String _baseUrl = 'https://naijago-backend.onrender.com';

  Future<List<Product>> fetchFlashSales() => _fetchProducts('/api/products/flashsales');
  Future<List<Product>> fetchNewArrivals() => _fetchProducts('/api/products/newarrivals');
  Future<List<Product>> fetchAllProducts() => _fetchProducts('/api/products');
  Future<List<Product>> fetchProductsByCategory(String category) =>
      _fetchProducts('/api/products/category/$category');
  Future<List<Product>> searchProducts(String query) =>
      _fetchProducts('/api/products/search?q=$query');

  Future<List<Product>> _fetchProducts(String endpoint) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('jwt_token');

    final headers = {
      'Content-Type': 'application/json; charset=UTF-8',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    final response = await http.get(Uri.parse('$_baseUrl$endpoint'), headers: headers);

    debugPrint('API Response for $endpoint: ${response.statusCode}');
    debugPrint('API Response Body: ${response.body}');

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = jsonDecode(response.body);
      return jsonList.map((json) => Product.fromJson(json)).toList();
    } else if (response.statusCode == 401) {
      throw Exception('Unauthorized: Please log in again.');
    } else if (response.statusCode >= 500) {
      throw Exception('Server error: Please try again later.');
    } else {
      throw Exception('Failed to load data from $endpoint: ${response.statusCode}');
    }
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Product> _flashSales = [];
  List<Product> _newArrivals = [];
  List<Product> _recommended = [];
  String? _errorMessage;

  final PageController _bannerController = PageController(viewportFraction: 0.95);
  final PageController _promoController = PageController(viewportFraction: 0.85);

  final TextEditingController _searchController = TextEditingController();

  late final ProductService _productService;

  int _currentBanner = 0;
  int _currentPromo = 0;

  String _userFirstName = 'there'; // fallback
  bool _hasLoadedUserName = false;

  final List<Map<String, String>> _homeCategories = [
    {"image": "assets/categories/smartphones.jpg", "label": "Phones"},
    {"image": "assets/categories/fashion_women.jpg", "label": "Fashion"},
    {"image": "assets/categories/appliances.jpg", "label": "Electronics"},
    {"image": "assets/categories/sporting_goods.jpg", "label": "Sports"},
    {"image": "assets/categories/groceries.jpg", "label": "Supermarket"},
    {"image": "assets/categories/pharmacy.jpg", "label": "Health"},
  ];

  // Cache settings
  static const String _cacheFlashKey = 'cache_flash_sales';
  static const String _cacheNewKey = 'cache_new_arrivals';
  static const String _cacheRecommendedKey = 'cache_recommended';
  static const String _cacheTimestampKey = 'cache_timestamp';
  static const int _cacheExpiryMs = 30 * 60 * 1000; // 30 minutes

  @override
  void initState() {
    super.initState();
    _productService = ProductService();
    _loadUserName();
    _fetchProducts(); // will use cache first
    _startAutoScrollTimers();
  }

  Future<void> _loadUserName() async {
    final prefs = await SharedPreferences.getInstance();
    final userJsonString = prefs.getString('user');

    if (userJsonString != null) {
      final userData = jsonDecode(userJsonString);
      final firstName = userData['firstName'] ?? 'there';

      if (mounted) {
        setState(() {
          _userFirstName = firstName;
          _hasLoadedUserName = true;
        });
      }
    }
  }

  Future<void> _fetchProducts({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    _errorMessage = null;

    // 1. Try to load from cache first (instant UI)
    if (!forceRefresh) {
  final cachedFlash = prefs.getString(_cacheFlashKey);
  final cachedNew = prefs.getString(_cacheNewKey);
  final cachedRecommended = prefs.getString(_cacheRecommendedKey);
  final cacheTimeStr = prefs.getString(_cacheTimestampKey);

  final cacheTime = cacheTimeStr != null ? int.tryParse(cacheTimeStr) : null;

  // Only use cache if it's not expired
  if (cacheTime != null && DateTime.now().millisecondsSinceEpoch - cacheTime < _cacheExpiryMs) {
    if (cachedFlash != null || cachedNew != null || cachedRecommended != null) {
      setState(() {
        // Use an empty list instance to call the extension method
        _flashSales = <Product>[].fromCacheString(cachedFlash);
        _newArrivals = <Product>[].fromCacheString(cachedNew);
        _recommended = <Product>[].fromCacheString(cachedRecommended);
      });
    }
  }
}

    // 2. Fetch fresh data in background
    try {
      final results = await Future.wait([
        _productService.fetchFlashSales(),
        _productService.fetchNewArrivals(),
        _productService.fetchAllProducts(),
      ]);

      if (mounted) {
        setState(() {
          _flashSales = results[0];
          _newArrivals = results[1];
          _recommended = results[2];
        });

        // 3. Save fresh data + timestamp to cache
        await prefs.setString(_cacheFlashKey, results[0].toCacheString());
        await prefs.setString(_cacheNewKey, results[1].toCacheString());
        await prefs.setString(_cacheRecommendedKey, results[2].toCacheString());
        await prefs.setString(_cacheTimestampKey, DateTime.now().millisecondsSinceEpoch.toString());
      }
    } on Exception catch (e) {
      debugPrint('Error fetching products: $e');
      if (mounted) {
        setState(() {
          if (e.toString().contains('Unauthorized')) {
            _errorMessage = 'Session expired. Please log in again.';
          } else if (e.toString().contains('Server error')) {
            _errorMessage = 'Server is currently unavailable. Please try again later.';
          } else {
            _errorMessage = 'An error occurred. Please check your network connection.';
          }
        });
      }
    }
  }

  void _startAutoScrollTimers() {
    final bannerImages = const ["assets/prod_flier1.jpg", "assets/prod_flier2.jpg", "assets/prod_flier3.jpg"];
    final promoBanners = const ["assets/ads1.png", "assets/ads2.png", "assets/ads3.png", "assets/ads4.png", "assets/ads5.png"];

    Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_bannerController.hasClients) {
        final next = (_currentBanner + 1) % bannerImages.length;
        _bannerController.animateToPage(
          next,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOut,
        );
      }
    });

    Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_promoController.hasClients) {
        final next = (_currentPromo + 1) % promoBanners.length;
        _promoController.animateToPage(
          next,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _bannerController.dispose();
    _promoController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildPhoneNumberButton(String phoneNumber) {
    return Expanded(
      child: InkWell(
        onTap: () => _launchPhone(phoneNumber),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.green,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.phone, size: 16, color: white),
              const SizedBox(width: 8),
              Text(
                phoneNumber,
                style: const TextStyle(
                  color: white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launchPhone(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not make a call.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // MAIN STICKY HEADER - Fixed height, no collapsing when scrolling
  Widget _buildPinnedHeader() {
    return SliverAppBar(
      backgroundColor: primaryNavy,
      elevation: 2,
      pinned: true,
      floating: false,
      snap: false,
      automaticallyImplyLeading: false,
      toolbarHeight: 0,
      expandedHeight: 220.0,
      collapsedHeight: 220.0,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          padding: const EdgeInsets.fromLTRB(16, 40, 16, 12),
          color: primaryNavy,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 48,
                decoration: BoxDecoration(
                  color: white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: secondaryBlack.withOpacity(0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (query) {
                    if (query.trim().isNotEmpty) {
                      final normalized = query.toLowerCase().trim();
                      final categoryLabels = _homeCategories
                          .map((cat) => cat['label']!.toLowerCase())
                          .toList();

                      if (categoryLabels.contains(normalized)) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CategoryProductsScreen(category: query),
                          ),
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SearchScreen(initialQuery: query),
                          ),
                        );
                      }
                    }
                  },
                  decoration: InputDecoration(
                    hintText: 'Search products on NaijaGo',
                    hintStyle: const TextStyle(color: lightGrey),
                    prefixIcon: const Icon(Icons.search, color: lightGrey),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear, color: lightGrey),
                      onPressed: () => _searchController.clear(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                getTimeBasedGreeting(_userFirstName),
                style: const TextStyle(
                  color: white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Hotlines for quick Contact',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildPhoneNumberButton('08156761792'),
                  const SizedBox(width: 16),
                  _buildPhoneNumberButton('07044332895'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return const SliverAppBar(
      backgroundColor: primaryNavy,
      elevation: 0,
      pinned: true,
      expandedHeight: 0,
      toolbarHeight: 0,
    );
  }

  Widget _buildBannerCarousel() {
    final banners = const ["assets/prod_flier1.jpg", "assets/prod_flier2.jpg", "assets/prod_flier3.jpg"];

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: PageView.builder(
            controller: _bannerController,
            onPageChanged: (i) => setState(() => _currentBanner = i),
            itemCount: banners.length,
            itemBuilder: (_, i) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    banners[i],
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => Container(
                      color: softGrey,
                      alignment: Alignment.center,
                      child: const Icon(Icons.image_not_supported, size: 48, color: lightGrey),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(banners.length, (i) {
            final active = i == _currentBanner;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: 8,
              width: active ? 24 : 8,
              decoration: BoxDecoration(
                color: active ? primaryNavy : Colors.grey[400],
                borderRadius: BorderRadius.circular(8),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildPromoCarousel() {
    final promoBanners = const ["assets/ads1.png", "assets/ads2.png", "assets/ads3.png", "assets/ads4.png", "assets/ads5.png"];
    return Column(
      children: [
        SizedBox(
          height: 120,
          child: PageView.builder(
            controller: _promoController,
            onPageChanged: (i) => setState(() => _currentPromo = i),
            itemCount: promoBanners.length,
            itemBuilder: (_, i) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    promoBanners[i],
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => Container(
                      color: softGrey,
                      alignment: Alignment.center,
                      child: const Icon(Icons.image_not_supported, size: 48, color: lightGrey),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(promoBanners.length, (i) {
            final active = i == _currentPromo;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: 8,
              width: active ? 24 : 8,
              decoration: BoxDecoration(
                color: active ? primaryNavy : Colors.grey[400],
                borderRadius: BorderRadius.circular(8),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, {VoidCallback? onSeeAll}) {
    final hasAnimation = title.contains('🔥') || title.contains('✨');
    final titleText = hasAnimation ? title.substring(0, title.length - 2).trim() : title;
    final emoji = hasAnimation ? title.substring(title.length - 2).trim() : '';

    return SliverToBoxAdapter(
      child: Container(
        color: Colors.lightGreenAccent[700],
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  titleText,
                  style: const TextStyle(
                    color: primaryNavy,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (hasAnimation)
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: _AnimatedText(
                      text: emoji,
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
              ],
            ),
            if (onSeeAll != null)
              TextButton(
                onPressed: onSeeAll,
                child: const Text(
                  'See all',
                  style: TextStyle(
                    color: primaryNavy,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategories() {
    return Container(
      color: white,
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 1.2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
        ),
        itemCount: _homeCategories.length,
        itemBuilder: (context, index) {
          final cat = _homeCategories[index];
          return _buildCategoryCard(imagePath: cat["image"] as String, label: cat["label"] as String);
        },
      ),
    );
  }

  Widget _buildCategoryCard({required String imagePath, required String label}) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const CategoriesScreen(),
          ),
        );
      },
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: primaryNavy.withOpacity(0.8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                imagePath,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => Container(
                  color: softGrey,
                  alignment: Alignment.center,
                  child: const Icon(Icons.image_not_supported, size: 48, color: lightGrey),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: secondaryBlack,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 32.0),
        child: Stack(
          alignment: Alignment.center,
          children: [
            _SpinningWatermark(),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                SizedBox(height: 8),
                Text(
                  '© 2025 NaijaGo. All rights reserved.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
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
    return Scaffold(
      backgroundColor: softGrey,
      body: RefreshIndicator(
        onRefresh: () => _fetchProducts(forceRefresh: true),
        color: primaryNavy,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildSliverAppBar(),
            _buildPinnedHeader(),
            SliverToBoxAdapter(child: _buildBannerCarousel()),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // Flash Sales section - shows shimmer when empty
            if (_flashSales.isNotEmpty) ...[
              _buildSectionHeader(
                'Flash Sales 🔥',
                onSeeAll: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => FlashSalesScreen(flashSales: _flashSales),
                    ),
                  );
                },
              ),
              SliverToBoxAdapter(
                child: ProductListHorizontal(
                  products: _flashSales,
                  sectionKey: 'flash',
                  showFlashBadge: true,
                  showNewBadge: false,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],

            // Categories section (static - always visible)
            _buildSectionHeader(
              'Categories',
              onSeeAll: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const CategoriesScreen()),
                );
              },
            ),
            SliverToBoxAdapter(child: _buildCategories()),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // New Arrivals section - shows shimmer when empty
            if (_newArrivals.isNotEmpty) ...[
              _buildSectionHeader('New Arrivals ✨', onSeeAll: null),
              SliverToBoxAdapter(
                child: ProductListHorizontal(
                  products: _newArrivals,
                  sectionKey: 'new',
                  showFlashBadge: false,
                  showNewBadge: true,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],

            SliverToBoxAdapter(child: _buildPromoCarousel()),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // Recommended section - shows shimmer when empty
            if (_recommended.isNotEmpty) ...[
              _buildSectionHeader('Recommended For You', onSeeAll: null),
              ProductListGrid(
                products: _recommended,
                sectionKey: 'rec',
              ),
            ],

            // Global error message if something critical fails
            if (_errorMessage != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 50),
                      const SizedBox(height: 10),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red, fontSize: 16),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () => _fetchProducts(forceRefresh: true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryNavy,
                          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30.0),
                          ),
                        ),
                        child: const Text('Retry', style: TextStyle(color: white, fontSize: 16)),
                      ),
                    ],
                  ),
                ),
              ),

            _buildFooter(),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }
}

// Delegate for the pinned header
class _HeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _HeaderDelegate({required this.child});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  double get maxExtent => 180.0;

  @override
  double get minExtent => 120.0;

  @override
  bool shouldRebuild(covariant _HeaderDelegate oldDelegate) {
    return oldDelegate.child != child;
  }
}

class _SpinningWatermark extends StatefulWidget {
  @override
  State<_SpinningWatermark> createState() => _SpinningWatermarkState();
}

class _SpinningWatermarkState extends State<_SpinningWatermark> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 30),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: const AlwaysStoppedAnimation(0.15),
      child: RotationTransition(
        turns: _controller,
        child: ClipOval(
          child: Image.asset(
            'assets/naijago-9.jpg',
            width: 100,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}

class ShimmerLoading extends StatelessWidget {
  final double width;
  final double height;

  const ShimmerLoading({super.key, required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        width: width,
        height: height,
        color: Colors.white,
      ),
    );
  }
}

class ProductListHorizontal extends StatelessWidget {
  final List<Product> products;
  final String sectionKey;
  final bool showFlashBadge;
  final bool showNewBadge;

  const ProductListHorizontal({
    super.key,
    required this.products,
    required this.sectionKey,
    this.showFlashBadge = false,
    this.showNewBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 270,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        scrollDirection: Axis.horizontal,
        itemCount: products.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final product = products[index];
          final heroTag = 'product-$sectionKey-${product.id}-$index';
          return SizedBox(
            width: 160,
            child: ProductCard(
              product: product,
              heroTag: heroTag,
              showFlashBadge: showFlashBadge,
              showNewBadge: showNewBadge,
            ),
          );
        },
      ),
    );
  }
}

class ProductListGrid extends StatelessWidget {
  final List<Product> products;
  final String sectionKey;

  const ProductListGrid({
    super.key,
    required this.products,
    required this.sectionKey,
  });

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return SliverPadding(
        padding: const EdgeInsets.all(16.0),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16.0,
            mainAxisSpacing: 16.0,
            childAspectRatio: 0.65,
          ),
          delegate: SliverChildBuilderDelegate(
            (_, __) => const ShimmerLoading(width: double.infinity, height: 250),
            childCount: 6,
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(16.0),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16.0,
          mainAxisSpacing: 16.0,
          childAspectRatio: 0.65,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final product = products[index];
            final heroTag = 'product-$sectionKey-${product.id}-$index';
            return ProductCard(
              product: product,
              heroTag: heroTag,
            );
          },
          childCount: products.length,
        ),
      ),
    );
  }
}

class ProductCard extends StatelessWidget {
  final Product product;
  final String heroTag;
  final bool showFlashBadge;
  final bool showNewBadge;

  const ProductCard({
    super.key,
    required this.product,
    required this.heroTag,
    this.showFlashBadge = false,
    this.showNewBadge = false,
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
    final cartProvider = Provider.of<CartProvider>(context, listen: false);

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
        color: white,
        elevation: 4,
        shadowColor: secondaryBlack.withOpacity(0.15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                Hero(
                  tag: heroTag,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: CachedNetworkImage(
                      imageUrl: product.imageUrls.isNotEmpty
                          ? product.imageUrls[0]
                          : 'https://placehold.co/400x300/CCCCCC/000000?text=No+Image',
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        height: 120,
                        color: Colors.grey[200],
                        child: const Center(child: CircularProgressIndicator(color: primaryNavy)),
                      ),
                      errorWidget: (context, url, error) => Container(
                        height: 120,
                        color: Colors.grey[200],
                        child: Icon(Icons.image_not_supported, size: 40, color: Colors.grey[600]),
                      ),
                    ),
                  ),
                ),
                if (showFlashBadge)
                  Positioned(
                    left: 8,
                    top: 8,
                    child: _AnimatedBadge(
                      label: 'FLASH SALE',
                      icon: Icons.flash_on,
                      color: Colors.red,
                    ),
                  ),
                if (showNewBadge)
                  Positioned(
                    left: 8,
                    top: 8,
                    child: _AnimatedBadge(
                      label: 'NEW',
                      icon: Icons.star,
                      color: accentGreen,
                    ),
                  ),
              ],
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
                        color: secondaryBlack,
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
                            color: primaryNavy,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Vendor: ${product.vendorBusinessName ?? 'N/A'}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: lightGrey,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                                        content: Text('${product.name} added to cart!'),
                                        backgroundColor: accentGreen,
                                      ),
                                    );
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: product.stockQuantity > 0 ? primaryNavy : Colors.grey[300],
                              foregroundColor: product.stockQuantity > 0 ? white : Colors.grey[700],
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: EdgeInsets.zero,
                              elevation: 0,
                            ),
                            child: Text(
                              product.stockQuantity > 0 ? 'Add to Cart' : 'Out of Stock',
                              style: TextStyle(
                                fontSize: 12,
                                color: product.stockQuantity > 0 ? white : Colors.grey[400],
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

class _AnimatedBadge extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _AnimatedBadge({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  _AnimatedBadgeState createState() => _AnimatedBadgeState();
}

class _AnimatedBadgeState extends State<_AnimatedBadge> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: widget.color.withOpacity(0.5),
              blurRadius: 8,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.icon, size: 14, color: white),
            const SizedBox(width: 4),
            Text(
              widget.label,
              style: const TextStyle(
                color: white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedText extends StatefulWidget {
  final String text;
  final TextStyle style;

  const _AnimatedText({
    required this.text,
    required this.style,
  });

  @override
  State<_AnimatedText> createState() => _AnimatedTextState();
}

class _AnimatedTextState extends State<_AnimatedText> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Text(
        widget.text,
        style: widget.style,
      ),
    );
  }
}

// ── Cache Helpers ── (at the bottom of your file)
extension ProductCache on List<Product> {
  String toCacheString() {
    return jsonEncode(map((p) => p.toJson()).toList());
  }

  // IMPORTANT: Remove 'static' here!
  List<Product> fromCacheString(String? cached) {
    if (cached == null || cached.isEmpty) return [];
    try {
      final list = jsonDecode(cached) as List<dynamic>;
      return list.map((json) => Product.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Cache parse error: $e');
      return [];
    }
  }
}



// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:provider/provider.dart';
// import 'package:intl/intl.dart';
// import 'package:url_launcher/url_launcher.dart';
// import 'dart:async';
// import 'dart:convert';
// import 'package:cached_network_image/cached_network_image.dart';
// import 'package:shimmer/shimmer.dart';

// // Import your existing files
// import '../../constants.dart';
// import '../../models/product.dart';
// import '../../providers/cart_provider.dart';
// import 'product_detail_screen.dart';
// import 'categories_screen.dart';
// import 'CategoryProductsScreen.dart';

// // New screen for flash sales products
// class FlashSalesScreen extends StatelessWidget {
//   final List<Product> flashSales;

//   const FlashSalesScreen({super.key, required this.flashSales});

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Flash Sales 🔥'),
//         backgroundColor: primaryNavy,
//         foregroundColor: white,
//       ),
//       body: flashSales.isEmpty
//           ? const Center(
//               child: Text(
//                 'No flash sales products available.',
//                 style: TextStyle(fontSize: 16),
//               ),
//             )
//           : GridView.builder(
//               padding: const EdgeInsets.all(16.0),
//               gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//                 crossAxisCount: 2,
//                 crossAxisSpacing: 16.0,
//                 mainAxisSpacing: 16.0,
//                 childAspectRatio: 0.65,
//               ),
//               itemCount: flashSales.length,
//               itemBuilder: (context, index) {
//                 final product = flashSales[index];
//                 final heroTag = 'flash_sales-${product.id}-$index';
//                 return ProductCard(
//                   product: product,
//                   heroTag: heroTag,
//                   showFlashBadge: true,
//                 );
//               },
//             ),
//     );
//   }
// }

// String getTimeBasedGreeting(String firstName) {
//   final hour = DateTime.now().hour;

//   if (hour < 12) {
//     return 'Good Morning, $firstName!';
//   } else if (hour < 17) {
//     return 'Good Afternoon, $firstName!';
//   } else {
//     return 'Good Evening, $firstName!';
//   }
// }

// // Search Screen
// class SearchScreen extends StatefulWidget {
//   final String initialQuery;

//   const SearchScreen({super.key, required this.initialQuery});

//   @override
//   State<SearchScreen> createState() => _SearchScreenState();
// }

// class _SearchScreenState extends State<SearchScreen> {
//   final TextEditingController _searchController = TextEditingController();
//   final ProductService _productService = ProductService();
//   List<Product> _searchResults = [];
//   bool _isLoading = true;
//   String? _errorMessage;

//   @override
//   void initState() {
//     super.initState();
//     _searchController.text = widget.initialQuery;
//     _performSearch(widget.initialQuery);
//   }

//   Future<void> _performSearch(String query) async {
//     if (query.isEmpty) {
//       setState(() {
//         _isLoading = false;
//         _searchResults = [];
//       });
//       return;
//     }

//     setState(() {
//       _isLoading = true;
//       _errorMessage = null;
//     });

//     try {
//       final results = await _productService.searchProducts(query);
//       if (mounted) {
//         setState(() {
//           _searchResults = results;
//         });
//       }
//     } catch (e) {
//       debugPrint('Search error: $e');
//       String friendlyMessage = 'An error occurred while searching';

//       if (e.toString().contains('404')) {
//         friendlyMessage = 'Search feature is not available yet (endpoint missing)';
//       } else if (e.toString().contains('500') || e.toString().contains('Server error')) {
//         friendlyMessage = 'Server is having issues right now... please try again in 30 seconds';
//       } else if (e.toString().contains('timeout') || e.toString().contains('Connection')) {
//         friendlyMessage = 'Connection problem. Server might be waking up — try again in 15–30 seconds';
//       }

//       if (mounted) {
//         setState(() {
//           _errorMessage = '$friendlyMessage\n\nDetails: $e';
//         });
//       }
//     } finally {
//       if (mounted) {
//         setState(() => _isLoading = false);
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: TextField(
//           controller: _searchController,
//           autofocus: true,
//           textInputAction: TextInputAction.search,
//           onSubmitted: _performSearch,
//           decoration: InputDecoration(
//             hintText: 'Search products...',
//             hintStyle: const TextStyle(color: white),
//             border: InputBorder.none,
//             suffixIcon: IconButton(
//               icon: const Icon(Icons.search, color: white),
//               onPressed: () => _performSearch(_searchController.text),
//             ),
//           ),
//           style: const TextStyle(color: white),
//         ),
//         backgroundColor: primaryNavy,
//       ),
//       body: _isLoading
//           ? const Center(child: CircularProgressIndicator(color: primaryNavy))
//           : _errorMessage != null
//               ? Center(child: Text(_errorMessage!, textAlign: TextAlign.center))
//               : _searchResults.isEmpty
//                   ? const Center(child: Text('No products found.'))
//                   : GridView.builder(
//                       padding: const EdgeInsets.all(16.0),
//                       gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//                         crossAxisCount: 2,
//                         crossAxisSpacing: 16.0,
//                         mainAxisSpacing: 16.0,
//                         childAspectRatio: 0.65,
//                       ),
//                       itemCount: _searchResults.length,
//                       itemBuilder: (context, index) {
//                         final product = _searchResults[index];
//                         final heroTag = 'search-${product.id}-$index';
//                         return ProductCard(product: product, heroTag: heroTag);
//                       },
//                     ),
//     );
//   }
// }

// // Service to handle API calls
// class ProductService {
//   final String _baseUrl = 'https://naijago-backend.onrender.com';

//   Future<List<Product>> fetchFlashSales() => _fetchProducts('/api/products/flashsales');
//   Future<List<Product>> fetchNewArrivals() => _fetchProducts('/api/products/newarrivals');
//   Future<List<Product>> fetchAllProducts() => _fetchProducts('/api/products');
//   Future<List<Product>> fetchProductsByCategory(String category) =>
//       _fetchProducts('/api/products/category/$category');
//   Future<List<Product>> searchProducts(String query) =>
//       _fetchProducts('/api/products/search?q=$query');

//   Future<List<Product>> _fetchProducts(String endpoint) async {
//     final SharedPreferences prefs = await SharedPreferences.getInstance();
//     final String? token = prefs.getString('jwt_token');

//     final headers = {
//       'Content-Type': 'application/json; charset=UTF-8',
//       if (token != null) 'Authorization': 'Bearer $token',
//     };

//     final response = await http.get(Uri.parse('$_baseUrl$endpoint'), headers: headers);

//     debugPrint('API Response for $endpoint: ${response.statusCode}');
//     debugPrint('API Response Body: ${response.body}');

//     if (response.statusCode == 200) {
//       final List<dynamic> jsonList = jsonDecode(response.body);
//       return jsonList.map((json) => Product.fromJson(json)).toList();
//     } else if (response.statusCode == 401) {
//       throw Exception('Unauthorized: Please log in again.');
//     } else if (response.statusCode >= 500) {
//       throw Exception('Server error: Please try again later.');
//     } else {
//       throw Exception('Failed to load data from $endpoint: ${response.statusCode}');
//     }
//   }
// }

// class HomeScreen extends StatefulWidget {
//   const HomeScreen({super.key});

//   @override
//   State<HomeScreen> createState() => _HomeScreenState();
// }

// class _HomeScreenState extends State<HomeScreen> {
//   List<Product> _flashSales = [];
//   List<Product> _newArrivals = [];
//   List<Product> _recommended = [];
//   String? _errorMessage;

//   final PageController _bannerController = PageController(viewportFraction: 0.95);
//   final PageController _promoController = PageController(viewportFraction: 0.85);

//   final TextEditingController _searchController = TextEditingController();

//   late final ProductService _productService;

//   int _currentBanner = 0;
//   int _currentPromo = 0;

//   String _userFirstName = 'there'; // fallback
//   bool _hasLoadedUserName = false;

//   final List<Map<String, String>> _homeCategories = [
//     {"image": "assets/categories/smartphones.jpg", "label": "Phones"},
//     {"image": "assets/categories/fashion_women.jpg", "label": "Fashion"},
//     {"image": "assets/categories/appliances.jpg", "label": "Electronics"},
//     {"image": "assets/categories/sporting_goods.jpg", "label": "Sports"},
//     {"image": "assets/categories/groceries.jpg", "label": "Supermarket"},
//     {"image": "assets/categories/pharmacy.jpg", "label": "Health"},
//   ];

//   @override
//   void initState() {
//     super.initState();
//     _productService = ProductService();
//     _loadUserName();
//     _fetchProducts();
//     _startAutoScrollTimers();
//   }

//   Future<void> _loadUserName() async {
//     final prefs = await SharedPreferences.getInstance();
//     final userJsonString = prefs.getString('user');

//     if (userJsonString != null) {
//       final userData = jsonDecode(userJsonString);
//       final firstName = userData['firstName'] ?? 'there';

//       if (mounted) {
//         setState(() {
//           _userFirstName = firstName;
//           _hasLoadedUserName = true;
//         });
//       }
//     }
//   }

//   Future<void> _fetchProducts() async {
//     // Removed global _isLoading - sections will show shimmer independently
//     _errorMessage = null;

//     try {
//       final results = await Future.wait([
//         _productService.fetchFlashSales(),
//         _productService.fetchNewArrivals(),
//         _productService.fetchAllProducts(),
//       ]);

//       if (mounted) {
//         setState(() {
//           _flashSales = results[0];
//           _newArrivals = results[1];
//           _recommended = results[2];
//         });
//       }
//     } on Exception catch (e) {
//       debugPrint('Error fetching products: $e');
//       if (mounted) {
//         setState(() {
//           if (e.toString().contains('Unauthorized')) {
//             _errorMessage = 'Session expired. Please log in again.';
//           } else if (e.toString().contains('Server error')) {
//             _errorMessage = 'Server is currently unavailable. Please try again later.';
//           } else {
//             _errorMessage = 'An error occurred. Please check your network connection.';
//           }
//         });
//       }
//     }
//   }

//   void _startAutoScrollTimers() {
//     final bannerImages = const ["assets/prod_flier1.jpg", "assets/prod_flier2.jpg", "assets/prod_flier3.jpg"];
//     final promoBanners = const ["assets/ads1.png", "assets/ads2.png", "assets/ads3.png", "assets/ads4.png", "assets/ads5.png"];

//     Timer.periodic(const Duration(seconds: 4), (timer) {
//       if (!mounted) {
//         timer.cancel();
//         return;
//       }
//       if (_bannerController.hasClients) {
//         final next = (_currentBanner + 1) % bannerImages.length;
//         _bannerController.animateToPage(
//           next,
//           duration: const Duration(milliseconds: 450),
//           curve: Curves.easeOut,
//         );
//       }
//     });

//     Timer.periodic(const Duration(seconds: 5), (timer) {
//       if (!mounted) {
//         timer.cancel();
//         return;
//       }
//       if (_promoController.hasClients) {
//         final next = (_currentPromo + 1) % promoBanners.length;
//         _promoController.animateToPage(
//           next,
//           duration: const Duration(milliseconds: 450),
//           curve: Curves.easeOut,
//         );
//       }
//     });
//   }

//   @override
//   void dispose() {
//     _bannerController.dispose();
//     _promoController.dispose();
//     _searchController.dispose();
//     super.dispose();
//   }

//   Widget _buildPhoneNumberButton(String phoneNumber) {
//     return Expanded(
//       child: InkWell(
//         onTap: () => _launchPhone(phoneNumber),
//         child: Container(
//           padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//           decoration: BoxDecoration(
//             color: Colors.green,
//             borderRadius: BorderRadius.circular(8),
//           ),
//           child: Row(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               const Icon(Icons.phone, size: 16, color: white),
//               const SizedBox(width: 8),
//               Text(
//                 phoneNumber,
//                 style: const TextStyle(
//                   color: white,
//                   fontSize: 12,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Future<void> _launchPhone(String phoneNumber) async {
//     final Uri launchUri = Uri(
//       scheme: 'tel',
//       path: phoneNumber,
//     );
//     if (await canLaunchUrl(launchUri)) {
//       await launchUrl(launchUri);
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Could not make a call.'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     }
//   }

//   // MAIN STICKY HEADER - Fixed height, no collapsing when scrolling
//   Widget _buildPinnedHeader() {
//     return SliverAppBar(
//       backgroundColor: primaryNavy,
//       elevation: 2,
//       pinned: true,
//       floating: false,
//       snap: false,
//       automaticallyImplyLeading: false,
//       toolbarHeight: 0,
//       expandedHeight: 220.0,
//       collapsedHeight: 220.0,
//       flexibleSpace: FlexibleSpaceBar(
//         background: Container(
//           padding: const EdgeInsets.fromLTRB(16, 40, 16, 12),
//           color: primaryNavy,
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Container(
//                 height: 48,
//                 decoration: BoxDecoration(
//                   color: white,
//                   borderRadius: BorderRadius.circular(12),
//                   boxShadow: [
//                     BoxShadow(
//                       color: secondaryBlack.withOpacity(0.12),
//                       blurRadius: 10,
//                       offset: const Offset(0, 4),
//                     ),
//                   ],
//                 ),
//                 child: TextField(
//                   controller: _searchController,
//                   textInputAction: TextInputAction.search,
//                   onSubmitted: (query) {
//                     if (query.trim().isNotEmpty) {
//                       final normalized = query.toLowerCase().trim();
//                       final categoryLabels = _homeCategories
//                           .map((cat) => cat['label']!.toLowerCase())
//                           .toList();

//                       if (categoryLabels.contains(normalized)) {
//                         Navigator.push(
//                           context,
//                           MaterialPageRoute(
//                             builder: (_) => CategoryProductsScreen(category: query),
//                           ),
//                         );
//                       } else {
//                         Navigator.push(
//                           context,
//                           MaterialPageRoute(
//                             builder: (_) => SearchScreen(initialQuery: query),
//                           ),
//                         );
//                       }
//                     }
//                   },
//                   decoration: InputDecoration(
//                     hintText: 'Search products on NaijaGo',
//                     hintStyle: const TextStyle(color: lightGrey),
//                     prefixIcon: const Icon(Icons.search, color: lightGrey),
//                     border: InputBorder.none,
//                     contentPadding: const EdgeInsets.symmetric(vertical: 12),
//                     suffixIcon: IconButton(
//                       icon: const Icon(Icons.clear, color: lightGrey),
//                       onPressed: () => _searchController.clear(),
//                     ),
//                   ),
//                 ),
//               ),
//               const SizedBox(height: 16),
//               Text(
//                 getTimeBasedGreeting(_userFirstName),
//                 style: const TextStyle(
//                   color: white,
//                   fontSize: 22,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//               const SizedBox(height: 4),
//               const Text(
//                 'Hotlines for quick Contact',
//                 style: TextStyle(
//                   color: Colors.white70,
//                   fontSize: 13,
//                   fontWeight: FontWeight.w500,
//                 ),
//               ),
//               const SizedBox(height: 12),
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                 children: [
//                   _buildPhoneNumberButton('08156761792'),
//                   const SizedBox(width: 16),
//                   _buildPhoneNumberButton('07044332895'),
//                 ],
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildSliverAppBar() {
//     return const SliverAppBar(
//       backgroundColor: primaryNavy,
//       elevation: 0,
//       pinned: true,
//       expandedHeight: 0,
//       toolbarHeight: 0,
//     );
//   }

//   Widget _buildBannerCarousel() {
//     final banners = const ["assets/prod_flier1.jpg", "assets/prod_flier2.jpg", "assets/prod_flier3.jpg"];

//     return Column(
//       children: [
//         SizedBox(
//           height: 200,
//           child: PageView.builder(
//             controller: _bannerController,
//             onPageChanged: (i) => setState(() => _currentBanner = i),
//             itemCount: banners.length,
//             itemBuilder: (_, i) {
//               return Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 12.0),
//                 child: ClipRRect(
//                   borderRadius: BorderRadius.circular(16),
//                   child: Image.asset(
//                     banners[i],
//                     fit: BoxFit.cover,
//                     errorBuilder: (context, error, stack) => Container(
//                       color: softGrey,
//                       alignment: Alignment.center,
//                       child: const Icon(Icons.image_not_supported, size: 48, color: lightGrey),
//                     ),
//                   ),
//                 ),
//               );
//             },
//           ),
//         ),
//         const SizedBox(height: 8),
//         Row(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: List.generate(banners.length, (i) {
//             final active = i == _currentBanner;
//             return AnimatedContainer(
//               duration: const Duration(milliseconds: 250),
//               margin: const EdgeInsets.symmetric(horizontal: 4),
//               height: 8,
//               width: active ? 24 : 8,
//               decoration: BoxDecoration(
//                 color: active ? primaryNavy : Colors.grey[400],
//                 borderRadius: BorderRadius.circular(8),
//               ),
//             );
//           }),
//         ),
//       ],
//     );
//   }

//   Widget _buildPromoCarousel() {
//     final promoBanners = const ["assets/ads1.png", "assets/ads2.png", "assets/ads3.png", "assets/ads4.png", "assets/ads5.png"];
//     return Column(
//       children: [
//         SizedBox(
//           height: 120,
//           child: PageView.builder(
//             controller: _promoController,
//             onPageChanged: (i) => setState(() => _currentPromo = i),
//             itemCount: promoBanners.length,
//             itemBuilder: (_, i) {
//               return Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 8.0),
//                 child: ClipRRect(
//                   borderRadius: BorderRadius.circular(16),
//                   child: Image.asset(
//                     promoBanners[i],
//                     fit: BoxFit.cover,
//                     errorBuilder: (context, error, stack) => Container(
//                       color: softGrey,
//                       alignment: Alignment.center,
//                       child: const Icon(Icons.image_not_supported, size: 48, color: lightGrey),
//                     ),
//                   ),
//                 ),
//               );
//             },
//           ),
//         ),
//         const SizedBox(height: 8),
//         Row(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: List.generate(promoBanners.length, (i) {
//             final active = i == _currentPromo;
//             return AnimatedContainer(
//               duration: const Duration(milliseconds: 250),
//               margin: const EdgeInsets.symmetric(horizontal: 4),
//               height: 8,
//               width: active ? 24 : 8,
//               decoration: BoxDecoration(
//                 color: active ? primaryNavy : Colors.grey[400],
//                 borderRadius: BorderRadius.circular(8),
//               ),
//             );
//           }),
//         ),
//       ],
//     );
//   }

//   Widget _buildSectionHeader(String title, {VoidCallback? onSeeAll}) {
//     final hasAnimation = title.contains('🔥') || title.contains('✨');
//     final titleText = hasAnimation ? title.substring(0, title.length - 2).trim() : title;
//     final emoji = hasAnimation ? title.substring(title.length - 2).trim() : '';

//     return SliverToBoxAdapter(
//       child: Container(
//         color: Colors.lightGreenAccent[700],
//         padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//           children: [
//             Row(
//               children: [
//                 Text(
//                   titleText,
//                   style: const TextStyle(
//                     color: primaryNavy,
//                     fontSize: 20,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//                 if (hasAnimation)
//                   Padding(
//                     padding: const EdgeInsets.only(left: 8.0),
//                     child: _AnimatedText(
//                       text: emoji,
//                       style: const TextStyle(fontSize: 20),
//                     ),
//                   ),
//               ],
//             ),
//             if (onSeeAll != null)
//               TextButton(
//                 onPressed: onSeeAll,
//                 child: const Text(
//                   'See all',
//                   style: TextStyle(
//                     color: primaryNavy,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//               ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildCategories() {
//     return Container(
//       color: white,
//       padding: const EdgeInsets.symmetric(vertical: 16.0),
//       child: GridView.builder(
//         shrinkWrap: true,
//         physics: const NeverScrollableScrollPhysics(),
//         padding: const EdgeInsets.symmetric(horizontal: 16),
//         gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//           crossAxisCount: 3,
//           childAspectRatio: 1.2,
//           mainAxisSpacing: 10,
//           crossAxisSpacing: 10,
//         ),
//         itemCount: _homeCategories.length,
//         itemBuilder: (context, index) {
//           final cat = _homeCategories[index];
//           return _buildCategoryCard(imagePath: cat["image"] as String, label: cat["label"] as String);
//         },
//       ),
//     );
//   }

//   Widget _buildCategoryCard({required String imagePath, required String label}) {
//     return GestureDetector(
//       onTap: () {
//         Navigator.of(context).push(
//           MaterialPageRoute(
//             builder: (context) => const CategoriesScreen(),
//           ),
//         );
//       },
//       child: Column(
//         children: [
//           Container(
//             width: 60,
//             height: 60,
//             decoration: BoxDecoration(
//               color: primaryNavy.withOpacity(0.8),
//               borderRadius: BorderRadius.circular(12),
//             ),
//             child: ClipRRect(
//               borderRadius: BorderRadius.circular(12),
//               child: Image.asset(
//                 imagePath,
//                 fit: BoxFit.cover,
//                 errorBuilder: (context, error, stack) => Container(
//                   color: softGrey,
//                   alignment: Alignment.center,
//                   child: const Icon(Icons.image_not_supported, size: 48, color: lightGrey),
//                 ),
//               ),
//             ),
//           ),
//           const SizedBox(height: 8),
//           Text(
//             label,
//             style: const TextStyle(
//               fontSize: 12,
//               fontWeight: FontWeight.w600,
//               color: secondaryBlack,
//             ),
//             textAlign: TextAlign.center,
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildFooter() {
//     return SliverToBoxAdapter(
//       child: Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 32.0),
//         child: Stack(
//           alignment: Alignment.center,
//           children: [
//             _SpinningWatermark(),
//             Column(
//               mainAxisSize: MainAxisSize.min,
//               children: const [
//                 SizedBox(height: 8),
//                 Text(
//                   '© 2025 NaijaGo. All rights reserved.',
//                   textAlign: TextAlign.center,
//                   style: TextStyle(
//                     color: Colors.grey,
//                     fontSize: 12,
//                   ),
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: softGrey,
//       body: RefreshIndicator(
//         onRefresh: _fetchProducts,
//         color: primaryNavy,
//         child: CustomScrollView(
//           physics: const BouncingScrollPhysics(),
//           slivers: [
//             _buildSliverAppBar(),
//             _buildPinnedHeader(),
//             SliverToBoxAdapter(child: _buildBannerCarousel()),
//             const SliverToBoxAdapter(child: SizedBox(height: 24)),

//             // Flash Sales section - shows shimmer when empty
//             if (_flashSales.isNotEmpty) ...[
//               _buildSectionHeader(
//                 'Flash Sales 🔥',
//                 onSeeAll: () {
//                   Navigator.of(context).push(
//                     MaterialPageRoute(
//                       builder: (context) => FlashSalesScreen(flashSales: _flashSales),
//                     ),
//                   );
//                 },
//               ),
//               SliverToBoxAdapter(
//                 child: ProductListHorizontal(
//                   products: _flashSales,
//                   sectionKey: 'flash',
//                   showFlashBadge: true,
//                   showNewBadge: false,
//                 ),
//               ),
//               const SliverToBoxAdapter(child: SizedBox(height: 24)),
//             ],

//             // Categories section (static - always visible)
//             _buildSectionHeader(
//               'Categories',
//               onSeeAll: () {
//                 Navigator.of(context).push(
//                   MaterialPageRoute(builder: (context) => const CategoriesScreen()),
//                 );
//               },
//             ),
//             SliverToBoxAdapter(child: _buildCategories()),
//             const SliverToBoxAdapter(child: SizedBox(height: 24)),

//             // New Arrivals section - shows shimmer when empty
//             if (_newArrivals.isNotEmpty) ...[
//               _buildSectionHeader('New Arrivals ✨', onSeeAll: null),
//               SliverToBoxAdapter(
//                 child: ProductListHorizontal(
//                   products: _newArrivals,
//                   sectionKey: 'new',
//                   showFlashBadge: false,
//                   showNewBadge: true,
//                 ),
//               ),
//               const SliverToBoxAdapter(child: SizedBox(height: 24)),
//             ],

//             SliverToBoxAdapter(child: _buildPromoCarousel()),
//             const SliverToBoxAdapter(child: SizedBox(height: 24)),

//             // Recommended section - shows shimmer when empty
//             if (_recommended.isNotEmpty) ...[
//               _buildSectionHeader('Recommended For You', onSeeAll: null),
//               ProductListGrid(
//                 products: _recommended,
//                 sectionKey: 'rec',
//               ),
//             ],

//             // Global error message if something critical fails
//             if (_errorMessage != null)
//               SliverToBoxAdapter(
//                 child: Padding(
//                   padding: const EdgeInsets.all(20.0),
//                   child: Column(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       const Icon(Icons.error_outline, color: Colors.red, size: 50),
//                       const SizedBox(height: 10),
//                       Text(
//                         _errorMessage!,
//                         textAlign: TextAlign.center,
//                         style: const TextStyle(color: Colors.red, fontSize: 16),
//                       ),
//                       const SizedBox(height: 20),
//                       ElevatedButton(
//                         onPressed: _fetchProducts,
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: primaryNavy,
//                           padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
//                           shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(30.0),
//                           ),
//                         ),
//                         child: const Text('Retry', style: TextStyle(color: white, fontSize: 16)),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),

//             _buildFooter(),
//             const SliverToBoxAdapter(child: SizedBox(height: 40)),
//           ],
//         ),
//       ),
//     );
//   }
// }

// // Delegate for the pinned header
// class _HeaderDelegate extends SliverPersistentHeaderDelegate {
//   final Widget child;

//   _HeaderDelegate({required this.child});

//   @override
//   Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
//     return child;
//   }

//   @override
//   double get maxExtent => 180.0;

//   @override
//   double get minExtent => 120.0;

//   @override
//   bool shouldRebuild(covariant _HeaderDelegate oldDelegate) {
//     return oldDelegate.child != child;
//   }
// }

// class _SpinningWatermark extends StatefulWidget {
//   @override
//   State<_SpinningWatermark> createState() => _SpinningWatermarkState();
// }

// class _SpinningWatermarkState extends State<_SpinningWatermark> with SingleTickerProviderStateMixin {
//   late AnimationController _controller;

//   @override
//   void initState() {
//     super.initState();
//     _controller = AnimationController(
//       duration: const Duration(seconds: 30),
//       vsync: this,
//     )..repeat();
//   }

//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return FadeTransition(
//       opacity: const AlwaysStoppedAnimation(0.15),
//       child: RotationTransition(
//         turns: _controller,
//         child: ClipOval(
//           child: Image.asset(
//             'assets/naijago-9.jpg',
//             width: 100,
//             fit: BoxFit.cover,
//           ),
//         ),
//       ),
//     );
//   }
// }

// class ShimmerLoading extends StatelessWidget {
//   final double width;
//   final double height;

//   const ShimmerLoading({super.key, required this.width, required this.height});

//   @override
//   Widget build(BuildContext context) {
//     return Shimmer.fromColors(
//       baseColor: Colors.grey[300]!,
//       highlightColor: Colors.grey[100]!,
//       child: Container(
//         width: width,
//         height: height,
//         color: Colors.white,
//       ),
//     );
//   }
// }

// class ProductListHorizontal extends StatelessWidget {
//   final List<Product> products;
//   final String sectionKey;
//   final bool showFlashBadge;
//   final bool showNewBadge;

//   const ProductListHorizontal({
//     super.key,
//     required this.products,
//     required this.sectionKey,
//     this.showFlashBadge = false,
//     this.showNewBadge = false,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return SizedBox(
//       height: 270,
//       child: ListView.separated(
//         padding: const EdgeInsets.symmetric(horizontal: 16.0),
//         scrollDirection: Axis.horizontal,
//         itemCount: products.length,
//         separatorBuilder: (_, __) => const SizedBox(width: 12),
//         itemBuilder: (context, index) {
//           final product = products[index];
//           final heroTag = 'product-$sectionKey-${product.id}-$index';
//           return SizedBox(
//             width: 160,
//             child: ProductCard(
//               product: product,
//               heroTag: heroTag,
//               showFlashBadge: showFlashBadge,
//               showNewBadge: showNewBadge,
//             ),
//           );
//         },
//       ),
//     );
//   }
// }

// class ProductListGrid extends StatelessWidget {
//   final List<Product> products;
//   final String sectionKey;

//   const ProductListGrid({
//     super.key,
//     required this.products,
//     required this.sectionKey,
//   });

//   @override
//   Widget build(BuildContext context) {
//     if (products.isEmpty) {
//       return SliverPadding(
//         padding: const EdgeInsets.all(16.0),
//         sliver: SliverGrid(
//           gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//             crossAxisCount: 2,
//             crossAxisSpacing: 16.0,
//             mainAxisSpacing: 16.0,
//             childAspectRatio: 0.65,
//           ),
//           delegate: SliverChildBuilderDelegate(
//             (_, __) => const ShimmerLoading(width: double.infinity, height: 250),
//             childCount: 6,
//           ),
//         ),
//       );
//     }

//     return SliverPadding(
//       padding: const EdgeInsets.all(16.0),
//       sliver: SliverGrid(
//         gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//           crossAxisCount: 2,
//           crossAxisSpacing: 16.0,
//           mainAxisSpacing: 16.0,
//           childAspectRatio: 0.65,
//         ),
//         delegate: SliverChildBuilderDelegate(
//           (context, index) {
//             final product = products[index];
//             final heroTag = 'product-$sectionKey-${product.id}-$index';
//             return ProductCard(
//               product: product,
//               heroTag: heroTag,
//             );
//           },
//           childCount: products.length,
//         ),
//       ),
//     );
//   }
// }

// class ProductCard extends StatelessWidget {
//   final Product product;
//   final String heroTag;
//   final bool showFlashBadge;
//   final bool showNewBadge;

//   const ProductCard({
//     super.key,
//     required this.product,
//     required this.heroTag,
//     this.showFlashBadge = false,
//     this.showNewBadge = false,
//   });

//   String _formatPrice(double price) {
//     final formatter = NumberFormat.currency(
//       locale: 'en_NG',
//       symbol: '₦',
//       decimalDigits: 2,
//     );
//     return formatter.format(price);
//   }

//   @override
//   Widget build(BuildContext context) {
//     final cartProvider = Provider.of<CartProvider>(context, listen: false);

//     return GestureDetector(
//       onTap: () {
//         Navigator.of(context).push(
//           MaterialPageRoute(
//             builder: (context) => ProductDetailScreen(
//               product: product,
//               heroTag: heroTag,
//             ),
//           ),
//         );
//       },
//       child: Card(
//         color: white,
//         elevation: 4,
//         shadowColor: secondaryBlack.withOpacity(0.15),
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.stretch,
//           children: [
//             Stack(
//               children: [
//                 Hero(
//                   tag: heroTag,
//                   child: ClipRRect(
//                     borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
//                     child: CachedNetworkImage(
//                       imageUrl: product.imageUrls.isNotEmpty
//                           ? product.imageUrls[0]
//                           : 'https://placehold.co/400x300/CCCCCC/000000?text=No+Image',
//                       height: 120,
//                       width: double.infinity,
//                       fit: BoxFit.cover,
//                       placeholder: (context, url) => Container(
//                         height: 120,
//                         color: Colors.grey[200],
//                         child: const Center(child: CircularProgressIndicator(color: primaryNavy)),
//                       ),
//                       errorWidget: (context, url, error) => Container(
//                         height: 120,
//                         color: Colors.grey[200],
//                         child: Icon(Icons.image_not_supported, size: 40, color: Colors.grey[600]),
//                       ),
//                     ),
//                   ),
//                 ),
//                 if (showFlashBadge)
//                   Positioned(
//                     left: 8,
//                     top: 8,
//                     child: _AnimatedBadge(
//                       label: 'FLASH SALE',
//                       icon: Icons.flash_on,
//                       color: Colors.red,
//                     ),
//                   ),
//                 if (showNewBadge)
//                   Positioned(
//                     left: 8,
//                     top: 8,
//                     child: _AnimatedBadge(
//                       label: 'NEW',
//                       icon: Icons.star,
//                       color: accentGreen,
//                     ),
//                   ),
//               ],
//             ),
//             Expanded(
//               child: Padding(
//                 padding: const EdgeInsets.all(12.0),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     Text(
//                       product.name,
//                       style: const TextStyle(
//                         fontSize: 14,
//                         fontWeight: FontWeight.w600,
//                         color: secondaryBlack,
//                       ),
//                       maxLines: 2,
//                       overflow: TextOverflow.ellipsis,
//                     ),
//                     Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(
//                           _formatPrice(product.price),
//                           style: const TextStyle(
//                             fontSize: 16,
//                             fontWeight: FontWeight.bold,
//                             color: primaryNavy,
//                           ),
//                         ),
//                         const SizedBox(height: 4),
//                         Text(
//                           'Vendor: ${product.vendorBusinessName ?? 'N/A'}',
//                           style: const TextStyle(
//                             fontSize: 10,
//                             color: lightGrey,
//                           ),
//                           maxLines: 1,
//                           overflow: TextOverflow.ellipsis,
//                         ),
//                         const SizedBox(height: 8),
//                         SizedBox(
//                           width: double.infinity,
//                           height: 36,
//                           child: ElevatedButton(
//                             onPressed: product.stockQuantity > 0
//                                 ? () {
//                                     cartProvider.addProduct(product);
//                                     ScaffoldMessenger.of(context).showSnackBar(
//                                       SnackBar(
//                                         content: Text('${product.name} added to cart!'),
//                                         backgroundColor: accentGreen,
//                                       ),
//                                     );
//                                   }
//                                 : null,
//                             style: ElevatedButton.styleFrom(
//                               backgroundColor: product.stockQuantity > 0 ? primaryNavy : Colors.grey[300],
//                               foregroundColor: product.stockQuantity > 0 ? white : Colors.grey[700],
//                               shape: RoundedRectangleBorder(
//                                 borderRadius: BorderRadius.circular(8),
//                               ),
//                               padding: EdgeInsets.zero,
//                               elevation: 0,
//                             ),
//                             child: Text(
//                               product.stockQuantity > 0 ? 'Add to Cart' : 'Out of Stock',
//                               style: TextStyle(
//                                 fontSize: 12,
//                                 color: product.stockQuantity > 0 ? white : Colors.grey[400],
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class _AnimatedBadge extends StatefulWidget {
//   final String label;
//   final IconData icon;
//   final Color color;

//   const _AnimatedBadge({
//     required this.label,
//     required this.icon,
//     required this.color,
//   });

//   @override
//   _AnimatedBadgeState createState() => _AnimatedBadgeState();
// }

// class _AnimatedBadgeState extends State<_AnimatedBadge> with SingleTickerProviderStateMixin {
//   late AnimationController _controller;
//   late Animation<double> _scaleAnimation;

//   @override
//   void initState() {
//     super.initState();
//     _controller = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 700),
//     )..repeat(reverse: true);

//     _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
//       CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
//     );
//   }

//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return ScaleTransition(
//       scale: _scaleAnimation,
//       child: Container(
//         padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//         decoration: BoxDecoration(
//           color: widget.color,
//           borderRadius: BorderRadius.circular(8),
//           boxShadow: [
//             BoxShadow(
//               color: widget.color.withOpacity(0.5),
//               blurRadius: 8,
//               spreadRadius: 2,
//               offset: const Offset(0, 4),
//             ),
//           ],
//         ),
//         child: Row(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Icon(widget.icon, size: 14, color: white),
//             const SizedBox(width: 4),
//             Text(
//               widget.label,
//               style: const TextStyle(
//                 color: white,
//                 fontSize: 10,
//                 fontWeight: FontWeight.bold,
//                 letterSpacing: 0.5,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class _AnimatedText extends StatefulWidget {
//   final String text;
//   final TextStyle style;

//   const _AnimatedText({
//     required this.text,
//     required this.style,
//   });

//   @override
//   State<_AnimatedText> createState() => _AnimatedTextState();
// }

// class _AnimatedTextState extends State<_AnimatedText> with SingleTickerProviderStateMixin {
//   late AnimationController _controller;
//   late Animation<double> _scaleAnimation;

//   @override
//   void initState() {
//     super.initState();
//     _controller = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 700),
//     )..repeat(reverse: true);

//     _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
//       CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
//     );
//   }

//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return ScaleTransition(
//       scale: _scaleAnimation,
//       child: Text(
//         widget.text,
//         style: widget.style,
//       ),
//     );
//   }
// }


// --------------------------------------------------------------
// =================================================================
// ---------------------------------------------------------------------

// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:provider/provider.dart';
// import 'package:intl/intl.dart';
// import 'package:url_launcher/url_launcher.dart';
// import 'dart:async';
// import 'dart:convert';
// import 'package:cached_network_image/cached_network_image.dart';
// import 'package:shimmer/shimmer.dart';

// // Import your existing files
// import '../../constants.dart';
// import '../../models/product.dart';
// import '../../providers/cart_provider.dart';
// import 'product_detail_screen.dart';
// import 'categories_screen.dart';
// import 'CategoryProductsScreen.dart';

// // New screen for flash sales products
// class FlashSalesScreen extends StatelessWidget {
//   final List<Product> flashSales;

//   const FlashSalesScreen({super.key, required this.flashSales});

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Flash Sales 🔥'),
//         backgroundColor: primaryNavy,
//         foregroundColor: white,
//       ),
//       body: flashSales.isEmpty
//           ? const Center(
//               child: Text(
//                 'No flash sales products available.',
//                 style: TextStyle(fontSize: 16),
//               ),
//             )
//           : GridView.builder(
//               padding: const EdgeInsets.all(16.0),
//               gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//                 crossAxisCount: 2,
//                 crossAxisSpacing: 16.0,
//                 mainAxisSpacing: 16.0,
//                 childAspectRatio: 0.65,
//               ),
//               itemCount: flashSales.length,
//               itemBuilder: (context, index) {
//                 final product = flashSales[index];
//                 final heroTag = 'flash_sales-${product.id}-$index';
//                 return ProductCard(
//                   product: product,
//                   heroTag: heroTag,
//                   showFlashBadge: true,
//                 );
//               },
//             ),
//     );
//   }
// }

// String getTimeBasedGreeting(String firstName) {
//   final hour = DateTime.now().hour;

//   if (hour < 12) {
//     return 'Good Morning, $firstName!';
//   } else if (hour < 17) {
//     return 'Good Afternoon, $firstName!';
//   } else {
//     return 'Good Evening, $firstName!';
//   }
// }

// // Search Screen
// class SearchScreen extends StatefulWidget {
//   final String initialQuery;

//   const SearchScreen({super.key, required this.initialQuery});

//   @override
//   State<SearchScreen> createState() => _SearchScreenState();
// }

// class _SearchScreenState extends State<SearchScreen> {
//   final TextEditingController _searchController = TextEditingController();
//   final ProductService _productService = ProductService();
//   List<Product> _searchResults = [];
//   bool _isLoading = true;
//   String? _errorMessage;

//   @override
//   void initState() {
//     super.initState();
//     _searchController.text = widget.initialQuery;
//     _performSearch(widget.initialQuery);
//   }

//   Future<void> _performSearch(String query) async {
//     if (query.isEmpty) {
//       setState(() {
//         _isLoading = false;
//         _searchResults = [];
//       });
//       return;
//     }

//     setState(() {
//       _isLoading = true;
//       _errorMessage = null;
//     });

//     try {
//       final results = await _productService.searchProducts(query);
//       if (mounted) {
//         setState(() {
//           _searchResults = results;
//         });
//       }
//     } catch (e) {
//       debugPrint('Search error: $e');
//       String friendlyMessage = 'An error occurred while searching';

//       if (e.toString().contains('404')) {
//         friendlyMessage = 'Search feature is not available yet (endpoint missing)';
//       } else if (e.toString().contains('500') || e.toString().contains('Server error')) {
//         friendlyMessage = 'Server is having issues right now... please try again in 30 seconds';
//       } else if (e.toString().contains('timeout') || e.toString().contains('Connection')) {
//         friendlyMessage = 'Connection problem. Server might be waking up — try again in 15–30 seconds';
//       }

//       if (mounted) {
//         setState(() {
//           _errorMessage = '$friendlyMessage\n\nDetails: $e';
//         });
//       }
//     } finally {
//       if (mounted) {
//         setState(() => _isLoading = false);
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: TextField(
//           controller: _searchController,
//           autofocus: true,
//           textInputAction: TextInputAction.search,
//           onSubmitted: _performSearch,
//           decoration: InputDecoration(
//             hintText: 'Search products...',
//             hintStyle: const TextStyle(color: white),
//             border: InputBorder.none,
//             suffixIcon: IconButton(
//               icon: const Icon(Icons.search, color: white),
//               onPressed: () => _performSearch(_searchController.text),
//             ),
//           ),
//           style: const TextStyle(color: white),
//         ),
//         backgroundColor: primaryNavy,
//       ),
//       body: _isLoading
//           ? const Center(child: CircularProgressIndicator(color: primaryNavy))
//           : _errorMessage != null
//               ? Center(child: Text(_errorMessage!, textAlign: TextAlign.center))
//               : _searchResults.isEmpty
//                   ? const Center(child: Text('No products found.'))
//                   : GridView.builder(
//                       padding: const EdgeInsets.all(16.0),
//                       gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//                         crossAxisCount: 2,
//                         crossAxisSpacing: 16.0,
//                         mainAxisSpacing: 16.0,
//                         childAspectRatio: 0.65,
//                       ),
//                       itemCount: _searchResults.length,
//                       itemBuilder: (context, index) {
//                         final product = _searchResults[index];
//                         final heroTag = 'search-${product.id}-$index';
//                         return ProductCard(product: product, heroTag: heroTag);
//                       },
//                     ),
//     );
//   }
// }

// // Service to handle API calls
// class ProductService {
//   final String _baseUrl = 'https://naijago-backend.onrender.com';

//   Future<List<Product>> fetchFlashSales() => _fetchProducts('/api/products/flashsales');
//   Future<List<Product>> fetchNewArrivals() => _fetchProducts('/api/products/newarrivals');
//   Future<List<Product>> fetchAllProducts() => _fetchProducts('/api/products');
//   Future<List<Product>> fetchProductsByCategory(String category) =>
//       _fetchProducts('/api/products/category/$category');
//   Future<List<Product>> searchProducts(String query) =>
//       _fetchProducts('/api/products/search?q=$query');

//   Future<List<Product>> _fetchProducts(String endpoint) async {
//     final SharedPreferences prefs = await SharedPreferences.getInstance();
//     final String? token = prefs.getString('jwt_token');

//     final headers = {
//       'Content-Type': 'application/json; charset=UTF-8',
//       if (token != null) 'Authorization': 'Bearer $token',
//     };

//     final response = await http.get(Uri.parse('$_baseUrl$endpoint'), headers: headers);

//     debugPrint('API Response for $endpoint: ${response.statusCode}');
//     debugPrint('API Response Body: ${response.body}');

//     if (response.statusCode == 200) {
//       final List<dynamic> jsonList = jsonDecode(response.body);
//       return jsonList.map((json) => Product.fromJson(json)).toList();
//     } else if (response.statusCode == 401) {
//       throw Exception('Unauthorized: Please log in again.');
//     } else if (response.statusCode >= 500) {
//       throw Exception('Server error: Please try again later.');
//     } else {
//       throw Exception('Failed to load data from $endpoint: ${response.statusCode}');
//     }
//   }
// }

// class HomeScreen extends StatefulWidget {
//   const HomeScreen({super.key});

//   @override
//   State<HomeScreen> createState() => _HomeScreenState();
// }

// class _HomeScreenState extends State<HomeScreen> {
//   List<Product> _flashSales = [];
//   List<Product> _newArrivals = [];
//   List<Product> _recommended = [];
//   bool _isLoading = true;
//   String? _errorMessage;
//   final PageController _bannerController = PageController(viewportFraction: 0.95);
//   final PageController _promoController = PageController(viewportFraction: 0.85);

//   final TextEditingController _searchController = TextEditingController();

//   late final ProductService _productService;

//   int _currentBanner = 0;
//   int _currentPromo = 0;

//   String _userFirstName = 'there'; // fallback
//   bool _hasLoadedUserName = false;

//   final List<Map<String, String>> _homeCategories = [
//     {"image": "assets/categories/smartphones.jpg", "label": "Phones"},
//     {"image": "assets/categories/fashion_women.jpg", "label": "Fashion"},
//     {"image": "assets/categories/appliances.jpg", "label": "Electronics"},
//     {"image": "assets/categories/sporting_goods.jpg", "label": "Sports"},
//     {"image": "assets/categories/groceries.jpg", "label": "Supermarket"},
//     {"image": "assets/categories/pharmacy.jpg", "label": "Health"},
//   ];

//   @override
//   void initState() {
//     super.initState();
//     _productService = ProductService();
//     _loadUserName();
//     _fetchProducts();
//     _startAutoScrollTimers();
//   }

//   Future<void> _loadUserName() async {
//     final prefs = await SharedPreferences.getInstance();
//     final userJsonString = prefs.getString('user');

//     if (userJsonString != null) {
//       final userData = jsonDecode(userJsonString);
//       final firstName = userData['firstName'] ?? 'there';

//       if (mounted) {
//         setState(() {
//           _userFirstName = firstName;
//           _hasLoadedUserName = true;
//         });
//       }
//     }
//   }

//   Future<void> _fetchProducts() async {
//     setState(() {
//       _isLoading = true;
//       _errorMessage = null;
//     });

//     try {
//       final results = await Future.wait([
//         _productService.fetchFlashSales(),
//         _productService.fetchNewArrivals(),
//         _productService.fetchAllProducts(),
//       ]);

//       if (mounted) {
//         setState(() {
//           _flashSales = results[0];
//           _newArrivals = results[1];
//           _recommended = results[2];
//         });
//       }
//     } on Exception catch (e) {
//       debugPrint('Error fetching products: $e');
//       if (mounted) {
//         setState(() {
//           if (e.toString().contains('Unauthorized')) {
//             _errorMessage = 'Session expired. Please log in again.';
//           } else if (e.toString().contains('Server error')) {
//             _errorMessage = 'Server is currently unavailable. Please try again later.';
//           } else {
//             _errorMessage = 'An error occurred. Please check your network connection.';
//           }
//         });
//       }
//     } finally {
//       if (mounted) {
//         setState(() {
//           _isLoading = false;
//         });
//       }
//     }
//   }

//   void _startAutoScrollTimers() {
//     final bannerImages = const ["assets/prod_flier1.jpg", "assets/prod_flier2.jpg", "assets/prod_flier3.jpg"];
//     final promoBanners = const ["assets/ads1.png", "assets/ads2.png", "assets/ads3.png", "assets/ads4.png", "assets/ads5.png"];

//     Timer.periodic(const Duration(seconds: 4), (timer) {
//       if (!mounted) {
//         timer.cancel();
//         return;
//       }
//       if (_bannerController.hasClients) {
//         final next = (_currentBanner + 1) % bannerImages.length;
//         _bannerController.animateToPage(
//           next,
//           duration: const Duration(milliseconds: 450),
//           curve: Curves.easeOut,
//         );
//       }
//     });

//     Timer.periodic(const Duration(seconds: 5), (timer) {
//       if (!mounted) {
//         timer.cancel();
//         return;
//       }
//       if (_promoController.hasClients) {
//         final next = (_currentPromo + 1) % promoBanners.length;
//         _promoController.animateToPage(
//           next,
//           duration: const Duration(milliseconds: 450),
//           curve: Curves.easeOut,
//         );
//       }
//     });
//   }

//   @override
//   void dispose() {
//     _bannerController.dispose();
//     _promoController.dispose();
//     _searchController.dispose();
//     super.dispose();
//   }

//   Widget _buildPhoneNumberButton(String phoneNumber) {
//     return Expanded(
//       child: InkWell(
//         onTap: () => _launchPhone(phoneNumber),
//         child: Container(
//           padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//           decoration: BoxDecoration(
//             color: Colors.green,
//             borderRadius: BorderRadius.circular(8),
//           ),
//           child: Row(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               const Icon(Icons.phone, size: 16, color: white),
//               const SizedBox(width: 8),
//               Text(
//                 phoneNumber,
//                 style: const TextStyle(
//                   color: white,
//                   fontSize: 12,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Future<void> _launchPhone(String phoneNumber) async {
//     final Uri launchUri = Uri(
//       scheme: 'tel',
//       path: phoneNumber,
//     );
//     if (await canLaunchUrl(launchUri)) {
//       await launchUrl(launchUri);
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Could not make a call.'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     }
//   }



//   // MAIN STICKY HEADER - Fixed height, no collapsing when scrolling
// Widget _buildPinnedHeader() {
//   return SliverAppBar(
//     backgroundColor: primaryNavy,
//     elevation: 2,                      // subtle shadow when content scrolls under
//     pinned: true,                      // stays visible at the top
//     floating: false,
//     snap: false,
//     automaticallyImplyLeading: false,  // no back button
//     toolbarHeight: 0,                  // hide default toolbar
//     expandedHeight: 220.0,             // ← full height when not scrolled
//     collapsedHeight: 220.0,            // ← same height when scrolled = NO shrinking!
//     flexibleSpace: FlexibleSpaceBar(
//       background: Container(
//         padding: const EdgeInsets.fromLTRB(16, 40, 16, 12), // 40 = safe area for status bar/notch
//         color: primaryNavy,
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // 1. Search bar
//             Container(
//               height: 48,
//               decoration: BoxDecoration(
//                 color: white,
//                 borderRadius: BorderRadius.circular(12),
//                 boxShadow: [
//                   BoxShadow(
//                     color: secondaryBlack.withOpacity(0.12),
//                     blurRadius: 10,
//                     offset: const Offset(0, 4),
//                   ),
//                 ],
//               ),
//               child: TextField(
//                 controller: _searchController,
//                 textInputAction: TextInputAction.search,
//                 onSubmitted: (query) {
//                   if (query.trim().isNotEmpty) {
//                     final normalized = query.toLowerCase().trim();
//                     final categoryLabels = _homeCategories
//                         .map((cat) => cat['label']!.toLowerCase())
//                         .toList();

//                     if (categoryLabels.contains(normalized)) {
//                       Navigator.push(
//                         context,
//                         MaterialPageRoute(
//                           builder: (_) => CategoryProductsScreen(category: query),
//                         ),
//                       );
//                     } else {
//                       Navigator.push(
//                         context,
//                         MaterialPageRoute(
//                           builder: (_) => SearchScreen(initialQuery: query),
//                         ),
//                       );
//                     }
//                   }
//                 },
//                 decoration: InputDecoration(
//                   hintText: 'Search products on NaijaGo',
//                   hintStyle: const TextStyle(color: lightGrey),
//                   prefixIcon: const Icon(Icons.search, color: lightGrey),
//                   border: InputBorder.none,
//                   contentPadding: const EdgeInsets.symmetric(vertical: 12),
//                   suffixIcon: IconButton(
//                     icon: const Icon(Icons.clear, color: lightGrey),
//                     onPressed: () => _searchController.clear(),
//                   ),
//                 ),
//               ),
//             ),

//             const SizedBox(height: 16),

//             // 2. Greeting
//             Text(
//               getTimeBasedGreeting(_userFirstName),
//               style: const TextStyle(
//                 color: white,
//                 fontSize: 22,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),

//             const SizedBox(height: 4),

//             // 3. Hotlines title
//             const Text(
//               'Hotlines for quick Contact',
//               style: TextStyle(
//                 color: Colors.white70,
//                 fontSize: 13,
//                 fontWeight: FontWeight.w500,
//               ),
//             ),

//             const SizedBox(height: 12),

//             // 4. Phone buttons
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//               children: [
//                 _buildPhoneNumberButton('08156761792'),
//                 const SizedBox(width: 16),
//                 _buildPhoneNumberButton('07044332895'),
//               ],
//             ),
//           ],
//         ),
//       ),
//     ),
//   );
// }

//   // Optional minimal AppBar (you can remove this completely if you want)
//   Widget _buildSliverAppBar() {
//     return const SliverAppBar(
//       backgroundColor: primaryNavy,
//       elevation: 0,
//       pinned: true,
//       expandedHeight: 0,
//       toolbarHeight: 0,
//     );
//   }

//   Widget _buildBannerCarousel() {
//     final banners = const ["assets/prod_flier1.jpg", "assets/prod_flier2.jpg", "assets/prod_flier3.jpg"];

//     return Column(
//       children: [
//         SizedBox(
//           height: 200,
//           child: PageView.builder(
//             controller: _bannerController,
//             onPageChanged: (i) => setState(() => _currentBanner = i),
//             itemCount: banners.length,
//             itemBuilder: (_, i) {
//               return Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 12.0),
//                 child: ClipRRect(
//                   borderRadius: BorderRadius.circular(16),
//                   child: Image.asset(
//                     banners[i],
//                     fit: BoxFit.cover,
//                     errorBuilder: (context, error, stack) => Container(
//                       color: softGrey,
//                       alignment: Alignment.center,
//                       child: const Icon(Icons.image_not_supported, size: 48, color: lightGrey),
//                     ),
//                   ),
//                 ),
//               );
//             },
//           ),
//         ),
//         const SizedBox(height: 8),
//         Row(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: List.generate(banners.length, (i) {
//             final active = i == _currentBanner;
//             return AnimatedContainer(
//               duration: const Duration(milliseconds: 250),
//               margin: const EdgeInsets.symmetric(horizontal: 4),
//               height: 8,
//               width: active ? 24 : 8,
//               decoration: BoxDecoration(
//                 color: active ? primaryNavy : Colors.grey[400],
//                 borderRadius: BorderRadius.circular(8),
//               ),
//             );
//           }),
//         ),
//       ],
//     );
//   }

//   Widget _buildPromoCarousel() {
//     final promoBanners = const ["assets/ads1.png", "assets/ads2.png", "assets/ads3.png", "assets/ads4.png", "assets/ads5.png"];
//     return Column(
//       children: [
//         SizedBox(
//           height: 120,
//           child: PageView.builder(
//             controller: _promoController,
//             onPageChanged: (i) => setState(() => _currentPromo = i),
//             itemCount: promoBanners.length,
//             itemBuilder: (_, i) {
//               return Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 8.0),
//                 child: ClipRRect(
//                   borderRadius: BorderRadius.circular(16),
//                   child: Image.asset(
//                     promoBanners[i],
//                     fit: BoxFit.cover,
//                     errorBuilder: (context, error, stack) => Container(
//                       color: softGrey,
//                       alignment: Alignment.center,
//                       child: const Icon(Icons.image_not_supported, size: 48, color: lightGrey),
//                     ),
//                   ),
//                 ),
//               );
//             },
//           ),
//         ),
//         const SizedBox(height: 8),
//         Row(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: List.generate(promoBanners.length, (i) {
//             final active = i == _currentPromo;
//             return AnimatedContainer(
//               duration: const Duration(milliseconds: 250),
//               margin: const EdgeInsets.symmetric(horizontal: 4),
//               height: 8,
//               width: active ? 24 : 8,
//               decoration: BoxDecoration(
//                 color: active ? primaryNavy : Colors.grey[400],
//                 borderRadius: BorderRadius.circular(8),
//               ),
//             );
//           }),
//         ),
//       ],
//     );
//   }

//   Widget _buildSectionHeader(String title, {VoidCallback? onSeeAll}) {
//     final hasAnimation = title.contains('🔥') || title.contains('✨');
//     final titleText = hasAnimation ? title.substring(0, title.length - 2).trim() : title;
//     final emoji = hasAnimation ? title.substring(title.length - 2).trim() : '';

//     return SliverToBoxAdapter(
//       child: Container(
//         color: Colors.lightGreenAccent[700],
//         padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//           children: [
//             Row(
//               children: [
//                 Text(
//                   titleText,
//                   style: const TextStyle(
//                     color: primaryNavy,
//                     fontSize: 20,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//                 if (hasAnimation)
//                   Padding(
//                     padding: const EdgeInsets.only(left: 8.0),
//                     child: _AnimatedText(
//                       text: emoji,
//                       style: const TextStyle(fontSize: 20),
//                     ),
//                   ),
//               ],
//             ),
//             if (onSeeAll != null)
//               TextButton(
//                 onPressed: onSeeAll,
//                 child: const Text(
//                   'See all',
//                   style: TextStyle(
//                     color: primaryNavy,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//               ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildCategories() {
//     return Container(
//       color: white,
//       padding: const EdgeInsets.symmetric(vertical: 16.0),
//       child: GridView.builder(
//         shrinkWrap: true,
//         physics: const NeverScrollableScrollPhysics(),
//         padding: const EdgeInsets.symmetric(horizontal: 16),
//         gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//           crossAxisCount: 3,
//           childAspectRatio: 1.2,
//           mainAxisSpacing: 10,
//           crossAxisSpacing: 10,
//         ),
//         itemCount: _homeCategories.length,
//         itemBuilder: (context, index) {
//           final cat = _homeCategories[index];
//           return _buildCategoryCard(imagePath: cat["image"] as String, label: cat["label"] as String);
//         },
//       ),
//     );
//   }

//   Widget _buildCategoryCard({required String imagePath, required String label}) {
//     return GestureDetector(
//       onTap: () {
//         Navigator.of(context).push(
//           MaterialPageRoute(
//             builder: (context) => const CategoriesScreen(),
//           ),
//         );
//       },
//       child: Column(
//         children: [
//           Container(
//             width: 60,
//             height: 60,
//             decoration: BoxDecoration(
//               color: primaryNavy.withOpacity(0.8),
//               borderRadius: BorderRadius.circular(12),
//             ),
//             child: ClipRRect(
//               borderRadius: BorderRadius.circular(12),
//               child: Image.asset(
//                 imagePath,
//                 fit: BoxFit.cover,
//                 errorBuilder: (context, error, stack) => Container(
//                   color: softGrey,
//                   alignment: Alignment.center,
//                   child: const Icon(Icons.image_not_supported, size: 48, color: lightGrey),
//                 ),
//               ),
//             ),
//           ),
//           const SizedBox(height: 8),
//           Text(
//             label,
//             style: const TextStyle(
//               fontSize: 12,
//               fontWeight: FontWeight.w600,
//               color: secondaryBlack,
//             ),
//             textAlign: TextAlign.center,
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildFooter() {
//     return SliverToBoxAdapter(
//       child: Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 32.0),
//         child: Stack(
//           alignment: Alignment.center,
//           children: [
//             _SpinningWatermark(),
//             Column(
//               mainAxisSize: MainAxisSize.min,
//               children: const [
//                 SizedBox(height: 8),
//                 Text(
//                   '© 2025 NaijaGo. All rights reserved.',
//                   textAlign: TextAlign.center,
//                   style: TextStyle(
//                     color: Colors.grey,
//                     fontSize: 12,
//                   ),
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: softGrey,
//       body: RefreshIndicator(
//         onRefresh: _fetchProducts,
//         color: primaryNavy,
//         child: CustomScrollView(
//           physics: const BouncingScrollPhysics(),
//           slivers: [
//             _buildSliverAppBar(),
//             _buildPinnedHeader(),
//             SliverToBoxAdapter(child: _buildBannerCarousel()),
//             const SliverToBoxAdapter(child: SizedBox(height: 24)),
//             if (_isLoading)
//               SliverToBoxAdapter(child: ShimmerLoading(width: double.infinity, height: 270))
//             else ...[
//               if (_flashSales.isNotEmpty) ...[
//                 _buildSectionHeader(
//                   'Flash Sales 🔥',
//                   onSeeAll: () {
//                     Navigator.of(context).push(
//                       MaterialPageRoute(
//                         builder: (context) => FlashSalesScreen(flashSales: _flashSales),
//                       ),
//                     );
//                   },
//                 ),
//                 SliverToBoxAdapter(
//                   child: ProductListHorizontal(
//                     products: _flashSales,
//                     sectionKey: 'flash',
//                     showFlashBadge: true,
//                     showNewBadge: false,
//                   ),
//                 ),
//                 const SliverToBoxAdapter(child: SizedBox(height: 24)),
//               ],
//               _buildSectionHeader(
//                 'Categories',
//                 onSeeAll: () {
//                   Navigator.of(context).push(
//                     MaterialPageRoute(builder: (context) => const CategoriesScreen()),
//                   );
//                 },
//               ),
//               SliverToBoxAdapter(child: _buildCategories()),
//               const SliverToBoxAdapter(child: SizedBox(height: 24)),
//               if (_newArrivals.isNotEmpty) ...[
//                 _buildSectionHeader('New Arrivals ✨', onSeeAll: null),
//                 SliverToBoxAdapter(
//                   child: ProductListHorizontal(
//                     products: _newArrivals,
//                     sectionKey: 'new',
//                     showFlashBadge: false,
//                     showNewBadge: true,
//                   ),
//                 ),
//                 const SliverToBoxAdapter(child: SizedBox(height: 24)),
//               ],
//               SliverToBoxAdapter(child: _buildPromoCarousel()),
//               const SliverToBoxAdapter(child: SizedBox(height: 24)),
//               if (_recommended.isNotEmpty) ...[
//                 _buildSectionHeader('Recommended For You', onSeeAll: null),
//                 ProductListGrid(
//                   products: _recommended,
//                   sectionKey: 'rec',
//                 ),
//               ],
//             ],
//             if (_errorMessage != null)
//               SliverToBoxAdapter(
//                 child: Padding(
//                   padding: const EdgeInsets.all(20.0),
//                   child: Column(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       const Icon(Icons.error_outline, color: Colors.red, size: 50),
//                       const SizedBox(height: 10),
//                       Text(
//                         _errorMessage!,
//                         textAlign: TextAlign.center,
//                         style: const TextStyle(color: Colors.red, fontSize: 16),
//                       ),
//                       const SizedBox(height: 20),
//                       ElevatedButton(
//                         onPressed: _fetchProducts,
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: primaryNavy,
//                           padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
//                           shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(30.0),
//                           ),
//                         ),
//                         child: const Text('Retry', style: TextStyle(color: white, fontSize: 16)),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             _buildFooter(),
//             const SliverToBoxAdapter(child: SizedBox(height: 40)),
//           ],
//         ),
//       ),
//     );
//   }
// }

// // Delegate for the pinned header
// class _HeaderDelegate extends SliverPersistentHeaderDelegate {
//   final Widget child;

//   _HeaderDelegate({required this.child});

//   @override
//   Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
//     return child;
//   }

//   @override
//   double get maxExtent => 180.0;

//   @override
//   double get minExtent => 120.0;

//   @override
//   bool shouldRebuild(covariant _HeaderDelegate oldDelegate) {
//     return oldDelegate.child != child;
//   }
// }

// class _SpinningWatermark extends StatefulWidget {
//   @override
//   State<_SpinningWatermark> createState() => _SpinningWatermarkState();
// }

// class _SpinningWatermarkState extends State<_SpinningWatermark> with SingleTickerProviderStateMixin {
//   late AnimationController _controller;

//   @override
//   void initState() {
//     super.initState();
//     _controller = AnimationController(
//       duration: const Duration(seconds: 30),
//       vsync: this,
//     )..repeat();
//   }

//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return FadeTransition(
//       opacity: const AlwaysStoppedAnimation(0.15),
//       child: RotationTransition(
//         turns: _controller,
//         child: ClipOval(
//           child: Image.asset(
//             'assets/naijago-9.jpg',
//             width: 100,
//             fit: BoxFit.cover,
//           ),
//         ),
//       ),
//     );
//   }
// }

// class ShimmerLoading extends StatelessWidget {
//   final double width;
//   final double height;

//   const ShimmerLoading({super.key, required this.width, required this.height});

//   @override
//   Widget build(BuildContext context) {
//     return Shimmer.fromColors(
//       baseColor: Colors.grey[300]!,
//       highlightColor: Colors.grey[100]!,
//       child: Container(
//         width: width,
//         height: height,
//         color: Colors.white,
//       ),
//     );
//   }
// }

// class ProductListHorizontal extends StatelessWidget {
//   final List<Product> products;
//   final String sectionKey;
//   final bool showFlashBadge;
//   final bool showNewBadge;

//   const ProductListHorizontal({
//     super.key,
//     required this.products,
//     required this.sectionKey,
//     this.showFlashBadge = false,
//     this.showNewBadge = false,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return SizedBox(
//       height: 270,
//       child: ListView.separated(
//         padding: const EdgeInsets.symmetric(horizontal: 16.0),
//         scrollDirection: Axis.horizontal,
//         itemCount: products.length,
//         separatorBuilder: (_, __) => const SizedBox(width: 12),
//         itemBuilder: (context, index) {
//           final product = products[index];
//           final heroTag = 'product-$sectionKey-${product.id}-$index';
//           return SizedBox(
//             width: 160,
//             child: ProductCard(
//               product: product,
//               heroTag: heroTag,
//               showFlashBadge: showFlashBadge,
//               showNewBadge: showNewBadge,
//             ),
//           );
//         },
//       ),
//     );
//   }
// }

// class ProductListGrid extends StatelessWidget {
//   final List<Product> products;
//   final String sectionKey;

//   const ProductListGrid({
//     super.key,
//     required this.products,
//     required this.sectionKey,
//   });

//   @override
//   Widget build(BuildContext context) {
//     if (products.isEmpty) {
//       return SliverPadding(
//         padding: const EdgeInsets.all(16.0),
//         sliver: SliverGrid(
//           gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//             crossAxisCount: 2,
//             crossAxisSpacing: 16.0,
//             mainAxisSpacing: 16.0,
//             childAspectRatio: 0.65,
//           ),
//           delegate: SliverChildBuilderDelegate(
//             (_, __) => const ShimmerLoading(width: double.infinity, height: 250),
//             childCount: 6,
//           ),
//         ),
//       );
//     }

//     return SliverPadding(
//       padding: const EdgeInsets.all(16.0),
//       sliver: SliverGrid(
//         gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//           crossAxisCount: 2,
//           crossAxisSpacing: 16.0,
//           mainAxisSpacing: 16.0,
//           childAspectRatio: 0.65,
//         ),
//         delegate: SliverChildBuilderDelegate(
//           (context, index) {
//             final product = products[index];
//             final heroTag = 'product-$sectionKey-${product.id}-$index';
//             return ProductCard(
//               product: product,
//               heroTag: heroTag,
//             );
//           },
//           childCount: products.length,
//         ),
//       ),
//     );
//   }
// }

// class ProductCard extends StatelessWidget {
//   final Product product;
//   final String heroTag;
//   final bool showFlashBadge;
//   final bool showNewBadge;

//   const ProductCard({
//     super.key,
//     required this.product,
//     required this.heroTag,
//     this.showFlashBadge = false,
//     this.showNewBadge = false,
//   });

//   String _formatPrice(double price) {
//     final formatter = NumberFormat.currency(
//       locale: 'en_NG',
//       symbol: '₦',
//       decimalDigits: 2,
//     );
//     return formatter.format(price);
//   }

//   @override
//   Widget build(BuildContext context) {
//     final cartProvider = Provider.of<CartProvider>(context, listen: false);

//     return GestureDetector(
//       onTap: () {
//         Navigator.of(context).push(
//           MaterialPageRoute(
//             builder: (context) => ProductDetailScreen(
//               product: product,
//               heroTag: heroTag,
//             ),
//           ),
//         );
//       },
//       child: Card(
//         color: white,
//         elevation: 4,
//         shadowColor: secondaryBlack.withOpacity(0.15),
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.stretch,
//           children: [
//             Stack(
//               children: [
//                 Hero(
//                   tag: heroTag,
//                   child: ClipRRect(
//                     borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
//                     child: CachedNetworkImage(
//                       imageUrl: product.imageUrls.isNotEmpty
//                           ? product.imageUrls[0]
//                           : 'https://placehold.co/400x300/CCCCCC/000000?text=No+Image',
//                       height: 120,
//                       width: double.infinity,
//                       fit: BoxFit.cover,
//                       placeholder: (context, url) => Container(
//                         height: 120,
//                         color: Colors.grey[200],
//                         child: const Center(child: CircularProgressIndicator(color: primaryNavy)),
//                       ),
//                       errorWidget: (context, url, error) => Container(
//                         height: 120,
//                         color: Colors.grey[200],
//                         child: Icon(Icons.image_not_supported, size: 40, color: Colors.grey[600]),
//                       ),
//                     ),
//                   ),
//                 ),
//                 if (showFlashBadge)
//                   Positioned(
//                     left: 8,
//                     top: 8,
//                     child: _AnimatedBadge(
//                       label: 'FLASH SALE',
//                       icon: Icons.flash_on,
//                       color: Colors.red,
//                     ),
//                   ),
//                 if (showNewBadge)
//                   Positioned(
//                     left: 8,
//                     top: 8,
//                     child: _AnimatedBadge(
//                       label: 'NEW',
//                       icon: Icons.star,
//                       color: accentGreen,
//                     ),
//                   ),
//               ],
//             ),
//             Expanded(
//               child: Padding(
//                 padding: const EdgeInsets.all(12.0),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     Text(
//                       product.name,
//                       style: const TextStyle(
//                         fontSize: 14,
//                         fontWeight: FontWeight.w600,
//                         color: secondaryBlack,
//                       ),
//                       maxLines: 2,
//                       overflow: TextOverflow.ellipsis,
//                     ),
//                     Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(
//                           _formatPrice(product.price),
//                           style: const TextStyle(
//                             fontSize: 16,
//                             fontWeight: FontWeight.bold,
//                             color: primaryNavy,
//                           ),
//                         ),
//                         const SizedBox(height: 4),
//                         Text(
//                           'Vendor: ${product.vendorBusinessName ?? 'N/A'}',
//                           style: const TextStyle(
//                             fontSize: 10,
//                             color: lightGrey,
//                           ),
//                           maxLines: 1,
//                           overflow: TextOverflow.ellipsis,
//                         ),
//                         const SizedBox(height: 8),
//                         SizedBox(
//                           width: double.infinity,
//                           height: 36,
//                           child: ElevatedButton(
//                             onPressed: product.stockQuantity > 0
//                                 ? () {
//                                     cartProvider.addProduct(product);
//                                     ScaffoldMessenger.of(context).showSnackBar(
//                                       SnackBar(
//                                         content: Text('${product.name} added to cart!'),
//                                         backgroundColor: accentGreen,
//                                       ),
//                                     );
//                                   }
//                                 : null,
//                             style: ElevatedButton.styleFrom(
//                               backgroundColor: product.stockQuantity > 0 ? primaryNavy : Colors.grey[300],
//                               foregroundColor: product.stockQuantity > 0 ? white : Colors.grey[700],
//                               shape: RoundedRectangleBorder(
//                                 borderRadius: BorderRadius.circular(8),
//                               ),
//                               padding: EdgeInsets.zero,
//                               elevation: 0,
//                             ),
//                             child: Text(
//                               product.stockQuantity > 0 ? 'Add to Cart' : 'Out of Stock',
//                               style: TextStyle(
//                                 fontSize: 12,
//                                 color: product.stockQuantity > 0 ? white : Colors.grey[400],
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class _AnimatedBadge extends StatefulWidget {
//   final String label;
//   final IconData icon;
//   final Color color;

//   const _AnimatedBadge({
//     required this.label,
//     required this.icon,
//     required this.color,
//   });

//   @override
//   _AnimatedBadgeState createState() => _AnimatedBadgeState();
// }

// class _AnimatedBadgeState extends State<_AnimatedBadge> with SingleTickerProviderStateMixin {
//   late AnimationController _controller;
//   late Animation<double> _scaleAnimation;

//   @override
//   void initState() {
//     super.initState();
//     _controller = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 700),
//     )..repeat(reverse: true);

//     _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
//       CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
//     );
//   }

//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return ScaleTransition(
//       scale: _scaleAnimation,
//       child: Container(
//         padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//         decoration: BoxDecoration(
//           color: widget.color,
//           borderRadius: BorderRadius.circular(8),
//           boxShadow: [
//             BoxShadow(
//               color: widget.color.withOpacity(0.5),
//               blurRadius: 8,
//               spreadRadius: 2,
//               offset: const Offset(0, 4),
//             ),
//           ],
//         ),
//         child: Row(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Icon(widget.icon, size: 14, color: white),
//             const SizedBox(width: 4),
//             Text(
//               widget.label,
//               style: const TextStyle(
//                 color: white,
//                 fontSize: 10,
//                 fontWeight: FontWeight.bold,
//                 letterSpacing: 0.5,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class _AnimatedText extends StatefulWidget {
//   final String text;
//   final TextStyle style;

//   const _AnimatedText({
//     required this.text,
//     required this.style,
//   });

//   @override
//   State<_AnimatedText> createState() => _AnimatedTextState();
// }

// class _AnimatedTextState extends State<_AnimatedText> with SingleTickerProviderStateMixin {
//   late AnimationController _controller;
//   late Animation<double> _scaleAnimation;

//   @override
//   void initState() {
//     super.initState();
//     _controller = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 700),
//     )..repeat(reverse: true);

//     _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
//       CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
//     );
//   }

//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return ScaleTransition(
//       scale: _scaleAnimation,
//       child: Text(
//         widget.text,
//         style: widget.style,
//       ),
//     );
//   }
// }



// ---------------------------------------------------------------------
// ====================================================================
// ---------------------------------------------------------------------



// // Import the new dependencies
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:provider/provider.dart';
// import 'package:intl/intl.dart';
// import 'package:url_launcher/url_launcher.dart';
// import 'dart:async';
// import 'dart:convert';
// import 'package:cached_network_image/cached_network_image.dart';
// import 'package:shimmer/shimmer.dart';

// // Import your existing files
// import '../../constants.dart';
// import '../../models/product.dart';
// import '../../providers/cart_provider.dart';
// import 'product_detail_screen.dart';
// import 'categories_screen.dart';
// import 'CategoryProductsScreen.dart';

// // New screen for flash sales products (No changes, just included for context)
// class FlashSalesScreen extends StatelessWidget {
//   final List<Product> flashSales;

//   const FlashSalesScreen({super.key, required this.flashSales});

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Flash Sales 🔥'),
//         backgroundColor: primaryNavy,
//         foregroundColor: white,
//       ),
//       body: flashSales.isEmpty
//           ? const Center(
//               child: Text(
//                 'No flash sales products available.',
//                 style: TextStyle(fontSize: 16),
//               ),
//             )
//           : GridView.builder(
//               padding: const EdgeInsets.all(16.0),
//               gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//                 crossAxisCount: 2,
//                 crossAxisSpacing: 16.0,
//                 mainAxisSpacing: 16.0,
//                 childAspectRatio: 0.65,
//               ),
//               itemCount: flashSales.length,
//               itemBuilder: (context, index) {
//                 final product = flashSales[index];
//                 final heroTag = 'flash_sales-${product.id}-$index';
//                 return ProductCard(
//                   product: product,
//                   heroTag: heroTag,
//                   showFlashBadge: true,
//                 );
//               },
//             ),
//     );
//   }
// }

// String getTimeBasedGreeting(String firstName) {
//   final hour = DateTime.now().hour;

//   if (hour < 12) {
//     return 'Good Morning, $firstName!';
//   } else if (hour < 17) {
//     return 'Good Afternoon, $firstName!';
//   } else {
//     return 'Good Evening, $firstName!';
//   }
// }


// // Search Screen (New Widget)
// class SearchScreen extends StatefulWidget {
//   final String initialQuery;

//   const SearchScreen({super.key, required this.initialQuery});

//   @override
//   State<SearchScreen> createState() => _SearchScreenState();
// }

// class _SearchScreenState extends State<SearchScreen> {
//   final TextEditingController _searchController = TextEditingController();
//   final ProductService _productService = ProductService();
//   List<Product> _searchResults = [];
//   bool _isLoading = true;
//   String? _errorMessage;

//   @override
//   void initState() {
//     super.initState();
//     _searchController.text = widget.initialQuery;
//     _performSearch(widget.initialQuery);
//   }

//   Future<void> _performSearch(String query) async {
//   if (query.isEmpty) {
//     setState(() {
//       _isLoading = false;
//       _searchResults = [];
//     });
//     return;
//   }

//   setState(() {
//     _isLoading = true;
//     _errorMessage = null;
//   });

//   try {
//     final results = await _productService.searchProducts(query);
//     if (mounted) {
//       setState(() {
//         _searchResults = results;
//       });
//     }
//   } catch (e) {
//     debugPrint('Search error: $e');
//     String friendlyMessage = 'An error occurred while searching';

//     if (e.toString().contains('404')) {
//       friendlyMessage = 'Search feature is not available yet (endpoint missing)';
//     } else if (e.toString().contains('500') || e.toString().contains('Server error')) {
//       friendlyMessage = 'Server is having issues right now... please try again in 30 seconds';
//     } else if (e.toString().contains('timeout') || e.toString().contains('Connection')) {
//       friendlyMessage = 'Connection problem. Server might be waking up — try again in 15–30 seconds';
//     }

//     if (mounted) {
//       setState(() {
//         _errorMessage = '$friendlyMessage\n\nDetails: $e';
//       });
//     }
//   } finally {
//     if (mounted) {
//       setState(() => _isLoading = false);
//     }
//   }
// }

//   // Future<void> _performSearch(String query) async {
//   //   if (query.isEmpty) {
//   //     setState(() {
//   //       _isLoading = false;
//   //       _searchResults = [];
//   //     });
//   //     return;
//   //   }
//   //   setState(() {
//   //     _isLoading = true;
//   //     _errorMessage = null;
//   //   });

//   //   try {
//   //     final results = await _productService.searchProducts(query);
//   //     if (mounted) {
//   //       setState(() {
//   //         _searchResults = results;
//   //       });
//   //     }
//   //   } catch (e) {
//   //     debugPrint('Error searching products: $e');
//   //     if (mounted) {
//   //       setState(() {
//   //         _errorMessage = 'An error occurred while searching. Please try again.';
//   //       });
//   //     }
//   //   } finally {
//   //     if (mounted) {
//   //       setState(() {
//   //         _isLoading = false;
//   //       });
//   //     }
//   //   }
//   // }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: TextField(
//           controller: _searchController,
//           autofocus: true,
//           textInputAction: TextInputAction.search,
//           onSubmitted: _performSearch,
//           decoration: InputDecoration(
//             hintText: 'Search products...',
//             hintStyle: const TextStyle(color: white),
//             border: InputBorder.none,
//             suffixIcon: IconButton(
//               icon: const Icon(Icons.search, color: white),
//               onPressed: () => _performSearch(_searchController.text),
//             ),
//           ),
//           style: const TextStyle(color: white),
//         ),
//         backgroundColor: primaryNavy,
//       ),
//       body: _isLoading
//           ? const Center(child: CircularProgressIndicator(color: primaryNavy))
//           : _errorMessage != null
//               ? Center(child: Text(_errorMessage!, textAlign: TextAlign.center))
//               : _searchResults.isEmpty
//                   ? const Center(child: Text('No products found.'))
//                   : GridView.builder(
//                       padding: const EdgeInsets.all(16.0),
//                       gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//                         crossAxisCount: 2,
//                         crossAxisSpacing: 16.0,
//                         mainAxisSpacing: 16.0,
//                         childAspectRatio: 0.65,
//                       ),
//                       itemCount: _searchResults.length,
//                       itemBuilder: (context, index) {
//                         final product = _searchResults[index];
//                         final heroTag = 'search-${product.id}-$index';
//                         return ProductCard(product: product, heroTag: heroTag);
//                       },
//                     ),
//     );
//   }
// }

// // Service to handle API calls (UPDATED with print for debugging)
// class ProductService {
//   final String _baseUrl = 'https://naijago-backend.onrender.com';

//   Future<List<Product>> fetchFlashSales() => _fetchProducts('/api/products/flashsales');
//   Future<List<Product>> fetchNewArrivals() => _fetchProducts('/api/products/newarrivals');
//   Future<List<Product>> fetchAllProducts() => _fetchProducts('/api/products');
//   Future<List<Product>> fetchProductsByCategory(String category) => _fetchProducts('/api/products/category/$category');
//   Future<List<Product>> searchProducts(String query) => _fetchProducts('/api/products/search?q=$query');

//   Future<List<Product>> _fetchProducts(String endpoint) async {
//     final SharedPreferences prefs = await SharedPreferences.getInstance();
//     final String? token = prefs.getString('jwt_token');

//     final headers = {
//       'Content-Type': 'application/json; charset=UTF-8',
//       if (token != null) 'Authorization': 'Bearer $token',
//     };

//     final response = await http.get(Uri.parse('$_baseUrl$endpoint'), headers: headers);
    
//     // **DEBUGGING LINE ADDED**
//     debugPrint('API Response for $endpoint: ${response.statusCode}');
//     debugPrint('API Response Body: ${response.body}');

//     if (response.statusCode == 200) {
//       final List<dynamic> jsonList = jsonDecode(response.body);
//       return jsonList.map((json) => Product.fromJson(json)).toList();
//     } else if (response.statusCode == 401) {
//       throw Exception('Unauthorized: Please log in again.');
//     } else if (response.statusCode >= 500) {
//       throw Exception('Server error: Please try again later.');
//     } else {
//       throw Exception('Failed to load data from $endpoint: ${response.statusCode}');
//     }
//   }
// }

// class HomeScreen extends StatefulWidget {
//   const HomeScreen({super.key});

//   @override
//   State<HomeScreen> createState() => _HomeScreenState();
// }

// class _HomeScreenState extends State<HomeScreen> {
//   List<Product> _flashSales = [];
//   List<Product> _newArrivals = [];
//   List<Product> _recommended = [];
//   bool _isLoading = true;
//   String? _errorMessage;
//   final PageController _bannerController = PageController(viewportFraction: 0.95);
//   final PageController _promoController = PageController(viewportFraction: 0.85);

//   final TextEditingController _searchController = TextEditingController();

//   late final ProductService _productService;

//   int _currentBanner = 0;
//   int _currentPromo = 0;
  
//   String _userFirstName = 'there'; // fallback
//   bool _hasLoadedUserName = false;

//   @override
//   void initState() {
//     super.initState();
//     _productService = ProductService();
//     _loadUserName(); // Add this
//     _fetchProducts();
//     _startAutoScrollTimers();
//   }

//   Future<void> _loadUserName() async {
//     final prefs = await SharedPreferences.getInstance();
//     final userJsonString = prefs.getString('user');
    
//     if (userJsonString != null) {
//       final userData = jsonDecode(userJsonString);
//       final firstName = userData['firstName'] ?? 'there';
      
//       if (mounted) {
//         setState(() {
//           _userFirstName = firstName;
//           _hasLoadedUserName = true;
//         });
//       }
//     }
//   }


//   final List<Map<String, String>> _homeCategories = [
//     {"image": "assets/categories/smartphones.jpg", "label": "Phones"},
//     {"image": "assets/categories/fashion_women.jpg", "label": "Fashion"},
//     {"image": "assets/categories/appliances.jpg", "label": "Electronics"},
//     {"image": "assets/categories/sporting_goods.jpg", "label": "Sports"},
//     {"image": "assets/categories/groceries.jpg", "label": "Supermarket"},
//     {"image": "assets/categories/pharmacy.jpg", "label": "Health"},
//   ];

//   Future<void> _fetchProducts() async {
//     setState(() {
//       _isLoading = true;
//       _errorMessage = null;
//     });

//     try {
//       final results = await Future.wait([
//         _productService.fetchFlashSales(),
//         _productService.fetchNewArrivals(),
//         _productService.fetchAllProducts(),
//       ]);

//       if (mounted) {
//         setState(() {
//           _flashSales = results[0];
//           _newArrivals = results[1];
//           _recommended = results[2];
//         });
//       }
//     } on Exception catch (e) {
//       debugPrint('Error fetching products: $e');
//       if (mounted) {
//         setState(() {
//           if (e.toString().contains('Unauthorized')) {
//             _errorMessage = 'Session expired. Please log in again.';
//           } else if (e.toString().contains('Server error')) {
//             _errorMessage = 'Server is currently unavailable. Please try again later.';
//           } else {
//             _errorMessage = 'An error occurred. Please check your network connection.';
//           }
//         });
//       }
//     } finally {
//       if (mounted) {
//         setState(() {
//           _isLoading = false;
//         });
//       }
//     }
//   }

//   void _startAutoScrollTimers() {
//     final bannerImages = const ["assets/prod_flier1.jpg", "assets/prod_flier2.jpg", "assets/prod_flier3.jpg"];
//     final promoBanners = const ["assets/ads1.png", "assets/ads2.png", "assets/ads3.png", "assets/ads4.png", "assets/ads5.png"];

//     Timer.periodic(const Duration(seconds: 4), (timer) {
//       if (!mounted) {
//         timer.cancel();
//         return;
//       }
//       if (_bannerController.hasClients) {
//         final next = (_currentBanner + 1) % bannerImages.length;
//         _bannerController.animateToPage(
//           next,
//           duration: const Duration(milliseconds: 450),
//           curve: Curves.easeOut,
//         );
//       }
//     });

//     Timer.periodic(const Duration(seconds: 5), (timer) {
//       if (!mounted) {
//         timer.cancel();
//         return;
//       }
//       if (_promoController.hasClients) {
//         final next = (_currentPromo + 1) % promoBanners.length;
//         _promoController.animateToPage(
//           next,
//           duration: const Duration(milliseconds: 450),
//           curve: Curves.easeOut,
//         );
//       }
//     });
//   }

//   Future<void> _launchPhone(String phoneNumber) async {
//     final Uri launchUri = Uri(
//       scheme: 'tel',
//       path: phoneNumber,
//     );
//     if (await canLaunchUrl(launchUri)) {
//       await launchUrl(launchUri);
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Could not make a call.'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     }
//   }

//   @override
//   void dispose() {
//     _bannerController.dispose();
//     _promoController.dispose();
//     _searchController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: softGrey,
//       body: RefreshIndicator(
//         onRefresh: _fetchProducts,
//         color: primaryNavy,
//         child: CustomScrollView(
//           physics: const BouncingScrollPhysics(),
//           slivers: [
//             _buildSliverAppBar(),
//             _buildSearchBarAndPhoneNumbers(),
//             SliverToBoxAdapter(child: _buildBannerCarousel()),
//             const SliverToBoxAdapter(child: SizedBox(height: 24)),
//             if (_isLoading)
//               SliverToBoxAdapter(child: ShimmerLoading(width: double.infinity, height: 270))
//             else ...[
//               if (_flashSales.isNotEmpty) ...[
//                 _buildSectionHeader(
//                   'Flash Sales 🔥',
//                   onSeeAll: () {
//                     Navigator.of(context).push(
//                       MaterialPageRoute(
//                         builder: (context) => FlashSalesScreen(flashSales: _flashSales),
//                       ),
//                     );
//                   },
//                 ),
//                 SliverToBoxAdapter(
//                   child: ProductListHorizontal(
//                     products: _flashSales,
//                     sectionKey: 'flash',
//                     showFlashBadge: true,
//                     showNewBadge: false,
//                   ),
//                 ),
//                 const SliverToBoxAdapter(child: SizedBox(height: 24)),
//               ],
//               _buildSectionHeader(
//                 'Categories',
//                 onSeeAll: () {
//                   Navigator.of(context).push(
//                     MaterialPageRoute(builder: (context) => const CategoriesScreen()),
//                   );
//                 },
//               ),
//               SliverToBoxAdapter(child: _buildCategories()),
//               const SliverToBoxAdapter(child: SizedBox(height: 24)),
//               if (_newArrivals.isNotEmpty) ...[
//                 _buildSectionHeader('New Arrivals ✨', onSeeAll: null),
//                 SliverToBoxAdapter(
//                   child: ProductListHorizontal(
//                     products: _newArrivals,
//                     sectionKey: 'new',
//                     showFlashBadge: false,
//                     showNewBadge: true,
//                   ),
//                 ),
//                 const SliverToBoxAdapter(child: SizedBox(height: 24)),
//               ],
//               SliverToBoxAdapter(child: _buildPromoCarousel()),
//               const SliverToBoxAdapter(child: SizedBox(height: 24)),
//               if (_recommended.isNotEmpty) ...[
//                 _buildSectionHeader('Recommended For You', onSeeAll: null),
//                 ProductListGrid(
//                   products: _recommended,
//                   sectionKey: 'rec',
//                 ),
//               ],
//             ],
//             if (_errorMessage != null)
//               SliverToBoxAdapter(
//                 child: Padding(
//                   padding: const EdgeInsets.all(20.0),
//                   child: Column(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       const Icon(Icons.error_outline, color: Colors.red, size: 50),
//                       const SizedBox(height: 10),
//                       Text(
//                         _errorMessage!,
//                         textAlign: TextAlign.center,
//                         style: const TextStyle(color: Colors.red, fontSize: 16),
//                       ),
//                       const SizedBox(height: 20),
//                       ElevatedButton(
//                         onPressed: _fetchProducts,
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: primaryNavy,
//                           padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
//                           shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(30.0),
//                           ),
//                         ),
//                         child: const Text('Retry', style: TextStyle(color: white, fontSize: 16)),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             _buildFooter(),
//             const SliverToBoxAdapter(child: SizedBox(height: 40)),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildSliverAppBar() {
//     return SliverAppBar(
//       backgroundColor: primaryNavy,
//       elevation: 0,
//       expandedHeight: 100,
//       floating: true,
//       pinned: true,
//       flexibleSpace: FlexibleSpaceBar(
//         centerTitle: false,
//         titlePadding: const EdgeInsets.only(left: 16.0, bottom: 16.0),
//         title: const Text(
//           'Hotlines For Quick Contact',
//           style: TextStyle(
//             color: white,
//             fontWeight: FontWeight.bold,
//             fontSize: 10,
//           ),
//         ),
//         background: Container(
//           decoration: BoxDecoration(
//             gradient: LinearGradient(
//               colors: [primaryNavy, primaryNavy.withOpacity(0.8)],
//               begin: Alignment.topLeft,
//               end: Alignment.bottomRight,
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildSearchBarAndPhoneNumbers() {
//   return SliverToBoxAdapter(
//     child: Container(
//       color: primaryNavy,
//       padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // Greeting Text
//           Padding(
//             padding: const EdgeInsets.only(left: 8.0, bottom: 12.0, top: 8.0),
//             child: Text(
//               getTimeBasedGreeting(_userFirstName),
//               style: const TextStyle(
//                 color: white,
//                 fontSize: 22,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//           ),
//           // Phone numbers
//           Row(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               _buildPhoneNumberButton('08156761792'),
//               const SizedBox(width: 16),
//               _buildPhoneNumberButton('07044332895'),
//             ],
//           ),
//           const SizedBox(height: 16),
//           // Search bar
//           Container(
//             height: 45,
//             decoration: BoxDecoration(
//               color: white,
//               borderRadius: BorderRadius.circular(12),
//               boxShadow: [
//                 BoxShadow(
//                   color: secondaryBlack.withOpacity(0.1),
//                   blurRadius: 10,
//                   offset: const Offset(0, 5),
//                 ),
//               ],
//             ),
//             child: TextField(
//               controller: _searchController,
//               textInputAction: TextInputAction.search,
//               onSubmitted: (query) {
//                 if (query.isNotEmpty) {
//                   final normalizedQuery = query.toLowerCase().trim();
//                   final categoryLabels = _homeCategories.map((cat) => cat['label']!.toLowerCase()).toList();

//                   if (categoryLabels.contains(normalizedQuery)) {
//                     Navigator.of(context).push(
//                       MaterialPageRoute(
//                         builder: (_) => CategoryProductsScreen(category: query),
//                       ),
//                     );
//                   } else {
//                     Navigator.of(context).push(
//                       MaterialPageRoute(
//                         builder: (_) => SearchScreen(initialQuery: query),
//                       ),
//                     );
//                   }
//                 }
//               },
//               decoration: InputDecoration(
//                 hintText: 'Search products on NaijaGo',
//                 hintStyle: const TextStyle(color: lightGrey),
//                 prefixIcon: const Icon(Icons.search, color: lightGrey),
//                 border: InputBorder.none,
//                 contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//                 suffixIcon: IconButton(
//                   icon: const Icon(Icons.clear, color: lightGrey),
//                   onPressed: () {
//                     _searchController.clear();
//                   },
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     ),
//   );
// }

//   // Widget _buildSearchBarAndPhoneNumbers() {
//   //   return SliverToBoxAdapter(
//   //     child: Container(
//   //       color: primaryNavy,
//   //       padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
//   //       child: Column(
//   //         children: [
//   //           Row(
//   //             mainAxisAlignment: MainAxisAlignment.center,
//   //             children: [
//   //               _buildPhoneNumberButton('07044332895'),
//   //               const SizedBox(width: 16),
//   //               _buildPhoneNumberButton('08056331560'),
//   //             ],
//   //           ),
//   //           const SizedBox(height: 16),
//   //           Container(
//   //             height: 45,
//   //             decoration: BoxDecoration(
//   //               color: white,
//   //               borderRadius: BorderRadius.circular(12),
//   //               boxShadow: [
//   //                 BoxShadow(
//   //                   color: secondaryBlack.withOpacity(0.1),
//   //                   blurRadius: 10,
//   //                   offset: const Offset(0, 5),
//   //                 ),
//   //               ],
//   //             ),
//   //             child: TextField(
//   //               controller: _searchController,
//   //               textInputAction: TextInputAction.search,
//   //               onSubmitted: (query) {
//   //                 if (query.isNotEmpty) {
//   //                   final normalizedQuery = query.toLowerCase().trim();
//   //                   final categoryLabels = _homeCategories.map((cat) => cat['label']!.toLowerCase()).toList();

//   //                   if (categoryLabels.contains(normalizedQuery)) {
//   //                     Navigator.of(context).push(
//   //                       MaterialPageRoute(
//   //                         builder: (_) => CategoryProductsScreen(category: query),
//   //                       ),
//   //                     );
//   //                   } else {
//   //                     Navigator.of(context).push(
//   //                       MaterialPageRoute(
//   //                         builder: (_) => SearchScreen(initialQuery: query),
//   //                       ),
//   //                     );
//   //                   }
//   //                 }
//   //               },
//   //               decoration: InputDecoration(
//   //                 hintText: 'Search products on NaijaGo',
//   //                 hintStyle: const TextStyle(color: lightGrey),
//   //                 prefixIcon: const Icon(Icons.search, color: lightGrey),
//   //                 border: InputBorder.none,
//   //                 contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//   //                 suffixIcon: IconButton(
//   //                   icon: const Icon(Icons.clear, color: lightGrey),
//   //                   onPressed: () {
//   //                     _searchController.clear();
//   //                   },
//   //                 ),
//   //               ),
//   //             ),
//   //           ),
//   //         ],
//   //       ),
//   //     ),
//   //   );
//   // }

//   Widget _buildPhoneNumberButton(String phoneNumber) {
//     return Expanded(
//       child: InkWell(
//         onTap: () => _launchPhone(phoneNumber),
//         child: Container(
//           padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//           decoration: BoxDecoration(
//             color: Colors.green,
//             borderRadius: BorderRadius.circular(8),
//           ),
//           child: Row(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               const Icon(Icons.phone, size: 16, color: white),
//               const SizedBox(width: 8),
//               Text(
//                 phoneNumber,
//                 style: const TextStyle(
//                   color: white,
//                   fontSize: 12,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildBannerCarousel() {
//     final banners = const ["assets/prod_flier1.jpg", "assets/prod_flier2.jpg", "assets/prod_flier3.jpg"];
//     // final banners = const ["assets/slider_app_five.jpg", "assets/slider_app_four.jpg", "assets/slider_app_one.jpg", "assets/slider_app_seven.jpg", "assets/slider_app_six.jpg"];

//     return Column(
//       children: [
//         SizedBox(
//           height: 200,
//           child: PageView.builder(
//             controller: _bannerController,
//             onPageChanged: (i) => setState(() => _currentBanner = i),
//             itemCount: banners.length,
//             itemBuilder: (_, i) {
//               return Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 12.0),
//                 child: ClipRRect(
//                   borderRadius: BorderRadius.circular(16),
//                   child: Image.asset(
//                     banners[i],
//                     fit: BoxFit.cover,
//                     errorBuilder: (context, error, stack) => Container(
//                       color: softGrey,
//                       alignment: Alignment.center,
//                       child: const Icon(Icons.image_not_supported, size: 48, color: lightGrey),
//                     ),
//                   ),
//                 ),
//               );
//             },
//           ),
//         ),
//         const SizedBox(height: 8),
//         Row(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: List.generate(banners.length, (i) {
//             final active = i == _currentBanner;
//             return AnimatedContainer(
//               duration: const Duration(milliseconds: 250),
//               margin: const EdgeInsets.symmetric(horizontal: 4),
//               height: 8,
//               width: active ? 24 : 8,
//               decoration: BoxDecoration(
//                 color: active ? primaryNavy : Colors.grey[400],
//                 borderRadius: BorderRadius.circular(8),
//               ),
//             );
//           }),
//         ),
//       ],
//     );
//   }

//   Widget _buildPromoCarousel() {
//     final promoBanners = const ["assets/ads1.png", "assets/ads2.png", "assets/ads3.png", "assets/ads4.png", "assets/ads5.png"];
//     return Column(
//       children: [
//         SizedBox(
//           height: 120,
//           child: PageView.builder(
//             controller: _promoController,
//             onPageChanged: (i) => setState(() => _currentPromo = i),
//             itemCount: promoBanners.length,
//             itemBuilder: (_, i) {
//               return Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 8.0),
//                 child: ClipRRect(
//                   borderRadius: BorderRadius.circular(16),
//                   child: Image.asset(
//                     promoBanners[i],
//                     fit: BoxFit.cover,
//                     errorBuilder: (context, error, stack) => Container(
//                       color: softGrey,
//                       alignment: Alignment.center,
//                       child: const Icon(Icons.image_not_supported, size: 48, color: lightGrey),
//                     ),
//                   ),
//                 ),
//               );
//             },
//           ),
//         ),
//         const SizedBox(height: 8),
//         Row(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: List.generate(promoBanners.length, (i) {
//             final active = i == _currentPromo;
//             return AnimatedContainer(
//               duration: const Duration(milliseconds: 250),
//               margin: const EdgeInsets.symmetric(horizontal: 4),
//               height: 8,
//               width: active ? 24 : 8,
//               decoration: BoxDecoration(
//                 color: active ? primaryNavy : Colors.grey[400],
//                 borderRadius: BorderRadius.circular(8),
//               ),
//             );
//           }),
//         ),
//       ],
//     );
//   }

//   Widget _buildSectionHeader(String title, {VoidCallback? onSeeAll}) {
//     final hasAnimation = title.contains('🔥') || title.contains('✨');
//     final titleText = hasAnimation ? title.substring(0, title.length - 2).trim() : title;
//     final emoji = hasAnimation ? title.substring(title.length - 2).trim() : '';

//     return SliverToBoxAdapter(
//       child: Container(
//         color: Colors.lightGreenAccent[700], // Changed background color
//         padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//           children: [
//             Row(
//               children: [
//                 Text(
//                   titleText,
//                   style: const TextStyle(
//                     color: primaryNavy,
//                     fontSize: 20,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//                 if (hasAnimation)
//                   Padding(
//                     padding: const EdgeInsets.only(left: 8.0),
//                     child: _AnimatedText(
//                       text: emoji,
//                       style: const TextStyle(
//                         fontSize: 20,
//                       ),
//                     ),
//                   ),
//               ],
//             ),
//             if (onSeeAll != null)
//               TextButton(
//                 onPressed: onSeeAll,
//                 child: const Text(
//                   'See all',
//                   style: TextStyle(
//                     color: primaryNavy,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//               ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildCategories() {
//     return Container(
//       color: white,
//       padding: const EdgeInsets.symmetric(vertical: 16.0),
//       child: GridView.builder(
//         shrinkWrap: true,
//         physics: const NeverScrollableScrollPhysics(),
//         padding: const EdgeInsets.symmetric(horizontal: 16),
//         gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//           crossAxisCount: 3,
//           childAspectRatio: 1.2,
//           mainAxisSpacing: 10,
//           crossAxisSpacing: 10,
//         ),
//         itemCount: _homeCategories.length,
//         itemBuilder: (context, index) {
//           final cat = _homeCategories[index];
//           return _buildCategoryCard(imagePath: cat["image"] as String, label: cat["label"] as String);
//         },
//       ),
//     );
//   }

//   Widget _buildCategoryCard({required String imagePath, required String label}) {
//     return GestureDetector(
//       onTap: () {
//         // FIXED: All category cards now lead to the main CategoriesScreen
//         Navigator.of(context).push(
//           MaterialPageRoute(
//             builder: (context) => const CategoriesScreen(),
//           ),
//         );
//       },
//       child: Column(
//         children: [
//           Container(
//             width: 60,
//             height: 60,
//             decoration: BoxDecoration(
//               color: primaryNavy.withOpacity(0.8),
//               borderRadius: BorderRadius.circular(12),
//             ),
//             child: ClipRRect(
//               borderRadius: BorderRadius.circular(12),
//               child: Image.asset(
//                 imagePath,
//                 fit: BoxFit.cover,
//                 errorBuilder: (context, error, stack) => Container(
//                   color: softGrey,
//                   alignment: Alignment.center,
//                   child: const Icon(Icons.image_not_supported, size: 48, color: lightGrey),
//                 ),
//               ),
//             ),
//           ),
//           const SizedBox(height: 8),
//           Text(
//             label,
//             style: const TextStyle(
//               fontSize: 12,
//               fontWeight: FontWeight.w600,
//               color: secondaryBlack,
//             ),
//             textAlign: TextAlign.center,
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildFooter() {
//     return SliverToBoxAdapter(
//       child: Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 32.0),
//         child: Stack(
//           alignment: Alignment.center,
//           children: [
//             _SpinningWatermark(),
//             Column(
//               mainAxisSize: MainAxisSize.min,
//               children: const [
//                 SizedBox(height: 8),
//                 Text(
//                   '© 2025 NaijaGo. All rights reserved.',
//                   textAlign: TextAlign.center,
//                   style: TextStyle(
//                     color: Colors.grey,
//                     fontSize: 12,
//                   ),
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class _SpinningWatermark extends StatefulWidget {
//   @override
//   State<_SpinningWatermark> createState() => _SpinningWatermarkState();
// }

// class _SpinningWatermarkState extends State<_SpinningWatermark> with SingleTickerProviderStateMixin {
//   late AnimationController _controller;

//   @override
//   void initState() {
//     super.initState();
//     _controller = AnimationController(
//       duration: const Duration(seconds: 30),
//       vsync: this,
//     )..repeat();
//   }

//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return FadeTransition(
//       opacity: const AlwaysStoppedAnimation(0.15),
//       child: RotationTransition(
//         turns: _controller,
//         child: ClipOval(
//           child: Image.asset(
//             'assets/naijago-9.jpg',
//             width: 100,
//             fit: BoxFit.cover,
//           ),
//         ),
//       ),
//     );
//   }
// }

// class ShimmerLoading extends StatelessWidget {
//   final double width;
//   final double height;

//   const ShimmerLoading({super.key, required this.width, required this.height});

//   @override
//   Widget build(BuildContext context) {
//     return Shimmer.fromColors(
//       baseColor: Colors.grey[300]!,
//       highlightColor: Colors.grey[100]!,
//       child: Container(
//         width: width,
//         height: height,
//         color: Colors.white,
//       ),
//     );
//   }
// }

// class ProductListHorizontal extends StatelessWidget {
//   final List<Product> products;
//   final String sectionKey;
//   final bool showFlashBadge;
//   final bool showNewBadge;

//   const ProductListHorizontal({
//     Key? key,
//     required this.products,
//     required this.sectionKey,
//     this.showFlashBadge = false,
//     this.showNewBadge = false,
//   }) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return SizedBox(
//       height: 270,
//       child: ListView.separated(
//         padding: const EdgeInsets.symmetric(horizontal: 16.0),
//         scrollDirection: Axis.horizontal,
//         itemCount: products.length,
//         separatorBuilder: (_, __) => const SizedBox(width: 12),
//         itemBuilder: (context, index) {
//           final product = products[index];
//           final heroTag = 'product-$sectionKey-${product.id}-$index';
//           return SizedBox(
//             width: 160,
//             child: ProductCard(
//               product: product,
//               heroTag: heroTag,
//               showFlashBadge: showFlashBadge,
//               showNewBadge: showNewBadge,
//             ),
//           );
//         },
//       ),
//     );
//   }
// }

// class ProductListGrid extends StatelessWidget {
//   final List<Product> products;
//   final String sectionKey;

//   const ProductListGrid({
//     Key? key,
//     required this.products,
//     required this.sectionKey,
//   }) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     if (products.isEmpty) {
//       return SliverPadding(
//         padding: const EdgeInsets.all(16.0),
//         sliver: SliverGrid(
//           gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//             crossAxisCount: 2,
//             crossAxisSpacing: 16.0,
//             mainAxisSpacing: 16.0,
//             childAspectRatio: 0.65,
//           ),
//           delegate: SliverChildBuilderDelegate(
//             (_, __) => const ShimmerLoading(width: double.infinity, height: 250),
//             childCount: 6,
//           ),
//         ),
//       );
//     }

//     return SliverPadding(
//       padding: const EdgeInsets.all(16.0),
//       sliver: SliverGrid(
//         gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//           crossAxisCount: 2,
//           crossAxisSpacing: 16.0,
//           mainAxisSpacing: 16.0,
//           childAspectRatio: 0.65,
//         ),
//         delegate: SliverChildBuilderDelegate(
//           (context, index) {
//             final product = products[index];
//             final heroTag = 'product-$sectionKey-${product.id}-$index';
//             return ProductCard(
//               product: product,
//               heroTag: heroTag,
//             );
//           },
//           childCount: products.length,
//         ),
//       ),
//     );
//   }
// }

// class ProductCard extends StatelessWidget {
//   final Product product;
//   final String heroTag;
//   final bool showFlashBadge;
//   final bool showNewBadge;

//   const ProductCard({
//     Key? key,
//     required this.product,
//     required this.heroTag,
//     this.showFlashBadge = false,
//     this.showNewBadge = false,
//   }) : super(key: key);

//   String _formatPrice(double price) {
//     final formatter = NumberFormat.currency(
//       locale: 'en_NG',
//       symbol: '₦',
//       decimalDigits: 2,
//     );
//     return formatter.format(price);
//   }

//   @override
//   Widget build(BuildContext context) {
//     final cartProvider = Provider.of<CartProvider>(context, listen: false);

//     return GestureDetector(
//       onTap: () {
//         Navigator.of(context).push(
//           MaterialPageRoute(
//             builder: (context) => ProductDetailScreen(
//               product: product,
//               heroTag: heroTag,
//             ),
//           ),
//         );
//       },
//       child: Card(
//         color: white,
//         elevation: 4,
//         shadowColor: secondaryBlack.withOpacity(0.15),
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.stretch,
//           children: [
//             Stack(
//               children: [
//                 Hero(
//                   tag: heroTag,
//                   child: ClipRRect(
//                     borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
//                     child: CachedNetworkImage(
//                       imageUrl: product.imageUrls.isNotEmpty
//                           ? product.imageUrls[0]
//                           : 'https://placehold.co/400x300/CCCCCC/000000?text=No+Image',
//                       height: 120,
//                       width: double.infinity,
//                       fit: BoxFit.cover,
//                       placeholder: (context, url) => Container(
//                         height: 120,
//                         color: Colors.grey[200],
//                         child: const Center(child: CircularProgressIndicator(color: primaryNavy)),
//                       ),
//                       errorWidget: (context, url, error) => Container(
//                         height: 120,
//                         color: Colors.grey[200],
//                         child: Icon(Icons.image_not_supported, size: 40, color: Colors.grey[600]),
//                       ),
//                     ),
//                   ),
//                 ),
//                 if (showFlashBadge)
//                   Positioned(
//                     left: 8,
//                     top: 8,
//                     child: _AnimatedBadge(
//                       label: 'FLASH SALE',
//                       icon: Icons.flash_on,
//                       color: Colors.red,
//                     ),
//                   ),
//                 if (showNewBadge)
//                   Positioned(
//                     left: 8,
//                     top: 8,
//                     child: _AnimatedBadge(
//                       label: 'NEW',
//                       icon: Icons.star,
//                       color: accentGreen,
//                     ),
//                   ),
//               ],
//             ),
//             Expanded(
//               child: Padding(
//                 padding: const EdgeInsets.all(12.0),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     Text(
//                       product.name,
//                       style: const TextStyle(
//                         fontSize: 14,
//                         fontWeight: FontWeight.w600,
//                         color: secondaryBlack,
//                       ),
//                       maxLines: 2,
//                       overflow: TextOverflow.ellipsis,
//                     ),
//                     Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(
//                           _formatPrice(product.price),
//                           style: const TextStyle(
//                             fontSize: 16,
//                             fontWeight: FontWeight.bold,
//                             color: primaryNavy,
//                           ),
//                         ),
//                         const SizedBox(height: 4),
//                         Text(
//                           'Vendor: ${product.vendorBusinessName ?? 'N/A'}',
//                           style: const TextStyle(
//                             fontSize: 10,
//                             color: lightGrey,
//                           ),
//                           maxLines: 1,
//                           overflow: TextOverflow.ellipsis,
//                         ),
//                         const SizedBox(height: 8),
//                         SizedBox(
//                           width: double.infinity,
//                           height: 36,
//                           child: ElevatedButton(
//                             onPressed: product.stockQuantity > 0
//                                 ? () {
//                                     cartProvider.addProduct(product);
//                                     ScaffoldMessenger.of(context).showSnackBar(
//                                       SnackBar(
//                                         content: Text('${product.name} added to cart!'),
//                                         backgroundColor: accentGreen,
//                                       ),
//                                     );
//                                   }
//                                 : null,
//                             style: ElevatedButton.styleFrom(
//                               backgroundColor: product.stockQuantity > 0 ? primaryNavy : Colors.grey[300],
//                               foregroundColor: product.stockQuantity > 0 ? white : Colors.grey[700],
//                               shape: RoundedRectangleBorder(
//                                 borderRadius: BorderRadius.circular(8),
//                               ),
//                               padding: EdgeInsets.zero,
//                               elevation: 0,
//                             ),
//                             child: Text(
//                               product.stockQuantity > 0 ? 'Add to Cart' : 'Out of Stock',
//                               style: TextStyle(
//                                 fontSize: 12,
//                                 color: product.stockQuantity > 0 ? white : Colors.grey[400],
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class _AnimatedBadge extends StatefulWidget {
//   final String label;
//   final IconData icon;
//   final Color color;

//   const _AnimatedBadge({
//     required this.label,
//     required this.icon,
//     required this.color,
//   });

//   @override
//   _AnimatedBadgeState createState() => _AnimatedBadgeState();
// }

// class _AnimatedBadgeState extends State<_AnimatedBadge> with SingleTickerProviderStateMixin {
//   late AnimationController _controller;
//   late Animation<double> _scaleAnimation;

//   @override
//   void initState() {
//     super.initState();
//     _controller = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 700),
//     )..repeat(reverse: true);

//     _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
//       CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
//     );
//   }

//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return ScaleTransition(
//       scale: _scaleAnimation,
//       child: Container(
//         padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//         decoration: BoxDecoration(
//           color: widget.color,
//           borderRadius: BorderRadius.circular(8),
//           boxShadow: [
//             BoxShadow(
//               color: widget.color.withOpacity(0.5),
//               blurRadius: 8,
//               spreadRadius: 2,
//               offset: const Offset(0, 4),
//             ),
//           ],
//         ),
//         child: Row(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Icon(widget.icon, size: 14, color: white),
//             const SizedBox(width: 4),
//             Text(
//               widget.label,
//               style: const TextStyle(
//                 color: white,
//                 fontSize: 10,
//                 fontWeight: FontWeight.bold,
//                 letterSpacing: 0.5,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class _AnimatedText extends StatefulWidget {
//   final String text;
//   final TextStyle style;

//   const _AnimatedText({
//     required this.text,
//     required this.style,
//   });

//   @override
//   State<_AnimatedText> createState() => _AnimatedTextState();
// }

// class _AnimatedTextState extends State<_AnimatedText> with SingleTickerProviderStateMixin {
//   late AnimationController _controller;
//   late Animation<double> _scaleAnimation;

//   @override
//   void initState() {
//     super.initState();
//     _controller = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 700),
//     )..repeat(reverse: true);

//     _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
//       CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
//     );
//   }

//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return ScaleTransition(
//       scale: _scaleAnimation,
//       child: Text(
//         widget.text,
//         style: widget.style,
//       ),
//     );
//   }
// }