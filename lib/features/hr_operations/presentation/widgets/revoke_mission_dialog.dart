import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:attend_mobile/core/design_system/app_theme.dart';

class RevokeMissionDialog extends StatefulWidget {
  final String operationId;
  final int expectedRevision;
  final Future<void> Function({
    required String commandId,
    required int expectedRevision,
    required String reason,
  }) onRevoke;

  const RevokeMissionDialog({
    super.key,
    required this.operationId,
    required this.expectedRevision,
    required this.onRevoke,
  });

  @override
  State<RevokeMissionDialog> createState() => _RevokeMissionDialogState();
}

class _RevokeMissionDialogState extends State<RevokeMissionDialog> {
  final _reasonController = TextEditingController();
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reasonController.text.trim();
    if (reason.length < 3) {
      setState(() {
        _error = 'يرجى كتابة سبب الإلغاء بوضوح (3 أحرف على الأقل).';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final commandId = const Uuid().v4();
      await widget.onRevoke(
        commandId: commandId,
        expectedRevision: widget.expectedRevision,
        reason: reason,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _error = 'تعذر تنفيذ الإلغاء؛ يرجى المحاولة مرة أخرى.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: AppTheme.errorColor),
          SizedBox(width: 8),
          Text(
            'إلغاء المأمورية المعتمدة',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'سيؤدي هذا الإجراء إلى إلغاء سريان المأمورية للفترة المتبقية القادمة. البصمات السابقة المسجلة داخل النطاق المعتمد تبقى موثقة.',
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _reasonController,
              maxLines: 3,
              maxLength: 1000,
              decoration: InputDecoration(
                labelText: 'سبب الإلغاء الإداري *',
                hintText: 'اكتب سبب إلغاء المأمورية...',
                errorText: _error,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('تراجع'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.errorColor,
            foregroundColor: Colors.white,
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('تأكيد الإلغاء'),
        ),
      ],
    );
  }
}
