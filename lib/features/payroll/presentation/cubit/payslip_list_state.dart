import 'package:attend_mobile/features/payroll/domain/payslip_models.dart';

sealed class PayslipListState {
  const PayslipListState();
}

final class PayslipListInitial extends PayslipListState {
  const PayslipListInitial();
}

final class PayslipListLoading extends PayslipListState {
  const PayslipListLoading();
}

final class PayslipListLoaded extends PayslipListState {
  final List<PayslipSummaryEntity> items;
  final String? nextCursor;
  final bool isLoadingMore;

  const PayslipListLoaded({
    required this.items,
    this.nextCursor,
    this.isLoadingMore = false,
  });

  bool get hasMore => nextCursor != null;

  PayslipListLoaded copyWith({
    List<PayslipSummaryEntity>? items,
    String? nextCursor,
    bool? isLoadingMore,
    bool clearNextCursor = false,
  }) =>
      PayslipListLoaded(
        items: items ?? this.items,
        nextCursor: clearNextCursor ? null : (nextCursor ?? this.nextCursor),
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      );
}

final class PayslipListEmpty extends PayslipListState {
  const PayslipListEmpty();
}

final class PayslipListDenied extends PayslipListState {
  const PayslipListDenied();
}

final class PayslipListError extends PayslipListState {
  final String message;
  const PayslipListError(this.message);
}
