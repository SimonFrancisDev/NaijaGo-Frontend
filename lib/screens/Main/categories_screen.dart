// lib/screens/Main/categories_screen.dart

import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'CategoryProductsScreen.dart';
import 'ai_diagnosis_screen.dart';
import 'chat_screen.dart';

class CategoryItem {
  final String name;
  final IconData? icon;
  final String? image;

  const CategoryItem({required this.name, this.icon, this.image});
}

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  String _searchQuery = "";

  static const deepNavyBlue = Color.fromARGB(255, 3, 2, 76);

  static const Map<String, List<CategoryItem>> categorySections = {
    "Supermarket": [
      CategoryItem(
        name: "Groceries",
        image: "assets/categories/groceries.jpg",
        icon: Ionicons.cart_outline,
      ),
      CategoryItem(
        name: "Baby Products",
        image: "assets/categories/baby_products.jpg",
        icon: Ionicons.happy_outline,
      ),
      CategoryItem(
        name: "Others",
        image: "assets/categories/others.png",
        icon: Ionicons.ellipsis_horizontal_circle_outline,
      ),
    ],
    "Health & Beauty": [
      CategoryItem(
        name: "Accessories",
        image: "assets/categories/accessories.jpg",
        icon: Ionicons.watch_outline,
      ),
      CategoryItem(
        name: "Perfume & Jewelry",
        image: "assets/categories/perfume_jewelry.jpg",
        icon: Ionicons.diamond_outline,
      ),
      CategoryItem(
        name: "Pharmacy",
        image: "assets/categories/pharmacy.jpg",
        icon: Ionicons.medical_outline,
      ),
    ],
    "Fashion": [
      CategoryItem(
        name: "Men",
        image: "assets/categories/fashion_men.jpg",
        icon: Ionicons.man_outline,
      ),
      CategoryItem(
        name: "Women",
        image: "assets/categories/fashion_women.jpg",
        icon: Ionicons.woman_outline,
      ),
      CategoryItem(
        name: "Kids",
        image: "assets/categories/fashion_kids.jpg",
        icon: Ionicons.body_outline,
      ),
    ],
    "Phones & Tablets": [
      CategoryItem(
        name: "Smartphones",
        image: "assets/categories/smartphones.jpg",
        icon: Ionicons.phone_portrait_outline,
      ),
      CategoryItem(
        name: "Tablets",
        image: "assets/categories/tablets.jpg",
        icon: Ionicons.tablet_landscape_outline,
      ),
      CategoryItem(
        name: "Accessories",
        image: "assets/categories/phone_accessories.jpg",
        icon: Ionicons.headset_outline,
      ),
    ],
    "Electronics": [
      CategoryItem(
        name: "TV & Audio",
        image: "assets/categories/tv_audio.jpg",
        icon: Ionicons.tv_outline,
      ),
      CategoryItem(
        name: "Computing",
        image: "assets/categories/computing.jpg",
        icon: Ionicons.laptop_outline,
      ),
      CategoryItem(
        name: "Gaming",
        image: "assets/categories/gaming.jpg",
        icon: Ionicons.game_controller_outline,
      ),
    ],
    "Home & Office": [
      CategoryItem(
        name: "Appliances",
        image: "assets/categories/appliances.jpg",
        icon: Ionicons.cube_outline,
      ),
      CategoryItem(
        name: "Sporting Goods",
        image: "assets/categories/sporting_goods.jpg",
        icon: Ionicons.football_outline,
      ),
      CategoryItem(
        name: "Books & Stationery",
        image: "assets/categories/books_stationery.jpg",
        icon: Ionicons.book_outline,
      ),
      CategoryItem(
        name: "Automobiles & Tools",
        image: "assets/categories/automobiles_tools.jpg",
        icon: Ionicons.car_outline,
      ),
    ],
  };

  Future<void> _launchWhatsApp(String phoneNumber, String message) async {
    final encodedMessage = Uri.encodeComponent(message);
    final url = 'https://wa.me/$phoneNumber?text=$encodedMessage';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _handleSpecialCategories(BuildContext context, CategoryItem category) {
  if (category.name == 'Pharmacy') {
    // ✅ Navigate directly to ChatScreen (in-app chat)
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ChatScreen(),
      ),
    );
    return;
  } else {
    final sectionName =
        categorySections.entries.firstWhere((e) => e.value.contains(category)).key;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CategoryProductsScreen(category: "$sectionName > ${category.name}"),
      ),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    final allCategories = categorySections.entries
        .expand((entry) => entry.value.map((item) => {"section": entry.key, "item": item}))
        .toList();

    final filteredCategories = _searchQuery.isEmpty
        ? allCategories
        : allCategories
            .where((entry) => (entry["item"] as CategoryItem)
                .name
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()))
            .toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: deepNavyBlue,
        elevation: 0,
        title: Container(
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Search categories or products...',
              prefixIcon: Icon(Icons.search, color: Colors.grey),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 10),
            ),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
        ),
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: deepNavyBlue),
              child: const Text(
                "All Categories",
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            ...categorySections.entries.map((entry) {
              return ExpansionTile(
                title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                children: entry.value.map((cat) {
                  return ListTile(
                    leading: _CategoryThumb(image: cat.image, icon: cat.icon, size: 28),
                    title: Text(cat.name),
                    onTap: () {
                      Navigator.pop(context);
                      _handleSpecialCategories(context, cat);
                    },
                  );
                }).toList(),
              );
            }),
          ],
        ),
      ),
      body: _searchQuery.isNotEmpty
          ? _buildSearchResults(filteredCategories)
          : _buildCategorySections(),
    );
  }

  Widget _buildSearchResults(List<Map<String, Object>> filteredCategories) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredCategories.length,
      itemBuilder: (context, index) {
        final entry = filteredCategories[index];
        final section = entry["section"] as String;
        final cat = entry["item"] as CategoryItem;

        return ListTile(
          leading: _CategoryThumb(image: cat.image, icon: cat.icon, size: 32),
          title: Text(cat.name),
          subtitle: Text(section),
          onTap: () => _handleSpecialCategories(context, cat),
        );
      },
    );
  }

  Widget _buildCategorySections() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: categorySections.keys.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final sectionName = categorySections.keys.elementAt(index);
        final items = categorySections[sectionName]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  sectionName.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // Navigate to CategoryProductsScreen for the entire section
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CategoryProductsScreen(category: sectionName),
                      ),
                    );
                  },
                  child: const Text(
                    "SEE ALL",
                    style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 0.7,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final cat = items[i];
                return GestureDetector(
                  onTap: () => _handleSpecialCategories(context, cat),
                  child: Column(
                    children: [
                      Container(
                        height: 60,
                        width: 60,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _CategoryThumb(image: cat.image, icon: cat.icon),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        cat.name,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _CategoryThumb extends StatelessWidget {
  final String? image;
  final IconData? icon;
  final double size;

  const _CategoryThumb({this.image, this.icon, this.size = 24});

  @override
  Widget build(BuildContext context) {
    if (image != null && image!.isNotEmpty) {
      return Image.asset(
        image!,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Icon(icon ?? Icons.image_not_supported, size: size),
      );
    }
    return Icon(icon ?? Icons.category, color: Colors.black54, size: size);
  }
}