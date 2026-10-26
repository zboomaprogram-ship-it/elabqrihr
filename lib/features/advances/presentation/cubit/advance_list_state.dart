import 'package:attend_mobile/features/advances/domain/advance_models.dart';

sealed class AdvanceListState {
  const AdvanceListState();
}

final class AdvanceListInitial extends AdvanceListState {
  const AdvanceListInitial();
}

final class AdvanceListLoading extends AdvanceListState {
  const AdvanceListLoading();
}

final class AdvanceListLoaded extends AdvanceListState {
  final List<AdvanceEntity> items;
  final String? nextCursor;
  final bool isLoadingMore;

  const AdvanceListLoaded({
    required this.items,
    this.nextCursor,
    this.isLoadingMore = false,
  });

  bool get hasMore => nextCursor != null;

  AdvanceListLoaded copyWith({
    List<AdvanceEntity>? items,
    String? nextCursor,
    bool? isLoadingMore,
    bool clearNextCursor = false,
  }) =>
      AdvanceListLoaded(
        items: items ?? this.items,
        nextCursor: clearNextCursor ? null : (nextCursor ?? this.nextCursor),
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      );
}

final class AdvanceListEmpty extends AdvanceListState {
  const AdvanceListEmpty();
}

final class AdvanceListDenied extends AdvanceListState {
  const AdvanceListDenied();
}

final class AdvanceListError extends AdvanceListState {
  final String message;
  const AdvanceListError(this.message);
}
