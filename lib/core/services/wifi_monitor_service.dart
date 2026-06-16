import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../features/admin/models/wifi_config.dart';
import '../../features/admin/repositories/admin_repository.dart';

/// WiFi connection status
class WifiStatus {
  const WifiStatus({
    this.isConnectedToOffice = false,
    this.currentSsid,
    this.currentBssid,
    this.matchedConfig,
  });

  final bool isConnectedToOffice;
  final String? currentSsid;
  final String? currentBssid;
  final WifiConfig? matchedConfig;

  @override
  String toString() =>
      'WifiStatus(office=$isConnectedToOffice, ssid=$currentSsid)';
}

/// Provider for WiFi status stream
final wifiStatusProvider = StreamProvider<WifiStatus>((ref) {
  final monitor = ref.watch(wifiMonitorServiceProvider);
  return monitor.statusStream;
});

final wifiMonitorServiceProvider = Provider<WifiMonitorService>((ref) {
  final adminRepo = ref.watch(adminRepositoryProvider);
  final service = WifiMonitorService(adminRepo);
  ref.onDispose(() => service.dispose());
  return service;
});

/// Monitors WiFi connectivity and checks against configured office networks
class WifiMonitorService {
  WifiMonitorService(this._adminRepo);

  final AdminRepository _adminRepo;
  final NetworkInfo _networkInfo = NetworkInfo();

  Timer? _pollTimer;
  List<WifiConfig> _configs = [];
  final _statusController = StreamController<WifiStatus>.broadcast();
  WifiStatus _lastStatus = const WifiStatus();

  Stream<WifiStatus> get statusStream => _statusController.stream;
  WifiStatus get currentStatus => _lastStatus;

  /// Start monitoring WiFi every [intervalSeconds]
  Future<void> startMonitoring({int intervalSeconds = 15}) async {
    // Request location permissions (required for WiFi SSID on Android 10+)
    final status = await Permission.locationWhenInUse.request();
    if (status.isDenied || status.isPermanentlyDenied) {
      debugPrint('WifiMonitor: Location permission denied. SSID will be <unknown>.');
    }

    // Load WiFi configs from server
    await _refreshConfigs();

    // Do an immediate check
    await _checkWifi();

    // Then poll periodically
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      Duration(seconds: intervalSeconds),
      (_) => _checkWifi(),
    );
  }

  Future<void> _refreshConfigs() async {
    try {
      _configs = await _adminRepo.getWifiConfigs();
      _configs = _configs.where((c) => c.isActive).toList();
      debugPrint('WifiMonitor: Loaded ${_configs.length} active WiFi configs');
    } catch (e) {
      debugPrint('WifiMonitor: Failed to load configs: $e');
    }
  }

  Future<void> _checkWifi() async {
    try {
      final ssid = await _networkInfo.getWifiName(); // Returns SSID with quotes
      final bssid = await _networkInfo.getWifiBSSID();

      // Clean SSID (remove surrounding quotes)
      final cleanSsid = ssid?.replaceAll('"', '').trim();

      if (cleanSsid == null || cleanSsid.isEmpty || cleanSsid == '<unknown ssid>') {
        _emitStatus(const WifiStatus());
        return;
      }

      // Check if current WiFi matches any configured network
      WifiConfig? matched;
      for (final config in _configs) {
        if (config.ssid.toLowerCase() == cleanSsid.toLowerCase()) {
          // STRICT SECURITY: BSSID must be configured and match exactly
          if (config.bssid != null && config.bssid!.isNotEmpty) {
            if (bssid?.toLowerCase() == config.bssid!.toLowerCase()) {
              matched = config;
              break;
            } else {
              debugPrint('WifiMonitor: BSSID mismatch. Possible spoofing detected. Configured: ${config.bssid}, Actual: $bssid');
            }
          } else {
            debugPrint('WifiMonitor: Insecure config for ${config.ssid}. BSSID is mandatory for attendance.');
          }
        }
      }

      _emitStatus(WifiStatus(
        isConnectedToOffice: matched != null,
        currentSsid: cleanSsid,
        currentBssid: bssid,
        matchedConfig: matched,
      ));
    } catch (e) {
      debugPrint('WifiMonitor: Check failed: $e');
      _emitStatus(const WifiStatus());
    }
  }

  void _emitStatus(WifiStatus status) {
    if (status.isConnectedToOffice != _lastStatus.isConnectedToOffice) {
      debugPrint('WifiMonitor: Status changed → $status');
    }
    _lastStatus = status;
    _statusController.add(status);
  }

  /// Force a config refresh (e.g., after admin adds new WiFi)
  Future<void> refreshConfigs() => _refreshConfigs();

  void dispose() {
    _pollTimer?.cancel();
    _statusController.close();
  }
}
