// lib/services/command_service.dart
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:rover_companion/models/rover_state.dart';
import 'package:rover_companion/models/app_config.dart';

class CommandService {
  final AppConfig config;
  bool _isConnected = false;
  DateTime? _lastSuccessfulCommand;
  Timer? _heartbeatTimer;

  // Prevent command flooding
  MoveDirection? _lastSent;
  DateTime? _lastSentAt;
  static const _minCommandInterval = Duration(milliseconds: 150);

  bool get isConnected => _isConnected;
  DateTime? get lastSuccessfulCommand => _lastSuccessfulCommand;

  CommandService(this.config) {
    _startHeartbeat();
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      await ping();
    });
  }

  Future<bool> ping() async {
    try {
      final res = await http
          .get(Uri.parse('${config.roverBaseUrl}/move?dir=stop'))
          .timeout(const Duration(seconds: 3));
      _isConnected = res.statusCode == 200;
    } catch (_) {
      _isConnected = false;
    }
    return _isConnected;
  }

  Future<bool> autoDiscoverRover() async {
    if (await ping()) return true;

    try {
      final interfaces = await NetworkInterface.list();
      final Set<String> subnets = {};
      for (var iface in interfaces) {
        for (var addr in iface.addresses) {
          if (addr.type == InternetAddressType.IPv4) {
            final ip = addr.address;
            final parts = ip.split('.');
            if (parts.length == 4) {
              subnets.add('${parts[0]}.${parts[1]}.${parts[2]}');
            }
          }
        }
      }
      
      // Known fallback Hotspot subnets in Android
      subnets.addAll(['192.168.43', '192.168.212', '192.168.106']);

      for (var subnet in subnets) {
        final tasks = <Future<String?>>[];
        for (int i = 1; i <= 254; i++) {
          final target = 'http://$subnet.$i';
          tasks.add((() async {
            try {
              final res = await http.get(Uri.parse('$target/status')).timeout(const Duration(milliseconds: 600));
              if (res.statusCode == 200 && res.body.contains("status")) {
                return target;
              }
            } catch (_) {}
            return null;
          })());
        }
        
        final results = await Future.wait(tasks);
        final found = results.firstWhere((ip) => ip != null, orElse: () => null);
        
        if (found != null) {
          config.roverHost = found;
          await config.save();
          return await ping();
        }
      }
    } catch (_) {}
    
    return false;
  }

  Future<bool> sendMove(MoveDirection dir) async {
    // Throttle duplicate commands
    final now = DateTime.now();
    if (_lastSent == dir &&
        _lastSentAt != null &&
        now.difference(_lastSentAt!) < _minCommandInterval) {
      return true;
    }

    _lastSent = dir;
    _lastSentAt = now;

    final dirStr = _dirToString(dir);
    try {
      final res = await http
          .get(Uri.parse('${config.roverBaseUrl}/move?dir=$dirStr'))
          .timeout(const Duration(seconds: 2));
      if (res.statusCode == 200) {
        _isConnected = true;
        _lastSuccessfulCommand = DateTime.now();
        return true;
      }
    } catch (_) {
      _isConnected = false;
    }
    return false;
  }

  Future<bool> sendServoAngle(int angle) async {
    final clamped = angle.clamp(0, 180);
    try {
      final res = await http
          .get(Uri.parse('${config.roverBaseUrl}/servo?angle=$clamped'))
          .timeout(const Duration(seconds: 2));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> sendStop() => sendMove(MoveDirection.stop);

  String _dirToString(MoveDirection dir) {
    switch (dir) {
      case MoveDirection.forward:
        return 'forward';
      case MoveDirection.backward:
        return 'back';
      case MoveDirection.left:
        return 'left';
      case MoveDirection.right:
        return 'right';
      case MoveDirection.stop:
        return 'stop';
    }
  }

  void dispose() {
    _heartbeatTimer?.cancel();
  }
  
  Future<int> getBatteryPercentage() async {
    try {
      final response = await http.get(
        Uri.parse('http://$roverHost/battery'),
      ).timeout(const Duration(seconds: 2));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['battery_percent'] ?? -1;
      }
    } catch (e) {
      debugPrint('Battery fetch failed: $e');
    }
    return -1; // Return -1 if can't fetch
  }
  
  Future<double> getBatteryVoltage() async {
    try {
      final response = await http.get(
        Uri.parse('http://$roverHost/battery'),
      ).timeout(const Duration(seconds: 2));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['voltage'] ?? -1.0;
      }
    } catch (e) {
      debugPrint('Battery voltage fetch failed: $e');
    }
    return -1.0;
  }
}

}
