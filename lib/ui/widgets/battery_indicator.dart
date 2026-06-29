import 'package:flutter/material.dart';

class BatteryIndicator extends StatelessWidget {
  final int batteryPercent;
  final double? voltage;
  
  const BatteryIndicator({
    Key? key,
    required this.batteryPercent,
    this.voltage,
  }) : super(key: key);

  Color _getBatteryColor() {
    if (batteryPercent == -1) return Colors.grey;
    if (batteryPercent < 20) return Colors.red;
    if (batteryPercent < 50) return Colors.orange;
    return Colors.green;
  }

  IconData _getBatteryIcon() {
    if (batteryPercent == -1) return Icons.battery_unknown;
    if (batteryPercent >= 90) return Icons.battery_full;
    if (batteryPercent >= 70) return Icons.battery_6_bar;
    if (batteryPercent >= 50) return Icons.battery_5_bar;
    if (batteryPercent >= 30) return Icons.battery_4_bar;
    if (batteryPercent >= 15) return Icons.battery_3_bar;
    if (batteryPercent >= 5) return Icons.battery_2_bar;
    return Icons.battery_1_bar;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getBatteryIcon(),
            color: _getBatteryColor(),
            size: 20,
          ),
          const SizedBox(width: 4),
          Text(
            batteryPercent == -1 ? '?' : '$batteryPercent%',
            style: TextStyle(
              color: _getBatteryColor(),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (voltage != null && voltage! > 0) ...[
            const SizedBox(width: 4),
            Text(
              '(${voltage!.toStringAsFixed(1)}V)',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 10,
              ),
            ),
          ],
        ],
      ),
    );
  }
}