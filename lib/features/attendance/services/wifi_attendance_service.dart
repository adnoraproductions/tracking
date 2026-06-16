import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:network_info_plus/network_info_plus.dart';

/// Configuration for office WiFi networks
class OfficeNetwork {
  const OfficeNetwork({
    required this.name,
    required this.allowedBssids,
  });

  final String name;
  final List<String> allowedBssids;
}

/// Service for monitoring WiFi connection and triggering auto check-in/out
class WifiAttendanceService {
  WifiAttendanceService({
    required this.officeNetworks,
    required this.onAutoCheckIn,
    required this.onAutoCheckOut,
    required this.onConnectionLost,
    this.pollInterval = const Duration(seconds: 30),
    this.checkoutTimeout = const Duration(minutes: 5),
  }) {
    _networkInfo = NetworkInfo();
  }

  final List<OfficeNetwork> officeNetworks;
  final Future<void> Function(String bssid) onAutoCheckIn;
  final Future<void> Function(String bssid, String reason) onAutoCheckOut;
  final Future<void> Function(String lastKnownBssid) onConnectionLost;
  final Duration pollInterval;
  final Duration checkoutTimeout;

  late final NetworkInfo _networkInfo;
  Timer? _pollingTimer;
  Timer? _checkoutTimer;

  bool _isConnectedToOffice = false;
  String? _currentBssid;


  bool get isConnected => _isConnectedToOffice;
  String? get currentBssid => _currentBssid;

  void startMonitoring() {
    if (_pollingTimer != null) return;
    
    // Initial check
    _checkConnection();

    // Poll periodically
    _pollingTimer = Timer.periodic(pollInterval, (_) => _checkConnection());
  }

  void stopMonitoring() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _cancelCheckoutTimer();
  }

  Future<void> _checkConnection() async {
    try {
      final currentBssid = await _networkInfo.getWifiBSSID();
      if (currentBssid == null || currentBssid.isEmpty) {
        _handleDisconnect();
        return;
      }

      // Check if current BSSID matches any office network
      final isOffice = officeNetworks.any((net) => 
        net.allowedBssids.contains(currentBssid.toLowerCase()));

      if (isOffice) {
        _handleConnect(currentBssid);
      } else {
        _handleDisconnect();
      }
    } catch (e) {
      debugPrint('Error checking WiFi: $e');
      _handleDisconnect();
    }
  }

  void _handleConnect(String bssid) {
    _cancelCheckoutTimer();
    
    if (!_isConnectedToOffice) {
      _isConnectedToOffice = true;
      _currentBssid = bssid;

      
      // Trigger Auto Check-In
      onAutoCheckIn(bssid);
    }
  }

  void _handleDisconnect() {
    if (_isConnectedToOffice) {
      _isConnectedToOffice = false;

      
      final lastBssid = _currentBssid ?? 'unknown';
      onConnectionLost(lastBssid);

      // Start 5 min countdown for auto check-out
      _startCheckoutTimer(lastBssid);
    }
  }

  void _startCheckoutTimer(String bssid) {
    _cancelCheckoutTimer();
    _checkoutTimer = Timer(checkoutTimeout, () {
      if (!_isConnectedToOffice) {
        onAutoCheckOut(bssid, '5_MIN_DISCONNECT');
        _currentBssid = null;
      }
    });
  }

  void _cancelCheckoutTimer() {
    _checkoutTimer?.cancel();
    _checkoutTimer = null;
  }
}
