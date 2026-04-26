import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  final StreamController<ConnectivityResult> _connectivityController =
      StreamController<ConnectivityResult>.broadcast();

  Stream<ConnectivityResult> get connectivityStream => _connectivityController.stream;

  ConnectivityService() {
    _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      // For simplicity, we take the first result if multiple are present
      if (results.isNotEmpty) {
        _connectivityController.add(results.first);
      }
    });
  }

  Future<bool> get isConnected async {
    final results = await _connectivity.checkConnectivity();
    if (results.isEmpty) return false;
    return results.any((result) => result != ConnectivityResult.none);
  }

  void dispose() {
    _connectivityController.close();
  }
}

final connectivityService = ConnectivityService();
