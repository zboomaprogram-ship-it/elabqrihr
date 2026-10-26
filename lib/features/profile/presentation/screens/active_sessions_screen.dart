import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:attend_mobile/core/design_system/app_theme.dart';
import 'package:attend_mobile/core/design_system/widgets/wolf_card.dart';
import 'package:attend_mobile/core/errors/app_failure.dart';
import 'package:attend_mobile/features/profile/domain/profile_models.dart';
import 'package:attend_mobile/features/profile/domain/profile_repository.dart';

class ActiveSessionsScreen extends StatefulWidget {
  const ActiveSessionsScreen({super.key});

  @override
  State<ActiveSessionsScreen> createState() => _ActiveSessionsScreenState();
}

class _ActiveSessionsScreenState extends State<ActiveSessionsScreen> {
  List<AccountSession>? _sessions;
  bool _isLoading = true;
  String? _errorMessage;
  String? _revokingSessionId;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repository = context.read<ProfileRepository>();
      final sessions = await repository.getActiveSessions();
      if (!mounted) return;
      setState(() {
        _sessions = sessions;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      final failure = AppFailureMapper.fromGeneric(e);
      setState(() {
        _errorMessage = failure.message;
        _isLoading = false;
      });
    }
  }

  Future<void> _confirmAndRevokeSession(AccountSession session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppTheme.surface03),
        ),
        title: const Text(
          'إنهاء الجلسة',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
          textDirection: TextDirection.rtl,
        ),
        content: Text(
          'هل تريد بالتأكيد إنهاء الجلسة على جهاز (${_clientTypeLabel(session.clientType)})؟ سيتم تسجيل الخروج فوراً من ذلك الجهاز.',
          style: const TextStyle(color: AppTheme.textSecondary),
          textDirection: TextDirection.rtl,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('إلغاء', style: TextStyle(color: AppTheme.steel)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('إنهاء الجلسة'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    final repository = context.read<ProfileRepository>();
    setState(() {
      _revokingSessionId = session.id;
    });

    try {
      await repository.revokeSession(session.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم إنهاء الجلسة المحددة بنجاح.',
            textDirection: TextDirection.rtl,
          ),
          backgroundColor: AppTheme.successColor,
        ),
      );
      _loadSessions();
    } catch (e) {
      if (!mounted) return;
      final failure = AppFailureMapper.fromGeneric(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            failure.message,
            textDirection: TextDirection.rtl,
          ),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _revokingSessionId = null;
        });
      }
    }
  }

  static String _clientTypeLabel(String clientType) {
    switch (clientType.toLowerCase()) {
      case 'mobile':
        return 'هاتف محمول';
      case 'web':
        return 'متصفح ويب';
      case 'desktop':
        return 'تطبيق حاسوب';
      default:
        return clientType;
    }
  }

  static IconData _clientTypeIcon(String clientType) {
    switch (clientType.toLowerCase()) {
      case 'mobile':
        return Icons.phone_android;
      case 'web':
        return Icons.language;
      default:
        return Icons.devices;
    }
  }

  static String _formatDate(DateTime dt) {
    return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
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
            'الجلسات والأجهزة النشطة',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: AppTheme.textPrimary,
            ),
          ),
          centerTitle: true,
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(key: Key('sessions_loading')),
      );
    }

    if (_errorMessage != null) {
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
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadSessions,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    final sessions = _sessions ?? [];
    if (sessions.isEmpty) {
      return const Center(
        child: Text(
          'لا توجد جلسات نشطة مسجلة.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }

    final currentSessions = sessions.where((s) => s.current).toList();
    final otherSessions = sessions.where((s) => !s.current).toList();

    return RefreshIndicator(
      onRefresh: _loadSessions,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          if (currentSessions.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.only(bottom: 8, top: 4),
              child: Text(
                'هذا الجهاز (الجلسة الحالية)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            ...currentSessions.map((session) => _buildSessionCard(session, isCurrent: true)),
            const SizedBox(height: 16),
          ],
          if (otherSessions.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.only(bottom: 8, top: 4),
              child: Text(
                'الجلسات والأجهزة الأخرى المرتبطة بحسابك',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            ...otherSessions.map((session) => _buildSessionCard(session, isCurrent: false)),
          ] else ...[
            const AttendCard(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.shield_outlined, color: AppTheme.mint, size: 22),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'لا توجد جلسات نشطة أخرى على أجهزة مختلفة.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSessionCard(AccountSession session, {required bool isCurrent}) {
    final isRevokingThis = _revokingSessionId == session.id;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AttendCard(
        key: Key('session_card_${session.id}'),
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isCurrent
                    ? AppTheme.primaryColor.withValues(alpha: 0.1)
                    : AppTheme.surface03,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _clientTypeIcon(session.clientType),
                color: isCurrent ? AppTheme.primaryColor : AppTheme.steel,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        isCurrent
                            ? 'هذا الجهاز (${_clientTypeLabel(session.clientType)})'
                            : 'جهاز مسجل (${_clientTypeLabel(session.clientType)})',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      if (isCurrent)
                        Container(
                          key: const Key('current_session_badge'),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.successColor
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: AppTheme.successColor
                                    .withValues(alpha: 0.3)),
                          ),
                          child: const Text(
                            'الجلسة الحالية',
                            style: TextStyle(
                              color: AppTheme.successColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'بدأت: ${_formatDate(session.createdAt)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  if (session.deviceInstallationId != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      isCurrent
                          ? 'تطبيق الهاتف الحالي'
                          : 'تطبيق هاتف مثبت',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.steel,
                      ),
                    ),
                  ],
                  if (isCurrent) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'لحماية حسابك، يمكنك إنهاء هذه الجلسة الحالية من زر تسجيل الخروج في الملف الشخصي.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.steel,
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        key: Key('revoke_session_${session.id}'),
                        onPressed: isRevokingThis
                            ? null
                            : () => _confirmAndRevokeSession(session),
                        icon: isRevokingThis
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              )
                            : const Icon(Icons.remove_circle_outline,
                                size: 16, color: AppTheme.errorColor),
                        label: const Text(
                          'إنهاء هذه الجلسة',
                          style: TextStyle(
                            color: AppTheme.errorColor,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
