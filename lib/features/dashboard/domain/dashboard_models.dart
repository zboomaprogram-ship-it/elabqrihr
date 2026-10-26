import 'package:equatable/equatable.dart';
import 'package:attend_mobile/features/profile/domain/profile_models.dart';

class DashboardSummary extends Equatable {
  final UserProfile profile;
  final String attendanceState;
  final int pendingRequests;
  final int pendingApprovals;
  final int teamExceptions;
  final List<String> capabilities;

  const DashboardSummary({
    required this.profile,
    this.attendanceState = 'not_started',
    this.pendingRequests = 0,
    this.pendingApprovals = 0,
    this.teamExceptions = 0,
    this.capabilities = const [],
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    final rawCaps = json['capabilities'] as List<dynamic>? ?? [];
    return DashboardSummary(
      profile: UserProfile.fromJson(json['profile'] as Map<String, dynamic>),
      attendanceState: json['attendanceState'] as String? ?? 'not_started',
      pendingRequests: json['pendingRequests'] as int? ?? 0,
      pendingApprovals: json['pendingApprovals'] as int? ?? 0,
      teamExceptions: json['teamExceptions'] as int? ?? 0,
      capabilities: rawCaps.map((c) => c.toString()).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'profile': profile.toJson(),
        'attendanceState': attendanceState,
        'pendingRequests': pendingRequests,
        'pendingApprovals': pendingApprovals,
        'teamExceptions': teamExceptions,
        'capabilities': capabilities,
      };

  @override
  List<Object?> get props => [
        profile,
        attendanceState,
        pendingRequests,
        pendingApprovals,
        teamExceptions,
        capabilities,
      ];
}
