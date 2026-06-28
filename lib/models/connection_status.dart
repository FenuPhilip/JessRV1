// lib/models/connection_status.dart

/// Represents the status of a connection (rover or camera).
enum ConnectionState {
  /// Initial state - no connection attempt made yet
  unknown,

  /// Actively trying to connect
  connecting,

  /// Successfully connected
  connected,

  /// Connection was lost or failed
  disconnected,

  /// An error occurred during connection
  error,
}

extension ConnectionStateLabel on ConnectionState {
  String get label {
    switch (this) {
      case ConnectionState.unknown:
        return 'UNKNOWN';
      case ConnectionState.connecting:
        return 'CONNECTING';
      case ConnectionState.connected:
        return 'CONNECTED';
      case ConnectionState.disconnected:
        return 'DISCONNECTED';
      case ConnectionState.error:
        return 'ERROR';
    }
  }

  String get statusText {
    switch (this) {
      case ConnectionState.unknown:
        return 'Unknown';
      case ConnectionState.connecting:
        return 'Connecting\u2026';
      case ConnectionState.connected:
        return 'Connected';
      case ConnectionState.disconnected:
        return 'Disconnected';
      case ConnectionState.error:
        return 'Error';
    }
  }
}

/// Holds the full connection status for both rover and camera.
class ConnectionStatus {
  final ConnectionState rover;
  final ConnectionState camera;
  final DateTime? lastRoverContact;
  final DateTime? lastCameraFrame;
  final String? roverErrorMessage;
  final String? cameraErrorMessage;

  const ConnectionStatus({
    this.rover = ConnectionState.unknown,
    this.camera = ConnectionState.unknown,
    this.lastRoverContact,
    this.lastCameraFrame,
    this.roverErrorMessage,
    this.cameraErrorMessage,
  });

  bool get isRoverConnected => rover == ConnectionState.connected;
  bool get isCameraConnected => camera == ConnectionState.connected;
  bool get isAllConnected => isRoverConnected && isCameraConnected;
  bool get isAnyDisconnected =>
      rover == ConnectionState.disconnected ||
      camera == ConnectionState.disconnected;

  ConnectionStatus copyWith({
    ConnectionState? rover,
    ConnectionState? camera,
    DateTime? lastRoverContact,
    DateTime? lastCameraFrame,
    String? roverErrorMessage,
    String? cameraErrorMessage,
    bool clearRoverError = false,
    bool clearCameraError = false,
  }) {
    return ConnectionStatus(
      rover: rover ?? this.rover,
      camera: camera ?? this.camera,
      lastRoverContact: lastRoverContact ?? this.lastRoverContact,
      lastCameraFrame: lastCameraFrame ?? this.lastCameraFrame,
      roverErrorMessage:
          clearRoverError ? null : (roverErrorMessage ?? this.roverErrorMessage),
      cameraErrorMessage:
          clearCameraError ? null : (cameraErrorMessage ?? this.cameraErrorMessage),
    );
  }
}