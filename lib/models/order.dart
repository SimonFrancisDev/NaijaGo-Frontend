//lib/modles/order.dart
import 'order_item.dart';
import 'user.dart';

class Order {
  final String id;
  final DateTime createdAt;
  final User? buyer;
  final String shippingAddress;
  final List<OrderItem> orderItems;
  final String status;

  Order({
    required this.id,
    required this.createdAt,
    this.buyer,
    required this.shippingAddress,
    required this.orderItems,
    required this.status,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['_id'] ?? '',
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      buyer: json['buyer'] != null
          ? User.fromJson(json['buyer'] as Map<String, dynamic>)
          : null,
      shippingAddress: json['shippingAddress'] is String
          ? json['shippingAddress'] as String
          : (json['shippingAddress']?['address'] ?? 'No address'),
      orderItems: (json['orderItems'] as List<dynamic>)
          .map((item) => OrderItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      status: json['orderStatus'] ?? 'Pending', // <-- This is the fix.
    );
  }

  Map<String, dynamic> toJson() => {
        '_id': id,
        'createdAt': createdAt.toIso8601String(),
        'buyer': buyer?.toJson(),
        'shippingAddress': shippingAddress,
        'orderItems': orderItems.map((item) => item.toJson()).toList(),
        'status': status,
      };

  Order copyWith({
    String? id,
    DateTime? createdAt,
    User? buyer,
    String? shippingAddress,
    List<OrderItem>? orderItems,
    String? status,
  }) {
    return Order(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      buyer: buyer ?? this.buyer,
      shippingAddress: shippingAddress ?? this.shippingAddress,
      orderItems: orderItems ?? this.orderItems,
      status: status ?? this.status,
    );
  }
}