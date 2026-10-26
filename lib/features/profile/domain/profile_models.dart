import 'package:attend_mobile/features/auth/domain/auth_models.dart';

class UserPreferences {
  final String locale;
  final bool reducedMotion;
  final bool notificationsEnabled;

  const UserPreferences({
    this.locale = 'ar',
    this.reducedMotion = false,
    this.notificationsEnabled = false,
  });

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      locale: json['locale'] as String? ?? 'ar',
      reducedMotion: json['reducedMotion'] as bool? ?? false,
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'locale': locale,
        'reducedMotion': reducedMotion,
        'notificationsEnabled': notificationsEnabled,
      };

  UserPreferences copyWith({
    String? locale,
    bool? reducedMotion,
    bool? notificationsEnabled,
  }) {
    return UserPreferences(
      locale: locale ?? this.locale,
      reducedMotion: reducedMotion ?? this.reducedMotion,
      notificationsEnabled:
          notificationsEnabled ?? this.notificationsEnabled,
    );
  }
}

class UserProfile {
  final String userId;
  final String tenantId;
  final String companyName;
  final String displayName;
  final String email;
  final UserRole role;
  final String? branchName;
  final String? managerName;
  final String? jobTitle;
  final DateTime? hireDate;
  final String? phone;
  final String? secondaryEmail;
  final UserPreferences preferences;
  final int revision;
  final String? membershipId;
  final List<String> capabilities;

  const UserProfile({
    required this.userId,
    required this.tenantId,
    required this.companyName,
    required this.displayName,
    required this.email,
    required this.role,
    this.branchName,
    this.managerName,
    this.jobTitle,
    this.hireDate,
    this.phone,
    this.secondaryEmail,
    this.preferences = const UserPreferences(),
    this.revision = 1,
    this.membershipId,
    this.capabilities = const [],
  });

  factory UserProfile.fromSession(AuthSessionEntity session) {
    return UserProfile(
      userId: session.userId,
      tenantId: session.tenantId,
      companyName: session.tenantId.toUpperCase(),
      displayName: session.displayName,
      email: session.email,
      role: session.role,
      branchName: null,
      managerName: null,
      jobTitle: null,
      revision: 1,
    );
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final roleStr = json['role'] as String? ?? 'employee';
    final role = switch (roleStr) {
      'company_admin' || 'admin' => UserRole.companyAdmin,
      'hr' => UserRole.hr,
      'manager' => UserRole.manager,
      _ => UserRole.employee,
    };

    final tenantObj = json['tenant'] is Map<String, dynamic>
        ? json['tenant'] as Map<String, dynamic>
        : null;
    final employeeObj = json['employee'] is Map<String, dynamic>
        ? json['employee'] as Map<String, dynamic>
        : null;

    final companyName = tenantObj?['name'] as String? ??
        json['companyName'] as String? ??
        json['tenantSlug'] as String? ??
        'الشركة';
    final tenantId = tenantObj?['id'] as String? ??
        json['tenantId'] as String? ??
        '';

    final displayName = employeeObj?['displayName'] as String? ??
        json['displayName'] as String? ??
        json['name'] as String? ??
        'الموظف';
    final branchName = employeeObj?['branchName'] as String? ??
        json['branchName'] as String?;
    final managerName = employeeObj?['managerName'] as String? ??
        json['managerName'] as String?;
    final phone = employeeObj?['phone'] as String? ?? json['phone'] as String?;

    final rawCaps = json['capabilities'] as List<dynamic>? ?? [];
    final capabilities = rawCaps.map((c) => c.toString()).toList();

    return UserProfile(
      userId: json['userId'] as String? ?? json['id'] as String? ?? '',
      tenantId: tenantId,
      companyName: companyName,
      displayName: displayName,
      email: json['email'] as String? ?? '',
      role: role,
      branchName: branchName,
      managerName: managerName,
      jobTitle: json['jobTitle'] as String?,
      hireDate: json['hireDate'] != null ? DateTime.tryParse(json['hireDate'] as String) : null,
      phone: phone,
      secondaryEmail: employeeObj?['secondaryEmail'] as String? ??
          json['secondaryEmail'] as String?,
      preferences: json['preferences'] != null
          ? UserPreferences.fromJson(json['preferences'] as Map<String, dynamic>)
          : const UserPreferences(),
      revision: json['revision'] as int? ?? 1,
      membershipId: json['membershipId'] as String?,
      capabilities: capabilities,
    );
  }

  UserProfile copyWith({
    String? userId,
    String? tenantId,
    String? companyName,
    String? displayName,
    String? email,
    UserRole? role,
    String? branchName,
    String? managerName,
    String? jobTitle,
    DateTime? hireDate,
    String? phone,
    String? secondaryEmail,
    UserPreferences? preferences,
    int? revision,
    String? membershipId,
    List<String>? capabilities,
  }) {
    return UserProfile(
      userId: userId ?? this.userId,
      tenantId: tenantId ?? this.tenantId,
      companyName: companyName ?? this.companyName,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      role: role ?? this.role,
      branchName: branchName ?? this.branchName,
      managerName: managerName ?? this.managerName,
      jobTitle: jobTitle ?? this.jobTitle,
      hireDate: hireDate ?? this.hireDate,
      phone: phone ?? this.phone,
      secondaryEmail: secondaryEmail ?? this.secondaryEmail,
      preferences: preferences ?? this.preferences,
      revision: revision ?? this.revision,
      membershipId: membershipId ?? this.membershipId,
      capabilities: capabilities ?? this.capabilities,
    );
  }

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'tenantId': tenantId,
        'companyName': companyName,
        'displayName': displayName,
        'email': email,
        'role': role.name,
        'branchName': branchName,
        'managerName': managerName,
        'jobTitle': jobTitle,
        'hireDate': hireDate?.toIso8601String(),
        'phone': phone,
        if (secondaryEmail != null) 'secondaryEmail': secondaryEmail,
        'preferences': preferences.toJson(),
        'revision': revision,
        'membershipId': membershipId,
        'capabilities': capabilities,
      };
}

class AccountSession {
  final String id;
  final String clientType;
  final String? deviceInstallationId;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool current;

  const AccountSession({
    required this.id,
    required this.clientType,
    this.deviceInstallationId,
    required this.createdAt,
    required this.expiresAt,
    required this.current,
  });

  factory AccountSession.fromJson(Map<String, dynamic> json) => AccountSession(
        id: json['id'] as String? ?? '',
        clientType: json['clientType'] as String? ?? 'mobile',
        deviceInstallationId: json['deviceInstallationId'] as String?,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
        expiresAt: DateTime.tryParse(json['expiresAt'] as String? ?? '') ??
            DateTime.now(),
        current: json['current'] as bool? ?? false,
      );
}
