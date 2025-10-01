//lib/models/order_item.dart
import 'product.dart';

class OrderItem {
  final Product product;
  final int quantity;
  final double price;

  OrderItem({
    required this.product,
    required this.quantity,
    required this.price,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      product: Product.fromJson(json['product'] as Map<String, dynamic>),
      quantity: (json['quantity'] as num).toInt(),
      price: (json['price'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'product': product.toJson(),
        'quantity': quantity,
        'price': price,
      };
}


// // lib/models/order_item.dart

// import 'product.dart';

// class OrderItem {
//   final Product product;
//   final int quantity;
//   final double price;

//   OrderItem({
//     required this.product,
//     required this.quantity,
//     required this.price,
//   });

//   factory OrderItem.fromJson(Map<String, dynamic> json) {
//     return OrderItem(
//       product: Product.fromJson(json['product'] as Map<String, dynamic>),
//       quantity: (json['quantity'] as num).toInt(),
//       price: (json['price'] as num).toDouble(),
//     );
//   }

//   Map<String, dynamic> toJson() => {
//         'product': product.toJson(),
//         'quantity': quantity,
//         'price': price,
//       };
// }
