// lib/ui/widgets/status_hud.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jessrv1/models/rover_state.dart';
import 'package:jessrv1/engines/state_manager.dart';
import 'package:jessrv1/ui/widgets/battery_indicator.dart';

class StatusHUD extends StatelessWidget {
  final StateManager sm;

  const StatusHUD({super.key, required this.sm});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.65),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _stateColor(sm.mainState).withOpacity(0.4),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _dot(sm.isConnected
              ? const Color(0xFF00FF88)
              : const Color(0xFFFF3355)),
          const SizedBox(width: 8),
          Text(
            sm.mainState.label,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: _stateColor(sm.mainState),
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            sm.emotionalState.emoji,
            style: const TextStyle(fontSize: 16),
          ),
          
          // ✅ CORRECTED: Use sm directly, not Consumer
          const Spacer(),
          
          // ✅ CORRECTED: Use sm.batteryPercent directly
          BatteryIndicator(
            batteryPercent: sm.batteryPercent ?? -1,
            voltage: sm.batteryVoltage,
          ),
          
          if (sm.lastPerception.personDetected) ...[
            const SizedBox(width: 10),
            const Icon(Icons.person, color: Color(0xFF00CFFF), size: 16),
          ],
          if (sm.isListening) ...[
            const SizedBox(width: 10),
            _pulseDot(const Color(0xFFFF4488)),
          ],
        ],
      ),
    );
  }

  Widget _dot(Color color) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color, blurRadius: 6)],
      ),
    );
  }

  Widget _pulseDot(Color color) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.5, end: 1.0),
      duration: const Duration(milliseconds: 600),
      builder: (_, v, __) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: color.withOpacity(v),
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  Color _stateColor(MainState s) {
    switch (s) {
      case MainState.idle:
        return const Color(0xFF7080A0);
      case MainState.manual:
        return const Color(0xFFFFAA00);
      case MainState.tracking:
        return const Color(0xFF00CFFF);
      case MainState.interacting:
        return const Color(0xFF00FF88);
      case MainState.searching:
        return const Color(0xFFFF8040);
      case MainState.error:
        return const Color(0xFFFF3355);
    }
  }
}