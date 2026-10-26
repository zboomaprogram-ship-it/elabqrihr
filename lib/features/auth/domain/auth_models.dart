import 'package:equatable/equatable.dart';

enum UserRole {
  companyAdmin,
  hr,
  manager,
  employee,
}

extension UserRoleX on UserRole {
  static UserRole fromApi(String role) {
    switch (role) {
      case 'company_admin':
        return UserRole.companyAdmin;
      case 'hr':
        return UserRole.hr;
      case 'manager':
        return UserRole.manager;
      case 'employee':
      default:
        return UserRole.employee;
    }
  }

  String toApi() {
    switch (this) {
      case UserRole.companyAdmin:
        return 'company_admin';
      case UserRole.hr:
        return 'hr';
      case UserRole.manager:
        return 'manager';
      case UserRole.employee:
        return 'employee';
    }
  }
}

class AuthSessionEntity extends Equatable {
  final String accessToken;
  final String? refreshToken;
  final String tenantId;
  final String userId;
  final UserRole role;
  final String email;
  final String displayName;

  const AuthSessionEntity({
    required this.accessToken,
    this.refreshToken,
    required this.tenantId,
    required this.userId,
    required this.role,
    required this.email,
    required this.displayName,
  });

  @override
  List<Object?> get props => [
        accessToken,
        refreshToken,
        tenantId,
        userId,
        role,
        email,
        displayName,
      ];
}
