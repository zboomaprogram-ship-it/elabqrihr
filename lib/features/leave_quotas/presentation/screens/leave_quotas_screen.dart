import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:attend_mobile/core/design_system/app_theme.dart';
import 'package:attend_mobile/core/design_system/widgets/skeleton_loaders.dart';
import '../cubit/leave_quota_cubit.dart';
import '../cubit/leave_quota_state.dart';
import '../widgets/leave_quota_balance_card.dart';

class LeaveQuotasScreen extends StatefulWidget {
  const LeaveQuotasScreen({super.key});

  @override
  State<LeaveQuotasScreen> createState() => _LeaveQuotasScreenState();
}

class _LeaveQuotasScreenState extends State<LeaveQuotasScreen> {
  @override
  void initState() {
    super.initState();
    final cubit = context.read<LeaveQuotaCubit>();
    if (cubit.state is LeaveQuotaInitial) {
      cubit.loadBalances();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            'أرصدة الإجازات والاستئذان',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: AppTheme.textPrimary,
            ),
          ),
          centerTitle: true,
        ),
        body: BlocBuilder<LeaveQuotaCubit, LeaveQuotaState>(
          builder: (context, state) {
            if (state is LeaveQuotaLoading || state is LeaveQuotaInitial) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: ProfileSkeleton(),
              );
            }

            if (state is LeaveQuotaError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppTheme.errorColor, size: 42),
                      const SizedBox(height: 12),
                      Text(
                        state.message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: context.read<LeaveQuotaCubit>().loadBalances,
                        icon: const Icon(Icons.refresh),
                        label: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final balances = (state as LeaveQuotaLoaded).balances;
            if (balances.isEmpty) {
              return RefreshIndicator(
                onRefresh: context.read<LeaveQuotaCubit>().refresh,
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: const [
                    SizedBox(height: 80),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.event_available_outlined,
                              size: 48, color: AppTheme.steel),
                          SizedBox(height: 12),
                          Text(
                            'لم يتم نشر سياسات أرصدة للشركة حتى الآن.',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: context.read<LeaveQuotaCubit>().refresh,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                itemCount: balances.length,
                separatorBuilder: (_, __) => const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  return LeaveQuotaBalanceCard(balance: balances[index]);
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
