class Client {
  const Client({
    required this.id,
    required this.name,
    required this.industry,
    this.logoUrl,
    required this.status,
    required this.financials,
    this.contacts = const [],
    this.notes,
    required this.createdAt,
    this.updatedAt,
  });

  factory Client.fromJson(Map<String, dynamic> json) {
    return Client(
      id: json['id'],
      name: json['name'],
      industry: json['industry'],
      logoUrl: json['logo_url'],
      status: json['status'],
      financials: ClientFinancials.fromJson(json['financials'] ?? {}),
      contacts: (json['contacts'] as List?)?.map((e) => ClientContact.fromJson(e)).toList() ?? [],
      notes: json['notes'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  final String id;
  final String name;
  final String industry;
  final String? logoUrl;
  final String status;
  final ClientFinancials financials;
  final List<ClientContact> contacts;
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;


  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'industry': industry,
      'logo_url': logoUrl,
      'status': status,
      'financials': financials.toJson(),
      'contacts': contacts.map((e) => e.toJson()).toList(),
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}

class ClientContact {
  const ClientContact({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    required this.role,
    this.isPrimary = false,
  });

  factory ClientContact.fromJson(Map<String, dynamic> json) {
    return ClientContact(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      phone: json['phone'],
      role: json['role'],
      isPrimary: json['is_primary'] ?? false,
    );
  }

  final String id;
  final String name;
  final String email;
  final String? phone;
  final String role;
  final bool isPrimary;


  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'is_primary': isPrimary,
    };
  }
}

class ClientFinancials {
  const ClientFinancials({
    this.totalRevenue = 0.0,
    this.pendingPayments = 0.0,
    this.lastPaymentDate,
  });

  factory ClientFinancials.fromJson(Map<String, dynamic> json) {
    return ClientFinancials(
      totalRevenue: (json['total_revenue'] as num?)?.toDouble() ?? 0.0,
      pendingPayments: (json['pending_payments'] as num?)?.toDouble() ?? 0.0,
      lastPaymentDate: json['last_payment_date'] != null ? DateTime.parse(json['last_payment_date']) : null,
    );
  }

  final double totalRevenue;
  final double pendingPayments;
  final DateTime? lastPaymentDate;


  Map<String, dynamic> toJson() {
    return {
      'total_revenue': totalRevenue,
      'pending_payments': pendingPayments,
      'last_payment_date': lastPaymentDate?.toIso8601String(),
    };
  }
}
