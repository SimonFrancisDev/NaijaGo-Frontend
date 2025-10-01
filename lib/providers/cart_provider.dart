//lib/providers/cart_provider.dart
import 'package:flutter/material.dart';
import '../models/product.dart'; // Import the Product model

// Define a class to represent an item in the cart
class CartItem {
  final Product product;
  int quantity;

  CartItem({required this.product, this.quantity = 1});

  // Method to convert CartItem to JSON for order submission
  Map<String, dynamic> toJson() {
    return {
      'product': product.id,
      'name': product.name,
      'image': product.imageUrls.isNotEmpty
          ? product.imageUrls[0]
          : 'https://placehold.co/100x100/CCCCCC/000000?text=No+Image',
      'quantity': quantity,
      'price': product.price,
      'vendor': product.vendorId ?? 'unknown', // fallback if vendor is null
    };
  }
}

// CartProvider class manages the state of the shopping cart
class CartProvider with ChangeNotifier {
  final Map<String, CartItem> _items = {};

  Map<String, CartItem> get items => {..._items};

  int get itemCount {
    return _items.values.fold(0, (sum, item) => sum + item.quantity);
  }

  double get totalAmount {
    return _items.values.fold(0.0,
        (sum, item) => sum + (item.product.price * item.quantity));
  }

  void addProduct(Product product) {
    if (_items.containsKey(product.id)) {
      _items.update(product.id, (existingItem) {
        if (existingItem.quantity < product.stockQuantity) {
          existingItem.quantity++;
        } else {
          print('Cannot add more. Max stock reached for ${product.name}');
        }
        return existingItem;
      });
    } else {
      if (product.stockQuantity > 0) {
        _items.putIfAbsent(product.id, () => CartItem(product: product));
      } else {
        print('Product ${product.name} is out of stock.');
      }
    }
    notifyListeners();
  }

  void removeSingleItem(String productId) {
    if (!_items.containsKey(productId)) return;

    if (_items[productId]!.quantity > 1) {
      _items.update(
        productId,
        (existingItem) => CartItem(
          product: existingItem.product,
          quantity: existingItem.quantity - 1,
        ),
      );
    } else {
      _items.remove(productId);
    }
    notifyListeners();
  }

  void removeItem(String productId) {
    _items.remove(productId);
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    notifyListeners();
  }
}
