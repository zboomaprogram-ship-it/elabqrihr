import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:attend_mobile/core/api/api_client.dart';
import 'package:attend_mobile/core/auth/token_storage.dart';
import 'package:attend_mobile/core/design_system/app_theme.dart';

class ServerConnectionDialog extends StatefulWidget {
  final ApiClient apiClient;
  final TokenStorage tokenStorage;
  final VoidCallback? onSaved;

  const ServerConnectionDialog({
    super.key,
    required this.apiClient,
    required this.tokenStorage,
    this.onSaved,
  });

  static Future<void> show(
    BuildContext context, {
    required ApiClient apiClient,
    required TokenStorage tokenStorage,
    VoidCallback? onSaved,
  }) {
    if (kReleaseMode) {
      return Future.value();
    }
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ServerConnectionDialog(
        apiClient: apiClient,
        tokenStorage: tokenStorage,
        onSaved: onSaved,
      ),
    );
  }

  @override
  State<ServerConnectionDialog> createState() => _ServerConnectionDialogState();
}

class _ServerConnectionDialogState extends State<ServerConnectionDialog> {
  late final TextEditingController _controller;
  bool _testing = false;
  String? _testResult;
  bool _testSuccess = false;

  static const String usbUrl = 'http://localhost:3000/api/v1';
  static const String wifiUrl = 'http://10.0.0.64:3000/api/v1';
  static const String emulatorUrl = 'http://10.0.2.2:3000/api/v1';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.apiClient.baseUrl);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _testPing(String url) async {
    setState(() {
      _testing = true;
      _testResult = null;
    });

    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 4),
          validateStatus: (status) => true,
        ),
      );
      final checkUrl = url.endsWith('/api/v1')
          ? '$url/health/ready'
          : (url.endsWith('/') ? '${url}api/v1/health/ready' : '$url/api/v1/health/ready');

      final res = await dio.get(checkUrl);
      if (res.statusCode == 200) {
        setState(() {
          _testSuccess = true;
          _testResult = 'تم الاتصال بالخادم بنجاح! (200 OK)';
        });
      } else if (res.statusCode != null && res.statusCode! > 0) {
        setState(() {
          _testSuccess = true;
          _testResult = 'تم الاتصال بالخادم بنجاح! (${res.statusCode})';
        });
      } else {
        setState(() {
          _testSuccess = false;
          _testResult = 'استجاب الخادم برمز غير معروف';
        });
      }
    } catch (e) {
      setState(() {
        _testSuccess = false;
        _testResult = 'فشل الاتصال: تأكد من تشغيل الخادم والشبكة.';
      });
    } finally {
      if (mounted) {
        setState(() => _testing = false);
      }
    }
  }

  Future<void> _save() async {
    final url = _controller.text.trim();
    if (url.isEmpty) return;

    await widget.tokenStorage.saveBaseUrl(url);
    widget.apiClient.updateBaseUrl(url);
    if (widget.onSaved != null) {
      widget.onSaved!();
    }
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم حفظ عنوان الخادم: $url'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUrl = widget.apiClient.baseUrl;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(
            top: BorderSide(color: AppTheme.surface03, width: 1.5),
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.surface03,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Icon(Icons.router, color: AppTheme.primaryColor),
                  SizedBox(width: 8),
                  Text(
                    'إعدادات الاتصال بالخادم المحلي',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'اختر وضع الاتصال المناسب لجهازك أو أدخل عنوان الخادم:',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildPresetChip(
                    label: 'وصلة USB (localhost)',
                    subtitle: 'يتطلب adb reverse',
                    url: usbUrl,
                    isSelected: _controller.text == usbUrl,
                  ),
                  _buildPresetChip(
                    label: 'شبكة Wi-Fi (10.0.0.64)',
                    subtitle: 'عنوان ماك المحلي',
                    url: wifiUrl,
                    isSelected: _controller.text == wifiUrl,
                  ),
                  _buildPresetChip(
                    label: 'محاكي أندرويد (10.0.2.2)',
                    subtitle: 'للإيموليتور فقط',
                    url: emulatorUrl,
                    isSelected: _controller.text == emulatorUrl,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'عنوان الخادم (API Base URL)',
                  labelStyle: const TextStyle(color: AppTheme.primaryColor),
                  filled: true,
                  fillColor: AppTheme.surface02,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppTheme.surface03),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
                  ),
                  prefixIcon: const Icon(Icons.link, color: AppTheme.textSecondary),
                ),
              ),
              if (_testResult != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _testSuccess
                        ? AppTheme.successColor.withValues(alpha: 0.12)
                        : AppTheme.errorColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _testSuccess
                          ? AppTheme.successColor.withValues(alpha: 0.4)
                          : AppTheme.errorColor.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _testSuccess ? Icons.check_circle : Icons.error_outline,
                        color: _testSuccess
                            ? AppTheme.successColor
                            : AppTheme.errorColor,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _testResult!,
                          style: TextStyle(
                            fontSize: 12,
                            color: _testSuccess
                                ? AppTheme.successColor
                                : AppTheme.errorColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _testing ? null : () => _testPing(_controller.text.trim()),
                      icon: _testing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.bolt, size: 18),
                      label: const Text('اختبار الاتصال'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
                        side: const BorderSide(color: AppTheme.primaryColor),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.save, size: 18),
                      label: const Text('حفظ واستخدام'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'العنوان النشط حالياً: $currentUrl',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPresetChip({
    required String label,
    required String subtitle,
    required String url,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () {
        setState(() {
          _controller.text = url;
          _testResult = null;
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.secondaryColor.withValues(alpha: 0.25)
              : AppTheme.surface02,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : AppTheme.surface03,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimary,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
