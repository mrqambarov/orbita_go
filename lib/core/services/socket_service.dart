import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config/app_config.dart';

class SocketService {
  io.Socket? _socket;

  io.Socket get socket {
    _socket ??= _createSocket();
    return _socket!;
  }

  io.Socket _createSocket() {
    return io.io(
      AppConfig.socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .setReconnectionAttempts(10)
          .setReconnectionDelay(2000)
          .build(),
    );
  }

  Future<void> connect(String userId, {bool isDriver = false}) async {
    socket.connect();
    // Remove old connect handler before adding new one
    socket.off('connect');
    socket.onConnect((_) {
      if (isDriver) {
        socket.emit('join_driver_room', userId);
      } else {
        socket.emit('join_user_room', userId);
      }
      // Also join the general client room for status updates
      if (!isDriver) {
        socket.emit('join_client_room', userId);
      }
      print('🔌 Socket connected and joined room: ${isDriver ? "driver" : "client"}_$userId');
    });
    // If already connected, join immediately
    if (socket.connected) {
      if (isDriver) {
        socket.emit('join_driver_room', userId);
      } else {
        socket.emit('join_user_room', userId);
        socket.emit('join_client_room', userId);
      }
      print('🔌 Socket already connected, joined room: ${isDriver ? "driver" : "client"}_$userId');
    }
  }

  // Register a named listener — SAFE to remove individually without affecting others
  void on(String event, Function(dynamic) callback) {
    socket.on(event, callback);
  }

  // Use socket.off() directly with the exact handler reference

  void onDriverLocationUpdate(Function(Map<String, dynamic>) callback) {
    socket.on('driver_location_update', (data) {
      callback(Map<String, dynamic>.from(data as Map));
    });
  }

  void onOrderStatusUpdate(Function(Map<String, dynamic>) callback) {
    socket.on('order_status_update', (data) {
      callback(Map<String, dynamic>.from(data as Map));
    });
  }

  void onDriverFound(Function(Map<String, dynamic>) callback) {
    socket.on('driver_found', (data) {
      callback(Map<String, dynamic>.from(data as Map));
    });
  }

  void onDriverArrived(Function() callback) {
    socket.on('driver_arrived', (_) => callback());
  }

  void onTripStarted(Function() callback) {
    socket.on('trip_started', (_) => callback());
  }

  void onTripCompleted(Function(Map<String, dynamic>) callback) {
    socket.on('trip_completed', (data) {
      callback(Map<String, dynamic>.from(data as Map));
    });
  }

  void onNewOrder(Function(Map<String, dynamic>) callback) {
    socket.on('new_order', (data) {
      callback(Map<String, dynamic>.from(data as Map));
    });
  }

  void onOrderCancelled(Function(Map<String, dynamic>) callback) {
    socket.on('order_cancelled', (data) {
      callback(Map<String, dynamic>.from(data as Map));
    });
  }

  void disconnect() {
    _socket?.disconnect();
    _socket = null;
  }

  void removeAllListeners() {
    _socket?.clearListeners();
  }

  bool get isConnected => _socket?.connected ?? false;
}

final socketServiceProvider = Provider<SocketService>((ref) => SocketService());
