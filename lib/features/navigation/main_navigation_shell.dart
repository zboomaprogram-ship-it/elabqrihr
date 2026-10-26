import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:attend_mobile/core/design_system/app_strings_ar.dart';
import 'package:attend_mobile/core/design_system/app_theme.dart';
import 'package:attend_mobile/features/attendance/presentation/widgets/attendance_screen.dart';
import 'package:attend_mobile/features/auth/domain/auth_models.dart';
import 'package:attend_mobile/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:attend_mobile/features/auth/presentation/cubit/auth_state.dart';
import 'package:attend_mobile/features/dashboard/presentation/screens/home_screen.dart';
import 'package:attend_mobile/features/dashboard/presentation/screens/team_roster_screen.dart';
import 'package:attend_mobile/features/navigation/domain/role_navigation_policy.dart';
import 'package:attend_mobile/features/profile/presentation/screens/profile_screen.dart';
import 'package:attend_mobile/features/requests/presentation/screens/manager_inbox_screen.dart';
import 'package:attend_mobile/features/requests/presentation/screens/requests_home_screen.dart';

/// Provides a way for child widgets to switch the bottom-nav tab.
/// Any child that needs to navigate to a different tab can read this
/// notifier and set its value.
class MainTabController extends InheritedNotifier<ValueNotifier<int>> {
  const MainTabController({
    super.key,
    required ValueNotifier<int> tabNotifier,
    required super.child,
  }) : super(notifier: tabNotifier);

  static ValueNotifier<int>? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<MainTabController>()
        ?.notifier;
  }

  /// Switches the main navigation shell to [tabIndex].
  static void switchTab(BuildContext context, int tabIndex) {
    maybeOf(context)?.value = tabIndex;
  }

  static ValueNotifier<int>? _activeNotifier;

  /// Allows an authenticated system-notification tap to switch tabs from the
  /// root navigator, where there is no descendant BuildContext for this
  /// inherited widget.
  static void switchCurrentTab(int tabIndex) {
    _activeNotifier?.value = tabIndex;
  }
}

class MainNavigationShell extends StatefulWidget {
  final UserRole? userRole;

  const MainNavigationShell({super.key, this.userRole});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  late final ValueNotifier<int> _tabNotifier;

  @override
  void initState() {
    super.initState();
    _tabNotifier = ValueNotifier<int>(0);
    MainTabController._activeNotifier = _tabNotifier;
    _tabNotifier.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    if (identical(MainTabController._activeNotifier, _tabNotifier)) {
      MainTabController._activeNotifier = null;
    }
    _tabNotifier.removeListener(_onTabChanged);
    _tabNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, authState) {
        final session = authState is Authenticated ? authState.session : null;
        final role = widget.userRole ?? session?.role ?? UserRole.employee;
        final policy = RoleNavigationPolicy(role);

        final List<Widget> tabs;
        final List<BottomNavigationBarItem> navItems;

        if (policy.isManager) {
          // A manager is also an employee. Self-attendance must remain reachable
          // alongside team roster and approval responsibilities.
          tabs = const [
            HomeScreen(),
            AttendanceScreen(),
            TeamRosterScreen(),
            ManagerInboxScreen(),
            ProfileScreen(),
          ];
          navItems = const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_filled),
              label: 'الرئيسية',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.access_time_filled),
              label: AppStringsAr.attendanceTab,
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.groups),
              label: 'فريقي',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.playlist_add_check),
              label: AppStringsAr.reviewerInboxTitle,
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'حسابي',
            ),
          ];
        } else if (policy.isHrOrAdmin) {
          // HR / Admin matrix: Home, Attendance, Requests/Approvals, Profile
          tabs = [
            const HomeScreen(),
            const AttendanceScreen(),
            RequestsHomeScreen(userRole: role),
            const ProfileScreen(),
          ];
          navItems = const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_filled),
              label: 'الرئيسية',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.access_time_filled),
              label: AppStringsAr.attendanceTab,
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.assignment),
              label: AppStringsAr.requestsTab,
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'حسابي',
            ),
          ];
        } else {
          // Employee matrix: Home, Attendance, Requests, Profile
          tabs = const [
            HomeScreen(),
            AttendanceScreen(),
            RequestsHomeScreen(),
            ProfileScreen(),
          ];
          navItems = const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_filled),
              label: 'الرئيسية',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.access_time_filled),
              label: AppStringsAr.attendanceTab,
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.assignment),
              label: AppStringsAr.requestsTab,
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'حسابي',
            ),
          ];
        }

        final safeIndex =
            _tabNotifier.value < tabs.length ? _tabNotifier.value : 0;

        return MainTabController(
          tabNotifier: _tabNotifier,
          child: Scaffold(
            backgroundColor: AppTheme.background,
            body: IndexedStack(
              index: safeIndex,
              children: tabs,
            ),
            bottomNavigationBar: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 12.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24.0),
                    border: Border.all(color: AppTheme.borderColor),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 16,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24.0),
                    child: BottomNavigationBar(
                      currentIndex: safeIndex,
                      onTap: (index) {
                        _tabNotifier.value = index;
                      },
                      selectedItemColor: AppTheme.primaryColor,
                      unselectedItemColor: AppTheme.textSecondary,
                      backgroundColor: Colors.white,
                      type: BottomNavigationBarType.fixed,
                      elevation: 0,
                      items: navItems,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
