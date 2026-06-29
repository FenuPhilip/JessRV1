// lib/ui/screens/control_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jessrv1/engines/state_manager.dart';
import 'package:jessrv1/models/rover_state.dart';
import 'package:jessrv1/ui/widgets/dpad_control.dart';
import 'package:jessrv1/ui/widgets/camera_stream_widget.dart';
import 'package:jessrv1/ui/widgets/status_hud.dart';

class ControlScreen extends StatefulWidget {
  const ControlScreen({super.key});

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> {
  @override
  void initState() {
    super.initState();
    
    // Start battery polling when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sm = context.read<StateManager>();
      sm.startBatteryPolling();
      sm.lowBatteryCallback = (percent) {
        _showLowBatterySnackbar(percent);
      };
    });
  }

  @override
  void dispose() {
    // Stop battery polling when screen closes
    final sm = context.read<StateManager>();
    sm.stopBatteryPolling();
    super.dispose();
  }

  void _showLowBatterySnackbar(int percent) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '⚠️ Low Battery: $percent% remaining! Please charge the rover.',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sm = context.watch<StateManager>();
    final isManual = sm.mainState == MainState.manual;

    return Scaffold(
      backgroundColor: const Color(0xFF070B12),
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: const Color(0xFF111825),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Color(0xFF8090B0),
                        size: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  StatusHUD(sm: sm),
                  const Spacer(),
                  // Mode toggle
                  _ModeToggle(sm: sm),
                ],
              ),
            ),

            // Camera feed
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: CameraStreamWidget(
                        cameraService: sm.cameraService,
                      ),
                    ),
                    // Tracking overlay
                    if (sm.mainState == MainState.tracking &&
                        sm.lastPerception.bbox != null)
                      _TrackingOverlay(sm: sm),
                    // Corner markers
                    const _CornerMarkers(),
                  ],
                ),
              ),
            ),

            // Servo control strip
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: _ServoControl(sm: sm),
            ),

            // D-Pad controls
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    DPadControl(
                      enabled: isManual,
                      onCommand: (dir) {
                        if (isManual) sm.sendManualCommand(dir);
                      },
                    ),
                    const SizedBox(height: 12),
                    if (!isManual)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: const Color(0xFFFFAA00).withOpacity(0.1),
                          border: Border.all(
                            color: const Color(0xFFFFAA00).withOpacity(0.3),
                          ),
                        ),
                        child: const Text(
                          'Switch to MANUAL to drive',
                          style: TextStyle(
                            color: Color(0xFFFFAA00),
                            fontSize: 11,
                            fontFamily: 'monospace',
                          ),
                        ),
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

// ─── Mode Toggle Widget ───────────────────────────────────────
class _ModeToggle extends StatelessWidget {
  final StateManager sm;
  const _ModeToggle({required this.sm});

  @override
  Widget build(BuildContext context) {
    final isManual = sm.mainState == MainState.manual;
    return GestureDetector(
      onTap: isManual ? sm.setAutoMode : sm.setManualMode,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: isManual
              ? const Color(0xFFFFAA00).withOpacity(0.15)
              : const Color(0xFF00CFFF).withOpacity(0.15),
          border: Border.all(
            color: isManual
                ? const Color(0xFFFFAA00)
                : const Color(0xFF00CFFF),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isManual
                  ? Icons.gamepad_rounded
                  : Icons.auto_mode_rounded,
              color: isManual
                  ? const Color(0xFFFFAA00)
                  : const Color(0xFF00CFFF),
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              isManual ? 'MANUAL' : 'AUTO',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isManual
                    ? const Color(0xFFFFAA00)
                    : const Color(0xFF00CFFF),
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Servo Control Widget ─────────────────────────────────────
class _ServoControl extends StatelessWidget {
  final StateManager sm;
  const _ServoControl({required this.sm});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          'TILT',
          style: TextStyle(
            fontFamily: 'monospace',
            color: Color(0xFF5060A0),
            fontSize: 11,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(width: 12),
        _ServoBtn(
          icon: Icons.keyboard_double_arrow_up_rounded,
          onTap: () => sm.adjustServo(-20),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              activeTrackColor: const Color(0xFF00CFFF),
              inactiveTrackColor: const Color(0xFF1A2030),
              thumbColor: const Color(0xFF00CFFF),
              overlayColor: const Color(0xFF00CFFF).withOpacity(0.2),
            ),
            child: Slider(
              min: 0,
              max: 180,
              value: sm.servoAngle.toDouble(),
              onChanged: (v) => sm.adjustServo(
                v.round() - sm.servoAngle,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _ServoBtn(
          icon: Icons.keyboard_double_arrow_down_rounded,
          onTap: () => sm.adjustServo(20),
        ),
        const SizedBox(width: 12),
        Text(
          '${sm.servoAngle}°',
          style: const TextStyle(
            fontFamily: 'monospace',
            color: Color(0xFF5060A0),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

// ─── Servo Button Widget ──────────────────────────────────────
class _ServoBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ServoBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: const Color(0xFF111825),
          border: Border.all(
            color: const Color(0xFF00CFFF).withOpacity(0.3),
          ),
        ),
        child: Icon(icon, color: const Color(0xFF00CFFF), size: 18),
      ),
    );
  }
}

// ─── Tracking Overlay Widget ──────────────────────────────────
class _TrackingOverlay extends StatelessWidget {
  final StateManager sm;
  const _TrackingOverlay({required this.sm});

  @override
  Widget build(BuildContext context) {
    final bbox = sm.lastPerception.bbox!;
    return LayoutBuilder(builder: (context, constraints) {
      final scaleX = constraints.maxWidth / 640;
      final scaleY = constraints.maxHeight / 480;
      return Stack(
        children: [
          Positioned(
            left: bbox.x * scaleX,
            top: bbox.y * scaleY,
            width: bbox.w * scaleX,
            height: bbox.h * scaleY,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: const Color(0xFF00FF88),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Align(
                alignment: Alignment.topLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  color: const Color(0xFF00FF88).withOpacity(0.8),
                  child: Text(
                    sm.lastPerception.label.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 9,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    });
  }
}

// ─── Corner Markers Widget ────────────────────────────────────
class _CornerMarkers extends StatelessWidget {
  const _CornerMarkers();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: CustomPaint(painter: _CornerPainter()),
    );
  }
}

// ─── Corner Painter ───────────────────────────────────────────
class _CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00CFFF).withOpacity(0.5)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    const len = 20.0;
    const r = 12.0;
    // TL
    canvas.drawLine(
      Offset(r, r + len),
      Offset(r, r),
      paint,
    );
    canvas.drawLine(
      Offset(r, r),
      Offset(r + len, r),
      paint,
    );
    // TR
    canvas.drawLine(
      Offset(size.width - r - len, r),
      Offset(size.width - r, r),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - r, r),
      Offset(size.width - r, r + len),
      paint,
    );
    // BL
    canvas.drawLine(
      Offset(r, size.height - r - len),
      Offset(r, size.height - r),
      paint,
    );
    canvas.drawLine(
      Offset(r, size.height - r),
      Offset(r + len, size.height - r),
      paint,
    );
    // BR
    canvas.drawLine(
      Offset(size.width - r - len, size.height - r),
      Offset(size.width - r, size.height - r),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - r, size.height - r - len),
      Offset(size.width - r, size.height - r),
      paint,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}