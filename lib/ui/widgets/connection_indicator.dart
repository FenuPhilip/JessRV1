// lib/ui/widgets/connection_indicator.dart

import 'package:flutter/material.dart';
import 'package:rover_companion/models/connection_status.dart';

/// A compact connection status indicator that shows rover and camera status
/// with colored dots and labels. Tapping opens a detailed expandable panel.
class ConnectionIndicator extends StatefulWidget {
  final ConnectionStatus status;
  final VoidCallback? onReconnectRover;
  final VoidCallback? onReconnectCamera;

  const ConnectionIndicator({
    super.key,
    required this.status,
    this.onReconnectRover,
    this.onReconnectCamera,
  });

  @override
  State<ConnectionIndicator> createState() => _ConnectionIndicatorState();
}

class _ConnectionIndicatorState extends State<ConnectionIndicator> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.65),
          borderRadius: BorderRadius.circular(_expanded ? 12 : 20),
          border: Border.all(
            color: _overallColor.withOpacity(0.4),
            width: 1,
          ),
        ),
        child: IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary row
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _miniDot(_statusColor(widget.status.rover)),
                  const SizedBox(width: 6),
                  Text(
                    'RC',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: _statusColor(widget.status.rover),
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(width: 10),
                  _miniDot(_statusColor(widget.status.camera)),
                  const SizedBox(width: 6),
                  Text(
                    'CAM',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: _statusColor(widget.status.camera),
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: Colors.white.withOpacity(0.5),
                    size: 14,
                  ),
                ],
              ),

              // Expanded detail panel
              if (_expanded) ...[
                const SizedBox(height: 8),
                _detailRow(
                  icon: Icons.sensors_rounded,
                  label: 'ROVER',
                  state: widget.status.rover,
                  error: widget.status.roverErrorMessage,
                  onReconnect: widget.onReconnectRover,
                ),
                const SizedBox(height: 6),
                _detailRow(
                  icon: Icons.videocam_rounded,
                  label: 'CAMERA',
                  state: widget.status.camera,
                  error: widget.status.cameraErrorMessage,
                  onReconnect: widget.onReconnectCamera,
                ),
                // Warning banner if both disconnected
                if (widget.status.rover == ConnectionState.disconnected &&
                    widget.status.camera == ConnectionState.disconnected)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF3355).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFFFF3355).withOpacity(0.3),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              color: Color(0xFFFF3355), size: 12),
                          SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Cannot reach rover.local or cam.local',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 9,
                                color: Color(0xFFFF8866),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniDot(Color color) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color, blurRadius: 4)],
      ),
    );
  }

  Widget _detailRow({
    required IconData icon,
    required String label,
    required ConnectionState state,
    String? error,
    VoidCallback? onReconnect,
  }) {
    final color = _statusColor(state);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 12),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 9,
            color: Color(0xFF5060A0),
            letterSpacing: 1,
          ),
        ),
        const SizedBox(width: 8),
        _dot(color, 6),
        const SizedBox(width: 5),
        Text(
          state.statusText.toUpperCase(),
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: color,
            letterSpacing: 0.5,
          ),
        ),
        if (error != null) ...[
          const SizedBox(width: 6),
          SizedBox(
            width: 80,
            child: Text(
              error,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 8,
                color: Color(0xFFFF8866),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
        if (state == ConnectionState.disconnected ||
            state == ConnectionState.error) ...[
          const SizedBox(width: 8),
          if (onReconnect != null)
            GestureDetector(
              onTap: onReconnect,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: color.withOpacity(0.15),
                  border: Border.all(color: color.withOpacity(0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh_rounded,
                        color: color, size: 10),
                    const SizedBox(width: 3),
                    Text(
                      'RETRY',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: color,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
        if (state == ConnectionState.connecting)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: color,
              ),
            ),
          ),
      ],
    );
  }

  Widget _dot(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color, blurRadius: 4)],
      ),
    );
  }

  Color get _overallColor {
    if (widget.status.isAllConnected) return const Color(0xFF00FF88);
    if (widget.status.rover == ConnectionState.connecting ||
        widget.status.camera == ConnectionState.connecting) {
      return const Color(0xFFFFAA00);
    }
    return const Color(0xFFFF3355);
  }

  Color _statusColor(ConnectionState state) {
    switch (state) {
      case ConnectionState.unknown:
        return const Color(0xFF506080);
      case ConnectionState.connecting:
        return const Color(0xFFFFAA00);
      case ConnectionState.connected:
        return const Color(0xFF00FF88);
      case ConnectionState.disconnected:
        return const Color(0xFFFF3355);
      case ConnectionState.error:
        return const Color(0xFFFF3355);
    }
  }
}