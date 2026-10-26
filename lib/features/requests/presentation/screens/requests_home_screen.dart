import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:attend_mobile/core/design_system/app_strings_ar.dart';
import 'package:attend_mobile/core/design_system/app_theme.dart';
import 'package:attend_mobile/core/design_system/app_motion.dart';
import 'package:attend_mobile/features/auth/domain/auth_models.dart';
import 'package:attend_mobile/features/requests/domain/request_models.dart';
import 'package:attend_mobile/features/requests/domain/request_repository.dart';
import 'package:attend_mobile/features/requests/presentation/cubits/employee_requests_cubit.dart';
import 'package:attend_mobile/features/requests/presentation/screens/manager_inbox_screen.dart';
import 'package:attend_mobile/features/requests/presentation/screens/request_catalog_screen.dart';
import 'package:attend_mobile/features/requests/presentation/screens/request_detail_screen.dart';
import 'package:attend_mobile/features/requests/presentation/widgets/request_card.dart';
import 'package:attend_mobile/features/dynamic_requests/domain/dynamic_request_repository.dart';
import 'package:attend_mobile/features/navigation/domain/role_navigation_policy.dart';
import 'package:attend_mobile/core/design_system/widgets/skeleton_loaders.dart';

class RequestsHomeScreen extends StatelessWidget {
  final UserRole userRole;

  const RequestsHomeScreen({
    super.key,
    this.userRole = UserRole.employee,
  });

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) {
            DynamicRequestRepository? dynRepo;
            try {
              dynRepo = context.read<DynamicRequestRepository>();
            } catch (_) {}
            return EmployeeRequestsCubit(
              repository: context.read<RequestRepository>(),
              dynamicRepository: dynRepo,
            )..loadRequests();
          },
        ),
      ],
      child: _RequestsHomeView(userRole: userRole),
    );
  }
}

class _RequestsHomeView extends StatefulWidget {
  final UserRole userRole;

  const _RequestsHomeView({required this.userRole});

  @override
  State<_RequestsHomeView> createState() => _RequestsHomeViewState();
}

class _RequestsHomeViewState extends State<_RequestsHomeView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool get _isReviewer =>
      RoleNavigationPolicy(widget.userRole).canAccessReviewerInbox;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _isReviewer ? 3 : 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStringsAr.requestsManagementTitle,
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primary,
          unselectedLabelColor: Colors.grey.shade600,
          indicatorColor: AppTheme.primary,
          tabs: [
            const Tab(
                text: AppStringsAr.myRequestsTab, icon: Icon(Icons.list_alt)),
            const Tab(
                text: AppStringsAr.newRequestTab,
                icon: Icon(Icons.add_circle_outline)),
            if (_isReviewer)
              const Tab(
                  text: AppStringsAr.reviewerInboxTitle,
                  icon: Icon(Icons.approval)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMyRequestsTab(),
          _buildNewRequestTab(),
          if (_isReviewer) const ManagerInboxScreen(),
        ],
      ),
    );
  }

  Widget _buildMyRequestsTab() {
    return BlocBuilder<EmployeeRequestsCubit, EmployeeRequestsState>(
      builder: (context, state) {
        return Column(
          children: [
            _buildHistoryHeader(state),
            if (state is EmployeeRequestsLoaded && state.pendingOutboxCount > 0)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: const Color(0xFFFEF3C7),
                child: Row(
                  children: [
                    const Icon(Icons.sync, size: 18, color: Color(0xFF92400E)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'يوجد ${state.pendingOutboxCount} طلبات معلقة بانتظار المزامنة',
                        style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF92400E),
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          context.read<EmployeeRequestsCubit>().syncOutbox(),
                      child: const Text('مزامنة الآن',
                          style: TextStyle(
                              color: Color(0xFF92400E),
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            _buildFilterConsole(state),
            Expanded(child: _buildRequestsList(context, state)),
          ],
        );
      },
    );
  }

  Widget _buildHistoryHeader(EmployeeRequestsState state) {
    final count =
        state is EmployeeRequestsLoaded ? state.requests.length : null;
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.history_rounded, color: AppTheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'سجل طلباتي',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  count == null
                      ? 'يتم تحميل طلباتك الحالية والسابقة.'
                      : count == 0
                          ? 'ستظهر هنا كل الطلبات التي تقدمها.'
                          : '$count طلبات تظهر حسب عامل التصفية الحالي.',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterConsole(EmployeeRequestsState state) {
    final activeState =
        state is EmployeeRequestsLoaded ? state.filterState : null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'حالة الطلب',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _filterChip(
                  label: 'الكل',
                  isSelected: activeState == null,
                  onSelected: () =>
                      context.read<EmployeeRequestsCubit>().filterByState(null),
                ),
                const SizedBox(width: 8),
                _filterChip(
                  label: 'قيد المراجعة',
                  isSelected: activeState == RequestState.submitted,
                  onSelected: () => context
                      .read<EmployeeRequestsCubit>()
                      .filterByState(RequestState.submitted),
                ),
                const SizedBox(width: 8),
                _filterChip(
                  label: 'معتمد',
                  isSelected: activeState == RequestState.approved,
                  onSelected: () => context
                      .read<EmployeeRequestsCubit>()
                      .filterByState(RequestState.approved),
                ),
                const SizedBox(width: 8),
                _filterChip(
                  label: 'مرفوض',
                  isSelected: activeState == RequestState.rejected,
                  onSelected: () => context
                      .read<EmployeeRequestsCubit>()
                      .filterByState(RequestState.rejected),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onSelected,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 38),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: AppTheme.primary.withValues(alpha: 0.15),
        checkmarkColor: AppTheme.primary,
        backgroundColor: Colors.grey.shade50,
        side: BorderSide(
          color: isSelected ? AppTheme.primary : Colors.grey.shade300,
          width: isSelected ? 1.5 : 1.0,
        ),
        labelStyle: TextStyle(
          color: isSelected ? AppTheme.primary : AppTheme.darkInk,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12.5,
        ),
        onSelected: (_) => onSelected(),
      ),
    );
  }

  Widget _buildRequestsList(BuildContext context, EmployeeRequestsState state) {
    if (state is EmployeeRequestsLoading) {
      return const RequestListSkeleton();
    }

    if (state is EmployeeRequestsError) {
      // The Cubit has already mapped the infrastructure failure to Arabic copy.
      // Re-mapping a string would hide a useful recovery instruction.
      final safeMessage = state.message;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppTheme.coral),
              const SizedBox(height: 16),
              Text(
                safeMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context
                    .read<EmployeeRequestsCubit>()
                    .loadRequests(refresh: true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    if (state is EmployeeRequestsLoaded) {
      if (state.requests.isEmpty) {
        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppMotion(
                  asset: AppMotionAsset.emptyRequests,
                  semanticLabel: 'لا توجد طلبات',
                  fallbackIcon: Icons.inbox_outlined,
                ),
                const SizedBox(height: 12),
                const Text(
                  AppStringsAr.noRequestsFound,
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _tabController.animateTo(1),
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: const Text('تقديم طلب جديد'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      return RefreshIndicator(
        onRefresh: () =>
            context.read<EmployeeRequestsCubit>().loadRequests(refresh: true),
        child: ListView.separated(
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          itemCount: state.requests.length,
          separatorBuilder: (_, __) => const SizedBox(height: 2),
          itemBuilder: (context, index) {
            final req = state.requests[index];
            return RequestCard(
              key: ValueKey('request_item_${req.id}'),
              request: req,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => RequestDetailScreen(
                      requestId: req.id,
                      isDynamic: req.isDynamic,
                    ),
                  ),
                );
              },
            );
          },
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildNewRequestTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ماذا تحتاج؟',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'اختر الخدمة المناسبة. ستظهر الحقول ومسار الاعتماد وفق سياسة شركتك.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppTheme.surface03),
        Expanded(
          child: RequestCatalogScreen(
            onRequestSubmitted: _returnToMyRequests,
          ),
        ),
      ],
    );
  }

  void _returnToMyRequests() {
    if (!mounted) return;
    _tabController.animateTo(0);
    context.read<EmployeeRequestsCubit>().loadRequests(refresh: true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم إرسال طلبك. يمكنك متابعة حالته من طلباتي.'),
        backgroundColor: AppTheme.mint,
      ),
    );
  }
}
