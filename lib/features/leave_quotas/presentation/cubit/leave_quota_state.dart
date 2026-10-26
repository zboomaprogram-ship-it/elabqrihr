import 'package:equatable/equatable.dart';
import '../../domain/leave_quota_models.dart';

abstract class LeaveQuotaState extends Equatable {
  const LeaveQuotaState();

  @override
  List<Object?> get props => [];
}

class LeaveQuotaInitial extends LeaveQuotaState {
  const LeaveQuotaInitial();
}

class LeaveQuotaLoading extends LeaveQuotaState {
  const LeaveQuotaLoading();
}

class LeaveQuotaLoaded extends LeaveQuotaState {
  final List<QuotaBalanceEntity> balances;

  const LeaveQuotaLoaded(this.balances);

  QuotaBalanceEntity? get dayOffQuota =>
      balances.where((b) => b.quotaKey == QuotaKey.dayOff).firstOrNull;

  QuotaBalanceEntity? get timePermissionQuota =>
      balances.where((b) => b.quotaKey == QuotaKey.timePermission).firstOrNull;

  @override
  List<Object?> get props => [balances];
}

class LeaveQuotaError extends LeaveQuotaState {
  final String message;

  const LeaveQuotaError(this.message);

  @override
  List<Object?> get props => [message];
}
