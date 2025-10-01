import 'package:flutter/material.dart';

class OrderTrackingWidget extends StatelessWidget {
  final String orderStatus;
  OrderTrackingWidget({
    Key? key,
    required this.orderStatus,
  }) : super(key: key);

  final List<String> statuses = [
    'pending',
    'processing',
    'shipped',
    'delivered',
  ];

  int get currentStep {
    final status = orderStatus.trim().toLowerCase();
    if (status == 'cancelled') return -1;
    return statuses.indexOf(status);
  }

  @override
  Widget build(BuildContext context) {
    final status = orderStatus.trim().toLowerCase();
    debugPrint('OrderTrackingWidget: orderStatus="$orderStatus", normalized="$status", currentStep=$currentStep');

    if (status == 'cancelled') {
      return Center(
        child: Text(
          'Order Cancelled',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(statuses.length, (index) {
        final isCompleted = index < currentStep;
        final isCurrent = index == currentStep;

        return Column(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: isCompleted || isCurrent
                  ? Colors.green
                  : Colors.grey[300],
              child: Icon(
                isCompleted
                    ? Icons.check
                    : isCurrent
                        ? Icons.radio_button_checked
                        : Icons.circle_outlined,
                color: isCompleted || isCurrent ? Colors.white : Colors.grey,
                size: 18,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              statuses[index][0].toUpperCase() + statuses[index].substring(1),
              style: TextStyle(
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                color: isCompleted || isCurrent ? Colors.black : Colors.grey,
              ),
            ),
          ],
        );
      }),
    );
  }
}
