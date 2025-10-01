//lib/models/product.dart
class Product {
  final String id;
  final String name;
  final String description;
  final double price;
  final String category;
  final int stockQuantity;
  final String vendorId;
  final String? vendorBusinessName;
  final List<String> imageUrls;
  final int salesCount;
  final bool isActive;
  final bool isFlashsale; // <-- New field

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    required this.stockQuantity,
    required this.vendorId,
    this.vendorBusinessName,
    this.imageUrls = const [],
    this.salesCount = 0,
    this.isActive = true,
    this.isFlashsale = false, // <-- New parameter
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    List<String> parsedImageUrls = [];

    try {
      if (json['imageUrls'] is List) {
        parsedImageUrls = List<String>.from(
            (json['imageUrls'] as List<dynamic>).map((url) => url.toString()));
      } else if (json['imageUrls'] is String) {
        parsedImageUrls = [json['imageUrls']];
      }
    } catch (e) {
      parsedImageUrls = [];
    }

    String vendorId;
    String? vendorBusinessName;

    if (json['vendor'] is Map) {
      vendorId = json['vendor']['_id'] ?? '';
      vendorBusinessName = json['vendor']['businessName'];
    } else {
      vendorId = json['vendor'] ?? '';
      vendorBusinessName = null;
    }

    return Product(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      price: (json['price'] as num).toDouble(),
      category: json['category'] ?? '',
      stockQuantity: json['stockQuantity'] ?? 0,
      vendorId: vendorId,
      vendorBusinessName: vendorBusinessName,
      imageUrls: parsedImageUrls,
      salesCount: json['salesCount'] ?? 0,
      isActive: json['isActive'] ?? true,
      isFlashsale: json['is_flashsale'] ?? false, // <-- Updated fromJson logic
    );
  }

  Map<String, dynamic> toJson() => {
        '_id': id,
        'name': name,
        'description': description,
        'price': price,
        'category': category,
        'stockQuantity': stockQuantity,
        'vendor': vendorId,
        'imageUrls': imageUrls,
        'salesCount': salesCount,
        'isActive': isActive,
        'is_flashsale': isFlashsale, // <-- Added toJson logic
      };
}