// lib/engines/state_manager.dart

import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:rover_companion/models/app_config.dart';
import 'package:rover_companion/models/memory_model.dart';
import 'package:rover_companion/models/perception.dart';
import 'package:rover_companion/models/rover_state.dart';
import 'package:rover_companion/models/connection_status.dart';
import 'package:rover_companion/engines/perception_engine.dart';
import 'package:rover_companion/engines/intent_engine.dart';
import 'package:rover_companion/engines/behavior_engine.dart';
import 'package:rover_companion/services/command_service.dart';
import 'package:rover_companion/services/vision_service.dart';
import 'package:rover_companion/services/voice_service.dart';
import 'package:rover_companion/services/camera_service.dart';

class RoverStateManager extends ChangeNotifier {
  final AppConfig config;

  late final PerceptionEngine _perceptionEngine;
  late final IntentEngine _intentEngine;
  late final BehaviorEngine _behaviorEngine;
  late final CommandService _commandService;
  late final VisionService _visionService;
  late final VoiceService _voiceService;
  late final CameraService _cameraService;

  final RoverMemory _memory = RoverMemory();

  // Observable state
  MainState mainState = MainState.idle;
  EmotionalState emotionalState = EmotionalState.neutral;
  PerceptionResult lastPerception = PerceptionResult.empty();
  bool isConnected = false;
  bool isCameraAvailable = false;
  bool isListening = false;
  String statusMessage = 'Initializing...';
  int servoAngle = 90;
  String? lastVoiceCommand;

  /// Tracks detailed rover and camera connection states.
  ConnectionStatus connectionStatus = const ConnectionStatus();

  // Safety: timeout watchdog
  Timer? _watchdogTimer;
  Timer? _loopTimer;
  StreamSubscription? _frameSub;
  StreamSubscription? _voiceSub;

  bool _isLoopRunning = false;

  RoverStateManager(this.config) {
    _perceptionEngine = PerceptionEngine();
    _intentEngine = IntentEngine();
    _behaviorEngine = BehaviorEngine();
    _commandService = CommandService(config);
    _visionService = VisionService();
    _voiceService = VoiceService();
    _cameraService = CameraService(config);
  }

  Future<void> initialize() async {
    statusMessage = 'Initializing perception...';
    notifyListeners();

    try {
      await _perceptionEngine.initialize();
    } catch (e) {
      debugPrint('PerceptionEngine init error: $e');
    }
    
    try {
      await _visionService.initialize();
    } catch (e) {
      debugPrint('VisionService init error: $e');
    }

    try {
      await _voiceService.initialize();
    } catch (e) {
      debugPrint('VoiceService init error: $e');
    }

    // Connect voice commands
    _voiceSub = _voiceService.commandStream.listen(_handleVoiceCommand);

    // Try connecting to rover
    connectionStatus = connectionStatus.copyWith(
      rover: ConnectionState.connecting,
    );
    notifyListeners();

    isConnected = await _commandService.autoDiscoverRover();

    connectionStatus = connectionStatus.copyWith(
      rover: isConnected ? ConnectionState.connected : ConnectionState.disconnected,
      lastRoverContact: isConnected ? DateTime.now() : null,
      clearRoverError: true,
    );

    // Start camera stream from ESP32-CAM
    connectionStatus = connectionStatus.copyWith(
      camera: ConnectionState.connecting,
    );
    notifyListeners();

    final camFound = await _cameraService.autoDiscoverCam();
    if (camFound) {
      connectionStatus = connectionStatus.copyWith(
        camera: ConnectionState.connected,
        lastCameraFrame: DateTime.now(),
        clearCameraError: true,
      );
    } else {
      connectionStatus = connectionStatus.copyWith(
        camera: ConnectionState.disconnected,
        cameraErrorMessage: 'cam.local not found',
      );
    }
    notifyListeners();

    _cameraService.startStream();

    try {
      // Start the ML frame subscription
      _frameSub = _visionService.frameStream.listen(_onCameraFrame);
      await _visionService.startCapturing();
    } catch (e) {
      debugPrint('Vision capturing error: $e');
    }

    // Start behavior loop
    _startBehaviorLoop();

    // Start watchdog
    _startWatchdog();

    statusMessage = isConnected ? 'Connected' : 'Rover not found';
    notifyListeners();
  }

  void _startBehaviorLoop() {
    _loopTimer?.cancel();
    _loopTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (mainState != MainState.manual) {
        _runBehaviorCycle();
      }
    });
  }

  void _startWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      // Check rover connection
      final roverAlive = await _commandService.ping();
      isConnected = roverAlive;

      if (roverAlive) {
        connectionStatus = connectionStatus.copyWith(
          rover: ConnectionState.connected,
          lastRoverContact: DateTime.now(),
          clearRoverError: true,
        );
      } else {
        connectionStatus = connectionStatus.copyWith(
          rover: ConnectionState.disconnected,
          roverErrorMessage: 'No response from rover',
        );
        if (mainState != MainState.error) {
          _setMainState(MainState.error);
          statusMessage = 'Connection lost';
        }
      }

      // Check camera availability
      final camAvailable = _cameraService.isAvailable;
      if (camAvailable) {
        connectionStatus = connectionStatus.copyWith(
          camera: ConnectionState.connected,
          lastCameraFrame: DateTime.now(),
          clearCameraError: true,
        );
      } else if (connectionStatus.camera != ConnectionState.connecting &&
          connectionStatus.camera != ConnectionState.unknown) {
        connectionStatus = connectionStatus.copyWith(
          camera: ConnectionState.disconnected,
          cameraErrorMessage: 'Camera stream lost',
        );
      }

      notifyListeners();
    });
  }

  Future<void> _onCameraFrame(CameraImage frame) async {
    final perception = await _perceptionEngine.analyzeFrame(frame);
    lastPerception = perception;
    _memory.updateFromPerception(perception);
  }

  void _runBehaviorCycle() {
    final intent = _intentEngine.decide(
      perception: lastPerception,
      memory: _memory,
      currentState: mainState,
    );

    final output = _behaviorEngine.produce(
      intent: intent,
      perception: lastPerception,
      memory: _memory,
      currentState: mainState,
    );

    // Send movement command
    if (output.direction != MoveDirection.stop ||
        mainState == MainState.tracking) {
      _commandService.sendMove(output.direction);
      _memory.recordCommand(output.direction);
    }

    // Send servo angle if changed
    if (output.servoAngle != null && output.servoAngle != servoAngle) {
      servoAngle = output.servoAngle!;
      _commandService.sendServoAngle(servoAngle);
    }

    // Update states
    emotionalState = output.emotion;
    _setMainState(output.nextMainState);

    // Speak if needed
    if (output.speechText != null) {
      _voiceService.speak(output.speechText!);
      _memory.recordInteraction(output.speechText!);
    }

    notifyListeners();
  }

  void _handleVoiceCommand(VoiceCommandResult result) {
    lastVoiceCommand = result.rawCommand;

    if (result.direction != null) {
      if (mainState == MainState.manual) {
        _commandService.sendMove(result.direction!);
      }
    }

    if (result.targetMode != null) {
      _setMainState(result.targetMode!);
    }

    if (result.servoCommand != null) {
      switch (result.servoCommand) {
        case 'up':
          servoAngle = (servoAngle - 20).clamp(0, 180);
          break;
        case 'down':
          servoAngle = (servoAngle + 20).clamp(0, 180);
          break;
        case 'center':
          servoAngle = 90;
          break;
      }
      _commandService.sendServoAngle(servoAngle);
    }

    notifyListeners();
  }

  // ─── Public API ───

  void sendManualCommand(MoveDirection dir) {
    if (mainState != MainState.manual) return;
    _commandService.sendMove(dir);
    _memory.recordCommand(dir);
    notifyListeners();
  }

  void setManualMode() {
    _commandService.sendStop();
    _setMainState(MainState.manual);
    emotionalState = EmotionalState.neutral;
    notifyListeners();
  }

  void setAutoMode() {
    _setMainState(MainState.tracking);
    notifyListeners();
  }

  void setIdleMode() {
    _commandService.sendStop();
    _setMainState(MainState.idle);
    emotionalState = EmotionalState.sleepy;
    notifyListeners();
  }

  Future<void> toggleListening() async {
    if (isListening) {
      await _voiceService.stopListening();
      isListening = false;
    } else {
      await _voiceService.startListening();
      isListening = true;
    }
    notifyListeners();
  }

  void adjustServo(int delta) {
    servoAngle = (servoAngle + delta).clamp(0, 180);
    _commandService.sendServoAngle(servoAngle);
    notifyListeners();
  }

  void updateConfig(AppConfig newConfig) {
    config.roverHost = newConfig.roverHost;
    config.camHost = newConfig.camHost;
    config.save();
    _commandService.ping().then((c) {
      isConnected = c;
      notifyListeners();
    });
  }

  /// Reconnect the rover: set connecting state, run discovery, update status.
  Future<void> reconnectRover() async {
    connectionStatus = connectionStatus.copyWith(
      rover: ConnectionState.connecting,
      clearRoverError: true,
    );
    notifyListeners();

    isConnected = await _commandService.autoDiscoverRover();

    connectionStatus = connectionStatus.copyWith(
      rover: isConnected ? ConnectionState.connected : ConnectionState.disconnected,
      lastRoverContact: isConnected ? DateTime.now() : null,
      roverErrorMessage: isConnected ? null : 'Could not reach rover',
    );

    if (isConnected && mainState == MainState.error) {
      _setMainState(MainState.idle);
      statusMessage = 'Reconnected';
    } else if (!isConnected) {
      statusMessage = 'Rover unreachable';
    }

    notifyListeners();
  }

  /// Reconnect the camera: set connecting state, run discovery, restart stream.
  Future<void> reconnectCamera() async {
    connectionStatus = connectionStatus.copyWith(
      camera: ConnectionState.connecting,
      clearCameraError: true,
    );
    notifyListeners();

    final camFound = await _cameraService.autoDiscoverCam();
    if (camFound) {
      await _cameraService.startStream();
      connectionStatus = connectionStatus.copyWith(
        camera: ConnectionState.connected,
        lastCameraFrame: DateTime.now(),
        clearCameraError: true,
      );
    } else {
      connectionStatus = connectionStatus.copyWith(
        camera: ConnectionState.disconnected,
        cameraErrorMessage: 'Could not reach cam.local',
      );
    }

    notifyListeners();
  }

  void _setMainState(MainState s) {
    if (mainState != s) {
      _memory.lastMainState = s;
      mainState = s;
    }
  }

  RoverMemory get memory => _memory;
  CommandService get commandService => _commandService;
  CameraService get cameraService => _cameraService;

  @override
  Future<void> dispose() async {
    _loopTimer?.cancel();
    _watchdogTimer?.cancel();
    await _frameSub?.cancel();
    await _voiceSub?.cancel();
    await _commandService.sendStop();
    _commandService.dispose();
    await _perceptionEngine.dispose();
    await _visionService.dispose();
    await _voiceService.dispose();
    _cameraService.dispose();
    super.dispose();
  }
}
