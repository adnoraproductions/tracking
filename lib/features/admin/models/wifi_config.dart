/// WiFi network configuration for office attendance gating
class WifiConfig {
  const WifiConfig({
    required this.id,
    this.orgId = 'adnora',
    required this.ssid,
    this.bssid,
    this.label = 'Office',
    this.isActive = true,
    this.createdBy,
    this.createdAt,
  });

  factory WifiConfig.fromJson(Map<String, dynamic> json) {
    return WifiConfig(
      id: json['id'],
      orgId: json['org_id'] ?? 'adnora',
      ssid: json['ssid'],
      bssid: json['bssid'],
      label: json['label'] ?? 'Office',
      isActive: json['is_active'] ?? true,
      createdBy: json['created_by'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  final String id;
  final String orgId;
  final String ssid;
  final String? bssid;
  final String label;
  final bool isActive;
  final String? createdBy;
  final DateTime? createdAt;


  Map<String, dynamic> toInsertJson() {
    return {
      'ssid': ssid,
      'bssid': bssid,
      'label': label,
      'is_active': isActive,
      'created_by': createdBy,
    };
  }
}
