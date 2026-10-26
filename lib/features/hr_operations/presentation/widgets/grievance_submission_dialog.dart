import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:attend_mobile/core/design_system/app_theme.dart';

class GrievanceSubmissionDialog extends StatefulWidget {
  final String operationId;
  final int expectedRevision;
  final Future<void> Function({
    required String commandId,
    required int expectedRevision,
    required String statement,
  }) onSubmit;

  const GrievanceSubmissionDialog({
    super.key,
    required this.operationId,
    required this.expectedRevision,
    required this.onSubmit,
  });

  @override
  State<GrievanceSubmissionDialog> createState() =>
      _GrievanceSubmissionDialogState();
}

class _GrievanceSubmissionDialogState extends State<GrievanceSubmissionDialog> {
  final _statementController = TextEditingController();
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _statementController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final statement = _statementController.text.trim();
    if (statement.length < 3) {
      setState(() {
        _error = 'يرجى كتابة نص التظلم والبيان التوضيحي (3 أحرف على الأقل).';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final commandId = const Uuid().v4();
      await widget.onSubmit(
        commandId: commandId,
        expectedRevision: widget.expectedRevision,
        statement: statement,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _error = 'تعذر إرسال التظلم؛ يرجى المحاولة مرة أخرى.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.gavel_rounded, color: AppTheme.primaryColor),
          SizedBox(width: 8),
          Text(
            'تقديم تظلم إداري',
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
              'يحق لك تقديم تظلم كتابي توضح فيه وجهة نظرك وأي ملابسات ذات صلة. ستتم مراجعة التظلم بواسطة لجنة محايدة.',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _statementController,
              maxLines: 4,
              maxLength: 4000,
              decoration: InputDecoration(
                labelText: 'بيان التظلم والشرح التفصيلي *',
                hintText: 'اكتب أسباب التظلم بالتفصيل...',
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
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
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
              : const Text('إرسال التظلم'),
        ),
      ],
    );
  }
}
